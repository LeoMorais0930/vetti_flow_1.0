import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/protheus_empenho.dart';
import 'package:vetti_flow_1_0/data/models/protheus_order.dart';
import 'package:vetti_flow_1_0/data/models/warehouse.dart';
import 'package:vetti_flow_1_0/data/repositories/empenho_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/flow_op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_order_repository.dart';

import 'fixtures.dart';

/// A filial é uma parede, não um rótulo.
///
/// Quem opera na filial 03 não pode ver OP, saldo nem empenho da 04 — no
/// Protheus são estoques físicos diferentes, em prédios diferentes. Estes
/// testes existem porque a primeira versão somava as duas: a tela mostrava um
/// total da empresa que não aparecia em nenhuma consulta do ERP, e ninguém
/// percebeu até conferir contra o banco.
void main() {
  group('OPs não vazam entre filiais', () {
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

    final repo = AssetProtheusOrderRepository([
      op('015961', '04'),
      op('015962', '04'),
      op('015963', '03'),
      op('015900', '04', encerrada: true),
      op('015901', '03', encerrada: true),
    ]);

    test('openIn traz só as da filial pedida', () {
      expect(
        repo.openIn('04').map((o) => o.key.numero),
        ['015961', '015962'],
      );
      expect(repo.openIn('03').map((o) => o.key.numero), ['015963']);
    });

    test('openIn não traz OP encerrada', () {
      expect(
        repo.openIn('04').every((o) => !o.closed),
        isTrue,
        reason: 'OP encerrada é somente leitura, não entra na lista de operar',
      );
    });

    test('openIn de filial sem OP devolve vazio, não a lista toda', () {
      // O modo de falhar que importa: um filtro que não casa nada devolvendo
      // tudo é pior do que devolvendo nada — o operador não teria como notar.
      expect(repo.openIn('90'), isEmpty);
    });

    test('search restrita à filial não devolve OP da outra', () {
      final achados = repo.search('0159', filial: '03');

      expect(achados.map((o) => o.key.numero), ['015963']);
    });

    test('search sem filial varre a empresa — é o contrato', () {
      expect(repo.search('0159').length, 3);
    });
  });

  group('empenho não vaza entre filiais', () {
    ProtheusEmpenho linha(String filial, String produto) => ProtheusEmpenho(
      filial: filial,
      op: '01596101001',
      produto: produto,
      local: '01',
      quantidade: 10,
    );

    // O caso que hoje não acontece no recorte embarcado mas o Protheus permite:
    // o mesmo número de OP existindo nas duas filiais, porque ele numera por
    // filial. Sem filtro, uma filial passa a ver o empenho da outra.
    final repo = AssetEmpenhoRepository([
      linha('04', '200-052'),
      linha('04', '200-053'),
      linha('03', '999-999'),
    ]);

    test('byOp com filial devolve só as linhas daquela filial', () {
      expect(
        repo.byOp('01596101001', filial: '04').map((e) => e.produto),
        ['200-052', '200-053'],
      );
      expect(
        repo.byOp('01596101001', filial: '03').map((e) => e.produto),
        ['999-999'],
      );
    });

    test('byOp sem filial devolve tudo — é o contrato', () {
      expect(repo.byOp('01596101001'), hasLength(3));
    });
  });

  group('saldo é por filial, nunca somado', () {
    // Números reais do produto 100-003 no banco migrado, em 31/07/2026.
    const item = ProductionCatalogItem(
      code: '100-003',
      name: 'PARAFUSO 5/32 X 3/4 ZI',
      stock: 6066,
      committed: 1867,
      saldos: [
        SaldoArmazem(filial: '04', local: '01', saldo: 4676, empenhado: 0),
        SaldoArmazem(filial: '03', local: '10', saldo: -10, empenhado: 467),
        SaldoArmazem(filial: '04', local: '70', saldo: 1400, empenhado: 1400),
      ],
    );

    test('saldoNa devolve o total da filial, não o da empresa', () {
      expect(item.saldoNa('04'), 6076);
      expect(item.saldoNa('03'), -10);
    });

    test('empenhadoNa devolve o total da filial', () {
      expect(item.empenhadoNa('04'), 1400);
      expect(item.empenhadoNa('03'), 467);
    });

    test('o agregado não é igual a nenhuma das filiais', () {
      // É exatamente por isso que ele não pode ir para a tela: 6066 é um número
      // que não aparece em consulta nenhuma do Protheus.
      expect(item.stock, isNot(item.saldoNa('04')));
      expect(item.stock, isNot(item.saldoNa('03')));
      expect(item.stock, item.saldoNa('04') + item.saldoNa('03'));
    });

    test('saldo negativo da filial é preservado, não zerado', () {
      // O Protheus permite estouro e isso acontece de verdade quando o material
      // está a caminho. Esconder viraria uma separação que não fecha.
      expect(item.saldoNa('03'), lessThan(0));
      expect(item.disponivelNa('03'), -477);
    });

    test('filial sem posição devolve zero', () {
      expect(item.saldoNa('90'), 0);
      expect(item.empenhadoNa('90'), 0);
    });
  });

  group('a lista de OPs acompanha a troca de filial', () {
    test('trocar a filial muda o que fetchOrdensDisponiveis devolve', () async {
      var filial = '04';
      final repo = FlowOpRepository(
        ProductionFlowStore(catalog: TestCatalog()),
        catalog: TestCatalog(),
        protheusOrders: testProtheusRepository([
          testOrder(numero: '015961'),
          testOrder(numero: '015962'),
          testOrderNaFilial03(numero: '039736'),
        ]),
        // Lê a cada chamada, como o app faz com a FilialStore.
        filial: () => filial,
      );

      final naQuatro = await repo.fetchOrdensDisponiveis();
      expect(naQuatro.map((o) => o.numeroLegivel), [
        '015961-01-001',
        '015962-01-001',
      ]);

      filial = '03';
      final naTres = await repo.fetchOrdensDisponiveis();

      // O ponto do teste: sem recriar o repositório, a lista mudou.
      expect(naTres.map((o) => o.numeroLegivel), ['039736-01-001']);
    });

    test('adotar OP de outra filial é recusado', () async {
      final repo = FlowOpRepository(
        ProductionFlowStore(catalog: TestCatalog()),
        catalog: TestCatalog(),
        protheusOrders: testProtheusRepository([
          testOrderNaFilial03(numero: '039736'),
        ]),
        filial: () => '04',
      );

      // A OP existe e está em aberto — só que na filial 03. Adotar da 04 tem de
      // falhar alto, não trazer a OP da outra filial para o fluxo.
      expect(
        () => repo.adotarOrdem(
          const AdocaoOrdemDTO(numero: '03973601001', responsavel: 'Vera'),
        ),
        throwsArgumentError,
      );
    });
  });
}
