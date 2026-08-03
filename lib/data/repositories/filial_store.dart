import 'package:flutter/foundation.dart';
import 'package:vetti_flow_1_0/data/repositories/local_json_persistence.dart';

/// A filial selecionada para operação.
///
/// Substitui a constante `filialOperacao` que era fixa em `04`. A Vetti
/// operava em duas filiais (03 e 04) e o valor determinava em que tabelas as
/// mutações escreviam e quais OPs apareciam.
///
/// **Desde 03/08/2026 a Vetti só usa a filial `04`** — decisão do gestor, não
/// limitação técnica. `filiaisDisponiveis` tem um único valor e [setFilial]
/// recusa qualquer outro, então o app nunca abre OP nem grava mutação fora
/// dela. O store continua existindo (em vez de virar uma constante espalhada
/// por 30 chamadas) porque toda a leitura já é parametrizada por filial —
/// reabrir a 03 no futuro é ampliar esta lista, não caçar código.
class FilialStore extends ChangeNotifier {
  FilialStore({LocalJsonPersistence? persistence})
    : _persistence =
          persistence ?? const LocalJsonPersistence(_storageKey) {
    final salva = _persistence.read();
    // Uma filial salva de antes da mudança (ex.: '03', de quando a Vetti ainda
    // operava as duas) não é mais válida — cai no padrão em vez de travar o
    // app numa filial que não existe mais para operar.
    if (salva != null &&
        salva.isNotEmpty &&
        filiaisDisponiveis.contains(salva)) {
      _filial = salva;
    }
    _persistence.listen((payload) {
      if (payload != null &&
          payload.isNotEmpty &&
          payload != _filial &&
          filiaisDisponiveis.contains(payload)) {
        _filial = payload;
        notifyListeners();
      }
    });
  }

  static const _storageKey = 'vetti_flow.filial.v1';
  static const filialPadrao = '04';

  /// Só a `04`. Ver a nota da classe — não é lista de UI, é a trava real.
  static const filiaisDisponiveis = ['04'];

  final LocalJsonPersistence _persistence;

  String _filial = filialPadrao;

  String get filial => _filial;

  void setFilial(String filial) {
    if (!filiaisDisponiveis.contains(filial)) {
      throw ArgumentError.value(
        filial,
        'filial',
        'A Vetti só opera a filial 04 no momento',
      );
    }
    if (filial == _filial) return;
    _filial = filial;
    _persistence.write(filial);
    notifyListeners();
  }
}
