import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

class FirmwareOperation {
  const FirmwareOperation({
    required this.number,
    required this.product,
    required this.quantity,
    required this.origin,
    required this.receivedAt,
    required this.receivedAgo,
  });

  final String number;
  final String product;
  final String quantity;
  final String origin;
  final String receivedAt;
  final String receivedAgo;
}

enum FirmwareStatus {
  waiting('Aguardando'),
  recording('Gravando'),
  paused('Pausada'),
  completed('Concluida');

  const FirmwareStatus(this.label);

  final String label;

  Color get color => switch (this) {
    FirmwareStatus.waiting => AppColors.muted,
    FirmwareStatus.recording => AppColors.primary,
    FirmwareStatus.paused => AppColors.orangeText,
    FirmwareStatus.completed => AppColors.green,
  };

  Color get surface => switch (this) {
    FirmwareStatus.waiting => const Color(0xFFEFF3F7),
    FirmwareStatus.recording => const Color(0xFFE7F4FB),
    FirmwareStatus.paused => const Color(0xFFFBF1E2),
    FirmwareStatus.completed => const Color(0xFFE7F6EC),
  };

  IconData get icon => switch (this) {
    FirmwareStatus.waiting => Icons.schedule_rounded,
    FirmwareStatus.recording => Icons.fiber_manual_record_rounded,
    FirmwareStatus.paused => Icons.pause_circle_outline_rounded,
    FirmwareStatus.completed => Icons.check_circle_rounded,
  };
}

class FirmwareDefect {
  const FirmwareDefect({required this.code, required this.title});

  final String code;
  final String title;

  static const all = [
    FirmwareDefect(code: 'A', title: 'Nao gravou'),
    FirmwareDefect(code: 'B', title: 'Firmware incorreto'),
    FirmwareDefect(code: 'C', title: 'Falha de comunicacao'),
    FirmwareDefect(code: 'D', title: 'Componente danificado'),
    FirmwareDefect(code: 'E', title: 'Placa com curto'),
    FirmwareDefect(code: 'F', title: 'Conector mal soldado'),
    FirmwareDefect(code: 'G', title: 'LED nao acende'),
    FirmwareDefect(code: 'H', title: 'Outro defeito'),
  ];
}
