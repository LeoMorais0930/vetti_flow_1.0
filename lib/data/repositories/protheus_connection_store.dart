import 'package:flutter/foundation.dart';

enum ProtheusConnectionMode { automatic, fastApi, localPostgres }

extension ProtheusConnectionModeLabel on ProtheusConnectionMode {
  String get label {
    switch (this) {
      case ProtheusConnectionMode.automatic:
        return 'Automático';
      case ProtheusConnectionMode.fastApi:
        return 'FastAPI';
      case ProtheusConnectionMode.localPostgres:
        return 'Local Postgres';
    }
  }

  String get description {
    switch (this) {
      case ProtheusConnectionMode.automatic:
        return 'Tenta API e usa local se precisar.';
      case ProtheusConnectionMode.fastApi:
        return 'Força leitura pelo serviço central.';
      case ProtheusConnectionMode.localPostgres:
        return 'Usa o Postgres direto deste PC.';
    }
  }
}

ProtheusConnectionMode protheusConnectionModeFromName(String value) {
  final normalized = value.trim().toLowerCase();
  switch (normalized) {
    case 'api':
    case 'fastapi':
    case 'fast_api':
    case 'fast-api':
      return ProtheusConnectionMode.fastApi;
    case 'local':
    case 'postgres':
    case 'local_postgres':
    case 'local-postgres':
      return ProtheusConnectionMode.localPostgres;
    default:
      return ProtheusConnectionMode.automatic;
  }
}

class ProtheusConnectionStore extends ChangeNotifier {
  ProtheusConnectionStore({
    ProtheusConnectionMode initialMode = ProtheusConnectionMode.automatic,
  }) : _mode = initialMode;

  ProtheusConnectionMode _mode;

  ProtheusConnectionMode get mode => _mode;

  void setMode(ProtheusConnectionMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }
}
