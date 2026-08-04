import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/models/warehouse_routing.dart';

void main() {
  test('routes main Protheus warehouses to VettiFlow screens', () {
    expect(WarehouseRouting.byCode('01')?.area, WorkArea.warehouse);
    expect(WarehouseRouting.stageForWarehouse('01'), WorkStage.warehouse);
    expect(WarehouseRouting.routeForWarehouse('01'), '/almoxarifado');

    final smd = WarehouseRouting.byCode('03');
    expect(smd?.area, WorkArea.smd);
    expect(smd?.responsibleName, 'Paula');
    expect(smd?.primaryStage, WorkStage.smd);
    expect(smd?.hasDedicatedScreen, isTrue);

    expect(WarehouseRouting.byCode('04'), isNull);
    final production = WarehouseRouting.byCode('05');
    expect(production?.area, WorkArea.production);
    expect(production?.stages, [
      WorkStage.firmware,
      WorkStage.soldering,
      WorkStage.testing,
      WorkStage.closing,
    ]);

    expect(WarehouseRouting.stageForWarehouse('06'), WorkStage.support);
    expect(WarehouseRouting.stageForWarehouse('07'), WorkStage.support);
    expect(WarehouseRouting.stageForWarehouse('10'), WorkStage.expedition);
  });

  test('formats warehouse labels with destination context', () {
    expect(
      WarehouseRouting.labelForWarehouse('01'),
      'Armazém 01 - Almoxarifado',
    );
    expect(WarehouseRouting.labelForWarehouse('03'), 'Armazém 03 - SMD');
    expect(WarehouseRouting.labelForWarehouse('10'), 'Armazém 10 - Expedição');
    expect(WarehouseRouting.labelForWarehouse('99'), 'Armazém 99');
  });

  test('limits OP creation warehouses by operator', () {
    expect(WarehouseRouting.warehousesForOperator('Tatiane'), ['05', '10']);
    expect(WarehouseRouting.warehousesForOperator('Andressa'), ['05']);
    expect(WarehouseRouting.warehousesForOperator('Vera'), ['01']);
    expect(WarehouseRouting.warehousesForOperator('Paula'), ['03']);
    expect(WarehouseRouting.warehousesForOperator('Bruno'), ['06', '07']);
    expect(WarehouseRouting.warehousesForOperator('Bruna'), ['10']);
    expect(WarehouseRouting.warehousesForOperator('Tamara'), ['10']);

    expect(WarehouseRouting.canOperatorUseWarehouse('Tatiane', '010'), isTrue);
    expect(WarehouseRouting.canOperatorUseWarehouse('Tatiane', '01'), isFalse);
    expect(WarehouseRouting.canOperatorUseWarehouse('Vera', '05'), isFalse);
  });
}
