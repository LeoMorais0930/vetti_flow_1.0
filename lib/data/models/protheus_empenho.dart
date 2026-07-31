/// Um empenho de componente para uma OP, como o Protheus registra na SD4.
///
/// É a reserva de material: "esta OP vai consumir tanto deste componente,
/// saindo deste almoxarifado". O Protheus gera a SD4 a partir da estrutura
/// (SG1) quando a OP nasce, e permite alterá-la depois — é essa alteração que
/// o VettiFlow passa a enfileirar.
class ProtheusEmpenho {
  const ProtheusEmpenho({
    required this.filial,
    required this.op,
    required this.produto,
    required this.local,
    required this.quantidade,
    this.saldo = 0,
    this.data,
  });

  /// D4_FILIAL
  final String filial;

  /// D4_OP — a OP concatenada (número + item + sequência), o mesmo formato de
  /// `ProtheusOrderKey.opConcatenada`. É por aqui que empenho e OP se ligam.
  final String op;

  /// D4_COD — o componente empenhado.
  final String produto;

  /// D4_LOCAL — de qual almoxarifado o componente sai.
  final String local;

  /// D4_QUANT — quanto foi empenhado. Fracionária: a estrutura usa frações
  /// para itens rateados.
  final double quantidade;

  /// D4_SLDEMP — quanto do empenho ainda não foi consumido.
  final double saldo;

  /// D4_DATA, já em dd/MM/yyyy.
  final String? data;

  /// Identidade da linha dentro da OP: um mesmo componente pode aparecer duas
  /// vezes se sair de almoxarifados diferentes.
  String get linhaId => '$filial|$op|$produto|$local';

  Map<String, dynamic> toJson() => {
    'filial': filial,
    'op': op,
    'produto': produto,
    'local': local,
    'quantidade': quantidade,
    'saldo': saldo,
    'data': data,
  };

  factory ProtheusEmpenho.fromJson(Map<String, dynamic> json) =>
      ProtheusEmpenho(
        filial: json['filial'] as String? ?? '',
        op: json['op'] as String? ?? '',
        produto: json['produto'] as String? ?? '',
        local: json['local'] as String? ?? '',
        quantidade: (json['quantidade'] as num?)?.toDouble() ?? 0,
        saldo: (json['saldo'] as num?)?.toDouble() ?? 0,
        data: json['data'] as String?,
      );

  ProtheusEmpenho copyWith({double? quantidade, String? local}) =>
      ProtheusEmpenho(
        filial: filial,
        op: op,
        produto: produto,
        local: local ?? this.local,
        quantidade: quantidade ?? this.quantidade,
        saldo: saldo,
        data: data,
      );
}
