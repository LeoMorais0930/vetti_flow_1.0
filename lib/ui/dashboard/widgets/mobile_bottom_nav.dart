import 'package:flutter/material.dart';
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
  final VoidCallback? onTap;

  const _Tab({
    required this.icon,
    required this.label,
    this.active = false,
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
            Icon(icon, size: 22, color: color),
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
