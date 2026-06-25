import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/shared/layout/app_breakpoints.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/vetti_top_bar.dart';

class WarehouseItem {
  const WarehouseItem({
    required this.code,
    required this.description,
    required this.quantity,
    required this.stock,
  });

  final String code;
  final String description;
  final String quantity;
  final String stock;
}

class WarehouseRequest {
  const WarehouseRequest({
    required this.number,
    required this.operation,
    required this.product,
    required this.requestedBy,
    required this.priority,
    required this.createdAt,
    required this.status,
    required this.items,
  });

  final String number;
  final String operation;
  final String product;
  final String requestedBy;
  final String priority;
  final String createdAt;
  final String status;
  final List<WarehouseItem> items;
}

class WarehousePage extends StatefulWidget {
  const WarehousePage({super.key});

  @override
  State<WarehousePage> createState() => _WarehousePageState();
}

class _WarehousePageState extends State<WarehousePage> {
  final _requests = const [
    WarehouseRequest(
      number: 'REQ-00091',
      operation: 'OP-00564-345',
      product: 'CR4 - Controle 4 teclas',
      requestedBy: 'Lucas - Suporte',
      priority: 'Alta',
      createdAt: '11:14',
      status: 'Aguardando separacao',
      items: [
        WarehouseItem(
          code: 'CN-004V',
          description: 'Conector barra 4 vias',
          quantity: '12 un',
          stock: '86 un',
        ),
        WarehouseItem(
          code: 'RS-10K',
          description: 'Resistor 10K 0603',
          quantity: '40 un',
          stock: '420 un',
        ),
      ],
    ),
    WarehouseRequest(
      number: 'REQ-00092',
      operation: 'OP-00565-112',
      product: 'Central Vetti Smart',
      requestedBy: 'Marina - Suporte',
      priority: 'Media',
      createdAt: '11:26',
      status: 'Em separacao',
      items: [
        WarehouseItem(
          code: 'MCU-ESP32',
          description: 'Microcontrolador ESP32-WROOM',
          quantity: '3 un',
          stock: '18 un',
        ),
      ],
    ),
    WarehouseRequest(
      number: 'REQ-00093',
      operation: 'OP-00566-078',
      product: 'Modulo RF Vetti One',
      requestedBy: 'Lucas - Suporte',
      priority: 'Baixa',
      createdAt: '11:41',
      status: 'Aguardando separacao',
      items: [
        WarehouseItem(
          code: 'RF-433',
          description: 'Modulo RF 433 MHz',
          quantity: '5 un',
          stock: '31 un',
        ),
        WarehouseItem(
          code: 'CAP-100N',
          description: 'Capacitor 100nF 0603',
          quantity: '20 un',
          stock: '980 un',
        ),
      ],
    ),
  ];

  var _selectedIndex = 0;
  var _status = 'Aguardando separacao';

  WarehouseRequest get _selectedRequest => _requests[_selectedIndex];

  void _startPicking() {
    setState(() => _status = 'Em separacao');
  }

  void _pausePicking() {
    setState(() => _status = 'Pausada');
  }

  Future<void> _deliverItems() async {
    final confirmed = await showWarehouseDeliveryDialog(
      context,
      request: _selectedRequest,
    );
    if (!mounted || confirmed != true) return;
    setState(() => _status = 'Entregue ao suporte');
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
          return _MobileWarehouseLayout(
            requests: _requests,
            selectedIndex: _selectedIndex,
            status: _status,
            onSelect: (index) => setState(() {
              _selectedIndex = index;
              _status = _requests[index].status;
            }),
            onStart: _startPicking,
            onPause: _pausePicking,
            onDeliver: _deliverItems,
          );
        }

        return _DesktopWarehouseLayout(
          requests: _requests,
          selectedIndex: _selectedIndex,
          status: _status,
          onSelect: (index) => setState(() {
            _selectedIndex = index;
            _status = _requests[index].status;
          }),
          onStart: _startPicking,
          onPause: _pausePicking,
          onDeliver: _deliverItems,
        );
      },
    );
  }
}

class _DesktopWarehouseLayout extends StatelessWidget {
  const _DesktopWarehouseLayout({
    required this.requests,
    required this.selectedIndex,
    required this.status,
    required this.onSelect,
    required this.onStart,
    required this.onPause,
    required this.onDeliver,
  });

  final List<WarehouseRequest> requests;
  final int selectedIndex;
  final String status;
  final ValueChanged<int> onSelect;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onDeliver;

  WarehouseRequest get selectedRequest => requests[selectedIndex];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Column(
        children: [
          const VettiTopBar(
            title: 'Almoxarifado',
            operatorName: 'Renata',
            operatorRole: 'Almoxarifado',
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
                        child: _WarehouseQueue(
                          requests: requests,
                          selectedIndex: selectedIndex,
                          onSelect: onSelect,
                        ),
                      ),
                      const SizedBox(width: 72),
                      Expanded(
                        child: _WarehouseDetails(
                          request: selectedRequest,
                          status: status,
                          onStart: onStart,
                          onPause: onPause,
                          onDeliver: onDeliver,
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

class _MobileWarehouseLayout extends StatelessWidget {
  const _MobileWarehouseLayout({
    required this.requests,
    required this.selectedIndex,
    required this.status,
    required this.onSelect,
    required this.onStart,
    required this.onPause,
    required this.onDeliver,
  });

  final List<WarehouseRequest> requests;
  final int selectedIndex;
  final String status;
  final ValueChanged<int> onSelect;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onDeliver;

  WarehouseRequest get selectedRequest => requests[selectedIndex];

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
                  title: 'Almoxarifado',
                  operatorName: 'Renata',
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
                          child: _WarehouseHeader(compact: true),
                        ),
                        const SizedBox(height: 18),
                        for (var i = 0; i < requests.length; i++) ...[
                          _WarehouseRequestCard(
                            request: requests[i],
                            selected: i == selectedIndex,
                            compact: true,
                            onTap: () => onSelect(i),
                          ),
                          if (i < requests.length - 1)
                            const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 24),
                        _MobileWarehouseSummary(
                          request: selectedRequest,
                          status: status,
                        ),
                        const SizedBox(height: 16),
                        _WarehouseItemsPanel(request: selectedRequest),
                        const SizedBox(height: 18),
                        _WarehouseActions(
                          compact: true,
                          onStart: onStart,
                          onPause: onPause,
                          onDeliver: onDeliver,
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

class _WarehouseQueue extends StatelessWidget {
  const _WarehouseQueue({
    required this.requests,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<WarehouseRequest> requests;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _WarehouseHeader(),
        const SizedBox(height: 38),
        for (var i = 0; i < requests.length; i++) ...[
          _WarehouseRequestCard(
            request: requests[i],
            selected: i == selectedIndex,
            onTap: () => onSelect(i),
          ),
          if (i < requests.length - 1) const SizedBox(height: 23),
        ],
      ],
    );
  }
}

class _WarehouseHeader extends StatelessWidget {
  const _WarehouseHeader({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Requisicoes do suporte',
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
              ? 'Pedidos para separar.'
              : 'Pedidos de componentes para conserto das OPs no suporte tecnico.',
          style: TextStyle(color: AppColors.muted, fontSize: compact ? 13 : 16),
        ),
      ],
    );
  }
}

class _WarehouseDetails extends StatelessWidget {
  const _WarehouseDetails({
    required this.request,
    required this.status,
    required this.onStart,
    required this.onPause,
    required this.onDeliver,
  });

  final WarehouseRequest request;
  final String status;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onDeliver;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.number,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${request.operation} · ${request.product}',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 38),
          _WarehouseMetrics(request: request, status: status),
          const SizedBox(height: 32),
          _WarehouseItemsPanel(request: request),
          const SizedBox(height: 54),
          const Text(
            'Acoes da requisicao',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'O almoxarifado separa, pausa ou entrega os itens solicitados ao suporte.',
            style: TextStyle(color: AppColors.muted, fontSize: 16),
          ),
          const SizedBox(height: 36),
          _WarehouseActions(
            onStart: onStart,
            onPause: onPause,
            onDeliver: onDeliver,
          ),
        ],
      ),
    );
  }
}

class _WarehouseRequestCard extends StatelessWidget {
  const _WarehouseRequestCard({
    required this.request,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final WarehouseRequest request;
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request.number,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: compact ? 17 : 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _PriorityBadge(priority: request.priority),
                ],
              ),
              SizedBox(height: compact ? 8 : 10),
              Text(
                request.operation,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: compact ? 13 : 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: compact ? 10 : 12),
              Text(
                '${request.items.length} item(s) · ${request.createdAt}',
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

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final color = priority == 'Alta'
        ? AppColors.orangeText
        : priority == 'Media'
        ? AppColors.primary
        : AppColors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        priority,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _WarehouseMetrics extends StatelessWidget {
  const _WarehouseMetrics({required this.request, required this.status});

  final WarehouseRequest request;
  final String status;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Prioridade', request.priority),
      ('Solicitante', request.requestedBy),
      ('Horario', request.createdAt),
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
            wide: metric.$1 == 'Solicitante' || metric.$1 == 'Status atual',
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
      width: wide ? 220 : 155,
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

class _WarehouseItemsPanel extends StatelessWidget {
  const _WarehouseItemsPanel({required this.request});

  final WarehouseRequest request;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Itens solicitados',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < request.items.length; i++) ...[
            _WarehouseItemRow(item: request.items[i]),
            if (i < request.items.length - 1)
              const Divider(height: 24, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _WarehouseItemRow extends StatelessWidget {
  const _WarehouseItemRow({required this.item});

  final WarehouseItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 78,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF7FF),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            item.code,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.description,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Solicitado: ${item.quantity} · Estoque: ${item.stock}',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WarehouseActions extends StatelessWidget {
  const _WarehouseActions({
    required this.onStart,
    required this.onPause,
    required this.onDeliver,
    this.compact = false,
  });

  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onDeliver;
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
            label: 'Iniciar separacao',
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
                  label: 'Entregar',
                  icon: Icons.inventory_2_rounded,
                  onPressed: onDeliver,
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
          label: 'Iniciar separacao',
          icon: Icons.play_arrow_rounded,
          onPressed: onStart,
          fillColor: AppColors.primary,
          foregroundColor: Colors.white,
          width: 270,
        ),
        _ActionButton(
          label: 'Pausar separacao',
          icon: Icons.pause_rounded,
          onPressed: onPause,
          foregroundColor: AppColors.orangeText,
          borderColor: AppColors.orange,
          width: 270,
        ),
        _ActionButton(
          label: 'Entregar ao suporte',
          icon: Icons.inventory_2_rounded,
          onPressed: onDeliver,
          foregroundColor: AppColors.green,
          borderColor: AppColors.green,
          width: 300,
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

class _MobileWarehouseSummary extends StatelessWidget {
  const _MobileWarehouseSummary({required this.request, required this.status});

  final WarehouseRequest request;
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
            child: _SummaryValue(label: 'OP', value: request.operation),
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

Future<bool?> showWarehouseDeliveryDialog(
  BuildContext context, {
  required WarehouseRequest request,
}) {
  final observationController = TextEditingController();

  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Entregar ao suporte'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${request.number} · ${request.operation}',
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
              decoration: InputDecoration(labelText: 'PIN', hintText: '1234'),
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
          child: const Text('Confirmar entrega'),
        ),
      ],
    ),
  ).whenComplete(observationController.dispose);
}
