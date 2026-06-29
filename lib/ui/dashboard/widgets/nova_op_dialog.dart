import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

class NovaOpDialog extends StatefulWidget {
  final List<String> produtos;
  final List<String> responsaveis;
  final ValueChanged<NovaOrdemDTO> onCreate;
  final VoidCallback onClose;
  final bool isDesktop;

  const NovaOpDialog({
    super.key,
    required this.produtos,
    required this.responsaveis,
    required this.onCreate,
    required this.onClose,
    this.isDesktop = true,
  });

  @override
  State<NovaOpDialog> createState() => _NovaOpDialogState();
}

class _NovaOpDialogState extends State<NovaOpDialog> {
  late String _produto;
  late String _responsavel;
  int _qtd = 50;
  String _prazo = '';

  @override
  void initState() {
    super.initState();
    _produto = widget.produtos.isNotEmpty ? widget.produtos.first : '';
    _responsavel = widget.responsaveis.isNotEmpty
        ? widget.responsaveis.first
        : '';
  }

  bool get _isValid =>
      _produto.isNotEmpty &&
      _responsavel.isNotEmpty &&
      _qtd > 0 &&
      _prazo.trim().isNotEmpty;

  void _submit() {
    if (!_isValid) return;
    widget.onCreate(
      NovaOrdemDTO(
        produto: _produto,
        qtd: _qtd,
        responsavel: _responsavel,
        prazo: _prazo.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
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
                      'Nova Ordem de Produção',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Será criada com status "A abrir".',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              _CloseButton(onTap: widget.onClose),
            ],
          ),
        ),

        // Form
        Padding(
          padding: EdgeInsets.all(widget.isDesktop ? 22 : 18),
          child: Column(
            children: [
              _FormField(
                label: 'Produto',
                child: DropdownButtonFormField<String>(
                  initialValue: _produto.isNotEmpty ? _produto : null,
                  decoration: _inputDecoration(),
                  style: _inputStyle(),
                  items: widget.produtos
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _produto = v);
                  },
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _FormField(
                      label: 'Quantidade',
                      child: TextFormField(
                        initialValue: '$_qtd',
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(),
                        style: _inputStyle(),
                        onChanged: (v) =>
                            setState(() => _qtd = int.tryParse(v) ?? 0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _FormField(
                      label: 'Prazo',
                      child: TextFormField(
                        decoration: _inputDecoration(hint: 'dd/mm/aaaa'),
                        style: _inputStyle(),
                        onChanged: (v) => setState(() => _prazo = v),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _FormField(
                label: 'Responsável',
                child: DropdownButtonFormField<String>(
                  initialValue: _responsavel.isNotEmpty ? _responsavel : null,
                  decoration: _inputDecoration(),
                  style: _inputStyle(),
                  items: widget.responsaveis
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _responsavel = v);
                  },
                ),
              ),
            ],
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
                  child: const Text('Criar OP'),
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
              width: 440,
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
            child: SingleChildScrollView(child: content),
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
