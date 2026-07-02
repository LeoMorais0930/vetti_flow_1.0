import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/shared/theme/app_colors.dart';

enum StatusOP {
  aAbrir,
  naoIniciada,
  emAndamento,
  finalizada;

  String get label => switch (this) {
    aAbrir => 'A abrir',
    naoIniciada => 'Aberta · não iniciada',
    emAndamento => 'Em andamento',
    finalizada => 'Finalizada',
  };

  String get shortLabel => switch (this) {
    aAbrir => 'A abrir',
    naoIniciada => 'Não iniciadas',
    emAndamento => 'Em andamento',
    finalizada => 'Finalizadas',
  };

  Color get dot => switch (this) {
    aAbrir => AppColors.dotAAbrir,
    naoIniciada => AppColors.dotNaoIniciada,
    emAndamento => AppColors.dotAndamento,
    finalizada => AppColors.dotFinalizada,
  };

  Color get textColor => switch (this) {
    aAbrir => AppColors.statusAAbrir,
    naoIniciada => AppColors.statusNaoIniciada,
    emAndamento => AppColors.statusAndamento,
    finalizada => AppColors.statusFinalizada,
  };

  Color get bgColor => switch (this) {
    aAbrir => AppColors.bgAAbrir,
    naoIniciada => AppColors.bgNaoIniciada,
    emAndamento => AppColors.bgAndamento,
    finalizada => AppColors.bgFinalizada,
  };

  Color get barColor => switch (this) {
    finalizada => AppColors.barGreen,
    emAndamento => AppColors.barYellow,
    _ => AppColors.barGray,
  };

  StatusOP? get next => switch (this) {
    aAbrir => naoIniciada,
    naoIniciada => emAndamento,
    emAndamento => finalizada,
    finalizada => null,
  };

  StatusOP? get previous => switch (this) {
    aAbrir => null,
    naoIniciada => aAbrir,
    emAndamento => naoIniciada,
    finalizada => emAndamento,
  };

  String get actionLabel => switch (this) {
    aAbrir => 'Abrir OP',
    naoIniciada => 'Iniciar produção',
    emAndamento => 'Finalizar OP',
    finalizada => '',
  };
}

class OrdemProducao {
  final String numero;
  final String produto;
  final int qtd;
  final String responsavel;
  final String dataAbertura;
  final String prazo;
  final StatusOP status;
  final int progresso;
  final String mes;
  final bool atrasada;

  /// Etapa real da OP no fluxo de produção (fonte: ProductionFlowStore).
  final ProductionStage stage;

  /// Materiais (BOM) do produto: (descrição, quantidade por unidade).
  final List<(String, int)> materiais;

  const OrdemProducao({
    required this.numero,
    required this.produto,
    required this.qtd,
    required this.responsavel,
    required this.dataAbertura,
    required this.prazo,
    required this.status,
    required this.progresso,
    required this.mes,
    this.atrasada = false,
    this.stage = ProductionStage.warehouse,
    this.materiais = const [],
  });

  String get qtdLabel => '$qtd un';

  String get prazoLabel => 'Prazo $prazo';

  String get percentLabel => '$progresso%';

  bool get showBar =>
      status == StatusOP.emAndamento || status == StatusOP.finalizada;

  OrdemProducao copyWith({
    String? numero,
    String? produto,
    int? qtd,
    String? responsavel,
    String? dataAbertura,
    String? prazo,
    StatusOP? status,
    int? progresso,
    String? mes,
    bool? atrasada,
    ProductionStage? stage,
    List<(String, int)>? materiais,
  }) {
    return OrdemProducao(
      numero: numero ?? this.numero,
      produto: produto ?? this.produto,
      qtd: qtd ?? this.qtd,
      responsavel: responsavel ?? this.responsavel,
      dataAbertura: dataAbertura ?? this.dataAbertura,
      prazo: prazo ?? this.prazo,
      status: status ?? this.status,
      progresso: progresso ?? this.progresso,
      mes: mes ?? this.mes,
      atrasada: atrasada ?? this.atrasada,
      stage: stage ?? this.stage,
      materiais: materiais ?? this.materiais,
    );
  }
}

class OrdemArmazenada {
  final String numero;
  final String produto;
  final int quantidadeOriginal;
  final int quantidadeArmazenada;
  final String responsavel;
  final String data;

  const OrdemArmazenada({
    required this.numero,
    required this.produto,
    required this.quantidadeOriginal,
    required this.quantidadeArmazenada,
    required this.responsavel,
    required this.data,
  });

  String get qtdOriginalLabel => '$quantidadeOriginal un';

  String get qtdArmazenadaLabel => '$quantidadeArmazenada un';

  String get tipoLabel => quantidadeArmazenada >= quantidadeOriginal
      ? 'Armazenada total'
      : 'Armazenada parcial';
}
