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
            TextButton(
              onPressed: fila.clearSent,
              child: const Text('Limpar aplicados'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _Resumo(
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
                ? const _Vazio()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      if (pendentes.isNotEmpty) ...[
                        const _Secao('Aguardando envio à API'),
                        for (final m in pendentes)
                          _Cartao(
                            mutacao: m,
                            onDescartar: () => fila.discard(m.id),
                          ),
                      ],
                      if (armazenadas.isNotEmpty) ...[
                        const _Secao(
                          'Na API — aguardando finalização da OP',
                        ),
                        for (final m in armazenadas) _Cartao(mutacao: m),
                      ],
                      if (aplicadas.isNotEmpty) ...[
                        const _Secao('Aplicado no Protheus'),
                        for (final m in aplicadas) _Cartao(mutacao: m),
                      ],
                    ],
                  ),
          ),
        ],
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
              ? 'Não deu para falar com a API: $erro. Nada foi perdido.'
              : aceitas == 0
              ? 'A API não aceitou nenhuma. Veja o motivo em cada linha.'
              : '$aceitas armazenada${aceitas == 1 ? '' : 's'} na API.',
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
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar OP'),
        content: Text(
          'Aplicar ${armazenadas.length} mutação${armazenadas.length == 1 ? '' : 'ões'} '
          'no Protheus?\n\nIsso grava de verdade nas tabelas do ERP.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (confirmou != true) return;

    final ids = armazenadas.map((m) => m.id).toList(growable: false);
    final aplicadas = await sync.finalizar(ids);
    final erro = sync.lastError;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          erro != null
              ? 'Não deu para falar com a API: $erro.'
              : aplicadas == 0
              ? 'Nenhuma foi aplicada. Veja o motivo em cada linha.'
              : '$aplicadas aplicada${aplicadas == 1 ? '' : 's'} no Protheus.',
        ),
      ),
    );
  }
}

class _Resumo extends StatelessWidget {
  const _Resumo({
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
    final total = pendentes + armazenadas;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      total == 0
                          ? 'Nada represado'
                          : pendentes > 0 && armazenadas > 0
                          ? '$pendentes para enviar · $armazenadas na API'
                          : pendentes > 0
                          ? '$pendentes aguardando envio'
                          : '$armazenadas na API, aguardando finalização',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: total == 0
                            ? AppColors.green
                            : AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ultimoEnvio == null
                          ? 'Nenhuma sincronização nesta sessão.'
                          : 'Última ação às '
                                '${_hora(ultimoEnvio!)} · '
                                '$aplicadas aplicada${aplicadas == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: onSincronizar,
                    icon: sincronizando
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.cloud_upload_rounded, size: 18),
                    label: Text(
                      sincronizando ? 'Enviando…' : 'Enviar à API',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.buttonSoft,
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      textStyle: GoogleFonts.ibmPlexSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: onFinalizar,
                    icon: finalizando
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      finalizando ? 'Finalizando…' : 'Finalizar OP',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.green.withValues(alpha: 0.4),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      textStyle: GoogleFonts.ibmPlexSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
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
                'API indisponível: $erro\n'
                'A fila continua intacta — nada foi perdido.',
                style: TextStyle(fontSize: 12, color: AppColors.danger),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

class _Secao extends StatelessWidget {
  const _Secao(this.titulo);

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8, left: 2),
      child: Text(
        titulo,
        style: GoogleFonts.ibmPlexSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.label,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _Cartao extends StatelessWidget {
  const _Cartao({required this.mutacao, this.onDescartar});

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
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mutacao.titulo,
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mutacao.detalhe,
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Selo(texto: mutacao.status.label, cor: _cor),
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
          const SizedBox(height: 8),
          Text(
            '${mutacao.autor} · filial ${mutacao.filial} · '
            '${_quando(mutacao.criadoEm)}'
            '${mutacao.protheusRef != null ? " · ref ${mutacao.protheusRef}" : ""}',
            style: TextStyle(fontSize: 11, color: AppColors.smallText),
          ),
          if (mutacao.erro != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(6),
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

  String _quando(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}

class _Selo extends StatelessWidget {
  const _Selo({required this.texto, required this.cor});

  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: GoogleFonts.ibmPlexSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: cor,
        ),
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio();

  @override
  Widget build(BuildContext context) {
    return Center(
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
            style: TextStyle(fontSize: 14, color: AppColors.muted),
          ),
          const SizedBox(height: 4),
          Text(
            'Pedidos de OP, alterações de empenho e transferências\n'
            'aparecem aqui antes de ir para o ERP.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.smallText),
          ),
        ],
      ),
    );
  }
}
