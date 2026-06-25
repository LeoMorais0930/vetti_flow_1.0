import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Center(
                child: Image.asset(
                  'assets/images/vetti-flow-logo.png',
                  width: 128,
                  color: Colors.white,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'PAINEL DE PRODUÇÃO',
              style: TextStyle(
                fontSize: 10.5,
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 24),
            _NavItem(icon: _panelIcon, label: 'Painel', active: true),
            _NavItem(icon: _listIcon, label: 'Ordens de Produção'),
            _NavItem(icon: _boxIcon, label: 'Produtos'),
            _NavItem(icon: _userIcon, label: 'Responsáveis'),
            _NavItem(icon: _chartIcon, label: 'Relatórios'),
            const Spacer(),
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.borderLight)),
              ),
              padding: const EdgeInsets.only(top: 11),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Color(0xFF7C3AED),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text('AR', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ana Ribeiro', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                        Text('Gestora de Produção', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final Widget icon;
  final String label;
  final bool active;

  const _NavItem({required this.icon, required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: active ? const Color(0xFFE6F3FC) : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () {},
          hoverColor: AppColors.bgHover,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            child: Row(
              children: [
                IconTheme(
                  data: IconThemeData(
                    color: active ? AppColors.primary : AppColors.textMuted,
                    size: 17,
                  ),
                  child: icon,
                ),
                const SizedBox(width: 11),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? AppColors.primary : AppColors.textMuted,
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

final _panelIcon = Icon(Icons.grid_view_rounded, size: 17);
final _listIcon = Icon(Icons.format_list_bulleted_rounded, size: 17);
final _boxIcon = Icon(Icons.inventory_2_outlined, size: 17);
final _userIcon = Icon(Icons.person_outline_rounded, size: 17);
final _chartIcon = Icon(Icons.bar_chart_rounded, size: 17);
