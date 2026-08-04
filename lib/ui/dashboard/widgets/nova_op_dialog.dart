import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vetti_flow_1_0/data/models/protheus_product_lookup.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/shared/models/warehouse_routing.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

class NovaOpDialog extends StatefulWidget {
  final List<String> produtos;
  final List<String> responsaveis;
  final ValueChanged<NovaOrdemDTO> onCreate;
  final Future<ProtheusProductLookup?> Function(String code)? onLookupProduto;
  final Future<List<ProtheusProduct>> Function(String query)? onSearchProdutos;
  final String? currentOperatorName;
  final VoidCallback onClose;
  final bool isDesktop;

  const NovaOpDialog({
    super.key,
    required this.produtos,
    required this.responsaveis,
    required this.onCreate,
    this.onLookupProduto,
    this.onSearchProdutos,
    this.currentOperatorName,
    required this.onClose,
    this.isDesktop = true,
  });

  @override
  State<NovaOpDialog> createState() => _NovaOpDialogState();
}

class _NovaOpDialogState extends State<NovaOpDialog> {
  static const _prioridades = ['Baixa', 'Media', 'Alta'];
  static const _filiais = ['04'];

  late String _produto;
  late final TextEditingController _codigoController;
  late final TextEditingController _produtoController;
  late final TextEditingController _prazoController;
  late final TextEditingController _pinController;
  late final FocusNode _codigoFocusNode;
  Timer? _lookupDebounce;
  ProtheusProductLookup? _lookup;
  String? _lookupMessage;
  var _lookupRequest = 0;
  var _isLookingUp = false;
  int _qtd = 50;
  String _prazo = '';
  String _prioridade = 'Media';
  String _filial = '04';
  String _armazem = '';
  String? _pinError;

  @override
  void initState() {
    super.initState();
    _produto = widget.produtos.isNotEmpty ? widget.produtos.first : '';
    _codigoController = TextEditingController();
    _produtoController = TextEditingController(text: _produto);
    _prazoController = TextEditingController();
    _pinController = TextEditingController();
    _codigoFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _lookupDebounce?.cancel();
    _codigoController.dispose();
    _produtoController.dispose();
    _prazoController.dispose();
    _pinController.dispose();
    _codigoFocusNode.dispose();
    super.dispose();
  }

  bool get _isValid =>
      (widget.onLookupProduto == null
          ? _produto.isNotEmpty
          : _lookup != null) &&
      _qtd > 0;

  bool get _requiresProtheusPin => _lookup?.components.isNotEmpty ?? false;

  void _submit() {
    if (!_isValid) return;
    final pin = _pinController.text.trim();
    if (_requiresProtheusPin && pin.isEmpty) {
      setState(() => _pinError = 'Informe o PIN para movimentar o Protheus.');
      return;
    }
    widget.onCreate(
      NovaOrdemDTO(
        produto: _lookup?.label ?? _produto,
        productCode: _lookup?.product.code,
        productName: _lookup?.product.description,
        components: _lookup?.components ?? const [],
        smdReleaseOrders: _lookup?.smdReleaseOrders ?? const [],
        filial: _filial,
        armazem: _armazem,
        openedBy: widget.currentOperatorName,
        operatorPin: pin.isEmpty ? null : pin,
        qtd: _qtd,
        responsavel: '',
        prazo: _prazo.trim().isEmpty ? null : _prazo.trim(),
        prioridade: _prioridade,
      ),
    );
  }

  void _scheduleLookup(String value) {
    _lookupDebounce?.cancel();
    final code = value.trim();
    if (code.isEmpty) {
      setState(() {
        _lookup = null;
        _lookupMessage = null;
        _produtoController.clear();
        _isLookingUp = false;
      });
      return;
    }
    _lookupDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _lookupProduto(code),
    );
  }

  Future<void> _lookupProduto(String code) async {
    final lookup = widget.onLookupProduto;
    if (lookup == null) return;
    final request = ++_lookupRequest;
    setState(() {
      _isLookingUp = true;
      _lookupMessage = null;
    });
    try {
      final result = await lookup(code);
      if (!mounted || request != _lookupRequest) return;
      setState(() {
        if (result != null) {
          final allowedWarehouses = _orderWarehousesForCurrentOperator(result);
          final currentWarehouse = WarehouseRouting.normalizeCode(_armazem);
          final selectedWarehouse =
              _armazem.isNotEmpty &&
                  allowedWarehouses.contains(currentWarehouse)
              ? currentWarehouse
              : allowedWarehouses.isNotEmpty
              ? allowedWarehouses.first
              : '';
          _lookup = result;
          _filial = result.filial;
          _armazem = selectedWarehouse;
          _produto = result.label;
          _produtoController.text = result.label;
          _lookupMessage = null;
        } else {
          _lookup = null;
          _produtoController.clear();
          _lookupMessage = code.contains('-')
              ? 'Código não encontrado no Protheus.'
              : 'Selecione um código completo da lista do Protheus.';
        }
        _isLookingUp = false;
      });
    } catch (e, st) {
      debugPrint('Erro ao consultar produto no Postgres: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted || request != _lookupRequest) return;
      setState(() {
        _lookup = null;
        _produtoController.clear();
        _lookupMessage = 'Não consegui consultar o Postgres agora.';
        _isLookingUp = false;
      });
    }
  }

  String? _productionGateMessage() {
    final lookup = _lookup;
    if (lookup == null) return null;
    if (!lookup.isReleasedBySmd) {
      return 'Aviso: produto sem OP SMD vinculada no Protheus.';
    }
    final shortages = lookup.stockShortagesFor(_qtd);
    if (shortages.isEmpty) return null;
    final shortage = shortages.first;
    return 'Aviso: estoque insuficiente em ${shortage.component.code}: precisa '
        '${shortage.requiredQuantity}, disponivel ${shortage.availableQuantity}.';
  }

  Future<Iterable<ProtheusProduct>> _searchProdutos(
    TextEditingValue value,
  ) async {
    final query = value.text.trim();
    if (query.isEmpty) return const [];
    final search = widget.onSearchProdutos;
    if (search != null) return search(query);

    final normalized = query.toLowerCase();
    return widget.produtos
        .where((produto) => produto.toLowerCase().contains(normalized))
        .take(12)
        .map(_productFromLabel);
  }

  void _selectProduct(ProtheusProduct product) {
    _codigoController.text = product.code;
    _codigoController.selection = TextSelection.collapsed(
      offset: product.code.length,
    );
    _lookupProduto(product.code);
  }

  ProtheusProduct _productFromLabel(String label) {
    final parts = label.split(' - ');
    return ProtheusProduct(
      code: parts.first.trim(),
      description: parts.length > 1 ? parts.sublist(1).join(' - ') : label,
      filial: _filial,
      type: '',
      unit: '',
      group: '',
    );
  }

  void _selectWarehouse(String? value) {
    if (value == null) return;
    final warehouse = WarehouseRouting.normalizeCode(value);
    if (!WarehouseRouting.canOperatorCreateOrder(
      widget.currentOperatorName,
      warehouse,
    )) {
      return;
    }
    setState(() {
      _armazem = warehouse;
    });
  }

  void _selectComponentWarehouse(String componentCode, String? value) {
    if (value == null) return;
    final warehouse = WarehouseRouting.normalizeCode(value);
    setState(() {
      _lookup = _lookup?.selectComponentWarehouse(componentCode, warehouse);
    });
  }

  List<String> _orderWarehousesForCurrentOperator(
    ProtheusProductLookup lookup,
  ) {
    final operatorName = widget.currentOperatorName?.trim();
    if (operatorName == null || operatorName.isEmpty) {
      return lookup.availableWarehouses;
    }
    final operatorWarehouses =
        WarehouseRouting.orderCreationWarehousesForOperator(operatorName);
    if (operatorWarehouses.isNotEmpty) return operatorWarehouses;
    return lookup.availableWarehouses;
  }

  String? _warehouseGateMessage() {
    final lookup = _lookup;
    final operatorName = widget.currentOperatorName?.trim();
    if (lookup == null || operatorName == null || operatorName.isEmpty) {
      return null;
    }
    final allowedWarehouses = _orderWarehousesForCurrentOperator(lookup);
    if (allowedWarehouses.isEmpty) {
      return null;
    }
    if (_armazem.isNotEmpty &&
        !WarehouseRouting.canOperatorCreateOrder(operatorName, _armazem)) {
      return '$operatorName pode apontar, mas não pode abrir OP no ${WarehouseRouting.labelForWarehouse(_armazem)}.';
    }
    if (_armazem.isNotEmpty &&
        !WarehouseRouting.canOperatorUseWarehouse(operatorName, _armazem)) {
      return '$operatorName não pode abrir OP no ${WarehouseRouting.labelForWarehouse(_armazem)}.';
    }
    // Itens atendidos por outro armazem viram pendencia de confirmacao para
    // aquele setor. A permissao aqui vale apenas para onde a OP sera aberta.
    return null;
  }

  Future<void> _selectDueDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: DateTime(today.year + 5, today.month, today.day),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _prazo = _formatPtBrDate(selected);
      _prazoController.text = _prazo;
    });
  }

  String _formatPtBrDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final productionGateMessage =
        _warehouseGateMessage() ?? _productionGateMessage();
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
                label: 'Código Protheus',
                child: RawAutocomplete<ProtheusProduct>(
                  textEditingController: _codigoController,
                  focusNode: _codigoFocusNode,
                  displayStringForOption: (product) => product.code,
                  optionsBuilder: _searchProdutos,
                  onSelected: _selectProduct,
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          key: const Key('nova-op-product-code'),
                          controller: controller,
                          focusNode: focusNode,
                          textCapitalization: TextCapitalization.characters,
                          decoration: _inputDecoration(
                            hint: 'Digite código ou descrição',
                            suffix: _isLookingUp
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : null,
                          ),
                          style: _inputStyle(),
                          onChanged: _scheduleLookup,
                          onFieldSubmitted: (_) =>
                              _lookupProduto(controller.text.trim()),
                        );
                      },
                  optionsViewBuilder: (context, onSelected, options) {
                    return _ProductOptionsView(
                      options: options.toList(),
                      onSelected: onSelected,
                    );
                  },
                ),
              ),
              if (_lookupMessage != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _lookupMessage!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
              if (_lookup != null) ...[
                const SizedBox(height: 12),
                _ProductLookupSummary(
                  lookup: _lookup!,
                  orderQuantity: _qtd,
                  selectedWarehouse: _armazem,
                  currentOperatorName: widget.currentOperatorName,
                  onComponentWarehouseChanged: _selectComponentWarehouse,
                ),
              ],
              if (productionGateMessage != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    productionGateMessage,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 15),
              _FormField(
                label: 'Produto encontrado',
                child: TextFormField(
                  key: const Key('nova-op-product-name'),
                  readOnly: true,
                  decoration: _inputDecoration(
                    hint: 'Selecione uma opção ou informe um código válido',
                  ),
                  controller: _produtoController,
                  style: _inputStyle(),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _FormField(
                      label: 'Filial',
                      child: DropdownButtonFormField<String>(
                        key: const Key('nova-op-branch'),
                        isExpanded: true,
                        initialValue: _filial,
                        decoration: _inputDecoration(),
                        style: _inputStyle(),
                        items: _filiais
                            .map(
                              (filial) => DropdownMenuItem(
                                value: filial,
                                child: Text('Filial $filial - VT'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _filial = value);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _FormField(
                      label: 'Armazém',
                      child: DropdownButtonFormField<String>(
                        key: const Key('nova-op-warehouse'),
                        isExpanded: true,
                        initialValue: _armazem.isNotEmpty ? _armazem : null,
                        decoration: _inputDecoration(
                          hint: 'Aguardando produto',
                        ),
                        style: _inputStyle(),
                        items:
                            (_lookup == null
                                    ? const <String>[]
                                    : _orderWarehousesForCurrentOperator(
                                        _lookup!,
                                      ))
                                .map(
                                  (warehouse) => DropdownMenuItem(
                                    value: warehouse,
                                    child: Text(
                                      WarehouseRouting.labelForWarehouse(
                                        warehouse,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: _lookup == null ? null : _selectWarehouse,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _FormField(
                      label: 'Quantidade',
                      child: TextFormField(
                        key: const Key('nova-op-quantity'),
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
                      label: 'Prazo (opcional)',
                      child: TextFormField(
                        key: const Key('nova-op-due-date'),
                        controller: _prazoController,
                        readOnly: true,
                        decoration: _inputDecoration(
                          hint: 'Selecionar data',
                          suffix: const Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                        ),
                        style: _inputStyle(),
                        onTap: _selectDueDate,
                      ),
                    ),
                  ),
                ],
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
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _prioridade = v);
                  },
                ),
              ),
              if (_lookup != null) ...[
                const SizedBox(height: 15),
                _FormField(
                  label: 'PIN do responsável',
                  child: TextFormField(
                    key: const Key('nova-op-operator-pin'),
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _inputDecoration(
                      hint: 'Assinatura para movimentar Protheus',
                    ).copyWith(errorText: _pinError),
                    style: _inputStyle(),
                    onChanged: (_) {
                      if (_pinError != null) {
                        setState(() => _pinError = null);
                      }
                    },
                  ),
                ),
              ],
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
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.92,
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
              child: SingleChildScrollView(child: content),
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

  InputDecoration _inputDecoration({String? hint, Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.ibmPlexSans(
          fontSize: 13.5,
          color: AppColors.muted,
        ),
        suffixIcon: suffix == null
            ? null
            : Padding(padding: const EdgeInsets.all(12), child: suffix),
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

class _ProductOptionsView extends StatelessWidget {
  const _ProductOptionsView({required this.options, required this.onSelected});

  final List<ProtheusProduct> options;
  final AutocompleteOnSelected<ProtheusProduct> onSelected;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 10,
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(9),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 396, maxHeight: 260),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 6),
            shrinkWrap: true,
            itemCount: options.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: AppColors.borderLight),
            itemBuilder: (context, index) {
              final product = options[index];
              return InkWell(
                onTap: () => onSelected(product),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.code,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        product.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textStrong,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProductLookupSummary extends StatelessWidget {
  const _ProductLookupSummary({
    required this.lookup,
    required this.orderQuantity,
    required this.selectedWarehouse,
    required this.currentOperatorName,
    required this.onComponentWarehouseChanged,
  });

  final ProtheusProductLookup lookup;
  final int orderQuantity;
  final String selectedWarehouse;
  final String? currentOperatorName;
  final void Function(String componentCode, String? warehouse)
  onComponentWarehouseChanged;

  @override
  Widget build(BuildContext context) {
    final childOrdersCount = lookup.components.fold<int>(
      0,
      (total, component) => total + component.childOrders.length,
    );
    const componentsTitle = 'Estrutura do produto (SG1)';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFD),
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lookup.label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textStrong,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${lookup.product.type} · ${lookup.product.unit} · grupo ${lookup.product.group}',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          Text(
            'Filial ${lookup.filial} - VT',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          if (lookup.components.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              componentsTitle,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textStrong,
              ),
            ),
            const SizedBox(height: 7),
            for (final component in lookup.components)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ComponentCommitmentCard(
                  component: component,
                  orderQuantity: orderQuantity,
                  selectedWarehouse: selectedWarehouse,
                  currentOperatorName: currentOperatorName,
                  onWarehouseChanged: onComponentWarehouseChanged,
                ),
              ),
            Text(
              '${lookup.components.length} componentes'
              '${childOrdersCount > 0 ? ' · $childOrdersCount OPs vinculadas a componentes' : ''}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
          if (lookup.smdReleaseOrders.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              '${lookup.smdReleaseOrders.length} OPs SMD encontradas no Protheus',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.green,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComponentCommitmentCard extends StatelessWidget {
  const _ComponentCommitmentCard({
    required this.component,
    required this.orderQuantity,
    required this.selectedWarehouse,
    required this.currentOperatorName,
    required this.onWarehouseChanged,
  });

  final ProtheusProductComponent component;
  final int orderQuantity;
  final String selectedWarehouse;
  final String? currentOperatorName;
  final void Function(String componentCode, String? warehouse)
  onWarehouseChanged;

  @override
  Widget build(BuildContext context) {
    final required = component.requiredQuantityFor(orderQuantity);
    final missing = component.missingQuantityFor(orderQuantity);
    final alternatives = component.warehousesThatCanCover(orderQuantity);
    final selectedFromOtherWarehouse =
        selectedWarehouse.isNotEmpty &&
        component.armazem.isNotEmpty &&
        component.armazem != selectedWarehouse;
    final coverageOptions = _coverageOptions(required);
    final commitmentLabel = component.commitmentQuantity > 0
        ? ' · quantidade empenhada ${component.commitmentQuantity}'
        : '';
    final originalLabel = component.originalQuantity > 0
        ? ' · quantidade original ${component.originalQuantity}'
        : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: missing > 0 ? const Color(0xFFE8C4C4) : AppColors.borderLight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${component.code} · ${component.description}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textStrong,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'necessário $required ${component.unit}'
            ' · saldo atual ${component.currentStock}'
            ' · empenhado ${component.committedQuantity}'
            ' · reservado ${component.reservedQuantity}'
            ' · disponível ${component.stockAvailable}'
            '${component.armazem.isNotEmpty ? ' · ${WarehouseRouting.labelForWarehouse(component.armazem)}' : ''}'
            '$commitmentLabel$originalLabel',
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
          if (missing > 0 || selectedFromOtherWarehouse) ...[
            const SizedBox(height: 5),
            Text(
              missing <= 0
                  ? 'Atendido pelo ${WarehouseRouting.labelForWarehouse(component.armazem)}.'
                  : alternatives.isEmpty
                  ? 'Falta $missing ${component.unit}. Nenhum outro armazém cobre a quantidade.'
                  : 'Falta $missing ${component.unit}. Selecione de qual armazém tirar.',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
            if (coverageOptions.isNotEmpty) ...[
              const SizedBox(height: 8),
              _WarehouseCoveragePicker(
                component: component,
                alternatives: coverageOptions,
                onWarehouseChanged: onWarehouseChanged,
              ),
            ],
          ],
        ],
      ),
    );
  }

  List<ProtheusWarehouseBalance> _coverageOptions(num requiredQuantity) {
    final options = <ProtheusWarehouseBalance>[];
    final seen = <String>{};
    for (final balance in component.warehouseBalances) {
      final selected = balance.armazem == component.armazem;
      final canCover = balance.availableQuantity >= requiredQuantity;
      if ((selected || canCover) && seen.add(balance.armazem)) {
        options.add(balance);
      }
    }
    options.sort((a, b) => b.availableQuantity.compareTo(a.availableQuantity));
    return options;
  }
}

class _WarehouseCoveragePicker extends StatelessWidget {
  const _WarehouseCoveragePicker({
    required this.component,
    required this.alternatives,
    required this.onWarehouseChanged,
  });

  final ProtheusProductComponent component;
  final List<ProtheusWarehouseBalance> alternatives;
  final void Function(String componentCode, String? warehouse)
  onWarehouseChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFF1D490)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Escolher armazém para atender',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textStrong,
            ),
          ),
          const SizedBox(height: 6),
          for (final balance in alternatives)
            _WarehouseCoverageOption(
              component: component,
              balance: balance,
              selected: component.armazem == balance.armazem,
              onWarehouseChanged: onWarehouseChanged,
            ),
        ],
      ),
    );
  }
}

class _WarehouseCoverageOption extends StatelessWidget {
  const _WarehouseCoverageOption({
    required this.component,
    required this.balance,
    required this.selected,
    required this.onWarehouseChanged,
  });

  final ProtheusProductComponent component;
  final ProtheusWarehouseBalance balance;
  final bool selected;
  final void Function(String componentCode, String? warehouse)
  onWarehouseChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key(
        'nova-op-component-warehouse-option-${component.code}-${balance.armazem}',
      ),
      borderRadius: BorderRadius.circular(7),
      onTap: () => onWarehouseChanged(component.code, balance.armazem),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Checkbox(
                value: selected,
                onChanged: (_) =>
                    onWarehouseChanged(component.code, balance.armazem),
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                WarehouseRouting.labelForWarehouse(balance.armazem),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textStrong,
                ),
              ),
            ),
            Text(
              'disponível ${balance.availableQuantity}',
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
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
