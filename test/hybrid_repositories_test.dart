import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/protheus_empenho.dart';
import 'package:vetti_flow_1_0/data/models/protheus_order.dart';
import 'package:vetti_flow_1_0/data/models/warehouse.dart';
import 'package:vetti_flow_1_0/data/repositories/empenho_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/product_catalog_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_order_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_sync_client.dart';

/// Fabrica um [ProtheusSyncClient] cujo transporte é este [MockClient] — sem
/// isso, todo teste de repositório híbrido precisaria de uma API de verdade
/// no ar, o que é exatamente o cenário que estes testes existem para cobrir
/// sem depender dele.
ProtheusSyncClient _cliente(http.Client mock) =>
    ProtheusSyncClient(baseUrl: 'http://teste', httpClient: mock);

/// Sempre recusa — simula a API fora do alcance.
ProtheusSyncClient _clienteIndisponivel() =>
    _cliente(MockClient((_) async => throw Exception('sem rede')));

void main() {
  group('HybridProtheusOrderRepository', () {
    ProtheusOrder op(String numero, String filial, {bool encerrada = false}) =>
        ProtheusOrder(
          key: ProtheusOrderKey(
            filial: filial,
            numero: numero,
            item: '01',
            sequencia: '001',
          ),
          productCode: '730-0863',
          quantity: 100,
          closed: encerrada,
        );

    test('refresh bem-sucedido substitui as OPs abertas da filial', () async {
      final cliente = _cliente(
        MockClient((req) async {
          expect(req.url.path, '/api/v1/ops/abertas');
          expect(req.url.queryParameters['filial'], '04');
          return http.Response(
            jsonEncode([
              {
                'filial': '04',
                'numero': '099999',
                'item': '01',
                'sequencia': '001',
                'itemGrade': '',
                'produto': '730-0863',
                'quantidade': 10,
                'local': '10',
                'emissao': '01/08/2026',
                'previsao': '05/08/2026',
                'encerrada': false,
              },
            ]),
            200,
          );
        }),
      );
      final repo = HybridProtheusOrderRepository(
        [op('015961', '04'), op('015900', '04', encerrada: true), op('039736', '03')],
        client: cliente,
      );

      await repo.refresh('04');

      expect(repo.usandoRetratoDesatualizado, isFalse);
      // A OP aberta antiga da filial 04 saiu — só a API manda a verdade sobre
      // o que está aberto agora.
      expect(
        repo.openIn('04').map((o) => o.key.numero),
        ['099999'],
      );
      // Encerrada da 04 e a da filial 03 continuam vindo do retrato original.
      expect(repo.all.any((o) => o.key.numero == '015900'), isTrue);
      expect(repo.all.any((o) => o.key.numero == '039736'), isTrue);
    });

    test('refresh falho mantém o retrato anterior e liga a flag', () async {
      final repo = HybridProtheusOrderRepository(
        [op('015961', '04')],
        client: _clienteIndisponivel(),
      );

      await repo.refresh('04');

      expect(repo.usandoRetratoDesatualizado, isTrue);
      expect(repo.ultimoErro, isNotNull);
      expect(repo.openIn('04').map((o) => o.key.numero), ['015961']);
    });
  });

  group('HybridEmpenhoRepository', () {
    test('refresh bem-sucedido substitui só as linhas da OP pedida', () async {
      final cliente = _cliente(
        MockClient((req) async {
          expect(req.url.path, '/api/v1/ops/01596101001/empenhos');
          return http.Response(
            jsonEncode([
              {
                'op': '01596101001',
                'produto': '102-339',
                'local': '10',
                'quantidade': 418.0,
                'quantidadeOriginal': 500.0,
              },
            ]),
            200,
          );
        }),
      );
      final repo = HybridEmpenhoRepository(
        [
          const ProtheusEmpenho(
            filial: '04',
            op: '01596101001',
            produto: '999-999',
            local: '01',
            quantidade: 1,
          ),
          const ProtheusEmpenho(
            filial: '04',
            op: '09999901001',
            produto: '100-003',
            local: '01',
            quantidade: 5,
          ),
        ],
        client: cliente,
      );

      await repo.refresh('01596101001', '04');

      expect(repo.usandoRetratoDesatualizado, isFalse);
      final linhas = repo.byOp('01596101001');
      expect(linhas.map((e) => e.produto), ['102-339']);
      expect(linhas.single.quantidadeOriginal, 500.0);
      // OP não tocada pelo refresh continua intacta.
      expect(repo.byOp('09999901001'), hasLength(1));
    });

    test('refresh falho mantém o retrato anterior e liga a flag', () async {
      final repo = HybridEmpenhoRepository(
        [
          const ProtheusEmpenho(
            filial: '04',
            op: '01596101001',
            produto: '102-339',
            local: '10',
            quantidade: 418,
          ),
        ],
        client: _clienteIndisponivel(),
      );

      await repo.refresh('01596101001', '04');

      expect(repo.usandoRetratoDesatualizado, isTrue);
      expect(repo.byOp('01596101001'), hasLength(1));
    });
  });

  group('HybridProductCatalogRepository', () {
    test('refreshSaldo substitui só o saldo da filial pedida', () async {
      final cliente = _cliente(
        MockClient((req) async {
          expect(req.url.path, '/api/v1/produtos/100-003/saldos');
          return http.Response(
            jsonEncode([
              {'local': '01', 'saldo': 4676.0, 'empenhado': 0.0},
            ]),
            200,
          );
        }),
      );
      final repo = HybridProductCatalogRepository(
        [
          const ProductionCatalogItem(
            code: '100-003',
            name: 'PARAFUSO',
            saldos: [
              SaldoArmazem(filial: '04', local: '70', saldo: 1400, empenhado: 1400),
              SaldoArmazem(filial: '03', local: '10', saldo: -10, empenhado: 467),
            ],
          ),
        ],
        client: cliente,
      );

      await repo.refreshSaldo('100-003', '04');

      expect(repo.usandoRetratoDesatualizado, isFalse);
      final item = repo.findByCode('100-003')!;
      // Saldo antigo da filial 04 (local 70) some — a API é quem manda agora
      // sobre a 04. O da filial 03 é preservado, e o novo (local 01) entrou.
      expect(item.saldoNa('04'), 4676);
      expect(item.saldoNa('03'), -10);
      // Nome/estrutura continuam vindo do cadastro estático.
      expect(item.name, 'PARAFUSO');
    });

    test('refresh falho mantém o saldo anterior e liga a flag', () async {
      final repo = HybridProductCatalogRepository(
        [
          const ProductionCatalogItem(
            code: '100-003',
            name: 'PARAFUSO',
            saldos: [
              SaldoArmazem(filial: '04', local: '70', saldo: 1400, empenhado: 1400),
            ],
          ),
        ],
        client: _clienteIndisponivel(),
      );

      await repo.refreshSaldo('100-003', '04');

      expect(repo.usandoRetratoDesatualizado, isTrue);
      expect(repo.findByCode('100-003')!.saldoNa('04'), 1400);
    });

    test('refreshSaldo de produto inexistente não faz nada', () async {
      final repo = HybridProductCatalogRepository(
        const [],
        client: _clienteIndisponivel(),
      );

      await repo.refreshSaldo('000-000', '04');

      expect(repo.usandoRetratoDesatualizado, isFalse);
      expect(repo.findByCode('000-000'), isNull);
    });
  });
}
