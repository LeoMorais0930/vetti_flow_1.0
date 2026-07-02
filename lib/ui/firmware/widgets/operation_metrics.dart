import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/firmware/widgets/firmware_models.dart';

/// Faixa unica com os dados essenciais da OP. Substitui os quatro cards
/// soltos por um bloco coeso, sem repetir o que ja aparece na lista.
class OperationMetrics extends StatelessWidget {
  const OperationMetrics({
    super.key,
    required this.operation,
    this.compact = false,
  });

  final FirmwareOperation operation;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String)>[
      ('Quantidade', operation.quantity),
      ('Origem', operation.origin),
      ('Recebida', operation.receivedAt),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 20,
        vertical: compact ? 14 : 17,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1EBF2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(
              child: _MetricItem(
                label: items[i].$1,
                value: items[i].$2,
                compact: compact,
              ),
            ),
            if (i < items.length - 1)
              Container(
                width: 1,
                height: compact ? 34 : 40,
                color: const Color(0xFFDDE9F1),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.label,
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: compact ? 5 : 7),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: AppColors.text,
              fontSize: compact ? 16 : 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

/// Chip de status dinamico exibido no cabecalho da OP em detalhe.
class OperationStatusChip extends StatelessWidget {
  const OperationStatusChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  final FirmwareStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: status.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: compact ? 13 : 15, color: status.color),
          SizedBox(width: compact ? 6 : 7),
          Text(
            status.label,
            style: TextStyle(
              color: status.color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
