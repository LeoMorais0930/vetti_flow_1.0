import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/protheus_stock_movement.dart';
import 'package:vetti_flow_1_0/data/repositories/postgres_settings.dart';

class ProductionFlowSnapshot {
  const ProductionFlowSnapshot({
    required this.orders,
    required this.catalogItems,
  });

  final List<ProductionOrderFlow> orders;
  final List<ProductionCatalogItem> catalogItems;
}

abstract class ProductionFlowDatabase {
  Future<ProductionFlowSnapshot> loadSnapshot();

  /// Proximo numero de OP, reservado no banco.
  ///
  /// Devolve `null` quando nao ha banco para reservar (offline, ou o
  /// [EmptyProductionFlowDatabase] dos testes); nesse caso quem chama cai no
  /// contador local. Com o banco de pe o numero e unico entre todas as
  /// maquinas que compartilham o Postgres.
  Future<int?> nextOrderSequence();

  Future<void> saveOrder(
    ProductionOrderFlow order,
    ProductionCatalogItem catalogItem, {
    required String eventType,
  });
  Future<void> deleteOrder(
    String number, {
    ProductionOrderFlow? order,
    ProductionCatalogItem? catalogItem,
    Map<String, String> returnWarehouses = const {},
    String? operatorName,
    String? operatorPin,
  });
}

class EmptyProductionFlowDatabase implements ProductionFlowDatabase {
  const EmptyProductionFlowDatabase();

  @override
  Future<void> deleteOrder(
    String number, {
    ProductionOrderFlow? order,
    ProductionCatalogItem? catalogItem,
    Map<String, String> returnWarehouses = const {},
    String? operatorName,
    String? operatorPin,
  }) async {}

  @override
  Future<ProductionFlowSnapshot> loadSnapshot() async {
    return const ProductionFlowSnapshot(orders: [], catalogItems: []);
  }

  @override
  Future<int?> nextOrderSequence() async => null;

  @override
  Future<void> saveOrder(
    ProductionOrderFlow order,
    ProductionCatalogItem catalogItem, {
    required String eventType,
  }) async {}
}

class PostgresProductionFlowDatabase implements ProductionFlowDatabase {
  PostgresProductionFlowDatabase({
    this.host = PostgresSettings.defaultHost,
    this.port = PostgresSettings.defaultPort,
    this.database = PostgresSettings.defaultDatabase,
    this.username = PostgresSettings.defaultUsername,
    this.password = PostgresSettings.defaultPassword,
  });

  final String host;
  final int port;
  final String database;
  final String username;
  final String password;

  static const _protheusSc2 = 'protheus_raw.sc2_orders';
  static const _protheusSd3 = 'protheus_raw.sd3_movements';
  static const _protheusSd4 = 'protheus_raw.sd4_commitments';
  static const _protheusSb2 = 'protheus_raw.sb2_balances';

  Connection? _connection;
  bool _schemaChecked = false;

  @override
  Future<ProductionFlowSnapshot> loadSnapshot() async {
    final conn = await _open();
    final orderRows = await conn.execute('''
        SELECT *
        FROM vettiflow.production_orders
        ORDER BY updated_at DESC
      ''', timeout: const Duration(seconds: 8));
    if (orderRows.isEmpty) {
      return const ProductionFlowSnapshot(orders: [], catalogItems: []);
    }

    final componentRows = await conn.execute('''
        SELECT *
        FROM vettiflow.production_components
        ORDER BY order_number, structure_sequence, component_code
      ''', timeout: const Duration(seconds: 8));
    final timingRows = await conn.execute(
      'SELECT * FROM vettiflow.production_stage_timings',
      timeout: const Duration(seconds: 8),
    );
    final sessionRows = await conn.execute(
      'SELECT * FROM vettiflow.production_operator_sessions',
      timeout: const Duration(seconds: 8),
    );
    final pauseRows = await conn.execute(
      'SELECT * FROM vettiflow.production_pause_events',
      timeout: const Duration(seconds: 8),
    );
    final defectRows = await conn.execute(
      'SELECT * FROM vettiflow.production_defects',
      timeout: const Duration(seconds: 8),
    );

    final componentsByOrder = <String, List<ProductionComponent>>{};
    for (final row in componentRows) {
      final data = row.toColumnMap();
      final orderNumber = _text(data['order_number']);
      componentsByOrder
          .putIfAbsent(orderNumber, () => [])
          .add(_componentFrom(data));
    }

    final timingsByOrder =
        _groupByOrder<(ProductionStage, ProductionStageTiming)>(
          timingRows,
          _timingFrom,
        );
    final sessionsByOrder = _groupByOrder<ProductionOperatorSession>(
      sessionRows,
      _sessionFrom,
    );
    final pausesByOrder = _groupByOrder<ProductionPauseEvent>(
      pauseRows,
      _pauseFrom,
    );
    final defectsByOrder = _groupByOrder<DefectRecord>(defectRows, _defectFrom);

    final orders = orderRows.map((row) {
      final data = row.toColumnMap();
      final number = _text(data['number']);
      return ProductionOrderFlow(
        number: number,
        productCode: _text(data['product_code']),
        productName: _text(data['product_name']),
        quantity: _int(data['quantity']),
        currentStage: _stageFrom(_text(data['current_stage'])),
        status: _statusFrom(_text(data['run_status'])),
        priority: _text(data['priority'], fallback: 'Media'),
        createdAt: _date(data['created_at']) ?? DateTime.now(),
        updatedAt: _date(data['updated_at']) ?? DateTime.now(),
        operatorName: _nullableText(data['operator_name']),
        operatorPin: _nullableText(data['operator_pin_hash']),
        responsavel: _nullableText(data['responsavel']),
        prazo: _formatDate(data['due_date']),
        orderWarehouse: _text(data['order_warehouse']),
        closedQuantity: _int(data['closed_quantity']),
        lastObservation: _nullableText(data['last_observation']),
        plannedStages: _stagesFromJson(data['planned_stages']),
        storedQuantity: _int(data['stored_quantity']),
        dispatchedQuantity: _int(data['dispatched_quantity']),
        timings: timingsByOrder[number] == null
            ? const {}
            : {
                for (final timing in timingsByOrder[number]!)
                  timing.$1: timing.$2,
              },
        testDefects: defectsByOrder[number] ?? const [],
        operatorSessions: sessionsByOrder[number] ?? const [],
        pauseEvents: pausesByOrder[number] ?? const [],
      );
    }).toList();

    final catalogItems = orders.map((order) {
      return ProductionCatalogItem(
        code: order.productCode,
        name: order.productName,
        defaultQuantity: order.quantity,
        unit: 'PC',
        components: componentsByOrder[order.number] ?? const [],
      );
    }).toList();

    return ProductionFlowSnapshot(orders: orders, catalogItems: catalogItems);
  }

  @override
  Future<int?> nextOrderSequence() async {
    final conn = await _open();
    final rows = await conn.execute(
      "SELECT nextval('vettiflow.production_order_number_seq') AS value",
      timeout: const Duration(seconds: 8),
    );
    final value = rows.first.toColumnMap()['value'];
    if (value is int) return value;
    if (value is BigInt) return value.toInt();
    return int.tryParse('$value');
  }

  @override
  Future<void> saveOrder(
    ProductionOrderFlow order,
    ProductionCatalogItem catalogItem, {
    required String eventType,
  }) async {
    final conn = await _open();
    await conn.runTx((tx) async {
      await tx.execute(
        Sql.named('''
          INSERT INTO vettiflow.production_orders (
            number,
            product_code,
            product_name,
            quantity,
            current_stage,
            run_status,
            op_status,
            priority,
            progress_percent,
            responsavel,
            operator_name,
            operator_pin_hash,
            order_warehouse,
            opened_at,
            due_date,
            month_label,
            is_late,
            closed_quantity,
            stored_quantity,
            dispatched_quantity,
            last_observation,
            planned_stages,
            created_at,
            updated_at,
            synchronized_at
          )
          VALUES (
            @number,
            @product_code,
            @product_name,
            @quantity,
            CAST(@current_stage AS vettiflow.production_stage),
            CAST(@run_status AS vettiflow.production_run_status),
            CAST(@op_status AS vettiflow.status_op),
            @priority,
            @progress_percent,
            @responsavel,
            @operator_name,
            @operator_pin_hash,
            @order_warehouse,
            @opened_at,
            @due_date,
            @month_label,
            @is_late,
            @closed_quantity,
            @stored_quantity,
            @dispatched_quantity,
            @last_observation,
            CAST(@planned_stages AS jsonb),
            @created_at,
            @updated_at,
            now()
          )
          ON CONFLICT (number) DO UPDATE SET
            product_code = EXCLUDED.product_code,
            product_name = EXCLUDED.product_name,
            quantity = EXCLUDED.quantity,
            current_stage = EXCLUDED.current_stage,
            run_status = EXCLUDED.run_status,
            op_status = EXCLUDED.op_status,
            priority = EXCLUDED.priority,
            progress_percent = EXCLUDED.progress_percent,
            responsavel = EXCLUDED.responsavel,
            operator_name = EXCLUDED.operator_name,
            operator_pin_hash = EXCLUDED.operator_pin_hash,
            order_warehouse = EXCLUDED.order_warehouse,
            opened_at = EXCLUDED.opened_at,
            due_date = EXCLUDED.due_date,
            month_label = EXCLUDED.month_label,
            is_late = EXCLUDED.is_late,
            closed_quantity = EXCLUDED.closed_quantity,
            stored_quantity = EXCLUDED.stored_quantity,
            dispatched_quantity = EXCLUDED.dispatched_quantity,
            last_observation = EXCLUDED.last_observation,
            planned_stages = EXCLUDED.planned_stages,
            updated_at = EXCLUDED.updated_at,
            synchronized_at = now()
        '''),
        parameters: _orderParameters(order),
      );

      await tx.execute(
        Sql.named(
          'DELETE FROM vettiflow.production_components WHERE order_number = @number',
        ),
        parameters: {'number': order.number},
      );
      for (final component in catalogItem.components) {
        await tx.execute(
          Sql.named('''
            INSERT INTO vettiflow.production_components (
              order_number,
              component_code,
              description,
              quantity,
              stock,
              filial,
              armazem,
              current_stock,
              committed_quantity,
              reserved_quantity,
              requirement_source,
              source_order,
              commitment_date,
              original_quantity,
              commitment_quantity,
              structure_sequence
            )
            VALUES (
              @order_number,
              @component_code,
              @description,
              @quantity,
              @stock,
              @filial,
              @armazem,
              @current_stock,
              @committed_quantity,
              @reserved_quantity,
              @requirement_source,
              @source_order,
              @commitment_date,
              @original_quantity,
              @commitment_quantity,
              @structure_sequence
            )
          '''),
          parameters: {
            'order_number': order.number,
            'component_code': component.code,
            'description': component.description,
            'quantity': component.quantity,
            'stock': component.stock,
            'filial': component.filial,
            'armazem': component.armazem,
            'current_stock': component.currentStock,
            'committed_quantity': component.committedQuantity,
            'reserved_quantity': component.reservedQuantity,
            'requirement_source': component.requirementSource,
            'source_order': component.sourceOrder,
            'commitment_date': component.commitmentDate,
            'original_quantity': component.originalQuantity,
            'commitment_quantity': component.commitmentQuantity,
            'structure_sequence': component.structureSequence,
          },
        );
      }

      await _replaceTimings(tx, order);
      await _replaceSessions(tx, order);
      await _replacePauses(tx, order);
      await _replaceDefects(tx, order);
      await _insertEvent(tx, order, eventType);
      if (eventType == 'created') {
        await _applyProtheusMovements(tx, order, catalogItem);
      } else if (order.isDone) {
        await _applyProtheusCompletion(tx, order, catalogItem);
      }
    });
  }

  @override
  Future<void> deleteOrder(
    String number, {
    ProductionOrderFlow? order,
    ProductionCatalogItem? catalogItem,
    Map<String, String> returnWarehouses = const {},
    String? operatorName,
    String? operatorPin,
  }) async {
    final conn = await _open();
    await conn.runTx((tx) async {
      if (order != null && catalogItem != null) {
        await _applyProtheusCancelation(
          tx,
          order,
          catalogItem,
          returnWarehouses: returnWarehouses,
          operatorName: operatorName,
          operatorPin: operatorPin,
        );
      }
      await tx.execute(
        Sql.named(
          'DELETE FROM vettiflow.production_orders WHERE number = @number',
        ),
        parameters: {'number': number},
        timeout: const Duration(seconds: 8),
      );
    });
  }

  Future<void> _replaceTimings(Session tx, ProductionOrderFlow order) async {
    await tx.execute(
      Sql.named(
        'DELETE FROM vettiflow.production_stage_timings WHERE order_number = @number',
      ),
      parameters: {'number': order.number},
    );
    for (final entry in order.timings.entries) {
      final timing = entry.value;
      await tx.execute(
        Sql.named('''
          INSERT INTO vettiflow.production_stage_timings (
            order_number,
            stage,
            started_at,
            completed_at,
            paused_at,
            paused_duration_ms
          )
          VALUES (
            @order_number,
            CAST(@stage AS vettiflow.production_stage),
            @started_at,
            @completed_at,
            @paused_at,
            @paused_duration_ms
          )
        '''),
        parameters: {
          'order_number': order.number,
          'stage': entry.key.name,
          'started_at': timing.startedAt,
          'completed_at': timing.completedAt,
          'paused_at': timing.pausedAt,
          'paused_duration_ms': timing.pausedDuration.inMilliseconds,
        },
      );
    }
  }

  Future<void> _replaceSessions(Session tx, ProductionOrderFlow order) async {
    await tx.execute(
      Sql.named(
        'DELETE FROM vettiflow.production_operator_sessions WHERE order_number = @number',
      ),
      parameters: {'number': order.number},
    );
    for (final session in order.operatorSessions) {
      await tx.execute(
        Sql.named('''
          INSERT INTO vettiflow.production_operator_sessions (
            order_number,
            stage,
            operator_name,
            operator_pin_hash,
            started_at,
            completed_at,
            paused_at,
            paused_duration_ms,
            produced_quantity
          )
          VALUES (
            @order_number,
            CAST(@stage AS vettiflow.production_stage),
            @operator_name,
            @operator_pin_hash,
            @started_at,
            @completed_at,
            @paused_at,
            @paused_duration_ms,
            @produced_quantity
          )
        '''),
        parameters: {
          'order_number': order.number,
          'stage': session.stage.name,
          'operator_name': session.operatorName,
          'operator_pin_hash': session.operatorPin,
          'started_at': session.startedAt,
          'completed_at': session.completedAt,
          'paused_at': session.pausedAt,
          'paused_duration_ms': session.pausedDuration.inMilliseconds,
          'produced_quantity': session.producedQuantity,
        },
      );
    }
  }

  Future<void> _replacePauses(Session tx, ProductionOrderFlow order) async {
    await tx.execute(
      Sql.named(
        'DELETE FROM vettiflow.production_pause_events WHERE order_number = @number',
      ),
      parameters: {'number': order.number},
    );
    for (final pause in order.pauseEvents) {
      await tx.execute(
        Sql.named('''
          INSERT INTO vettiflow.production_pause_events (
            order_number,
            stage,
            operator_name,
            operator_pin_hash,
            reason,
            custom_reason,
            produced_quantity,
            created_at,
            resumed_at
          )
          VALUES (
            @order_number,
            CAST(@stage AS vettiflow.production_stage),
            @operator_name,
            @operator_pin_hash,
            @reason,
            @custom_reason,
            @produced_quantity,
            @created_at,
            @resumed_at
          )
        '''),
        parameters: {
          'order_number': order.number,
          'stage': pause.stage.name,
          'operator_name': pause.operatorName,
          'operator_pin_hash': pause.operatorPin,
          'reason': pause.reason.name,
          'custom_reason': pause.customReason,
          'produced_quantity': pause.producedQuantity,
          'created_at': pause.createdAt,
          'resumed_at': pause.resumedAt,
        },
      );
    }
  }

  Future<void> _replaceDefects(Session tx, ProductionOrderFlow order) async {
    await tx.execute(
      Sql.named(
        'DELETE FROM vettiflow.production_defects WHERE order_number = @number',
      ),
      parameters: {'number': order.number},
    );
    for (final defect in order.testDefects) {
      await tx.execute(
        Sql.named('''
          INSERT INTO vettiflow.production_defects (
            order_number,
            code,
            title,
            quantity
          )
          VALUES (
            @order_number,
            @code,
            @title,
            @quantity
          )
        '''),
        parameters: {
          'order_number': order.number,
          'code': defect.code,
          'title': defect.title,
          'quantity': defect.quantity,
        },
      );
    }
  }

  Future<void> _insertEvent(
    Session tx,
    ProductionOrderFlow order,
    String eventType,
  ) async {
    await tx.execute(
      Sql.named('''
        INSERT INTO vettiflow.production_flow_events (
          order_number,
          event_type,
          stage,
          run_status,
          payload
        )
        VALUES (
          @order_number,
          @event_type,
          CAST(@stage AS vettiflow.production_stage),
          CAST(@run_status AS vettiflow.production_run_status),
          CAST(@payload AS jsonb)
        )
      '''),
      parameters: {
        'order_number': order.number,
        'event_type': eventType,
        'stage': order.currentStage.name,
        'run_status': order.status.name,
        'payload': jsonEncode(_eventPayload(order)),
      },
    );
  }

  Future<void> _applyProtheusMovements(
    Session tx,
    ProductionOrderFlow order,
    ProductionCatalogItem catalogItem,
  ) async {
    await _insertSc2Order(
      tx,
      ProtheusProductionOrder.fromOrder(order, unit: catalogItem.unit),
    );

    final existing = await tx.execute(
      Sql.named('''
        SELECT 1
        FROM protheus_raw.sd4_commitments
        WHERE payload ->> 'vettiflow_order_number' = @order_number
        LIMIT 1
      '''),
      parameters: {'order_number': order.number},
    );
    if (existing.isNotEmpty) return;

    final plan = ProtheusStockMovementPlan.fromOrder(order, catalogItem);
    for (final movement in plan.movements) {
      await _insertSd4Commitment(tx, movement);
      if (movement.affectsStockBalance) {
        await _increaseSb2Commitment(tx, movement);
      }
    }
  }

  Future<void> _insertSc2Order(
    Session tx,
    ProtheusProductionOrder order,
  ) async {
    final payload = await _withNextRecno(tx, _protheusSc2, order.sc2Payload);
    await tx.execute(
      Sql.named('''
        INSERT INTO protheus_raw.sc2_orders (payload)
        SELECT CAST(@payload AS jsonb)
        WHERE NOT EXISTS (
          SELECT 1
          FROM protheus_raw.sc2_orders
          WHERE (
              payload ->> 'vettiflow_order_number' = @order_number
              OR (
                c2_filial = @filial
                AND c2_num = @numero
                AND c2_item = @item
                AND c2_sequen = @sequencia
              )
            )
            AND COALESCE(payload ->> 'd_e_l_e_t_', '') <> '*'
        )
      '''),
      parameters: {
        'payload': jsonEncode(payload),
        'order_number': order.orderNumber,
        'filial': payload['c2_filial'],
        'numero': payload['c2_num'],
        'item': payload['c2_item'],
        'sequencia': payload['c2_sequen'],
      },
    );
  }

  Future<void> _increaseSb2Commitment(
    Session tx,
    ProtheusStockMovement movement,
  ) async {
    final updated = await tx.execute(
      Sql.named('''
        UPDATE protheus_raw.sb2_balances
        SET payload = jsonb_set(
          jsonb_set(
            jsonb_set(
              payload,
              '{b2_qemp}',
              to_jsonb(
                COALESCE(NULLIF(trim(payload ->> 'b2_qemp'), '')::numeric, 0)
                + CAST(@quantity AS numeric)
              ),
              true
            ),
            '{b2_dmov}',
            to_jsonb(CAST(@emission_date AS text)),
            true
          ),
          '{vettiflow_last_order_number}',
          to_jsonb(CAST(@order_number AS text)),
          true
        )
        WHERE b2_filial = @filial
          AND b2_cod = @component_code
          AND b2_local = @armazem
          AND COALESCE(payload ->> 'd_e_l_e_t_', '') <> '*'
        RETURNING id
      '''),
      parameters: {
        'quantity': movement.quantity,
        'emission_date': movement.emissionDate,
        'order_number': movement.orderNumber,
        'filial': movement.filial,
        'component_code': movement.componentCode,
        'armazem': movement.armazem,
      },
    );
    if (updated.isNotEmpty) return;

    final payload = await _withNextRecno(
      tx,
      _protheusSb2,
      movement.newSb2Payload,
    );
    await tx.execute(
      Sql.named('''
        INSERT INTO protheus_raw.sb2_balances (payload)
        VALUES (CAST(@payload AS jsonb))
      '''),
      parameters: {'payload': jsonEncode(payload)},
    );
  }

  Future<void> _insertSd4Commitment(
    Session tx,
    ProtheusStockMovement movement,
  ) async {
    final payload = await _withNextRecno(tx, _protheusSd4, movement.sd4Payload);
    await tx.execute(
      Sql.named('''
        INSERT INTO protheus_raw.sd4_commitments (payload)
        SELECT CAST(@payload AS jsonb)
        WHERE NOT EXISTS (
          SELECT 1
          FROM protheus_raw.sd4_commitments
          WHERE payload ->> 'vettiflow_order_number' = @order_number
            AND d4_cod = @component_code
            AND d4_local = @armazem
            AND COALESCE(payload ->> 'd_e_l_e_t_', '') <> '*'
        )
      '''),
      parameters: {
        'payload': jsonEncode(payload),
        'order_number': movement.orderNumber,
        'component_code': movement.componentCode,
        'armazem': movement.armazem,
      },
    );
  }

  Future<Map<String, dynamic>> _withNextRecno(
    Session tx,
    String table,
    Map<String, dynamic> payload,
  ) async {
    if (_int(payload['r_e_c_n_o_']) > 0) return payload;
    final tableName = switch (table) {
      _protheusSc2 => _protheusSc2,
      _protheusSd3 => _protheusSd3,
      _protheusSd4 => _protheusSd4,
      _protheusSb2 => _protheusSb2,
      _ => throw ArgumentError.value(table, 'table', 'Tabela nao permitida'),
    };
    await tx.execute(
      'LOCK TABLE $tableName IN SHARE ROW EXCLUSIVE MODE',
      timeout: const Duration(seconds: 8),
    );
    final rows = await tx.execute('''
        SELECT COALESCE(MAX(id), 0)::int + 1 AS next_recno
        FROM $tableName
      ''', timeout: const Duration(seconds: 8));
    return {
      ...payload,
      'r_e_c_n_o_': _int(rows.single.toColumnMap()['next_recno']),
    };
  }

  Future<void> _applyProtheusCompletion(
    Session tx,
    ProductionOrderFlow order,
    ProductionCatalogItem catalogItem,
  ) async {
    final existing = await tx.execute(
      Sql.named('''
        SELECT 1
        FROM protheus_raw.sd3_movements
        WHERE payload ->> 'vettiflow_order_number' = @order_number
          AND payload ->> 'vettiflow_origin' = 'op_completion'
        LIMIT 1
      '''),
      parameters: {'order_number': order.number},
    );
    if (existing.isNotEmpty) return;

    final plan = ProtheusProductionCompletionPlan.fromOrder(order, catalogItem);
    await _finishSc2Order(tx, plan.finishedProduct);
    await _insertSd3Movement(tx, plan.finishedProduct.sd3Payload, sequence: '');
    await _increaseSb2CurrentStock(tx, plan.finishedProduct);

    for (final movement in plan.consumptions) {
      await _closeSd4Commitment(tx, movement);
      if (!movement.affectsStockBalance) continue;
      await _insertSd3Movement(
        tx,
        movement.sd3Payload,
        sequence: movement.structureSequence,
      );
      await _decreaseSb2CurrentAndCommitment(tx, movement);
    }
  }

  Future<void> _finishSc2Order(
    Session tx,
    ProtheusFinishedProductMovement movement,
  ) async {
    await tx.execute(
      Sql.named('''
        UPDATE protheus_raw.sc2_orders
        SET payload = jsonb_set(
          jsonb_set(
            jsonb_set(
              jsonb_set(
                payload,
                '{c2_quje}',
                to_jsonb(CAST(@quantity AS numeric)),
                true
              ),
              '{c2_datrf}',
              to_jsonb(CAST(@emission_date AS text)),
              true
            ),
            '{c2_status}',
            to_jsonb('F'::text),
            true
          ),
          '{vettiflow_finished_at}',
          to_jsonb(CAST(@emission_date AS text)),
          true
        )
        WHERE payload ->> 'vettiflow_order_number' = @order_number
          AND COALESCE(payload ->> 'd_e_l_e_t_', '') <> '*'
      '''),
      parameters: {
        'quantity': movement.quantity,
        'emission_date': movement.emissionDate,
        'order_number': movement.orderNumber,
      },
    );
  }

  Future<void> _insertSd3Movement(
    Session tx,
    Map<String, dynamic> payload, {
    required String sequence,
  }) async {
    final movementPayload = await _withNextRecno(tx, _protheusSd3, payload);
    await tx.execute(
      Sql.named('''
        INSERT INTO protheus_raw.sd3_movements (payload)
        SELECT CAST(@payload AS jsonb)
        WHERE NOT EXISTS (
          SELECT 1
          FROM protheus_raw.sd3_movements
          WHERE payload ->> 'vettiflow_order_number' = @order_number
            AND payload ->> 'vettiflow_origin' = 'op_completion'
            AND d3_cod = @code
            AND d3_local = @warehouse
            AND d3_cf = @movement_type
            AND COALESCE(payload ->> 'd3_numseq', '') = @sequence
            AND COALESCE(payload ->> 'd_e_l_e_t_', '') <> '*'
        )
      '''),
      parameters: {
        'payload': jsonEncode(movementPayload),
        'order_number': movementPayload['vettiflow_order_number'],
        'code': movementPayload['d3_cod'],
        'warehouse': movementPayload['d3_local'],
        'movement_type': movementPayload['d3_cf'],
        'sequence': sequence,
      },
    );
  }

  Future<void> _increaseSb2CurrentStock(
    Session tx,
    ProtheusFinishedProductMovement movement,
  ) async {
    final updated = await tx.execute(
      Sql.named('''
        UPDATE protheus_raw.sb2_balances
        SET payload = jsonb_set(
          jsonb_set(
            jsonb_set(
              payload,
              '{b2_qatu}',
              to_jsonb(
                COALESCE(NULLIF(trim(payload ->> 'b2_qatu'), '')::numeric, 0)
                + CAST(@quantity AS numeric)
              ),
              true
            ),
            '{b2_dmov}',
            to_jsonb(CAST(@emission_date AS text)),
            true
          ),
          '{vettiflow_last_completion_order_number}',
          to_jsonb(CAST(@order_number AS text)),
          true
        )
        WHERE b2_filial = @filial
          AND b2_cod = @product_code
          AND b2_local = @warehouse
          AND COALESCE(payload ->> 'd_e_l_e_t_', '') <> '*'
        RETURNING id
      '''),
      parameters: {
        'quantity': movement.quantity,
        'emission_date': movement.emissionDate,
        'order_number': movement.orderNumber,
        'filial': movement.filial,
        'product_code': movement.productCode,
        'warehouse': movement.warehouse,
      },
    );
    if (updated.isNotEmpty) return;

    final payload = await _withNextRecno(
      tx,
      _protheusSb2,
      movement.newSb2Payload,
    );
    await tx.execute(
      Sql.named('''
        INSERT INTO protheus_raw.sb2_balances (payload)
        VALUES (CAST(@payload AS jsonb))
      '''),
      parameters: {'payload': jsonEncode(payload)},
    );
  }

  Future<void> _decreaseSb2CurrentAndCommitment(
    Session tx,
    ProtheusComponentConsumptionMovement movement,
  ) async {
    await tx.execute(
      Sql.named('''
        UPDATE protheus_raw.sb2_balances
        SET payload = jsonb_set(
          jsonb_set(
            jsonb_set(
              jsonb_set(
                payload,
                '{b2_qatu}',
                to_jsonb(
                  GREATEST(
                    COALESCE(NULLIF(trim(payload ->> 'b2_qatu'), '')::numeric, 0)
                    - CAST(@quantity AS numeric),
                    0
                  )
                ),
                true
              ),
              '{b2_qemp}',
              to_jsonb(
                GREATEST(
                  COALESCE(NULLIF(trim(payload ->> 'b2_qemp'), '')::numeric, 0)
                  - CAST(@quantity AS numeric),
                  0
                )
              ),
              true
            ),
            '{b2_dmov}',
            to_jsonb(CAST(@emission_date AS text)),
            true
          ),
          '{vettiflow_last_completion_order_number}',
          to_jsonb(CAST(@order_number AS text)),
          true
        )
        WHERE b2_filial = @filial
          AND b2_cod = @component_code
          AND b2_local = @armazem
          AND COALESCE(payload ->> 'd_e_l_e_t_', '') <> '*'
      '''),
      parameters: {
        'quantity': movement.quantity,
        'emission_date': movement.emissionDate,
        'order_number': movement.orderNumber,
        'filial': movement.filial,
        'component_code': movement.componentCode,
        'armazem': movement.armazem,
      },
    );
  }

  Future<void> _closeSd4Commitment(
    Session tx,
    ProtheusComponentConsumptionMovement movement,
  ) async {
    await tx.execute(
      Sql.named('''
        UPDATE protheus_raw.sd4_commitments
        SET payload = jsonb_set(
          jsonb_set(
            jsonb_set(
              jsonb_set(
                jsonb_set(
                  payload,
                  '{d4_quant}',
                  to_jsonb(0),
                  true
                ),
                '{d4_sldemp}',
                to_jsonb(0),
                true
              ),
              '{d4_sldemp2}',
              to_jsonb(0),
              true
            ),
            '{d4_situaca}',
            to_jsonb('R'::text),
            true
          ),
          '{vettiflow_consumed_at}',
          to_jsonb(CAST(@emission_date AS text)),
          true
        )
        WHERE payload ->> 'vettiflow_order_number' = @order_number
          AND d4_cod = @component_code
          AND d4_local = @armazem
          AND COALESCE(payload ->> 'd_e_l_e_t_', '') <> '*'
      '''),
      parameters: {
        'emission_date': movement.emissionDate,
        'order_number': movement.orderNumber,
        'component_code': movement.componentCode,
        'armazem': movement.armazem,
      },
    );
  }

  Future<void> _applyProtheusCancelation(
    Session tx,
    ProductionOrderFlow order,
    ProductionCatalogItem catalogItem, {
    Map<String, String> returnWarehouses = const {},
    String? operatorName,
    String? operatorPin,
  }) async {
    await _cancelSc2Order(
      tx,
      order,
      operatorName: operatorName,
      operatorPin: operatorPin,
    );

    final existing = await tx.execute(
      Sql.named('''
        SELECT 1
        FROM protheus_raw.sd4_commitments
        WHERE payload ->> 'vettiflow_order_number' = @order_number
          AND payload ->> 'vettiflow_origin' = 'op_cancel'
        LIMIT 1
      '''),
      parameters: {'order_number': order.number},
    );
    if (existing.isNotEmpty) return;

    final plan = ProtheusStockCancelationPlan.fromOrder(
      order,
      catalogItem,
      returnWarehouses: returnWarehouses,
      operatorName: operatorName,
      operatorPin: operatorPin,
    );
    for (final movement in plan.movements) {
      await _cancelSd4Commitment(tx, movement);
      await _insertSd4CancelAudit(tx, movement);
      if (movement.affectsStockBalance) {
        await _decreaseSb2Commitment(tx, movement);
      }
    }
  }

  Future<void> _cancelSc2Order(
    Session tx,
    ProductionOrderFlow order, {
    String? operatorName,
    String? operatorPin,
  }) async {
    await tx.execute(
      Sql.named('''
        UPDATE protheus_raw.sc2_orders
        SET payload = jsonb_set(
          jsonb_set(
            jsonb_set(
              jsonb_set(
                jsonb_set(
                  payload,
                  '{c2_status}',
                  to_jsonb('C'::text),
                  true
                ),
                '{d_e_l_e_t_}',
                to_jsonb('*'::text),
                true
              ),
              '{vettiflow_cancelled_at}',
              to_jsonb(CAST(@cancelled_at AS text)),
              true
            ),
            '{vettiflow_cancel_operator_name}',
            to_jsonb(CAST(@operator_name AS text)),
            true
          ),
          '{vettiflow_cancel_operator_pin}',
          to_jsonb(CAST(@operator_pin AS text)),
          true
        )
        WHERE payload ->> 'vettiflow_order_number' = @order_number
          AND COALESCE(payload ->> 'd_e_l_e_t_', '') <> '*'
      '''),
      parameters: {
        'cancelled_at': _yyyymmdd(order.updatedAt),
        'operator_name': _operatorName(operatorName ?? order.operatorName),
        'operator_pin': _operatorPin(operatorPin ?? order.operatorPin),
        'order_number': order.number,
      },
    );
  }

  Future<void> _decreaseSb2Commitment(
    Session tx,
    ProtheusStockCancelationMovement movement,
  ) async {
    await tx.execute(
      Sql.named('''
        UPDATE protheus_raw.sb2_balances
        SET payload = jsonb_set(
          jsonb_set(
            jsonb_set(
              payload,
              '{b2_qemp}',
              to_jsonb(
                GREATEST(
                  COALESCE(NULLIF(trim(payload ->> 'b2_qemp'), '')::numeric, 0)
                  - CAST(@quantity AS numeric),
                  0
                )
              ),
              true
            ),
            '{b2_dmov}',
            to_jsonb(CAST(@emission_date AS text)),
            true
          ),
          '{vettiflow_last_cancel_order_number}',
          to_jsonb(CAST(@order_number AS text)),
          true
        )
        WHERE b2_filial = @filial
          AND b2_cod = @component_code
          AND b2_local = @armazem
          AND COALESCE(payload ->> 'd_e_l_e_t_', '') <> '*'
      '''),
      parameters: {
        'quantity': movement.quantity,
        'emission_date': movement.emissionDate,
        'order_number': movement.orderNumber,
        'filial': movement.filial,
        'component_code': movement.componentCode,
        'armazem': movement.armazem,
      },
    );
  }

  Future<void> _cancelSd4Commitment(
    Session tx,
    ProtheusStockCancelationMovement movement,
  ) async {
    await tx.execute(
      Sql.named('''
        UPDATE protheus_raw.sd4_commitments
        SET payload = jsonb_set(
          jsonb_set(
            jsonb_set(
              jsonb_set(
                jsonb_set(
                  payload,
                  '{d4_sldemp}',
                  to_jsonb(0),
                  true
                ),
                '{d4_sldemp2}',
                to_jsonb(0),
                true
              ),
              '{d4_situaca}',
              to_jsonb('D'::text),
              true
            ),
            '{d_e_l_e_t_}',
            to_jsonb('*'::text),
            true
          ),
          '{vettiflow_cancelled_at}',
          to_jsonb(CAST(@emission_date AS text)),
          true
        )
        WHERE payload ->> 'vettiflow_order_number' = @order_number
          AND d4_cod = @component_code
          AND d4_local = @armazem
          AND COALESCE(payload ->> 'd_e_l_e_t_', '') <> '*'
      '''),
      parameters: {
        'emission_date': movement.emissionDate,
        'order_number': movement.orderNumber,
        'component_code': movement.componentCode,
        'armazem': movement.armazem,
      },
    );
  }

  Future<void> _insertSd4CancelAudit(
    Session tx,
    ProtheusStockCancelationMovement movement,
  ) async {
    final payload = await _withNextRecno(
      tx,
      _protheusSd4,
      movement.sd4CancelPayload,
    );
    await tx.execute(
      Sql.named('''
        INSERT INTO protheus_raw.sd4_commitments (payload)
        SELECT CAST(@payload AS jsonb)
        WHERE NOT EXISTS (
          SELECT 1
          FROM protheus_raw.sd4_commitments
          WHERE payload ->> 'vettiflow_order_number' = @order_number
            AND payload ->> 'vettiflow_origin' = 'op_cancel'
            AND d4_cod = @component_code
            AND d4_local = @armazem
        )
      '''),
      parameters: {
        'payload': jsonEncode(payload),
        'order_number': movement.orderNumber,
        'component_code': movement.componentCode,
        'armazem': movement.armazem,
      },
    );
  }

  Future<Connection> _open() async {
    final current = _connection;
    if (current != null && current.isOpen) {
      await _ensureSchema(current);
      return current;
    }
    final conn = await Connection.open(
      Endpoint(
        host: host,
        port: port,
        database: database,
        username: username,
        password: password,
      ),
      settings: const ConnectionSettings(
        applicationName: 'vettiflow-production-flow',
        sslMode: SslMode.disable,
        connectTimeout: Duration(seconds: 4),
        queryTimeout: Duration(seconds: 30),
      ),
    );
    _connection = conn;
    await _ensureSchema(conn);
    return conn;
  }

  Future<void> _ensureSchema(Connection conn) async {
    if (_schemaChecked) return;
    await conn.execute('''
      ALTER TABLE IF EXISTS vettiflow.production_orders
      ADD COLUMN IF NOT EXISTS planned_stages jsonb NOT NULL DEFAULT '[]'::jsonb
    ''', timeout: const Duration(seconds: 8));
    await conn.execute('''
      ALTER TABLE IF EXISTS vettiflow.production_orders
      ADD COLUMN IF NOT EXISTS order_warehouse text NOT NULL DEFAULT ''
    ''', timeout: const Duration(seconds: 8));
    await conn.execute('''
      ALTER TABLE IF EXISTS vettiflow.production_orders
      ADD COLUMN IF NOT EXISTS operator_pin_hash text
    ''', timeout: const Duration(seconds: 8));
    await conn.execute('''
      ALTER TABLE IF EXISTS vettiflow.production_components
      ADD COLUMN IF NOT EXISTS structure_sequence text NOT NULL DEFAULT ''
    ''', timeout: const Duration(seconds: 8));
    await conn.execute('''
      CREATE SEQUENCE IF NOT EXISTS vettiflow.production_order_number_seq
        AS bigint START WITH 564351 MINVALUE 1
    ''', timeout: const Duration(seconds: 8));
    // So semeia se a sequence nunca foi usada (`last_value` nulo em
    // `pg_sequences`). Sem essa guarda, um app subindo depois que outra maquina
    // reservou um numero mas ainda nao gravou a OP jogaria o contador para tras.
    await conn.execute('''
      SELECT setval('vettiflow.production_order_number_seq', s.value, true)
      FROM (
        SELECT GREATEST(
                 564350,
                 COALESCE(max(split_part(number, '-', 3)::bigint), 0)
               ) AS value
        FROM vettiflow.production_orders
        WHERE split_part(number, '-', 3) ~ '^[0-9]+\$'
      ) AS s
      WHERE NOT EXISTS (
        SELECT 1 FROM pg_sequences
        WHERE schemaname = 'vettiflow'
          AND sequencename = 'production_order_number_seq'
          AND last_value IS NOT NULL
      )
    ''', timeout: const Duration(seconds: 8));
    _schemaChecked = true;
  }

  Map<String, dynamic> _orderParameters(ProductionOrderFlow order) {
    return {
      'number': order.number,
      'product_code': order.productCode,
      'product_name': order.productName,
      'quantity': order.quantity,
      'current_stage': order.currentStage.name,
      'run_status': order.status.name,
      'op_status': order.isDone
          ? 'finalizada'
          : order.currentStage == ProductionStage.warehouse
          ? 'nao_iniciada'
          : 'em_andamento',
      'priority': order.priority,
      'progress_percent': order.isDone
          ? 100
          : (order.currentStage.progressIndex /
                    ProductionStage.productionFlow.length *
                    100)
                .round(),
      'responsavel': order.responsavel,
      'operator_name': order.operatorName,
      'operator_pin_hash': order.operatorPin,
      'order_warehouse': order.orderWarehouse,
      'opened_at': DateTime(
        order.createdAt.year,
        order.createdAt.month,
        order.createdAt.day,
      ),
      'due_date': _parsePtBrDate(order.prazo),
      'month_label': order.createdAt.month.toString().padLeft(2, '0'),
      'is_late': false,
      'closed_quantity': order.closedQuantity,
      'stored_quantity': order.storedQuantity,
      'dispatched_quantity': order.dispatchedQuantity,
      'last_observation': order.lastObservation,
      'planned_stages': jsonEncode(
        order.plannedStages.map((stage) => stage.name).toList(),
      ),
      'created_at': order.createdAt,
      'updated_at': order.updatedAt,
    };
  }

  Map<String, dynamic> _eventPayload(ProductionOrderFlow order) {
    return _orderParameters(order).map((key, value) {
      if (value is DateTime) return MapEntry(key, value.toIso8601String());
      return MapEntry(key, value);
    });
  }

  Map<String, List<T>> _groupByOrder<T>(
    Result rows,
    T Function(Map<String, dynamic> data) map,
  ) {
    final grouped = <String, List<T>>{};
    for (final row in rows) {
      final data = row.toColumnMap();
      final orderNumber = _text(data['order_number']);
      grouped.putIfAbsent(orderNumber, () => []).add(map(data));
    }
    return grouped;
  }

  ProductionComponent _componentFrom(Map<String, dynamic> data) {
    return ProductionComponent(
      code: _text(data['component_code']),
      description: _text(data['description']),
      quantity: _int(data['quantity']),
      stock: _int(data['stock']),
      filial: _text(data['filial']),
      armazem: _text(data['armazem']),
      currentStock: _int(data['current_stock']),
      committedQuantity: _int(data['committed_quantity']),
      reservedQuantity: _int(data['reserved_quantity']),
      requirementSource: _text(data['requirement_source'], fallback: 'SG1'),
      sourceOrder: _text(data['source_order']),
      commitmentDate: _text(data['commitment_date']),
      originalQuantity: _int(data['original_quantity']),
      commitmentQuantity: _int(data['commitment_quantity']),
      structureSequence: _text(data['structure_sequence']),
    );
  }

  (ProductionStage, ProductionStageTiming) _timingFrom(
    Map<String, dynamic> data,
  ) {
    return (
      _stageFrom(_text(data['stage'])),
      ProductionStageTiming(
        startedAt: _date(data['started_at']),
        completedAt: _date(data['completed_at']),
        pausedAt: _date(data['paused_at']),
        pausedDuration: Duration(
          milliseconds: _int(data['paused_duration_ms']),
        ),
      ),
    );
  }

  ProductionOperatorSession _sessionFrom(Map<String, dynamic> data) {
    return ProductionOperatorSession(
      stage: _stageFrom(_text(data['stage'])),
      operatorName: _text(data['operator_name']),
      operatorPin: _text(data['operator_pin_hash']),
      startedAt: _date(data['started_at']) ?? DateTime.now(),
      completedAt: _date(data['completed_at']),
      pausedAt: _date(data['paused_at']),
      pausedDuration: Duration(milliseconds: _int(data['paused_duration_ms'])),
      producedQuantity: _int(data['produced_quantity']),
    );
  }

  ProductionPauseEvent _pauseFrom(Map<String, dynamic> data) {
    return ProductionPauseEvent(
      stage: _stageFrom(_text(data['stage'])),
      operatorName: _text(data['operator_name']),
      operatorPin: _text(data['operator_pin_hash']),
      reason: PauseReason.values.firstWhere(
        (reason) => reason.name == _text(data['reason']),
        orElse: () => PauseReason.outro,
      ),
      customReason: _nullableText(data['custom_reason']),
      producedQuantity: _int(data['produced_quantity']),
      createdAt: _date(data['created_at']) ?? DateTime.now(),
      resumedAt: _date(data['resumed_at']),
    );
  }

  DefectRecord _defectFrom(Map<String, dynamic> data) {
    return DefectRecord(
      code: _text(data['code']),
      title: _text(data['title']),
      quantity: _int(data['quantity']),
    );
  }

  ProductionStage _stageFrom(String value) {
    return ProductionStage.values.firstWhere(
      (stage) => stage.name == value,
      orElse: () => ProductionStage.warehouse,
    );
  }

  List<ProductionStage> _stagesFromJson(Object? value) {
    if (value is List) {
      return value
          .map((stage) => _stageFrom(stage.toString()))
          .where((stage) => ProductionStage.productionFlow.contains(stage))
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded
            .map((stage) => _stageFrom(stage.toString()))
            .where((stage) => ProductionStage.productionFlow.contains(stage))
            .toList();
      }
    }
    return const [];
  }

  ProductionRunStatus _statusFrom(String value) {
    return ProductionRunStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ProductionRunStatus.waiting,
    );
  }

  String _text(Object? value, {String fallback = ''}) {
    final text = switch (value) {
      null => null,
      UndecodedBytes() => value.asString.trim(),
      _ => value.toString().trim(),
    };
    return text == null || text.isEmpty ? fallback : text;
  }

  String? _nullableText(Object? value) {
    final text = switch (value) {
      null => null,
      UndecodedBytes() => value.asString.trim(),
      _ => value.toString().trim(),
    };
    return text == null || text.isEmpty ? null : text;
  }

  int _int(Object? value) {
    if (value is num) return value.round();
    return num.tryParse(value?.toString() ?? '')?.round() ?? 0;
  }

  String _operatorName(String? value) {
    final name = value?.trim();
    return name == null || name.isEmpty ? 'VettiFlow' : name;
  }

  String _operatorPin(String? value) => value?.trim() ?? '';

  String _yyyymmdd(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }

  DateTime? _date(Object? value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  String? _formatDate(Object? value) {
    final date = _date(value);
    if (date == null) return null;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  DateTime? _parsePtBrDate(String? value) {
    if (value == null) return null;
    final parts = value.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }
}
