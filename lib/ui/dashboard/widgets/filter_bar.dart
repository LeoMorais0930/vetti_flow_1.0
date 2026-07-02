import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/dashboard/cubit/dashboard_state.dart';

class FilterBar extends StatelessWidget {
  final String busca;
  final String filtroPeriodo;
  final String filtroResponsavel;
  final String filtroProduto;
  final List<String> responsaveis;
  final List<String> produtos;
  final ViewMode viewMode;
  final bool hasActiveFilters;
  final String resultText;
  final ValueChanged<String> onBusca;
  final ValueChanged<String> onPeriodo;
  final ValueChanged<String> onResponsavel;
  final ValueChanged<String> onProduto;
  final ValueChanged<ViewMode> onViewMode;
  final VoidCallback onLimpar;

  const FilterBar({
    super.key,
    required this.busca,
    required this.filtroPeriodo,
    required this.filtroResponsavel,
    required this.filtroProduto,
    required this.responsaveis,
    required this.produtos,
    required this.viewMode,
    required this.hasActiveFilters,
    required this.resultText,
    required this.onBusca,
    required this.onPeriodo,
    required this.onResponsavel,
    required this.onProduto,
    required this.onViewMode,
    required this.onLimpar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(flex: 3, child: _SearchField(onChanged: onBusca)),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: _Dropdown(
                  value: filtroPeriodo,
                  items: const {
                    'todos': 'Todos os períodos',
                    'jun': 'Junho 2026',
                    'mai': 'Maio 2026',
                  },
                  onChanged: onPeriodo,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: _Dropdown(
                  value: filtroResponsavel,
                  items: {
                    'todos': 'Todos os responsáveis',
                    for (final r in responsaveis) r: r,
                  },
                  onChanged: onResponsavel,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: _Dropdown(
                  value: filtroProduto,
                  items: {
                    'todos': 'Todos os produtos',
                    for (final p in produtos) p: p,
                  },
                  onChanged: onProduto,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (hasActiveFilters)
                TextButton(
                  onPressed: onLimpar,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: GoogleFonts.ibmPlexSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Limpar filtros'),
                ),
              const Spacer(),
              Text(
                resultText,
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
              Container(
                width: 1,
                height: 24,
                color: AppColors.border,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
              _ViewToggle(mode: viewMode, onChanged: onViewMode),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderField),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 16, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Buscar OP ou produto...',
                hintStyle: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  color: AppColors.muted,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                color: AppColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  const _Dropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderField),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          style: GoogleFonts.ibmPlexSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
          items: items.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  final ViewMode mode;
  final ValueChanged<ViewMode> onChanged;

  const _ViewToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.bgSegment,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [ViewMode.kanban, ViewMode.tabela, ViewMode.cards].map((
          v,
        ) {
          final active = mode == v;
          final label = switch (v) {
            ViewMode.kanban => 'Kanban',
            ViewMode.tabela => 'Tabela',
            ViewMode.cards => 'Cards',
            ViewMode.armazenadas => 'Armazenadas',
            ViewMode.responsaveis => 'Equipe',
          };
          return Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Material(
              color: active ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              elevation: active ? 1 : 0,
              child: InkWell(
                borderRadius: BorderRadius.circular(7),
                onTap: () => onChanged(v),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 7,
                  ),
                  child: Text(
                    label,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active ? AppColors.text : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
