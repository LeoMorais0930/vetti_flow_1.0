import 'package:vetti_flow_1_0/data/models/production_flow.dart'
    show formatProductionQuantity;

/// O que a mutação pede ao Protheus.
enum MutationKind {
  /// Abrir uma OP nova para um produto (SC2).
  aberturaOp,

  /// Mexer no empenho de componentes de uma OP (SD4).
  empenho,

  /// Mover saldo de um almoxarifado para outro (SB2, via movimento interno).
  transferencia,
}

/// Onde a mutação está no caminho entre o VettiFlow e o Protheus.
///
/// A fila é o ponto de verdade enquanto `enviado` não acontece: o Protheus só
/// sabe da mudança depois que a API confirma.
enum MutationStatus {
  /// Na fila local, ainda não foi para a API.
  pendente,

  /// Enviada, aguardando resposta. Não reenviar nesse estado.
  enviando,

  /// A API recebeu e guardou, mas não aplicou no Protheus.
  ///
  /// O Protheus só recebe a escrita quando a OP for finalizada pela
  /// Responsável. Até lá, a mutação fica armazenada na API.
  armazenado,

  /// A API aplicou no Protheus — a OP foi finalizada.
  enviado,

  /// A API recusou. `erro` diz por quê; pode ser reenviada.
  erro,
}

extension MutationStatusLabel on MutationStatus {
  String get label => switch (this) {
    MutationStatus.pendente => 'Pendente',
    MutationStatus.enviando => 'Enviando',
    MutationStatus.armazenado => 'Armazenado',
    MutationStatus.enviado => 'Aplicado',
    MutationStatus.erro => 'Erro',
  };
}

/// O que fazer com uma linha de empenho.
enum EmpenhoOperacao { incluir, alterar, excluir }

extension EmpenhoOperacaoLabel on EmpenhoOperacao {
  String get label => switch (this) {
    EmpenhoOperacao.incluir => 'Incluir',
    EmpenhoOperacao.alterar => 'Alterar',
    EmpenhoOperacao.excluir => 'Excluir',
  };
}

/// Uma alteração que o VettiFlow quer fazer no Protheus, guardada em cache até
/// a API levá-la para lá.
///
/// Existe porque a decisão de 31/07/2026 inverteu a regra anterior: o
/// VettiFlow deixou de ser só leitor da OP e passa a **solicitar** abertura de
/// OP, alteração de empenho e transferência entre armazéns. Como o Protheus
/// não está no ar durante a operação de chão de fábrica, a solicitação nasce
/// aqui, fica na fila, e é transportada depois.
///
/// A fila é append-only até a confirmação: nada é apagado por engano, e o que
/// falhou continua visível com o motivo.
sealed class PendingMutation {
  const PendingMutation({
    required this.id,
    required this.filial,
    required this.criadoEm,
    required this.autor,
    this.status = MutationStatus.pendente,
    this.erro,
    this.protheusRef,
  });

  /// Gerado no app. Vai junto para a API como chave de idempotência: reenviar
  /// a mesma mutação não pode criar duas OPs.
  final String id;

  final String filial;
  final DateTime criadoEm;

  /// Quem pediu — o operador logado. O Protheus vai querer saber.
  final String autor;

  final MutationStatus status;

  /// Preenchido quando [status] é [MutationStatus.erro].
  final String? erro;

  /// O que o Protheus devolveu ao aplicar: o número da OP criada, o documento
  /// da transferência. Nulo até a confirmação.
  final String? protheusRef;

  MutationKind get kind;

  /// Uma linha para a fila na tela.
  String get titulo;

  /// A segunda linha, com o detalhe do que muda.
  String get detalhe;

  /// O corpo específico do tipo, sem o envelope.
  Map<String, dynamic> payload();

  /// Devolve a mesma mutação em outro estado.
  PendingMutation copyWithStatus({
    required MutationStatus status,
    String? erro,
    String? protheusRef,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'filial': filial,
    'criadoEm': criadoEm.toIso8601String(),
    'autor': autor,
    'status': status.name,
    'erro': erro,
    'protheusRef': protheusRef,
    'payload': payload(),
  };

  static PendingMutation fromJson(Map<String, dynamic> json) {
    final kind = MutationKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => throw FormatException('kind desconhecido: ${json['kind']}'),
    );
    final payload = (json['payload'] as Map?)?.cast<String, dynamic>() ?? {};
    return switch (kind) {
      MutationKind.aberturaOp => AberturaOpMutation._fromJson(json, payload),
      MutationKind.empenho => EmpenhoMutation._fromJson(json, payload),
      MutationKind.transferencia => TransferenciaMutation._fromJson(
        json,
        payload,
      ),
    };
  }
}

/// Campos do envelope, lidos uma vez só para os três tipos.
class _Envelope {
  _Envelope(Map<String, dynamic> json)
    : id = json['id'] as String? ?? '',
      filial = json['filial'] as String? ?? '',
      criadoEm =
          DateTime.tryParse(json['criadoEm'] as String? ?? '') ?? DateTime.now(),
      autor = json['autor'] as String? ?? '',
      status = MutationStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => MutationStatus.pendente,
      ),
      erro = json['erro'] as String?,
      protheusRef = json['protheusRef'] as String?;

  final String id;
  final String filial;
  final DateTime criadoEm;
  final String autor;
  final MutationStatus status;
  final String? erro;
  final String? protheusRef;
}

/// Pedido de abertura de uma OP nova para um produto.
///
/// O número da OP **não** nasce aqui: quem numera é o Protheus. Até a
/// confirmação, esta mutação é só um pedido — `protheusRef` recebe o número
/// de verdade depois.
final class AberturaOpMutation extends PendingMutation {
  const AberturaOpMutation({
    required super.id,
    required super.filial,
    required super.criadoEm,
    required super.autor,
    required this.produto,
    required this.produtoDescricao,
    required this.quantidade,
    required this.localProducao,
    this.previsao,
    this.observacao,
    this.empenhos = const [],
    super.status,
    super.erro,
    super.protheusRef,
  });

  /// C2_PRODUTO
  final String produto;

  /// Só para a fila ficar legível; o Protheus não usa.
  final String produtoDescricao;

  /// C2_QUANT
  final int quantidade;

  /// C2_LOCAL — onde a OP entrega o produto acabado.
  final String localProducao;

  /// C2_DATPRF, em dd/MM/yyyy.
  final String? previsao;

  final String? observacao;

  /// Os empenhos com que a OP deve nascer.
  ///
  /// Vazio significa "usa a estrutura padrão do produto", que é o que o
  /// Protheus faz sozinho. Preenchido, substitui essa explosão — é como o
  /// operador ajusta o que vai compor a OP antes mesmo de ela existir.
  final List<EmpenhoLinha> empenhos;

  @override
  MutationKind get kind => MutationKind.aberturaOp;

  @override
  String get titulo => 'Abrir OP · $produto';

  @override
  String get detalhe {
    final partes = [
      '$quantidade un',
      'almox. $localProducao',
      if (previsao != null) 'prazo $previsao',
      if (empenhos.isNotEmpty) '${empenhos.length} empenhos ajustados',
    ];
    return partes.join(' · ');
  }

  @override
  Map<String, dynamic> payload() => {
    'produto': produto,
    'produtoDescricao': produtoDescricao,
    'quantidade': quantidade,
    'localProducao': localProducao,
    'previsao': previsao,
    'observacao': observacao,
    'empenhos': [for (final e in empenhos) e.toJson()],
  };

  @override
  AberturaOpMutation copyWithStatus({
    required MutationStatus status,
    String? erro,
    String? protheusRef,
  }) => AberturaOpMutation(
    id: id,
    filial: filial,
    criadoEm: criadoEm,
    autor: autor,
    produto: produto,
    produtoDescricao: produtoDescricao,
    quantidade: quantidade,
    localProducao: localProducao,
    previsao: previsao,
    observacao: observacao,
    empenhos: empenhos,
    status: status,
    erro: erro,
    protheusRef: protheusRef ?? this.protheusRef,
  );

  static AberturaOpMutation _fromJson(
    Map<String, dynamic> json,
    Map<String, dynamic> p,
  ) {
    final env = _Envelope(json);
    return AberturaOpMutation(
      id: env.id,
      filial: env.filial,
      criadoEm: env.criadoEm,
      autor: env.autor,
      status: env.status,
      erro: env.erro,
      protheusRef: env.protheusRef,
      produto: p['produto'] as String? ?? '',
      produtoDescricao: p['produtoDescricao'] as String? ?? '',
      quantidade: (p['quantidade'] as num?)?.toInt() ?? 0,
      localProducao: p['localProducao'] as String? ?? '',
      previsao: p['previsao'] as String?,
      observacao: p['observacao'] as String?,
      empenhos: [
        for (final e in (p['empenhos'] as List?) ?? const [])
          EmpenhoLinha.fromJson((e as Map).cast<String, dynamic>()),
      ],
    );
  }
}

/// Uma linha de empenho dentro de um pedido de abertura de OP.
class EmpenhoLinha {
  const EmpenhoLinha({
    required this.produto,
    required this.descricao,
    required this.quantidade,
    required this.local,
    this.quantidadeOriginal,
  });

  final String produto;
  final String descricao;

  /// O que resta do empenho hoje — em edição de OP existente é o D4_QUANT
  /// (ver [ProtheusEmpenho.quantidade]); numa OP nova é a quantidade inteira,
  /// já que nada foi consumido ainda.
  final double quantidade;

  final String local;

  /// D4_QTDEORI, só para dar contexto na tela ("418 de 500, 82 já
  /// produzidos"). `null` numa OP nova, que ainda não tem histórico de
  /// consumo — ali [quantidade] já é o valor cheio.
  final double? quantidadeOriginal;

  double? get consumido =>
      quantidadeOriginal == null ? null : quantidadeOriginal! - quantidade;

  Map<String, dynamic> toJson() => {
    'produto': produto,
    'descricao': descricao,
    'quantidade': quantidade,
    'local': local,
    'quantidadeOriginal': quantidadeOriginal,
  };

  factory EmpenhoLinha.fromJson(Map<String, dynamic> json) => EmpenhoLinha(
    produto: json['produto'] as String? ?? '',
    descricao: json['descricao'] as String? ?? '',
    quantidade: (json['quantidade'] as num?)?.toDouble() ?? 0,
    local: json['local'] as String? ?? '',
    quantidadeOriginal: (json['quantidadeOriginal'] as num?)?.toDouble(),
  );
}

/// Alteração no empenho de uma OP que **já existe** no Protheus.
final class EmpenhoMutation extends PendingMutation {
  const EmpenhoMutation({
    required super.id,
    required super.filial,
    required super.criadoEm,
    required super.autor,
    required this.op,
    required this.operacao,
    required this.produto,
    required this.produtoDescricao,
    required this.local,
    required this.quantidade,
    this.quantidadeAnterior,
    this.localAnterior,
    this.motivo,
    super.status,
    super.erro,
    super.protheusRef,
  });

  /// D4_OP — a OP concatenada.
  final String op;

  final EmpenhoOperacao operacao;

  /// D4_COD
  final String produto;

  final String produtoDescricao;

  /// D4_LOCAL de destino da alteração.
  final String local;

  /// D4_QUANT depois da alteração. Em [EmpenhoOperacao.excluir] é ignorada.
  final double quantidade;

  /// Como estava antes, para a fila mostrar a mudança e para a API conseguir
  /// detectar que o Protheus mudou por baixo entre a fila e o envio.
  final double? quantidadeAnterior;
  final String? localAnterior;

  final String? motivo;

  @override
  MutationKind get kind => MutationKind.empenho;

  @override
  String get titulo => '${operacao.label} empenho · OP $op';

  @override
  String get detalhe {
    final qtd = formatProductionQuantity(quantidade);
    return switch (operacao) {
      EmpenhoOperacao.incluir =>
        '$produto · $qtd un · almox. $local',
      EmpenhoOperacao.excluir => '$produto · almox. $local',
      EmpenhoOperacao.alterar => () {
        final antes = quantidadeAnterior;
        final mudouLocal = localAnterior != null && localAnterior != local;
        final partes = <String>[produto];
        if (antes != null && antes != quantidade) {
          partes.add('${formatProductionQuantity(antes)} → $qtd un');
        } else {
          partes.add('$qtd un');
        }
        if (mudouLocal) partes.add('almox. $localAnterior → $local');
        return partes.join(' · ');
      }(),
    };
  }

  @override
  Map<String, dynamic> payload() => {
    'op': op,
    'operacao': operacao.name,
    'produto': produto,
    'produtoDescricao': produtoDescricao,
    'local': local,
    'quantidade': quantidade,
    'quantidadeAnterior': quantidadeAnterior,
    'localAnterior': localAnterior,
    'motivo': motivo,
  };

  @override
  EmpenhoMutation copyWithStatus({
    required MutationStatus status,
    String? erro,
    String? protheusRef,
  }) => EmpenhoMutation(
    id: id,
    filial: filial,
    criadoEm: criadoEm,
    autor: autor,
    op: op,
    operacao: operacao,
    produto: produto,
    produtoDescricao: produtoDescricao,
    local: local,
    quantidade: quantidade,
    quantidadeAnterior: quantidadeAnterior,
    localAnterior: localAnterior,
    motivo: motivo,
    status: status,
    erro: erro,
    protheusRef: protheusRef ?? this.protheusRef,
  );

  static EmpenhoMutation _fromJson(
    Map<String, dynamic> json,
    Map<String, dynamic> p,
  ) {
    final env = _Envelope(json);
    return EmpenhoMutation(
      id: env.id,
      filial: env.filial,
      criadoEm: env.criadoEm,
      autor: env.autor,
      status: env.status,
      erro: env.erro,
      protheusRef: env.protheusRef,
      op: p['op'] as String? ?? '',
      operacao: EmpenhoOperacao.values.firstWhere(
        (o) => o.name == p['operacao'],
        orElse: () => EmpenhoOperacao.alterar,
      ),
      produto: p['produto'] as String? ?? '',
      produtoDescricao: p['produtoDescricao'] as String? ?? '',
      local: p['local'] as String? ?? '',
      quantidade: (p['quantidade'] as num?)?.toDouble() ?? 0,
      quantidadeAnterior: (p['quantidadeAnterior'] as num?)?.toDouble(),
      localAnterior: p['localAnterior'] as String?,
      motivo: p['motivo'] as String?,
    );
  }
}

/// Transferência de saldo entre almoxarifados.
final class TransferenciaMutation extends PendingMutation {
  const TransferenciaMutation({
    required super.id,
    required super.filial,
    required super.criadoEm,
    required super.autor,
    required this.produto,
    required this.produtoDescricao,
    required this.quantidade,
    required this.localOrigem,
    required this.localDestino,
    this.op,
    this.motivo,
    super.status,
    super.erro,
    super.protheusRef,
  });

  final String produto;
  final String produtoDescricao;
  final double quantidade;

  /// De onde sai (SB2 origem).
  final String localOrigem;

  /// Para onde vai (SB2 destino).
  final String localDestino;

  /// A OP que motivou a transferência, quando houver. Não é obrigatória:
  /// transferência também acontece fora de OP.
  final String? op;

  final String? motivo;

  @override
  MutationKind get kind => MutationKind.transferencia;

  @override
  String get titulo => 'Transferir · $produto';

  @override
  String get detalhe {
    final partes = [
      '${formatProductionQuantity(quantidade)} un',
      '$localOrigem → $localDestino',
      if (op != null) 'OP $op',
    ];
    return partes.join(' · ');
  }

  @override
  Map<String, dynamic> payload() => {
    'produto': produto,
    'produtoDescricao': produtoDescricao,
    'quantidade': quantidade,
    'localOrigem': localOrigem,
    'localDestino': localDestino,
    'op': op,
    'motivo': motivo,
  };

  @override
  TransferenciaMutation copyWithStatus({
    required MutationStatus status,
    String? erro,
    String? protheusRef,
  }) => TransferenciaMutation(
    id: id,
    filial: filial,
    criadoEm: criadoEm,
    autor: autor,
    produto: produto,
    produtoDescricao: produtoDescricao,
    quantidade: quantidade,
    localOrigem: localOrigem,
    localDestino: localDestino,
    op: op,
    motivo: motivo,
    status: status,
    erro: erro,
    protheusRef: protheusRef ?? this.protheusRef,
  );

  static TransferenciaMutation _fromJson(
    Map<String, dynamic> json,
    Map<String, dynamic> p,
  ) {
    final env = _Envelope(json);
    return TransferenciaMutation(
      id: env.id,
      filial: env.filial,
      criadoEm: env.criadoEm,
      autor: env.autor,
      status: env.status,
      erro: env.erro,
      protheusRef: env.protheusRef,
      produto: p['produto'] as String? ?? '',
      produtoDescricao: p['produtoDescricao'] as String? ?? '',
      quantidade: (p['quantidade'] as num?)?.toDouble() ?? 0,
      localOrigem: p['localOrigem'] as String? ?? '',
      localDestino: p['localDestino'] as String? ?? '',
      op: p['op'] as String?,
      motivo: p['motivo'] as String?,
    );
  }
}
