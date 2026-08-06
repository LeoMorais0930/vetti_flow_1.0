import 'package:flutter/foundation.dart';
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/repositories/pending_mutation_store.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_sync_client.dart';

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

  Future<int> sync() async {
    if (_syncing) return 0;

    final batch = store.pending
        .where((mutation) => mutation.status != MutationStatus.enviando)
        .toList(growable: false);
    if (batch.isEmpty) return 0;

    _syncing = true;
    _lastError = null;
    notifyListeners();

    for (final mutation in batch) {
      store.updateStatus(mutation.id, status: MutationStatus.enviando);
    }

    try {
      final results = await client.push(batch);
      final byId = {for (final result in results) result.id: result};

      var accepted = 0;
      for (final mutation in batch) {
        final result = byId[mutation.id];
        if (result == null) {
          store.updateStatus(
            mutation.id,
            status: MutationStatus.pendente,
            erro: 'A API nao respondeu sobre esta mutacao.',
          );
          continue;
        }
        store.updateStatus(
          mutation.id,
          status: result.status,
          erro: result.erro,
          protheusRef: result.protheusRef,
        );
        if (result.status == MutationStatus.armazenado) accepted++;
      }

      _lastSyncAt = DateTime.now();
      return accepted;
    } on SyncUnavailableException catch (error) {
      for (final mutation in batch) {
        store.updateStatus(mutation.id, status: MutationStatus.pendente);
      }
      _lastError = error.motivo;
      return 0;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<int> finalizar(List<String> ids) async {
    if (_finalizing || ids.isEmpty) return 0;

    _finalizing = true;
    _lastError = null;
    notifyListeners();

    try {
      final results = await client.finalizar(ids);
      final byId = {for (final result in results) result.id: result};

      var applied = 0;
      for (final id in ids) {
        final result = byId[id];
        if (result == null) continue;
        store.updateStatus(
          id,
          status: result.status,
          erro: result.erro,
          protheusRef: result.protheusRef,
        );
        if (result.status == MutationStatus.enviado) applied++;
      }

      _lastSyncAt = DateTime.now();
      return applied;
    } on SyncUnavailableException catch (error) {
      _lastError = error.motivo;
      return 0;
    } finally {
      _finalizing = false;
      notifyListeners();
    }
  }
}
