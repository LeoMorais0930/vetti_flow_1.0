import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/data/repositories/postgres_settings.dart';

void main() {
  test('centraliza os defaults de conexao do Postgres', () {
    expect(PostgresSettings.defaultHost, 'localhost');
    expect(PostgresSettings.defaultPort, 5432);
    expect(PostgresSettings.defaultDatabase, 'vettiflow');
    expect(PostgresSettings.defaultUsername, 'postgres');
    expect(PostgresSettings.defaultPassword, '093003');
  });
}
