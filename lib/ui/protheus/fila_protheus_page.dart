import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/repositories/mutation_sync_service.dart';
import 'package:vetti_flow_1_0/data/repositories/pending_mutation_store.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

class FilaProtheusPage extends StatelessWidget {
  const FilaProtheusPage({super.key});

  static const rota = '/fila-protheus';

  @override
  Widget build(BuildContext context) {
    final fila = context.watch<PendingMutationStore>();
    final sync = context.watch<MutationSyncService>();
    final pendentes = fila.pending;
    final armazenadas = fila.stored;
    final aplicadas = fila.sent;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('Fila do Protheus'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
        actions: [
          if (aplicadas.isNotEmpty)
            TextButton.icon(
              onPressed: fila.clearSent,
              icon: const Icon(Icons.cleaning_services_rounded, size: 18),
              label: const Text('Limpar aplicados'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ResumoFila(
              pendentes: pendentes.length,
              armazenadas: armazenadas.length,
              aplicadas: aplicadas.length,
              sincronizando: sync.isSyncing,
              finalizando: sync.isFinalizing,
              erro: sync.lastError,
              ultimoEnvio: sync.lastSyncAt,
              onSincronizar: pendentes.isEmpty || sync.isSyncing
                  ? null
                  : () => _sincronizar(context, sync),
              onFinalizar: armazenadas.isEmpty || sync.isFinalizing
                  ? null
                  : () => _finalizar(context, sync, armazenadas),
            ),
            Expanded(
              child: fila.all.isEmpty
                  ? const _FilaVazia()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        if (pendentes.isNotEmpty) ...[
                          const _SecaoFila('Aguardando envio para a API'),
                          for (final mutacao in pendentes)
                            _CartaoMutacao(
                              mutacao: mutacao,
                              onDescartar: () => fila.discard(mutacao.id),
                            ),
                        ],
                        if (armazenadas.isNotEmpty) ...[
                          const _SecaoFila('Na API, aguardando aplicar'),
                          for (final mutacao in armazenadas)
                            _CartaoMutacao(mutacao: mutacao),
                        ],
                        if (aplicadas.isNotEmpty) ...[
                          const _SecaoFila('Aplicado no Protheus'),
                          for (final mutacao in aplicadas)
                            _CartaoMutacao(mutacao: mutacao),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sincronizar(
    BuildContext context,
    MutationSyncService sync,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final aceitas = await sync.sync();
    final erro = sync.lastError;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          erro != null
              ? 'Nao deu para falar com a API: $erro. Nada foi perdido.'
              : aceitas == 0
              ? 'A API nao aceitou nenhuma linha. Veja o motivo na fila.'
              : '$aceitas linha${aceitas == 1 ? '' : 's'} enviada${aceitas == 1 ? '' : 's'} para a API.',
        ),
      ),
    );
  }

  Future<void> _finalizar(
    BuildContext context,
    MutationSyncService sync,
    List<PendingMutation> armazenadas,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Aplicar no Protheus'),
        content: Text(
          'Aplicar ${armazenadas.length} linha${armazenadas.length == 1 ? '' : 's'} '
          'no Protheus agora?\n\nIsso grava de verdade no ERP.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Voltar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('Aplicar'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;

    final ids = armazenadas
        .map((mutacao) => mutacao.id)
        .toList(growable: false);
    final aplicadas = await sync.finalizar(ids);
    final erro = sync.lastError;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          erro != null
              ? 'Nao deu para falar com a API: $erro.'
              : aplicadas == 0
              ? 'Nenhuma linha foi aplicada. Veja o motivo na fila.'
              : '$aplicadas linha${aplicadas == 1 ? '' : 's'} aplicada${aplicadas == 1 ? '' : 's'} no Protheus.',
        ),
      ),
    );
  }
}

class _ResumoFila extends StatelessWidget {
  const _ResumoFila({
    required this.pendentes,
    required this.armazenadas,
    required this.aplicadas,
    required this.sincronizando,
    required this.finalizando,
    required this.erro,
    required this.ultimoEnvio,
    required this.onSincronizar,
    required this.onFinalizar,
  });

  final int pendentes;
  final int armazenadas;
  final int aplicadas;
  final bool sincronizando;
  final bool finalizando;
  final String? erro;
  final DateTime? ultimoEnvio;
  final VoidCallback? onSincronizar;
  final VoidCallback? onFinalizar;

  @override
  Widget build(BuildContext context) {
    final totalAberto = pendentes + armazenadas;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 560;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (narrow) ...[
                _ResumoTexto(
                  totalAberto: totalAberto,
                  pendentes: pendentes,
                  armazenadas: armazenadas,
                  aplicadas: aplicadas,
                  ultimoEnvio: ultimoEnvio,
                ),
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: _actions),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: _ResumoTexto(
                        totalAberto: totalAberto,
                        pendentes: pendentes,
                        armazenadas: armazenadas,
                        aplicadas: aplicadas,
                        ultimoEnvio: ultimoEnvio,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: _actions,
                    ),
                  ],
                ),
              if (erro != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'API indisponivel: $erro\nA fila continua intacta.',
                    style: TextStyle(fontSize: 12, color: AppColors.danger),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  List<Widget> get _actions => [
    _ActionButton(
      label: sincronizando ? 'Enviando' : 'Enviar API',
      icon: Icons.cloud_upload_rounded,
      busy: sincronizando,
      onPressed: onSincronizar,
      color: AppColors.primary,
    ),
    _ActionButton(
      label: finalizando ? 'Aplicando' : 'Aplicar ERP',
      icon: Icons.check_circle_rounded,
      busy: finalizando,
      onPressed: onFinalizar,
      color: AppColors.green,
    ),
  ];
}

class _ResumoTexto extends StatelessWidget {
  const _ResumoTexto({
    required this.totalAberto,
    required this.pendentes,
    required this.armazenadas,
    required this.aplicadas,
    required this.ultimoEnvio,
  });

  final int totalAberto;
  final int pendentes;
  final int armazenadas;
  final int aplicadas;
  final DateTime? ultimoEnvio;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          totalAberto == 0
              ? 'Nada represado'
              : pendentes > 0 && armazenadas > 0
              ? '$pendentes para enviar, $armazenadas aguardando aplicar'
              : pendentes > 0
              ? '$pendentes aguardando envio'
              : '$armazenadas aguardando aplicar',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: totalAberto == 0 ? AppColors.green : AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          ultimoEnvio == null
              ? 'Nenhuma sincronizacao nesta sessao.'
              : 'Ultima acao as ${_hora(ultimoEnvio!)}. $aplicadas aplicada${aplicadas == 1 ? '' : 's'}.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    );
  }

  String _hora(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.busy,
    required this.onPressed,
    required this.color,
  });

  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: busy
          ? const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon, size: 18),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.buttonSoft,
        disabledForegroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        textStyle: GoogleFonts.ibmPlexSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SecaoFila extends StatelessWidget {
  const _SecaoFila(this.titulo);

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8, left: 2),
      child: Text(
        titulo,
        style: GoogleFonts.ibmPlexSans(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.label,
        ),
      ),
    );
  }
}

class _CartaoMutacao extends StatelessWidget {
  const _CartaoMutacao({required this.mutacao, this.onDescartar});

  final PendingMutation mutacao;
  final VoidCallback? onDescartar;

  Color get _cor => switch (mutacao.status) {
    MutationStatus.pendente => AppColors.orange,
    MutationStatus.enviando => AppColors.primary,
    MutationStatus.armazenado => const Color(0xFF6366F1),
    MutationStatus.enviado => AppColors.green,
    MutationStatus.erro => AppColors.danger,
  };

  IconData get _icone => switch (mutacao.kind) {
    MutationKind.aberturaOp => Icons.note_add_rounded,
    MutationKind.empenho => Icons.inventory_2_rounded,
    MutationKind.transferencia => Icons.swap_horiz_rounded,
    MutationKind.baixaProducao => Icons.precision_manufacturing_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_icone, size: 19, color: _cor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mutacao.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mutacao.detalhe,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(texto: mutacao.status.label, cor: _cor),
              if (onDescartar != null)
                IconButton(
                  tooltip: 'Descartar',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: AppColors.iconMuted,
                  onPressed: onDescartar,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _MetaChip(mutacao.autor),
              _MetaChip('Filial ${mutacao.filial}'),
              _MetaChip(_quando(mutacao.criadoEm)),
              if (mutacao.protheusRef != null)
                _MetaChip('Ref ${mutacao.protheusRef}'),
            ],
          ),
          if (mutacao.erro != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                mutacao.erro!,
                style: TextStyle(fontSize: 11.5, color: AppColors.danger),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _quando(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.texto, required this.cor});

  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 98),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.ibmPlexSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: cor,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: TextStyle(fontSize: 11, color: AppColors.smallText),
    );
  }
}

class _FilaVazia extends StatelessWidget {
  const _FilaVazia();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_done_rounded,
              size: 44,
              color: AppColors.iconMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'Nada pendente para o Protheus.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.muted),
            ),
            const SizedBox(height: 4),
            Text(
              'Pedidos de OP, empenhos, transferencias e baixas aparecem aqui quando forem enviados pela API.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.smallText),
            ),
          ],
        ),
      ),
    );
  }
}
