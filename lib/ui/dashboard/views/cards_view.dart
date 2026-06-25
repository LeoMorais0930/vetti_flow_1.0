import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/dashboard/widgets/op_card.dart';

class CardsView extends StatelessWidget {
  final List<OrdemProducao> ordens;
  final ValueChanged<String> onOpenOP;

  const CardsView({super.key, required this.ordens, required this.onOpenOP});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: StatusOP.values.map((status) {
        final items = ordens.where((op) => op.status == status).toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(color: status.dot, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    status.shortLabel,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textStrong),
                  ),
                  const SizedBox(width: 9),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${items.length}',
                      style: GoogleFonts.ibmPlexMono(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              if (items.isEmpty)
                Text('Nenhuma OP neste status.', style: TextStyle(fontSize: 12.5, color: AppColors.textWeak))
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = (constraints.maxWidth / 278).floor().clamp(1, 4);
                    return Wrap(
                      spacing: 13,
                      runSpacing: 13,
                      children: items.map((op) => SizedBox(
                        width: (constraints.maxWidth - 13 * (crossAxisCount - 1)) / crossAxisCount,
                        child: OpCard(
                          op: op,
                          accentColor: status.dot,
                          onTap: () => onOpenOP(op.numero),
                          showResponsavelName: true,
                        ),
                      )).toList(),
                    );
                  },
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
