import 'package:flutter/foundation.dart';
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/repositories/pending_mutation_store.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_sync_client.dart';

/// Leva a fila até a API e devolve o resultado para a fila.
///
/// Dois momentos distintos:
/// 1. **Sincronizar** — empurra mutações pendentes para a API, que as
///    **armazena** sem aplicar no Protheus.
/// 2. **Finalizar** — pede à API para aplicar no Protheus as mutações já
///    armazenadas, quando a Responsável confirma o fim da OP.
class MutationSyncService extends ChangeNotifier {
  MutationSyncService({required this.store, required this.client});

  final PendingMutationStore store;
  final ProtheusSyncClient client;

  bool _syncing = false;
  bool _finalizing = false;
  String? _lastError;
  DateTime? _lastSyncAt;

  bool get isSyncing => _syncing;
  bool get isFinalizing => _finalizing;
  String? get lastError => _lastError;
  DateTime? get lastSyncAt => _lastSyncAt;

  /// Empurra tudo que está pendente para a API, que **armazena** sem aplicar.
  ///
  /// Devolve quantas mutações a API aceitou. As recusadas ficam na fila
  /// com o motivo, para o operador corrigir e reenviar — nada some.
  Future<int> sync() async {
    if (_syncing) return 0;

    final lote = store.pending
        .where((m) => m.status != MutationStatus.enviando)
        .toList(growable: false);
    if (lote.isEmpty) return 0;

    _syncing = true;
    _lastError = null;
    notifyListeners();

    for (final m in lote) {
      store.updateStatus(m.id, status: MutationStatus.enviando);
    }

    try {
      final resultados = await client.push(lote);
      final porId = {for (final r in resultados) r.id: r};

      var aceitas = 0;
      for (final m in lote) {
        final r = porId[m.id];
        if (r == null) {
          store.updateStatus(
            m.id,
            status: MutationStatus.pendente,
            erro: 'A API não respondeu sobre esta mutação',
          );
          continue;
        }
        store.updateStatus(
          m.id,
          status: r.status,
          erro: r.erro,
          protheusRef: r.protheusRef,
        );
        if (r.status == MutationStatus.armazenado) aceitas++;
      }

      _lastSyncAt = DateTime.now();
      return aceitas;
    } on SyncUnavailableException catch (e) {
      for (final m in lote) {
        store.updateStatus(m.id, status: MutationStatus.pendente);
      }
      _lastError = e.motivo;
      return 0;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  /// Pede à API para aplicar no Protheus as mutações armazenadas.
  ///
  /// Chamado quando a Responsável finaliza a OP. Devolve quantas foram
  /// aplicadas com sucesso.
  Future<int> finalizar(List<String> ids) async {
    if (_finalizing || ids.isEmpty) return 0;

    _finalizing = true;
    _lastError = null;
    notifyListeners();

    try {
      final resultados = await client.finalizar(ids);
      final porId = {for (final r in resultados) r.id: r};

      var aplicadas = 0;
      for (final id in ids) {
        final r = porId[id];
        if (r == null) continue;
        store.updateStatus(
          id,
          status: r.status,
          erro: r.erro,
          protheusRef: r.protheusRef,
        );
        if (r.status == MutationStatus.enviado) aplicadas++;
      }

      _lastSyncAt = DateTime.now();
      return aplicadas;
    } on SyncUnavailableException catch (e) {
      _lastError = e.motivo;
      return 0;
    } finally {
      _finalizing = false;
      notifyListeners();
    }
  }
}
