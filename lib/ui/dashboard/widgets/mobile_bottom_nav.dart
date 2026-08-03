import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/repositories/pending_mutation_store.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/dashboard/cubit/dashboard_state.dart';

class MobileBottomNav extends StatelessWidget {
  const MobileBottomNav({
    super.key,
    required this.viewMode,
    required this.onViewMode,
  });

  final ViewMode viewMode;
  final ValueChanged<ViewMode> onViewMode;

  @override
  Widget build(BuildContext context) {
    final solicitacoesPendentes = context
        .watch<PendingMutationStore>()
        .aberturasPendentes
        .length;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.only(left: 6, right: 6, top: 9, bottom: 12),
      child: Row(
        children: [
          _Tab(
            icon: Icons.grid_view_rounded,
            label: 'Painel',
            active: viewMode == ViewMode.kanban,
            onTap: () => onViewMode(ViewMode.kanban),
          ),
          _Tab(
            icon: Icons.format_list_bulleted_rounded,
            label: 'OPs',
            active: viewMode == ViewMode.cards || viewMode == ViewMode.tabela,
            onTap: () => onViewMode(ViewMode.cards),
          ),
          _Tab(
            icon: Icons.inventory_2_outlined,
            label: 'Armaz.',
            active: viewMode == ViewMode.armazenadas,
            onTap: () => onViewMode(ViewMode.armazenadas),
          ),
          _Tab(
            icon: Icons.note_add_outlined,
            label: 'Solic.',
            active: viewMode == ViewMode.solicitacoes,
            badge: solicitacoesPendentes > 0 ? solicitacoesPendentes : null,
            onTap: () => onViewMode(ViewMode.solicitacoes),
          ),
          _Tab(
            icon: Icons.groups_2_outlined,
            label: 'Equipe',
            active: viewMode == ViewMode.responsaveis,
            onTap: () => onViewMode(ViewMode.responsaveis),
          ),
          _Tab(
            icon: Icons.bar_chart_rounded,
            label: 'Relat.',
            active: viewMode == ViewMode.relatorios,
            onTap: () => onViewMode(ViewMode.relatorios),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final int? badge;
  final VoidCallback? onTap;

  const _Tab({
    required this.icon,
    required this.label,
    this.active = false,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.muted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 22, color: color),
                if (badge != null)
                  Positioned(
                    right: -6,
                    top: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.orange,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$badge',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
