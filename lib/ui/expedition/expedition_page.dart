import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vetti_flow_1_0/shared/layout/app_breakpoints.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/vetti_top_bar.dart';

class ExpeditionOrder {
  const ExpeditionOrder({
    required this.number,
    required this.product,
    required this.quantity,
    required this.origin,
    required this.readyAt,
    required this.readyAgo,
    required this.orderCode,
    required this.customer,
    required this.channel,
    required this.carrier,
    required this.packaging,
  });

  final String number;
  final String product;
  final String quantity;
  final String origin;
  final String readyAt;
  final String readyAgo;
  final String orderCode;
  final String customer;
  final String channel;
  final String carrier;
  final List<String> packaging;
}

enum ExpeditionStatus {
  waiting(
    'Aguardando',
    AppColors.muted,
    Color(0xFFEFF3F7),
    Icons.schedule_rounded,
  ),
  active(
    'Em conferencia',
    AppColors.primary,
    Color(0xFFE7F4FB),
    Icons.inventory_2_rounded,
  ),
  paused(
    'Pausada',
    AppColors.orangeText,
    Color(0xFFFBF1E2),
    Icons.pause_rounded,
  ),
  completed(
    'Despachada',
    AppColors.green,
    Color(0xFFE7F6EC),
    Icons.check_circle_rounded,
  );

  const ExpeditionStatus(this.label, this.color, this.surface, this.icon);

  final String label;
  final Color color;
  final Color surface;
  final IconData icon;
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
      readyAt: '12:18',
      readyAgo: 'Liberada ha 18 min',
      orderCode: 'PED-77421',
      customer: 'Estoque acabado',
      channel: 'Reposicao interna',
      carrier: 'Movimentacao interna',
      packaging: [
        'Conferir etiqueta da OP e quantidade final.',
        'Separar em caixas padrao CR4 com lacre azul.',
        'Registrar volume e local de destino.',
      ],
    ),
    ExpeditionOrder(
      number: 'OP-00565-112',
      product: 'Central Vetti Smart',
      quantity: '495 un',
      origin: 'Suporte tecnico',
      readyAt: '12:34',
      readyAgo: 'Liberada ha 7 min',
      orderCode: 'PED-77435',
      customer: 'Distribuidor Sul',
      channel: 'Pedido comercial',
      carrier: 'Retirada agendada',
      packaging: [
        'Embalar centrais com fonte e manual revisados.',
        'Aplicar etiqueta de revisao do suporte.',
        'Separar volumes por lote comercial.',
      ],
    ),
    ExpeditionOrder(
      number: 'OP-00566-078',
      product: 'Modulo RF Vetti One',
      quantity: '1187 un',
      origin: 'Teste aprovado',
      readyAt: '12:51',
      readyAgo: 'Liberada agora',
      orderCode: 'PED-77448',
      customer: 'Separacao comercial',
      channel: 'Venda direta',
      carrier: 'Transportadora parceira',
      packaging: [
        'Conferir protecao antiestatica por pacote.',
        'Separar volumes de ate 100 unidades.',
        'Anexar romaneio ao volume principal.',
      ],
    ),
  ];

  var _selectedIndex = 0;
  final _statuses = <int, ExpeditionStatus>{};

  ExpeditionOrder get _selectedOrder => _orders[_selectedIndex];
  ExpeditionStatus _statusOf(int index) =>
      _statuses[index] ?? ExpeditionStatus.waiting;

  void _select(int index) {
    setState(() => _selectedIndex = index);
  }

  void _setStatus(int index, ExpeditionStatus status) {
    setState(() => _statuses[index] = status);
  }

  void _startExpedition() =>
      _setStatus(_selectedIndex, ExpeditionStatus.active);

  void _pauseExpedition() =>
      _setStatus(_selectedIndex, ExpeditionStatus.paused);

  Future<void> _finishExpedition() async {
    final signed = await showExpeditionPinDialog(context, _selectedOrder);
    if (!mounted || signed != true) return;

    _setStatus(_selectedIndex, ExpeditionStatus.completed);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_selectedOrder.number} despachada.')),
    );
  }

  void _showMobileActions(BuildContext context) {
    final status = _statusOf(_selectedIndex);
    final order = _selectedOrder;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MobileExpeditionActionSheet(
        order: order,
        status: status,
        onStart: () {
          Navigator.pop(ctx);
          _startExpedition();
        },
        onPause: () {
          Navigator.pop(ctx);
          _pauseExpedition();
        },
        onFinish: () {
          Navigator.pop(ctx);
          _finishExpedition();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final formFactor = AppBreakpoints.fromWidth(constraints.maxWidth);
        final isMobile = formFactor != AppFormFactor.expanded;

        if (isMobile) {
          return _MobileExpeditionLayout(
            orders: _orders,
            selectedIndex: _selectedIndex,
            statuses: _statuses,
            onSelect: (index) {
              _select(index);
              _showMobileActions(context);
            },
          );
        }

        return _DesktopExpeditionLayout(
          orders: _orders,
          selectedIndex: _selectedIndex,
          statuses: _statuses,
          onSelect: _select,
          onStart: _startExpedition,
          onPause: _pauseExpedition,
          onFinish: _finishExpedition,
        );
      },
    );
  }
}

class _MobileExpeditionActionSheet extends StatelessWidget {
  const _MobileExpeditionActionSheet({
    required this.order,
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onFinish,
  });

  final ExpeditionOrder order;
  final ExpeditionStatus status;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onFinish;

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
                        order.number,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.product,
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
                _ExpeditionStatusChip(status: status, compact: true),
              ],
            ),
            const SizedBox(height: 16),
            _ExpeditionMetrics(order: order, compact: true),
            const SizedBox(height: 16),
            _DestinationPanel(order: order, compact: true),
            const SizedBox(height: 16),
            _PackagingPanel(order: order, compact: true),
            const SizedBox(height: 20),
            _ExpeditionActions(
              status: status,
              compact: true,
              onStart: onStart,
              onPause: onPause,
              onFinish: onFinish,
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileExpeditionLayout extends StatelessWidget {
  const _MobileExpeditionLayout({
    required this.orders,
    required this.selectedIndex,
    required this.statuses,
    required this.onSelect,
  });

  final List<ExpeditionOrder> orders;
  final int selectedIndex;
  final Map<int, ExpeditionStatus> statuses;
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
                  title: 'Expedicao',
                  operatorName: 'Ricardo',
                  compact: true,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'OPs prontas',
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Toque na OP para conferir destino e embalagem.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        for (var i = 0; i < orders.length; i++) ...[
                          _ExpeditionCard(
                            order: orders[i],
                            selected: i == selectedIndex,
                            status: statuses[i] ?? ExpeditionStatus.waiting,
                            compact: true,
                            onTap: () => onSelect(i),
                          ),
                          if (i < orders.length - 1) const SizedBox(height: 10),
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

class _DesktopExpeditionLayout extends StatelessWidget {
  const _DesktopExpeditionLayout({
    required this.orders,
    required this.selectedIndex,
    required this.statuses,
    required this.onSelect,
    required this.onStart,
    required this.onPause,
    required this.onFinish,
  });

  final List<ExpeditionOrder> orders;
  final int selectedIndex;
  final Map<int, ExpeditionStatus> statuses;
  final ValueChanged<int> onSelect;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onFinish;

  ExpeditionOrder get selectedOrder => orders[selectedIndex];
  ExpeditionStatus get status =>
      statuses[selectedIndex] ?? ExpeditionStatus.waiting;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Column(
        children: [
          const VettiTopBar(
            title: 'Expedicao',
            operatorName: 'Ricardo',
            operatorRole: 'Expedicao',
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
                        child: _DesktopExpeditionQueue(
                          orders: orders,
                          selectedIndex: selectedIndex,
                          statuses: statuses,
                          onSelect: onSelect,
                        ),
                      ),
                      const SizedBox(width: 36),
                      Expanded(
                        child: _DesktopExpeditionDetail(
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

class _DesktopExpeditionQueue extends StatelessWidget {
  const _DesktopExpeditionQueue({
    required this.orders,
    required this.selectedIndex,
    required this.statuses,
    required this.onSelect,
  });

  final List<ExpeditionOrder> orders;
  final int selectedIndex;
  final Map<int, ExpeditionStatus> statuses;
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
                Icons.local_shipping_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'OPs prontas',
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
              _CountBadge(value: '${orders.length}'),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Aprovadas no teste para conferencia e despacho.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < orders.length; i++) ...[
            _ExpeditionCard(
              order: orders[i],
              selected: i == selectedIndex,
              status: statuses[i] ?? ExpeditionStatus.waiting,
              onTap: () => onSelect(i),
            ),
            if (i < orders.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _DesktopExpeditionDetail extends StatelessWidget {
  const _DesktopExpeditionDetail({
    required this.order,
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onFinish,
  });

  final ExpeditionOrder order;
  final ExpeditionStatus status;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onFinish;

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
                      order.number,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      order.product,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.readyAgo,
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
              _ExpeditionStatusChip(status: status),
            ],
          ),
          const SizedBox(height: 24),
          _ExpeditionMetrics(order: order),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _DestinationPanel(order: order)),
              const SizedBox(width: 16),
              Expanded(child: _PackagingPanel(order: order)),
            ],
          ),
          const SizedBox(height: 28),
          _DividerLine(),
          const SizedBox(height: 28),
          const Text(
            'Acoes da expedicao',
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
          _ExpeditionActions(
            status: status,
            onStart: onStart,
            onPause: onPause,
            onFinish: onFinish,
          ),
        ],
      ),
    );
  }

  String _actionHint(ExpeditionStatus status) {
    return switch (status) {
      ExpeditionStatus.waiting =>
        'Inicie a conferencia para liberar pausa e despacho.',
      ExpeditionStatus.active =>
        'Conferencia em andamento. Pause ou finalize o despacho.',
      ExpeditionStatus.paused =>
        'OP pausada. Retome ou finalize com assinatura.',
      ExpeditionStatus.completed => 'OP finalizada na expedicao.',
    };
  }
}

class _ExpeditionCard extends StatelessWidget {
  const _ExpeditionCard({
    required this.order,
    required this.selected,
    required this.status,
    required this.onTap,
    this.compact = false,
  });

  final ExpeditionOrder order;
  final bool selected;
  final ExpeditionStatus status;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final active = status != ExpeditionStatus.waiting;
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
                              order.number,
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
                            _ExpeditionStatusChip(
                              status: status,
                              compact: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        order.product,
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
                        '${order.quantity} · ${order.orderCode}',
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

class _ExpeditionStatusChip extends StatelessWidget {
  const _ExpeditionStatusChip({required this.status, this.compact = false});

  final ExpeditionStatus status;
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

class _ExpeditionMetrics extends StatelessWidget {
  const _ExpeditionMetrics({required this.order, this.compact = false});

  final ExpeditionOrder order;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Quantidade', order.quantity),
      ('Origem', order.origin),
      ('Liberada', order.readyAt),
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

class _DestinationPanel extends StatelessWidget {
  const _DestinationPanel({required this.order, this.compact = false});

  final ExpeditionOrder order;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Pedido', order.orderCode),
      ('Destino', order.customer),
      ('Canal', order.channel),
      ('Transporte', order.carrier),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB8DFF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Destino',
            style: TextStyle(
              color: AppColors.text,
              fontSize: compact ? 15 : 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < rows.length; i++) ...[
            _InfoRow(label: rows[i].$1, value: rows[i].$2),
            if (i < rows.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _PackagingPanel extends StatelessWidget {
  const _PackagingPanel({required this.order, this.compact = false});

  final ExpeditionOrder order;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4EDF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Conferencia de embalagem',
            style: TextStyle(
              color: AppColors.text,
              fontSize: compact ? 15 : 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < order.packaging.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 17,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.packaging[i],
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: compact ? 12 : 13,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
            if (i < order.packaging.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.label,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExpeditionActions extends StatelessWidget {
  const _ExpeditionActions({
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onFinish,
    this.compact = false,
  });

  final ExpeditionStatus status;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onFinish;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (status == ExpeditionStatus.completed) {
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
                'Despacho finalizado e assinado.',
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

    if (status == ExpeditionStatus.waiting) {
      return _ActionButton(
        label: 'Iniciar conferencia',
        icon: Icons.play_arrow_rounded,
        onPressed: onStart,
        fillColor: AppColors.primary,
        foregroundColor: Colors.white,
        width: compact ? double.infinity : 250,
      );
    }

    if (status == ExpeditionStatus.paused) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _ActionButton(
            label: 'Retomar conferencia',
            icon: Icons.play_arrow_rounded,
            onPressed: onStart,
            fillColor: AppColors.primary,
            foregroundColor: Colors.white,
            width: compact ? double.infinity : 250,
          ),
          _ActionButton(
            label: 'Finalizar despacho',
            icon: Icons.check_rounded,
            onPressed: onFinish,
            foregroundColor: AppColors.green,
            borderColor: AppColors.green,
            width: compact ? double.infinity : 250,
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
          label: 'Finalizar despacho',
          icon: Icons.check_rounded,
          onPressed: onFinish,
          fillColor: AppColors.green,
          foregroundColor: Colors.white,
          width: compact ? double.infinity : 250,
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

Future<bool?> showExpeditionPinDialog(
  BuildContext context,
  ExpeditionOrder order,
) {
  final compact = MediaQuery.sizeOf(context).width < 720;

  if (compact) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExpeditionPinSheet(order: order, compact: true),
    );
  }

  return showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      backgroundColor: Colors.transparent,
      child: _ExpeditionPinSheet(order: order),
    ),
  );
}

class _ExpeditionPinSheet extends StatefulWidget {
  const _ExpeditionPinSheet({required this.order, this.compact = false});

  final ExpeditionOrder order;
  final bool compact;

  @override
  State<_ExpeditionPinSheet> createState() => _ExpeditionPinSheetState();
}

class _ExpeditionPinSheetState extends State<_ExpeditionPinSheet> {
  final _pinController = TextEditingController();
  Operator? _operator;
  bool _invalidPin = false;
  bool _wrongStage = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
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
      _wrongStage = operator != null && operator.stage != WorkStage.expedition;
    });
  }

  @override
  Widget build(BuildContext context) {
    final valid = _operator != null && !_wrongStage;

    return _ModalSurface(
      compact: widget.compact,
      maxWidth: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.compact) const _SheetHandle(),
          const Text(
            'Assinatura do operador',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Digite o PIN para finalizar o despacho da ${widget.order.number}.',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFB8DFF2)),
            ),
            child: Text(
              '${widget.order.orderCode} · ${widget.order.customer}',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 24),
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
              border: _pinBorder(AppColors.border),
              enabledBorder: _pinBorder(
                _invalidPin
                    ? const Color(0xFFD45B5B)
                    : valid
                    ? AppColors.green
                    : AppColors.border,
              ),
              focusedBorder: _pinBorder(
                _invalidPin
                    ? const Color(0xFFD45B5B)
                    : valid
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
          if (valid)
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
                  'Voce esta na etapa "Expedicao".',
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _DialogButton(
                  label: 'Cancelar',
                  onPressed: () => Navigator.of(context).pop(false),
                  fillColor: const Color(0xFFF6F9FB),
                  foregroundColor: AppColors.muted,
                  borderColor: AppColors.border,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _DialogButton(
                  label: 'Finalizar',
                  onPressed: valid
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  fillColor: valid ? AppColors.green : const Color(0xFFE4EDF4),
                  foregroundColor: valid ? Colors.white : AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _pinBorder(Color color, {double width = 1}) {
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
