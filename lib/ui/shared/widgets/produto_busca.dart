import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/filial_store.dart';
import 'package:vetti_flow_1_0/data/repositories/product_catalog_repository.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

/// Busca de produto pelo **código do Protheus**, com sugestões e o cartão do
/// item encontrado.
///
/// É o código que a produção conhece de cor — o número da OP (11 dígitos) não.
/// Extraída para ser compartilhada pelas duas coisas que partem de um produto:
/// trazer uma OP existente para o fluxo e pedir a abertura de uma nova.
class ProdutoBusca extends StatefulWidget {
  const ProdutoBusca({
    super.key,
    required this.catalogo,
    required this.onProduto,
    this.opsPorProduto = const {},
    this.mostrarCartao = true,
    this.somenteLiberados = false,
  });

  final ProductCatalogRepository catalogo;

  /// Chamado a cada mudança: o produto encontrado, ou `null`.
  final ValueChanged<ProductionCatalogItem?> onProduto;

  /// Quantas OPs em aberto cada produto tem.
  ///
  /// Vazio esconde a contagem — faz sentido quando a tela vai **pedir** uma OP
  /// nova, situação em que quantas já existem não muda a decisão.
  final Map<String, int> opsPorProduto;

  final bool mostrarCartao;

  /// Esconde produto com bloqueio de tela na SB1 (B1_MSBLQL = '1').
  ///
  /// Ligado onde se **pede OP nova**: o Protheus recusa movimentar item
  /// bloqueado, então oferecê-lo só produziria um pedido que morre na API.
  /// Desligado onde se traz uma OP que já existe — 4 produtos com OP em aberto
  /// estão bloqueados hoje, e escondê-los travaria trabalho em andamento.
  final bool somenteLiberados;

  @override
  State<ProdutoBusca> createState() => _ProdutoBuscaState();
}

class _ProdutoBuscaState extends State<ProdutoBusca> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// O produto do código digitado.
  ///
  /// Com [ProdutoBusca.somenteLiberados], produto bloqueado no Protheus é
  /// tratado como inexistente: nem o código exato o traz de volta. Foi a
  /// decisão do gestor em 04/08/2026 — quem pede a OP não deve nem ver o item,
  /// e um cartão dizendo "existe, mas está bloqueado" já é ver.
  ProductionCatalogItem? get _produto {
    final codigo = _controller.text.trim();
    if (codigo.isEmpty) return null;
    final item = widget.catalogo.findByCode(codigo);
    if (item == null) return null;
    return widget.somenteLiberados && item.blocked ? null : item;
  }

  /// Produtos que casam com o que já foi digitado.
  ///
  /// Some assim que o código bate exato com um produto — aí o lugar da
  /// informação é o cartão, não a lista.
  List<ProductionCatalogItem> get _sugestoes {
    final termo = _controller.text.trim().toUpperCase();
    if (termo.isEmpty || _produto != null) return const [];

    final porCodigo = <ProductionCatalogItem>[];
    final porDescricao = <ProductionCatalogItem>[];
    for (final item in widget.catalogo.items) {
      if (widget.somenteLiberados && item.blocked) continue;
      if (item.code.toUpperCase().startsWith(termo)) {
        porCodigo.add(item);
      } else if (item.name.toUpperCase().contains(termo)) {
        porDescricao.add(item);
      }
    }

    // Produto com OP em aberto primeiro: é o que pode virar produção agora.
    int ordenar(ProductionCatalogItem a, ProductionCatalogItem b) {
      final ca = widget.opsPorProduto[a.code] ?? 0;
      final cb = widget.opsPorProduto[b.code] ?? 0;
      if (ca != cb) return cb.compareTo(ca);
      return a.code.compareTo(b.code);
    }

    porCodigo.sort(ordenar);
    porDescricao.sort(ordenar);
    return [...porCodigo, ...porDescricao];
  }

  void _aoMudar(String _) {
    setState(() {});
    final produto = _produto;
    widget.onProduto(produto);
    if (produto != null) _atualizarSaldo(produto.code);
  }

  void _escolher(ProductionCatalogItem item) {
    _controller.text = item.code;
    _aoMudar(item.code);
  }

  /// Busca o saldo deste produto na filial corrente assim que ele é
  /// reconhecido — sem isso, o disponível mostrado vem só do retrato
  /// embarcado, que pode já ter mudado desde a última extração. Silencioso
  /// se o catálogo não for o híbrido (ex.: em teste) ou se a busca falhar —
  /// quem mostra o aviso de retrato desatualizado é a tela que lê o saldo.
  void _atualizarSaldo(String codigo) {
    final catalogo = widget.catalogo;
    if (catalogo is! HybridProductCatalogRepository) return;
    final filial = context.read<FilialStore>().filial;
    catalogo.refreshSaldo(codigo, filial);
  }

  @override
  Widget build(BuildContext context) {
    final sugestoes = _sugestoes;
    final digitou = _controller.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormFieldLabel(
          label: 'Código Protheus',
          child: TextFormField(
            controller: _controller,
            decoration: campoDecoracao(hint: '000-0000'),
            textCapitalization: TextCapitalization.characters,
            onChanged: _aoMudar,
          ),
        ),
        if (sugestoes.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ListaSugestoes(
            itens: sugestoes,
            opsPorProduto: widget.opsPorProduto,
            onEscolher: _escolher,
          ),
        ] else if (digitou && widget.mostrarCartao) ...[
          const SizedBox(height: 12),
          _ProdutoCard(
            produto: _produto,
            opsEmAberto: widget.opsPorProduto[_produto?.code] ?? 0,
            mostrarOps: widget.opsPorProduto.isNotEmpty,
          ),
        ],
      ],
    );
  }
}

/// Decoração dos campos do formulário, compartilhada pelos widgets do seletor.
InputDecoration campoDecoracao({String? hint, String? sufixo}) =>
    InputDecoration(
      hintText: hint,
      suffixText: sufixo,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.borderField),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.borderField),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );

class FormFieldLabel extends StatelessWidget {
  const FormFieldLabel({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textCode,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// Valor vindo do Protheus: mostrado, nunca editável.
///
/// Compartilhado pelas duas metades do diálogo de OP — a que traz uma OP que
/// já existe e a que pede uma nova —, para quantidade, prazo e número da OP
/// terem a mesma cara nos dois lados.
class ReadOnlyValue extends StatelessWidget {
  const ReadOnlyValue({super.key, required this.value, this.mono = false});

  final String value;

  /// Fonte monoespaçada, para código e número de OP.
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(fontSize: 14, color: AppColors.muted);
    return Container(
      height: 44,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.bgHeader,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Text(
        value,
        style: mono ? GoogleFonts.ibmPlexMono(textStyle: estilo) : estilo,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Cartão do produto encontrado: identificação, estrutura e OPs em aberto.
class _ProdutoCard extends StatelessWidget {
  const _ProdutoCard({
    required this.produto,
    required this.opsEmAberto,
    required this.mostrarOps,
  });

  final ProductionCatalogItem? produto;
  final int opsEmAberto;
  final bool mostrarOps;

  @override
  Widget build(BuildContext context) {
    final item = produto;
    if (item == null) {
      return _Caixa(
        child: Text(
          'Nenhum produto com esse código.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
      );
    }

    // A estrutura inteira, sem corte: o operador confere componente por
    // componente antes de pedir a OP, e "e mais 3 componentes" escondia
    // justamente o que ele precisava olhar. O maior produto da Vetti tem 78
    // linhas — o cartão vive dentro de rolagem, então cresce à vontade.
    final componentes = item.components;

    return _Caixa(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${item.code} - ${item.name}',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            [
              item.type,
              item.unit,
              if (item.group.isNotEmpty) 'grupo ${item.group}',
            ].where((p) => p.isNotEmpty).join(' · '),
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          if (componentes.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final c in componentes)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '${c.code} · ${c.description} · ${c.quantityWithUnit}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
          ],
          const SizedBox(height: 8),
          Text(
            [
              '${componentes.length} componente${componentes.length == 1 ? '' : 's'}',
              if (mostrarOps)
                opsEmAberto == 0
                    ? 'nenhuma OP em aberto'
                    : '$opsEmAberto OP${opsEmAberto == 1 ? '' : 's'} em aberto',
            ].join(' · '),
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: !mostrarOps || opsEmAberto > 0
                  ? AppColors.primary
                  : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Caixa extends StatelessWidget {
  const _Caixa({required this.child});

  final Widget child;

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
      child: child,
    );
  }
}

/// Produtos que casam com o que está sendo digitado.
class _ListaSugestoes extends StatelessWidget {
  const _ListaSugestoes({
    required this.itens,
    required this.opsPorProduto,
    required this.onEscolher,
  });

  final List<ProductionCatalogItem> itens;
  final Map<String, int> opsPorProduto;
  final ValueChanged<ProductionCatalogItem> onEscolher;

  static const _maxVisiveis = 6;

  @override
  Widget build(BuildContext context) {
    final visiveis = itens.take(_maxVisiveis).toList();
    final restantes = itens.length - visiveis.length;

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
          for (var i = 0; i < visiveis.length; i++)
            _LinhaSugestao(
              item: visiveis[i],
              opsEmAberto: opsPorProduto[visiveis[i].code] ?? 0,
              mostrarOps: opsPorProduto.isNotEmpty,
              onTap: () => onEscolher(visiveis[i]),
              ultima: i == visiveis.length - 1 && restantes == 0,
            ),
          if (restantes > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'e mais $restantes produto${restantes > 1 ? 's' : ''} — '
                  'digite mais para refinar',
                  style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LinhaSugestao extends StatelessWidget {
  const _LinhaSugestao({
    required this.item,
    required this.opsEmAberto,
    required this.mostrarOps,
    required this.onTap,
    required this.ultima,
  });

  final ProductionCatalogItem item;
  final int opsEmAberto;
  final bool mostrarOps;
  final VoidCallback onTap;
  final bool ultima;

  @override
  Widget build(BuildContext context) {
    final temOp = opsEmAberto > 0;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          border: ultima
              ? null
              : const Border(bottom: BorderSide(color: AppColors.borderLight)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.code,
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (mostrarOps) ...[
              const SizedBox(width: 8),
              Text(
                temOp
                    ? '$opsEmAberto OP${opsEmAberto > 1 ? 's' : ''}'
                    : 'sem OP',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: temOp ? AppColors.primary : AppColors.muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
