import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

class KpiCards extends StatelessWidget {
  final Map<StatusOP, int> counts;
  final int atrasadas;
  final StatusOP? activeFilter;
  final ValueChanged<StatusOP> onToggle;
  final bool compact;

  const KpiCards({
    super.key,
    required this.counts,
    required this.atrasadas,
    required this.activeFilter,
    required this.onToggle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final items = StatusOP.values.map((s) {
      final sub = switch (s) {
        StatusOP.aAbrir => 'aguardando abertura',
        StatusOP.naoIniciada => 'prontas para iniciar',
        StatusOP.emAndamento =>
          atrasadas > 0
              ? '$atrasadas atrasada${atrasadas > 1 ? 's' : ''}'
              : 'todas no prazo',
        StatusOP.finalizada => 'no período',
      };
      final subColor = (s == StatusOP.emAndamento && atrasadas > 0)
          ? AppColors.danger
          : AppColors.muted;
      return _KpiData(
        status: s,
        count: counts[s] ?? 0,
        sub: sub,
        subColor: subColor,
      );
    }).toList();

    if (compact) {
      return SizedBox(
        height: 100,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: items.length,
          separatorBuilder: (_, index) => const SizedBox(width: 10),
          itemBuilder: (_, i) => SizedBox(
            width: 138,
            child: _KpiCard(
              data: items[i],
              active: activeFilter == items[i].status,
              onTap: () => onToggle(items[i].status),
              compact: true,
            ),
          ),
        ),
      );
    }

    return Row(
      children: items
          .map(
            (d) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: d.status != StatusOP.finalizada ? 14 : 0,
                ),
                child: _KpiCard(
                  data: d,
                  active: activeFilter == d.status,
                  onTap: () => onToggle(d.status),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _KpiData {
  final StatusOP status;
  final int count;
  final String sub;
  final Color subColor;

  const _KpiData({
    required this.status,
    required this.count,
    required this.sub,
    required this.subColor,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;
  final bool active;
  final VoidCallback onTap;
  final bool compact;

  const _KpiCard({
    required this.data,
    required this.active,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? data.status.bgColor : AppColors.surface,
      borderRadius: BorderRadius.circular(compact ? 13 : 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(compact ? 13 : 12),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(compact ? 13 : 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 13 : 12),
            border: Border.all(
              color: active ? data.status.dot : AppColors.border,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: compact ? 8 : 9,
                    height: compact ? 8 : 9,
                    decoration: BoxDecoration(
                      color: data.status.dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    data.status.shortLabel,
                    style: TextStyle(
                      fontSize: compact ? 11.5 : 12.5,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 9 : 11),
              Text(
                '${data.count}',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: compact ? 26 : 30,
                  fontWeight: FontWeight.w600,
                  color: data.status.textColor,
                  height: 1,
                ),
              ),
              SizedBox(height: compact ? 4 : 5),
              Text(
                data.sub,
                style: TextStyle(
                  fontSize: compact ? 10.5 : 12,
                  color: data.subColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
