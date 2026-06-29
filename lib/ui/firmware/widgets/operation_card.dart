import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/firmware/widgets/firmware_models.dart';

class OperationCard extends StatelessWidget {
  const OperationCard({
    super.key,
    required this.operation,
    required this.selected,
    required this.status,
    required this.onTap,
    this.compact = false,
  });

  final FirmwareOperation operation;
  final bool selected;
  final FirmwareStatus status;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isActive = status != FirmwareStatus.waiting;
    final radius = BorderRadius.circular(14);

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: selected
            ? const Color(0xFFEAF7FF)
            : isActive
            ? status.surface
            : Colors.white,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 20,
              compact ? 14 : 16,
              compact ? 14 : 16,
              compact ? 14 : 16,
            ),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : isActive
                    ? status.color.withValues(alpha: 0.35)
                    : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                if (isActive) ...[
                  Container(
                    width: 4,
                    height: compact ? 44 : 48,
                    decoration: BoxDecoration(
                      color: status.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: compact ? 12 : 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
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
                                fontSize: compact ? 14 : 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (isActive)
                            _StatusDot(status: status, compact: compact),
                        ],
                      ),
                      SizedBox(height: compact ? 4 : 5),
                      Text(
                        operation.product,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: compact ? 12 : 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: compact ? 7 : 8),
                      Text(
                        '${operation.quantity} · ${operation.origin} · ${operation.receivedAgo}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.smallText,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.chevron_right_rounded,
                  size: 18,
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

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status, required this.compact});

  final FirmwareStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: status.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: compact ? 10 : 11, color: status.color),
          SizedBox(width: compact ? 4 : 5),
          Text(
            status.label,
            style: TextStyle(
              color: status.color,
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
