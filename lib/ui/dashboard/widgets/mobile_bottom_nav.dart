import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

class MobileBottomNav extends StatelessWidget {
  const MobileBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.only(left: 6, right: 6, top: 9, bottom: 12),
      child: Row(
        children: const [
          _Tab(icon: Icons.grid_view_rounded, label: 'Painel', active: true),
          _Tab(icon: Icons.format_list_bulleted_rounded, label: 'OPs'),
          _Tab(icon: Icons.inventory_2_outlined, label: 'Produtos'),
          _Tab(icon: Icons.bar_chart_rounded, label: 'Relatórios'),
          _Tab(icon: Icons.person_outline_rounded, label: 'Perfil'),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _Tab({required this.icon, required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.muted;
    return Expanded(
      child: InkWell(
        onTap: () {},
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
