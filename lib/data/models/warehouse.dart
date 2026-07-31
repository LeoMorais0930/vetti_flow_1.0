/// Almoxarifado do Protheus (tabela NNR).
///
/// No ambiente da Vetti o cadastro não tem filial preenchida: os códigos valem
/// para a empresa inteira. `01` é o almoxarifado, `03`/`04`/`05` são as linhas
/// de produção, `10` a expedição, `70`+ os terceiros.
class Armazem {
  const Armazem({required this.codigo, required this.descricao});

  /// NNR_CODIGO
  final String codigo;

  /// NNR_DESCRI
  final String descricao;

  String get label => '$codigo - $descricao';

  Map<String, dynamic> toJson() => {'codigo': codigo, 'descricao': descricao};

  factory Armazem.fromJson(Map<String, dynamic> json) => Armazem(
    codigo: json['codigo'] as String? ?? '',
    descricao: json['descricao'] as String? ?? '',
  );

  @override
  bool operator ==(Object other) =>
      other is Armazem &&
      other.codigo == codigo &&
      other.descricao == descricao;

  @override
  int get hashCode => Object.hash(codigo, descricao);
}

/// Posição de estoque de um produto em um almoxarifado (tabela SB2).
///
/// A chave real da SB2 é filial + produto + local: o mesmo produto tem uma
/// linha por almoxarifado, e é isso que dá sentido a transferir saldo de um
/// lugar para outro.
class SaldoArmazem {
  const SaldoArmazem({
    required this.filial,
    required this.local,
    required this.saldo,
    required this.empenhado,
  });

  /// B2_FILIAL
  final String filial;

  /// B2_LOCAL
  final String local;

  /// B2_QATU — saldo atual. Pode ser negativo: o Protheus permite estouro.
  final double saldo;

  /// B2_QEMP — quanto desse saldo já está reservado para alguma OP.
  final double empenhado;

  /// O que sobra para empenhar em uma OP nova.
  ///
  /// Também pode ser negativo, quando o empenhado supera o saldo — situação
  /// real na base e que a tela precisa mostrar, não esconder.
  double get disponivel => saldo - empenhado;

  Map<String, dynamic> toJson() => {
    'filial': filial,
    'local': local,
    'saldo': saldo,
    'empenhado': empenhado,
  };

  factory SaldoArmazem.fromJson(Map<String, dynamic> json) => SaldoArmazem(
    filial: json['filial'] as String? ?? '',
    local: json['local'] as String? ?? '',
    saldo: (json['saldo'] as num?)?.toDouble() ?? 0,
    empenhado: (json['empenhado'] as num?)?.toDouble() ?? 0,
  );
}
