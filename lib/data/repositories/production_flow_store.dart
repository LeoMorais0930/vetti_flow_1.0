import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_persistence.dart';

class ProductionFlowStore extends ChangeNotifier {
  ProductionFlowStore() {
    if (!_restore(_persistence.read())) {
      _orders.addAll(_seedOrders());
      _persist();
    }
    _persistence.listen((payload) {
      if (_restore(payload)) notifyListeners();
    });
  }

  final _persistence = ProductionFlowPersistence();
  final _orders = <ProductionOrderFlow>[];
  var _nextSequence = 564351;

  static const catalog = [
    ProductionCatalogItem(
      code: 'SMARTALARM32-V6',
      name: 'Central SmartAlarm32 V6.68',
      defaultQuantity: 500,
      components: [
        ProductionComponent(
          code: 'PCI-SA32-V6',
          description: 'Placa principal SmartAlarm32 V6',
          quantity: 1,
          stock: 74,
        ),
        ProductionComponent(
          code: 'MOD-EG912Y',
          description: 'Modulo modem EG912Y',
          quantity: 1,
          stock: 38,
        ),
        ProductionComponent(
          code: 'RF-SI4463',
          description: 'Modulo RF Si4463',
          quantity: 1,
          stock: 112,
        ),
      ],
    ),
    ProductionCatalogItem(
      code: 'CR4',
      name: 'Modulo de 4 zonas com fio',
      defaultQuantity: 3000,
      components: [
        ProductionComponent(
          code: 'PCI-CR4',
          description: 'PCI CR4 v2.1',
          quantity: 1,
          stock: 220,
        ),
        ProductionComponent(
          code: 'CN-004V',
          description: 'Conector barra 4 vias',
          quantity: 4,
          stock: 860,
        ),
      ],
    ),
    ProductionCatalogItem(
      code: 'CR8',
      name: 'Modulo de 8 zonas com fio',
      defaultQuantity: 1200,
      components: [
        ProductionComponent(
          code: 'PCI-CR8',
          description: 'PCI CR8',
          quantity: 1,
          stock: 96,
        ),
        ProductionComponent(
          code: 'CN-008V',
          description: 'Conector barra 8 vias',
          quantity: 4,
          stock: 420,
        ),
      ],
    ),
    ProductionCatalogItem(
      code: 'MAG-CURTO',
      name: 'Sensor magnetico alcance curto',
      defaultQuantity: 900,
      components: [
        ProductionComponent(
          code: 'REED-MAG',
          description: 'Chave reed magnetica',
          quantity: 1,
          stock: 1800,
        ),
        ProductionComponent(
          code: 'BAT-CR2032',
          description: 'Bateria CR2032',
          quantity: 1,
          stock: 2400,
        ),
      ],
    ),
    ProductionCatalogItem(
      code: 'INFRA-LONGO',
      name: 'Sensor infravermelho alcance longo',
      defaultQuantity: 650,
      components: [
        ProductionComponent(
          code: 'PIR-LR',
          description: 'Elemento PIR longo alcance',
          quantity: 1,
          stock: 760,
        ),
        ProductionComponent(
          code: 'LENTE-PIR',
          description: 'Lente fresnel PIR',
          quantity: 1,
          stock: 830,
        ),
      ],
    ),
    ProductionCatalogItem(
      code: 'SIRENE-SF',
      name: 'Sirene sem fio',
      defaultQuantity: 300,
      components: [
        ProductionComponent(
          code: 'BUZZ-12V',
          description: 'Transdutor sonoro 12V',
          quantity: 1,
          stock: 410,
        ),
        ProductionComponent(
          code: 'RF-SI4463',
          description: 'Modulo RF Si4463',
          quantity: 1,
          stock: 112,
        ),
      ],
    ),
    ProductionCatalogItem(
      code: 'SMART-TECLADO',
      name: 'Teclado inteligente',
      defaultQuantity: 450,
      components: [
        ProductionComponent(
          code: 'PCI-TCL-SMART',
          description: 'PCI teclado inteligente',
          quantity: 1,
          stock: 128,
        ),
        ProductionComponent(
          code: 'DISPLAY-OLED',
          description: 'Display OLED compacto',
          quantity: 1,
          stock: 210,
        ),
      ],
    ),
    ProductionCatalogItem(
      code: 'BOTAO-PANICO',
      name: 'Botao de panico',
      defaultQuantity: 800,
      components: [
        ProductionComponent(
          code: 'PCI-PANICO',
          description: 'PCI botao panico RF',
          quantity: 1,
          stock: 330,
        ),
        ProductionComponent(
          code: 'SW-TATIL',
          description: 'Chave tatil reforcada',
          quantity: 1,
          stock: 1900,
        ),
      ],
    ),
  ];

  List<ProductionOrderFlow> get orders => List.unmodifiable(_orders);

  List<ProductionOrderFlow> ordersAtStage(ProductionStage stage) {
    return _orders.where((order) => order.currentStage == stage).toList()
      ..sort(_sortOrders);
  }

  List<ProductionOrderFlow> get activeOrders {
    return _orders.where((order) => !order.isDone).toList()..sort(_sortOrders);
  }

  List<ProductionOrderFlow> get recentCompleted {
    return _orders.where((order) => order.isDone).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  ProductionCatalogItem catalogItem(String code) {
    return catalog.firstWhere(
      (item) => item.code == code,
      orElse: () => catalog.first,
    );
  }

  ProductionOrderFlow createOrder({
    required String productCode,
    required int quantity,
    required String priority,
    required String operatorName,
    String? responsavel,
    String? prazo,
  }) {
    final now = DateTime.now();
    final product = catalogItem(productCode);
    final number = 'OP-${now.year}-${_nextSequence++}';
    final order = ProductionOrderFlow(
      number: number,
      productCode: product.code,
      productName: product.name,
      quantity: quantity,
      currentStage: ProductionStage.warehouse,
      status: ProductionRunStatus.waiting,
      priority: priority,
      createdAt: now,
      updatedAt: now,
      operatorName: operatorName,
      responsavel: responsavel,
      prazo: prazo,
    );
    _orders.insert(0, order);
    _persist();
    notifyListeners();
    return order;
  }

  void startStage(String number, {String? operatorName}) {
    _mutate(number, (order, now) {
      final timings = Map<ProductionStage, ProductionStageTiming>.from(
        order.timings,
      );
      final current =
          timings[order.currentStage] ?? const ProductionStageTiming();
      timings[order.currentStage] = current.pausedAt == null
          ? current.start(now)
          : current.resume(now);
      return order.copyWith(
        status: ProductionRunStatus.active,
        updatedAt: now,
        operatorName: () => operatorName ?? order.operatorName,
        timings: timings,
      );
    });
  }

  void pauseStage(String number) {
    _mutate(number, (order, now) {
      final timings = Map<ProductionStage, ProductionStageTiming>.from(
        order.timings,
      );
      final current =
          timings[order.currentStage] ?? const ProductionStageTiming();
      timings[order.currentStage] = current.pause(now);
      return order.copyWith(
        status: ProductionRunStatus.paused,
        updatedAt: now,
        timings: timings,
      );
    });
  }

  void resetStage(String number) {
    _mutate(number, (order, now) {
      return order.copyWith(
        status: ProductionRunStatus.waiting,
        updatedAt: now,
      );
    });
  }

  /// Volta a OP para a etapa anterior do fluxo (usado pelo dashboard).
  void regressStage(String number) {
    _mutate(number, (order, now) {
      final previous = _previousStage(order.currentStage);
      final timings = Map<ProductionStage, ProductionStageTiming>.from(
        order.timings,
      )..remove(order.currentStage);
      return order.copyWith(
        currentStage: previous,
        status: ProductionRunStatus.waiting,
        updatedAt: now,
        timings: timings,
      );
    });
  }

  /// Remove a OP do fluxo (cancelamento pelo dashboard).
  void cancelOrder(String number) {
    final index = _orders.indexWhere((order) => order.number == number);
    if (index == -1) return;
    _orders.removeAt(index);
    _persist();
    notifyListeners();
  }

  void completeStage(String number, {String? observation}) {
    _mutate(number, (order, now) {
      final timings = Map<ProductionStage, ProductionStageTiming>.from(
        order.timings,
      );
      final current =
          timings[order.currentStage] ??
          const ProductionStageTiming(startedAt: null);
      timings[order.currentStage] = current
          .start(current.startedAt ?? now)
          .complete(now);
      return order.copyWith(
        currentStage: _nextStage(order.currentStage),
        status: ProductionRunStatus.waiting,
        updatedAt: now,
        lastObservation: () {
          final note = observation?.trim();
          return note == null || note.isEmpty ? null : note;
        },
        timings: timings,
      );
    });
  }

  /// Conclui o teste registrando os defeitos encontrados (tipo + quantidade)
  /// e avança a OP para a etapa seguinte.
  void completeTesting(String number, {required List<DefectRecord> defects}) {
    _mutate(number, (order, now) {
      final timings = Map<ProductionStage, ProductionStageTiming>.from(
        order.timings,
      );
      final current =
          timings[order.currentStage] ??
          const ProductionStageTiming(startedAt: null);
      timings[order.currentStage] = current
          .start(current.startedAt ?? now)
          .complete(now);
      return order.copyWith(
        currentStage: _nextStage(order.currentStage),
        status: ProductionRunStatus.waiting,
        updatedAt: now,
        testDefects: defects,
        timings: timings,
      );
    });
  }

  void completeClosing(String number, {required int closedQuantity}) {
    _mutate(number, (order, now) {
      final timings = Map<ProductionStage, ProductionStageTiming>.from(
        order.timings,
      );
      final current =
          timings[order.currentStage] ??
          const ProductionStageTiming(startedAt: null);
      timings[order.currentStage] = current
          .start(current.startedAt ?? now)
          .complete(now);
      final safeClosed = closedQuantity.clamp(0, order.quantity).toInt();
      return order.copyWith(
        currentStage: _nextStage(order.currentStage),
        status: ProductionRunStatus.waiting,
        updatedAt: now,
        closedQuantity: safeClosed,
        timings: timings,
      );
    });
  }

  void completeExpedition(String number, {required int storedQuantity}) {
    _mutate(number, (order, now) {
      final timings = Map<ProductionStage, ProductionStageTiming>.from(
        order.timings,
      );
      final current =
          timings[order.currentStage] ??
          const ProductionStageTiming(startedAt: null);
      timings[order.currentStage] = current
          .start(current.startedAt ?? now)
          .complete(now);
      final safeStored = storedQuantity.clamp(0, order.quantity).toInt();
      return order.copyWith(
        currentStage: safeStored > 0
            ? ProductionStage.storage
            : ProductionStage.completed,
        status: ProductionRunStatus.completed,
        updatedAt: now,
        storedQuantity: safeStored,
        dispatchedQuantity: order.quantity - safeStored,
        timings: timings,
      );
    });
  }

  void dispatchStored(String number, {required int quantity}) {
    _mutate(number, (order, now) {
      if (order.currentStage != ProductionStage.storage) return order;
      final safeQuantity = quantity.clamp(0, order.storedQuantity).toInt();
      if (safeQuantity <= 0) return order;
      final remainingStored = order.storedQuantity - safeQuantity;
      return order.copyWith(
        currentStage: remainingStored == 0
            ? ProductionStage.completed
            : ProductionStage.storage,
        status: ProductionRunStatus.completed,
        updatedAt: now,
        storedQuantity: remainingStored,
        dispatchedQuantity: order.dispatchedQuantity + safeQuantity,
      );
    });
  }

  void _mutate(
    String number,
    ProductionOrderFlow Function(ProductionOrderFlow order, DateTime now)
    update,
  ) {
    final index = _orders.indexWhere((order) => order.number == number);
    if (index == -1) return;
    _orders[index] = update(_orders[index], DateTime.now());
    _persist();
    notifyListeners();
  }

  void _persist() {
    _persistence.write(
      jsonEncode({
        'nextSequence': _nextSequence,
        'orders': _orders.map(_orderToJson).toList(),
      }),
    );
  }

  bool _restore(String? payload) {
    if (payload == null || payload.isEmpty) return false;
    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      final orders = decoded['orders'] as List<dynamic>;
      _orders
        ..clear()
        ..addAll(
          orders.map((order) => _orderFromJson(order as Map<String, dynamic>)),
        );
      _nextSequence =
          (decoded['nextSequence'] as num?)?.toInt() ?? _nextSequence;
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _orderToJson(ProductionOrderFlow order) {
    return {
      'number': order.number,
      'productCode': order.productCode,
      'productName': order.productName,
      'quantity': order.quantity,
      'currentStage': order.currentStage.name,
      'status': order.status.name,
      'priority': order.priority,
      'createdAt': order.createdAt.toIso8601String(),
      'updatedAt': order.updatedAt.toIso8601String(),
      'operatorName': order.operatorName,
      'responsavel': order.responsavel,
      'prazo': order.prazo,
      'closedQuantity': order.closedQuantity,
      'lastObservation': order.lastObservation,
      'storedQuantity': order.storedQuantity,
      'dispatchedQuantity': order.dispatchedQuantity,
      'timings': {
        for (final entry in order.timings.entries)
          entry.key.name: _timingToJson(entry.value),
      },
      'testDefects': order.testDefects.map((d) => d.toJson()).toList(),
    };
  }

  ProductionOrderFlow _orderFromJson(Map<String, dynamic> json) {
    return ProductionOrderFlow(
      number: json['number'] as String,
      productCode: json['productCode'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      quantity: (json['quantity'] as num).toInt(),
      currentStage: _stageFromName(json['currentStage'] as String?),
      status: _statusFromName(json['status'] as String?),
      priority: json['priority'] as String? ?? 'Media',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      operatorName: json['operatorName'] as String?,
      responsavel: json['responsavel'] as String?,
      prazo: json['prazo'] as String?,
      closedQuantity: (json['closedQuantity'] as num?)?.toInt() ?? 0,
      lastObservation: json['lastObservation'] as String?,
      storedQuantity: (json['storedQuantity'] as num?)?.toInt() ?? 0,
      dispatchedQuantity: (json['dispatchedQuantity'] as num?)?.toInt() ?? 0,
      timings: _timingsFromJson(json['timings'] as Map<String, dynamic>?),
      testDefects: (json['testDefects'] as List<dynamic>?)
              ?.map((d) => DefectRecord.fromJson(d as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> _timingToJson(ProductionStageTiming timing) {
    return {
      'startedAt': timing.startedAt?.toIso8601String(),
      'completedAt': timing.completedAt?.toIso8601String(),
      'pausedAt': timing.pausedAt?.toIso8601String(),
      'pausedDurationMs': timing.pausedDuration.inMilliseconds,
    };
  }

  Map<ProductionStage, ProductionStageTiming> _timingsFromJson(
    Map<String, dynamic>? json,
  ) {
    if (json == null) return const {};
    return {
      for (final entry in json.entries)
        _stageFromName(entry.key): _timingFromJson(
          entry.value as Map<String, dynamic>,
        ),
    };
  }

  ProductionStageTiming _timingFromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? value) =>
        value is String ? DateTime.parse(value) : null;
    return ProductionStageTiming(
      startedAt: parseDate(json['startedAt']),
      completedAt: parseDate(json['completedAt']),
      pausedAt: parseDate(json['pausedAt']),
      pausedDuration: Duration(
        milliseconds: (json['pausedDurationMs'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  ProductionStage _stageFromName(String? name) {
    return ProductionStage.values.firstWhere(
      (stage) => stage.name == name,
      orElse: () => ProductionStage.warehouse,
    );
  }

  ProductionRunStatus _statusFromName(String? name) {
    return ProductionRunStatus.values.firstWhere(
      (status) => status.name == name,
      orElse: () => ProductionRunStatus.waiting,
    );
  }

  ProductionStage _nextStage(ProductionStage stage) {
    return switch (stage) {
      ProductionStage.warehouse => ProductionStage.firmware,
      ProductionStage.firmware => ProductionStage.soldering,
      ProductionStage.soldering => ProductionStage.testing,
      ProductionStage.testing => ProductionStage.closing,
      ProductionStage.closing => ProductionStage.expedition,
      ProductionStage.expedition => ProductionStage.completed,
      ProductionStage.storage => ProductionStage.completed,
      ProductionStage.completed => ProductionStage.completed,
    };
  }

  ProductionStage _previousStage(ProductionStage stage) {
    final flow = ProductionStage.productionFlow;
    final index = flow.indexOf(stage);
    if (index == -1) {
      return flow.last; // storage/completed -> volta p/ expedicao
    }
    if (index == 0) return flow.first;
    return flow[index - 1];
  }

  int _sortOrders(ProductionOrderFlow a, ProductionOrderFlow b) {
    if (a.isHighPriority != b.isHighPriority) {
      return a.isHighPriority ? -1 : 1;
    }
    return b.updatedAt.compareTo(a.updatedAt);
  }

  List<ProductionOrderFlow> _seedOrders() {
    final now = DateTime.now();
    return [
      ProductionOrderFlow(
        number: 'OP-00564-345',
        productCode: 'CR4',
        productName: 'Modulo de 4 zonas com fio',
        quantity: 3000,
        currentStage: ProductionStage.firmware,
        status: ProductionRunStatus.waiting,
        priority: 'Alta',
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(minutes: 24)),
      ),
      ProductionOrderFlow(
        number: 'OP-00564-348',
        productCode: 'SMARTALARM32-V6',
        productName: 'Central SmartAlarm32 V6.68',
        quantity: 500,
        currentStage: ProductionStage.soldering,
        status: ProductionRunStatus.active,
        priority: 'Media',
        createdAt: now.subtract(const Duration(hours: 4)),
        updatedAt: now.subtract(const Duration(minutes: 8)),
        timings: {
          ProductionStage.soldering: ProductionStageTiming(
            startedAt: now.subtract(const Duration(minutes: 18)),
          ),
        },
      ),
      ProductionOrderFlow(
        number: 'OP-00564-350',
        productCode: 'INFRA-LONGO',
        productName: 'Sensor infravermelho alcance longo',
        quantity: 650,
        currentStage: ProductionStage.testing,
        status: ProductionRunStatus.paused,
        priority: 'Baixa',
        createdAt: now.subtract(const Duration(hours: 5)),
        updatedAt: now.subtract(const Duration(minutes: 4)),
        timings: {
          ProductionStage.testing: ProductionStageTiming(
            startedAt: now.subtract(const Duration(minutes: 35)),
            pausedAt: now.subtract(const Duration(minutes: 4)),
          ),
        },
      ),
      ProductionOrderFlow(
        number: 'OP-00564-351',
        productCode: 'SMART-TECLADO',
        productName: 'Teclado inteligente',
        quantity: 450,
        currentStage: ProductionStage.closing,
        status: ProductionRunStatus.waiting,
        priority: 'Media',
        createdAt: now.subtract(const Duration(hours: 5)),
        updatedAt: now.subtract(const Duration(minutes: 6)),
      ),
      ProductionOrderFlow(
        number: 'OP-00564-352',
        productCode: 'SIRENE-SF',
        productName: 'Sirene sem fio',
        quantity: 300,
        currentStage: ProductionStage.expedition,
        status: ProductionRunStatus.waiting,
        priority: 'Media',
        createdAt: now.subtract(const Duration(hours: 6)),
        updatedAt: now.subtract(const Duration(minutes: 2)),
      ),
      ProductionOrderFlow(
        number: 'OP-00563-992',
        productCode: 'MAG-CURTO',
        productName: 'Sensor magnetico alcance curto',
        quantity: 900,
        currentStage: ProductionStage.storage,
        status: ProductionRunStatus.completed,
        priority: 'Baixa',
        createdAt: now.subtract(const Duration(hours: 8)),
        updatedAt: now.subtract(const Duration(minutes: 30)),
        storedQuantity: 180,
        dispatchedQuantity: 720,
      ),
    ];
  }
}
