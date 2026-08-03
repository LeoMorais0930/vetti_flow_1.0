import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/models/protheus_empenho.dart';
import 'package:vetti_flow_1_0/data/repositories/empenho_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/pending_mutation_store.dart';
import 'package:vetti_flow_1_0/data/repositories/product_catalog_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_repository.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/empenho_editor.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/produto_busca.dart';

/// Altera os empenhos de uma OP que já existe no Protheus.
///
/// Edita sobre o **estado efetivo** — o retrato da SD4 mais o que já está na
/// fila —, e ao gravar recalcula o diff inteiro contra o retrato. Assim a fila
/// guarda a intenção final, não um histórico de rascunhos.
///
/// O Protheus permite empenhar mais do que há em estoque, e a produção precisa
/// disso quando o material está a caminho: a falta aparece em vermelho, mas
/// não impede gravar.
class EmpenhosOpDialog extends StatefulWidget {
  const EmpenhosOpDialog({
    super.key,
    required this.op,
    required this.filial,
    required this.autor,
    this.opLegivel,
    this.produtoLabel,
  });

  /// A OP concatenada (número + item + sequência).
  final String op;

  final String filial;

  /// Quem responde pela alteração.
  final String autor;

  /// `015942-01-001`, para o cabeçalho.
  final String? opLegivel;

  final String? produtoLabel;

  /// Abre o diálogo e devolve quantas mutações foram gravadas.
  static Future<int?> mostrar(
    BuildContext context, {
    required String op,
    required String filial,
    required String autor,
    String? opLegivel,
    String? produtoLabel,
  }) {
    return showDialog<int>(
      context: context,
      builder: (_) => EmpenhosOpDialog(
        op: op,
        filial: filial,
        autor: autor,
        opLegivel: opLegivel,
        produtoLabel: produtoLabel,
      ),
    );
  }

  @override
  State<EmpenhosOpDialog> createState() => _EmpenhosOpDialogState();
}

class _EmpenhosOpDialogState extends State<EmpenhosOpDialog> {
  /// O retrato do Protheus, contra o qual o diff é calculado.
  late final List<ProtheusEmpenho> _base = context
      .read<EmpenhoRepository>()
      .byOp(widget.op, filial: widget.filial);

  late List<EmpenhoLinha> _linhas;
  final _motivo = TextEditingController();

  @override
  void initState() {
    super.initState();
    final catalogo = context.read<ProductCatalogRepository>();
    final efetivo = context.read<PendingMutationStore>().empenhosEfetivos(
      widget.op,
      _base,
    );
    _linhas = [
      for (final e in efetivo)
        EmpenhoLinha(
          produto: e.produto,
          descricao: catalogo.findByCode(e.produto)?.name ?? e.produto,
          quantidade: e.quantidade,
          local: e.local,
        ),
    ];
  }

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  /// As mutações que levam o retrato do Protheus até o que está na tela.
  ///
  /// Uma linha que mudou de almoxarifado casa pelo código do componente: na
  /// SD4 isso é sair de uma linha e entrar em outra, mas para quem opera é a
  /// mesma linha mudando de lugar, e é assim que a fila deve contar a história.
  List<EmpenhoMutation Function(String, DateTime)> _diff() {
    final motivo = _motivo.text.trim().isEmpty ? null : _motivo.text.trim();
    final mutacoes = <EmpenhoMutation Function(String, DateTime)>[];

    EmpenhoMutation Function(String, DateTime) construir({
      required EmpenhoOperacao operacao,
      required String produto,
      required String descricao,
      required String local,
      double quantidade = 0,
      double? quantidadeAnterior,
      String? localAnterior,
    }) => (id, agora) => EmpenhoMutation(
      id: id,
      filial: widget.filial,
      criadoEm: agora,
      autor: widget.autor,
      op: widget.op,
      operacao: operacao,
      produto: produto,
      produtoDescricao: descricao,
      local: local,
      quantidade: quantidade,
      quantidadeAnterior: quantidadeAnterior,
      localAnterior: localAnterior,
      motivo: motivo,
    );

    final porProdutoBase = {for (final e in _base) e.produto: e};
    final produtosNaTela = {for (final l in _linhas) l.produto};

    for (final linha in _linhas) {
      final original = porProdutoBase[linha.produto];
      if (original == null) {
        mutacoes.add(
          construir(
            operacao: EmpenhoOperacao.incluir,
            produto: linha.produto,
            descricao: linha.descricao,
            local: linha.local,
            quantidade: linha.quantidade,
          ),
        );
        continue;
      }
      final mudouQuantidade = original.quantidade != linha.quantidade;
      final mudouLocal = original.local != linha.local;
      if (mudouQuantidade || mudouLocal) {
        mutacoes.add(
          construir(
            operacao: EmpenhoOperacao.alterar,
            produto: linha.produto,
            descricao: linha.descricao,
            local: linha.local,
            quantidade: linha.quantidade,
            quantidadeAnterior: original.quantidade,
            localAnterior: original.local,
          ),
        );
      }
    }

    for (final original in _base) {
      if (produtosNaTela.contains(original.produto)) continue;
      mutacoes.add(
        construir(
          operacao: EmpenhoOperacao.excluir,
          produto: original.produto,
          descricao:
              context.read<ProductCatalogRepository>()
                  .findByCode(original.produto)
                  ?.name ??
              original.produto,
          local: original.local,
          quantidadeAnterior: original.quantidade,
        ),
      );
    }

    return mutacoes;
  }

  void _gravar() {
    final fila = context.read<PendingMutationStore>();
    // O conjunto anterior é substituído inteiro: ver `discardPendingEmpenhos`.
    fila.discardPendingEmpenhos(widget.op);
    final mutacoes = _diff();
    for (final construir in mutacoes) {
      fila.enqueue(construir);
    }
    Navigator.of(context).pop(mutacoes.length);
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = context.read<ProductCatalogRepository>();
    final armazens = context.read<WarehouseRepository>().armazens;
    final fila = context.watch<PendingMutationStore>();
    final alteracoes = _diff().length;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.borderLight),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Empenhos da OP ${widget.opLegivel ?? widget.op}',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.produtoLabel ??
                              'O que esta OP consome e de onde sai.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppColors.iconMuted,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_base.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          'Esta OP não tem empenho carregado do Protheus. '
                          'O que for acrescentado aqui vai como inclusão.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.orangeText,
                          ),
                        ),
                      ),
                    EmpenhoEditor(
                      linhas: _linhas,
                      armazens: armazens,
                      catalogo: catalogo,
                      // A OP já existe: `_base` (o retrato real da SD4) é o
                      // que ela já tem reservado, e o Protheus já conta isso
                      // dentro do B2_QEMP. Passar op/baseOp soma essa reserva
                      // de volta — senão o disponível descontaria a própria
                      // OP duas vezes.
                      saldoDisponivel: (produto, local) {
                        final item = catalogo.findByCode(produto);
                        if (item == null) return null;
                        return fila.disponivelPara(
                          produto: produto,
                          filial: widget.filial,
                          local: local,
                          baseCatalogo: item.saldos,
                          op: widget.op,
                          baseOp: _base,
                        );
                      },
                      onAlterar: (i, nova) =>
                          setState(() => _linhas[i] = nova),
                      onRemover: (i) => setState(() => _linhas.removeAt(i)),
                      onIncluir: (nova) => setState(() => _linhas.add(nova)),
                    ),
                    const SizedBox(height: 16),
                    FormFieldLabel(
                      label: 'Motivo',
                      child: TextField(
                        controller: _motivo,
                        maxLines: 2,
                        decoration: campoDecoracao(
                          hint: 'Por que o empenho mudou',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      alteracoes == 0
                          ? 'Nada mudou em relação ao Protheus.'
                          : '$alteracoes alteração${alteracoes == 1 ? '' : 'es'} '
                                'vão para a fila.',
                      style: TextStyle(
                        fontSize: 12,
                        color: alteracoes == 0
                            ? AppColors.muted
                            : AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.muted,
                    ),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: alteracoes == 0 ? null : _gravar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withValues(
                        alpha: 0.4,
                      ),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      textStyle: GoogleFonts.ibmPlexSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Gravar na fila'),
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
