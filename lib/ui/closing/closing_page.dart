import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/shared/layout/app_breakpoints.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/vetti_top_bar.dart';

const _operatorName = 'Bruno';

class ClosingOperation {
  const ClosingOperation({
    required this.number,
    required this.product,
    required this.quantity,
    required this.quantityValue,
    required this.origin,
    required this.receivedAt,
    required this.receivedAgo,
    required this.closedQuantity,
  });

  final String number;
  final String product;
  final String quantity;
  final int quantityValue;
  final String origin;
  final String receivedAt;
  final String receivedAgo;
  final int closedQuantity;
}

enum ClosingStatus {
  waiting(
    'Aguardando',
    AppColors.muted,
    Color(0xFFEFF3F7),
    Icons.schedule_rounded,
  ),
  active(
    'Em fechamento',
    AppColors.primary,
    Color(0xFFE7F4FB),
    Icons.inventory_rounded,
  ),
  paused(
    'Pausada',
    AppColors.orangeText,
    Color(0xFFFBF1E2),
    Icons.pause_rounded,
  ),
  completed(
    'Concluida',
    AppColors.green,
    Color(0xFFE7F6EC),
    Icons.check_circle_rounded,
  );

  const ClosingStatus(this.label, this.color, this.surface, this.icon);

  final String label;
  final Color color;
  final Color surface;
  final IconData icon;
}

class ClosingPage extends StatefulWidget {
  const ClosingPage({super.key});

  @override
  State<ClosingPage> createState() => _ClosingPageState();
}

class _ClosingPageState extends State<ClosingPage> {
  var _selectedIndex = 0;

  List<ProductionOrderFlow> _flowOrders() => context
      .read<ProductionFlowStore>()
      .ordersAtStage(ProductionStage.closing);

  ProductionOrderFlow? _selectedFlowOrder() {
    final orders = _flowOrders();
    if (orders.isEmpty) return null;
    final index = _selectedIndex.clamp(0, orders.length - 1).toInt();
    return orders[index];
  }

  ClosingOperation _operationFromFlow(ProductionOrderFlow order) {
    final elapsed = order.activeElapsed(DateTime.now());
    return ClosingOperation(
      number: order.number,
      product: order.productLabel,
      quantity: order.quantityLabel,
      quantityValue: order.quantity,
      origin: 'Testes',
      receivedAt: _clockLabel(order.updatedAt),
      receivedAgo: order.timings[ProductionStage.closing]?.startedAt == null
          ? 'Aguardando inicio'
          : 'Tempo na etapa: ${formatProductionDuration(elapsed)}',
      closedQuantity: order.closedQuantity,
    );
  }

  ClosingStatus _statusFromFlow(ProductionOrderFlow order) {
    return switch (order.status) {
      ProductionRunStatus.waiting => ClosingStatus.waiting,
      ProductionRunStatus.active => ClosingStatus.active,
      ProductionRunStatus.paused => ClosingStatus.paused,
      ProductionRunStatus.completed => ClosingStatus.completed,
    };
  }

  void _select(int index) {
    setState(() => _selectedIndex = index);
  }

  void _startClosing() {
    final order = _selectedFlowOrder();
    if (order == null) return;
    context.read<ProductionFlowStore>().startStage(
      order.number,
      operatorName: _operatorName,
    );
  }

  void _pauseOperation() {
    final order = _selectedFlowOrder();
    if (order == null) return;
    context.read<ProductionFlowStore>().pauseStage(order.number);
  }

  Future<void> _completeClosing() async {
    final flowOrder = _selectedFlowOrder();
    if (flowOrder == null) return;
    final operation = _operationFromFlow(flowOrder);
    final closedQuantity = await showClosingCompletionDialog(
      context,
      operation,
    );
    if (!mounted || closedQuantity == null) return;

    context.read<ProductionFlowStore>().completeClosing(
      flowOrder.number,
      closedQuantity: closedQuantity,
    );
    setState(() => _selectedIndex = 0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${operation.number} fechada ($closedQuantity un) e liberada para expedicao.',
        ),
      ),
    );
  }

  void _showMobileActions(BuildContext context) {
    final order = _selectedFlowOrder();
    if (order == null) return;
    final status = _statusFromFlow(order);
    final operation = _operationFromFlow(order);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MobileClosingActionSheet(
        operation: operation,
        status: status,
        onStart: () {
          Navigator.pop(ctx);
          _startClosing();
        },
        onPause: () {
          Navigator.pop(ctx);
          _pauseOperation();
        },
        onComplete: () {
          Navigator.pop(ctx);
          _completeClosing();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flowOrders = context.watch<ProductionFlowStore>().ordersAtStage(
      ProductionStage.closing,
    );
    if (_selectedIndex >= flowOrders.length) {
      _selectedIndex = flowOrders.isEmpty ? 0 : flowOrders.length - 1;
    }
    final operations = flowOrders.map(_operationFromFlow).toList();
    final statuses = {
      for (var i = 0; i < flowOrders.length; i++)
        i: _statusFromFlow(flowOrders[i]),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final formFactor = AppBreakpoints.fromWidth(constraints.maxWidth);
        final isMobile = formFactor != AppFormFactor.expanded;

        if (operations.isEmpty) {
          return _EmptyClosingStage(compact: isMobile);
        }

        if (isMobile) {
          return _MobileClosingLayout(
            operations: operations,
            selectedIndex: _selectedIndex,
            statuses: statuses,
            onSelect: (index) {
              _select(index);
              _showMobileActions(context);
            },
          );
        }

        return _DesktopClosingLayout(
          operations: operations,
          selectedIndex: _selectedIndex,
          statuses: statuses,
          onSelect: _select,
          onStart: _startClosing,
          onPause: _pauseOperation,
          onComplete: _completeClosing,
        );
      },
    );
  }

  String _clockLabel(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _EmptyClosingStage extends StatelessWidget {
  const _EmptyClosingStage({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: compact
          ? const Color(0xFF101820)
          : AppColors.pageBackground,
      body: SafeArea(
        child: Center(
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxWidth: compact ? 430 : double.infinity,
            ),
            margin: compact ? const EdgeInsets.all(10) : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: AppColors.pageBackground,
              borderRadius: BorderRadius.circular(compact ? 22 : 0),
            ),
            clipBehavior: Clip.antiAlias,
            child: const Column(
              children: [
                VettiTopBar(
                  title: 'Fechamento de Producao',
                  operatorName: _operatorName,
                  operatorRole: 'Fechamento',
                ),
                Expanded(
                  child: _EmptyStageMessage(
                    icon: Icons.inventory_rounded,
                    title: 'Nenhuma OP em fechamento',
                    text:
                        'As OPs aparecem aqui assim que o teste for concluido.',
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

class _EmptyStageMessage extends StatelessWidget {
  const _EmptyStageMessage({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.primary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileClosingActionSheet extends StatelessWidget {
  const _MobileClosingActionSheet({
    required this.operation,
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onComplete,
  });

  final ClosingOperation operation;
  final ClosingStatus status;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetHandle(),
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
                _ClosingStatusChip(status: status, compact: true),
              ],
            ),
            const SizedBox(height: 16),
            _ClosingMetrics(operation: operation, compact: true),
            const SizedBox(height: 20),
            _ClosingActions(
              status: status,
              compact: true,
              onStart: onStart,
              onPause: onPause,
              onComplete: onComplete,
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileClosingLayout extends StatelessWidget {
  const _MobileClosingLayout({
    required this.operations,
    required this.selectedIndex,
    required this.statuses,
    required this.onSelect,
  });

  final List<ClosingOperation> operations;
  final int selectedIndex;
  final Map<int, ClosingStatus> statuses;
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
                  title: 'Fechamento de Producao',
                  operatorName: _operatorName,
                  compact: true,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'OPs para fechamento',
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
                          _ClosingCard(
                            operation: operations[i],
                            selected: i == selectedIndex,
                            status: statuses[i] ?? ClosingStatus.waiting,
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

class _DesktopClosingLayout extends StatelessWidget {
  const _DesktopClosingLayout({
    required this.operations,
    required this.selectedIndex,
    required this.statuses,
    required this.onSelect,
    required this.onStart,
    required this.onPause,
    required this.onComplete,
  });

  final List<ClosingOperation> operations;
  final int selectedIndex;
  final Map<int, ClosingStatus> statuses;
  final ValueChanged<int> onSelect;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onComplete;

  ClosingOperation get selectedOperation => operations[selectedIndex];
  ClosingStatus get status => statuses[selectedIndex] ?? ClosingStatus.waiting;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Column(
        children: [
          const VettiTopBar(
            title: 'Fechamento de Producao',
            operatorName: _operatorName,
            operatorRole: 'Fechamento',
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
                        child: _DesktopClosingQueue(
                          operations: operations,
                          selectedIndex: selectedIndex,
                          statuses: statuses,
                          onSelect: onSelect,
                        ),
                      ),
                      const SizedBox(width: 36),
                      Expanded(
                        child: _DesktopClosingDetail(
                          operation: selectedOperation,
                          status: status,
                          onStart: onStart,
                          onPause: onPause,
                          onComplete: onComplete,
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

class _DesktopClosingQueue extends StatelessWidget {
  const _DesktopClosingQueue({
    required this.operations,
    required this.selectedIndex,
    required this.statuses,
    required this.onSelect,
  });

  final List<ClosingOperation> operations;
  final int selectedIndex;
  final Map<int, ClosingStatus> statuses;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.inventory_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'OPs para fechamento',
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
              _CountBadge(value: '${operations.length}'),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Liberadas pelo teste para fechamento final.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < operations.length; i++) ...[
            _ClosingCard(
              operation: operations[i],
              selected: i == selectedIndex,
              status: statuses[i] ?? ClosingStatus.waiting,
              onTap: () => onSelect(i),
            ),
            if (i < operations.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _DesktopClosingDetail extends StatelessWidget {
  const _DesktopClosingDetail({
    required this.operation,
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onComplete,
  });

  final ClosingOperation operation;
  final ClosingStatus status;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(28),
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
              _ClosingStatusChip(status: status),
            ],
          ),
          const SizedBox(height: 24),
          _ClosingMetrics(operation: operation),
          const SizedBox(height: 28),
          _DividerLine(),
          const SizedBox(height: 28),
          const Text(
            'Acoes do fechamento',
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
          _ClosingActions(
            status: status,
            onStart: onStart,
            onPause: onPause,
            onComplete: onComplete,
          ),
        ],
      ),
    );
  }

  String _actionHint(ClosingStatus status) {
    return switch (status) {
      ClosingStatus.waiting =>
        'Inicie o fechamento para liberar pausa e conclusao.',
      ClosingStatus.active =>
        'Fechamento em andamento. Pause ou conclua a OP.',
      ClosingStatus.paused =>
        'OP pausada. Retome ou conclua registrando a quantidade fechada.',
      ClosingStatus.completed => 'OP finalizada nesta etapa.',
    };
  }
}

class _ClosingCard extends StatelessWidget {
  const _ClosingCard({
    required this.operation,
    required this.selected,
    required this.status,
    required this.onTap,
    this.compact = false,
  });

  final ClosingOperation operation;
  final bool selected;
  final ClosingStatus status;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final active = status != ClosingStatus.waiting;
    final radius = BorderRadius.circular(14);

    return Material(
      color: selected
          ? const Color(0xFFEAF7FF)
          : active
          ? status.surface
          : Colors.white,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            compact ? 14 : 16,
            compact ? 13 : 15,
            compact ? 14 : 16,
            compact ? 13 : 15,
          ),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : active
                  ? status.color.withValues(alpha: 0.35)
                  : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                if (active) ...[
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: status.color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              operation.number,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: compact ? 15 : 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (active)
                            _ClosingStatusChip(status: status, compact: true),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        operation.product,
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        '${operation.quantity} · ${operation.origin}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.smallText,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.chevron_right_rounded,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.iconMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClosingStatusChip extends StatelessWidget {
  const _ClosingStatusChip({required this.status, this.compact = false});

  final ClosingStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: status.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: compact ? 12 : 14, color: status.color),
          SizedBox(width: compact ? 4 : 6),
          Text(
            status.label,
            style: TextStyle(
              color: status.color,
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClosingMetrics extends StatelessWidget {
  const _ClosingMetrics({required this.operation, this.compact = false});

  final ClosingOperation operation;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Quantidade', operation.quantity),
      ('Origem', operation.origin),
      ('Recebida', operation.receivedAt),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 18,
        vertical: compact ? 12 : 15,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4EDF4)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < metrics.length; i++) ...[
            Expanded(
              child: _MetricItem(
                label: metrics[i].$1,
                value: metrics[i].$2,
                compact: compact,
              ),
            ),
            if (i < metrics.length - 1)
              Container(
                width: 1,
                height: compact ? 36 : 42,
                margin: EdgeInsets.symmetric(horizontal: compact ? 8 : 14),
                color: const Color(0xFFE9F0F5),
              ),
          ],
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.label,
    required this.value,
    required this.compact,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.label,
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.text,
            fontSize: compact ? 16 : 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ClosingActions extends StatelessWidget {
  const _ClosingActions({
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onComplete,
    this.compact = false,
  });

  final ClosingStatus status;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onComplete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (status == ClosingStatus.completed) {
      return Container(
        width: compact ? double.infinity : 480,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFE7F6EC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBFE5CC)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.green, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Fechamento assinado. OP liberada para expedicao.',
                style: TextStyle(
                  color: AppColors.green,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (status == ClosingStatus.waiting) {
      return _ActionButton(
        label: 'Iniciar fechamento',
        icon: Icons.play_arrow_rounded,
        onPressed: onStart,
        fillColor: AppColors.primary,
        foregroundColor: Colors.white,
        width: compact ? double.infinity : 240,
      );
    }

    if (status == ClosingStatus.paused) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _ActionButton(
            label: 'Retomar fechamento',
            icon: Icons.play_arrow_rounded,
            onPressed: onStart,
            fillColor: AppColors.primary,
            foregroundColor: Colors.white,
            width: compact ? double.infinity : 240,
          ),
          _ActionButton(
            label: 'Concluir fechamento',
            icon: Icons.check_rounded,
            onPressed: onComplete,
            foregroundColor: AppColors.green,
            borderColor: AppColors.green,
            width: compact ? double.infinity : 240,
          ),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ActionButton(
          label: 'Pausar OP',
          icon: Icons.pause_rounded,
          onPressed: onPause,
          foregroundColor: AppColors.orangeText,
          borderColor: AppColors.orange,
          width: compact ? double.infinity : 190,
        ),
        _ActionButton(
          label: 'Concluir fechamento',
          icon: Icons.check_rounded,
          onPressed: onComplete,
          fillColor: AppColors.green,
          foregroundColor: Colors.white,
          width: compact ? double.infinity : 240,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    required this.foregroundColor,
    this.icon,
    this.fillColor,
    this.borderColor,
    this.width,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final Color foregroundColor;
  final Color? fillColor;
  final Color? borderColor;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 20),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          backgroundColor: fillColor ?? Colors.white,
          foregroundColor: foregroundColor,
          side: BorderSide(
            color: borderColor ?? fillColor ?? Colors.white,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
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
      child: child,
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 1,
      color: const Color(0xFFEEF3F7),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// Conclusao — registra a quantidade fechada e assina com PIN.
// ────────────────────────────────────────────────────────────────────

Future<int?> showClosingCompletionDialog(
  BuildContext context,
  ClosingOperation operation,
) {
  final compact = MediaQuery.sizeOf(context).width < 720;

  if (compact) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _ClosingCompletionSheet(operation: operation, compact: true),
    );
  }

  return showDialog<int>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      backgroundColor: Colors.transparent,
      child: _ClosingCompletionSheet(operation: operation),
    ),
  );
}

class _ClosingCompletionSheet extends StatefulWidget {
  const _ClosingCompletionSheet({required this.operation, this.compact = false});

  final ClosingOperation operation;
  final bool compact;

  @override
  State<_ClosingCompletionSheet> createState() =>
      _ClosingCompletionSheetState();
}

class _ClosingCompletionSheetState extends State<_ClosingCompletionSheet> {
  late final TextEditingController _quantityController;
  final _pinController = TextEditingController();
  Operator? _operator;
  bool _invalidPin = false;
  bool _wrongStage = false;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: '${widget.operation.quantityValue}',
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  int? get _closedQuantity {
    final value = int.tryParse(_quantityController.text.trim());
    if (value == null) return null;
    if (value < 0 || value > widget.operation.quantityValue) return null;
    return value;
  }

  void _onPinChanged(String value) {
    if (value.length < 4) {
      setState(() {
        _operator = null;
        _invalidPin = false;
        _wrongStage = false;
      });
      return;
    }

    final operator = Operator.findByPin(value);
    setState(() {
      _operator = operator;
      _invalidPin = operator == null;
      _wrongStage = operator != null && operator.stage != WorkStage.closing;
    });
  }

  @override
  Widget build(BuildContext context) {
    final validPin = _operator != null && !_wrongStage;
    final quantity = _closedQuantity;
    final canConfirm = validPin && quantity != null;

    return _ModalSurface(
      compact: widget.compact,
      maxWidth: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.compact) const _SheetHandle(),
          const Text(
            'Concluir fechamento',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Registre a quantidade fechada e assine com o PIN para liberar a '
            '${widget.operation.number} para expedicao.',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          const Text(
            'Quantidade fechada',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _quantityController,
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FBFD),
              suffixText: 'de ${widget.operation.quantityValue} un',
              suffixStyle: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: _fieldBorder(AppColors.border),
              enabledBorder: _fieldBorder(
                quantity == null ? const Color(0xFFD45B5B) : AppColors.border,
              ),
              focusedBorder: _fieldBorder(
                quantity == null ? const Color(0xFFD45B5B) : AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
          if (quantity == null) ...[
            const SizedBox(height: 8),
            Text(
              'Informe um valor entre 0 e ${widget.operation.quantityValue}.',
              style: const TextStyle(
                color: Color(0xFFD45B5B),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'PIN (4 digitos)',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _pinController,
            onChanged: _onPinChanged,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 12,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: const Color(0xFFF8FBFD),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: _fieldBorder(AppColors.border),
              enabledBorder: _fieldBorder(
                _invalidPin
                    ? const Color(0xFFD45B5B)
                    : validPin
                    ? AppColors.green
                    : AppColors.border,
              ),
              focusedBorder: _fieldBorder(
                _invalidPin
                    ? const Color(0xFFD45B5B)
                    : validPin
                    ? AppColors.green
                    : AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_invalidPin)
            const _PinFeedback(
              icon: Icons.error_outline_rounded,
              color: Color(0xFFD45B5B),
              bgColor: Color(0xFFFFF0F0),
              borderColor: Color(0xFFE8C4C4),
              text: 'PIN nao encontrado. Verifique e tente novamente.',
            ),
          if (validPin)
            _PinFeedback(
              icon: Icons.check_circle_rounded,
              color: AppColors.green,
              bgColor: const Color(0xFFE7F6EC),
              borderColor: const Color(0xFFBFE5CC),
              text: 'Operador: ${_operator!.name} (${_operator!.stage.label})',
            ),
          if (_wrongStage && _operator != null)
            _PinFeedback(
              icon: Icons.warning_amber_rounded,
              color: AppColors.orangeText,
              bgColor: const Color(0xFFFFF8EC),
              borderColor: const Color(0xFFEFDFBF),
              text:
                  'PIN de ${_operator!.name}, vinculado a etapa "${_operator!.stage.label}". '
                  'Voce esta na etapa "Fechamento".',
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _DialogButton(
                  label: 'Cancelar',
                  onPressed: () => Navigator.of(context).pop(null),
                  fillColor: const Color(0xFFF6F9FB),
                  foregroundColor: AppColors.muted,
                  borderColor: AppColors.border,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _DialogButton(
                  label: 'Concluir OP',
                  onPressed: canConfirm
                      ? () => Navigator.of(context).pop(quantity)
                      : null,
                  fillColor: canConfirm
                      ? AppColors.green
                      : const Color(0xFFE4EDF4),
                  foregroundColor: canConfirm ? Colors.white : AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

class _ModalSurface extends StatelessWidget {
  const _ModalSurface({
    required this.child,
    required this.compact,
    required this.maxWidth,
  });

  final Widget child;
  final bool compact;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: compact ? Alignment.bottomCenter : Alignment.center,
      child: Container(
        width: compact ? double.infinity : null,
        constraints: BoxConstraints(
          maxWidth: compact ? double.infinity : maxWidth,
        ),
        margin: EdgeInsets.only(
          left: compact ? 10 : 0,
          right: compact ? 10 : 0,
          bottom: compact ? 10 : 0,
        ),
        padding: EdgeInsets.fromLTRB(
          compact ? 24 : 36,
          compact ? 16 : 32,
          compact ? 24 : 36,
          compact ? 24 : 28,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(compact ? 22 : 16),
        ),
        child: SingleChildScrollView(child: child),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.fillColor,
    required this.foregroundColor,
    this.onPressed,
    this.borderColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color fillColor;
  final Color foregroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: fillColor,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: const Color(0xFFE4EDF4),
          disabledForegroundColor: AppColors.muted,
          side: BorderSide(color: borderColor ?? fillColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 50,
        height: 4,
        margin: const EdgeInsets.only(bottom: 22),
        decoration: BoxDecoration(
          color: const Color(0xFFCBD7E1),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

class _PinFeedback extends StatelessWidget {
  const _PinFeedback({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
