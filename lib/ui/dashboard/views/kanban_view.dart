import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/dashboard/widgets/op_card.dart';

class KanbanView extends StatelessWidget {
  final List<OrdemProducao> ordens;
  final ValueChanged<String> onOpenOP;

  const KanbanView({super.key, required this.ordens, required this.onOpenOP});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: StatusOP.values.map((status) {
        final items = ordens.where((op) => op.status == status).toList();
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: status != StatusOP.finalizada ? 14 : 0,
            ),
            child: _KanbanColumn(
              status: status,
              items: items,
              onOpenOP: onOpenOP,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  final StatusOP status;
  final List<OrdemProducao> items;
  final ValueChanged<String> onOpenOP;

  const _KanbanColumn({
    required this.status,
    required this.items,
    required this.onOpenOP,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 600),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: status.dot,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status.shortLabel,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgHeader,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${items.length}',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Nenhuma OP',
                style: TextStyle(fontSize: 12, color: AppColors.textWeak),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(10),
                itemCount: items.length,
                separatorBuilder: (_, index) => const SizedBox(height: 10),
                itemBuilder: (_, i) => OpCard(
                  op: items[i],
                  accentColor: status.dot,
                  onTap: () => onOpenOP(items[i].numero),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
