import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/protheus_stock_movement.dart';

void main() {
  test(
    'plans SB2, SD3 and SD4 movements for stock components on OP creation',
    () {
      final createdAt = DateTime(2026, 8, 3, 14, 30, 5);
      final order = ProductionOrderFlow(
        number: 'OP-2026-564351',
        productCode: '730-0863',
        productName: 'SMART ALARM - MONITORADA CENTRAL',
        quantity: 5,
        currentStage: ProductionStage.warehouse,
        status: ProductionRunStatus.waiting,
        priority: 'Media',
        createdAt: createdAt,
        updatedAt: createdAt,
        operatorName: 'Tatiane',
        operatorPin: '2001',
        responsavel: 'Tatiane',
      );
      const catalogItem = ProductionCatalogItem(
        code: '730-0863',
        name: 'SMART ALARM - MONITORADA CENTRAL',
        defaultQuantity: 5,
        components: [
          ProductionComponent(
            code: '100-010',
            description: 'PARAFUSO 2,9 X 6,5 MM ZI',
            quantity: 2,
            stock: 3803,
            filial: '04',
            armazem: '05',
            currentStock: 3803,
            committedQuantity: 5284,
            requirementSource: 'SG1',
          ),
          ProductionComponent(
            code: 'MOD-001',
            description: 'MAO DE OBRA',
            quantity: 1,
            stock: -999,
            filial: '04',
            armazem: '05',
          ),
        ],
      );

      final plan = ProtheusStockMovementPlan.fromOrder(order, catalogItem);

      expect(plan.movements, hasLength(2));
      expect(plan.totalCommittedByBalanceKey[('04', '100-010', '05')], 10);
      expect(
        plan.totalCommittedByBalanceKey.containsKey(('04', 'MOD-001', '05')),
        isFalse,
      );

      final movement = plan.movements.firstWhere(
        (item) => item.componentCode == '100-010',
      );
      expect(movement.quantity, 10);
      expect(movement.affectsStockBalance, isTrue);
      expect(movement.emissionDate, '20260803');

      expect(movement.sd4Payload['d4_filial'], '04');
      expect(movement.sd4Payload['d4_op'], 'OP-2026-564351');
      expect(movement.sd4Payload['d4_produto'], '730-0863');
      expect(movement.sd4Payload['d4_cod'], '100-010');
      expect(movement.sd4Payload['d4_local'], '05');
      expect(movement.sd4Payload['d4_quant'], 10);
      expect(movement.sd4Payload['d4_sldemp'], 10);
      expect(movement.sd4Payload['vettiflow_order_number'], 'OP-2026-564351');
      expect(movement.sd4Payload['vettiflow_operator_name'], 'Tatiane');
      expect(movement.sd4Payload['vettiflow_operator_pin'], '2001');

      expect(movement.sd3Payload['d3_filial'], '04');
      expect(movement.sd3Payload['d3_op'], 'OP-2026-564351');
      expect(movement.sd3Payload['d3_cod'], '100-010');
      expect(movement.sd3Payload['d3_local'], '05');
      expect(movement.sd3Payload['d3_quant'], 10);
      expect(movement.sd3Payload['d3_cf'], 'RE0');
      expect(movement.sd3Payload['d3_doc'], 'OP-2026-564351');
      expect(movement.sd3Payload['d3_usuario'], 'Tatiane');
      expect(movement.sd3Payload['vettiflow_operator_pin'], '2001');

      final modMovement = plan.movements.firstWhere(
        (item) => item.componentCode == 'MOD-001',
      );
      expect(modMovement.quantity, 5);
      expect(modMovement.affectsStockBalance, isFalse);
      expect(modMovement.sd4Payload['d4_cod'], 'MOD-001');
      expect(modMovement.sd4Payload['d4_quant'], 5);
    },
  );

  test(
    'uses the selected component warehouse in SB2, SD3 and SD4 movements',
    () {
      final createdAt = DateTime(2026, 8, 4, 9, 10);
      final order = ProductionOrderFlow(
        number: 'OP-2026-564999',
        productCode: '730-0863',
        productName: 'SMART ALARM - MONITORADA CENTRAL',
        quantity: 4,
        currentStage: ProductionStage.warehouse,
        status: ProductionRunStatus.waiting,
        priority: 'Media',
        createdAt: createdAt,
        updatedAt: createdAt,
        responsavel: 'Tatiane',
      );
      const catalogItem = ProductionCatalogItem(
        code: '730-0863',
        name: 'SMART ALARM - MONITORADA CENTRAL',
        defaultQuantity: 4,
        components: [
          ProductionComponent(
            code: '100-010',
            description: 'PARAFUSO 2,9 X 6,5 MM ZI',
            quantity: 3,
            stock: 7514,
            filial: '04',
            armazem: '01',
            currentStock: 7514,
            requirementSource: 'SG1',
          ),
        ],
      );

      final plan = ProtheusStockMovementPlan.fromOrder(order, catalogItem);
      final movement = plan.movements.single;

      expect(plan.totalCommittedByBalanceKey[('04', '100-010', '01')], 12);
      expect(
        plan.totalCommittedByBalanceKey.containsKey(('04', '100-010', '05')),
        isFalse,
      );
      expect(movement.sd4Payload['d4_local'], '01');
      expect(movement.sd3Payload['d3_local'], '01');
      expect(movement.newSb2Payload['b2_local'], '01');
    },
  );

  test('plans SD3 audit movement for stage transfer signature', () {
    final updatedAt = DateTime(2026, 8, 4, 10, 45);
    final order = ProductionOrderFlow(
      number: 'OP-2026-565000',
      productCode: '730-0863',
      productName: 'SMART ALARM - MONITORADA CENTRAL',
      quantity: 5,
      currentStage: ProductionStage.smd,
      status: ProductionRunStatus.waiting,
      priority: 'Media',
      createdAt: DateTime(2026, 8, 4, 9),
      updatedAt: updatedAt,
      operatorSessions: [
        ProductionOperatorSession(
          stage: ProductionStage.warehouse,
          operatorName: 'Vera',
          operatorPin: '4003',
          startedAt: DateTime(2026, 8, 4, 10),
          completedAt: updatedAt,
        ),
      ],
    );

    final movement = ProtheusStageTransferMovement.fromOrder(order);

    expect(movement.transferId, 'OP-2026-565000-warehouse-smd-4003');
    expect(movement.fromWarehouse, '01');
    expect(movement.toWarehouse, '03');
    expect(movement.movesWarehouseStock, isTrue);
    expect(movement.sd3Payload['d3_filial'], '04');
    expect(movement.sd3Payload['d3_op'], 'OP-2026-565000');
    expect(movement.sd3Payload['d3_cod'], '730-0863');
    expect(movement.sd3Payload['d3_cf'], 'VFT');
    expect(movement.sd3Payload['d3_local'], '01');
    expect(movement.sd3Payload['d3_localdest'], '03');
    expect(movement.sd3Payload['d3_usuario'], 'Vera');
    expect(movement.sd3Payload['vettiflow_origin'], 'stage_transfer');
    expect(movement.sd3Payload['vettiflow_from_stage'], 'warehouse');
    expect(movement.sd3Payload['vettiflow_to_stage'], 'smd');
    expect(movement.sd3Payload['vettiflow_from_warehouse'], '01');
    expect(movement.sd3Payload['vettiflow_to_warehouse'], '03');
    expect(movement.sd3Payload['vettiflow_operator_pin'], '4003');
  });

  test(
    'does not move SB2 stock between production stages in same warehouse',
    () {
      final updatedAt = DateTime(2026, 8, 4, 13, 20);
      final order = ProductionOrderFlow(
        number: 'OP-2026-565001',
        productCode: '730-0863',
        productName: 'SMART ALARM - MONITORADA CENTRAL',
        quantity: 5,
        currentStage: ProductionStage.soldering,
        status: ProductionRunStatus.waiting,
        priority: 'Media',
        createdAt: DateTime(2026, 8, 4, 9),
        updatedAt: updatedAt,
        operatorSessions: [
          ProductionOperatorSession(
            stage: ProductionStage.firmware,
            operatorName: 'Tatiane',
            operatorPin: '2001',
            startedAt: DateTime(2026, 8, 4, 12),
            completedAt: updatedAt,
          ),
        ],
      );

      final movement = ProtheusStageTransferMovement.fromOrder(order);

      expect(movement.fromWarehouse, '05');
      expect(movement.toWarehouse, '05');
      expect(movement.movesWarehouseStock, isFalse);
      expect(movement.sd3Payload['d3_local'], '05');
      expect(movement.sd3Payload['d3_localdest'], '05');
    },
  );

  test('plans SB2, SD3 and SD4 reversal movements for OP cancelation', () {
    final createdAt = DateTime(2026, 8, 4, 9, 10);
    final canceledAt = DateTime(2026, 8, 4, 11, 20);
    final order = ProductionOrderFlow(
      number: 'OP-2026-565111',
      productCode: '730-0863',
      productName: 'SMART ALARM - MONITORADA CENTRAL',
      quantity: 4,
      currentStage: ProductionStage.warehouse,
      status: ProductionRunStatus.waiting,
      priority: 'Media',
      createdAt: createdAt,
      updatedAt: canceledAt,
      operatorName: 'Tatiane',
      operatorPin: '2001',
    );
    const catalogItem = ProductionCatalogItem(
      code: '730-0863',
      name: 'SMART ALARM - MONITORADA CENTRAL',
      defaultQuantity: 4,
      components: [
        ProductionComponent(
          code: '100-010',
          description: 'PARAFUSO 2,9 X 6,5 MM ZI',
          quantity: 3,
          stock: 7514,
          filial: '04',
          armazem: '01',
          currentStock: 7514,
          requirementSource: 'SG1',
        ),
        ProductionComponent(
          code: 'MOD-001',
          description: 'MAO DE OBRA',
          quantity: 1,
          stock: -999,
          filial: '04',
          armazem: '05',
        ),
      ],
    );

    final plan = ProtheusStockCancelationPlan.fromOrder(
      order,
      catalogItem,
      returnWarehouses: const {'100-010': '05'},
      operatorName: 'Vera',
      operatorPin: '4003',
    );

    expect(plan.movements, hasLength(2));
    expect(plan.totalReleasedByBalanceKey[('04', '100-010', '01')], 12);
    expect(
      plan.totalReleasedByBalanceKey.containsKey(('04', 'MOD-001', '05')),
      isFalse,
    );

    final movement = plan.movements.firstWhere(
      (item) => item.componentCode == '100-010',
    );
    expect(movement.quantity, 12);
    expect(movement.armazem, '01');
    expect(movement.returnWarehouse, '05');
    expect(movement.emissionDate, '20260804');
    expect(movement.sd4CancelPayload['d4_sldemp'], 0);
    expect(movement.sd4CancelPayload['d_e_l_e_t_'], '*');
    expect(movement.sd4CancelPayload['vettiflow_origin'], 'op_cancel');
    expect(movement.sd4CancelPayload['vettiflow_operator_name'], 'Vera');
    expect(movement.sd4CancelPayload['vettiflow_operator_pin'], '4003');
    expect(movement.sd3Payload['d3_cf'], 'DE0');
    expect(movement.sd3Payload['d3_estorno'], 'S');
    expect(movement.sd3Payload['d3_local'], '01');
    expect(movement.sd3Payload['d3_usuario'], 'Vera');
    expect(movement.sd3Payload['vettiflow_return_warehouse'], '05');
    expect(movement.sd3Payload['vettiflow_origin'], 'op_cancel');
    expect(movement.sd3Payload['vettiflow_operator_pin'], '4003');
  });
}
