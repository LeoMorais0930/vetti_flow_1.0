import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/warehouse.dart';
import 'package:vetti_flow_1_0/data/repositories/product_catalog_repository.dart';
import 'package:vetti_flow_1_0/shared/config/protheus_config.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/empenho_editor.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/produto_busca.dart';

/// O que o formulário juntou: um pedido de abertura de OP pronto para virar
/// [AberturaOpMutation].
class SolicitacaoOp {
  const SolicitacaoOp({
    required this.produto,
    required this.produtoDescricao,
    required this.quantidade,
    required this.localProducao,
    required this.empenhos,
    this.previsao,
    this.observacao,
  });

  final String produto;
  final String produtoDescricao;
  final int quantidade;
  final String localProducao;
  final List<EmpenhoLinha> empenhos;
  final String? previsao;
  final String? observacao;
}

/// Pede a abertura de uma OP nova para um produto.
///
/// Entrou em 31/07/2026, quando ficou decidido que o VettiFlow deixa de ser só
/// leitor da OP. O número **não** nasce aqui: quem numera é o Protheus. Isto
/// gera um pedido, que fica na fila até a API levá-lo.
///
/// Quantidade e prazo são digitados — ao contrário do seletor de OP existente,
/// onde vêm do ERP e são só exibidos.
class SolicitacaoOpForm extends StatefulWidget {
  const SolicitacaoOpForm({
    super.key,
    required this.catalogo,
    required this.armazens,
    required this.onMudar,
    this.saldoDisponivel,
    this.localPadrao = almoxarifadoPadrao,
  });

  final ProductCatalogRepository catalogo;
  final List<Armazem> armazens;

  /// Chamado a cada mudança: o pedido, ou `null` enquanto faltar algo.
  final ValueChanged<SolicitacaoOp?> onMudar;

  final double Function(String produto, String local)? saldoDisponivel;

  /// Almoxarifado sugerido para a produção — `01` (ALMOXARIFADO) na Vetti.
  final String localPadrao;

  @override
  State<SolicitacaoOpForm> createState() => _SolicitacaoOpFormState();
}

class _SolicitacaoOpFormState extends State<SolicitacaoOpForm> {
  ProductionCatalogItem? _produto;
  final _quantidade = TextEditingController();
  final _prazo = TextEditingController();
  final _observacao = TextEditingController();
  late String _local = widget.localPadrao;

  /// Os empenhos do pedido, começando pela estrutura do produto e mexidos à
  /// vontade daqui em diante.
  List<EmpenhoLinha> _empenhos = [];

  /// Verdadeiro depois que o operador mexeu nos empenhos.
  ///
  /// A partir daí mudar a quantidade não recalcula mais as linhas: refazer a
  /// explosão apagaria o ajuste que ele acabou de fazer.
  bool _empenhosAjustados = false;

  @override
  void dispose() {
    _quantidade.dispose();
    _prazo.dispose();
    _observacao.dispose();
    super.dispose();
  }

  int get _qtd => int.tryParse(_quantidade.text.trim()) ?? 0;

  /// Explode a estrutura do produto pela quantidade pedida.
  ///
  /// É o que o Protheus faz ao abrir a OP. Fazer aqui deixa o operador ver e
  /// ajustar antes, em vez de pedir a OP às cegas e corrigir depois.
  void _recalcularEmpenhos() {
    final produto = _produto;
    if (produto == null || _empenhosAjustados) return;
    final qtd = _qtd;
    _empenhos = [
      for (final c in produto.components)
        EmpenhoLinha(
          produto: c.code,
          descricao: c.description,
          quantidade: c.quantity * qtd,
          local: _local,
        ),
    ];
  }

  void _notificar() {
    final produto = _produto;
    final qtd = _qtd;
    final prazo = _prazo.text.trim();
    if (produto == null || qtd <= 0 || _local.isEmpty) {
      widget.onMudar(null);
      return;
    }
    widget.onMudar(
      SolicitacaoOp(
        produto: produto.code,
        produtoDescricao: produto.name,
        quantidade: qtd,
        localProducao: _local,
        previsao: prazo.isEmpty ? null : prazo,
        observacao: _observacao.text.trim().isEmpty
            ? null
            : _observacao.text.trim(),
        empenhos: List.unmodifiable(_empenhos),
      ),
    );
  }

  void _aoMudarProduto(ProductionCatalogItem? produto) {
    setState(() {
      _produto = produto;
      // Produto novo, estrutura nova: o ajuste anterior era de outro item.
      _empenhosAjustados = false;
      _recalcularEmpenhos();
    });
    _notificar();
  }

  void _aoMudarQuantidade(String _) {
    setState(_recalcularEmpenhos);
    _notificar();
  }

  void _mexerNosEmpenhos(void Function() mudanca) {
    setState(() {
      _empenhosAjustados = true;
      mudanca();
    });
    _notificar();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProdutoBusca(catalogo: widget.catalogo, onProduto: _aoMudarProduto),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: FormFieldLabel(
                label: 'Quantidade',
                child: TextField(
                  controller: _quantidade,
                  keyboardType: TextInputType.number,
                  decoration: campoDecoracao(hint: '0'),
                  onChanged: _aoMudarQuantidade,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: FormFieldLabel(
                label: 'Prazo',
                child: TextField(
                  controller: _prazo,
                  keyboardType: TextInputType.datetime,
                  decoration: campoDecoracao(hint: 'dd/mm/aaaa'),
                  onChanged: (_) => _notificar(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        FormFieldLabel(
          label: 'Almoxarifado de produção',
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _local.isNotEmpty ? _local : null,
            decoration: campoDecoracao(),
            items: [
              for (final a in widget.armazens)
                DropdownMenuItem(
                  value: a.codigo,
                  child: Text(a.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _local = v;
                _recalcularEmpenhos();
              });
              _notificar();
            },
          ),
        ),
        if (_produto != null) ...[
          const SizedBox(height: 15),
          EmpenhoEditor(
            linhas: _empenhos,
            armazens: widget.armazens,
            catalogo: widget.catalogo,
            saldoDisponivel: widget.saldoDisponivel,
            onAlterar: (i, nova) =>
                _mexerNosEmpenhos(() => _empenhos[i] = nova),
            onRemover: (i) => _mexerNosEmpenhos(() => _empenhos.removeAt(i)),
            onIncluir: (nova) => _mexerNosEmpenhos(() => _empenhos.add(nova)),
          ),
          if (_empenhosAjustados)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Empenhos ajustados — mudar a quantidade não recalcula mais.',
                style: TextStyle(fontSize: 11.5, color: AppColors.orangeText),
              ),
            ),
        ],
        const SizedBox(height: 15),
        FormFieldLabel(
          label: 'Observação',
          child: TextField(
            controller: _observacao,
            maxLines: 2,
            decoration: campoDecoracao(hint: 'Por que esta OP é necessária'),
            onChanged: (_) => _notificar(),
          ),
        ),
      ],
    );
  }
}
