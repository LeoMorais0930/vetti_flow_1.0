/// Conexao com o Postgres local que serve o VettiFlow.
///
/// O nome do banco local padronizado e `vettip12`, igual ao ambiente do
/// Vitor/macOS, com schemas `vettiflow` e `protheus_raw`.
///
/// ```bash
/// flutter run --dart-define=VETTIFLOW_PG_DATABASE=vettip12
/// ```
class PostgresSettings {
  const PostgresSettings({
    this.host = defaultHost,
    this.port = defaultPort,
    this.database = defaultDatabase,
    this.username = defaultUsername,
    this.password = defaultPassword,
  });

  static const defaultHost = String.fromEnvironment(
    'VETTIFLOW_PG_HOST',
    defaultValue: 'localhost',
  );

  static const defaultPort = int.fromEnvironment(
    'VETTIFLOW_PG_PORT',
    defaultValue: 5432,
  );

  static const defaultDatabase = String.fromEnvironment(
    'VETTIFLOW_PG_DATABASE',
    defaultValue: 'vettip12',
  );

  static const defaultUsername = String.fromEnvironment(
    'VETTIFLOW_PG_USER',
    defaultValue: 'postgres',
  );

  static const defaultPassword = String.fromEnvironment(
    'VETTIFLOW_PG_PASSWORD',
    defaultValue: '093003',
  );

  final String host;
  final int port;
  final String database;
  final String username;
  final String password;
}
