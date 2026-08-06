import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_database.dart';

Future<void> main() async {
  _logFile
    ..createSync(recursive: true)
    ..writeAsStringSync('Inicio ${DateTime.now().toIso8601String()}\n');
  final settings = _PostgresSettings.fromEnvironment();
  final timestamp = DateTime.now().microsecondsSinceEpoch.toString();
  final suffix = timestamp.substring(timestamp.length - 6);
  final cancelSuffix = ((int.parse(suffix) + 1) % 1000000).toString().padLeft(
    6,
    '0',
  );
  final completedOrderNumber = 'OP-FLOW-FIN-$suffix';
  final canceledOrderNumber = 'OP-FLOW-CAN-$cancelSuffix';
  final productCode = 'VF-PA-$suffix';
  final componentCode = 'VF-MP-$suffix';
  const filial = '04';
  const sourceWarehouse = '01';
  const productionWarehouse = '05';
  const orderQuantity = 3;
  const componentPerUnit = 2;
  const totalComponentQuantity = orderQuantity * componentPerUnit;
  const componentSeedStock = 100;

  final database = PostgresProductionFlowDatabase(
    host: settings.host,
    port: settings.port,
    database: settings.database,
    username: settings.username,
    password: settings.password,
  );
  final conn = await _open(settings);
  try {
    await _step(
      'seed SB2 $componentCode/$sourceWarehouse',
      () => _seedSb2Balance(
        conn,
        filial: filial,
        code: componentCode,
        warehouse: sourceWarehouse,
        currentStock: componentSeedStock,
      ),
    );

    final catalogItem = ProductionCatalogItem(
      code: productCode,
      name: 'TESTE FLUXO REAL VETTIFLOW',
      defaultQuantity: orderQuantity,
      unit: 'PC',
      components: [
        ProductionComponent(
          code: componentCode,
          description: 'MATERIA PRIMA TESTE VETTIFLOW',
          quantity: componentPerUnit,
          stock: componentSeedStock,
          filial: filial,
          armazem: sourceWarehouse,
          currentStock: componentSeedStock,
          requirementSource: 'SG1',
        ),
        const ProductionComponent(
          code: 'MOD-FLOW',
          description: 'MAO DE OBRA TESTE VETTIFLOW',
          quantity: 1,
          stock: -999,
          filial: filial,
          armazem: productionWarehouse,
          requirementSource: 'SG1',
        ),
      ],
    );

    final createdAt = DateTime.now();
    var completedOrder = _newOrder(
      number: completedOrderNumber,
      productCode: productCode,
      createdAt: createdAt,
    );
    await _step(
      'criar ${completedOrder.number}',
      () =>
          database.saveOrder(completedOrder, catalogItem, eventType: 'created'),
    );
    await _step(
      'validar criacao ${completedOrder.number}',
      () => _expectCreation(
        conn,
        orderNumber: completedOrder.number,
        componentCode: componentCode,
        componentWarehouse: sourceWarehouse,
        expectedCommitment: totalComponentQuantity,
      ),
    );

    completedOrder = await _step(
      'avancar ${completedOrder.number} ate expedicao',
      () => _walkToExpedition(database, completedOrder, catalogItem),
    );
    await _step(
      'validar expedicao ${completedOrder.number}',
      () =>
          _expectStage(conn, completedOrder.number, ProductionStage.expedition),
    );

    completedOrder = completedOrder.copyWith(
      currentStage: ProductionStage.completed,
      status: ProductionRunStatus.completed,
      updatedAt: DateTime.now(),
      closedQuantity: orderQuantity,
      dispatchedQuantity: orderQuantity,
      operatorName: () => 'Tatiane',
      operatorPin: () => '1001',
    );
    await _step(
      'finalizar ${completedOrder.number}',
      () =>
          database.saveOrder(completedOrder, catalogItem, eventType: 'updated'),
    );
    await _step(
      'validar conclusao ${completedOrder.number}',
      () => _expectCompletion(
        conn,
        orderNumber: completedOrder.number,
        productCode: productCode,
        componentCode: componentCode,
        componentWarehouse: sourceWarehouse,
        productWarehouse: productionWarehouse,
        expectedProduced: orderQuantity,
        expectedComponentCurrentStock:
            componentSeedStock - totalComponentQuantity,
      ),
    );

    var canceledOrder = _newOrder(
      number: canceledOrderNumber,
      productCode: productCode,
      createdAt: DateTime.now(),
    );
    await _step(
      'criar ${canceledOrder.number}',
      () =>
          database.saveOrder(canceledOrder, catalogItem, eventType: 'created'),
    );
    canceledOrder = await _step(
      'avancar ${canceledOrder.number} ate expedicao',
      () => _walkToExpedition(database, canceledOrder, catalogItem),
    );
    await _step(
      'cancelar ${canceledOrder.number}',
      () => database.deleteOrder(
        canceledOrder.number,
        order: canceledOrder.copyWith(
          updatedAt: DateTime.now(),
          operatorName: () => 'Vera',
          operatorPin: () => '4003',
        ),
        catalogItem: catalogItem,
        operatorName: 'Vera',
        operatorPin: '4003',
      ),
    );
    await _step(
      'validar cancelamento ${canceledOrder.number}',
      () => _expectCancelation(
        conn,
        orderNumber: canceledOrder.number,
        componentCode: componentCode,
        componentWarehouse: sourceWarehouse,
      ),
    );

    stdout.writeln('OK: fluxo real Postgres validado.');
    stdout.writeln('OP finalizada: ${completedOrder.number}');
    stdout.writeln('OP cancelada: ${canceledOrder.number}');
    stdout.writeln('Produto teste: $productCode');
    stdout.writeln('Componente teste: $componentCode');
  } finally {
    await conn.close();
  }
  exit(0);
}

Future<T> _step<T>(String label, Future<T> Function() action) async {
  _log('... $label');
  final result = await action().timeout(
    const Duration(seconds: 45),
    onTimeout: () => throw TimeoutException(label),
  );
  _log('OK  $label');
  return result;
}

final _logFile = File('.dart_tool/real_flow_check.log');

void _log(String message) {
  final line = '${DateTime.now().toIso8601String()} $message';
  _logFile.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
  stdout.writeln(message);
}

ProductionOrderFlow _newOrder({
  required String number,
  required String productCode,
  required DateTime createdAt,
}) {
  return ProductionOrderFlow(
    number: number,
    productCode: productCode,
    productName: 'TESTE FLUXO REAL VETTIFLOW',
    quantity: 3,
    currentStage: ProductionStage.warehouse,
    status: ProductionRunStatus.waiting,
    priority: 'Media',
    createdAt: createdAt,
    updatedAt: createdAt,
    operatorName: 'Vera',
    operatorPin: '4003',
    responsavel: 'Vera',
    orderWarehouse: '05',
    plannedStages: const [
      ProductionStage.warehouse,
      ProductionStage.smd,
      ProductionStage.firmware,
      ProductionStage.soldering,
      ProductionStage.testing,
      ProductionStage.closing,
      ProductionStage.expedition,
    ],
  );
}

Future<ProductionOrderFlow> _walkToExpedition(
  PostgresProductionFlowDatabase database,
  ProductionOrderFlow order,
  ProductionCatalogItem catalogItem,
) async {
  var current = order;
  final signatures = <ProductionStage, (String, String)>{
    ProductionStage.smd: ('Paula', '3001'),
    ProductionStage.firmware: ('Tatiane', '1001'),
    ProductionStage.soldering: ('Tatiane', '1001'),
    ProductionStage.testing: ('Tatiane', '1001'),
    ProductionStage.closing: ('Tatiane', '1001'),
    ProductionStage.expedition: ('Tamara', '5002'),
  };

  for (final stage in current.plannedStages.skip(1)) {
    final signature = signatures[stage] ?? ('VettiFlow', '');
    current = current.copyWith(
      currentStage: stage,
      status: ProductionRunStatus.waiting,
      updatedAt: DateTime.now(),
      operatorName: () => signature.$1,
      operatorPin: () => signature.$2,
      responsavel: () => signature.$1,
    );
    await database.saveOrder(current, catalogItem, eventType: 'updated');
  }
  return current;
}

Future<void> _seedSb2Balance(
  Connection conn, {
  required String filial,
  required String code,
  required String warehouse,
  required int currentStock,
}) async {
  final payload = {
    'b2_filial': filial,
    'b2_cod': code,
    'b2_local': warehouse,
    'b2_qatu': currentStock,
    'b2_qemp': 0,
    'b2_reserva': 0,
    'b2_qfim': currentStock,
    'd_e_l_e_t_': '',
    'vettiflow_origin': 'real_flow_seed',
  };
  await conn.execute(
    Sql.named('''
      INSERT INTO protheus_raw.sb2_balances (payload)
      VALUES (CAST(@payload AS jsonb))
    '''),
    parameters: {'payload': jsonEncode(payload)},
  );
}

Future<void> _expectCreation(
  Connection conn, {
  required String orderNumber,
  required String componentCode,
  required String componentWarehouse,
  required int expectedCommitment,
}) async {
  final sc2 = await _single(
    conn,
    '''
      SELECT payload
      FROM protheus_raw.sc2_orders
      WHERE payload ->> 'vettiflow_order_number' = @order_number
    ''',
    {'order_number': orderNumber},
  );
  final sc2Payload = sc2['payload'] as Map<String, dynamic>;
  final sc2Columns = sc2Payload.keys
      .where(
        (key) =>
            key.startsWith('c2_') ||
            key == 'd_e_l_e_t_' ||
            key == 'r_e_c_d_e_l_' ||
            key == 'r_e_c_n_o_',
      )
      .length;
  _expect(sc2Columns == 151, 'SC2 deveria ter 151 colunas, veio $sc2Columns.');
  _expect(sc2Payload['c2_status'] == 'N', 'SC2 deveria nascer normal.');

  final sd4Count = await _count(
    conn,
    '''
      SELECT count(*)::int AS total
      FROM protheus_raw.sd4_commitments
      WHERE payload ->> 'vettiflow_order_number' = @order_number
        AND payload ->> 'vettiflow_origin' = 'op_creation'
    ''',
    {'order_number': orderNumber},
  );
  _expect(sd4Count == 2, 'Criacao deveria gerar 2 SD4, veio $sd4Count.');

  final sd3Count = await _count(
    conn,
    '''
      SELECT count(*)::int AS total
      FROM protheus_raw.sd3_movements
      WHERE payload ->> 'vettiflow_order_number' = @order_number
    ''',
    {'order_number': orderNumber},
  );
  _expect(sd3Count == 0, 'Criacao nao deveria gerar SD3, veio $sd3Count.');

  final balance = await _single(
    conn,
    '''
      SELECT b2_qemp
      FROM protheus_raw.sb2_balances
      WHERE b2_cod = @component_code
        AND b2_local = @warehouse
        AND COALESCE(payload ->> 'd_e_l_e_t_', '') <> '*'
      ORDER BY id DESC
      LIMIT 1
    ''',
    {'component_code': componentCode, 'warehouse': componentWarehouse},
  );
  _expect(
    _int(balance['b2_qemp']) == expectedCommitment,
    'SB2 b2_qemp deveria ser $expectedCommitment.',
  );
}

Future<void> _expectStage(
  Connection conn,
  String orderNumber,
  ProductionStage stage,
) async {
  final row = await _single(
    conn,
    '''
      SELECT current_stage
      FROM vettiflow.production_orders
      WHERE number = @order_number
    ''',
    {'order_number': orderNumber},
  );
  _expect(
    _text(row['current_stage']) == stage.name,
    'Etapa deveria ser ${stage.name}, veio ${row['current_stage']}.',
  );
}

Future<void> _expectCompletion(
  Connection conn, {
  required String orderNumber,
  required String productCode,
  required String componentCode,
  required String componentWarehouse,
  required String productWarehouse,
  required int expectedProduced,
  required int expectedComponentCurrentStock,
}) async {
  final sc2 = await _single(
    conn,
    '''
      SELECT payload
      FROM protheus_raw.sc2_orders
      WHERE payload ->> 'vettiflow_order_number' = @order_number
    ''',
    {'order_number': orderNumber},
  );
  final sc2Payload = sc2['payload'] as Map<String, dynamic>;
  _expect(sc2Payload['c2_status'] == 'F', 'SC2 deveria finalizar com F.');
  _expect(
    _int(sc2Payload['c2_quje']) == expectedProduced,
    'SC2 c2_quje errado.',
  );
  _expect(
    (sc2Payload['c2_datrf'] as String?)?.isNotEmpty ?? false,
    'SC2 c2_datrf deveria ser preenchido.',
  );

  final pr0Count = await _count(
    conn,
    '''
      SELECT count(*)::int AS total
      FROM protheus_raw.sd3_movements
      WHERE payload ->> 'vettiflow_order_number' = @order_number
        AND d3_cf = 'PR0'
        AND d3_cod = @product_code
    ''',
    {'order_number': orderNumber, 'product_code': productCode},
  );
  final re1Count = await _count(
    conn,
    '''
      SELECT count(*)::int AS total
      FROM protheus_raw.sd3_movements
      WHERE payload ->> 'vettiflow_order_number' = @order_number
        AND d3_cf = 'RE1'
        AND d3_cod = @component_code
    ''',
    {'order_number': orderNumber, 'component_code': componentCode},
  );
  _expect(pr0Count == 1, 'Conclusao deveria gerar 1 PR0.');
  _expect(re1Count == 1, 'Conclusao deveria gerar 1 RE1 fisico.');

  final modSd3 = await _count(
    conn,
    '''
      SELECT count(*)::int AS total
      FROM protheus_raw.sd3_movements
      WHERE payload ->> 'vettiflow_order_number' = @order_number
        AND d3_cod = 'MOD-FLOW'
    ''',
    {'order_number': orderNumber},
  );
  _expect(modSd3 == 0, 'MOD nao deve gerar SD3 fisica.');

  final productBalance = await _single(
    conn,
    '''
      SELECT b2_qatu
      FROM protheus_raw.sb2_balances
      WHERE b2_cod = @product_code
        AND b2_local = @warehouse
      ORDER BY id DESC
      LIMIT 1
    ''',
    {'product_code': productCode, 'warehouse': productWarehouse},
  );
  _expect(
    _int(productBalance['b2_qatu']) == expectedProduced,
    'Produto acabado deveria entrar no SB2.',
  );

  final componentBalance = await _single(
    conn,
    '''
      SELECT b2_qatu, b2_qemp
      FROM protheus_raw.sb2_balances
      WHERE b2_cod = @component_code
        AND b2_local = @warehouse
      ORDER BY id DESC
      LIMIT 1
    ''',
    {'component_code': componentCode, 'warehouse': componentWarehouse},
  );
  _expect(
    _int(componentBalance['b2_qatu']) == expectedComponentCurrentStock,
    'Componente deveria baixar saldo atual no SB2.',
  );
  _expect(
    _int(componentBalance['b2_qemp']) == 0,
    'Componente deveria zerar empenho.',
  );
}

Future<void> _expectCancelation(
  Connection conn, {
  required String orderNumber,
  required String componentCode,
  required String componentWarehouse,
}) async {
  final orderCount = await _count(
    conn,
    '''
      SELECT count(*)::int AS total
      FROM vettiflow.production_orders
      WHERE number = @order_number
    ''',
    {'order_number': orderNumber},
  );
  _expect(
    orderCount == 0,
    'OP cancelada nao deve permanecer em production_orders.',
  );

  final sc2 = await _single(
    conn,
    '''
      SELECT payload
      FROM protheus_raw.sc2_orders
      WHERE payload ->> 'vettiflow_order_number' = @order_number
    ''',
    {'order_number': orderNumber},
  );
  final sc2Payload = sc2['payload'] as Map<String, dynamic>;
  _expect(
    sc2Payload['c2_status'] == 'C',
    'SC2 cancelada deveria ter status C.',
  );
  _expect(
    sc2Payload['d_e_l_e_t_'] == '*',
    'SC2 cancelada deveria ter delete logico.',
  );

  final cancelSd4 = await _count(
    conn,
    '''
      SELECT count(*)::int AS total
      FROM protheus_raw.sd4_commitments
      WHERE payload ->> 'vettiflow_order_number' = @order_number
        AND payload ->> 'vettiflow_origin' = 'op_cancel'
    ''',
    {'order_number': orderNumber},
  );
  _expect(
    cancelSd4 == 2,
    'Cancelamento deveria gerar auditoria SD4 para MP e MOD.',
  );

  final balance = await _single(
    conn,
    '''
      SELECT b2_qemp
      FROM protheus_raw.sb2_balances
      WHERE b2_cod = @component_code
        AND b2_local = @warehouse
        AND COALESCE(payload ->> 'd_e_l_e_t_', '') <> '*'
      ORDER BY id DESC
      LIMIT 1
    ''',
    {'component_code': componentCode, 'warehouse': componentWarehouse},
  );
  _expect(
    _int(balance['b2_qemp']) == 0,
    'Cancelamento deveria devolver B2_QEMP.',
  );
}

Future<Map<String, dynamic>> _single(
  Connection conn,
  String sql,
  Map<String, dynamic> parameters,
) async {
  final rows = await conn.execute(Sql.named(sql), parameters: parameters);
  _expect(
    rows.length == 1,
    'Consulta deveria retornar 1 linha, veio ${rows.length}.',
  );
  return rows.single.toColumnMap();
}

Future<int> _count(
  Connection conn,
  String sql,
  Map<String, dynamic> parameters,
) async {
  final row = await _single(conn, sql, parameters);
  return _int(row['total']);
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}

int _int(Object? value) {
  if (value is num) return value.round();
  return num.tryParse(value?.toString() ?? '')?.round() ?? 0;
}

String _text(Object? value) {
  if (value is UndecodedBytes) return value.asString.trim();
  return value?.toString().trim() ?? '';
}

Future<Connection> _open(_PostgresSettings settings) {
  return Connection.open(
    Endpoint(
      host: settings.host,
      port: settings.port,
      database: settings.database,
      username: settings.username,
      password: settings.password,
    ),
    settings: const ConnectionSettings(
      applicationName: 'vettiflow-real-flow-check',
      sslMode: SslMode.disable,
      connectTimeout: Duration(seconds: 4),
      queryTimeout: Duration(seconds: 30),
    ),
  );
}

class _PostgresSettings {
  const _PostgresSettings({
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
  });

  final String host;
  final int port;
  final String database;
  final String username;
  final String password;

  factory _PostgresSettings.fromEnvironment() {
    final password = Platform.environment['VETTIFLOW_PG_PASSWORD'] ?? '093003';
    return _PostgresSettings(
      host: Platform.environment['VETTIFLOW_PG_HOST'] ?? 'localhost',
      port:
          int.tryParse(Platform.environment['VETTIFLOW_PG_PORT'] ?? '') ?? 5432,
      database: Platform.environment['VETTIFLOW_PG_DATABASE'] ?? 'vettiflow',
      username: Platform.environment['VETTIFLOW_PG_USER'] ?? 'postgres',
      password: password,
    );
  }
}
