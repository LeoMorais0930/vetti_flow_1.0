import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/responsavel.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

class OpDetailPanel extends StatelessWidget {
  final OrdemProducao op;
  final bool confirmCancel;
  final VoidCallback onClose;
  final void Function({int quantidadeArmazenada}) onAdvance;
  final VoidCallback onRegress;
  final VoidCallback onAskCancel;
  final VoidCallback onConfirmCancel;
  final VoidCallback onCancelNo;
  final bool isDesktop;

  const OpDetailPanel({
    super.key,
    required this.op,
    required this.confirmCancel,
    required this.onClose,
    required this.onAdvance,
    required this.onRegress,
    required this.onAskCancel,
    required this.onConfirmCancel,
    required this.onCancelNo,
    this.isDesktop = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isDesktop) return _DesktopDrawer(panel: this);
    return _MobileFullScreen(panel: this);
  }
}

class _DesktopDrawer extends StatelessWidget {
  final OpDetailPanel panel;

  const _DesktopDrawer({required this.panel});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: panel.onClose,
      child: Container(
        color: Colors.black.withValues(alpha: 0.42),
        child: Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 500,
              height: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x330F172A),
                    blurRadius: 36,
                    offset: Offset(-10, 0),
                  ),
                ],
              ),
              child: _DetailContent(panel: panel, showBackArrow: false),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileFullScreen extends StatelessWidget {
  final OpDetailPanel panel;

  const _MobileFullScreen({required this.panel});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: _DetailContent(panel: panel, showBackArrow: true),
    );
  }
}

class _DetailContent extends StatelessWidget {
  final OpDetailPanel panel;
  final bool showBackArrow;

  const _DetailContent({required this.panel, required this.showBackArrow});

  OrdemProducao get op => panel.op;

  @override
  Widget build(BuildContext context) {
    final resp = Responsavel.byNome(op.responsavel);
    final isDone = op.status == StatusOP.finalizada;
    final canAdvance = !isDone;
    final canRegress = op.stage != ProductionStage.warehouse;

    final flow = ProductionStage.productionFlow;
    final stageIdx = flow.indexOf(op.stage);
    final advanceLabel = stageIdx == -1
        ? 'Finalizar OP'
        : stageIdx == flow.length - 1
        ? 'Concluir e expedir'
        : 'Avançar p/ ${flow[stageIdx + 1].label}';

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.borderLight)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (showBackArrow) ...[
                    _IconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: panel.onClose,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    op.numeroLegivel,
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const Spacer(),
                  if (!showBackArrow)
                    _IconButton(icon: Icons.close, onTap: panel.onClose)
                  else
                    _StatusBadge(status: op.status),
                ],
              ),
              const SizedBox(height: 11),
              Text(
                op.produto,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 11),
              if (!showBackArrow)
                Row(
                  children: [
                    _StatusBadge(status: op.status),
                    if (op.prioridadeAlta) ...[
                      const SizedBox(width: 9),
                      const _PriorityBadge(),
                    ],
                    if (op.atrasada) ...[
                      const SizedBox(width: 9),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.dangerBg,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          'Atrasada',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              if (showBackArrow && (op.prioridadeAlta || op.atrasada))
                Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (op.prioridadeAlta) const _PriorityBadge(),
                      if (op.atrasada)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.dangerBg,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            'Atrasada',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(showBackArrow ? 16 : 20),
            child: Column(
              children: [
                _InfoCard(op: op, resp: resp),
                SizedBox(height: showBackArrow ? 18 : 24),
                _StagesCard(op: op),
                SizedBox(height: showBackArrow ? 18 : 24),
                _MaterialsCard(op: op),
                SizedBox(height: showBackArrow ? 18 : 24),
                _ApontamentosCard(op: op),
              ],
            ),
          ),
        ),

        // Actions
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: showBackArrow ? 16 : 22,
            vertical: showBackArrow ? 13 : 14,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.borderLight)),
          ),
          child: panel.confirmCancel
              ? _CancelConfirm(
                  onConfirm: panel.onConfirmCancel,
                  onBack: panel.onCancelNo,
                )
              : _ActionButtons(
                  canAdvance: canAdvance,
                  isDone: isDone,
                  canRegress: canRegress,
                  actionLabel: advanceLabel,
                  op: op,
                  onAdvance: panel.onAdvance,
                  onRegress: panel.onRegress,
                  onAskCancel: panel.onAskCancel,
                  onClose: panel.onClose,
                  isDesktop: !showBackArrow,
                ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final OrdemProducao op;
  final Responsavel? resp;

  const _InfoCard({required this.op, required this.resp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _InfoField(
                  label: 'RESPONSÁVEL',
                  child: Row(
                    children: [
                      if (resp != null) ...[
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: resp!.cor,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            resp!.iniciais,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        op.responsavel,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textStrong,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _InfoField(label: 'QUANTIDADE', text: op.qtdLabel),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: _InfoField(label: 'ABERTURA', text: op.dataAbertura),
              ),
              Expanded(
                child: _InfoField(
                  label: 'PRAZO',
                  child: Text(
                    op.prazo,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: op.atrasada
                          ? AppColors.danger
                          : AppColors.textStrong,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionLabel('PROGRESSO'),
              Text(
                op.percentLabel,
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textCode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: op.progresso / 100,
              minHeight: 8,
              backgroundColor: AppColors.bgProgress,
              valueColor: AlwaysStoppedAnimation(op.status.barColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _StagesCard extends StatelessWidget {
  final OrdemProducao op;

  const _StagesCard({required this.op});

  @override
  Widget build(BuildContext context) {
    const flow = ProductionStage.productionFlow;
    final finalizada = op.status == StatusOP.finalizada;
    final currentIndex = op.stage.progressIndex;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('ETAPAS DE PRODUÇÃO'),
          const SizedBox(height: 6),
          ...List.generate(flow.length, (i) {
            final isOk = finalizada || i < currentIndex;
            final isRunning =
                !finalizada &&
                i == currentIndex &&
                op.status == StatusOP.emAndamento;

            final Color bg, color, textColor;
            final String mark, statusLabel;

            if (isOk) {
              bg = AppColors.bgFinalizada;
              color = AppColors.statusFinalizada;
              textColor = AppColors.textCode;
              mark = '✓';
              statusLabel = 'Concluída';
            } else if (isRunning) {
              bg = AppColors.bgAndamento;
              color = AppColors.statusAndamento;
              textColor = AppColors.textStrong;
              mark = '●';
              statusLabel = 'Em andamento';
            } else {
              bg = AppColors.bgButton;
              color = AppColors.muted;
              textColor = AppColors.muted;
              mark = '${i + 1}';
              statusLabel = 'Pendente';
            }

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.background)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 23,
                    height: 23,
                    decoration: BoxDecoration(
                      color: bg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      mark,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      flow[i].label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MaterialsCard extends StatelessWidget {
  final OrdemProducao op;

  const _MaterialsCard({required this.op});

  @override
  Widget build(BuildContext context) {
    final mats = op.materiais.isNotEmpty
        ? op.materiais
        : const [('Componentes diversos', 1)];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('MATERIAIS (BOM)'),
          const SizedBox(height: 6),
          ...mats.map((m) {
            final nome = m.$1;
            final qtdPer = m.$2;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.background)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    nome,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${qtdPer * op.qtd} un',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ApontamentosCard extends StatelessWidget {
  final OrdemProducao op;

  const _ApontamentosCard({required this.op});

  List<_Apontamento> _buildApontamentos() {
    final list = <_Apontamento>[];
    list.add(
      _Apontamento(
        'OP criada e adicionada à fila',
        '${op.dataAbertura} · 08:12',
        op.responsavel,
      ),
    );
    if (op.status.index >= StatusOP.naoIniciada.index) {
      list.add(
        _Apontamento(
          'Materiais separados e conferidos',
          '${op.dataAbertura} · 14:30',
          'Almoxarifado',
        ),
      );
    }
    if (op.status.index >= StatusOP.emAndamento.index) {
      list.add(
        _Apontamento(
          'Produção iniciada na linha 02',
          'em produção',
          op.responsavel,
        ),
      );
    }
    if (op.status == StatusOP.emAndamento) {
      final produced = (op.progresso / 100 * op.qtd).round();
      list.add(
        _Apontamento(
          'Apontamento parcial: $produced un produzidas',
          'hoje · 10:45',
          op.responsavel,
        ),
      );
    }
    if (op.status == StatusOP.finalizada) {
      list.add(
        _Apontamento(
          'Produção concluída — ${op.qtd} un',
          '${op.prazo} · 16:20',
          op.responsavel,
        ),
      );
      list.add(
        _Apontamento(
          'Inspeção de qualidade aprovada · liberado p/ expedição',
          '${op.prazo} · 17:05',
          'Qualidade',
        ),
      );
    }
    return list.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final apontamentos = _buildApontamentos();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('APONTAMENTOS'),
          const SizedBox(height: 10),
          ...apontamentos.asMap().entries.map((e) {
            final isFirst = e.key == 0;
            final a = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: isFirst ? AppColors.primary : AppColors.barGray,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.texto,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textStrong,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${a.tempo} · ${a.usuario}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Apontamento {
  final String texto;
  final String tempo;
  final String usuario;

  const _Apontamento(this.texto, this.tempo, this.usuario);
}

class _CancelConfirm extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onBack;

  const _CancelConfirm({required this.onConfirm, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cancelar esta OP? Ela será removida do painel de produção.',
          style: TextStyle(
            fontSize: 12.5,
            color: AppColors.textCode,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 11),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                  textStyle: GoogleFonts.ibmPlexSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Sim, cancelar OP'),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: onBack,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.bgButton,
                foregroundColor: AppColors.textCode,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                textStyle: GoogleFonts.ibmPlexSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Voltar'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final bool canAdvance;
  final bool isDone;
  final bool canRegress;
  final String actionLabel;
  final OrdemProducao op;
  final void Function({int quantidadeArmazenada}) onAdvance;
  final VoidCallback onRegress;
  final VoidCallback onAskCancel;
  final VoidCallback onClose;
  final bool isDesktop;

  const _ActionButtons({
    required this.canAdvance,
    required this.isDone,
    required this.canRegress,
    required this.actionLabel,
    required this.op,
    required this.onAdvance,
    required this.onRegress,
    required this.onAskCancel,
    required this.onClose,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    Future<void> handleAdvance() async {
      if (op.stage != ProductionStage.expedition) {
        onAdvance();
        return;
      }

      final quantidade = await showDialog<int>(
        context: context,
        builder: (context) => _StorageDecisionDialog(op: op),
      );
      if (quantidade == null) return;
      onAdvance(quantidadeArmazenada: quantidade);
    }

    return Column(
      children: [
        if (canAdvance)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: handleAdvance,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isDesktop ? 9 : 11),
                ),
                textStyle: GoogleFonts.ibmPlexSans(
                  fontSize: isDesktop ? 13.5 : 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(actionLabel),
            ),
          ),
        if (isDone)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.bgFinalizada,
              borderRadius: BorderRadius.circular(isDesktop ? 9 : 11),
            ),
            alignment: Alignment.center,
            child: Text(
              'OP finalizada ✓',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.statusFinalizada,
              ),
            ),
          ),
        const SizedBox(height: 11),
        Row(
          children: [
            if (canRegress) ...[
              Expanded(
                child: ElevatedButton(
                  onPressed: onRegress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.bgButton,
                    foregroundColor: AppColors.textCode,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isDesktop ? 9 : 11),
                    ),
                    textStyle: GoogleFonts.ibmPlexSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Voltar etapa'),
                ),
              ),
              const SizedBox(width: 9),
            ],
            if (isDesktop)
              TextButton(
                onPressed: onAskCancel,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  textStyle: GoogleFonts.ibmPlexSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Cancelar OP'),
              )
            else
              Expanded(
                child: OutlinedButton(
                  onPressed: onAskCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: Color(0xFFF3D4D4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                    textStyle: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Cancelar OP'),
                ),
              ),
            if (isDesktop) ...[
              const Spacer(),
              OutlinedButton(
                onPressed: onClose,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textCode,
                  side: const BorderSide(color: AppColors.borderField),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                  textStyle: GoogleFonts.ibmPlexSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Fechar'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _StorageDecisionDialog extends StatefulWidget {
  final OrdemProducao op;

  const _StorageDecisionDialog({required this.op});

  @override
  State<_StorageDecisionDialog> createState() => _StorageDecisionDialogState();
}

class _StorageDecisionDialogState extends State<_StorageDecisionDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? _parseQuantity() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value < 0 || value > widget.op.qtd) {
      setState(() {
        _error = 'Informe uma quantidade entre 0 e ${widget.op.qtd}.';
      });
      return null;
    }
    return value;
  }

  void _submitTypedQuantity() {
    final quantity = _parseQuantity();
    if (quantity == null) return;
    Navigator.of(context).pop(quantity);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 440,
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Concluir OP',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.op.numeroLegivel} · ${widget.op.qtdLabel}',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.bgHeader,
                border: Border.all(color: AppColors.borderLight),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Text(
                'Separe a quantidade que deve ir apenas para armazenamento. Use 0 para concluir sem armazenar.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const _SectionLabel('QUANTIDADE PARA ARMAZENAMENTO', small: true),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '0 a ${widget.op.qtd}',
                errorText: _error,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: AppColors.borderField),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: AppColors.borderField),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
              style: GoogleFonts.ibmPlexMono(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textCode,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(0),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textCode,
                      side: const BorderSide(color: AppColors.borderField),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Sem armazenar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(widget.op.qtd),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Armazenar tudo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitTypedQuantity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Concluir com quantidade informada'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgButton,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 18, color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final StatusOP status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: status.bgColor,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: status.dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: status.textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Text(
        'Prioridade alta',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.danger,
        ),
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  final String label;
  final String? text;
  final Widget? child;

  const _InfoField({required this.label, this.text, this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label, small: true),
        const SizedBox(height: 6),
        child ??
            Text(
              text!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textStrong,
              ),
            ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool small;

  const _SectionLabel(this.text, {this.small = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: small ? 10.5 : 11.5,
        fontWeight: FontWeight.w700,
        color: small ? AppColors.muted : AppColors.text,
        letterSpacing: 0.5,
      ),
    );
  }
}
