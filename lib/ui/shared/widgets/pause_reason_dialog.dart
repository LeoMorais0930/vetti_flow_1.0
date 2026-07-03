import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

class ProductionPauseRequest {
  const ProductionPauseRequest({
    required this.operatorName,
    required this.operatorPin,
    required this.reason,
    this.customReason,
    this.producedQuantity = 0,
  });

  final String operatorName;
  final String operatorPin;
  final PauseReason reason;
  final String? customReason;
  final int producedQuantity;
}

Future<ProductionPauseRequest?> showPauseReasonDialog(
  BuildContext context, {
  required ProductionStage stage,
  required int maxQuantity,
}) {
  final compact = MediaQuery.sizeOf(context).width < 720;
  if (compact) {
    return showModalBottomSheet<ProductionPauseRequest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PauseReasonSheet(
        stage: stage,
        maxQuantity: maxQuantity,
        compact: true,
      ),
    );
  }

  return showDialog<ProductionPauseRequest>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      backgroundColor: Colors.transparent,
      child: _PauseReasonSheet(stage: stage, maxQuantity: maxQuantity),
    ),
  );
}

class _PauseReasonSheet extends StatefulWidget {
  const _PauseReasonSheet({
    required this.stage,
    required this.maxQuantity,
    this.compact = false,
  });

  final ProductionStage stage;
  final int maxQuantity;
  final bool compact;

  @override
  State<_PauseReasonSheet> createState() => _PauseReasonSheetState();
}

class _PauseReasonSheetState extends State<_PauseReasonSheet> {
  final _pinController = TextEditingController();
  final _customController = TextEditingController();
  final _quantityController = TextEditingController();
  var _reason = PauseReason.cafe;
  Operator? _operator;
  bool _invalidPin = false;
  bool _wrongStage = false;
  String? _customReasonError;
  String? _quantityError;

  @override
  void dispose() {
    _pinController.dispose();
    _customController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _onPinChanged(String value) {
    if (value.length < 4) {
      setState(() {
        _operator = null;
        _invalidPin = false;
        _wrongStage = false;
      });
      return;
    }

    final operator = context.read<OperatorAssignmentStore>().findByPin(value);
    setState(() {
      _operator = operator;
      _invalidPin = operator == null;
      _wrongStage =
          operator != null && operator.stage.route != widget.stage.route;
    });
  }

  void _submit() {
    final operator = _operator;
    if (operator == null || _wrongStage) return;
    final customReason = _customController.text.trim();
    if (_reason == PauseReason.outro && customReason.isEmpty) {
      setState(() {
        _customReasonError = 'Informe o motivo da pausa.';
      });
      return;
    }
    final quantityText = _quantityController.text.trim();
    final quantity = quantityText.isEmpty ? 0 : int.tryParse(quantityText);
    if (quantity == null || quantity < 0 || quantity > widget.maxQuantity) {
      setState(() {
        _quantityError = 'Use uma quantidade entre 0 e ${widget.maxQuantity}.';
      });
      return;
    }
    Navigator.of(context).pop(
      ProductionPauseRequest(
        operatorName: operator.name,
        operatorPin: operator.pin,
        reason: _reason,
        customReason: _reason == PauseReason.outro ? customReason : null,
        producedQuantity: quantity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final valid = _operator != null && !_wrongStage;

    return Align(
      alignment: widget.compact ? Alignment.bottomCenter : Alignment.center,
      child: Container(
        width: widget.compact ? double.infinity : null,
        constraints: BoxConstraints(
          maxWidth: widget.compact ? double.infinity : 480,
        ),
        margin: EdgeInsets.all(widget.compact ? 10 : 0),
        padding: EdgeInsets.fromLTRB(
          widget.compact ? 22 : 30,
          widget.compact ? 18 : 28,
          widget.compact ? 22 : 30,
          widget.compact ? 22 : 26,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(widget.compact ? 22 : 16),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.compact) const _SheetHandle(),
              const Text(
                'Pausar OP',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Informe o motivo, a quantidade produzida se for deixar saldo para outra pessoa, e assine com PIN.',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<PauseReason>(
                key: const Key('pause-reason-dropdown'),
                initialValue: _reason,
                decoration: _inputDecoration(label: 'Motivo da pausa'),
                items: PauseReason.values
                    .map(
                      (reason) => DropdownMenuItem(
                        value: reason,
                        child: Text(reason.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _reason = value;
                      _customReasonError = null;
                    });
                  }
                },
              ),
              if (_reason == PauseReason.outro) ...[
                const SizedBox(height: 12),
                TextField(
                  key: const Key('pause-custom-reason'),
                  controller: _customController,
                  onChanged: (_) {
                    if (_customReasonError != null) {
                      setState(() => _customReasonError = null);
                    }
                  },
                  decoration: _inputDecoration(
                    label: 'Explique o motivo',
                    errorText: _customReasonError,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                key: const Key('pause-produced-quantity'),
                controller: _quantityController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _inputDecoration(
                  label: 'Quantidade produzida antes de sair (opcional)',
                  errorText: _quantityError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('pause-pin'),
                controller: _pinController,
                onChanged: _onPinChanged,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 12,
                ),
                decoration: _inputDecoration(
                  label: 'PIN (4 digitos)',
                ).copyWith(counterText: ''),
              ),
              if (_invalidPin)
                const _Feedback(
                  color: Color(0xFFD45B5B),
                  bgColor: Color(0xFFFFF0F0),
                  text: 'PIN nao encontrado. Verifique e tente novamente.',
                ),
              if (_wrongStage && _operator != null)
                _Feedback(
                  color: AppColors.orangeText,
                  bgColor: const Color(0xFFFFF8EC),
                  text:
                      'PIN de ${_operator!.name}, vinculado a "${_operator!.stage.label}".',
                ),
              if (valid)
                _Feedback(
                  color: AppColors.green,
                  bgColor: const Color(0xFFE7F6EC),
                  text: 'Assinando como ${_operator!.name}.',
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.muted,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: valid ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFE4EDF4),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('Pausar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String label, String? errorText}) {
    return InputDecoration(
      labelText: label,
      errorText: errorText,
      filled: true,
      fillColor: const Color(0xFFF8FBFD),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.color,
    required this.bgColor,
    required this.text,
  });

  final Color color;
  final Color bgColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 50,
        height: 4,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFCBD7E1),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
