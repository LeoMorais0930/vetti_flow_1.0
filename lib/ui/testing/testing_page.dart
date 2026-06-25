import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/shared/layout/app_breakpoints.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/vetti_top_bar.dart';

class TestOperation {
  const TestOperation({
    required this.number,
    required this.product,
    required this.quantity,
    required this.origin,
    required this.receivedAt,
    required this.firmwareDefects,
  });

  final String number;
  final String product;
  final String quantity;
  final String origin;
  final String receivedAt;
  final List<DefectEntry> firmwareDefects;
}

class DefectEntry {
  const DefectEntry({
    required this.code,
    required this.title,
    required this.quantity,
  });

  final String code;
  final String title;
  final String quantity;
}

class TestingPage extends StatefulWidget {
  const TestingPage({super.key});

  @override
  State<TestingPage> createState() => _TestingPageState();
}

class _TestingPageState extends State<TestingPage> {
  final _operations = const [
    TestOperation(
      number: 'OP-00564-345',
      product: 'CR4 - Controle 4 teclas',
      quantity: '2985 un',
      origin: 'Gravacao',
      receivedAt: '11:14',
      firmwareDefects: [
        DefectEntry(code: 'A', title: 'Nao gravou', quantity: '12 un'),
        DefectEntry(code: 'D', title: 'Firmware incorreto', quantity: '3 un'),
      ],
    ),
    TestOperation(
      number: 'OP-00564-346',
      product: '105-141 - Central Vetti Smart',
      quantity: '496 un',
      origin: 'Gravacao',
      receivedAt: '11:22',
      firmwareDefects: [
        DefectEntry(code: 'A', title: 'Nao gravou', quantity: '4 un'),
      ],
    ),
    TestOperation(
      number: 'OP-00564-347',
      product: 'TX-433 - Transmissor RF',
      quantity: '1200 un',
      origin: 'Gravacao',
      receivedAt: '11:35',
      firmwareDefects: [],
    ),
  ];

  var _selectedIndex = 0;
  var _status = 'Aguardando';

  TestOperation get _selectedOperation => _operations[_selectedIndex];

  void _startTest() {
    setState(() => _status = 'Em teste');
  }

  void _pauseOperation() {
    setState(() => _status = 'Pausada');
  }

  Future<void> _completeTest() async {
    final confirmed = await showTestDefectsDialog(context, _selectedOperation);
    if (!mounted || confirmed != true) return;

    setState(() => _status = 'Concluida');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_selectedOperation.number}: defeitos seguem ao suporte e saldo aprovado segue para frente.',
        ),
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
          return _MobileTestingLayout(
            operations: _operations,
            selectedIndex: _selectedIndex,
            status: _status,
            onSelect: (index) => setState(() => _selectedIndex = index),
            onStart: _startTest,
            onPause: _pauseOperation,
            onComplete: _completeTest,
          );
        }

        return _DesktopTestingLayout(
          operations: _operations,
          selectedIndex: _selectedIndex,
          status: _status,
          onSelect: (index) => setState(() => _selectedIndex = index),
          onStart: _startTest,
          onPause: _pauseOperation,
          onComplete: _completeTest,
        );
      },
    );
  }
}

class _DesktopTestingLayout extends StatelessWidget {
  const _DesktopTestingLayout({
    required this.operations,
    required this.selectedIndex,
    required this.status,
    required this.onSelect,
    required this.onStart,
    required this.onPause,
    required this.onComplete,
  });

  final List<TestOperation> operations;
  final int selectedIndex;
  final String status;
  final ValueChanged<int> onSelect;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onComplete;

  TestOperation get selectedOperation => operations[selectedIndex];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Column(
        children: [
          const VettiTopBar(
            title: 'Teste de Producao',
            operatorName: 'Joao',
            operatorRole: 'Teste',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(40, 46, 40, 36),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppBreakpoints.maxContentWidth,
                    minWidth: 1040,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 390,
                        child: _TestingQueue(
                          operations: operations,
                          selectedIndex: selectedIndex,
                          onSelect: onSelect,
                        ),
                      ),
                      const SizedBox(width: 72),
                      Expanded(
                        child: _TestingDetails(
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

class _MobileTestingLayout extends StatelessWidget {
  const _MobileTestingLayout({
    required this.operations,
    required this.selectedIndex,
    required this.status,
    required this.onSelect,
    required this.onStart,
    required this.onPause,
    required this.onComplete,
  });

  final List<TestOperation> operations;
  final int selectedIndex;
  final String status;
  final ValueChanged<int> onSelect;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onComplete;

  TestOperation get selectedOperation => operations[selectedIndex];

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
                  title: 'Teste de Producao',
                  operatorName: 'Joao',
                  compact: true,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 18, 12, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: _TestingHeader(compact: true),
                        ),
                        const SizedBox(height: 18),
                        for (var i = 0; i < operations.length; i++) ...[
                          _TestingCard(
                            operation: operations[i],
                            selected: i == selectedIndex,
                            compact: true,
                            onTap: () => onSelect(i),
                          ),
                          if (i < operations.length - 1)
                            const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 26),
                        _FirmwareDefectsPanel(operation: selectedOperation),
                        const SizedBox(height: 18),
                        _TestingActions(
                          compact: true,
                          onStart: onStart,
                          onPause: onPause,
                          onComplete: onComplete,
                        ),
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

class _TestingQueue extends StatelessWidget {
  const _TestingQueue({
    required this.operations,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<TestOperation> operations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TestingHeader(),
        const SizedBox(height: 38),
        for (var i = 0; i < operations.length; i++) ...[
          _TestingCard(
            operation: operations[i],
            selected: i == selectedIndex,
            onTap: () => onSelect(i),
          ),
          if (i < operations.length - 1) const SizedBox(height: 23),
        ],
      ],
    );
  }
}

class _TestingHeader extends StatelessWidget {
  const _TestingHeader({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OPs para teste',
          style: TextStyle(
            color: AppColors.text,
            fontSize: compact ? 24 : 32,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        SizedBox(height: compact ? 6 : 8),
        Text(
          compact
              ? 'Recebidas da gravacao.'
              : 'Defeitos da gravacao ficam fixos na OP; defeitos do teste vao ao suporte.',
          style: TextStyle(color: AppColors.muted, fontSize: compact ? 13 : 16),
        ),
      ],
    );
  }
}

class _TestingDetails extends StatelessWidget {
  const _TestingDetails({
    required this.operation,
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onComplete,
  });

  final TestOperation operation;
  final String status;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            operation.number,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            operation.product,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 42),
          _TestingMetrics(operation: operation, status: status),
          const SizedBox(height: 32),
          _FirmwareDefectsPanel(operation: operation),
          const SizedBox(height: 54),
          const Text(
            'Acoes do teste',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ao concluir, registre defeitos do teste. Defeitos seguem ao suporte e o saldo aprovado segue para frente.',
            style: TextStyle(color: AppColors.muted, fontSize: 16),
          ),
          const SizedBox(height: 36),
          _TestingActions(
            onStart: onStart,
            onPause: onPause,
            onComplete: onComplete,
          ),
        ],
      ),
    );
  }
}

class _TestingCard extends StatelessWidget {
  const _TestingCard({
    required this.operation,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final TestOperation operation;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(compact ? 10 : 8);

    return Material(
      color: selected ? const Color(0xFFEAF7FF) : Colors.white,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: compact ? 112 : 126),
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 20,
            compact ? 14 : 16,
            compact ? 16 : 20,
            compact ? 13 : 14,
          ),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                operation.number,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: compact ? 17 : 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: compact ? 10 : 12),
              Text(
                operation.product,
                maxLines: compact ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: compact ? 13 : 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: compact ? 12 : 14),
              Text(
                'Qtd: ${operation.quantity} · Origem: ${operation.origin}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.smallText,
                  fontSize: compact ? 11 : 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestingMetrics extends StatelessWidget {
  const _TestingMetrics({required this.operation, required this.status});

  final TestOperation operation;
  final String status;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Saldo para teste', operation.quantity),
      ('Origem', operation.origin),
      ('Recebida', operation.receivedAt),
      ('Status atual', status),
    ];

    return Wrap(
      spacing: 24,
      runSpacing: 18,
      children: [
        for (final metric in metrics)
          _MetricCard(
            label: metric.$1,
            value: metric.$2,
            wide:
                metric.$1 == 'Saldo para teste' || metric.$1 == 'Status atual',
          ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.wide,
  });

  final String label;
  final String value;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? 205 : 160,
      constraints: const BoxConstraints(minHeight: 98),
      padding: const EdgeInsets.fromLTRB(20, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE4EDF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.label,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FirmwareDefectsPanel extends StatelessWidget {
  const _FirmwareDefectsPanel({required this.operation});

  final TestOperation operation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9EF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF4D7A7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Defeitos fixos da gravacao',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          if (operation.firmwareDefects.isEmpty)
            const Text(
              'Nenhum defeito registrado na gravacao.',
              style: TextStyle(color: AppColors.muted),
            )
          else
            for (final defect in operation.firmwareDefects) ...[
              Text(
                '${defect.code} - ${defect.title}: ${defect.quantity}',
                style: const TextStyle(color: AppColors.orangeText),
              ),
              const SizedBox(height: 4),
            ],
        ],
      ),
    );
  }
}

class _TestingActions extends StatelessWidget {
  const _TestingActions({
    required this.onStart,
    required this.onPause,
    required this.onComplete,
    this.compact = false,
  });

  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onComplete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acoes da OP',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          _ActionButton(
            label: 'Iniciar teste',
            icon: Icons.play_arrow_rounded,
            onPressed: onStart,
            fillColor: AppColors.primary,
            foregroundColor: Colors.white,
            width: double.infinity,
            height: 54,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Pausar OP',
                  onPressed: onPause,
                  foregroundColor: AppColors.orangeText,
                  borderColor: AppColors.orange,
                  height: 54,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _ActionButton(
                  label: 'Concluir',
                  onPressed: onComplete,
                  foregroundColor: AppColors.green,
                  borderColor: AppColors.green,
                  height: 54,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: [
        _ActionButton(
          label: 'Iniciar teste',
          icon: Icons.play_arrow_rounded,
          onPressed: onStart,
          fillColor: AppColors.primary,
          foregroundColor: Colors.white,
          width: 250,
        ),
        _ActionButton(
          label: 'Pausar OP',
          icon: Icons.pause_rounded,
          onPressed: onPause,
          foregroundColor: AppColors.orangeText,
          borderColor: AppColors.orange,
          width: 250,
        ),
        _ActionButton(
          label: 'Concluir teste',
          icon: Icons.check_rounded,
          onPressed: onComplete,
          foregroundColor: AppColors.green,
          borderColor: AppColors.green,
          width: 250,
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
    this.height = 74,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final Color foregroundColor;
  final Color? fillColor;
  final Color? borderColor;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: fillColor ?? Colors.white,
          foregroundColor: foregroundColor,
          side: BorderSide(
            color: borderColor ?? fillColor ?? Colors.white,
            width: 2,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 22),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> showTestDefectsDialog(
  BuildContext context,
  TestOperation operation,
) {
  final compact = MediaQuery.sizeOf(context).width < 720;
  final content = _TestDefectsSheet(operation: operation, compact: compact);

  if (compact) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => content,
    );
  }

  return showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      backgroundColor: Colors.transparent,
      child: content,
    ),
  );
}

class _TestDefectsSheet extends StatelessWidget {
  const _TestDefectsSheet({required this.operation, required this.compact});

  final TestOperation operation;
  final bool compact;

  static const _testDefects = [
    DefectEntry(code: 'T2', title: 'Sem resposta', quantity: '12 un'),
    DefectEntry(code: 'T7', title: 'Falha intermitente', quantity: '5 un'),
  ];

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: compact ? Alignment.bottomCenter : Alignment.center,
      child: Container(
        width: compact ? double.infinity : 620,
        margin: EdgeInsets.only(
          left: compact ? 10 : 0,
          right: compact ? 10 : 0,
          bottom: compact ? 10 : 0,
        ),
        padding: EdgeInsets.fromLTRB(34, compact ? 20 : 38, 34, 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(compact ? 22 : 8),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact) const _SheetHandle(),
              const Text(
                'Defeitos do teste',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${operation.number} · informe defeitos encontrados no teste.',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 24),
              const Text(
                'Defeitos da gravacao (fixos)',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              _CompactDefectList(defects: operation.firmwareDefects),
              const SizedBox(height: 24),
              const Text(
                'Defeitos apontados no teste',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              const _CompactDefectList(defects: _testDefects),
              const SizedBox(height: 20),
              TextField(
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Observacao opcional',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Voltar'),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Concluir'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactDefectList extends StatelessWidget {
  const _CompactDefectList({required this.defects});

  final List<DefectEntry> defects;

  @override
  Widget build(BuildContext context) {
    if (defects.isEmpty) {
      return const Text(
        'Nenhum defeito registrado.',
        style: TextStyle(color: AppColors.muted),
      );
    }

    return Column(
      children: [
        for (final defect in defects) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FBFD),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE3EDF4)),
            ),
            child: Text(
              '${defect.code} - ${defect.title}: ${defect.quantity}',
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 70,
        height: 5,
        margin: const EdgeInsets.only(bottom: 28),
        decoration: BoxDecoration(
          color: const Color(0xFFCBD7E1),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
