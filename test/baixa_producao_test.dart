import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/protheus_empenho.dart';
import 'package:vetti_flow_1_0/data/repositories/empenho_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/flow_op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/local_json_persistence.dart';
import 'package:vetti_flow_1_0/data/repositories/pending_mutation_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';

import 'fixtures.dart';

/// Persistência de mentira, igual à dos outros testes de fila.
class _MemoryPersistence implements LocalJsonPersistence {
  _MemoryPersistence();

  String? payload;

  @override
  String get key => 'teste';

  @override
  String? read() => payload;

  @override
  void write(String value) => payload = value;

  @override
  void listen(void Function(String?) onChange) {}
}

/// Anda a OP até a etapa de fechamento e fecha com [closedQuantity].
///
/// Etapas antes do fechamento avançam sem valor especial — só o fechamento
/// carrega a quantidade que interessa para a baixa.
void _fecharComQuantidade(
  ProductionFlowStore store,
  String numero,
  int closedQuantity,
) {
  while (store.orders.first.currentStage != ProductionStage.closing) {
    store.completeStage(numero);
  }
  store.completeClosing(numero, closedQuantity: closedQuantity);
}

/// A baixa de produção dispara na expedição — o único ponto do fluxo do
/// VettiFlow que corresponde a "produção terminou" no sentido do Protheus.
///
/// Números conferidos na base real (`vettip12`) em 03/08/2026: a OP 015961
/// (filial 04, produto 730-0863, C2_QUANT=500) produziu 82 até agora, e o
/// componente MOD08010201006 (D4_QTDEORI=4.17) consumiu exatamente
/// 82 × 4.17 ÷ 500 = 0.6839.
void main() {
  group('baixa de produção ao expedir', () {
    (FlowOpRepository, PendingMutationStore) montar({
      required ProductionFlowStore store,
      List<ProtheusEmpenho> empenhos = const [],
    }) {
      final pending = PendingMutationStore(persistence: _MemoryPersistence());
      final repo = FlowOpRepository(
        store,
        catalog: TestCatalog(),
        protheusOrders: testProtheusRepository([
          testOrder(numero: '015961', quantidade: 500, localProducao: '10'),
        ]),
        empenhos: AssetEmpenhoRepository(empenhos),
        pendingMutations: pending,
        filial: () => '04',
      );
      return (repo, pending);
    }

    test('consumo proporcional ao empenho real, não à estrutura padrão', () async {
      final store = ProductionFlowStore(catalog: TestCatalog());
      final (repo, pending) = montar(
        store: store,
        empenhos: const [
          ProtheusEmpenho(
            filial: '04',
            op: '01596101001',
            produto: '102-339',
            local: '10',
            quantidade: 418,
            quantidadeOriginal: 500,
          ),
          ProtheusEmpenho(
            filial: '04',
            op: '01596101001',
            produto: 'MOD08010201006',
            local: '10',
            quantidade: 3.49,
            quantidadeOriginal: 4.17,
          ),
        ],
      );

      final order = store.adoptOrder(
        testOrder(numero: '015961', quantidade: 500),
      );
      _fecharComQuantidade(store, order.number, 82);
      await repo.avancarStatus(order.number, quantidadeArmazenada: 0);

      final baixa = pending.all.whereType<BaixaProducaoMutation>().single;
      expect(baixa.op, '01596101001');
      expect(baixa.produto, '730-0863');
      expect(baixa.produtoDescricao, isNotEmpty);
      expect(baixa.quantidadeProduzida, 82);
      expect(baixa.localProducao, '10');
      expect(baixa.filial, '04');
      expect(baixa.componentes, hasLength(2));

      final parafuso = baixa.componentes.firstWhere(
        (c) => c.produto == '102-339',
      );
      // Razão 1:1 (500/500) — consome exatamente o que foi produzido.
      expect(parafuso.quantidade, closeTo(82, 0.001));
      expect(parafuso.local, '10');

      final mod = baixa.componentes.firstWhere(
        (c) => c.produto == 'MOD08010201006',
      );
      expect(mod.quantidade, closeTo(0.6839, 0.001));
    });

    test('linha incluída pela fila, sem D4_QTDEORI, usa a própria quantidade como razão', () async {
      final store = ProductionFlowStore(catalog: TestCatalog());
      // Sem quantidadeOriginal: nunca existiu de verdade na SD4, só foi
      // acrescentada pelo operador na fila.
      final (repo, pending) = montar(
        store: store,
        empenhos: const [
          ProtheusEmpenho(
            filial: '04',
            op: '01596101001',
            produto: '999-999',
            local: '01',
            quantidade: 50,
          ),
        ],
      );

      final order = store.adoptOrder(
        testOrder(numero: '015961', quantidade: 500),
      );
      _fecharComQuantidade(store, order.number, 100);
      await repo.avancarStatus(order.number, quantidadeArmazenada: 0);

      final baixa = pending.all.whereType<BaixaProducaoMutation>().single;
      final linha = baixa.componentes.single;
      // 100 produzidos × (50 ÷ 500) = 10.
      expect(linha.quantidade, closeTo(10, 0.001));
    });

    test('sem quantidade fechada, não enfileira baixa nenhuma', () async {
      final store = ProductionFlowStore(catalog: TestCatalog());
      final (repo, pending) = montar(
        store: store,
        empenhos: const [
          ProtheusEmpenho(
            filial: '04',
            op: '01596101001',
            produto: '102-339',
            local: '10',
            quantidade: 500,
            quantidadeOriginal: 500,
          ),
        ],
      );

      final order = store.adoptOrder(
        testOrder(numero: '015961', quantidade: 500),
      );
      // Anda até a expedição sem passar por completeClosing — closedQuantity
      // fica no zero padrão.
      while (store.orders.first.currentStage != ProductionStage.expedition) {
        store.completeStage(order.number);
      }
      await repo.avancarStatus(order.number, quantidadeArmazenada: 0);

      expect(pending.all.whereType<BaixaProducaoMutation>(), isEmpty);
    });

    test('OP sem empenho carregado não gera baixa (silencioso)', () async {
      final store = ProductionFlowStore(catalog: TestCatalog());
      final (repo, pending) = montar(store: store, empenhos: const []);

      final order = store.adoptOrder(
        testOrder(numero: '015961', quantidade: 500),
      );
      _fecharComQuantidade(store, order.number, 82);
      await repo.avancarStatus(order.number, quantidadeArmazenada: 0);

      expect(pending.all.whereType<BaixaProducaoMutation>(), isEmpty);
    });
  });
}
