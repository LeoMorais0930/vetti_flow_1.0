import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

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
    if (compact) {
      return Container(
        height: 104,
        padding: const EdgeInsets.fromLTRB(18, 16, 20, 14),
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _HeaderLogo(compact: true),
                const Spacer(),
                _OperatorBlock(name: operatorName, compact: true),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 72,
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 34),
      child: Row(
        children: [
          const _HeaderLogo(),
          Container(
            width: 1,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 31),
            color: Colors.white.withValues(alpha: 0.45),
          ),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          _OperatorBlock(name: operatorName, role: operatorRole),
        ],
      ),
    );
  }
}

class _HeaderLogo extends StatelessWidget {
  const _HeaderLogo({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'VETTI',
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 18 : 24,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        Text(
          'FLOW',
          style: TextStyle(
            color: const Color(0xFFDFF3FF),
            fontSize: compact ? 13 : 17,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _OperatorBlock extends StatelessWidget {
  const _OperatorBlock({required this.name, this.role, this.compact = false});

  final String name;
  final String? role;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final displayName = role == null || compact ? name : '$name ($role)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          compact ? 'Operador' : 'Operador logado',
          style: TextStyle(
            color: const Color(0xFFDFF3FF),
            fontSize: compact ? 10 : 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          displayName,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 12 : 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
