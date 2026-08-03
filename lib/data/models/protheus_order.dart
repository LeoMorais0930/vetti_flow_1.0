import 'package:vetti_flow_1_0/data/models/production_flow.dart';

/// Uma ordem de produção como ela existe no Protheus (SC2).
///
/// O VettiFlow não cria OPs: elas nascem no ERP e são adotadas aqui. Este
/// modelo é somente leitura — espelha o que veio do Protheus, sem nada do
/// fluxo de etapas, que é responsabilidade do [ProductionOrderFlow].
class ProtheusOrder {
  const ProtheusOrder({
    required this.key,
    required this.productCode,
    required this.quantity,
    this.localProducao = '',
    this.issuedAt,
    this.dueAt,
    this.closed = false,
  });

  final ProtheusOrderKey key;

  /// C2_PRODUTO
  final String productCode;

  /// C2_QUANT
  final int quantity;

  /// C2_LOCAL — onde o produto acabado entra quando a OP produz.
  final String localProducao;

  /// C2_EMISSAO, já em dd/MM/yyyy.
  final String? issuedAt;

  /// C2_DATPRF (previsão de término), já em dd/MM/yyyy.
  final String? dueAt;

  /// Verdadeiro quando C2_DATRF está preenchido.
  ///
  /// OP encerrada no Protheus é **somente leitura**: aparece para consulta,
  /// mas não pode ser adotada nem operada no VettiFlow.
  final bool closed;

  /// Identificador interno: o formato concatenado do Protheus, o mesmo que
  /// aparece em D3_OP e D4_OP. É a chave usada entre as camadas.
  String get displayNumber => key.opConcatenada;

  /// Como a OP aparece para quem opera: `015942-01-001`.
  String get numeroLegivel => key.numeroLegivel;

  factory ProtheusOrder.fromJson(Map<String, dynamic> json) {
    return ProtheusOrder(
      key: ProtheusOrderKey(
        filial: json['filial'] as String? ?? '',
        numero: json['numero'] as String? ?? '',
        item: json['item'] as String? ?? '',
        sequencia: json['sequencia'] as String? ?? '',
        itemGrade: json['itemGrade'] as String? ?? '',
      ),
      productCode: json['produto'] as String? ?? '',
      quantity: (json['quantidade'] as num?)?.toInt() ?? 0,
      localProducao: json['local'] as String? ?? '',
      issuedAt: json['emissao'] as String?,
      dueAt: json['previsao'] as String?,
      closed: json['encerrada'] as bool? ?? false,
    );
  }
}
