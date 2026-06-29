/// Etapa de trabalho do operador — define pra qual tela ele é direcionado.
enum WorkStage {
  dashboard('Dashboard', '/dashboard'),
  firmware('Gravacao', '/firmware'),
  soldering('Soldagem', '/soldagem'),
  testing('Teste', '/teste'),
  expedition('Expedicao', '/expedicao'),
  warehouse('Almoxarifado', '/almoxarifado'),
  support('Suporte', '/suporte'),
  tv('VettiFlow TV', '/tv');

  const WorkStage(this.label, this.route);

  final String label;
  final String route;
}

class Operator {
  const Operator({
    required this.name,
    required this.username,
    required this.password,
    required this.pin,
    required this.stage,
  });

  final String name;
  final String username;
  final String password;
  final String pin;
  final WorkStage stage;

  static const all = [
    Operator(
      name: 'Marina',
      username: 'marina',
      password: '0000',
      pin: '0000',
      stage: WorkStage.dashboard,
    ),
    Operator(
      name: 'Fernando',
      username: 'fernando',
      password: '5643',
      pin: '5643',
      stage: WorkStage.firmware,
    ),
    Operator(
      name: 'Carlos',
      username: 'carlos',
      password: '1234',
      pin: '1234',
      stage: WorkStage.soldering,
    ),
    Operator(
      name: 'Ana',
      username: 'ana',
      password: '7890',
      pin: '7890',
      stage: WorkStage.testing,
    ),
    Operator(
      name: 'Ricardo',
      username: 'ricardo',
      password: '4321',
      pin: '4321',
      stage: WorkStage.expedition,
    ),
    Operator(
      name: 'Julia',
      username: 'julia',
      password: '9999',
      pin: '9999',
      stage: WorkStage.warehouse,
    ),
    Operator(
      name: 'Pedro',
      username: 'pedro',
      password: '1111',
      pin: '1111',
      stage: WorkStage.support,
    ),
    Operator(
      name: 'VettiFlow TV',
      username: 'tv',
      password: '2026',
      pin: '2026',
      stage: WorkStage.tv,
    ),
  ];

  /// Busca por username + password. Retorna null se nao encontrar.
  static Operator? authenticate(String username, String password) {
    final u = username.trim().toLowerCase();
    final p = password.trim();
    for (final op in all) {
      if (op.username == u && op.password == p) return op;
    }
    return null;
  }

  /// Busca operador pelo PIN (4 digitos).
  static Operator? findByPin(String pin) {
    for (final op in all) {
      if (op.pin == pin) return op;
    }
    return null;
  }
}
