import 'package:flutter/material.dart';
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
  final _operations = const [
    FirmwareOperation(
      number: 'OP-00564-345',
      product: 'CR4 - Controle 4 teclas',
      quantity: '3000 un',
      origin: 'SMD',
      receivedAt: '09:42',
      receivedAgo: 'Recebida ha 12 min',
    ),
    FirmwareOperation(
      number: 'OP-00564-346',
      product: '105-141 - Central Vetti Smart',
      quantity: '500 un',
      origin: 'SMD',
      receivedAt: '09:55',
      receivedAgo: 'Recebida ha 4 min',
    ),
    FirmwareOperation(
      number: 'OP-00564-347',
      product: 'TX-433 - Transmissor RF',
      quantity: '1200 un',
      origin: 'SMD',
      receivedAt: '10:08',
      receivedAgo: 'Recebida agora',
    ),
  ];

  var _selectedIndex = 0;
  final _statuses = <int, FirmwareStatus>{};

  FirmwareOperation get _selectedOperation => _operations[_selectedIndex];
  FirmwareStatus _statusOf(int index) =>
      _statuses[index] ?? FirmwareStatus.waiting;

  void _select(int index) {
    setState(() => _selectedIndex = index);
  }

  void _setStatus(int index, FirmwareStatus status) {
    setState(() => _statuses[index] = status);
  }

  void _startRecording() =>
      _setStatus(_selectedIndex, FirmwareStatus.recording);

  void _pauseOperation() => _setStatus(_selectedIndex, FirmwareStatus.paused);

  void _resetOperation() => _setStatus(_selectedIndex, FirmwareStatus.waiting);

  Future<void> _completeOperation() async {
    final defects = await showFirmwareDefectsDialog(context);
    if (!mounted || defects == null) return;

    final signed = await showFirmwarePinDialog(
      context,
      _selectedOperation,
      defects: defects,
    );
    if (!mounted || signed != true) return;

    _setStatus(_selectedIndex, FirmwareStatus.completed);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_selectedOperation.number} concluida.')),
    );
  }

  void _showMobileActions(BuildContext context) {
    final status = _statusOf(_selectedIndex);
    final op = _selectedOperation;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final formFactor = constraints.maxWidth >= 1180
            ? AppFormFactor.expanded
            : AppBreakpoints.fromWidth(constraints.maxWidth);
        final isMobile = formFactor != AppFormFactor.expanded;

        if (isMobile) {
          return _MobileFirmwareLayout(
            operations: _operations,
            selectedIndex: _selectedIndex,
            statuses: _statuses,
            onSelect: (i) {
              _select(i);
              _showMobileActions(context);
            },
          );
        }

        return _DesktopFirmwareLayout(
          operations: _operations,
          selectedIndex: _selectedIndex,
          statuses: _statuses,
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
