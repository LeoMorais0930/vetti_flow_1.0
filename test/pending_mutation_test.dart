import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/models/protheus_empenho.dart';
import 'package:vetti_flow_1_0/data/models/warehouse.dart';
import 'package:vetti_flow_1_0/data/repositories/local_json_persistence.dart';
import 'package:vetti_flow_1_0/data/repositories/pending_mutation_store.dart';

/// Persistência de mentira que guarda em memória, para exercitar o ciclo
/// gravar/reler sem depender de `localStorage`.
class _MemoryPersistence implements LocalJsonPersistence {
  _MemoryPersistence([this.payload]);

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

const _op = '01596101001';

EmpenhoMutation _empenho({
  required EmpenhoOperacao operacao,
  required String produto,
  required String local,
  double quantidade = 0,
  double? quantidadeAnterior,
  String? localAnterior,
  String id = 'm1',
  DateTime? criadoEm,
}) => EmpenhoMutation(
  id: id,
  filial: '04',
  criadoEm: criadoEm ?? DateTime(2026, 7, 31),
  autor: 'Bryan',
  op: _op,
  operacao: operacao,
  produto: produto,
  produtoDescricao: produto,
  local: local,
  quantidade: quantidade,
  quantidadeAnterior: quantidadeAnterior,
  localAnterior: localAnterior,
);

/// Retrato de SD4 como o Protheus entrega.
List<ProtheusEmpenho> _base() => const [
  ProtheusEmpenho(
    filial: '04',
    op: _op,
    produto: '200-052',
    local: '01',
    quantidade: 500,
  ),
  ProtheusEmpenho(
    filial: '04',
    op: _op,
    produto: '575-0863',
    local: '03',
    quantidade: 500,
  ),
];

void main() {
  group('fila de mutações', () {
    test('enfileirar gera id único e deixa a mutação pendente', () {
      final store = PendingMutationStore(persistence: _MemoryPersistence());

      final a = store.enqueue(
        (id, agora) => _empenho(
          id: id,
          criadoEm: agora,
          operacao: EmpenhoOperacao.alterar,
          produto: '200-052',
          local: '01',
          quantidade: 600,
        ),
      );
      final b = store.enqueue(
        (id, agora) => _empenho(
          id: id,
          criadoEm: agora,
          operacao: EmpenhoOperacao.alterar,
          produto: '575-0863',
          local: '03',
          quantidade: 400,
        ),
      );

      expect(a.id, isNot(b.id));
      expect(store.pendingCount, 2);
      expect(store.hasPending, isTrue);
    });

    test('o que já foi enviado não pode ser descartado', () {
      final store = PendingMutationStore(persistence: _MemoryPersistence());
      final m = store.enqueue(
        (id, agora) => _empenho(
          id: id,
          criadoEm: agora,
          operacao: EmpenhoOperacao.alterar,
          produto: '200-052',
          local: '01',
          quantidade: 600,
        ),
      );

      store.updateStatus(
        m.id,
        status: MutationStatus.enviado,
        protheusRef: 'SD4-99',
      );

      // Apagar algo que o Protheus já aplicou só perderia o rastro.
      expect(store.discard(m.id), isFalse);
      expect(store.all, hasLength(1));
    });

    test('erro continua pendente: recusado não é aplicado', () {
      final store = PendingMutationStore(persistence: _MemoryPersistence());
      final m = store.enqueue(
        (id, agora) => _empenho(
          id: id,
          criadoEm: agora,
          operacao: EmpenhoOperacao.alterar,
          produto: '200-052',
          local: '01',
          quantidade: 600,
        ),
      );

      store.updateStatus(
        m.id,
        status: MutationStatus.erro,
        erro: 'saldo insuficiente',
      );

      expect(store.pendingCount, 1);
      expect(store.pending.single.erro, 'saldo insuficiente');
    });

    test('clearSent leva só o confirmado', () {
      final store = PendingMutationStore(persistence: _MemoryPersistence());
      final enviada = store.enqueue(
        (id, agora) => _empenho(
          id: id,
          criadoEm: agora,
          operacao: EmpenhoOperacao.alterar,
          produto: '200-052',
          local: '01',
          quantidade: 600,
        ),
      );
      store.enqueue(
        (id, agora) => _empenho(
          id: id,
          criadoEm: agora,
          operacao: EmpenhoOperacao.alterar,
          produto: '575-0863',
          local: '03',
          quantidade: 400,
        ),
      );
      store.updateStatus(enviada.id, status: MutationStatus.enviado);

      expect(store.clearSent(), 1);
      expect(store.all, hasLength(1));
      expect(store.pendingCount, 1);
    });
  });

  group('persistência da fila', () {
    test('sobrevive à ida e volta em JSON', () {
      final memoria = _MemoryPersistence();
      final store = PendingMutationStore(persistence: memoria);

      store.enqueue(
        (id, agora) => AberturaOpMutation(
          id: id,
          filial: '04',
          criadoEm: agora,
          autor: 'Bryan',
          produto: '730-0863',
          produtoDescricao: 'SMART CENTRAL VETTI',
          quantidade: 250,
          localProducao: '01',
          previsao: '15/08/2026',
          empenhos: const [
            EmpenhoLinha(
              produto: '200-052',
              descricao: 'TAMPA SUPERIOR',
              quantidade: 250,
              local: '01',
            ),
          ],
        ),
      );
      store.enqueue(
        (id, agora) => TransferenciaMutation(
          id: id,
          filial: '04',
          criadoEm: agora,
          autor: 'Bryan',
          produto: '200-052',
          produtoDescricao: 'TAMPA SUPERIOR',
          quantidade: 120,
          localOrigem: '01',
          localDestino: '05',
          op: _op,
        ),
      );

      final relido = PendingMutationStore(
        persistence: _MemoryPersistence(memoria.payload),
      );

      expect(relido.all, hasLength(2));
      final abertura = relido.all.whereType<AberturaOpMutation>().single;
      expect(abertura.produto, '730-0863');
      expect(abertura.quantidade, 250);
      expect(abertura.empenhos.single.produto, '200-052');
      final transferencia = relido.all
          .whereType<TransferenciaMutation>()
          .single;
      expect(transferencia.localOrigem, '01');
      expect(transferencia.localDestino, '05');
      expect(transferencia.quantidade, 120);
    });

    test('payload corrompido não derruba o app', () {
      // A fila importa, mas não a ponto de impedir a produção de trabalhar.
      final store = PendingMutationStore(
        persistence: _MemoryPersistence('{isso não é json}'),
      );

      expect(store.all, isEmpty);
    });
  });

  group('projeção de empenhos', () {
    test('sem nada na fila, vale o retrato do Protheus', () {
      final store = PendingMutationStore(persistence: _MemoryPersistence());

      expect(store.empenhosEfetivos(_op, _base()), hasLength(2));
    });

    test('alterar quantidade aparece por cima do retrato', () {
      final store = PendingMutationStore(persistence: _MemoryPersistence());
      store.enqueue(
        (id, agora) => _empenho(
          id: id,
          criadoEm: agora,
          operacao: EmpenhoOperacao.alterar,
          produto: '200-052',
          local: '01',
          quantidade: 800,
          quantidadeAnterior: 500,
        ),
      );

      final efetivo = store.empenhosEfetivos(_op, _base());

      expect(efetivo.firstWhere((e) => e.produto == '200-052').quantidade, 800);
      expect(efetivo, hasLength(2));
    });

    test('excluir tira a linha', () {
      final store = PendingMutationStore(persistence: _MemoryPersistence());
      store.enqueue(
        (id, agora) => _empenho(
          id: id,
          criadoEm: agora,
          operacao: EmpenhoOperacao.excluir,
          produto: '575-0863',
          local: '03',
        ),
      );

      final efetivo = store.empenhosEfetivos(_op, _base());

      expect(efetivo, hasLength(1));
      expect(efetivo.single.produto, '200-052');
    });

    test('incluir componente novo acrescenta linha', () {
      final store = PendingMutationStore(persistence: _MemoryPersistence());
      store.enqueue(
        (id, agora) => _empenho(
          id: id,
          criadoEm: agora,
          operacao: EmpenhoOperacao.incluir,
          produto: '100-003',
          local: '01',
          quantidade: 1000,
        ),
      );

      final efetivo = store.empenhosEfetivos(_op, _base());

      expect(efetivo, hasLength(3));
      expect(efetivo.firstWhere((e) => e.produto == '100-003').quantidade, 1000);
    });

    test('trocar o almoxarifado move a linha, não duplica', () {
      final store = PendingMutationStore(persistence: _MemoryPersistence());
      store.enqueue(
        (id, agora) => _empenho(
          id: id,
          criadoEm: agora,
          operacao: EmpenhoOperacao.alterar,
          produto: '200-052',
          local: '05',
          localAnterior: '01',
          quantidade: 500,
        ),
      );

      final efetivo = store.empenhosEfetivos(_op, _base());

      expect(efetivo, hasLength(2));
      expect(efetivo.firstWhere((e) => e.produto == '200-052').local, '05');
    });

    test('mutações se acumulam na ordem em que foram criadas', () {
      final store = PendingMutationStore(persistence: _MemoryPersistence());
      store.enqueue(
        (id, _) => _empenho(
          id: id,
          criadoEm: DateTime(2026, 7, 31, 8),
          operacao: EmpenhoOperacao.alterar,
          produto: '200-052',
          local: '01',
          quantidade: 800,
        ),
      );
      store.enqueue(
        (id, _) => _empenho(
          id: id,
          criadoEm: DateTime(2026, 7, 31, 9),
          operacao: EmpenhoOperacao.alterar,
          produto: '200-052',
          local: '01',
          quantidade: 650,
        ),
      );

      final efetivo = store.empenhosEfetivos(_op, _base());

      expect(efetivo.firstWhere((e) => e.produto == '200-052').quantidade, 650);
    });

    test('o que já foi enviado sai da projeção', () {
      // Depois de confirmado, o efeito passa a vir do próprio Protheus na
      // próxima leitura — aplicar de novo aqui contaria em dobro.
      final store = PendingMutationStore(persistence: _MemoryPersistence());
      final m = store.enqueue(
        (id, agora) => _empenho(
          id: id,
          criadoEm: agora,
          operacao: EmpenhoOperacao.alterar,
          produto: '200-052',
          local: '01',
          quantidade: 800,
        ),
      );
      store.updateStatus(m.id, status: MutationStatus.enviado);

      final efetivo = store.empenhosEfetivos(_op, _base());

      expect(efetivo.firstWhere((e) => e.produto == '200-052').quantidade, 500);
    });
  });

  group('projeção de saldo por armazém', () {
    const base = [
      SaldoArmazem(filial: '04', local: '01', saldo: 1000, empenhado: 200),
      SaldoArmazem(filial: '04', local: '05', saldo: 50, empenhado: 0),
    ];

    TransferenciaMutation transferir(
      String id,
      DateTime agora, {
      required String origem,
      required String destino,
      required double quantidade,
    }) => TransferenciaMutation(
      id: id,
      filial: '04',
      criadoEm: agora,
      autor: 'Bryan',
      produto: '200-052',
      produtoDescricao: 'TAMPA SUPERIOR',
      quantidade: quantidade,
      localOrigem: origem,
      localDestino: destino,
    );

    test('transferência tira da origem e põe no destino', () {
      final store = PendingMutationStore(persistence: _MemoryPersistence());
      store.enqueue(
        (id, agora) => transferir(
          id,
          agora,
          origem: '01',
          destino: '05',
          quantidade: 300,
        ),
      );

      final efetivo = store.saldosEfetivos('200-052', '04', base);

      expect(efetivo.firstWhere((s) => s.local == '01').saldo, 700);
      expect(efetivo.firstWhere((s) => s.local == '05').saldo, 350);
    });

    test('o empenhado não se move junto com o saldo', () {
      final store = PendingMutationStore(persistence: _MemoryPersistence());
      store.enqueue(
        (id, agora) => transferir(
          id,
          agora,
          origem: '01',
          destino: '05',
          quantidade: 300,
        ),
      );

      final efetivo = store.saldosEfetivos('200-052', '04', base);

      expect(efetivo.firstWhere((s) => s.local == '01').empenhado, 200);
      expect(efetivo.firstWhere((s) => s.local == '05').empenhado, 0);
    });

    test('destino sem posição de estoque aparece com o que entrou', () {
      final store = PendingMutationStore(persistence: _MemoryPersistence());
      store.enqueue(
        (id, agora) => transferir(
          id,
          agora,
          origem: '01',
          destino: '10',
          quantidade: 120,
        ),
      );

      final efetivo = store.saldosEfetivos('200-052', '04', base);

      expect(efetivo.firstWhere((s) => s.local == '10').saldo, 120);
    });

    test('transferência de outro produto não contamina', () {
      final store = PendingMutationStore(persistence: _MemoryPersistence());
      store.enqueue(
        (id, agora) => TransferenciaMutation(
          id: id,
          filial: '04',
          criadoEm: agora,
          autor: 'Bryan',
          produto: '999-999',
          produtoDescricao: 'OUTRO',
          quantidade: 999,
          localOrigem: '01',
          localDestino: '05',
        ),
      );

      final efetivo = store.saldosEfetivos('200-052', '04', base);

      expect(efetivo.firstWhere((s) => s.local == '01').saldo, 1000);
    });
  });

  group('rótulos da fila', () {
    test('alteração mostra de quanto para quanto', () {
      final m = _empenho(
        operacao: EmpenhoOperacao.alterar,
        produto: '200-052',
        local: '01',
        quantidade: 800,
        quantidadeAnterior: 500,
      );

      expect(m.detalhe, contains('500 → 800 un'));
    });

    test('troca de almoxarifado aparece no detalhe', () {
      final m = _empenho(
        operacao: EmpenhoOperacao.alterar,
        produto: '200-052',
        local: '05',
        localAnterior: '01',
        quantidade: 500,
      );

      expect(m.detalhe, contains('almox. 01 → 05'));
    });

    test('quantidade fracionária não é arredondada no rótulo', () {
      final m = _empenho(
        operacao: EmpenhoOperacao.incluir,
        produto: 'MOD08010201005',
        local: '01',
        quantidade: 0.001348,
      );

      expect(m.detalhe, contains('0.001348 un'));
    });
  });
}
