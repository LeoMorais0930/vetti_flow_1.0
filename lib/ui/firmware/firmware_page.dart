import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/shared/layout/app_breakpoints.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/firmware/widgets/firmware_completion_dialogs.dart';
import 'package:vetti_flow_1_0/ui/firmware/widgets/firmware_models.dart';
import 'package:vetti_flow_1_0/ui/firmware/widgets/operation_actions.dart';
import 'package:vetti_flow_1_0/ui/firmware/widgets/operation_card.dart';
import 'package:vetti_flow_1_0/ui/firmware/widgets/operation_metrics.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/vetti_top_bar.dart';

class FirmwarePage extends StatefulWidget {
  const FirmwarePage({super.key});

  @override
  State<FirmwarePage> createState() => _FirmwarePageState();
}

class _FirmwarePageState extends State<FirmwarePage> {
  var _selectedIndex = 0;

  List<ProductionOrderFlow> _flowOrders() => context
      .read<ProductionFlowStore>()
      .ordersAtStage(ProductionStage.firmware);

  ProductionOrderFlow? _selectedFlowOrder() {
    final orders = _flowOrders();
    if (orders.isEmpty) return null;
    final index = _selectedIndex.clamp(0, orders.length - 1).toInt();
    return orders[index];
  }

  FirmwareOperation _operationFromFlow(ProductionOrderFlow order) {
    final elapsed = order.activeElapsed(DateTime.now());
    return FirmwareOperation(
      number: order.number,
      product: order.productLabel,
      quantity: order.quantityLabel,
      origin: 'Almoxarifado',
      receivedAt: _timeLabel(order.updatedAt),
      receivedAgo: order.timings[ProductionStage.firmware]?.startedAt == null
          ? 'Aguardando inicio'
          : 'Tempo na etapa: ${formatProductionDuration(elapsed)}',
    );
  }

  FirmwareStatus _statusFromFlow(ProductionRunStatus status) {
    return switch (status) {
      ProductionRunStatus.waiting => FirmwareStatus.waiting,
      ProductionRunStatus.active => FirmwareStatus.recording,
      ProductionRunStatus.paused => FirmwareStatus.paused,
      ProductionRunStatus.completed => FirmwareStatus.completed,
    };
  }

  void _select(int index) {
    setState(() => _selectedIndex = index);
  }

  void _startRecording() {
    final order = _selectedFlowOrder();
    if (order == null) return;
    context.read<ProductionFlowStore>().startStage(
      order.number,
      operatorName: 'Fernando',
    );
  }

  void _pauseOperation() {
    final order = _selectedFlowOrder();
    if (order == null) return;
    context.read<ProductionFlowStore>().pauseStage(order.number);
  }

  void _resetOperation() {
    final order = _selectedFlowOrder();
    if (order == null) return;
    context.read<ProductionFlowStore>().resetStage(order.number);
  }

  Future<void> _completeOperation() async {
    final flowOrder = _selectedFlowOrder();
    if (flowOrder == null) return;
    final selectedOperation = _operationFromFlow(flowOrder);
    final defects = await showFirmwareDefectsDialog(context);
    if (!mounted || defects == null) return;

    final signed = await showFirmwarePinDialog(
      context,
      selectedOperation,
      defects: defects,
    );
    if (!mounted || signed != true) return;

    context.read<ProductionFlowStore>().completeStage(flowOrder.number);
    setState(() => _selectedIndex = 0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${flowOrder.number} liberada para Soldagem.')),
    );
  }

  void _showMobileActions(BuildContext context) {
    final flowOrder = _selectedFlowOrder();
    if (flowOrder == null) return;
    final status = _statusFromFlow(flowOrder.status);
    final op = _operationFromFlow(flowOrder);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MobileActionSheet(
        operation: op,
        status: status,
        onStart: () {
          Navigator.pop(ctx);
          _startRecording();
        },
        onPause: () {
          Navigator.pop(ctx);
          _pauseOperation();
        },
        onComplete: () {
          Navigator.pop(ctx);
          _completeOperation();
        },
        onReset: () {
          Navigator.pop(ctx);
          _resetOperation();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flowOrders = context.watch<ProductionFlowStore>().ordersAtStage(
      ProductionStage.firmware,
    );
    if (_selectedIndex >= flowOrders.length && flowOrders.isNotEmpty) {
      _selectedIndex = flowOrders.length - 1;
    }
    final operations = flowOrders.map(_operationFromFlow).toList();
    final statuses = {
      for (var i = 0; i < flowOrders.length; i++)
        i: _statusFromFlow(flowOrders[i].status),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final formFactor = constraints.maxWidth >= 1180
            ? AppFormFactor.expanded
            : AppBreakpoints.fromWidth(constraints.maxWidth);
        final isMobile = formFactor != AppFormFactor.expanded;

        if (isMobile) {
          if (operations.isEmpty) {
            return const _EmptyFirmwareStage(compact: true);
          }
          return _MobileFirmwareLayout(
            operations: operations,
            selectedIndex: _selectedIndex,
            statuses: statuses,
            onSelect: (i) {
              _select(i);
              _showMobileActions(context);
            },
          );
        }

        if (operations.isEmpty) {
          return const _EmptyFirmwareStage();
        }
        return _DesktopFirmwareLayout(
          operations: operations,
          selectedIndex: _selectedIndex,
          statuses: statuses,
          onSelect: _select,
          onStart: _startRecording,
          onPause: _pauseOperation,
          onComplete: _completeOperation,
          onReset: _resetOperation,
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// Mobile action sheet (flutuante ao clicar no card)
// ────────────────────────────────────────────────────────────────────

class _MobileActionSheet extends StatelessWidget {
  const _MobileActionSheet({
    required this.operation,
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onComplete,
    required this.onReset,
  });

  final FirmwareOperation operation;
  final FirmwareStatus status;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onComplete;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD7E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      operation.number,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      operation.product,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              OperationStatusChip(status: status, compact: true),
            ],
          ),
          const SizedBox(height: 16),
          OperationMetrics(operation: operation, compact: true),
          const SizedBox(height: 20),
          OperationActions(
            status: status,
            compact: true,
            onStart: onStart,
            onPause: onPause,
            onComplete: onComplete,
            onReset: onReset,
          ),
        ],
      ),
    );
  }
}

class _EmptyFirmwareStage extends StatelessWidget {
  const _EmptyFirmwareStage({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Scaffold(
        backgroundColor: const Color(0xFF101820),
        body: SafeArea(
          child: Center(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 430),
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.pageBackground,
                borderRadius: BorderRadius.circular(22),
              ),
              clipBehavior: Clip.antiAlias,
              child: const Column(
                children: [
                  VettiTopBar(
                    title: 'Gravacao de Firmware',
                    operatorName: 'Fernando',
                    compact: true,
                  ),
                  Expanded(
                    child: Center(
                      child: _EmptyStageMessage(
                        text: 'Nenhuma OP aguardando firmware.',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return const Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Column(
        children: [
          VettiTopBar(
            title: 'Gravacao de Firmware',
            operatorName: 'Fernando',
            operatorRole: 'Firmware',
          ),
          Expanded(
            child: Center(
              child: _EmptyStageMessage(
                text: 'Nenhuma OP aguardando firmware.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStageMessage extends StatelessWidget {
  const _EmptyStageMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

String _timeLabel(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

// ────────────────────────────────────────────────────────────────────
// Mobile layout — so lista de cards, tap abre o sheet
// ────────────────────────────────────────────────────────────────────

class _MobileFirmwareLayout extends StatelessWidget {
  const _MobileFirmwareLayout({
    required this.operations,
    required this.selectedIndex,
    required this.statuses,
    required this.onSelect,
  });

  final List<FirmwareOperation> operations;
  final int selectedIndex;
  final Map<int, FirmwareStatus> statuses;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101820),
      body: SafeArea(
        child: Center(
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 430),
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.pageBackground,
              borderRadius: BorderRadius.circular(22),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const VettiTopBar(
                  title: 'Gravacao de Firmware',
                  operatorName: 'Fernando',
                  compact: true,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'OPs disponiveis',
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Toque na OP para ver detalhes e acoes.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        for (var i = 0; i < operations.length; i++) ...[
                          OperationCard(
                            operation: operations[i],
                            selected: i == selectedIndex,
                            status: statuses[i] ?? FirmwareStatus.waiting,
                            compact: true,
                            onTap: () => onSelect(i),
                          ),
                          if (i < operations.length - 1)
                            const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// Desktop layout — lista esquerda + detalhe completo a direita
// ────────────────────────────────────────────────────────────────────

class _DesktopFirmwareLayout extends StatelessWidget {
  const _DesktopFirmwareLayout({
    required this.operations,
    required this.selectedIndex,
    required this.statuses,
    required this.onSelect,
    required this.onStart,
    required this.onPause,
    required this.onComplete,
    required this.onReset,
  });

  final List<FirmwareOperation> operations;
  final int selectedIndex;
  final Map<int, FirmwareStatus> statuses;
  final ValueChanged<int> onSelect;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onComplete;
  final VoidCallback onReset;

  FirmwareOperation get selectedOperation => operations[selectedIndex];
  FirmwareStatus get status =>
      statuses[selectedIndex] ?? FirmwareStatus.waiting;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Column(
        children: [
          const VettiTopBar(
            title: 'Gravacao de Firmware',
            operatorName: 'Fernando',
            operatorRole: 'Gravacao',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(40, 32, 40, 36),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 340,
                        child: _DesktopOperationsPanel(
                          operations: operations,
                          selectedIndex: selectedIndex,
                          statuses: statuses,
                          onSelect: onSelect,
                        ),
                      ),
                      const SizedBox(width: 36),
                      Expanded(
                        child: _DesktopDetailPanel(
                          operation: selectedOperation,
                          status: status,
                          onStart: onStart,
                          onPause: onPause,
                          onComplete: onComplete,
                          onReset: onReset,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopOperationsPanel extends StatelessWidget {
  const _DesktopOperationsPanel({
    required this.operations,
    required this.selectedIndex,
    required this.statuses,
    required this.onSelect,
  });

  final List<FirmwareOperation> operations;
  final int selectedIndex;
  final Map<int, FirmwareStatus> statuses;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EDF4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'OPs disponiveis',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${operations.length}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Liberadas pela SMD para gravacao.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < operations.length; i++) ...[
            OperationCard(
              operation: operations[i],
              selected: i == selectedIndex,
              status: statuses[i] ?? FirmwareStatus.waiting,
              onTap: () => onSelect(i),
            ),
            if (i < operations.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _DesktopDetailPanel extends StatelessWidget {
  const _DesktopDetailPanel({
    required this.operation,
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onComplete,
    required this.onReset,
  });

  final FirmwareOperation operation;
  final FirmwareStatus status;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onComplete;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EDF4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      operation.number,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      operation.product,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      operation.receivedAgo,
                      style: const TextStyle(
                        color: AppColors.smallText,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              OperationStatusChip(status: status),
            ],
          ),
          const SizedBox(height: 24),
          OperationMetrics(operation: operation),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            height: 1,
            color: const Color(0xFFEEF3F7),
          ),
          const SizedBox(height: 28),
          const Text(
            'Acoes da OP',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _actionHint(status),
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          OperationActions(
            status: status,
            onStart: onStart,
            onPause: onPause,
            onComplete: onComplete,
            onReset: onReset,
          ),
        ],
      ),
    );
  }

  String _actionHint(FirmwareStatus status) {
    return switch (status) {
      FirmwareStatus.waiting =>
        'Inicie a gravacao para liberar as demais acoes.',
      FirmwareStatus.recording =>
        'Gravacao em andamento. Pause ou conclua a OP.',
      FirmwareStatus.paused => 'OP pausada. Retome ou conclua a gravacao.',
      FirmwareStatus.completed => 'OP finalizada nesta etapa.',
    };
  }
}
