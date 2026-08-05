import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/product_catalog_repository.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/produto_busca.dart';

/// Escolhe uma OP **que já existe** no Protheus, a partir do código do produto.
///
/// Duas coisas saíram daqui em 31/07/2026, a pedido de quem opera:
///
/// - o campo "Produto encontrado", que só repetia o que o cartão do produto já
///   mostra logo acima;
/// - o dropdown "Ordem de produção em aberto", cujo rótulo era quantidade e
///   prazo. Ele deixava 12 das 298 OPs em aberto com texto idêntico (medido nos
///   dados de 29/07/2026), e escondia o número, que é justamente o que as
///   separa. No lugar entrou uma lista que mostra o número legível.
///
/// Para **pedir** uma OP nova, e não escolher uma existente, veja
/// `SolicitacaoOpForm`.
class ProtheusOpPicker extends StatefulWidget {
  const ProtheusOpPicker({
    super.key,
    required this.catalogo,
    required this.ordensDisponiveis,
    required this.onSelecionar,
    this.retratoDesatualizado = false,
  });

  final ProductCatalogRepository catalogo;

  /// OPs em aberto que ainda não entraram no fluxo.
  final List<OrdemDisponivel> ordensDisponiveis;

  /// Chamado a cada mudança: a OP escolhida, ou `null` se ainda não há uma.
  final ValueChanged<OrdemDisponivel?> onSelecionar;

  /// A busca ao vivo no Protheus falhou — esta lista pode não refletir OPs
  /// adotadas em outra máquina agora mesmo.
  final bool retratoDesatualizado;

  @override
  State<ProtheusOpPicker> createState() => _ProtheusOpPickerState();
}

class _ProtheusOpPickerState extends State<ProtheusOpPicker> {
  ProductionCatalogItem? _produto;
  String _numero = '';

  /// Quantas OPs em aberto cada produto tem, para a lista de sugestões mostrar
  /// de cara o que dá para trazer e o que é beco sem saída.
  Map<String, int> get _opsPorProduto {
    final contagem = <String, int>{};
    for (final op in widget.ordensDisponiveis) {
      contagem[op.produtoCodigo] = (contagem[op.produtoCodigo] ?? 0) + 1;
    }
    return contagem;
  }

  List<OrdemDisponivel> get _opsDoProduto {
    final produto = _produto;
    if (produto == null) return const [];
    return widget.ordensDisponiveis
        .where((op) => op.produtoCodigo == produto.code)
        .toList();
  }

  OrdemDisponivel? get _selecionada {
    for (final op in _opsDoProduto) {
      if (op.numero == _numero) return op;
    }
    return null;
  }

  void _aoMudarProduto(ProductionCatalogItem? produto) {
    setState(() {
      _produto = produto;
      // Ao trocar de produto, a OP escolhida antes deixa de valer. Produto com
      // uma única OP já entra escolhido: não há o que decidir.
      final ops = _opsDoProduto;
      _numero = ops.length == 1 ? ops.first.numero : '';
    });
    widget.onSelecionar(_selecionada);
  }

  @override
  Widget build(BuildContext context) {
    final ops = _opsDoProduto;
    final escolhida = _selecionada;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.retratoDesatualizado)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Não deu para confirmar com o Protheus agora — mostrando o '
              'último retrato conhecido. Outra máquina pode já ter adotado '
              'alguma destas OPs.',
              style: TextStyle(fontSize: 12, color: AppColors.orangeText),
            ),
          ),
        ProdutoBusca(
          catalogo: widget.catalogo,
          opsPorProduto: _opsPorProduto,
          onProduto: _aoMudarProduto,
        ),
        if (_produto != null) ...[
          const SizedBox(height: 15),
          FormFieldLabel(
            label: ops.length == 1
                ? 'Ordem de produção'
                : 'Qual OP entra no fluxo',
            child: ops.isEmpty
                ? const _SemOps()
                : _ListaOps(
                    ordens: ops,
                    selecionada: _numero,
                    onEscolher: (numero) {
                      setState(() => _numero = numero);
                      widget.onSelecionar(_selecionada);
                    },
                  ),
          ),
        ],
        const SizedBox(height: 15),
        // O número da OP escolhida, em campo próprio: na lista acima ele
        // divide espaço com quantidade e prazo de várias OPs, e depois de
        // escolher é este o dado que a pessoa leva para o Protheus.
        FormFieldLabel(
          label: 'Número da OP',
          child: ReadOnlyValue(
            value: escolhida?.numeroLegivel ?? '—',
            mono: true,
          ),
        ),
        const SizedBox(height: 15),
        // Quantidade e prazo são da OP no Protheus: exibidos, não editáveis.
        // Para digitá-los é preciso pedir uma OP nova — ali eles são entrada.
        Row(
          children: [
            Expanded(
              child: FormFieldLabel(
                label: 'Quantidade',
                child: ReadOnlyValue(
                  value: escolhida == null ? '—' : '${escolhida.quantidade}',
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: FormFieldLabel(
                label: 'Prazo',
                child: ReadOnlyValue(
                  value: escolhida?.previsao ?? 'dd/mm/aaaa',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SemOps extends StatelessWidget {
  const _SemOps();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgHeader,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Text(
        'Este produto não tem OP em aberto no Protheus. '
        'Peça a abertura de uma OP nova.',
        style: TextStyle(fontSize: 12.5, color: AppColors.muted),
      ),
    );
  }
}

/// As OPs em aberto do produto, uma por linha.
///
/// Mostra o número legível (`015942-01-001`) junto de quantidade e prazo: sem
/// o número, OPs do mesmo produto com a mesma quantidade e o mesmo prazo ficam
/// indistinguíveis — situação real na base, não hipótese.
class _ListaOps extends StatelessWidget {
  const _ListaOps({
    required this.ordens,
    required this.selecionada,
    required this.onEscolher,
  });

  final List<OrdemDisponivel> ordens;
  final String selecionada;
  final ValueChanged<String> onEscolher;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < ordens.length; i++)
            _LinhaOp(
              ordem: ordens[i],
              ativa: ordens[i].numero == selecionada,
              ultima: i == ordens.length - 1,
              onTap: () => onEscolher(ordens[i].numero),
            ),
        ],
      ),
    );
  }
}

class _LinhaOp extends StatelessWidget {
  const _LinhaOp({
    required this.ordem,
    required this.ativa,
    required this.ultima,
    required this.onTap,
  });

  final OrdemDisponivel ordem;
  final bool ativa;
  final bool ultima;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ativa ? AppColors.bgAndamento : null,
          border: ultima
              ? null
              : const Border(bottom: BorderSide(color: AppColors.borderLight)),
        ),
        child: Row(
          children: [
            Icon(
              ativa
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 17,
              color: ativa ? AppColors.primary : AppColors.iconMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ordem.numeroLegivel,
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: ativa ? AppColors.primaryDark : AppColors.text,
                    ),
                  ),
                  Text(
                    '${ordem.quantidade} un · '
                    'prazo ${ordem.previsao ?? "não informado"}',
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted),
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
