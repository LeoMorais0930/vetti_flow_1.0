import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/models/warehouse_routing.dart';

enum WarehouseRequestStatus { pending, confirmed, rejected }

class WarehouseConfirmationRequest {
  const WarehouseConfirmationRequest({
    required this.id,
    required this.orderNumber,
    required this.productCode,
    required this.productName,
    required this.componentCode,
    required this.componentDescription,
    required this.quantity,
    required this.filial,
    required this.orderWarehouse,
    required this.requestedWarehouse,
    required this.requestedBy,
    required this.createdAt,
    required this.updatedAt,
    this.status = WarehouseRequestStatus.pending,
    this.responseBy,
    this.responsePin,
    this.responseNote,
    this.manual = false,
  });

  final String id;
  final String orderNumber;
  final String productCode;
  final String productName;
  final String componentCode;
  final String componentDescription;
  final int quantity;
  final String filial;
  final String orderWarehouse;
  final String requestedWarehouse;
  final String requestedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final WarehouseRequestStatus status;
  final String? responseBy;
  final String? responsePin;
  final String? responseNote;
  final bool manual;

  String get warehouseLabel =>
      WarehouseRouting.labelForWarehouse(requestedWarehouse);

  String get orderWarehouseLabel =>
      WarehouseRouting.labelForWarehouse(orderWarehouse);

  WorkArea? get area => WarehouseRouting.byCode(requestedWarehouse)?.area;

  bool get isPending => status == WarehouseRequestStatus.pending;

  WarehouseConfirmationRequest copyWith({
    WarehouseRequestStatus? status,
    String? Function()? responseBy,
    String? Function()? responsePin,
    String? Function()? responseNote,
    DateTime? updatedAt,
  }) {
    return WarehouseConfirmationRequest(
      id: id,
      orderNumber: orderNumber,
      productCode: productCode,
      productName: productName,
      componentCode: componentCode,
      componentDescription: componentDescription,
      quantity: quantity,
      filial: filial,
      orderWarehouse: orderWarehouse,
      requestedWarehouse: requestedWarehouse,
      requestedBy: requestedBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      responseBy: responseBy != null ? responseBy() : this.responseBy,
      responsePin: responsePin != null ? responsePin() : this.responsePin,
      responseNote: responseNote != null ? responseNote() : this.responseNote,
      manual: manual,
    );
  }
}
