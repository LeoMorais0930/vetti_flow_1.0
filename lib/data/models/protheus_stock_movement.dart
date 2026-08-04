import 'package:vetti_flow_1_0/data/models/production_flow.dart';

class ProtheusStockMovementPlan {
  const ProtheusStockMovementPlan({required this.movements});

  final List<ProtheusStockMovement> movements;

  Map<(String filial, String componentCode, String armazem), num>
  get totalCommittedByBalanceKey {
    final totals = <(String, String, String), num>{};
    for (final movement in movements) {
      if (!movement.affectsStockBalance) continue;
      final key = (movement.filial, movement.componentCode, movement.armazem);
      totals[key] = (totals[key] ?? 0) + movement.quantity;
    }
    return totals;
  }

  static ProtheusStockMovementPlan fromOrder(
    ProductionOrderFlow order,
    ProductionCatalogItem catalogItem,
  ) {
    final operatorName = _operatorName(order.operatorName);
    final operatorPin = _operatorPin(order.operatorPin);
    return ProtheusStockMovementPlan(
      movements: [
        for (var index = 0; index < catalogItem.components.length; index++)
          if (_shouldMove(catalogItem.components[index]))
            ProtheusStockMovement.fromComponent(
              order: order,
              component: catalogItem.components[index],
              structureSequence: (index + 1).toString().padLeft(3, '0'),
              operatorName: operatorName,
              operatorPin: operatorPin,
            ),
      ],
    );
  }

  static bool _shouldMove(ProductionComponent component) {
    if (component.code.trim().isEmpty) return false;
    if (component.armazem.trim().isEmpty) return false;
    return component.quantity > 0;
  }

  static String _operatorName(String? value) {
    final name = value?.trim();
    return name == null || name.isEmpty ? 'VettiFlow' : name;
  }

  static String _operatorPin(String? value) {
    return value?.trim() ?? '';
  }
}

class ProtheusStockCancelationPlan {
  const ProtheusStockCancelationPlan({required this.movements});

  final List<ProtheusStockCancelationMovement> movements;

  Map<(String filial, String componentCode, String armazem), num>
  get totalReleasedByBalanceKey {
    final totals = <(String, String, String), num>{};
    for (final movement in movements) {
      if (!movement.affectsStockBalance) continue;
      final key = (movement.filial, movement.componentCode, movement.armazem);
      totals[key] = (totals[key] ?? 0) + movement.quantity;
    }
    return totals;
  }

  static ProtheusStockCancelationPlan fromOrder(
    ProductionOrderFlow order,
    ProductionCatalogItem catalogItem, {
    Map<String, String> returnWarehouses = const {},
    String? operatorName,
    String? operatorPin,
  }) {
    final signerName = ProtheusStockMovementPlan._operatorName(
      operatorName ?? order.operatorName,
    );
    final signerPin = ProtheusStockMovementPlan._operatorPin(
      operatorPin ?? order.operatorPin,
    );
    return ProtheusStockCancelationPlan(
      movements: [
        for (var index = 0; index < catalogItem.components.length; index++)
          if (ProtheusStockMovementPlan._shouldMove(
            catalogItem.components[index],
          ))
            ProtheusStockCancelationMovement.fromComponent(
              order: order,
              component: catalogItem.components[index],
              structureSequence: (index + 1).toString().padLeft(3, '0'),
              returnWarehouse:
                  returnWarehouses[catalogItem.components[index].code],
              operatorName: signerName,
              operatorPin: signerPin,
            ),
      ],
    );
  }
}

class ProtheusStageTransferMovement {
  const ProtheusStageTransferMovement({
    required this.orderNumber,
    required this.productCode,
    required this.quantity,
    required this.filial,
    required this.fromStage,
    required this.toStage,
    required this.fromWarehouse,
    required this.toWarehouse,
    required this.operatorName,
    required this.operatorPin,
    required this.emissionDate,
  });

  final String orderNumber;
  final String productCode;
  final int quantity;
  final String filial;
  final ProductionStage fromStage;
  final ProductionStage toStage;
  final String fromWarehouse;
  final String toWarehouse;
  final String operatorName;
  final String operatorPin;
  final String emissionDate;

  String get transferId =>
      '$orderNumber-${fromStage.name}-${toStage.name}-$operatorPin';

  bool get movesWarehouseStock =>
      fromWarehouse.isNotEmpty &&
      toWarehouse.isNotEmpty &&
      fromWarehouse != toWarehouse &&
      quantity > 0;

  factory ProtheusStageTransferMovement.fromOrder(
    ProductionOrderFlow order, {
    String filial = '04',
  }) {
    final session =
        order.operatorSessions
            .where((item) => item.completedAt != null)
            .toList()
          ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    final latest = session.isEmpty ? null : session.first;
    return ProtheusStageTransferMovement(
      orderNumber: order.number,
      productCode: order.productCode,
      quantity: order.quantity,
      filial: filial,
      fromStage: latest?.stage ?? order.currentStage,
      toStage: order.currentStage,
      fromWarehouse: _warehouseForStage(latest?.stage ?? order.currentStage),
      toWarehouse: _warehouseForStage(order.currentStage),
      operatorName: latest?.operatorName ?? order.operatorName ?? 'VettiFlow',
      operatorPin: latest?.operatorPin ?? '',
      emissionDate: ProtheusStockMovement._yyyymmdd(order.updatedAt),
    );
  }

  Map<String, dynamic> get sd3Payload => {
    'd3_filial': filial,
    'd3_tm': '000',
    'd3_cod': productCode,
    'd3_um': 'UN',
    'd3_quant': quantity,
    'd3_cf': 'VFT',
    'd3_conta': '',
    'd3_op': orderNumber,
    'd3_local': fromWarehouse,
    'd3_localdest': toWarehouse,
    'd3_doc': orderNumber,
    'd3_emissao': emissionDate,
    'd3_grupo': '',
    'd3_estorno': '',
    'd3_numseq': transferId,
    'd3_usuario': operatorName,
    'd_e_l_e_t_': '',
    'vettiflow_origin': 'stage_transfer',
    'vettiflow_order_number': orderNumber,
    'vettiflow_from_stage': fromStage.name,
    'vettiflow_to_stage': toStage.name,
    'vettiflow_from_warehouse': fromWarehouse,
    'vettiflow_to_warehouse': toWarehouse,
    'vettiflow_operator_name': operatorName,
    'vettiflow_operator_pin': operatorPin,
    'vettiflow_stage_transfer_id': transferId,
  };

  static String _warehouseForStage(ProductionStage stage) {
    return switch (stage) {
      ProductionStage.warehouse => '01',
      ProductionStage.smd => '03',
      ProductionStage.firmware ||
      ProductionStage.soldering ||
      ProductionStage.testing ||
      ProductionStage.closing => '05',
      ProductionStage.expedition || ProductionStage.storage => '10',
      ProductionStage.completed => '',
    };
  }
}

class ProtheusStockCancelationMovement {
  const ProtheusStockCancelationMovement({
    required this.orderNumber,
    required this.productCode,
    required this.componentCode,
    required this.filial,
    required this.armazem,
    required this.returnWarehouse,
    required this.quantity,
    required this.emissionDate,
    required this.structureSequence,
    required this.operatorName,
    required this.operatorPin,
  });

  final String orderNumber;
  final String productCode;
  final String componentCode;
  final String filial;
  final String armazem;
  final String returnWarehouse;
  final num quantity;
  final String emissionDate;
  final String structureSequence;
  final String operatorName;
  final String operatorPin;

  bool get affectsStockBalance =>
      !componentCode.toUpperCase().startsWith('MOD');

  factory ProtheusStockCancelationMovement.fromComponent({
    required ProductionOrderFlow order,
    required ProductionComponent component,
    required String structureSequence,
    String? returnWarehouse,
    required String operatorName,
    required String operatorPin,
  }) {
    final sourceWarehouse = component.armazem.trim();
    final destination = returnWarehouse?.trim();
    return ProtheusStockCancelationMovement(
      orderNumber: order.number,
      productCode: order.productCode,
      componentCode: component.code,
      filial: component.filial.trim().isEmpty ? '04' : component.filial.trim(),
      armazem: sourceWarehouse,
      returnWarehouse: destination == null || destination.isEmpty
          ? sourceWarehouse
          : destination,
      quantity: component.quantity * order.quantity,
      emissionDate: ProtheusStockMovement._yyyymmdd(order.updatedAt),
      structureSequence: structureSequence,
      operatorName: operatorName,
      operatorPin: operatorPin,
    );
  }

  Map<String, dynamic> get sd4CancelPayload => {
    'd4_filial': filial,
    'd4_cod': componentCode,
    'd4_local': armazem,
    'd4_op': orderNumber,
    'd4_data': emissionDate,
    'd4_qsusp': 0,
    'd4_situaca': 'C',
    'd4_qtdeori': quantity,
    'd4_quant': quantity,
    'd4_trt': structureSequence,
    'd4_oporig': '',
    'd4_qtsegum': 0,
    'd4_sldemp': 0,
    'd4_sldemp2': 0,
    'd4_produto': productCode,
    'd4_qtneces': quantity,
    'd_e_l_e_t_': '*',
    'r_e_c_d_e_l_': 0,
    'd4_ok': '',
    'vettiflow_origin': 'op_cancel',
    'vettiflow_order_number': orderNumber,
    'vettiflow_return_warehouse': returnWarehouse,
    'vettiflow_operator_name': operatorName,
    'vettiflow_operator_pin': operatorPin,
  };

  Map<String, dynamic> get sd3Payload => {
    'd3_filial': filial,
    'd3_tm': '999',
    'd3_cod': componentCode,
    'd3_um': '',
    'd3_quant': quantity,
    'd3_cf': 'DE0',
    'd3_conta': '',
    'd3_op': orderNumber,
    'd3_local': armazem,
    'd3_doc': orderNumber,
    'd3_emissao': emissionDate,
    'd3_grupo': '',
    'd3_estorno': 'S',
    'd3_numseq': '$orderNumber-$componentCode-$armazem-cancel',
    'd3_usuario': operatorName,
    'd3_trt': structureSequence,
    'd_e_l_e_t_': '',
    'vettiflow_origin': 'op_cancel',
    'vettiflow_order_number': orderNumber,
    'vettiflow_return_warehouse': returnWarehouse,
    'vettiflow_operator_name': operatorName,
    'vettiflow_operator_pin': operatorPin,
  };
}

class ProtheusStockMovement {
  const ProtheusStockMovement({
    required this.orderNumber,
    required this.productCode,
    required this.componentCode,
    required this.filial,
    required this.armazem,
    required this.quantity,
    required this.emissionDate,
    required this.structureSequence,
    required this.operatorName,
    required this.operatorPin,
  });

  final String orderNumber;
  final String productCode;
  final String componentCode;
  final String filial;
  final String armazem;
  final num quantity;
  final String emissionDate;
  final String structureSequence;
  final String operatorName;
  final String operatorPin;

  bool get affectsStockBalance =>
      !componentCode.toUpperCase().startsWith('MOD');

  factory ProtheusStockMovement.fromComponent({
    required ProductionOrderFlow order,
    required ProductionComponent component,
    required String structureSequence,
    required String operatorName,
    required String operatorPin,
  }) {
    return ProtheusStockMovement(
      orderNumber: order.number,
      productCode: order.productCode,
      componentCode: component.code,
      filial: component.filial.trim().isEmpty ? '04' : component.filial.trim(),
      armazem: component.armazem.trim(),
      quantity: component.quantity * order.quantity,
      emissionDate: _yyyymmdd(order.createdAt),
      structureSequence: structureSequence,
      operatorName: operatorName,
      operatorPin: operatorPin,
    );
  }

  Map<String, dynamic> get sd4Payload => {
    'd4_filial': filial,
    'd4_cod': componentCode,
    'd4_local': armazem,
    'd4_op': orderNumber,
    'd4_data': emissionDate,
    'd4_qsusp': 0,
    'd4_situaca': '',
    'd4_qtdeori': quantity,
    'd4_quant': quantity,
    'd4_trt': structureSequence,
    'd4_oporig': '',
    'd4_qtsegum': 0,
    'd4_sldemp': quantity,
    'd4_sldemp2': quantity,
    'd4_produto': productCode,
    'd4_qtneces': quantity,
    'd_e_l_e_t_': '',
    'r_e_c_d_e_l_': 0,
    'd4_ok': '',
    'vettiflow_origin': 'op_creation',
    'vettiflow_order_number': orderNumber,
    'vettiflow_operator_name': operatorName,
    'vettiflow_operator_pin': operatorPin,
  };

  Map<String, dynamic> get sd3Payload => {
    'd3_filial': filial,
    'd3_tm': '999',
    'd3_cod': componentCode,
    'd3_um': '',
    'd3_quant': quantity,
    'd3_cf': 'RE0',
    'd3_conta': '',
    'd3_op': orderNumber,
    'd3_local': armazem,
    'd3_doc': orderNumber,
    'd3_emissao': emissionDate,
    'd3_grupo': '',
    'd3_estorno': '',
    'd3_numseq': '',
    'd3_usuario': operatorName,
    'd3_trt': structureSequence,
    'd_e_l_e_t_': '',
    'vettiflow_origin': 'op_creation',
    'vettiflow_order_number': orderNumber,
    'vettiflow_operator_name': operatorName,
    'vettiflow_operator_pin': operatorPin,
  };

  Map<String, dynamic> get newSb2Payload => {
    'b2_filial': filial,
    'b2_cod': componentCode,
    'b2_local': armazem,
    'b2_qatu': 0,
    'b2_qemp': quantity,
    'b2_reserva': 0,
    'b2_qfim': 0,
    'b2_dmov': emissionDate,
    'd_e_l_e_t_': '',
    'vettiflow_origin': 'op_creation',
  };

  static String _yyyymmdd(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }
}
