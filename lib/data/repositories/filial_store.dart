import 'package:flutter/foundation.dart';
import 'package:vetti_flow_1_0/data/repositories/local_json_persistence.dart';

/// A filial selecionada para operação.
///
/// Substitui a constante `filialOperacao` que era fixa em `04`. A Vetti opera
/// em pelo menos duas filiais (03 e 04); qual está ativa determina em que
/// tabelas as mutações vão escrever e quais OPs aparecem.
class FilialStore extends ChangeNotifier {
  FilialStore({LocalJsonPersistence? persistence})
    : _persistence =
          persistence ?? const LocalJsonPersistence(_storageKey) {
    final salva = _persistence.read();
    if (salva != null && salva.isNotEmpty) _filial = salva;
    _persistence.listen((payload) {
      if (payload != null && payload.isNotEmpty && payload != _filial) {
        _filial = payload;
        notifyListeners();
      }
    });
  }

  static const _storageKey = 'vetti_flow.filial.v1';
  static const filialPadrao = '04';
  static const filiaisDisponiveis = ['03', '04'];

  final LocalJsonPersistence _persistence;

  String _filial = filialPadrao;

  String get filial => _filial;

  void setFilial(String filial) {
    if (filial == _filial) return;
    _filial = filial;
    _persistence.write(filial);
    notifyListeners();
  }
}
