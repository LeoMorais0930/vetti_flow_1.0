import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/repositories/pending_mutation_store.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/protheus/fila_protheus_page.dart';

/// Pedidos de abertura de OP que ainda não viraram uma OP de verdade no
/// Protheus.
///
/// Existe porque solicitar uma OP só enfileira um `AberturaOpMutation` em
/// `PendingMutationStore` — nada entra em `ProductionFlowStore`, que é o que
/// o resto do Dashboard mostra. Sem esta aba, a Gestora solicitava uma OP e,
/// do ponto de vista do painel, nada tinha acontecido; a única prova era a
/// tela "Fila do Protheus", que ela não tinha motivo para abrir sozinha.
class SolicitacoesView extends StatelessWidget {
  const SolicitacoesView({super.key});

  @override
  Widget build(BuildContext context) {
    final fila = context.watch<PendingMutationStore>();
    final pedidos = fila.aberturasPendentes;

    if (pedidos.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Nenhuma solicitação de OP pendente.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 320).floor().clamp(
          1,
          3,
        );
        return Wrap(
          spacing: 13,
          runSpacing: 13,
          children: pedidos.map((pedido) {
            return SizedBox(
              width:
                  (constraints.maxWidth - 13 * (crossAxisCount - 1)) /
                  crossAxisCount,
              child: _SolicitacaoCard(
                pedido: pedido,
                onCancelar: pedido.status == MutationStatus.pendente
                    ? () => fila.discard(pedido.id)
                    : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _SolicitacaoCard extends StatelessWidget {
  const _SolicitacaoCard({required this.pedido, this.onCancelar});

  final AberturaOpMutation pedido;
  final VoidCallback? onCancelar;

  Color get _cor => switch (pedido.status) {
    MutationStatus.pendente => AppColors.orange,
    MutationStatus.enviando => AppColors.primary,
    MutationStatus.armazenado => const Color(0xFF6366F1),
    MutationStatus.enviado => AppColors.green,
    MutationStatus.erro => AppColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  pedido.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textStrong,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _cor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  pedido.status.label,
                  style: TextStyle(
                    color: _cor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            pedido.detalhe,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
          // O número que o Protheus deu ao pedido, quando já deu. É o que a
          // Gestora leva para procurar a OP no ERP — antes disso ele não
          // existe, e o card não tem o que mostrar.
          if (pedido.protheusRef != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.tag_rounded,
                  size: 15,
                  color: AppColors.iconMuted,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'OP ${pedido.protheusRef}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textCode,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (pedido.erro != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                pedido.erro!,
                style: TextStyle(fontSize: 11.5, color: AppColors.danger),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.note_add_rounded,
                size: 16,
                color: AppColors.iconMuted,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${pedido.autor} · ${_quando(pedido.criadoEm)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              if (onCancelar != null)
                TextButton(
                  onPressed: onCancelar,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: GoogleFonts.ibmPlexSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Cancelar'),
                ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(FilaProtheusPage.rota),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: GoogleFonts.ibmPlexSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Ver na fila'),
              ),
            ],
          ),
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
