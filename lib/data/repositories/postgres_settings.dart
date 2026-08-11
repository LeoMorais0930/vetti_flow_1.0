/// Conexao com o Postgres local que serve o VettiFlow.
///
/// O nome do banco muda por maquina: aqui o dump do Protheus foi restaurado no
/// banco `vettip12` (schemas `vettiflow` e `protheus_raw` criados por
/// `db/migrations`); na maquina do Leonardo o mesmo conteudo vive em
/// `vettiflow`. Por isso todo valor pode ser sobrescrito em tempo de build:
///
/// ```bash
/// flutter run --dart-define=VETTIFLOW_PG_DATABASE=vettiflow
/// ```
class PostgresSettings {
  const PostgresSettings({
    this.host = defaultHost,
    this.port = defaultPort,
    this.database = defaultDatabase,
    this.username = defaultUsername,
    this.password = defaultPassword,
  });
  const PostgresSettings._();

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
    defaultValue: 'vettiflow',
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
