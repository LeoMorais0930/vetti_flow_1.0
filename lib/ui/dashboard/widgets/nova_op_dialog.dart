import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetti_flow_1_0/data/models/warehouse.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/product_catalog_repository.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/protheus_op_picker.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/solicitacao_op_form.dart';

/// Como a OP entra no fluxo.
enum ModoNovaOp {
  /// A OP já existe no Protheus: só se escolhe qual entra.
  trazerExistente,

  /// A OP ainda não existe: o VettiFlow pede a abertura, e o pedido fica na
  /// fila até a API levá-lo ao Protheus.
  solicitarNova,
}

/// Põe uma OP no fluxo do VettiFlow, pelos dois caminhos que existem.
///
/// A busca é sempre pelo **código do produto** (`000-0000`), não pelo número da
/// OP: é o código que a produção conhece de cor.
///
/// Até 30/07/2026 só havia o primeiro caminho, porque o Protheus era o único
/// dono da OP. Em 31/07/2026 ficou decidido que o VettiFlow também solicita a
/// abertura — o segundo caminho. Quem numera continua sendo o ERP.
class NovaOpDialog extends StatefulWidget {
  final List<OrdemDisponivel> ordensDisponiveis;
  final ProductCatalogRepository catalogo;
  final List<Armazem> armazens;
  final List<String> responsaveis;
  final ValueChanged<AdocaoOrdemDTO> onCreate;

  /// Chamado quando o operador pede a abertura de uma OP nova.
  final void Function(SolicitacaoOp pedido, String responsavel, String
  prioridade)
  onSolicitar;

  final VoidCallback onClose;
  final bool isDesktop;
  final double? Function(String produto, String local)? saldoDisponivel;

  const NovaOpDialog({
    super.key,
    required this.ordensDisponiveis,
    required this.catalogo,
    required this.armazens,
    required this.responsaveis,
    required this.onCreate,
    required this.onSolicitar,
    required this.onClose,
    this.isDesktop = true,
    this.saldoDisponivel,
  });

  @override
  State<NovaOpDialog> createState() => _NovaOpDialogState();
}

class _NovaOpDialogState extends State<NovaOpDialog> {
  static const _prioridades = ['Baixa', 'Media', 'Alta'];

  var _modo = ModoNovaOp.trazerExistente;

  /// A OP escolhida no seletor, no modo "trazer existente".
  OrdemDisponivel? _selecionada;

  /// O pedido montado, no modo "solicitar nova".
  SolicitacaoOp? _pedido;

  late String _responsavel;
  String _prioridade = 'Media';

  @override
  void initState() {
    super.initState();
    _responsavel = widget.responsaveis.isNotEmpty
        ? widget.responsaveis.first
        : '';
  }

  bool get _isValid {
    if (_responsavel.isEmpty) return false;
    return switch (_modo) {
      ModoNovaOp.trazerExistente => _selecionada != null,
      ModoNovaOp.solicitarNova => _pedido != null,
    };
  }

  String get _acaoLabel => switch (_modo) {
    ModoNovaOp.trazerExistente => 'Trazer OP para o fluxo',
    ModoNovaOp.solicitarNova => 'Solicitar abertura da OP',
  };

  String get _subtitulo => switch (_modo) {
    ModoNovaOp.trazerExistente =>
      'Busque pelo código do produto. A OP já existe no Protheus.',
    ModoNovaOp.solicitarNova =>
      'O pedido fica na fila até a API levá-lo ao Protheus, que numera a OP.',
  };

  void _submit() {
    if (!_isValid) return;
    switch (_modo) {
      case ModoNovaOp.trazerExistente:
        widget.onCreate(
          AdocaoOrdemDTO(
            numero: _selecionada!.numero,
            responsavel: _responsavel,
            prioridade: _prioridade,
          ),
        );
      case ModoNovaOp.solicitarNova:
        widget.onSolicitar(_pedido!, _responsavel, _prioridade);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(widget.isDesktop ? 22 : 18),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.borderLight)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ordem de Produção',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitulo,
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              _CloseButton(onTap: widget.onClose),
            ],
          ),
        ),

        // Form — rolável: o cartão do produto e a lista de empenhos fazem a
        // altura variar bastante, e sem isto o diálogo estoura em telas menores.
        Flexible(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(widget.isDesktop ? 22 : 18),
              child: Column(
                children: [
                  _SeletorModo(
                    modo: _modo,
                    onMudar: (modo) => setState(() => _modo = modo),
                  ),
                  const SizedBox(height: 18),
                  if (_modo == ModoNovaOp.trazerExistente)
                    ProtheusOpPicker(
                      catalogo: widget.catalogo,
                      ordensDisponiveis: widget.ordensDisponiveis,
                      onSelecionar: (op) =>
                          setState(() => _selecionada = op),
                    )
                  else
                    SolicitacaoOpForm(
                      catalogo: widget.catalogo,
                      armazens: widget.armazens,
                      saldoDisponivel: widget.saldoDisponivel,
                      onMudar: (pedido) => setState(() => _pedido = pedido),
                    ),
                  const SizedBox(height: 15),
                  _FormField(
                    label: 'Responsável',
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _responsavel.isNotEmpty
                          ? _responsavel
                          : null,
                      decoration: _inputDecoration(),
                      style: _inputStyle(),
                      items: widget.responsaveis
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text(r, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _responsavel = v);
                      },
                    ),
                  ),
                  const SizedBox(height: 15),
                  _FormField(
                    label: 'Prioridade',
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _prioridade,
                      decoration: _inputDecoration(),
                      style: _inputStyle(),
                      items: _prioridades
                          .map(
                            (p) => DropdownMenuItem(value: p, child: Text(p)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _prioridade = v);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Footer
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.isDesktop ? 22 : 18,
            vertical: widget.isDesktop ? 15 : 14,
          ),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.borderLight)),
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isValid ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.45,
                    ),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      vertical: widget.isDesktop ? 11 : 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        widget.isDesktop ? 9 : 11,
                      ),
                    ),
                    textStyle: GoogleFonts.ibmPlexSans(
                      fontSize: widget.isDesktop ? 13.5 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(_acaoLabel),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: widget.onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bgButton,
                  foregroundColor: AppColors.textCode,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: widget.isDesktop ? 11 : 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      widget.isDesktop ? 9 : 11,
                    ),
                  ),
                  textStyle: GoogleFonts.ibmPlexSans(
                    fontSize: widget.isDesktop ? 13.5 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.isDesktop) {
      return GestureDetector(
        onTap: widget.onClose,
        child: Container(
          color: Colors.black.withValues(alpha: 0.45),
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 460,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x520F172A),
                    blurRadius: 64,
                    offset: Offset(0, 24),
                  ),
                ],
              ),
              child: content,
            ),
          ),
        ),
      );
    }

    // Mobile: bottom sheet
    return GestureDetector(
      onTap: widget.onClose,
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: content,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.ibmPlexSans(fontSize: 13.5, color: AppColors.muted),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(widget.isDesktop ? 9 : 11),
      borderSide: const BorderSide(color: Color(0xFFDFE3E9)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(widget.isDesktop ? 9 : 11),
      borderSide: const BorderSide(color: Color(0xFFDFE3E9)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(widget.isDesktop ? 9 : 11),
      borderSide: const BorderSide(color: AppColors.primary),
    ),
    contentPadding: EdgeInsets.symmetric(
      horizontal: 11,
      vertical: widget.isDesktop ? 10 : 13,
    ),
    filled: true,
    fillColor: AppColors.surface,
  );

  TextStyle _inputStyle() =>
      GoogleFonts.ibmPlexSans(fontSize: 13.5, color: AppColors.textStrong);
}

/// Alterna entre trazer uma OP que já existe e pedir uma nova.
class _SeletorModo extends StatelessWidget {
  const _SeletorModo({required this.modo, required this.onMudar});

  final ModoNovaOp modo;
  final ValueChanged<ModoNovaOp> onMudar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.bgSegment,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          _Aba(
            label: 'Trazer OP existente',
            ativa: modo == ModoNovaOp.trazerExistente,
            onTap: () => onMudar(ModoNovaOp.trazerExistente),
          ),
          _Aba(
            label: 'Solicitar OP nova',
            ativa: modo == ModoNovaOp.solicitarNova,
            onTap: () => onMudar(ModoNovaOp.solicitarNova),
          ),
        ],
      ),
    );
  }
}

class _Aba extends StatelessWidget {
  const _Aba({required this.label, required this.ativa, required this.onTap});

  final String label;
  final bool ativa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ativa ? AppColors.surface : null,
            borderRadius: BorderRadius.circular(7),
            boxShadow: ativa
                ? const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: ativa ? AppColors.primaryDark : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final Widget child;

  const _FormField({required this.label, required this.child});

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

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgButton,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: const SizedBox(
          width: 30,
          height: 30,
          child: Center(
            child: Text(
              '×',
              style: TextStyle(fontSize: 18, color: AppColors.textMuted),
            ),
          ),
        ),
      ),
    );
  }
}
