import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/protheus/protheus_queue_button.dart';

class VettiTopBar extends StatelessWidget {
  const VettiTopBar({
    super.key,
    required this.title,
    required this.operatorName,
    this.operatorRole,
    this.compact = false,
  });

  final String title;
  final String operatorName;
  final String? operatorRole;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    void logout() => Navigator.of(context).pushReplacementNamed('/login');

    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveCompact = compact || constraints.maxWidth < 720;
        if (effectiveCompact) {
          return _CompactTopBar(
            title: title,
            operatorName: operatorName,
            operatorRole: operatorRole,
            onLogout: logout,
          );
        }

        return _DesktopTopBar(
          title: title,
          operatorName: operatorName,
          operatorRole: operatorRole,
          onLogout: logout,
        );
      },
    );
  }
}

class _CompactTopBar extends StatelessWidget {
  const _CompactTopBar({
    required this.title,
    required this.operatorName,
    required this.operatorRole,
    required this.onLogout,
  });

  final String title;
  final String operatorName;
  final String? operatorRole;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B202E), Color(0xFF123A52)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: const Border(bottom: BorderSide(color: Color(0xFF1F5875))),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          const _HeaderLogo(compact: true, dark: true),
          Container(
            width: 1,
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: Colors.white24,
          ),
          Expanded(child: _StageTitle(title: title, compact: true, dark: true)),
          const SizedBox(width: 10),
          Flexible(
            child: _OperatorBlock(
              name: operatorName,
              role: operatorRole,
              compact: true,
              dark: true,
            ),
          ),
          const SizedBox(width: 8),
          const ProtheusQueueButton(compact: true, dark: true),
          const SizedBox(width: 4),
          _LogoutButton(compact: true, dark: true, onPressed: onLogout),
        ],
      ),
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({
    required this.title,
    required this.operatorName,
    required this.operatorRole,
    required this.onLogout,
  });

  final String title;
  final String operatorName;
  final String? operatorRole;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF071D2A), Color(0xFF0D344B), Color(0xFF105071)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: const Border(bottom: BorderSide(color: Color(0xFF1E6C91))),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.28),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          const _HeaderLogo(dark: true),
          Container(
            width: 1,
            height: 38,
            margin: const EdgeInsets.symmetric(horizontal: 26),
            color: Colors.white24,
          ),
          Expanded(child: _StageTitle(title: title, dark: true)),
          const Spacer(),
          _OperatorBlock(name: operatorName, role: operatorRole, dark: true),
          const SizedBox(width: 16),
          const ProtheusQueueButton(dark: true),
          const SizedBox(width: 8),
          _LogoutButton(dark: true, onPressed: onLogout),
        ],
      ),
    );
  }
}

class _HeaderLogo extends StatelessWidget {
  const _HeaderLogo({this.compact = false, this.dark = false});

  final bool compact;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: compact ? 86 : 112),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: compact ? 8 : 10,
            height: compact ? 36 : 42,
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF74D4FF) : AppColors.primary,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          SizedBox(width: compact ? 8 : 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vetti',
                style: TextStyle(
                  color: dark ? Colors.white : AppColors.title,
                  fontSize: compact ? 18 : 23,
                  fontWeight: FontWeight.w900,
                  height: 0.95,
                ),
              ),
              Text(
                'Flow',
                style: TextStyle(
                  color: dark ? const Color(0xFF9EE5FF) : AppColors.primary,
                  fontSize: compact ? 15 : 19,
                  fontWeight: FontWeight.w800,
                  height: 0.95,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StageTitle extends StatelessWidget {
  const _StageTitle({
    required this.title,
    this.compact = false,
    this.dark = false,
  });

  final String title;
  final bool compact;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 34 : 40,
          height: compact ? 34 : 40,
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withValues(alpha: 0.11)
                : AppColors.bgAndamento,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: dark ? Colors.white24 : const Color(0xFFD3EAF6),
            ),
          ),
          child: Icon(
            _iconForTitle(title),
            color: dark ? const Color(0xFF9EE5FF) : AppColors.primary,
            size: compact ? 18 : 21,
          ),
        ),
        SizedBox(width: compact ? 10 : 12),
        Flexible(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                compact ? 'Etapa atual' : 'Posto de trabalho',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.68)
                      : AppColors.muted,
                  fontSize: compact ? 10 : 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: dark ? Colors.white : AppColors.text,
                  fontSize: compact ? 17 : 22,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _iconForTitle(String title) {
    final normalized = title.toLowerCase();
    if (normalized.contains('firmware')) return Icons.memory_rounded;
    if (normalized.contains('soldagem')) return Icons.precision_manufacturing;
    if (normalized.contains('teste')) return Icons.fact_check_rounded;
    if (normalized.contains('exped')) return Icons.local_shipping_rounded;
    if (normalized.contains('fechamento')) return Icons.inventory_2_rounded;
    if (normalized.contains('almox')) return Icons.warehouse_rounded;
    if (normalized.contains('suporte')) return Icons.support_agent_rounded;
    return Icons.view_kanban_rounded;
  }
}

class _OperatorBlock extends StatelessWidget {
  const _OperatorBlock({
    required this.name,
    this.role,
    this.compact = false,
    this.dark = false,
  });

  final String name;
  final String? role;
  final bool compact;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final displayName = role == null || compact ? name : '$name ($role)';

    return Container(
      constraints: BoxConstraints(maxWidth: compact ? 178 : 260),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 7 : 8,
      ),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.1) : AppColors.bgButton,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dark ? Colors.white24 : AppColors.borderLight,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 26 : 30,
            height: compact ? 26 : 30,
            decoration: const BoxDecoration(
              color: Color(0xFF74D4FF),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _initials(name),
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(width: compact ? 8 : 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  compact ? 'Operador' : 'Operador logado',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.68)
                        : AppColors.muted,
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: dark ? Colors.white : AppColors.text,
                    fontSize: compact ? 12 : 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'VF';
    if (words.length == 1) return words.first.characters.first.toUpperCase();
    return '${words.first.characters.first}${words.last.characters.first}'
        .toUpperCase();
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({
    required this.onPressed,
    this.compact = false,
    this.dark = false,
  });

  final VoidCallback onPressed;
  final bool compact;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Sair',
      onPressed: onPressed,
      icon: Icon(
        Icons.logout_rounded,
        color: dark ? Colors.white : AppColors.textCode,
        size: compact ? 20 : 22,
      ),
      style: IconButton.styleFrom(
        backgroundColor: dark
            ? Colors.white.withValues(alpha: 0.12)
            : AppColors.bgButton,
        side: BorderSide(color: dark ? Colors.white24 : AppColors.borderLight),
        minimumSize: Size.square(compact ? 34 : 40),
        fixedSize: Size.square(compact ? 34 : 40),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
