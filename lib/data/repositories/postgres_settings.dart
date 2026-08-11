class PostgresSettings {
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
  );

  static const defaultUsername = String.fromEnvironment(
    'VETTIFLOW_PG_USER',
    defaultValue: 'postgres',
  );

  static const defaultPassword = String.fromEnvironment(
    'VETTIFLOW_PG_PASSWORD',
    defaultValue: '093003',
  );
}
