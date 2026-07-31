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

  /// O saldo por armazém de um produto depois das transferências na fila.
  ///
  /// Um destino que ainda não tem linha na SB2 aparece aqui zerado mais o que
  /// entrou — é exatamente o que o Protheus criaria ao receber a transferência.
  List<SaldoArmazem> saldosEfetivos(
    String produto,
    String filial,
    List<SaldoArmazem> base,
  ) {
    final porLocal = {
      for (final s in base)
        if (s.filial == filial) s.local: s,
    };

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

    SaldoArmazem linha(String local) =>
        porLocal[local] ??
        SaldoArmazem(filial: filial, local: local, saldo: 0, empenhado: 0);

    for (final t in transferencias) {
      final origem = linha(t.localOrigem);
      final destino = linha(t.localDestino);
      porLocal[t.localOrigem] = SaldoArmazem(
        filial: filial,
        local: t.localOrigem,
        saldo: origem.saldo - t.quantidade,
        empenhado: origem.empenhado,
      );
      porLocal[t.localDestino] = SaldoArmazem(
        filial: filial,
        local: t.localDestino,
        saldo: destino.saldo + t.quantidade,
        empenhado: destino.empenhado,
      );
    }

    final saida = porLocal.values.toList()
      ..sort((a, b) => a.local.compareTo(b.local));
    return saida;
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
