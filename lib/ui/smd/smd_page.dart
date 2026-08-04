import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/ui/firmware/firmware_page.dart';

class SmdPage extends StatelessWidget {
  const SmdPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FirmwarePage(
      stage: ProductionStage.smd,
      workStage: WorkStage.smd,
      title: 'SMD',
      operatorName: 'Paula',
      operatorRole: 'SMD',
      origin: 'Almoxarifado',
      emptyText: 'Nenhuma OP aguardando SMD.',
      queueSubtitle: 'Liberadas pelo almoxarifado para SMD.',
      runningMetricLabel: 'Em apontamento',
      nextStageLabel: 'Gravacao',
      startLabel: 'Iniciar SMD',
      resumeLabel: 'Retomar SMD',
      completeLabel: 'Concluir apontamento',
      pauseLabel: 'Pausar apontamento',
      waitingHint: 'Inicie o apontamento para liberar as demais acoes.',
      runningHint: 'SMD em apontamento. Pause ou conclua a OP.',
      pausedHint: 'OP pausada. Retome ou conclua o apontamento.',
      completedLabel: 'OP apontada e enviada para gravacao.',
      completionSnackTarget: 'Gravacao',
      collectDefectsOnComplete: false,
      stageIcon: Icons.developer_board_rounded,
      accent: Color(0xFF0E9C8A),
    );
  }
}
