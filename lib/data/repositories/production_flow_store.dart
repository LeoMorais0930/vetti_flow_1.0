import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/protheus_order.dart';
import 'package:vetti_flow_1_0/data/repositories/product_catalog_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/local_json_persistence.dart';

class ProductionFlowStore extends ChangeNotifier {
  /// Começa vazio: nenhuma OP existe aqui até ser adotada do Protheus.
  ProductionFlowStore({required ProductCatalogRepository catalog})
    // `this._catalog` exporia o nome privado do campo na chamada.
    // ignore: prefer_initializing_formals
    : _catalog = catalog {
    _restore(_persistence.read());
    _persistence.listen((payload) {
      if (_restore(payload)) notifyListeners();
    });
  }

  /// Dados de produto vêm de fora: o store é dono do fluxo, não do catálogo.
  final ProductCatalogRepository _catalog;

  static const _storageKey = 'vetti_flow.production_flow.v1';

  final _persistence = const LocalJsonPersistence(_storageKey);
  final _orders = <ProductionOrderFlow>[];

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

  /// Produto de uma OP já existente.
  ///
  /// Código desconhecido devolve um item vazio com o próprio código no lugar
  /// do nome — nunca outro produto. O fallback antigo caía no primeiro item do
  /// catálogo, o que com centenas de produtos reais seria um erro silencioso e
  /// caro: a tela mostraria um produto que não é o da OP.
  ProductionCatalogItem catalogItem(String code) {
    return _catalog.findByCode(code) ??
        ProductionCatalogItem(code: code, name: code);
  }

  /// Traz uma OP do Protheus para o fluxo do VettiFlow.
  ///
  /// O VettiFlow não cria OPs — o dono delas é o ERP. Adotar significa criar
  /// o envelope de etapas em volta de uma OP que já existe lá.
  ///
  /// Lança [ArgumentError] se a OP estiver encerrada no Protheus: encerrada é
  /// somente leitura. Adotar a mesma OP duas vezes devolve a que já existe.
  ProductionOrderFlow adoptOrder(
    ProtheusOrder source, {
    String priority = 'Media',
    String? operatorName,
    String? responsavel,
  }) {
    if (source.closed) {
      throw ArgumentError.value(
        source.displayNumber,
        'source',
        'OP encerrada no Protheus é somente leitura e não pode ser adotada',
      );
    }

    final existing = orderByProtheusKey(source.key);
    if (existing != null) return existing;

    final now = DateTime.now();
    final product = _catalog.findByCode(source.productCode);
    final order = ProductionOrderFlow(
      number: source.displayNumber,
      protheusKey: source.key,
      productCode: source.productCode,
      productName: product?.name ?? source.productCode,
      quantity: source.quantity,
      currentStage: ProductionStage.warehouse,
      status: ProductionRunStatus.waiting,
      priority: priority,
      createdAt: now,
      updatedAt: now,
      operatorName: operatorName,
      responsavel: responsavel,
      prazo: source.dueAt,
    );
    _orders.insert(0, order);
    _persist();
    notifyListeners();
    return order;
  }

  /// A OP já adotada que corresponde a esta chave do Protheus, se houver.
  ProductionOrderFlow? orderByProtheusKey(ProtheusOrderKey key) {
    for (final order in _orders) {
      if (order.protheusKey == key) return order;
    }
    return null;
  }

  /// Chaves das OPs já trazidas para o fluxo, para a tela de seleção não
  /// oferecer o que já está em produção.
  Set<ProtheusOrderKey> get adoptedKeys => {
    for (final order in _orders)
      if (order.protheusKey != null) order.protheusKey!,
  };

  void startStage(String number, {String? operatorName, String? operatorPin}) {
    _mutate(number, (order, now) {
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
        timings: timings,
        operatorSessions: sessions,
        pauseEvents: pauseEvents,
      );
    });
  }

  void pauseStage(
    String number, {
    String? operatorName,
    String? operatorPin,
    PauseReason reason = PauseReason.outro,
    String? customReason,
    int producedQuantity = 0,
  }) {
    _mutate(number, (order, now) {
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

  void completeStage(
    String number, {
    String? observation,
    String? operatorName,
    String? operatorPin,
  }) {
    _mutate(number, (order, now) {
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
        currentStage: _nextStage(order.currentStage),
        status: ProductionRunStatus.waiting,
        updatedAt: now,
        lastObservation: () {
          final note = observation?.trim();
          return note == null || note.isEmpty ? null : note;
        },
        timings: timings,
        operatorSessions: sessions,
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
      jsonEncode({'orders': _orders.map(_orderToJson).toList()}),
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
      'protheusKey': order.protheusKey?.toJson(),
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
      'operatorSessions': order.operatorSessions
          .map((s) => s.toJson())
          .toList(),
      'pauseEvents': order.pauseEvents.map((p) => p.toJson()).toList(),
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
      // Ausente nos payloads gravados antes da integração: fica nulo.
      protheusKey: json['protheusKey'] is Map<String, dynamic>
          ? ProtheusOrderKey.fromJson(
              json['protheusKey'] as Map<String, dynamic>,
            )
          : null,
      operatorName: json['operatorName'] as String?,
      responsavel: json['responsavel'] as String?,
      prazo: json['prazo'] as String?,
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
