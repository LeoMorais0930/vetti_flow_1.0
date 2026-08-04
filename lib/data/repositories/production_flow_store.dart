import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_database.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_persistence.dart';

class ProductionFlowStore extends ChangeNotifier {
  ProductionFlowStore({
    this.database = const EmptyProductionFlowDatabase(),
    List<ProductionOrderFlow> seedOrders = const [],
  }) {
    if (!_restore(_persistence.read())) {
      _orders.addAll(seedOrders);
      _persist();
    }
    _loadFromDatabase();
    _persistence.listen((payload) {
      if (_restore(payload)) notifyListeners();
    });
  }

  final ProductionFlowDatabase database;
  final _persistence = ProductionFlowPersistence();
  final _orders = <ProductionOrderFlow>[];
  final _catalogOverrides = <String, ProductionCatalogItem>{};
  var _nextSequence = 564351;

  static const catalog = <ProductionCatalogItem>[];

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

  List<ProductionCatalogItem> get catalogItems {
    final items = <String, ProductionCatalogItem>{
      for (final item in catalog) item.code: item,
      ..._catalogOverrides,
    };
    return items.values.toList()..sort((a, b) => a.code.compareTo(b.code));
  }

  ProductionCatalogItem catalogItem(String code) {
    final normalizedCode = code.trim();
    final override = _catalogOverrides[normalizedCode];
    if (override != null) return override;
    return catalog.firstWhere(
      (item) => item.code == code,
      orElse: () => ProductionCatalogItem(
        code: normalizedCode,
        name: normalizedCode,
        defaultQuantity: 1,
        components: const [],
      ),
    );
  }

  Future<ProductionOrderFlow> createOrder({
    required String productCode,
    String? productName,
    List<ProductionComponent> components = const [],
    required int quantity,
    required String priority,
    required String operatorName,
    String? responsavel,
    String? prazo,
    String orderWarehouse = '',
    ProductionStage initialStage = ProductionStage.warehouse,
    String? operatorPin,
  }) async {
    final now = DateTime.now();
    final existing = catalogItem(productCode);
    final product = ProductionCatalogItem(
      code: productCode,
      name: productName?.trim().isNotEmpty == true
          ? productName!.trim()
          : existing.name,
      defaultQuantity: quantity,
      components: components.isNotEmpty ? components : existing.components,
    );
    if (_requiresProtheusSignature(product.components) &&
        !_hasPin(operatorPin)) {
      throw StateError('Informe o PIN para movimentar o Protheus.');
    }
    _catalogOverrides[product.code] = product;
    final number = 'OP-${now.year}-${_nextSequence++}';
    final order = ProductionOrderFlow(
      number: number,
      productCode: product.code,
      productName: product.name,
      quantity: quantity,
      currentStage: initialStage,
      plannedStages: ProductionStage.productionFlow
          .where((stage) => stage.progressIndex >= initialStage.progressIndex)
          .toList(),
      status: ProductionRunStatus.waiting,
      priority: priority,
      createdAt: now,
      updatedAt: now,
      operatorName: operatorName,
      operatorPin: operatorPin,
      responsavel: responsavel,
      prazo: prazo,
      orderWarehouse: orderWarehouse,
    );
    _orders.insert(0, order);
    _persist();
    notifyListeners();
    await _syncOrder(order, 'created');
    return order;
  }

  Future<void> startStage(
    String number, {
    String? operatorName,
    String? operatorPin,
  }) {
    return _mutate(number, (order, now) {
      final timings = Map<ProductionStage, ProductionStageTiming>.from(
        order.timings,
      );
      final current =
          timings[order.currentStage] ?? const ProductionStageTiming();
      timings[order.currentStage] = current.pausedAt == null
          ? current.start(now)
          : current.resume(now);

      final sessions = [...order.operatorSessions];
      final pauseEvents = [...order.pauseEvents];
      final signature = _signatureKey(operatorName, operatorPin);
      if (signature != null) {
        final index = _sessionIndex(
          sessions,
          order.currentStage,
          operatorName,
          operatorPin,
        );
        if (index == -1) {
          sessions.add(
            ProductionOperatorSession(
              stage: order.currentStage,
              operatorName: operatorName ?? 'Operador',
              operatorPin: operatorPin ?? signature,
              startedAt: now,
            ),
          );
        } else {
          sessions[index] = sessions[index].resume(now);
        }
        _closeLatestPauseEvent(
          pauseEvents,
          order.currentStage,
          operatorName,
          operatorPin,
          now,
        );
      }

      return order.copyWith(
        status: ProductionRunStatus.active,
        updatedAt: now,
        operatorName: () => operatorName ?? order.operatorName,
        responsavel: () {
          final name = operatorName?.trim();
          return name == null || name.isEmpty ? order.responsavel : name;
        },
        timings: timings,
        operatorSessions: sessions,
        pauseEvents: pauseEvents,
      );
    });
  }

  Future<void> pauseStage(
    String number, {
    String? operatorName,
    String? operatorPin,
    PauseReason reason = PauseReason.outro,
    String? customReason,
    int producedQuantity = 0,
  }) {
    return _mutate(number, (order, now) {
      final timings = Map<ProductionStage, ProductionStageTiming>.from(
        order.timings,
      );
      final current =
          timings[order.currentStage] ?? const ProductionStageTiming();
      final sessions = [...order.operatorSessions];
      final signature = _signatureKey(operatorName, operatorPin);
      if (signature != null) {
        final index = _sessionIndex(
          sessions,
          order.currentStage,
          operatorName,
          operatorPin,
        );
        final safeQuantity = producedQuantity.clamp(0, order.quantity).toInt();
        if (index == -1) {
          sessions.add(
            ProductionOperatorSession(
              stage: order.currentStage,
              operatorName: operatorName ?? 'Operador',
              operatorPin: operatorPin ?? signature,
              startedAt: now,
            ).pause(now, producedQuantity: safeQuantity),
          );
        } else {
          sessions[index] = sessions[index].pause(
            now,
            producedQuantity: safeQuantity,
          );
        }
      }
      final hasRunning = _hasRunningSession(sessions, order.currentStage);
      timings[order.currentStage] = hasRunning ? current : current.pause(now);
      final pauseEvents = [
        ...order.pauseEvents,
        if (signature != null)
          ProductionPauseEvent(
            stage: order.currentStage,
            operatorName: operatorName ?? 'Operador',
            operatorPin: operatorPin ?? signature,
            reason: reason,
            customReason: customReason,
            producedQuantity: producedQuantity.clamp(0, order.quantity).toInt(),
            createdAt: now,
          ),
      ];
      return order.copyWith(
        status: hasRunning
            ? ProductionRunStatus.active
            : ProductionRunStatus.paused,
        updatedAt: now,
        timings: timings,
        operatorSessions: sessions,
        pauseEvents: pauseEvents,
      );
    });
  }

  Future<void> resetStage(String number) {
    return _mutate(number, (order, now) {
      return order.copyWith(
        status: ProductionRunStatus.waiting,
        updatedAt: now,
      );
    });
  }

  /// Volta a OP para a etapa anterior do fluxo (usado pelo dashboard).
  Future<void> regressStage(String number) {
    return _mutate(number, (order, now) {
      final previous = _previousStage(order.currentStage);
      final timings = Map<ProductionStage, ProductionStageTiming>.from(
        order.timings,
      )..remove(order.currentStage);
      return order.copyWith(
        currentStage: previous,
        status: ProductionRunStatus.waiting,
        updatedAt: now,
        responsavel: () => null,
        timings: timings,
      );
    });
  }

  /// Remove a OP do fluxo (cancelamento pelo dashboard).
  Future<void> cancelOrder(
    String number, {
    Map<String, String> returnWarehouses = const {},
    String? operatorName,
    String? operatorPin,
  }) async {
    final index = _orders.indexWhere((order) => order.number == number);
    if (index == -1) return;
    final order = _orders[index];
    final item = catalogItem(order.productCode);
    if (_requiresProtheusSignature(item.components) && !_hasPin(operatorPin)) {
      throw StateError('Informe o PIN para cancelar e devolver no Protheus.');
    }
    await database.deleteOrder(
      number,
      order: order.copyWith(updatedAt: DateTime.now()),
      catalogItem: item,
      returnWarehouses: returnWarehouses,
      operatorName: operatorName,
      operatorPin: operatorPin,
    );
    _orders.removeAt(index);
    _persist();
    notifyListeners();
  }

  Future<void> updatePlannedStages(
    String number,
    List<ProductionStage> stages,
  ) {
    return _mutate(number, (order, now) {
      final validStages = _sanitizePlannedStages(order.currentStage, stages);
      return order.copyWith(plannedStages: validStages, updatedAt: now);
    });
  }

  Future<void> completeStage(
    String number, {
    String? observation,
    String? operatorName,
    String? operatorPin,
    List<DefectRecord> defects = const [],
  }) {
    return _mutate(number, (order, now) {
      final timings = Map<ProductionStage, ProductionStageTiming>.from(
        order.timings,
      );
      final current =
          timings[order.currentStage] ??
          const ProductionStageTiming(startedAt: null);
      final sessions = [...order.operatorSessions];
      final signature = _signatureKey(operatorName, operatorPin);
      if (signature != null) {
        final index = _sessionIndex(
          sessions,
          order.currentStage,
          operatorName,
          operatorPin,
        );
        if (index == -1) {
          sessions.add(
            ProductionOperatorSession(
              stage: order.currentStage,
              operatorName: operatorName ?? 'Operador',
              operatorPin: operatorPin ?? signature,
              startedAt: now,
              completedAt: now,
            ),
          );
        } else {
          sessions[index] = sessions[index].complete(now);
        }
        final remaining = _activeSessions(sessions, order.currentStage);
        if (remaining.isNotEmpty) {
          final status = remaining.any((session) => session.isRunning)
              ? ProductionRunStatus.active
              : ProductionRunStatus.paused;
          return order.copyWith(
            status: status,
            updatedAt: now,
            lastObservation: () {
              final note = observation?.trim();
              return note == null || note.isEmpty ? null : note;
            },
            operatorSessions: sessions,
          );
        }
      }
      timings[order.currentStage] = current
          .start(current.startedAt ?? now)
          .complete(now);
      return order.copyWith(
        currentStage: _nextStageFor(order),
        status: ProductionRunStatus.waiting,
        updatedAt: now,
        responsavel: () => null,
        lastObservation: () {
          final note = observation?.trim();
          return note == null || note.isEmpty ? null : note;
        },
        timings: timings,
        operatorSessions: sessions,
        testDefects: defects.isEmpty
            ? order.testDefects
            : [...order.testDefects, ...defects],
      );
    });
  }

  /// Conclui o teste registrando os defeitos encontrados (tipo + quantidade)
  /// e avança a OP para a etapa seguinte.
  Future<void> completeTesting(
    String number, {
    required List<DefectRecord> defects,
  }) {
    return _mutate(number, (order, now) {
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
        currentStage: _nextStageFor(order),
        status: ProductionRunStatus.waiting,
        updatedAt: now,
        testDefects: defects.isEmpty
            ? order.testDefects
            : [...order.testDefects, ...defects],
        timings: timings,
      );
    });
  }

  Future<void> completeClosing(String number, {required int closedQuantity}) {
    return _mutate(number, (order, now) {
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
        currentStage: _nextStageFor(order),
        status: ProductionRunStatus.waiting,
        updatedAt: now,
        closedQuantity: safeClosed,
        timings: timings,
      );
    });
  }

  Future<void> completeExpedition(
    String number, {
    required int storedQuantity,
  }) {
    return _mutate(number, (order, now) {
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

  Future<void> dispatchStored(String number, {required int quantity}) {
    return _mutate(number, (order, now) {
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

  Future<void> _mutate(
    String number,
    ProductionOrderFlow Function(ProductionOrderFlow order, DateTime now)
    update,
  ) async {
    final index = _orders.indexWhere((order) => order.number == number);
    if (index == -1) return;
    final updated = update(_orders[index], DateTime.now());
    await _syncOrder(updated, 'updated');
    _orders[index] = updated;
    _persist();
    notifyListeners();
  }

  Future<void> _loadFromDatabase() async {
    try {
      final snapshot = await database.loadSnapshot();
      if (snapshot.orders.isEmpty) return;
      _orders
        ..clear()
        ..addAll(snapshot.orders);
      _catalogOverrides
        ..clear()
        ..addEntries(
          snapshot.catalogItems.map((item) => MapEntry(item.code, item)),
        );
      _nextSequence = _nextSequenceFrom(snapshot.orders);
      _persist();
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('Erro ao carregar OPs do Postgres: $error');
      debugPrintStack(stackTrace: stackTrace);
      // O app continua pelo cache local quando o Postgres estiver indisponivel.
    }
  }

  Future<void> _syncOrder(ProductionOrderFlow order, String eventType) async {
    final product = catalogItem(order.productCode);
    try {
      await database.saveOrder(order, product, eventType: eventType);
    } catch (error, stackTrace) {
      debugPrint('Erro ao sincronizar OP ${order.number} no Postgres: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  int _nextSequenceFrom(List<ProductionOrderFlow> orders) {
    var next = _nextSequence;
    for (final order in orders) {
      final sequence = int.tryParse(order.number.split('-').last);
      if (sequence != null && sequence >= next) next = sequence + 1;
    }
    return next;
  }

  void _persist() {
    _persistence.write(
      jsonEncode({
        'nextSequence': _nextSequence,
        'catalogOverrides': _catalogOverrides.values
            .map(_catalogItemToJson)
            .toList(),
        'orders': _orders.map(_orderToJson).toList(),
      }),
    );
  }

  bool _restore(String? payload) {
    if (payload == null || payload.isEmpty) return false;
    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      final orders = decoded['orders'] as List<dynamic>;
      final catalogOverrides = decoded['catalogOverrides'] as List<dynamic>?;
      _catalogOverrides
        ..clear()
        ..addEntries(
          (catalogOverrides ?? const [])
              .map((item) => _catalogItemFromJson(item as Map<String, dynamic>))
              .map((item) => MapEntry(item.code, item)),
        );
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

  Map<String, dynamic> _catalogItemToJson(ProductionCatalogItem item) {
    return {
      'code': item.code,
      'name': item.name,
      'defaultQuantity': item.defaultQuantity,
      'components': item.components.map(_componentToJson).toList(),
    };
  }

  ProductionCatalogItem _catalogItemFromJson(Map<String, dynamic> json) {
    return ProductionCatalogItem(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      defaultQuantity: (json['defaultQuantity'] as num?)?.toInt() ?? 1,
      components:
          (json['components'] as List<dynamic>?)
              ?.map(
                (component) =>
                    _componentFromJson(component as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> _componentToJson(ProductionComponent component) {
    return {
      'code': component.code,
      'description': component.description,
      'quantity': component.quantity,
      'stock': component.stock,
      'filial': component.filial,
      'armazem': component.armazem,
      'currentStock': component.currentStock,
      'committedQuantity': component.committedQuantity,
      'reservedQuantity': component.reservedQuantity,
      'requirementSource': component.requirementSource,
      'sourceOrder': component.sourceOrder,
      'commitmentDate': component.commitmentDate,
      'originalQuantity': component.originalQuantity,
      'commitmentQuantity': component.commitmentQuantity,
    };
  }

  ProductionComponent _componentFromJson(Map<String, dynamic> json) {
    return ProductionComponent(
      code: json['code'] as String? ?? '',
      description: json['description'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      filial: json['filial'] as String? ?? '',
      armazem: json['armazem'] as String? ?? '',
      currentStock: (json['currentStock'] as num?)?.toInt() ?? 0,
      committedQuantity: (json['committedQuantity'] as num?)?.toInt() ?? 0,
      reservedQuantity: (json['reservedQuantity'] as num?)?.toInt() ?? 0,
      requirementSource: json['requirementSource'] as String? ?? 'SG1',
      sourceOrder: json['sourceOrder'] as String? ?? '',
      commitmentDate: json['commitmentDate'] as String? ?? '',
      originalQuantity: (json['originalQuantity'] as num?)?.toInt() ?? 0,
      commitmentQuantity: (json['commitmentQuantity'] as num?)?.toInt() ?? 0,
    );
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
      'operatorPin': order.operatorPin,
      'responsavel': order.responsavel,
      'prazo': order.prazo,
      'orderWarehouse': order.orderWarehouse,
      'closedQuantity': order.closedQuantity,
      'lastObservation': order.lastObservation,
      'storedQuantity': order.storedQuantity,
      'dispatchedQuantity': order.dispatchedQuantity,
      'timings': {
        for (final entry in order.timings.entries)
          entry.key.name: _timingToJson(entry.value),
      },
      'testDefects': order.testDefects.map((d) => d.toJson()).toList(),
      'operatorSessions': order.operatorSessions
          .map((s) => s.toJson())
          .toList(),
      'pauseEvents': order.pauseEvents.map((p) => p.toJson()).toList(),
      'plannedStages': order.plannedStages.map((stage) => stage.name).toList(),
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
      operatorPin: json['operatorPin'] as String?,
      responsavel: json['responsavel'] as String?,
      prazo: json['prazo'] as String?,
      orderWarehouse: json['orderWarehouse'] as String? ?? '',
      closedQuantity: (json['closedQuantity'] as num?)?.toInt() ?? 0,
      lastObservation: json['lastObservation'] as String?,
      storedQuantity: (json['storedQuantity'] as num?)?.toInt() ?? 0,
      dispatchedQuantity: (json['dispatchedQuantity'] as num?)?.toInt() ?? 0,
      timings: _timingsFromJson(json['timings'] as Map<String, dynamic>?),
      testDefects:
          (json['testDefects'] as List<dynamic>?)
              ?.map((d) => DefectRecord.fromJson(d as Map<String, dynamic>))
              .toList() ??
          const [],
      operatorSessions:
          (json['operatorSessions'] as List<dynamic>?)
              ?.map(
                (s) => ProductionOperatorSession.fromJson(
                  s as Map<String, dynamic>,
                ),
              )
              .toList() ??
          const [],
      pauseEvents:
          (json['pauseEvents'] as List<dynamic>?)
              ?.map(
                (p) => ProductionPauseEvent.fromJson(p as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      plannedStages:
          (json['plannedStages'] as List<dynamic>?)
              ?.map((stage) => _stageFromName(stage as String?))
              .where(_isRoutableStage)
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

  ProductionStage _nextStageFor(ProductionOrderFlow order) {
    final route = order.plannedStages.where(_isRoutableStage).toList();
    if (route.isNotEmpty) {
      final currentIndex = route.indexOf(order.currentStage);
      if (currentIndex != -1) {
        if (currentIndex < route.length - 1) return route[currentIndex + 1];
        return ProductionStage.completed;
      }
      return route.first == order.currentStage
          ? ProductionStage.completed
          : route.first;
    }

    return _nextStage(order.currentStage);
  }

  ProductionStage _nextStage(ProductionStage stage) {
    return switch (stage) {
      ProductionStage.warehouse => ProductionStage.smd,
      ProductionStage.smd => ProductionStage.firmware,
      ProductionStage.firmware => ProductionStage.soldering,
      ProductionStage.soldering => ProductionStage.testing,
      ProductionStage.testing => ProductionStage.closing,
      ProductionStage.closing => ProductionStage.expedition,
      ProductionStage.expedition => ProductionStage.completed,
      ProductionStage.storage => ProductionStage.completed,
      ProductionStage.completed => ProductionStage.completed,
    };
  }

  List<ProductionStage> _sanitizePlannedStages(
    ProductionStage currentStage,
    List<ProductionStage> stages,
  ) {
    final route = <ProductionStage>[];
    for (final stage in stages) {
      if (!_isRoutableStage(stage)) continue;
      if (!route.contains(stage)) route.add(stage);
    }
    if (_isRoutableStage(currentStage) && !route.contains(currentStage)) {
      route.insert(0, currentStage);
    }
    return route;
  }

  bool _isRoutableStage(ProductionStage stage) =>
      ProductionStage.productionFlow.contains(stage);

  bool _requiresProtheusSignature(List<ProductionComponent> components) {
    return components.any(_movesProtheusStock);
  }

  bool _movesProtheusStock(ProductionComponent component) {
    return component.code.trim().isNotEmpty &&
        component.armazem.trim().isNotEmpty &&
        component.quantity > 0 &&
        !component.code.toUpperCase().startsWith('MOD');
  }

  bool _hasPin(String? operatorPin) => operatorPin?.trim().isNotEmpty ?? false;

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

  String? _signatureKey(String? operatorName, String? operatorPin) {
    final pin = operatorPin?.trim();
    if (pin != null && pin.isNotEmpty) return pin;
    final name = operatorName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return null;
  }

  int _sessionIndex(
    List<ProductionOperatorSession> sessions,
    ProductionStage stage,
    String? operatorName,
    String? operatorPin,
  ) {
    final signature = _signatureKey(operatorName, operatorPin);
    if (signature == null) return -1;
    return sessions.indexWhere(
      (session) =>
          session.stage == stage &&
          !session.isCompleted &&
          (session.operatorPin == signature ||
              session.operatorName.toLowerCase() == signature.toLowerCase()),
    );
  }

  List<ProductionOperatorSession> _activeSessions(
    List<ProductionOperatorSession> sessions,
    ProductionStage stage,
  ) {
    return sessions
        .where((session) => session.stage == stage && !session.isCompleted)
        .toList();
  }

  bool _hasRunningSession(
    List<ProductionOperatorSession> sessions,
    ProductionStage stage,
  ) {
    return sessions.any(
      (session) => session.stage == stage && session.isRunning,
    );
  }

  void _closeLatestPauseEvent(
    List<ProductionPauseEvent> pauseEvents,
    ProductionStage stage,
    String? operatorName,
    String? operatorPin,
    DateTime now,
  ) {
    final signature = _signatureKey(operatorName, operatorPin);
    if (signature == null) return;
    for (var i = pauseEvents.length - 1; i >= 0; i--) {
      final event = pauseEvents[i];
      if (event.stage == stage &&
          event.resumedAt == null &&
          (event.operatorPin == signature ||
              event.operatorName.toLowerCase() == signature.toLowerCase())) {
        pauseEvents[i] = event.copyWith(resumedAt: () => now);
        return;
      }
    }
  }
}
