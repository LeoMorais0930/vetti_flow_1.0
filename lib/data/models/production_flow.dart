import 'package:vetti_flow_1_0/data/models/warehouse.dart';

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
    testing => 'Teste',
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

enum PauseReason {
  ginasticaLaboral('Ginastica laboral'),
  cafe('Cafe'),
  banheiro('Banheiro'),
  almoco('Almoco'),
  outro('Outro');

  const PauseReason(this.label);

  final String label;
}

/// Um defeito registrado no teste: tipo (código + título) e quantidade de
/// dispositivos afetados.
class DefectRecord {
  const DefectRecord({
    required this.code,
    required this.title,
    required this.quantity,
  });

  final String code;
  final String title;
  final int quantity;

  Map<String, dynamic> toJson() => {
    'code': code,
    'title': title,
    'quantity': quantity,
  };

  factory DefectRecord.fromJson(Map<String, dynamic> json) => DefectRecord(
    code: json['code'] as String? ?? '',
    title: json['title'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
  );
}

class ProductionPauseEvent {
  const ProductionPauseEvent({
    required this.stage,
    required this.operatorName,
    required this.operatorPin,
    required this.reason,
    required this.createdAt,
    this.resumedAt,
    this.customReason,
    this.producedQuantity = 0,
  });

  final ProductionStage stage;
  final String operatorName;
  final String operatorPin;
  final PauseReason reason;
  final DateTime createdAt;
  final DateTime? resumedAt;
  final String? customReason;
  final int producedQuantity;

  String get reasonLabel {
    if (reason != PauseReason.outro) return reason.label;
    final custom = customReason?.trim();
    return custom == null || custom.isEmpty ? reason.label : custom;
  }

  Duration pauseDuration(DateTime now) {
    final end = resumedAt ?? now;
    final duration = end.difference(createdAt);
    return duration.isNegative ? Duration.zero : duration;
  }

  ProductionPauseEvent copyWith({DateTime? Function()? resumedAt}) {
    return ProductionPauseEvent(
      stage: stage,
      operatorName: operatorName,
      operatorPin: operatorPin,
      reason: reason,
      createdAt: createdAt,
      resumedAt: resumedAt != null ? resumedAt() : this.resumedAt,
      customReason: customReason,
      producedQuantity: producedQuantity,
    );
  }

  Map<String, dynamic> toJson() => {
    'stage': stage.name,
    'operatorName': operatorName,
    'operatorPin': operatorPin,
    'reason': reason.name,
    'createdAt': createdAt.toIso8601String(),
    'resumedAt': resumedAt?.toIso8601String(),
    'customReason': customReason,
    'producedQuantity': producedQuantity,
  };

  factory ProductionPauseEvent.fromJson(Map<String, dynamic> json) {
    return ProductionPauseEvent(
      stage: ProductionStage.values.firstWhere(
        (stage) => stage.name == json['stage'],
        orElse: () => ProductionStage.warehouse,
      ),
      operatorName: json['operatorName'] as String? ?? '',
      operatorPin: json['operatorPin'] as String? ?? '',
      reason: PauseReason.values.firstWhere(
        (reason) => reason.name == json['reason'],
        orElse: () => PauseReason.outro,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      resumedAt: json['resumedAt'] is String
          ? DateTime.parse(json['resumedAt'] as String)
          : null,
      customReason: json['customReason'] as String?,
      producedQuantity: (json['producedQuantity'] as num?)?.toInt() ?? 0,
    );
  }
}

class ProductionOperatorSession {
  const ProductionOperatorSession({
    required this.stage,
    required this.operatorName,
    required this.operatorPin,
    required this.startedAt,
    this.completedAt,
    this.pausedAt,
    this.pausedDuration = Duration.zero,
    this.producedQuantity = 0,
  });

  final ProductionStage stage;
  final String operatorName;
  final String operatorPin;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime? pausedAt;
  final Duration pausedDuration;
  final int producedQuantity;

  bool get isCompleted => completedAt != null;

  bool get isPaused => pausedAt != null && !isCompleted;

  bool get isRunning => pausedAt == null && !isCompleted;

  Duration elapsed(DateTime now) {
    final end = completedAt ?? pausedAt ?? now;
    final elapsed = end.difference(startedAt) - pausedDuration;
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  Duration workedDuration(DateTime now) => elapsed(now);

  ProductionOperatorSession pause(DateTime now, {int producedQuantity = 0}) {
    return copyWith(
      pausedAt: () => pausedAt ?? now,
      producedQuantity: this.producedQuantity + producedQuantity,
    );
  }

  ProductionOperatorSession resume(DateTime now) {
    final paused = pausedAt;
    return copyWith(
      pausedAt: () => null,
      pausedDuration: paused == null
          ? pausedDuration
          : pausedDuration + now.difference(paused),
    );
  }

  ProductionOperatorSession complete(DateTime now) {
    final resumed = pausedAt == null ? this : resume(now);
    return resumed.copyWith(completedAt: () => now, pausedAt: () => null);
  }

  ProductionOperatorSession copyWith({
    DateTime? Function()? completedAt,
    DateTime? Function()? pausedAt,
    Duration? pausedDuration,
    int? producedQuantity,
  }) {
    return ProductionOperatorSession(
      stage: stage,
      operatorName: operatorName,
      operatorPin: operatorPin,
      startedAt: startedAt,
      completedAt: completedAt != null ? completedAt() : this.completedAt,
      pausedAt: pausedAt != null ? pausedAt() : this.pausedAt,
      pausedDuration: pausedDuration ?? this.pausedDuration,
      producedQuantity: producedQuantity ?? this.producedQuantity,
    );
  }

  Map<String, dynamic> toJson() => {
    'stage': stage.name,
    'operatorName': operatorName,
    'operatorPin': operatorPin,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'pausedAt': pausedAt?.toIso8601String(),
    'pausedDurationMs': pausedDuration.inMilliseconds,
    'producedQuantity': producedQuantity,
  };

  factory ProductionOperatorSession.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? value) =>
        value is String ? DateTime.parse(value) : null;
    return ProductionOperatorSession(
      stage: ProductionStage.values.firstWhere(
        (stage) => stage.name == json['stage'],
        orElse: () => ProductionStage.warehouse,
      ),
      operatorName: json['operatorName'] as String? ?? '',
      operatorPin: json['operatorPin'] as String? ?? '',
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: parseDate(json['completedAt']),
      pausedAt: parseDate(json['pausedAt']),
      pausedDuration: Duration(
        milliseconds: (json['pausedDurationMs'] as num?)?.toInt() ?? 0,
      ),
      producedQuantity: (json['producedQuantity'] as num?)?.toInt() ?? 0,
    );
  }
}

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

/// Identidade de uma OP no Protheus (tabela SC2).
///
/// A chave é composta — foi conferida no SX2 do ambiente da Vetti, não é
/// suposição. `itemGrade` (C2_ITEMGRD) faz parte dela e costuma ser esquecido.
///
/// O VettiFlow não cria OPs: elas nascem no Protheus e são adotadas aqui. Esta
/// chave é o que amarra o envelope de fluxo do VettiFlow à OP de verdade.
class ProtheusOrderKey {
  const ProtheusOrderKey({
    required this.filial,
    required this.numero,
    required this.item,
    required this.sequencia,
    this.itemGrade = '',
  });

  /// C2_FILIAL
  final String filial;

  /// C2_NUM
  final String numero;

  /// C2_ITEM
  final String item;

  /// C2_SEQUEN
  final String sequencia;

  /// C2_ITEMGRD
  final String itemGrade;

  /// Formato concatenado usado em D3_OP e D4_OP: número + item + sequência.
  String get opConcatenada => '$numero$item$sequencia';

  /// Mesma chave, separada para leitura humana: `015942-01-001`.
  ///
  /// Os 11 dígitos grudados são o formato do banco, não algo para se mostrar
  /// a quem opera.
  String get numeroLegivel => '$numero-$item-$sequencia';

  Map<String, dynamic> toJson() => {
    'filial': filial,
    'numero': numero,
    'item': item,
    'sequencia': sequencia,
    'itemGrade': itemGrade,
  };

  factory ProtheusOrderKey.fromJson(Map<String, dynamic> json) {
    return ProtheusOrderKey(
      filial: json['filial'] as String? ?? '',
      numero: json['numero'] as String? ?? '',
      item: json['item'] as String? ?? '',
      sequencia: json['sequencia'] as String? ?? '',
      itemGrade: json['itemGrade'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProtheusOrderKey &&
      other.filial == filial &&
      other.numero == numero &&
      other.item == item &&
      other.sequencia == sequencia &&
      other.itemGrade == itemGrade;

  @override
  int get hashCode => Object.hash(filial, numero, item, sequencia, itemGrade);

  @override
  String toString() =>
      'ProtheusOrderKey($filial/$numero/$item/$sequencia/$itemGrade)';
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
    this.protheusKey,
    this.operatorName,
    this.responsavel,
    this.prazo,
    this.closedQuantity = 0,
    this.lastObservation,
    this.storedQuantity = 0,
    this.dispatchedQuantity = 0,
    this.timings = const {},
    this.testDefects = const [],
    this.operatorSessions = const [],
    this.pauseEvents = const [],
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

  /// Identidade desta OP no Protheus. Nulo enquanto a OP for local (criada
  /// pelo próprio app antes da integração) — fora isso, sempre preenchida.
  final ProtheusOrderKey? protheusKey;

  final String? operatorName;
  final String? responsavel;
  final String? prazo;
  final int closedQuantity;
  final String? lastObservation;
  final int storedQuantity;
  final int dispatchedQuantity;
  final Map<ProductionStage, ProductionStageTiming> timings;
  final List<DefectRecord> testDefects;
  final List<ProductionOperatorSession> operatorSessions;
  final List<ProductionPauseEvent> pauseEvents;

  /// Total de dispositivos marcados como defeito no teste.
  int get totalDefects =>
      testDefects.fold(0, (sum, defect) => sum + defect.quantity);

  String get productLabel =>
      productCode.isEmpty ? productName : '$productCode - $productName';

  String get quantityLabel => '$quantity un';

  bool get isHighPriority => priority == 'Alta';

  bool get isDone =>
      currentStage == ProductionStage.completed ||
      currentStage == ProductionStage.storage;

  Duration activeElapsed(DateTime now) =>
      timings[currentStage]?.elapsed(now) ?? Duration.zero;

  List<ProductionOperatorSession> sessionsAt(ProductionStage stage) =>
      operatorSessions.where((session) => session.stage == stage).toList();

  List<ProductionOperatorSession> activeSessionsAt(ProductionStage stage) =>
      sessionsAt(stage).where((session) => !session.isCompleted).toList();

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
    String? Function()? lastObservation,
    int? storedQuantity,
    int? dispatchedQuantity,
    Map<ProductionStage, ProductionStageTiming>? timings,
    List<DefectRecord>? testDefects,
    List<ProductionOperatorSession>? operatorSessions,
    List<ProductionPauseEvent>? pauseEvents,
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
      // Identidade não muda: quem é dono da OP é o Protheus.
      protheusKey: protheusKey,
      operatorName: operatorName != null ? operatorName() : this.operatorName,
      responsavel: responsavel ?? this.responsavel,
      prazo: prazo ?? this.prazo,
      closedQuantity: closedQuantity ?? this.closedQuantity,
      lastObservation: lastObservation != null
          ? lastObservation()
          : this.lastObservation,
      storedQuantity: storedQuantity ?? this.storedQuantity,
      dispatchedQuantity: dispatchedQuantity ?? this.dispatchedQuantity,
      timings: timings ?? this.timings,
      testDefects: testDefects ?? this.testDefects,
      operatorSessions: operatorSessions ?? this.operatorSessions,
      pauseEvents: pauseEvents ?? this.pauseEvents,
    );
  }
}

/// Formata quantidade do Protheus, que pode ser fracionária.
///
/// A estrutura de produto usa frações para itens rateados (`0.001348` de um
/// código de custo indireto, por exemplo). Mostrar isso como inteiro zeraria o
/// valor, então as casas decimais só aparecem quando existem.
String formatProductionQuantity(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value
      .toStringAsFixed(6)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// Produto do cadastro do Protheus (SB1) com sua estrutura (SG1) e saldo (SB2).
class ProductionCatalogItem {
  const ProductionCatalogItem({
    required this.code,
    required this.name,
    this.unit = '',
    this.type = '',
    this.group = '',
    this.stock = 0,
    this.committed = 0,
    this.components = const [],
    this.saldos = const [],
  });

  /// B1_COD
  final String code;

  /// B1_DESC
  final String name;

  /// B1_UM
  final String unit;

  /// B1_TIPO — PA, PI, MP, MC…
  final String type;

  /// B1_GRUPO
  final String group;

  /// Soma de B2_QATU de **todas as filiais e almoxarifados**.
  ///
  /// Não mostre este número ao operador: ele opera em uma filial, e o total da
  /// empresa não bate com o que ele vê no Protheus. Para tela, use [saldoNa].
  /// Serve para varredura e diagnóstico, onde o recorte por filial não importa.
  final int stock;

  /// Soma de B2_QEMP (empenhado) de **todas as filiais**. Mesma ressalva de
  /// [stock] — para tela, use [empenhadoNa].
  final int committed;

  final List<ProductionComponent> components;

  /// Posição por almoxarifado (SB2 quebrada por B2_LOCAL).
  ///
  /// É o que [stock] esconde: o mesmo total pode estar todo na expedição ou
  /// espalhado por três linhas de produção, e transferir entre armazéns só faz
  /// sentido com esse detalhe à mão.
  ///
  /// Vazia para produto sem posição de estoque em lugar nenhum.
  final List<SaldoArmazem> saldos;

  String get label => '$code - $name';

  /// Disponível somando **todas** as filiais. Ver a ressalva em [stock]: para
  /// mostrar número ao operador, use [disponivelNa].
  int get available => stock - committed;

  /// Saldo (B2_QATU) só da filial informada.
  ///
  /// É este o número que o operador precisa ver: ele opera em uma filial, e o
  /// saldo da outra não está ao alcance dele. Somar as duas produz um total que
  /// não existe em lugar nenhum do ERP.
  double saldoNa(String filial) {
    var total = 0.0;
    for (final s in saldos) {
      if (s.filial == filial) total += s.saldo;
    }
    return total;
  }

  /// Empenhado (B2_QEMP) só da filial informada.
  double empenhadoNa(String filial) {
    var total = 0.0;
    for (final s in saldos) {
      if (s.filial == filial) total += s.empenhado;
    }
    return total;
  }

  /// O que sobra para empenhar nesta filial. Pode ser negativo — o Protheus
  /// permite estouro e a tela precisa mostrar isso, não esconder.
  double disponivelNa(String filial) =>
      saldoNa(filial) - empenhadoNa(filial);

  /// Saldo neste almoxarifado, ou zero se o produto não tem posição lá.
  SaldoArmazem? saldoEm(String local, {String? filial}) {
    for (final s in saldos) {
      if (s.local == local && (filial == null || s.filial == filial)) return s;
    }
    return null;
  }

  /// Almoxarifados onde há algo deste produto, do maior saldo para o menor.
  List<SaldoArmazem> saldosComEstoque({String? filial}) {
    final lista =
        saldos
            .where((s) => (filial == null || s.filial == filial) && s.saldo != 0)
            .toList()
          ..sort((a, b) => b.saldo.compareTo(a.saldo));
    return lista;
  }
}

class ProductionComponent {
  const ProductionComponent({
    required this.code,
    required this.description,
    required this.quantity,
    required this.stock,
    this.unit = '',
  });

  final String code;
  final String description;

  /// G1_QUANT — quantidade por unidade produzida, pode ser fracionária.
  final double quantity;

  /// Saldo do componente somando **todas as filiais** — o mesmo agregado de
  /// `ProductionCatalogItem.stock`, denormalizado aqui na explosão da estrutura.
  ///
  /// Quem monta tela deve buscar o número da filial corrente no catálogo
  /// (`findByCode(code)?.saldoNa(filial)`) em vez de usar este campo.
  final int stock;

  /// B1_UM do componente.
  final String unit;

  /// Quantidade com a unidade real do componente: "1 PC", "0.001348 KG".
  String get quantityWithUnit =>
      '${formatProductionQuantity(quantity)}${unit.isEmpty ? '' : ' $unit'}';

  String get quantityLabel => '${formatProductionQuantity(quantity)} un';
  String get stockLabel => '$stock un';
}
