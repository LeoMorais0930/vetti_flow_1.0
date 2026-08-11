import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';
import 'package:vetti_flow_1_0/data/models/protheus_product_lookup.dart';
import 'package:vetti_flow_1_0/data/repositories/api_settings.dart';
import 'package:vetti_flow_1_0/data/repositories/postgres_settings.dart';

abstract class ProtheusProductRepository {
  Future<ProtheusProductLookup?> lookupByCode(String code);
  Future<List<ProtheusProduct>> searchProducts(String query, {int limit = 12});
  Future<List<String>> fetchProductLabels({int limit = 250});
}

class EmptyProtheusProductRepository implements ProtheusProductRepository {
  const EmptyProtheusProductRepository();

  @override
  Future<List<String>> fetchProductLabels({int limit = 250}) async {
    return const [];
  }

  @override
  Future<List<ProtheusProduct>> searchProducts(
    String query, {
    int limit = 12,
  }) async {
    return const [];
  }

  @override
  Future<ProtheusProductLookup?> lookupByCode(String code) async {
    return null;
  }
}

class ApiFirstProtheusProductRepository implements ProtheusProductRepository {
  const ApiFirstProtheusProductRepository({
    required this.primary,
    required this.fallback,
  });

  final ProtheusProductRepository primary;
  final ProtheusProductRepository fallback;

  @override
  Future<List<String>> fetchProductLabels({int limit = 250}) async {
    try {
      return await primary.fetchProductLabels(limit: limit);
    } catch (_) {
      return fallback.fetchProductLabels(limit: limit);
    }
  }

  @override
  Future<ProtheusProductLookup?> lookupByCode(String code) async {
    try {
      return await primary.lookupByCode(code);
    } catch (_) {
      return fallback.lookupByCode(code);
    }
  }

  @override
  Future<List<ProtheusProduct>> searchProducts(
    String query, {
    int limit = 12,
  }) async {
    try {
      return await primary.searchProducts(query, limit: limit);
    } catch (_) {
      return fallback.searchProducts(query, limit: limit);
    }
  }
}

class ApiProtheusProductRepository implements ProtheusProductRepository {
  ApiProtheusProductRepository({
    required String baseUrl,
    http.Client? httpClient,
  }) : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
       _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  static const _timeout = Duration(seconds: 12);

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }

  @override
  Future<List<String>> fetchProductLabels({int limit = 250}) async {
    final products = await searchProducts('', limit: limit);
    return products.map((product) => product.label).toList();
  }

  @override
  Future<ProtheusProductLookup?> lookupByCode(String code) async {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) return null;

    final response = await _http
        .get(
          _uri('/api/v1/produtos/$normalizedCode'),
          headers: ApiSettings.headers(),
        )
        .timeout(_timeout);
    if (response.statusCode == 404) return null;
    _ensureOk(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _lookupFromApi(json);
  }

  @override
  Future<List<ProtheusProduct>> searchProducts(
    String query, {
    int limit = 12,
  }) async {
    final response = await _http
        .get(
          _uri('/api/v1/produtos', {
            'query': query.trim(),
            'limit': limit.toString(),
          }),
          headers: ApiSettings.headers(),
        )
        .timeout(_timeout);
    _ensureOk(response);
    final json = jsonDecode(response.body);
    final items = json is List ? json : const [];
    return items
        .whereType<Map>()
        .map((item) => _productFromApi(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  void _ensureOk(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw StateError(
      'API Protheus HTTP ${response.statusCode}: ${response.body}',
    );
  }

  ProtheusProductLookup _lookupFromApi(Map<String, dynamic> data) {
    return ProtheusProductLookup(
      filial: _text(data['filial'], fallback: '04'),
      armazem: _text(data['armazem']),
      product: _productFromApi(_map(data['product'])),
      components: _list(
        data['components'],
      ).map(_componentFromApi).toList(growable: false),
      smdReleaseOrders: _list(
        data['smdReleaseOrders'],
      ).map(_childOrderFromApi).toList(growable: false),
    );
  }

  ProtheusProduct _productFromApi(Map<String, dynamic> data) {
    return ProtheusProduct(
      filial: _text(data['filial']),
      code: _text(data['code'] ?? data['codigo']),
      description: _text(data['description'] ?? data['descricao']),
      type: _text(data['type'] ?? data['tipo']),
      unit: _text(data['unit'] ?? data['unidade']),
      group: _text(data['group'] ?? data['grupo']),
      screenBlock: _text(data['screenBlock'] ?? data['b1_msblql']),
    );
  }

  ProtheusProductComponent _componentFromApi(Map<String, dynamic> data) {
    return ProtheusProductComponent(
      filial: _text(data['filial']),
      armazem: _text(data['armazem']),
      code: _text(data['code'] ?? data['codigo']),
      description: _text(data['description'] ?? data['descricao']),
      quantityPerUnit: _num(
        data['quantityPerUnit'] ?? data['quantidadePorUnidade'],
      ),
      unit: _text(data['unit'] ?? data['unidade']),
      stockAvailable: _num(data['stockAvailable'] ?? data['saldoDisponivel']),
      currentStock: _num(data['currentStock'] ?? data['saldoAtual']),
      committedQuantity: _num(
        data['committedQuantity'] ?? data['quantidadeEmpenhada'],
      ),
      reservedQuantity: _num(
        data['reservedQuantity'] ?? data['quantidadeReservada'],
      ),
      requirementSource: _text(
        data['requirementSource'] ?? data['origemNecessidade'],
        fallback: 'SG1',
      ),
      sourceOrder: _text(data['sourceOrder'] ?? data['opOrigem']),
      commitmentDate: _text(data['commitmentDate'] ?? data['dataEmpenho']),
      originalQuantity: _num(
        data['originalQuantity'] ?? data['quantidadeOriginal'],
      ),
      commitmentQuantity: _num(
        data['commitmentQuantity'] ?? data['quantidadeEmpenho'],
      ),
      structureSequence: _text(
        data['structureSequence'] ??
            data['sequenciaEstrutura'] ??
            data['structure_sequence'] ??
            data['g1_trt'],
      ),
      warehouseBalances: _list(
        data['warehouseBalances'],
      ).map(_warehouseBalanceFromApi).toList(growable: false),
      childOrders: _list(
        data['childOrders'],
      ).map(_childOrderFromApi).toList(growable: false),
    );
  }

  ProtheusWarehouseBalance _warehouseBalanceFromApi(Map<String, dynamic> data) {
    return ProtheusWarehouseBalance(
      filial: _text(data['filial']),
      armazem: _text(data['armazem']),
      currentStock: _num(data['currentStock'] ?? data['saldoAtual']),
      committedQuantity: _num(
        data['committedQuantity'] ?? data['quantidadeEmpenhada'],
      ),
      reservedQuantity: _num(
        data['reservedQuantity'] ?? data['quantidadeReservada'],
      ),
      availableQuantity: _num(
        data['availableQuantity'] ?? data['saldoDisponivel'],
      ),
    );
  }

  ProtheusChildOrder _childOrderFromApi(Map<String, dynamic> data) {
    return ProtheusChildOrder(
      number: _text(data['number'] ?? data['numero']),
      productCode: _text(data['productCode'] ?? data['produtoCodigo']),
      productDescription: _text(
        data['productDescription'] ?? data['produtoDescricao'],
      ),
      plannedQuantity: _num(
        data['plannedQuantity'] ?? data['quantidadePlanejada'],
      ),
      producedQuantity: _num(
        data['producedQuantity'] ?? data['quantidadeProduzida'],
      ),
      status: _text(data['status']),
    );
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return const {};
  }

  List<Map<String, dynamic>> _list(Object? value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList(growable: false);
    }
    return const [];
  }

  String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  num _num(Object? value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class PostgresProtheusProductRepository implements ProtheusProductRepository {
  static const vtFilial = '04';

  PostgresProtheusProductRepository({
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

  @override
  Future<List<String>> fetchProductLabels({int limit = 250}) async {
    final products = await searchProducts('', limit: limit);
    return products.map((product) => product.label).toList();
  }

  @override
  Future<List<ProtheusProduct>> searchProducts(
    String query, {
    int limit = 12,
  }) async {
    final normalizedQuery = query.trim().toUpperCase();
    final conn = await _open();
    final rows = await conn.execute(
      Sql.named('''
        SELECT
          filial,
          codigo,
          descricao,
          tipo,
          unidade,
          grupo,
          COALESCE(payload ->> 'b1_msblql', payload ->> 'B1_MSBLQL', '') AS b1_msblql
        FROM protheus_raw.vw_sb1_products
        WHERE codigo IS NOT NULL
          AND descricao IS NOT NULL
          AND (filial = @filial OR filial = '')
          AND COALESCE(NULLIF(payload ->> 'b1_msblql', ''), NULLIF(payload ->> 'B1_MSBLQL', ''), '2') <> '1'
          AND (
            @query = ''
            OR codigo ILIKE @pattern
            OR descricao ILIKE @pattern
          )
        ORDER BY
          CASE WHEN codigo = @query THEN 0 ELSE 1 END,
          CASE WHEN codigo ILIKE @prefix THEN 0 ELSE 1 END,
          CASE WHEN codigo LIKE '7%' THEN 0 ELSE 1 END,
          CASE
            WHEN tipo IN ('PA', 'PI') THEN 0
            WHEN tipo IN ('SB', 'SV') THEN 1
            ELSE 2
          END,
          codigo
        LIMIT @limit
      '''),
      parameters: {
        'filial': vtFilial,
        'query': normalizedQuery,
        'pattern': '%$normalizedQuery%',
        'prefix': '$normalizedQuery%',
        'limit': limit,
      },
      timeout: const Duration(seconds: 6),
    );
    return rows.map((row) => _productFrom(row.toColumnMap())).toList();
  }

  @override
  Future<ProtheusProductLookup?> lookupByCode(String code) async {
    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) return null;

    final conn = await _open();
    final productRows = await conn.execute(
      Sql.named('''
        SELECT
          filial,
          codigo,
          descricao,
          tipo,
          unidade,
          grupo,
          COALESCE(payload ->> 'b1_msblql', payload ->> 'B1_MSBLQL', '') AS b1_msblql
        FROM protheus_raw.vw_sb1_products
        WHERE codigo = @code
          AND (filial = @filial OR filial = '')
          AND COALESCE(NULLIF(payload ->> 'b1_msblql', ''), NULLIF(payload ->> 'B1_MSBLQL', ''), '2') <> '1'
        LIMIT 1
      '''),
      parameters: {'code': normalizedCode, 'filial': vtFilial},
      timeout: const Duration(seconds: 6),
    );

    if (productRows.isEmpty) return null;

    final product = _productFrom(productRows.first.toColumnMap());
    final components = await _componentsFor(conn, normalizedCode);
    final smdReleaseOrders = await _smdReleaseOrdersFor(conn, normalizedCode);
    return ProtheusProductLookup(
      filial: vtFilial,
      product: product,
      components: components,
      smdReleaseOrders: smdReleaseOrders,
    );
  }

  Future<List<ProtheusProductComponent>> _componentsFor(
    Connection conn,
    String productCode,
  ) async {
    return _structureComponentsFor(conn, productCode);
  }

  Future<List<ProtheusProductComponent>> _structureComponentsFor(
    Connection conn,
    String productCode,
  ) async {
    final rows = await conn.execute(
      Sql.named('''
        WITH component_orders AS (
          SELECT
            produto_codigo,
            jsonb_agg(
              jsonb_build_object(
                'number', op,
                'product_code', produto_codigo,
                'product_description', produto_descricao,
                'planned_quantity', quantidade_planejada,
                'produced_quantity', quantidade_produzida,
                'status', status_protheus
              )
              ORDER BY emissao_aaaammdd DESC NULLS LAST, op DESC
            ) FILTER (WHERE op IS NOT NULL) AS child_orders
          FROM protheus_raw.vw_sc2_orders
          WHERE filial = @filial
          GROUP BY produto_codigo
        ),
        stock_summary AS (
          SELECT
            produto_codigo,
            sum(saldo_disponivel_estimado) AS stock_available
          FROM protheus_raw.vw_sb2_stock_balances
          WHERE filial = @filial
          GROUP BY produto_codigo
        ),
        stock_balances AS (
          SELECT
            produto_codigo,
            jsonb_agg(
              jsonb_build_object(
                'filial', filial,
                'armazem', armazem,
                'current_stock', saldo_atual,
                'committed_quantity', quantidade_empenhada,
                'reserved_quantity', quantidade_reservada,
                'available_quantity', saldo_disponivel_estimado
              )
              ORDER BY armazem
            ) AS warehouse_balances
          FROM protheus_raw.vw_sb2_stock_balances
          WHERE filial = @filial
          GROUP BY produto_codigo
        )
        SELECT
          s.filial,
          s.componente_codigo,
          s.componente_descricao,
          s.quantidade_por_unidade,
          p.unidade,
          COALESCE(stock_summary.stock_available, 0) AS stock_available,
          COALESCE(stock_balances.warehouse_balances, '[]'::jsonb) AS warehouse_balances,
          COALESCE(component_orders.child_orders, '[]'::jsonb) AS child_orders,
          'SG1' AS requirement_source,
          '' AS source_order,
          '' AS commitment_date,
          0 AS original_quantity,
          0 AS commitment_quantity,
          COALESCE(s.payload ->> 'g1_trt', s.payload ->> 'G1_TRT', '') AS structure_sequence
        FROM protheus_raw.vw_sg1_product_structures AS s
        LEFT JOIN protheus_raw.vw_sb1_products AS p
          ON p.codigo = s.componente_codigo
         AND (p.filial = @filial OR p.filial = '')
        LEFT JOIN stock_summary
          ON stock_summary.produto_codigo = s.componente_codigo
        LEFT JOIN stock_balances
          ON stock_balances.produto_codigo = s.componente_codigo
        LEFT JOIN component_orders
          ON component_orders.produto_codigo = s.componente_codigo
        WHERE s.produto_codigo = @code
          AND (s.filial = @filial OR s.filial = '')
          AND COALESCE(NULLIF(p.payload ->> 'b1_msblql', ''), NULLIF(p.payload ->> 'B1_MSBLQL', ''), '2') <> '1'
        ORDER BY
          COALESCE(NULLIF(s.payload ->> 'g1_trt', ''), NULLIF(s.payload ->> 'G1_TRT', ''), s.componente_codigo),
          s.componente_codigo
      '''),
      parameters: {'code': productCode, 'filial': vtFilial},
      timeout: const Duration(seconds: 8),
    );

    return rows.map((row) => _componentFrom(row.toColumnMap())).toList();
  }

  Future<List<ProtheusChildOrder>> _smdReleaseOrdersFor(
    Connection conn,
    String productCode,
  ) async {
    final rows = await conn.execute(
      Sql.named('''
        WITH RECURSIVE structure_tree AS (
          SELECT
            0 AS nivel,
            p.codigo AS produto_codigo,
            p.codigo AS componente_codigo,
            p.descricao AS componente_descricao
          FROM protheus_raw.vw_sb1_products AS p
          WHERE p.codigo = @code
            AND (p.filial = @filial OR p.filial = '')

          UNION ALL

          SELECT
            structure_tree.nivel + 1,
            s.produto_codigo,
            s.componente_codigo,
            s.componente_descricao
          FROM structure_tree
          JOIN protheus_raw.vw_sg1_product_structures AS s
            ON s.produto_codigo = structure_tree.componente_codigo
           AND (s.filial = @filial OR s.filial = '')
          WHERE structure_tree.nivel < 4
        )
        SELECT DISTINCT ON (o.op)
          o.op AS number,
          o.produto_codigo AS product_code,
          o.produto_descricao AS product_description,
          o.quantidade_planejada AS planned_quantity,
          o.quantidade_produzida AS produced_quantity,
          o.status_protheus AS status,
          o.emissao_aaaammdd
        FROM structure_tree
        JOIN protheus_raw.vw_sc2_orders AS o
          ON o.produto_codigo = structure_tree.componente_codigo
         AND o.filial = @filial
        WHERE structure_tree.componente_codigo LIKE '500-%'
           OR structure_tree.componente_descricao ILIKE '%SMD%'
        ORDER BY o.op, o.emissao_aaaammdd DESC NULLS LAST
        LIMIT 30
      '''),
      parameters: {'code': productCode, 'filial': vtFilial},
      timeout: const Duration(seconds: 8),
    );

    return rows.map((row) => _childOrderFrom(row.toColumnMap())).toList()
      ..sort((a, b) => b.number.compareTo(a.number));
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
        applicationName: 'vettiflow-windows',
        sslMode: SslMode.disable,
        connectTimeout: Duration(seconds: 4),
        queryTimeout: Duration(seconds: 8),
      ),
    );
    _connection = conn;
    return conn;
  }

  ProtheusProduct _productFrom(Map<String, dynamic> data) {
    return ProtheusProduct(
      filial: _text(data['filial']),
      code: _text(data['codigo']),
      description: _text(data['descricao']),
      type: _text(data['tipo']),
      unit: _text(data['unidade']),
      group: _text(data['grupo']),
      screenBlock: _text(data['b1_msblql']),
    );
  }

  ProtheusProductComponent _componentFrom(Map<String, dynamic> data) {
    final childOrders = data['child_orders'];
    final orderList = switch (childOrders) {
      final List value => value,
      final String value => (jsonDecode(value) as List<dynamic>),
      _ => const [],
    };
    final warehouseBalances = data['warehouse_balances'];
    final warehouseList = switch (warehouseBalances) {
      final List value => value,
      final String value => (jsonDecode(value) as List<dynamic>),
      _ => const [],
    };
    final balances = warehouseList
        .whereType<Map>()
        .map((item) => _warehouseBalanceFrom(item.cast<String, dynamic>()))
        .toList();
    final preferredWarehouse = _text(data['armazem']);
    final selectedBalance = ProtheusProductComponent.selectBestWarehouseBalance(
      balances,
      preferredWarehouse,
    );
    return ProtheusProductComponent(
      filial: selectedBalance?.filial ?? _text(data['filial']),
      armazem: selectedBalance?.armazem ?? preferredWarehouse,
      code: _text(data['componente_codigo']),
      description: _text(data['componente_descricao']),
      quantityPerUnit: _num(data['quantidade_por_unidade']),
      unit: _text(data['unidade']),
      stockAvailable:
          selectedBalance?.availableQuantity ?? _num(data['stock_available']),
      currentStock: selectedBalance?.currentStock ?? 0,
      committedQuantity: selectedBalance?.committedQuantity ?? 0,
      reservedQuantity: selectedBalance?.reservedQuantity ?? 0,
      requirementSource: _text(data['requirement_source'], fallback: 'SG1'),
      sourceOrder: _text(data['source_order']),
      commitmentDate: _text(data['commitment_date']),
      originalQuantity: _num(data['original_quantity']),
      commitmentQuantity: _num(data['commitment_quantity']),
      structureSequence: _text(data['structure_sequence']),
      warehouseBalances: balances,
      childOrders: orderList
          .whereType<Map>()
          .map((item) => _childOrderFrom(item.cast<String, dynamic>()))
          .toList(),
    );
  }

  ProtheusWarehouseBalance _warehouseBalanceFrom(Map<String, dynamic> data) {
    return ProtheusWarehouseBalance(
      filial: _text(data['filial']),
      armazem: _text(data['armazem']),
      currentStock: _num(data['current_stock']),
      committedQuantity: _num(data['committed_quantity']),
      reservedQuantity: _num(data['reserved_quantity']),
      availableQuantity: _num(data['available_quantity']),
    );
  }

  ProtheusChildOrder _childOrderFrom(Map<String, dynamic> data) {
    return ProtheusChildOrder(
      number: _text(data['number']),
      productCode: _text(data['product_code']),
      productDescription: _text(data['product_description']),
      plannedQuantity: _num(data['planned_quantity']),
      producedQuantity: _num(data['produced_quantity']),
      status: _text(data['status']),
    );
  }

  String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  num _num(Object? value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }
}
