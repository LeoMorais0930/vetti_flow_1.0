// Abrir OP tem que chegar ao Protheus — e, quando nao chegar, tem que doer.
//
// Ate 14/08/2026 o `createOrder` gravava so em `vettiflow.production_orders`
// e nunca criava a `AberturaOpMutation`: o `enqueue` do `PendingMutationStore`
// nao tinha um unico call site no app. A OP nascia so no VettiFlow, a SC2/SD4
// ficavam intactas e ninguem era avisado.
import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/mutation_sync_service.dart';
import 'package:vetti_flow_1_0/data/repositories/pending_mutation_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_order_publisher.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_sync_client.dart';

/// Cliente que finge ser a API, para dizer exatamente onde a OP para.
class _FakeSyncClient implements ProtheusSyncClient {
  _FakeSyncClient({
    this.armazenaOk = true,
    this.finalizaOk = true,
    this.quedaNoPush = false,
    this.refDoFinalizar = 'SC2-015964',
  });

  final bool armazenaOk;
  final bool finalizaOk;
  final bool quedaNoPush;
  final String refDoFinalizar;

  final pushed = <List<PendingMutation>>[];
  final finalized = <List<String>>[];

  @override
  Future<List<MutationResult>> push(List<PendingMutation> mutations) async {
    if (quedaNoPush) {
      throw const SyncUnavailableException('conexao recusada na porta 8000');
    }
    pushed.add(mutations);
    return [
      for (final mutation in mutations)
        MutationResult(
          id: mutation.id,
          status: armazenaOk ? MutationStatus.armazenado : MutationStatus.erro,
          erro: armazenaOk ? null : 'produto bloqueado na SB1',
          protheusRef: armazenaOk ? 'vf-ref-1' : null,
        ),
    ];
  }

  @override
  Future<List<MutationResult>> finalizar(List<String> ids) async {
    finalized.add(ids);
    return [
      for (final id in ids)
        MutationResult(
          id: id,
          status: finalizaOk ? MutationStatus.enviado : MutationStatus.erro,
          erro: finalizaOk ? null : 'saldo insuficiente na SB2',
          protheusRef: refDoFinalizar,
        ),
    ];
  }

  @override
  Future<bool> health() async => true;

  @override
  void dispose() {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProductionFlowStore _storeCom(_FakeSyncClient client) {
  final mutations = PendingMutationStore();
  return ProductionFlowStore(
    protheusPublisher: MutationProtheusOrderPublisher(
      mutations: mutations,
      sync: MutationSyncService(store: mutations, client: client),
    ),
  );
}

Future<ProductionOrderFlow> _abrirOp(ProductionFlowStore store) {
  return store.createOrder(
    productCode: '575-0863A',
    productName: 'SUB MEC SMART ALARM MONITORADA',
    quantity: 15,
    priority: 'Media',
    operatorName: 'Tatiane',
    // Com componentes o store exige PIN antes de mexer no Protheus.
    operatorPin: '2001',
    orderWarehouse: '05',
    components: const [
      ProductionComponent(
        code: '550-0845',
        description: 'Componente mecanico',
        quantity: 2,
        stock: 900,
        filial: '04',
        armazem: '05',
        structureSequence: '0001',
      ),
    ],
  );
}

void main() {
  test('abrir OP vai ate o Protheus: armazena e finaliza', () async {
    final client = _FakeSyncClient();
    final store = _storeCom(client);

    final order = await _abrirOp(store);
    final envio = store.protheusOutcome(order.number);

    expect(envio, isNotNull);
    expect(envio!.gravouNoProtheus, isTrue, reason: envio.motivo ?? '');
    expect(envio.protheusRef, 'SC2-015964');
    expect(store.ordersNotInProtheus, isEmpty);

    // As duas fases, nesta ordem.
    expect(client.pushed.single.single, isA<AberturaOpMutation>());
    expect(client.finalized.single.single, envio.mutationId);
  });

  test('o empenho vai junto, multiplicado pela quantidade da OP', () async {
    final client = _FakeSyncClient();
    final store = _storeCom(client);

    await _abrirOp(store);

    final mutation = client.pushed.single.single as AberturaOpMutation;
    expect(mutation.produto, '575-0863A');
    expect(mutation.quantidade, 15);
    expect(mutation.localProducao, '05');
    expect(mutation.filial, '04');

    // 2 por peca x 15 pecas.
    expect(mutation.empenhos.single.produto, '550-0845');
    expect(mutation.empenhos.single.quantidade, 30);
    expect(mutation.empenhos.single.local, '05');
    expect(mutation.empenhos.single.structureSequence, '0001');
  });

  test('API fora do ar: a OP nasce mesmo assim, mas avisa e fica na fila', () async {
    final client = _FakeSyncClient(quedaNoPush: true);
    final store = _storeCom(client);

    final order = await _abrirOp(store);

    // A OP nao pode sumir porque a API caiu.
    expect(store.orders.single.number, order.number);

    final envio = store.protheusOutcome(order.number)!;
    expect(envio.gravouNoProtheus, isFalse);
    expect(envio.motivo, contains('porta 8000'));
    expect(envio.aviso, contains('nao foi enviada ao Protheus'));
    expect(envio.aviso, contains('fila'));
    expect(store.ordersNotInProtheus, [order.number]);
  });

  test('a API recusa a abertura: o motivo dela chega na tela', () async {
    final client = _FakeSyncClient(armazenaOk: false);
    final store = _storeCom(client);

    final order = await _abrirOp(store);
    final envio = store.protheusOutcome(order.number)!;

    expect(envio.gravouNoProtheus, isFalse);
    expect(envio.motivo, 'produto bloqueado na SB1');
    // Recusou na fase 1, entao nem tentou finalizar.
    expect(client.finalized, isEmpty);
  });

  test('armazenou mas nao aplicou: nao pode contar como gravada', () async {
    final client = _FakeSyncClient(finalizaOk: false);
    final store = _storeCom(client);

    final order = await _abrirOp(store);
    final envio = store.protheusOutcome(order.number)!;

    expect(envio.gravouNoProtheus, isFalse);
    expect(envio.motivo, 'saldo insuficiente na SB2');
  });

  test('VF_APPLY=0: a API diz "enviado", mas isso nao e gravado', () async {
    // A API em modo de validacao responde sucesso com `DRY:` no ref. Tratar
    // isso como gravado seria anunciar uma OP que nao existe no Protheus.
    final client = _FakeSyncClient(refDoFinalizar: 'DRY:aberturaOp');
    final store = _storeCom(client);

    final order = await _abrirOp(store);
    final envio = store.protheusOutcome(order.number)!;

    expect(envio.gravouNoProtheus, isFalse);
    expect(envio.simulacao, isTrue);
    expect(envio.aviso, contains('VF_APPLY=0'));
    expect(envio.aviso, contains('SC2/SD4 nao foram'));
    expect(store.ordersNotInProtheus, [order.number]);
  });

  test('sem publicador configurado nao ha tentativa nem aviso falso', () async {
    final store = ProductionFlowStore();

    final order = await _abrirOp(store);

    expect(store.protheusOutcome(order.number), isNull);
    expect(store.ordersNotInProtheus, isEmpty);
  });
}
