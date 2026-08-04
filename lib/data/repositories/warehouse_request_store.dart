import 'package:flutter/foundation.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/warehouse_request.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_request_database.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/models/warehouse_routing.dart';

class WarehouseRequestStore extends ChangeNotifier {
  WarehouseRequestStore({
    this.database = const EmptyWarehouseRequestDatabase(),
    List<WarehouseConfirmationRequest> seedRequests = const [],
  }) {
    _requests.addAll(seedRequests);
    _loadFromDatabase();
  }

  final WarehouseRequestDatabase database;
  final _requests = <WarehouseConfirmationRequest>[];

  List<WarehouseConfirmationRequest> get requests =>
      List.unmodifiable(_requests);

  List<WarehouseConfirmationRequest> pendingForArea(WorkArea? area) {
    final values =
        _requests
            .where((request) => request.isPending)
            .where((request) => area == null || request.area == area)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return values;
  }

  bool canCreateManualRequest(WorkArea? area) {
    return area == WorkArea.warehouse || area == WorkArea.smd;
  }

  List<WarehouseConfirmationRequest> createForOrder({
    required ProductionOrderFlow order,
    required ProductionCatalogItem catalogItem,
    required String orderWarehouse,
    required String requestedBy,
  }) {
    final normalizedOrderWarehouse = WarehouseRouting.normalizeCode(
      orderWarehouse,
    );
    final now = DateTime.now();
    final created = <WarehouseConfirmationRequest>[];
    for (final component in catalogItem.components) {
      if (component.code.trim().toUpperCase().startsWith('MOD')) continue;
      if (component.armazem.trim().isEmpty) continue;
      final componentWarehouse = WarehouseRouting.normalizeCode(
        component.armazem,
      );
      if (componentWarehouse == normalizedOrderWarehouse) {
        continue;
      }
      final quantity = component.quantity * order.quantity;
      final request = WarehouseConfirmationRequest(
        id: _idFor(order.number, component.code, componentWarehouse),
        orderNumber: order.number,
        productCode: order.productCode,
        productName: order.productName,
        componentCode: component.code,
        componentDescription: component.description,
        quantity: quantity,
        filial: component.filial.trim().isEmpty ? '04' : component.filial,
        orderWarehouse: normalizedOrderWarehouse,
        requestedWarehouse: componentWarehouse,
        requestedBy: requestedBy.trim(),
        createdAt: now,
        updatedAt: now,
      );
      _upsertLocal(request);
      created.add(request);
    }
    if (created.isNotEmpty) {
      notifyListeners();
      for (final request in created) {
        _save(request);
      }
    }
    return created;
  }

  WarehouseConfirmationRequest createManualRequest({
    required String productCode,
    required String productName,
    required String componentCode,
    required String componentDescription,
    required int quantity,
    required String filial,
    required String orderWarehouse,
    required String requestedWarehouse,
    required String requestedBy,
  }) {
    final now = DateTime.now();
    final request = WarehouseConfirmationRequest(
      id: 'REQ-${now.microsecondsSinceEpoch}-${componentCode.trim().replaceAll(' ', '_')}',
      orderNumber: 'Manual',
      productCode: productCode,
      productName: productName,
      componentCode: componentCode,
      componentDescription: componentDescription,
      quantity: quantity,
      filial: filial.trim().isEmpty ? '04' : filial.trim(),
      orderWarehouse: WarehouseRouting.normalizeCode(orderWarehouse),
      requestedWarehouse: WarehouseRouting.normalizeCode(requestedWarehouse),
      requestedBy: requestedBy.trim(),
      createdAt: now,
      updatedAt: now,
      manual: true,
    );
    _upsertLocal(request);
    notifyListeners();
    _save(request);
    return request;
  }

  void confirm(String id, Operator operator) {
    _respond(
      id,
      WarehouseRequestStatus.confirmed,
      operator: operator,
      note: null,
    );
  }

  void reject(String id, Operator operator, String note) {
    final trimmed = note.trim();
    if (trimmed.isEmpty) {
      throw StateError('Explique por que o saldo não existe no armazém.');
    }
    _respond(
      id,
      WarehouseRequestStatus.rejected,
      operator: operator,
      note: trimmed,
    );
  }

  void _respond(
    String id,
    WarehouseRequestStatus status, {
    required Operator operator,
    required String? note,
  }) {
    final index = _requests.indexWhere((request) => request.id == id);
    if (index == -1) return;
    final updated = _requests[index].copyWith(
      status: status,
      responseBy: () => operator.name,
      responsePin: () => operator.pin,
      responseNote: () => note,
      updatedAt: DateTime.now(),
    );
    _requests[index] = updated;
    notifyListeners();
    _save(updated);
  }

  void _upsertLocal(WarehouseConfirmationRequest request) {
    final index = _requests.indexWhere((item) => item.id == request.id);
    if (index == -1) {
      _requests.insert(0, request);
    } else {
      _requests[index] = request;
    }
  }

  Future<void> _loadFromDatabase() async {
    try {
      final loaded = await database.loadRequests();
      if (loaded.isEmpty) return;
      _requests
        ..clear()
        ..addAll(loaded);
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('Erro ao carregar requisicoes de armazem: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _save(WarehouseConfirmationRequest request) async {
    try {
      await database.saveRequest(request);
    } catch (error, stackTrace) {
      debugPrint('Erro ao salvar requisicao ${request.id}: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  String _idFor(String orderNumber, String componentCode, String warehouse) {
    return '$orderNumber-${componentCode.trim()}-${warehouse.trim()}';
  }
}
