import 'package:postgres/postgres.dart';
import 'package:vetti_flow_1_0/data/models/warehouse_request.dart';
import 'package:vetti_flow_1_0/data/repositories/postgres_settings.dart';

abstract class WarehouseRequestDatabase {
  Future<List<WarehouseConfirmationRequest>> loadRequests();
  Future<void> saveRequest(WarehouseConfirmationRequest request);
}

class EmptyWarehouseRequestDatabase implements WarehouseRequestDatabase {
  const EmptyWarehouseRequestDatabase();

  @override
  Future<List<WarehouseConfirmationRequest>> loadRequests() async => const [];

  @override
  Future<void> saveRequest(WarehouseConfirmationRequest request) async {}
}

class PostgresWarehouseRequestDatabase implements WarehouseRequestDatabase {
  PostgresWarehouseRequestDatabase({
    this.host = PostgresSettings.defaultHost,
    this.port = PostgresSettings.defaultPort,
    this.database = PostgresSettings.defaultDatabase,
    this.username = PostgresSettings.defaultUsername,
    this.password = PostgresSettings.defaultPassword,
  });

  final String host;
  final int port;
  final String database;
  final String username;
  final String password;

  Connection? _connection;
  var _schemaReady = false;

  @override
  Future<List<WarehouseConfirmationRequest>> loadRequests() async {
    final conn = await _open();
    await _ensureSchema(conn);
    final rows = await conn.execute('''
      SELECT *
      FROM vettiflow.warehouse_requests
      ORDER BY created_at DESC
    ''', timeout: const Duration(seconds: 8));
    return rows.map((row) => _requestFrom(row.toColumnMap())).toList();
  }

  @override
  Future<void> saveRequest(WarehouseConfirmationRequest request) async {
    final conn = await _open();
    await _ensureSchema(conn);
    await conn.execute(
      Sql.named('''
        INSERT INTO vettiflow.warehouse_requests (
          id,
          order_number,
          product_code,
          product_name,
          component_code,
          component_description,
          quantity,
          filial,
          order_warehouse,
          requested_warehouse,
          requested_by,
          status,
          response_by,
          response_pin_hash,
          response_note,
          manual,
          created_at,
          updated_at
        )
        VALUES (
          @id,
          @order_number,
          @product_code,
          @product_name,
          @component_code,
          @component_description,
          @quantity,
          @filial,
          @order_warehouse,
          @requested_warehouse,
          @requested_by,
          @status,
          @response_by,
          @response_pin_hash,
          @response_note,
          @manual,
          @created_at,
          @updated_at
        )
        ON CONFLICT (id) DO UPDATE SET
          status = EXCLUDED.status,
          response_by = EXCLUDED.response_by,
          response_pin_hash = EXCLUDED.response_pin_hash,
          response_note = EXCLUDED.response_note,
          updated_at = EXCLUDED.updated_at
      '''),
      parameters: {
        'id': request.id,
        'order_number': request.orderNumber,
        'product_code': request.productCode,
        'product_name': request.productName,
        'component_code': request.componentCode,
        'component_description': request.componentDescription,
        'quantity': request.quantity,
        'filial': request.filial,
        'order_warehouse': request.orderWarehouse,
        'requested_warehouse': request.requestedWarehouse,
        'requested_by': request.requestedBy,
        'status': request.status.name,
        'response_by': request.responseBy,
        'response_pin_hash': request.responsePin,
        'response_note': request.responseNote,
        'manual': request.manual,
        'created_at': request.createdAt,
        'updated_at': request.updatedAt,
      },
      timeout: const Duration(seconds: 8),
    );
  }

  Future<void> _ensureSchema(Connection conn) async {
    if (_schemaReady) return;
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS vettiflow.warehouse_requests (
        id text PRIMARY KEY,
        order_number text NOT NULL,
        product_code text NOT NULL DEFAULT '',
        product_name text NOT NULL DEFAULT '',
        component_code text NOT NULL DEFAULT '',
        component_description text NOT NULL DEFAULT '',
        quantity integer NOT NULL CHECK (quantity >= 0),
        filial text NOT NULL DEFAULT '04',
        order_warehouse text NOT NULL DEFAULT '',
        requested_warehouse text NOT NULL DEFAULT '',
        requested_by text NOT NULL DEFAULT '',
        status text NOT NULL DEFAULT 'pending',
        response_by text,
        response_pin_hash text,
        response_note text,
        manual boolean NOT NULL DEFAULT false,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now()
      )
    ''', timeout: const Duration(seconds: 8));
    await conn.execute('''
      CREATE INDEX IF NOT EXISTS idx_warehouse_requests_area
        ON vettiflow.warehouse_requests (requested_warehouse, status)
    ''', timeout: const Duration(seconds: 8));
    await conn.execute('''
      CREATE INDEX IF NOT EXISTS idx_warehouse_requests_order
        ON vettiflow.warehouse_requests (order_number)
    ''', timeout: const Duration(seconds: 8));
    _schemaReady = true;
  }

  WarehouseConfirmationRequest _requestFrom(Map<String, dynamic> data) {
    return WarehouseConfirmationRequest(
      id: _text(data['id']),
      orderNumber: _text(data['order_number']),
      productCode: _text(data['product_code']),
      productName: _text(data['product_name']),
      componentCode: _text(data['component_code']),
      componentDescription: _text(data['component_description']),
      quantity: _int(data['quantity']),
      filial: _text(data['filial'], fallback: '04'),
      orderWarehouse: _text(data['order_warehouse']),
      requestedWarehouse: _text(data['requested_warehouse']),
      requestedBy: _text(data['requested_by']),
      status: WarehouseRequestStatus.values.firstWhere(
        (status) => status.name == _text(data['status']),
        orElse: () => WarehouseRequestStatus.pending,
      ),
      responseBy: _nullableText(data['response_by']),
      responsePin: _nullableText(data['response_pin_hash']),
      responseNote: _nullableText(data['response_note']),
      manual: data['manual'] == true,
      createdAt: _date(data['created_at']) ?? DateTime.now(),
      updatedAt: _date(data['updated_at']) ?? DateTime.now(),
    );
  }

  Future<Connection> _open() async {
    final current = _connection;
    if (current != null && current.isOpen) return current;
    final conn = await Connection.open(
      Endpoint(
        host: host,
        port: port,
        database: database,
        username: username,
        password: password,
      ),
      settings: const ConnectionSettings(
        applicationName: 'vettiflow-warehouse-requests',
        sslMode: SslMode.disable,
        connectTimeout: Duration(seconds: 4),
        queryTimeout: Duration(seconds: 8),
      ),
    );
    _connection = conn;
    return conn;
  }

  String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  int _int(Object? value) {
    if (value is num) return value.round();
    return num.tryParse(value?.toString() ?? '')?.round() ?? 0;
  }

  DateTime? _date(Object? value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }
}
