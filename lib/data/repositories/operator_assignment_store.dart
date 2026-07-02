import 'package:flutter/foundation.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';

class OperatorAssignmentStore extends ChangeNotifier {
  OperatorAssignmentStore()
    : _assignments = {
        for (final operator in _assignableOperators)
          operator.username: operator.stage,
      };

  static const assignableStages = [
    WorkStage.firmware,
    WorkStage.soldering,
    WorkStage.testing,
    WorkStage.closing,
    WorkStage.expedition,
    WorkStage.warehouse,
    WorkStage.support,
  ];

  static const productionStages = [
    WorkStage.firmware,
    WorkStage.soldering,
    WorkStage.testing,
    WorkStage.closing,
    WorkStage.expedition,
  ];

  static const smdStages = [WorkStage.firmware, WorkStage.soldering];

  static const warehouseStages = [WorkStage.warehouse];

  static const supportStages = [WorkStage.support];

  static List<Operator> get assignableOperators {
    final seen = <String>{};
    return [
      for (final operator in _assignableOperators)
        if (seen.add(operator.username)) operator,
    ];
  }

  static List<Operator> get dashboardOperators => Operator.all
      .where((operator) => operator.canManageAssignments)
      .where((operator) => operator.stage == WorkStage.dashboard)
      .toList();

  static Iterable<Operator> get _assignableOperators =>
      Operator.all.where((operator) => operator.usesAssignedStage);

  final Map<String, WorkStage> _assignments;
  Operator? _currentOperator;

  Operator? get currentOperator => _currentOperator;
  WorkArea? get currentManagedArea => _currentOperator?.managesArea;

  String get currentAreaLabel =>
      currentManagedArea?.label ?? 'Todos os setores';

  List<Operator> get visibleAssignableOperators {
    final area = currentManagedArea;
    if (area == null) return assignableOperators;
    return assignableOperators
        .where((operator) => operator.area == area)
        .toList();
  }

  List<Operator> get visibleDashboardOperators {
    final area = currentManagedArea;
    if (area == null) return dashboardOperators;
    return dashboardOperators
        .where((operator) => operator.managesArea == area)
        .toList();
  }

  WorkStage stageFor(Operator operator) {
    if (!operator.usesAssignedStage) return operator.stage;
    return _assignments[operator.username] ?? operator.stage;
  }

  Operator resolve(Operator operator) =>
      operator.copyWithStage(stageFor(operator));

  Operator? authenticate(String username, String password) {
    final operator = Operator.authenticate(username, password);
    if (operator == null) return null;
    final resolved = resolve(operator);
    _currentOperator = resolved;
    notifyListeners();
    return resolved;
  }

  Operator? findByPin(String pin) {
    final operator = Operator.findByPin(pin);
    if (operator == null) return null;
    return resolve(operator);
  }

  void assignStage(String username, WorkStage stage) {
    final operator = assignableOperators.cast<Operator?>().firstWhere(
      (operator) => operator?.username == username,
      orElse: () => null,
    );
    if (operator == null) return;
    if (!_canCurrentManagerAssign(operator, stage)) return;
    _assignments[username] = stage;
    notifyListeners();
  }

  List<WorkStage> stagesFor(Operator operator) {
    return switch (operator.area) {
      WorkArea.production => productionStages,
      WorkArea.smd => smdStages,
      WorkArea.warehouse => warehouseStages,
      WorkArea.support => supportStages,
      WorkArea.system => const [],
    };
  }

  int countAt(WorkStage stage) {
    return visibleAssignableOperators
        .where((operator) => stageFor(operator) == stage)
        .length;
  }

  bool _canCurrentManagerAssign(Operator operator, WorkStage stage) {
    final managedArea = currentManagedArea;
    if (managedArea != null && operator.area != managedArea) return false;
    return stagesFor(operator).contains(stage);
  }
}
