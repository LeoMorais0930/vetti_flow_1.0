enum ProductionStage {
  warehouse,
  firmware,
  soldering,
  testing,
  closing,
  expedition,
  storage,
  completed;

  String get label => switch (this) {
    warehouse => 'Almoxarifado',
    firmware => 'Gravacao',
    soldering => 'Soldagem',
    testing => 'Testes',
    closing => 'Fechamento',
    expedition => 'Expedicao',
    storage => 'Armazenada',
    completed => 'Finalizada',
  };

  String get route => switch (this) {
    warehouse => '/almoxarifado',
    firmware => '/firmware',
    soldering => '/soldagem',
    testing => '/teste',
    closing => '/fechamento',
    expedition => '/expedicao',
    storage => '/expedicao',
    completed => '/dashboard',
  };

  int get progressIndex => switch (this) {
    warehouse => 0,
    firmware => 1,
    soldering => 2,
    testing => 3,
    closing => 4,
    expedition => 5,
    storage || completed => 6,
  };

  static const productionFlow = [
    warehouse,
    firmware,
    soldering,
    testing,
    closing,
    expedition,
  ];
}

enum ProductionRunStatus { waiting, active, paused, completed }

String formatProductionDuration(Duration duration) {
  final normalized = duration.isNegative ? Duration.zero : duration;
  final hours = normalized.inHours;
  final minutes = normalized.inMinutes.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}min';
  if (minutes > 0) return '${minutes}min';
  return '${normalized.inSeconds}s';
}

class ProductionStageTiming {
  const ProductionStageTiming({
    this.startedAt,
    this.completedAt,
    this.pausedAt,
    this.pausedDuration = Duration.zero,
  });

  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? pausedAt;
  final Duration pausedDuration;

  Duration elapsed(DateTime now) {
    final start = startedAt;
    if (start == null) return Duration.zero;
    final end = completedAt ?? pausedAt ?? now;
    return end.difference(start) - pausedDuration;
  }

  ProductionStageTiming start(DateTime now) {
    return copyWith(startedAt: () => startedAt ?? now, pausedAt: () => null);
  }

  ProductionStageTiming pause(DateTime now) {
    return copyWith(pausedAt: () => pausedAt ?? now);
  }

  ProductionStageTiming resume(DateTime now) {
    final paused = pausedAt;
    return copyWith(
      pausedAt: () => null,
      pausedDuration: paused == null
          ? pausedDuration
          : pausedDuration + now.difference(paused),
    );
  }

  ProductionStageTiming complete(DateTime now) {
    final resumed = pausedAt == null ? this : resume(now);
    return resumed.copyWith(completedAt: () => now, pausedAt: () => null);
  }

  ProductionStageTiming copyWith({
    DateTime? Function()? startedAt,
    DateTime? Function()? completedAt,
    DateTime? Function()? pausedAt,
    Duration? pausedDuration,
  }) {
    return ProductionStageTiming(
      startedAt: startedAt != null ? startedAt() : this.startedAt,
      completedAt: completedAt != null ? completedAt() : this.completedAt,
      pausedAt: pausedAt != null ? pausedAt() : this.pausedAt,
      pausedDuration: pausedDuration ?? this.pausedDuration,
    );
  }
}

class ProductionOrderFlow {
  const ProductionOrderFlow({
    required this.number,
    required this.productCode,
    required this.productName,
    required this.quantity,
    required this.currentStage,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.operatorName,
    this.responsavel,
    this.prazo,
    this.closedQuantity = 0,
    this.storedQuantity = 0,
    this.dispatchedQuantity = 0,
    this.timings = const {},
  });

  final String number;
  final String productCode;
  final String productName;
  final int quantity;
  final ProductionStage currentStage;
  final ProductionRunStatus status;
  final String priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? operatorName;
  final String? responsavel;
  final String? prazo;
  final int closedQuantity;
  final int storedQuantity;
  final int dispatchedQuantity;
  final Map<ProductionStage, ProductionStageTiming> timings;

  String get productLabel =>
      productCode.isEmpty ? productName : '$productCode - $productName';

  String get quantityLabel => '$quantity un';

  bool get isHighPriority => priority == 'Alta';

  bool get isDone =>
      currentStage == ProductionStage.completed ||
      currentStage == ProductionStage.storage;

  Duration activeElapsed(DateTime now) =>
      timings[currentStage]?.elapsed(now) ?? Duration.zero;

  Duration totalElapsed(DateTime now) {
    return timings.values.fold<Duration>(
      Duration.zero,
      (total, timing) => total + timing.elapsed(now),
    );
  }

  ProductionOrderFlow copyWith({
    ProductionStage? currentStage,
    ProductionRunStatus? status,
    String? priority,
    DateTime? updatedAt,
    String? Function()? operatorName,
    String? responsavel,
    String? prazo,
    int? closedQuantity,
    int? storedQuantity,
    int? dispatchedQuantity,
    Map<ProductionStage, ProductionStageTiming>? timings,
  }) {
    return ProductionOrderFlow(
      number: number,
      productCode: productCode,
      productName: productName,
      quantity: quantity,
      currentStage: currentStage ?? this.currentStage,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      operatorName: operatorName != null ? operatorName() : this.operatorName,
      responsavel: responsavel ?? this.responsavel,
      prazo: prazo ?? this.prazo,
      closedQuantity: closedQuantity ?? this.closedQuantity,
      storedQuantity: storedQuantity ?? this.storedQuantity,
      dispatchedQuantity: dispatchedQuantity ?? this.dispatchedQuantity,
      timings: timings ?? this.timings,
    );
  }
}

class ProductionCatalogItem {
  const ProductionCatalogItem({
    required this.code,
    required this.name,
    required this.defaultQuantity,
    required this.components,
  });

  final String code;
  final String name;
  final int defaultQuantity;
  final List<ProductionComponent> components;

  String get label => '$code - $name';
}

class ProductionComponent {
  const ProductionComponent({
    required this.code,
    required this.description,
    required this.quantity,
    required this.stock,
  });

  final String code;
  final String description;
  final int quantity;
  final int stock;

  String get quantityLabel => '$quantity un';
  String get stockLabel => '$stock un';
}
