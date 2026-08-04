import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/models/protheus_empenho.dart';
import 'package:vetti_flow_1_0/data/models/warehouse.dart';
import 'package:vetti_flow_1_0/data/repositories/local_json_persistence.dart';

/// A fila de alterações que o VettiFlow quer aplicar no Protheus.
///
/// É o cache de que trata a decisão de 31/07/2026: o chão de fábrica pede
/// abertura de OP, mexe em empenho e transfere entre armazéns sem o ERP no
/// ar; tudo fica aqui até a API levar para lá.
///
/// Além de guardar, o store **projeta**: [empenhosEfetivos] e [saldosEfetivos]
/// aplicam o que está na fila por cima do retrato vindo do Protheus, para a
/// tela mostrar o que o operador acabou de pedir em vez do dado velho.
class PendingMutationStore extends ChangeNotifier {
  PendingMutationStore({LocalJsonPersistence? persistence})
    : _persistence = persistence ?? const LocalJsonPersistence(_storageKey) {
    _restore(_persistence.read());
    _persistence.listen((payload) {
      if (_restore(payload)) notifyListeners();
    });
  }

  static const _storageKey = 'vetti_flow.pending_mutations.v1';

  final LocalJsonPersistence _persistence;
  final _mutations = <PendingMutation>[];

  /// Contador para o sufixo do id, para duas mutações criadas no mesmo
  /// milissegundo não colidirem.
  int _sequence = 0;

  List<PendingMutation> get all => List.unmodifiable(_mutations);

  /// O que ainda não chegou à API — pendente ou com erro.
  List<PendingMutation> get pending => _mutations
      .where((m) =>
          m.status != MutationStatus.enviado &&
          m.status != MutationStatus.armazenado)
      .toList(growable: false);

  /// Na API, aguardando a Responsável finalizar a OP.
  List<PendingMutation> get stored => _mutations
      .where((m) => m.status == MutationStatus.armazenado)
      .toList(growable: false);

  /// Aplicado no Protheus — a OP já foi finalizada.
  List<PendingMutation> get sent => _mutations
      .where((m) => m.status == MutationStatus.enviado)
      .toList(growable: false);

  /// O que a fila tem para uma OP específica.
  List<PendingMutation> forOp(String op) => _mutations
      .where(
        (m) => switch (m) {
          EmpenhoMutation() => m.op == op,
          TransferenciaMutation() => m.op == op,
          AberturaOpMutation() => m.protheusRef == op,
          BaixaProducaoMutation() => m.op == op,
        },
      )
      .toList(growable: false);

  bool get hasPending => pending.isNotEmpty;

  int get pendingCount => pending.length;

  int get storedCount => stored.length;

  /// Tudo que ainda não foi aplicado no Protheus (pendente + armazenado).
  int get awaitingCount => pendingCount + storedCount;

  /// Gera um id único para uma mutação nova.
  ///
  /// Vai para a API como chave de idempotência: reenviar não pode duplicar.
  String _nextId() {
    _sequence++;
    return 'vf-${DateTime.now().microsecondsSinceEpoch}-$_sequence';
  }

  /// Coloca uma mutação na fila. Devolve a mutação com id e data preenchidos.
  T enqueue<T extends PendingMutation>(
    T Function(String id, DateTime criadoEm) build,
  ) {
    final mutation = build(_nextId(), DateTime.now());
    _mutations.add(mutation);
    _persist();
    notifyListeners();
    return mutation;
  }

  /// Tira da fila algo que ainda não foi aplicado.
  ///
  /// O que já está `enviado` não sai: o Protheus já sabe, apagar aqui só
  /// perderia o rastro. Devolve `false` nesse caso.
  bool discard(String id) {
    final index = _mutations.indexWhere((m) => m.id == id);
    if (index < 0) return false;
    if (_mutations[index].status == MutationStatus.enviado) return false;
    _mutations.removeAt(index);
    _persist();
    notifyListeners();
    return true;
  }

  /// Limpa o que já foi confirmado pelo Protheus, para a fila não crescer sem
  /// fim. O que está pendente ou com erro fica.
  int clearSent() {
    final before = _mutations.length;
    _mutations.removeWhere((m) => m.status == MutationStatus.enviado);
    if (_mutations.length == before) return 0;
    _persist();
    notifyListeners();
    return before - _mutations.length;
  }

  /// Tira da fila as alterações de empenho ainda não enviadas de uma OP.
  ///
  /// Usado antes de gravar um novo conjunto: a tela de empenhos edita sobre o
  /// retrato do Protheus e regrava o diff inteiro. Sem isto, cada gravação
  /// empilharia mutações sobre as anteriores e a fila viraria um histórico de
  /// rascunhos em vez da intenção final.
  int discardPendingEmpenhos(String op) {
    final before = _mutations.length;
    _mutations.removeWhere(
      (m) =>
          m is EmpenhoMutation &&
          m.op == op &&
          m.status != MutationStatus.enviado,
    );
    if (_mutations.length == before) return 0;
    _persist();
    notifyListeners();
    return before - _mutations.length;
  }

  void updateStatus(
    String id, {
    required MutationStatus status,
    String? erro,
    String? protheusRef,
  }) {
    final index = _mutations.indexWhere((m) => m.id == id);
    if (index < 0) return;
    _mutations[index] = _mutations[index].copyWithStatus(
      status: status,
      erro: erro,
      protheusRef: protheusRef,
    );
    _persist();
    notifyListeners();
  }

  /// Os empenhos de uma OP como ficam **depois** do que está na fila.
  ///
  /// [base] é o retrato vindo do Protheus (SD4). Sobre ele aplica, em ordem de
  /// criação, as mutações ainda não confirmadas. Uma inclusão de componente que
  /// já existe vira alteração — é o que o Protheus faria.
  List<ProtheusEmpenho> empenhosEfetivos(
    String op,
    List<ProtheusEmpenho> base,
  ) {
    final resultado = [...base];
    final mutacoes =
        _mutations
            .whereType<EmpenhoMutation>()
            .where((m) => m.op == op && m.status != MutationStatus.enviado)
            .toList()
          ..sort((a, b) => a.criadoEm.compareTo(b.criadoEm));

    for (final m in mutacoes) {
      // Casa pela chave da linha: mesmo componente saindo de almoxarifado
      // diferente é outra linha na SD4.
      final anterior = m.localAnterior ?? m.local;
      final index = resultado.indexWhere(
        (e) => e.produto == m.produto && e.local == anterior,
      );

      switch (m.operacao) {
        case EmpenhoOperacao.excluir:
          if (index >= 0) resultado.removeAt(index);
        case EmpenhoOperacao.incluir:
        case EmpenhoOperacao.alterar:
          if (index >= 0) {
            resultado[index] = resultado[index].copyWith(
              quantidade: m.quantidade,
              local: m.local,
            );
          } else {
            resultado.add(
              ProtheusEmpenho(
                filial: m.filial,
                op: op,
                produto: m.produto,
                local: m.local,
                quantidade: m.quantidade,
              ),
            );
          }
      }
    }
    return resultado;
  }

  /// O saldo por armazém de um produto depois do que está na fila.
  ///
  /// Projeta as duas coisas que mudam saldo antes de chegar ao Protheus:
  /// transferência move `saldo` entre locais; empenho (de **qualquer** OP,
  /// menos [excluirOp] quando informado) muda `empenhado` no local de destino.
  /// Empenho pendente precisa entrar aqui — senão duas OPs abertas no mesmo
  /// dia podem pedir o mesmo material sem nenhum aviso, porque a reserva só
  /// existiria de verdade depois que a API aplicasse no Protheus.
  ///
  /// [excluirOp] serve para quem está editando os empenhos de uma OP: a
  /// própria fila dela não deve contar como "reservado por outra OP" — quem
  /// soma de volta a reserva real dessa OP é [disponivelPara].
  ///
  /// Um destino que ainda não tem linha na SB2 aparece aqui zerado mais o que
  /// entrou — é exatamente o que o Protheus criaria ao receber a transferência
  /// ou o empenho.
  List<SaldoArmazem> saldosEfetivos(
    String produto,
    String filial,
    List<SaldoArmazem> base, {
    String? excluirOp,
  }) {
    final porLocal = {
      for (final s in base)
        if (s.filial == filial) s.local: s,
    };

    SaldoArmazem linha(String local) =>
        porLocal[local] ??
        SaldoArmazem(filial: filial, local: local, saldo: 0, empenhado: 0);

    void ajustarSaldo(String local, double delta) {
      final atual = linha(local);
      porLocal[local] = SaldoArmazem(
        filial: filial,
        local: local,
        saldo: atual.saldo + delta,
        empenhado: atual.empenhado,
      );
    }

    void ajustarEmpenhado(String local, double delta) {
      final atual = linha(local);
      porLocal[local] = SaldoArmazem(
        filial: filial,
        local: local,
        saldo: atual.saldo,
        empenhado: atual.empenhado + delta,
      );
    }

    final transferencias =
        _mutations
            .whereType<TransferenciaMutation>()
            .where(
              (m) =>
                  m.produto == produto &&
                  m.filial == filial &&
                  m.status != MutationStatus.enviado,
            )
            .toList()
          ..sort((a, b) => a.criadoEm.compareTo(b.criadoEm));

    for (final t in transferencias) {
      ajustarSaldo(t.localOrigem, -t.quantidade);
      ajustarSaldo(t.localDestino, t.quantidade);
    }

    final empenhos =
        _mutations
            .whereType<EmpenhoMutation>()
            .where(
              (m) =>
                  m.produto == produto &&
                  m.filial == filial &&
                  m.status != MutationStatus.enviado &&
                  (excluirOp == null || m.op != excluirOp),
            )
            .toList()
          ..sort((a, b) => a.criadoEm.compareTo(b.criadoEm));

    for (final m in empenhos) {
      switch (m.operacao) {
        case EmpenhoOperacao.excluir:
          ajustarEmpenhado(
            m.localAnterior ?? m.local,
            -(m.quantidadeAnterior ?? 0),
          );
        case EmpenhoOperacao.incluir:
          ajustarEmpenhado(m.local, m.quantidade);
        case EmpenhoOperacao.alterar:
          final anterior = m.localAnterior ?? m.local;
          if (anterior != m.local) {
            ajustarEmpenhado(anterior, -(m.quantidadeAnterior ?? 0));
            ajustarEmpenhado(m.local, m.quantidade);
          } else {
            ajustarEmpenhado(m.local, m.quantidade - (m.quantidadeAnterior ?? 0));
          }
      }
    }

    final saida = porLocal.values.toList()
      ..sort((a, b) => a.local.compareTo(b.local));
    return saida;
  }

  /// O disponível de um produto num almoxarifado, para quem está mexendo na
  /// OP [op].
  ///
  /// O `B2_QEMP` do Protheus já inclui a reserva que a própria OP tem hoje
  /// naquele produto/local — sem somar de volta, o disponível descontaria essa
  /// reserva duas vezes: uma porque já está no `B2_QEMP`, outra porque a tela
  /// compara contra a quantidade que o operador está digitando para a mesma
  /// linha. [baseOp] é o retrato real da SD4 daquela OP (o que [byOp] devolve,
  /// **antes** de qualquer edição em tela ou fila) — é dali que vem o que "já é
  /// dela" hoje de verdade.
  ///
  /// Quando [op] é `null` (abertura de OP nova, que ainda não existe no
  /// Protheus), não há reserva própria para somar de volta — o comportamento
  /// cai no de [saldosEfetivos].
  ///
  /// Devolve `null` quando o produto não tem nenhuma posição na filial e local
  /// pedidos e nenhuma mutação pendente cria uma: sem isso, "não existe esse
  /// armazém para este produto" e "saldo zero de verdade" ficam
  /// indistinguíveis, e o Protheus trata os dois de formas bem diferentes.
  double? disponivelPara({
    required String produto,
    required String filial,
    required String local,
    required List<SaldoArmazem> baseCatalogo,
    String? op,
    List<ProtheusEmpenho> baseOp = const [],
  }) {
    final efetivo = saldosEfetivos(
      produto,
      filial,
      baseCatalogo,
      excluirOp: op,
    );

    SaldoArmazem? linha;
    for (final s in efetivo) {
      if (s.local == local) {
        linha = s;
        break;
      }
    }
    if (linha == null) return null;

    var reservadoPelaPropriaOp = 0.0;
    for (final e in baseOp) {
      if (e.produto == produto && e.local == local) {
        reservadoPelaPropriaOp += e.quantidade;
      }
    }

    return linha.disponivel + reservadoPelaPropriaOp;
  }

  /// O disponível de um produto em **todo** armazém de uma vez, para quem
  /// está mexendo na OP [op] — mesma conta de [disponivelPara], linha a linha
  /// em vez de um armazém por chamada. Serve para mostrar "tem X aqui, Y no
  /// outro armazém" sem repetir [saldosEfetivos] uma vez por armazém.
  ///
  /// Mesma regra de [disponivelPara] para não contar a reserva da própria OP
  /// em dobro: [baseOp] é somado de volta ao `empenhado` de cada local antes
  /// de devolver, porque o `B2_QEMP` do Protheus já inclui essa reserva.
  ///
  /// Quando [op] é `null` (abertura de OP nova), cai no comportamento de
  /// [saldosEfetivos] puro — mesma regra de [disponivelPara].
  List<SaldoArmazem> disponivelPorArmazem({
    required String produto,
    required String filial,
    required List<SaldoArmazem> baseCatalogo,
    String? op,
    List<ProtheusEmpenho> baseOp = const [],
  }) {
    final efetivo = saldosEfetivos(
      produto,
      filial,
      baseCatalogo,
      excluirOp: op,
    );
    if (baseOp.isEmpty) return efetivo;

    final reservadoPorLocal = <String, double>{};
    for (final e in baseOp) {
      if (e.produto != produto) continue;
      reservadoPorLocal[e.local] =
          (reservadoPorLocal[e.local] ?? 0) + e.quantidade;
    }
    if (reservadoPorLocal.isEmpty) return efetivo;

    final porLocal = {for (final s in efetivo) s.local: s};
    for (final local in reservadoPorLocal.keys) {
      porLocal.putIfAbsent(
        local,
        () =>
            SaldoArmazem(filial: filial, local: local, saldo: 0, empenhado: 0),
      );
    }

    return [
      for (final s in porLocal.values)
        SaldoArmazem(
          filial: s.filial,
          local: s.local,
          saldo: s.saldo,
          empenhado: s.empenhado - (reservadoPorLocal[s.local] ?? 0),
        ),
    ]..sort((a, b) => a.local.compareTo(b.local));
  }

  /// O saldo **físico** de um produto em cada armazém — `B2_QATU` puro, sem
  /// descontar `B2_QEMP`.
  ///
  /// Decisão explícita do usuário (03/08/2026): a abertura de OP nova mostra
  /// só o que existe fisicamente no armazém, não o que sobra depois de
  /// descontar o que outras OPs já empenharam. Ainda projeta transferências
  /// pendentes (o material muda de lugar de verdade antes de chegar ao
  /// Protheus — ver [saldosEfetivos]), só não desconta empenho de nenhuma OP.
  ///
  /// **Risco aceito conscientemente:** o número pode mostrar mais material
  /// livre do que realmente sobra, porque o que já foi reservado para outra
  /// OP em aberto não aparece descontado aqui. Quem edita o empenho de uma OP
  /// que já existe continua vendo o disponível de verdade — essa função só
  /// vale para [disponivelPorArmazem]/[disponivelPara], não os substitui.
  List<SaldoArmazem> saldoFisicoPorArmazem(
    String produto,
    String filial,
    List<SaldoArmazem> baseCatalogo,
  ) {
    final efetivo = saldosEfetivos(produto, filial, baseCatalogo);
    return [
      for (final s in efetivo)
        SaldoArmazem(filial: s.filial, local: s.local, saldo: s.saldo, empenhado: 0),
    ];
  }

  /// As OPs pedidas mas ainda não abertas no Protheus.
  ///
  /// Elas não têm número — quem numera é o ERP —, então não entram no fluxo de
  /// etapas; ficam visíveis como solicitação até a confirmação.
  List<AberturaOpMutation> get aberturasPendentes => _mutations
      .whereType<AberturaOpMutation>()
      .where((m) => m.status != MutationStatus.enviado)
      .toList(growable: false);

  void _persist() {
    _persistence.write(
      jsonEncode([for (final m in _mutations) m.toJson()]),
    );
  }

  /// Relê a fila do armazenamento. Devolve `true` se algo mudou.
  ///
  /// Payload corrompido é descartado em silêncio em vez de derrubar o app: a
  /// fila é importante, mas não a ponto de impedir a produção de trabalhar.
  bool _restore(String? payload) {
    if (payload == null || payload.isEmpty) return false;
    try {
      final list = jsonDecode(payload) as List<dynamic>;
      final restored = [
        for (final item in list)
          PendingMutation.fromJson((item as Map).cast<String, dynamic>()),
      ];
      _mutations
        ..clear()
        ..addAll(restored);
      return true;
    } catch (_) {
      return false;
    }
  }
}
