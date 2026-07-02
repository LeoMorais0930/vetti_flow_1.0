import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

class OperatorAssignmentsView extends StatefulWidget {
  const OperatorAssignmentsView({super.key});

  @override
  State<OperatorAssignmentsView> createState() =>
      _OperatorAssignmentsViewState();
}

class _OperatorAssignmentsViewState extends State<OperatorAssignmentsView> {
  var _selectedUsername =
      OperatorAssignmentStore.assignableOperators.first.username;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<OperatorAssignmentStore>();
    final operators = store.visibleAssignableOperators;
    if (operators.isEmpty) {
      return const _Panel(
        child: _PanelTitle(
          icon: Icons.lock_person_rounded,
          title: 'Sem equipe vinculada',
          subtitle: 'Este usuario ainda nao possui um setor para gerenciar.',
        ),
      );
    }
    final selected = operators.firstWhere(
      (operator) => operator.username == _selectedUsername,
      orElse: () => operators.first,
    );
    final selectedStage = store.stageFor(selected);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TeamSummary(store: store),
              const SizedBox(height: 14),
              _PeoplePanel(
                operators: operators,
                selectedUsername: selected.username,
                store: store,
                onSelect: (username) =>
                    setState(() => _selectedUsername = username),
              ),
              const SizedBox(height: 14),
              _AssignmentPanel(
                operator: selected,
                selectedStage: selectedStage,
                onAssign: (stage) =>
                    store.assignStage(selected.username, stage),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TeamSummary(store: store),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 390,
                  child: _PeoplePanel(
                    operators: operators,
                    selectedUsername: selected.username,
                    store: store,
                    onSelect: (username) =>
                        setState(() => _selectedUsername = username),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _AssignmentPanel(
                    operator: selected,
                    selectedStage: selectedStage,
                    onAssign: (stage) =>
                        store.assignStage(selected.username, stage),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _TeamSummary extends StatelessWidget {
  const _TeamSummary({required this.store});

  final OperatorAssignmentStore store;

  @override
  Widget build(BuildContext context) {
    final total = store.visibleAssignableOperators.length;
    final dashboard = store.visibleDashboardOperators.length;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF071D2A), Color(0xFF105071)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Equipe e designacoes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gestao de ${store.currentAreaLabel}. Cada gestor visualiza apenas as pessoas do proprio setor.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.74),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _SummaryTile(label: 'Pessoas', value: '$total'),
          const SizedBox(width: 10),
          _SummaryTile(label: 'Gestao', value: '$dashboard'),
          const SizedBox(width: 10),
          _SummaryTile(
            label: 'Setor',
            value: store.currentManagedArea == null ? 'Geral' : '1',
          ),
        ],
      ),
    );
  }
}

class _PeoplePanel extends StatelessWidget {
  const _PeoplePanel({
    required this.operators,
    required this.selectedUsername,
    required this.store,
    required this.onSelect,
  });

  final List<Operator> operators;
  final String selectedUsername;
  final OperatorAssignmentStore store;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle(
            icon: Icons.groups_2_rounded,
            title: 'Colaboradores',
            subtitle: 'Selecione uma pessoa para alterar a etapa.',
          ),
          const SizedBox(height: 16),
          for (final area in WorkArea.values) ...[
            _PeopleGroup(
              label: area.label,
              operators: operators
                  .where((operator) => operator.area == area)
                  .toList(),
              selectedUsername: selectedUsername,
              store: store,
              onSelect: onSelect,
            ),
            if (operators.any((operator) => operator.area == area))
              const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

class _PeopleGroup extends StatelessWidget {
  const _PeopleGroup({
    required this.label,
    required this.operators,
    required this.selectedUsername,
    required this.store,
    required this.onSelect,
  });

  final String label;
  final List<Operator> operators;
  final String selectedUsername;
  final OperatorAssignmentStore store;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (operators.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textCode,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        for (final operator in operators) ...[
          _PersonRow(
            operator: operator,
            stage: store.stageFor(operator),
            selected: selectedUsername == operator.username,
            onTap: () => onSelect(operator.username),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _AssignmentPanel extends StatelessWidget {
  const _AssignmentPanel({
    required this.operator,
    required this.selectedStage,
    required this.onAssign,
  });

  final Operator operator;
  final WorkStage selectedStage;
  final ValueChanged<WorkStage> onAssign;

  @override
  Widget build(BuildContext context) {
    final store = context.read<OperatorAssignmentStore>();
    final stages = store.stagesFor(operator);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(name: operator.name, large: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      operator.name,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SoftChip(
                          icon: Icons.alternate_email_rounded,
                          label: operator.username,
                        ),
                        _SoftChip(
                          icon: Icons.password_rounded,
                          label: 'Senha/PIN ${operator.password}',
                        ),
                        _SoftChip(
                          icon: Icons.verified_user_rounded,
                          label: operator.role,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FBFD),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE1EBF2)),
            ),
            child: Row(
              children: [
                _StageIcon(stage: selectedStage, large: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Etapa atual',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedStage.label,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Designar para',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final stage in stages)
                _StageButton(
                  stage: stage,
                  selected: stage == selectedStage,
                  onTap: () => onAssign(stage),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.075),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.operator,
    required this.stage,
    required this.selected,
    required this.onTap,
  });

  final Operator operator;
  final WorkStage stage;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEAF7FF) : const Color(0xFFF8FBFD),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFE1EBF2),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              _Avatar(name: operator.name),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      operator.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stage.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              _StageIcon(stage: stage),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageButton extends StatelessWidget {
  const _StageButton({
    required this.stage,
    required this.selected,
    required this.onTap,
  });

  final WorkStage stage;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _stageColor(stage);
    return SizedBox(
      height: 46,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? color : Colors.white,
          foregroundColor: selected ? Colors.white : AppColors.text,
          side: BorderSide(color: selected ? color : const Color(0xFFD8E6EE)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
        icon: Icon(_stageIcon(stage), size: 18),
        label: Text(stage.label),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 98,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textCode,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.large = false});

  final String name;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 58.0 : 36.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0077BD), Color(0xFF74D4FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(large ? 18 : 12),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials(name),
        style: TextStyle(
          color: Colors.white,
          fontSize: large ? 18 : 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'VF';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }
}

class _StageIcon extends StatelessWidget {
  const _StageIcon({required this.stage, this.large = false});

  final WorkStage stage;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final color = _stageColor(stage);
    final size = large ? 48.0 : 34.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: large ? 0.14 : 0.11),
        borderRadius: BorderRadius.circular(large ? 16 : 12),
      ),
      child: Icon(_stageIcon(stage), color: color, size: large ? 24 : 18),
    );
  }
}

Color _stageColor(WorkStage stage) {
  return switch (stage) {
    WorkStage.dashboard => const Color(0xFF0F6B8F),
    WorkStage.firmware => AppColors.primary,
    WorkStage.soldering => const Color(0xFFE16A3D),
    WorkStage.testing => const Color(0xFF209F58),
    WorkStage.closing => const Color(0xFF7458D8),
    WorkStage.expedition => const Color(0xFF334B5D),
    WorkStage.warehouse => const Color(0xFF8B6B22),
    WorkStage.support => const Color(0xFF7C3AED),
    WorkStage.tv => const Color(0xFF111827),
  };
}

IconData _stageIcon(WorkStage stage) {
  return switch (stage) {
    WorkStage.dashboard => Icons.dashboard_rounded,
    WorkStage.firmware => Icons.memory_rounded,
    WorkStage.soldering => Icons.precision_manufacturing,
    WorkStage.testing => Icons.fact_check_rounded,
    WorkStage.closing => Icons.inventory_2_rounded,
    WorkStage.expedition => Icons.local_shipping_rounded,
    WorkStage.warehouse => Icons.warehouse_rounded,
    WorkStage.support => Icons.support_agent_rounded,
    WorkStage.tv => Icons.tv_rounded,
  };
}
