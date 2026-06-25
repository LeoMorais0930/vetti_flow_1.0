import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/data/models/responsavel.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

class OpCard extends StatelessWidget {
  final OrdemProducao op;
  final Color accentColor;
  final VoidCallback onTap;
  final bool showResponsavelName;

  const OpCard({
    super.key,
    required this.op,
    required this.accentColor,
    required this.onTap,
    this.showResponsavelName = false,
  });

  @override
  Widget build(BuildContext context) {
    final resp = Responsavel.byNome(op.responsavel);

    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Material(
        color: AppColors.surface,
        child: InkWell(
          onTap: onTap,
          hoverColor: Colors.white,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.borderLight),
                right: BorderSide(color: AppColors.borderLight),
                bottom: BorderSide(color: AppColors.borderLight),
                left: BorderSide(color: accentColor, width: 3),
              ),
            ),
            padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      op.numero,
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textCode,
                        letterSpacing: 0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (op.atrasada)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.dangerBg,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Text(
                        'Atrasada',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.danger),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                op.produto,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textStrong),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (showResponsavelName && resp != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Avatar(resp: resp),
                        const SizedBox(width: 7),
                        Text(op.responsavel, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ],
                    )
                  else
                    Text(op.qtdLabel, style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  if (!showResponsavelName && resp != null)
                    _Avatar(resp: resp),
                  if (showResponsavelName)
                    Text(op.qtdLabel, style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                ],
              ),
              if (op.showBar) ...[
                const SizedBox(height: 8),
                _ProgressBar(progress: op.progresso / 100, color: op.status.barColor, label: op.percentLabel),
              ],
              const SizedBox(height: 8),
              Text(op.prazoLabel, style: TextStyle(fontSize: 11.5, color: AppColors.textWeak)),
            ],
          ),
        ),
      ),
    ));
  }
}

class _Avatar extends StatelessWidget {
  final Responsavel resp;

  const _Avatar({required this.resp});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(color: resp.cor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        resp.iniciais,
        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  final Color color;
  final String label;

  const _ProgressBar({required this.progress, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.bgProgress,
              borderRadius: BorderRadius.circular(99),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0, 1),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.ibmPlexMono(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
