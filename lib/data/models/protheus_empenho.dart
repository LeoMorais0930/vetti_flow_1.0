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
    this.quantidadeOriginal,
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

  /// D4_QUANT ("Sal. Empenho") — quanto **ainda resta** do empenho depois do
  /// que a OP já consumiu. Fracionária: a estrutura usa frações para itens
  /// rateados.
  ///
  /// Achado batendo o nome do campo contra a documentação do Protheus e a
  /// base real em 03/08/2026: apesar do nome sugerir "quantidade empenhada",
  /// este é o valor que **soma no `B2_QEMP`** e que **some conforme a OP
  /// produz** — não é o pedido original. É este campo, e não
  /// [quantidadeOriginal], que entra na matemática de saldo disponível: soma
  /// certo com o estoque porque é exatamente o que o Protheus também soma lá.
  final double quantidade;

  /// D4_QTDEORI ("Qtd. Empenho") — o valor **original**, fixo desde a
  /// abertura da OP, antes de qualquer consumo.
  ///
  /// `null` para retratos antigos que não traziam este campo. A diferença
  /// `quantidadeOriginal - quantidade` é quanto a OP já consumiu deste
  /// componente — no Protheus isso aparece separadamente em `C2_QUJE`
  /// (quantidade já produzida da OP como um todo), não linha a linha; aqui é
  /// só para dar contexto na tela, não entra em nenhuma conta de saldo.
  final double? quantidadeOriginal;

  /// D4_DATA, já em dd/MM/yyyy.
  final String? data;

  /// Quanto deste componente a OP já consumiu, ou `null` sem
  /// [quantidadeOriginal] para comparar.
  double? get consumido =>
      quantidadeOriginal == null ? null : quantidadeOriginal! - quantidade;

  /// Identidade da linha dentro da OP: um mesmo componente pode aparecer duas
  /// vezes se sair de almoxarifados diferentes.
  String get linhaId => '$filial|$op|$produto|$local';

  Map<String, dynamic> toJson() => {
    'filial': filial,
    'op': op,
    'produto': produto,
    'local': local,
    'quantidade': quantidade,
    'quantidadeOriginal': quantidadeOriginal,
    'data': data,
  };

  factory ProtheusEmpenho.fromJson(Map<String, dynamic> json) =>
      ProtheusEmpenho(
        filial: json['filial'] as String? ?? '',
        op: json['op'] as String? ?? '',
        produto: json['produto'] as String? ?? '',
        local: json['local'] as String? ?? '',
        quantidade: (json['quantidade'] as num?)?.toDouble() ?? 0,
        quantidadeOriginal: (json['quantidadeOriginal'] as num?)?.toDouble(),
        data: json['data'] as String?,
      );

  ProtheusEmpenho copyWith({double? quantidade, String? local}) =>
      ProtheusEmpenho(
        filial: filial,
        op: op,
        produto: produto,
        local: local ?? this.local,
        quantidade: quantidade ?? this.quantidade,
        quantidadeOriginal: quantidadeOriginal,
        data: data,
      );
}
