import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/warehouse.dart';
import 'package:vetti_flow_1_0/data/repositories/product_catalog_repository.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/produto_busca.dart';

/// Edita os empenhos que compõem uma OP: o que ela consome, quanto e de qual
/// almoxarifado.
///
/// Serve as duas pontas do mesmo problema — a OP que ainda vai ser pedida
/// (linhas vindas da estrutura do produto) e a OP que já existe no Protheus
/// (linhas vindas da SD4). Quem chama decide o que fazer com a alteração:
/// aqui só se edita.
///
/// Não valida saldo a ponto de bloquear: o Protheus permite empenhar mais do
/// que há em estoque, e o chão de fábrica precisa disso quando o material
/// está a caminho. O que falta aparece em vermelho, e segue.
class EmpenhoEditor extends StatelessWidget {
  const EmpenhoEditor({
    super.key,
    required this.linhas,
    required this.armazens,
    required this.catalogo,
    required this.onAlterar,
    required this.onRemover,
    required this.onIncluir,
    this.saldoDisponivel,
    this.somenteLeitura = false,
  });

  final List<EmpenhoLinha> linhas;
  final List<Armazem> armazens;
  final ProductCatalogRepository catalogo;

  final void Function(int index, EmpenhoLinha nova) onAlterar;
  final void Function(int index) onRemover;
  final void Function(EmpenhoLinha nova) onIncluir;

  /// Saldo disponível de um componente num almoxarifado, para a linha avisar
  /// quando o empenho passa do que há.
  ///
  /// `null` no retorno (com a função presente) diz "este produto não tem
  /// posição neste armazém nesta filial" — diferente de saldo zero, que é uma
  /// posição real só que vazia. A função ausente (`saldoDisponivel == null`)
  /// desliga o aviso inteiro, para quem chama sem essa informação disponível.
  final double? Function(String produto, String local)? saldoDisponivel;

  final bool somenteLeitura;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Empenhos da OP',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textCode,
                ),
              ),
            ),
            Text(
              '${linhas.length} componente${linhas.length == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (linhas.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Sem empenhos. O Protheus vai explodir a estrutura '
                      'padrão do produto.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                ),
              for (var i = 0; i < linhas.length; i++)
                _LinhaEmpenho(
                  // A chave amarra o controller de quantidade à linha certa:
                  // sem ela, remover uma linha faria o texto da seguinte
                  // aparecer no lugar errado.
                  key: ValueKey('${linhas[i].produto}|${linhas[i].local}'),
                  linha: linhas[i],
                  armazens: armazens,
                  ultima: i == linhas.length - 1,
                  somenteLeitura: somenteLeitura,
                  disponivelNoArmazem: saldoDisponivel == null
                      ? null
                      : (local) => saldoDisponivel!(linhas[i].produto, local),
                  onAlterar: (nova) => onAlterar(i, nova),
                  onRemover: () => onRemover(i),
                ),
            ],
          ),
        ),
        if (!somenteLeitura) ...[
          const SizedBox(height: 8),
          _AdicionarComponente(
            catalogo: catalogo,
            armazens: armazens,
            jaPresentes: {for (final l in linhas) '${l.produto}|${l.local}'},
            saldoDisponivel: saldoDisponivel,
            onIncluir: onIncluir,
          ),
        ],
      ],
    );
  }
}

class _LinhaEmpenho extends StatefulWidget {
  const _LinhaEmpenho({
    super.key,
    required this.linha,
    required this.armazens,
    required this.ultima,
    required this.somenteLeitura,
    required this.onAlterar,
    required this.onRemover,
    this.disponivelNoArmazem,
  });

  final EmpenhoLinha linha;
  final List<Armazem> armazens;
  final bool ultima;
  final bool somenteLeitura;

  /// Disponível deste componente, num armazém qualquer da lista — usada tanto
  /// para o aviso da linha (no armazém escolhido) quanto para separar, no
  /// dropdown, os armazéns onde o produto tem posição dos que não têm.
  final double? Function(String local)? disponivelNoArmazem;

  final ValueChanged<EmpenhoLinha> onAlterar;
  final VoidCallback onRemover;

  @override
  State<_LinhaEmpenho> createState() => _LinhaEmpenhoState();
}

class _LinhaEmpenhoState extends State<_LinhaEmpenho> {
  late final TextEditingController _quantidade = TextEditingController(
    text: formatProductionQuantity(widget.linha.quantidade),
  );

  @override
  void dispose() {
    _quantidade.dispose();
    super.dispose();
  }

  void _aoMudarQuantidade(String texto) {
    // Vírgula é o separador decimal em pt-BR, e é o que o teclado do chão de
    // fábrica oferece.
    final valor = double.tryParse(texto.trim().replaceAll(',', '.'));
    if (valor == null) return;
    widget.onAlterar(
      EmpenhoLinha(
        produto: widget.linha.produto,
        descricao: widget.linha.descricao,
        quantidade: valor,
        local: widget.linha.local,
      ),
    );
  }

  void _aoMudarLocal(String? local) {
    if (local == null) return;
    widget.onAlterar(
      EmpenhoLinha(
        produto: widget.linha.produto,
        descricao: widget.linha.descricao,
        quantidade: widget.linha.quantidade,
        local: local,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final temInfoSaldo = widget.disponivelNoArmazem != null;
    final disponivel = widget.disponivelNoArmazem?.call(widget.linha.local);
    // `temInfoSaldo` e `disponivel == null` juntos dizem "este produto não tem
    // posição neste armazém" — diferente de `disponivel == 0`, que é uma
    // posição real e vazia.
    final semPosicao = temInfoSaldo && disponivel == null;
    final falta = disponivel != null && widget.linha.quantidade > disponivel;
    // D4_QUANT (o que a linha mostra e edita) é o que **resta** do empenho —
    // não o pedido original. Sem este aviso, "418" parece um número errado
    // para quem espera ver os 500 da estrutura padrão do produto.
    final consumido = widget.linha.consumido;
    final armazensOrdenados = _ordenarArmazensPorPosicao(
      widget.armazens,
      widget.disponivelNoArmazem,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: widget.ultima
            ? null
            : const Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.linha.produto,
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      widget.linha.descricao,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                    if (consumido != null && consumido != 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${formatProductionQuantity(widget.linha.quantidade)} '
                          'de ${formatProductionQuantity(widget.linha.quantidadeOriginal!)} '
                          '· ${formatProductionQuantity(consumido)} já produzido${consumido == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textCode,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 84,
                child: widget.somenteLeitura
                    ? Text(
                        formatProductionQuantity(widget.linha.quantidade),
                        textAlign: TextAlign.right,
                        style: GoogleFonts.ibmPlexMono(fontSize: 12.5),
                      )
                    : TextField(
                        controller: _quantidade,
                        textAlign: TextAlign.right,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: GoogleFonts.ibmPlexMono(fontSize: 12.5),
                        decoration: campoDecoracao(),
                        onChanged: _aoMudarQuantidade,
                      ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 92,
                child: widget.somenteLeitura
                    ? Text(
                        widget.linha.local,
                        style: GoogleFonts.ibmPlexMono(fontSize: 12.5),
                      )
                    : DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: widget.linha.local,
                        decoration: campoDecoracao(),
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: 12.5,
                          color: AppColors.text,
                        ),
                        items: [
                          for (final a in armazensOrdenados)
                            DropdownMenuItem(
                              value: a.codigo,
                              child: Text(
                                _rotuloArmazem(
                                  a.codigo,
                                  widget.disponivelNoArmazem,
                                ),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: temPosicao(
                                    a.codigo,
                                    widget.disponivelNoArmazem,
                                  )
                                      ? null
                                      : AppColors.muted,
                                ),
                              ),
                            ),
                        ],
                        onChanged: _aoMudarLocal,
                      ),
              ),
              if (!widget.somenteLeitura) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Remover empenho',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 17),
                  color: AppColors.iconMuted,
                  onPressed: widget.onRemover,
                ),
              ],
            ],
          ),
          if (semPosicao)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Este produto não tem posição no almox. ${widget.linha.local} '
                'nesta filial.',
                style: TextStyle(fontSize: 11, color: AppColors.orangeText),
              ),
            )
          else if (falta)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Almox. ${widget.linha.local} tem '
                '${formatProductionQuantity(disponivel)} disponível',
                style: TextStyle(fontSize: 11, color: AppColors.danger),
              ),
            ),
        ],
      ),
    );
  }
}

/// Separa os armazéns onde [disponivelNoArmazem] acha posição dos que não
/// têm, sem tirar nenhum da lista — o operador ainda pode escolher um vazio
/// de propósito (começar uma posição nova, por exemplo).
///
/// `null` em [disponivelNoArmazem] (a função em si, não o retorno) significa
/// que não há essa informação para oferecer: devolve a lista como veio.
List<Armazem> _ordenarArmazensPorPosicao(
  List<Armazem> armazens,
  double? Function(String local)? disponivelNoArmazem,
) {
  if (disponivelNoArmazem == null) return armazens;
  final comPosicao = <Armazem>[];
  final semPosicao = <Armazem>[];
  for (final a in armazens) {
    (disponivelNoArmazem(a.codigo) != null ? comPosicao : semPosicao).add(a);
  }
  return [...comPosicao, ...semPosicao];
}

bool temPosicao(
  String codigo,
  double? Function(String local)? disponivelNoArmazem,
) => disponivelNoArmazem == null || disponivelNoArmazem(codigo) != null;

String _rotuloArmazem(
  String codigo,
  double? Function(String local)? disponivelNoArmazem,
) => temPosicao(codigo, disponivelNoArmazem)
    ? codigo
    : '$codigo (sem posição aqui)';

/// Acrescenta um componente que não está na estrutura padrão.
///
/// Acontece de verdade: substituição de componente em falta, reforço de
/// material para refugo previsto.
class _AdicionarComponente extends StatefulWidget {
  const _AdicionarComponente({
    required this.catalogo,
    required this.armazens,
    required this.jaPresentes,
    required this.onIncluir,
    this.saldoDisponivel,
  });

  final ProductCatalogRepository catalogo;
  final List<Armazem> armazens;
  final Set<String> jaPresentes;
  final ValueChanged<EmpenhoLinha> onIncluir;

  /// Mesma função da [EmpenhoEditor] — usada aqui só para separar, no
  /// dropdown, os armazéns onde o produto escolhido tem posição.
  final double? Function(String produto, String local)? saldoDisponivel;

  @override
  State<_AdicionarComponente> createState() => _AdicionarComponenteState();
}

class _AdicionarComponenteState extends State<_AdicionarComponente> {
  bool _aberto = false;
  ProductionCatalogItem? _produto;
  final _quantidade = TextEditingController();
  String _local = '';

  @override
  void initState() {
    super.initState();
    _local = widget.armazens.isNotEmpty ? widget.armazens.first.codigo : '';
  }

  @override
  void dispose() {
    _quantidade.dispose();
    super.dispose();
  }

  double? get _valor =>
      double.tryParse(_quantidade.text.trim().replaceAll(',', '.'));

  bool get _valido {
    final produto = _produto;
    final valor = _valor;
    if (produto == null || valor == null || valor <= 0) return false;
    return !widget.jaPresentes.contains('${produto.code}|$_local');
  }

  void _incluir() {
    final produto = _produto;
    final valor = _valor;
    if (produto == null || valor == null) return;
    widget.onIncluir(
      EmpenhoLinha(
        produto: produto.code,
        descricao: produto.name,
        quantidade: valor,
        local: _local,
      ),
    );
    setState(() {
      _aberto = false;
      _produto = null;
      _quantidade.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_aberto) {
      return TextButton.icon(
        onPressed: () => setState(() => _aberto = true),
        icon: const Icon(Icons.add_rounded, size: 17),
        label: const Text('Acrescentar componente'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: GoogleFonts.ibmPlexSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final produto = _produto;
    final disponivelNoArmazem = produto == null || widget.saldoDisponivel == null
        ? null
        : (String local) => widget.saldoDisponivel!(produto.code, local);
    final armazensOrdenados = _ordenarArmazensPorPosicao(
      widget.armazens,
      disponivelNoArmazem,
    );
    final duplicado =
        produto != null &&
        widget.jaPresentes.contains('${produto.code}|$_local');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgHeader,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProdutoBusca(
            catalogo: widget.catalogo,
            mostrarCartao: false,
            onProduto: (p) => setState(() => _produto = p),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FormFieldLabel(
                  label: 'Quantidade',
                  child: TextField(
                    controller: _quantidade,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: campoDecoracao(hint: '0'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FormFieldLabel(
                  label: 'Almoxarifado',
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _local.isNotEmpty ? _local : null,
                    decoration: campoDecoracao(),
                    items: [
                      for (final a in armazensOrdenados)
                        DropdownMenuItem(
                          value: a.codigo,
                          child: Text(
                            temPosicao(a.codigo, disponivelNoArmazem)
                                ? a.label
                                : '${a.label} (sem posição aqui)',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: temPosicao(a.codigo, disponivelNoArmazem)
                                  ? null
                                  : AppColors.muted,
                            ),
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _local = v ?? _local),
                  ),
                ),
              ),
            ],
          ),
          if (duplicado)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Este componente já está empenhado neste almoxarifado. '
                'Altere a linha existente.',
                style: TextStyle(fontSize: 11.5, color: AppColors.danger),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton(
                onPressed: _valido ? _incluir : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  textStyle: GoogleFonts.ibmPlexSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Acrescentar'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() => _aberto = false),
                style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
