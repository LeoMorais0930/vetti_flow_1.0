import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/shared/layout/app_breakpoints.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/vetti_top_bar.dart';

class ExpeditionOrder {
  const ExpeditionOrder({
    required this.number,
    required this.product,
    required this.quantity,
    required this.origin,
    required this.destination,
    required this.readyAt,
    required this.status,
  });

  final String number;
  final String product;
  final String quantity;
  final String origin;
  final String destination;
  final String readyAt;
  final String status;
}

class ExpeditionPage extends StatefulWidget {
  const ExpeditionPage({super.key});

  @override
  State<ExpeditionPage> createState() => _ExpeditionPageState();
}

class _ExpeditionPageState extends State<ExpeditionPage> {
  final _orders = const [
    ExpeditionOrder(
      number: 'OP-00564-348',
      product: 'CR4 - Controle 4 teclas',
      quantity: '2968 un',
      origin: 'Teste aprovado',
      destination: 'Estoque acabado',
      readyAt: '12:18',
      status: 'Aguardando expedicao',
    ),
    ExpeditionOrder(
      number: 'OP-00565-112',
      product: 'Central Vetti Smart',
      quantity: '495 un',
      origin: 'Suporte tecnico',
      destination: 'Estoque acabado',
      readyAt: '12:34',
      status: 'Aguardando expedicao',
    ),
    ExpeditionOrder(
      number: 'OP-00566-078',
      product: 'Modulo RF Vetti One',
      quantity: '1187 un',
      origin: 'Teste aprovado',
      destination: 'Separacao comercial',
      readyAt: '12:51',
      status: 'Em conferencia',
    ),
  ];

  var _selectedIndex = 0;
  var _status = 'Aguardando expedicao';

  ExpeditionOrder get _selectedOrder => _orders[_selectedIndex];

  void _startExpedition() {
    setState(() => _status = 'Em conferencia');
  }

  void _pauseExpedition() {
    setState(() => _status = 'Pausada');
  }

  Future<void> _finishExpedition() async {
    final confirmed = await showExpeditionFinishDialog(
      context,
      order: _selectedOrder,
    );
    if (!mounted || confirmed != true) return;
    setState(() => _status = 'OP finalizada');
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
          return _MobileExpeditionLayout(
            orders: _orders,
            selectedIndex: _selectedIndex,
            status: _status,
            onSelect: (index) => setState(() {
              _selectedIndex = index;
              _status = _orders[index].status;
            }),
            onStart: _startExpedition,
            onPause: _pauseExpedition,
            onFinish: _finishExpedition,
          );
        }

        return _DesktopExpeditionLayout(
          orders: _orders,
          selectedIndex: _selectedIndex,
          status: _status,
          onSelect: (index) => setState(() {
            _selectedIndex = index;
            _status = _orders[index].status;
          }),
          onStart: _startExpedition,
          onPause: _pauseExpedition,
          onFinish: _finishExpedition,
        );
      },
    );
  }
}

class _DesktopExpeditionLayout extends StatelessWidget {
  const _DesktopExpeditionLayout({
    required this.orders,
    required this.selectedIndex,
    required this.status,
    required this.onSelect,
    required this.onStart,
    required this.onPause,
    required this.onFinish,
  });

  final List<ExpeditionOrder> orders;
  final int selectedIndex;
  final String status;
  final ValueChanged<int> onSelect;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onFinish;

  ExpeditionOrder get selectedOrder => orders[selectedIndex];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Column(
        children: [
          const VettiTopBar(
            title: 'Expedicao',
            operatorName: 'Camila',
            operatorRole: 'Expedicao',
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
                        child: _ExpeditionQueue(
                          orders: orders,
                          selectedIndex: selectedIndex,
                          onSelect: onSelect,
                        ),
                      ),
                      const SizedBox(width: 72),
                      Expanded(
                        child: _ExpeditionDetails(
                          order: selectedOrder,
                          status: status,
                          onStart: onStart,
                          onPause: onPause,
                          onFinish: onFinish,
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

class _MobileExpeditionLayout extends StatelessWidget {
  const _MobileExpeditionLayout({
    required this.orders,
    required this.selectedIndex,
    required this.status,
    required this.onSelect,
    required this.onStart,
    required this.onPause,
    required this.onFinish,
  });

  final List<ExpeditionOrder> orders;
  final int selectedIndex;
  final String status;
  final ValueChanged<int> onSelect;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onFinish;

  ExpeditionOrder get selectedOrder => orders[selectedIndex];

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
                  title: 'Expedicao',
                  operatorName: 'Camila',
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
                          child: _ExpeditionHeader(compact: true),
                        ),
                        const SizedBox(height: 18),
                        for (var i = 0; i < orders.length; i++) ...[
                          _ExpeditionCard(
                            order: orders[i],
                            selected: i == selectedIndex,
                            compact: true,
                            onTap: () => onSelect(i),
                          ),
                          if (i < orders.length - 1) const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 24),
                        _MobileExpeditionSummary(
                          order: selectedOrder,
                          status: status,
                        ),
                        const SizedBox(height: 16),
                        _ExpeditionDestinationPanel(order: selectedOrder),
                        const SizedBox(height: 18),
                        _ExpeditionActions(
                          compact: true,
                          onStart: onStart,
                          onPause: onPause,
                          onFinish: onFinish,
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

class _ExpeditionQueue extends StatelessWidget {
  const _ExpeditionQueue({
    required this.orders,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<ExpeditionOrder> orders;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ExpeditionHeader(),
        const SizedBox(height: 38),
        for (var i = 0; i < orders.length; i++) ...[
          _ExpeditionCard(
            order: orders[i],
            selected: i == selectedIndex,
            onTap: () => onSelect(i),
          ),
          if (i < orders.length - 1) const SizedBox(height: 23),
        ],
      ],
    );
  }
}

class _ExpeditionHeader extends StatelessWidget {
  const _ExpeditionHeader({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OPs prontas',
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
              ? 'Liberadas para finalizar.'
              : 'Recebe OPs aprovadas no teste ou liberadas pelo suporte tecnico.',
          style: TextStyle(color: AppColors.muted, fontSize: compact ? 13 : 16),
        ),
      ],
    );
  }
}

class _ExpeditionDetails extends StatelessWidget {
  const _ExpeditionDetails({
    required this.order,
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onFinish,
  });

  final ExpeditionOrder order;
  final String status;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.number,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            order.product,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 38),
          _ExpeditionMetrics(order: order, status: status),
          const SizedBox(height: 32),
          _ExpeditionDestinationPanel(order: order),
          const SizedBox(height: 54),
          const Text(
            'Acoes da expedicao',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'A expedicao confere a quantidade e finaliza a OP com assinatura por PIN.',
            style: TextStyle(color: AppColors.muted, fontSize: 16),
          ),
          const SizedBox(height: 36),
          _ExpeditionActions(
            onStart: onStart,
            onPause: onPause,
            onFinish: onFinish,
          ),
        ],
      ),
    );
  }
}

class _ExpeditionCard extends StatelessWidget {
  const _ExpeditionCard({
    required this.order,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final ExpeditionOrder order;
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
          constraints: BoxConstraints(minHeight: compact ? 118 : 126),
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
                order.number,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: compact ? 17 : 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: compact ? 8 : 10),
              Text(
                order.product,
                maxLines: compact ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: compact ? 13 : 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: compact ? 10 : 12),
              Text(
                '${order.quantity} · ${order.origin}',
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

class _ExpeditionMetrics extends StatelessWidget {
  const _ExpeditionMetrics({required this.order, required this.status});

  final ExpeditionOrder order;
  final String status;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Quantidade', order.quantity),
      ('Origem', order.origin),
      ('Liberada', order.readyAt),
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
            wide: metric.$1 == 'Status atual' || metric.$1 == 'Origem',
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
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpeditionDestinationPanel extends StatelessWidget {
  const _ExpeditionDestinationPanel({required this.order});

  final ExpeditionOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFB8DFF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Destino da OP',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            order.destination,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Origem: ${order.origin}',
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _ExpeditionActions extends StatelessWidget {
  const _ExpeditionActions({
    required this.onStart,
    required this.onPause,
    required this.onFinish,
    this.compact = false,
  });

  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onFinish;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acoes',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          _ActionButton(
            label: 'Iniciar expedicao',
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
                  label: 'Pausar',
                  icon: Icons.pause_rounded,
                  onPressed: onPause,
                  foregroundColor: AppColors.orangeText,
                  borderColor: AppColors.orange,
                  height: 54,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _ActionButton(
                  label: 'Finalizar',
                  icon: Icons.check_rounded,
                  onPressed: onFinish,
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
          label: 'Iniciar expedicao',
          icon: Icons.play_arrow_rounded,
          onPressed: onStart,
          fillColor: AppColors.primary,
          foregroundColor: Colors.white,
          width: 270,
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
          label: 'Finalizar OP',
          icon: Icons.check_rounded,
          onPressed: onFinish,
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
    required this.icon,
    required this.onPressed,
    required this.foregroundColor,
    this.fillColor,
    this.borderColor,
    this.width,
    this.height = 74,
  });

  final String label;
  final IconData icon;
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
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
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
      ),
    );
  }
}

class _MobileExpeditionSummary extends StatelessWidget {
  const _MobileExpeditionSummary({required this.order, required this.status});

  final ExpeditionOrder order;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryValue(label: 'Quantidade', value: order.quantity),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: _SummaryValue(label: 'Status', value: status),
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.label,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

Future<bool?> showExpeditionFinishDialog(
  BuildContext context, {
  required ExpeditionOrder order,
}) {
  final observationController = TextEditingController();

  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Finalizar OP'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${order.number} · ${order.quantity}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: observationController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Observacao opcional',
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(labelText: 'PIN', hintText: '4321'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Finalizar'),
        ),
      ],
    ),
  ).whenComplete(observationController.dispose);
}
