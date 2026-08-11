import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_database.dart';

Future<void> main() async {
  final password = Platform.environment['VETTIFLOW_PG_PASSWORD'];
  if (password == null || password.isEmpty) {
    throw StateError('Defina VETTIFLOW_PG_PASSWORD antes de rodar o check.');
  }

  final now = DateTime.now();
  final orderNumber = 'OP-CHECK-MOV-${now.microsecondsSinceEpoch}';
  const componentCode = 'VETTI-CHECK-MOV';
  const armazem = '01';
  const filial = '04';
  const movementQuantity = 6;

  final database = PostgresProductionFlowDatabase(password: password);
  final order = ProductionOrderFlow(
    number: orderNumber,
    productCode: '730-TESTE',
    productName: 'TESTE MOVIMENTACAO VETTIFLOW',
    quantity: 3,
    currentStage: ProductionStage.warehouse,
    status: ProductionRunStatus.waiting,
    priority: 'Media',
    createdAt: now,
    updatedAt: now,
    responsavel: 'Check',
  );
  const catalogItem = ProductionCatalogItem(
    code: '730-TESTE',
    name: 'TESTE MOVIMENTACAO VETTIFLOW',
    defaultQuantity: 3,
    components: [
      ProductionComponent(
        code: componentCode,
        description: 'COMPONENTE TESTE MOVIMENTACAO VETTIFLOW',
        quantity: 2,
        stock: 999,
        filial: filial,
        armazem: armazem,
        currentStock: 999,
      ),
      ProductionComponent(
        code: 'MOD-CHECK',
        description: 'MAO DE OBRA TESTE',
        quantity: 1,
        stock: -999,
        filial: filial,
        armazem: armazem,
      ),
    ],
  );

  final conn = await _open(password);
  try {
    await database.saveOrder(order, catalogItem, eventType: 'created');

    final sb2 = await conn.execute(
      Sql.named('''
        SELECT b2_qemp
        FROM protheus_raw.sb2_balances
        WHERE b2_filial = @filial
          AND b2_cod = @component_code
          AND b2_local = @armazem
          AND payload ->> 'vettiflow_origin' = 'op_creation'
      '''),
      parameters: {
        'filial': filial,
        'component_code': componentCode,
        'armazem': armazem,
      },
    );
    final sd4 = await _countRows(
      conn,
      'protheus_raw.sd4_commitments',
      orderNumber,
    );
    final sd3 = await _countRows(
      conn,
      'protheus_raw.sd3_movements',
      orderNumber,
    );
    final modSd4 = await conn.execute(
      Sql.named('''
        SELECT count(*)::int AS total
        FROM protheus_raw.sd4_commitments
        WHERE payload ->> 'vettiflow_order_number' = @order_number
          AND d4_cod = 'MOD-CHECK'
      '''),
      parameters: {'order_number': orderNumber},
    );

    final qemp = sb2.isEmpty ? 0 : _int(sb2.single.toColumnMap()['b2_qemp']);
    final modCount = modSd4.single.toColumnMap()['total'] as int;

    if (qemp != movementQuantity) {
      throw StateError(
        'SB2 b2_qemp no armazem $armazem esperado $movementQuantity, veio $qemp.',
      );
    }
    if (sd4 != 2) throw StateError('SD4 esperado 2 registros, veio $sd4.');
    if (sd3 != 0) {
      throw StateError(
        'Criacao de OP nao deve gerar SD3; foram encontrados $sd3 registros.',
      );
    }
    if (modCount != 1) {
      throw StateError('MOD deveria gerar SD4, veio $modCount.');
    }

    stdout.writeln(
      'OK: criacao usou armazem $armazem em SB2/SD4 sem SD3; MOD gera SD4 sem mexer saldo fisico.',
    );
  } finally {
    await _cleanup(conn, orderNumber, componentCode);
    await conn.close();
  }
  exit(0);
}

Future<int> _countRows(
  Connection conn,
  String table,
  String orderNumber,
) async {
  final rows = await conn.execute(
    Sql.named('''
      SELECT count(*)::int AS total
      FROM $table
      WHERE payload ->> 'vettiflow_order_number' = @order_number
    '''),
    parameters: {'order_number': orderNumber},
  );
  return rows.single.toColumnMap()['total'] as int;
}

Future<void> _cleanup(
  Connection conn,
  String orderNumber,
  String componentCode,
) async {
  await conn.runTx((tx) async {
    await tx.execute(
      Sql.named('''
        DELETE FROM protheus_raw.sd4_commitments
        WHERE payload ->> 'vettiflow_order_number' = @order_number
      '''),
      parameters: {'order_number': orderNumber},
    );
    await tx.execute(
      Sql.named('''
        DELETE FROM protheus_raw.sd3_movements
        WHERE payload ->> 'vettiflow_order_number' = @order_number
      '''),
      parameters: {'order_number': orderNumber},
    );
    await tx.execute(
      Sql.named('''
        DELETE FROM protheus_raw.sb2_balances
        WHERE b2_cod = @component_code
          AND payload ->> 'vettiflow_origin' = 'op_creation'
      '''),
      parameters: {'component_code': componentCode},
    );
    await tx.execute(
      Sql.named('''
        DELETE FROM vettiflow.production_orders
        WHERE number = @order_number
      '''),
      parameters: {'order_number': orderNumber},
    );
  });
}

int _int(Object? value) {
  if (value is num) return value.toInt();
  return num.tryParse(value?.toString() ?? '')?.toInt() ?? 0;
}

Future<Connection> _open(String password) {
  return Connection.open(
    Endpoint(
      host: const String.fromEnvironment(
        'VETTIFLOW_PG_HOST',
        defaultValue: 'localhost',
      ),
      port: const int.fromEnvironment('VETTIFLOW_PG_PORT', defaultValue: 5432),
      database: const String.fromEnvironment(
        'VETTIFLOW_PG_DATABASE',
        defaultValue: 'vettip12',
      ),
      username: const String.fromEnvironment(
        'VETTIFLOW_PG_USER',
        defaultValue: 'postgres',
      ),
      password: password,
    ),
    settings: const ConnectionSettings(
      applicationName: 'vettiflow-protheus-movement-check',
      sslMode: SslMode.disable,
      connectTimeout: Duration(seconds: 4),
      queryTimeout: Duration(seconds: 8),
    ),
  );
}
