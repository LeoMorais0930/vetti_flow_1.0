import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/warehouse.dart';
import 'package:vetti_flow_1_0/data/repositories/pending_mutation_store.dart';
import 'package:vetti_flow_1_0/data/repositories/product_catalog_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_repository.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/produto_busca.dart';

/// Move saldo de um almoxarifado para outro.
///
/// Acontece o tempo todo: o material está no `01` (ALMOXARIFADO) e a OP vai
/// consumir no `05` (PRODUCAO MEC). No Protheus isso é um movimento interno
/// que mexe nas duas posições da SB2; aqui vira um pedido na fila.
class TransferenciaDialog extends StatefulWidget {
  const TransferenciaDialog({
    super.key,
    required this.filial,
    required this.autor,
    this.produtoInicial,
    this.op,
    this.localDestinoInicial,
  });

  final String filial;
  final String autor;

  /// Produto já escolhido, quando a transferência parte de uma OP.
  final String? produtoInicial;

  /// A OP que motivou a transferência, se houver.
  final String? op;

  final String? localDestinoInicial;

  static Future<bool?> mostrar(
    BuildContext context, {
    required String filial,
    required String autor,
    String? produtoInicial,
    String? op,
    String? localDestinoInicial,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => TransferenciaDialog(
        filial: filial,
        autor: autor,
        produtoInicial: produtoInicial,
        op: op,
        localDestinoInicial: localDestinoInicial,
      ),
    );
  }

  @override
  State<TransferenciaDialog> createState() => _TransferenciaDialogState();
}

class _TransferenciaDialogState extends State<TransferenciaDialog> {
  ProductionCatalogItem? _produto;
  final _quantidade = TextEditingController();
  final _motivo = TextEditingController();
  String _origem = '';
  String _destino = '';

  @override
  void initState() {
    super.initState();
    _destino = widget.localDestinoInicial ?? '';
    final codigo = widget.produtoInicial;
    if (codigo != null) {
      _produto = context.read<ProductCatalogRepository>().findByCode(codigo);
      _origem = _sugerirOrigem();
    }
  }

  @override
  void dispose() {
    _quantidade.dispose();
    _motivo.dispose();
    super.dispose();
  }

  /// Onde há mais saldo deste produto — quase sempre de onde faz sentido tirar.
  String _sugerirOrigem() {
    final saldos = _saldos();
    for (final s in saldos) {
      if (s.saldo > 0 && s.local != _destino) return s.local;
    }
    return saldos.isNotEmpty ? saldos.first.local : '';
  }

  /// Saldo por armazém já contando o que está na fila.
  List<SaldoArmazem> _saldos() {
    final produto = _produto;
    if (produto == null) return const [];
    final efetivo = context.read<PendingMutationStore>().saldosEfetivos(
      produto.code,
      widget.filial,
      produto.saldos,
    );
    return efetivo..sort((a, b) => b.saldo.compareTo(a.saldo));
  }

  double? get _valor =>
      double.tryParse(_quantidade.text.trim().replaceAll(',', '.'));

  double get _saldoOrigem {
    for (final s in _saldos()) {
      if (s.local == _origem) return s.saldo;
    }
    return 0;
  }

  bool get _valido {
    final valor = _valor;
    return _produto != null &&
        valor != null &&
        valor > 0 &&
        _origem.isNotEmpty &&
        _destino.isNotEmpty &&
        _origem != _destino;
  }

  void _gravar() {
    final produto = _produto;
    final valor = _valor;
    if (produto == null || valor == null) return;

    context.read<PendingMutationStore>().enqueue(
      (id, agora) => TransferenciaMutation(
        id: id,
        filial: widget.filial,
        criadoEm: agora,
        autor: widget.autor,
        produto: produto.code,
        produtoDescricao: produto.name,
        quantidade: valor,
        localOrigem: _origem,
        localDestino: _destino,
        op: widget.op,
        motivo: _motivo.text.trim().isEmpty ? null : _motivo.text.trim(),
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final armazens = context.read<WarehouseRepository>().armazens;
    final saldos = _saldos();
    final valor = _valor;
    // Estourar o saldo é permitido pelo Protheus e acontece de verdade quando
    // o material está a caminho — avisa, mas não bloqueia.
    final estoura = valor != null && valor > _saldoOrigem;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
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
                          'Transferir entre armazéns',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.op == null
                              ? 'O movimento fica na fila até ir ao Protheus.'
                              : 'Para a OP ${widget.op}.',
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
                    if (widget.produtoInicial == null)
                      ProdutoBusca(
                        catalogo: context.read<ProductCatalogRepository>(),
                        mostrarCartao: false,
                        onProduto: (p) => setState(() {
                          _produto = p;
                          _origem = _sugerirOrigem();
                        }),
                      )
                    else
                      FormFieldLabel(
                        label: 'Produto',
                        child: _Leitura(
                          _produto?.label ?? widget.produtoInicial!,
                        ),
                      ),
                    if (saldos.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _PosicaoEstoque(saldos: saldos),
                    ],
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: FormFieldLabel(
                            label: 'De',
                            child: _SeletorArmazem(
                              armazens: armazens,
                              valor: _origem,
                              onMudar: (v) => setState(() => _origem = v),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 18, left: 8, right: 8),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: AppColors.iconMuted,
                          ),
                        ),
                        Expanded(
                          child: FormFieldLabel(
                            label: 'Para',
                            child: _SeletorArmazem(
                              armazens: armazens,
                              valor: _destino,
                              onMudar: (v) => setState(() => _destino = v),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_origem.isNotEmpty && _origem == _destino)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Origem e destino são o mesmo armazém.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    const SizedBox(height: 15),
                    FormFieldLabel(
                      label: 'Quantidade',
                      child: TextField(
                        controller: _quantidade,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: campoDecoracao(
                          hint: '0',
                          sufixo: _produto?.unit,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (estoura)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Almox. $_origem tem '
                          '${formatProductionQuantity(_saldoOrigem)}. '
                          'A transferência deixa o saldo negativo.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.orangeText,
                          ),
                        ),
                      ),
                    const SizedBox(height: 15),
                    FormFieldLabel(
                      label: 'Motivo',
                      child: TextField(
                        controller: _motivo,
                        maxLines: 2,
                        decoration: campoDecoracao(
                          hint: 'Por que o material está mudando de lugar',
                        ),
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
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.muted,
                    ),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _valido ? _gravar : null,
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

class _SeletorArmazem extends StatelessWidget {
  const _SeletorArmazem({
    required this.armazens,
    required this.valor,
    required this.onMudar,
  });

  final List<Armazem> armazens;
  final String valor;
  final ValueChanged<String> onMudar;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: valor.isNotEmpty ? valor : null,
      decoration: campoDecoracao(hint: 'Armazém'),
      items: [
        for (final a in armazens)
          DropdownMenuItem(
            value: a.codigo,
            child: Text(
              a.label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
      ],
      onChanged: (v) {
        if (v != null) onMudar(v);
      },
    );
  }
}

/// Onde o produto está hoje, já contando o que a fila prometeu mover.
class _PosicaoEstoque extends StatelessWidget {
  const _PosicaoEstoque({required this.saldos});

  final List<SaldoArmazem> saldos;

  @override
  Widget build(BuildContext context) {
    final comSaldo = saldos.where((s) => s.saldo != 0).take(6).toList();
    if (comSaldo.isEmpty) {
      return Text(
        'Sem saldo em nenhum armazém.',
        style: TextStyle(fontSize: 12, color: AppColors.muted),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgHeader,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Posição por armazém',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textCode,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              for (final s in comSaldo)
                Text(
                  '${s.local}: ${formatProductionQuantity(s.saldo)}',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 12,
                    color: s.saldo < 0 ? AppColors.danger : AppColors.text,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Leitura extends StatelessWidget {
  const _Leitura(this.valor);

  final String valor;

  @override
  Widget build(BuildContext context) {
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
        valor,
        style: TextStyle(fontSize: 13.5, color: AppColors.text),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
