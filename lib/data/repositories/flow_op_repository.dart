import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/responsavel.dart';
import 'package:vetti_flow_1_0/data/repositories/empenho_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/pending_mutation_store.dart';
import 'package:vetti_flow_1_0/data/repositories/product_catalog_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_order_repository.dart';

/// Implementação de [OpRepository] que projeta o [ProductionFlowStore] (fonte
/// única, compartilhada com as telas de operador e a TV) no modelo de view
/// [OrdemProducao] usado pelo dashboard, e roteia as ações de volta ao store.
class FlowOpRepository implements OpRepository {
  FlowOpRepository(
    this._store, {
    required ProductCatalogRepository catalog,
    required ProtheusOrderRepository protheusOrders,
    required EmpenhoRepository empenhos,
    required PendingMutationStore pendingMutations,
    required String Function() filial,
  }) // `this._catalog` e `this._filial` exporiam o nome privado do campo na
    // chamada.
    // ignore: prefer_initializing_formals
    : _catalog = catalog,
       _protheus = protheusOrders,
       // ignore: prefer_initializing_formals
       _empenhos = empenhos,
       // ignore: prefer_initializing_formals
       _pendingMutations = pendingMutations,
       // ignore: prefer_initializing_formals
       _filial = filial;

  final ProductionFlowStore _store;
  final ProductCatalogRepository _catalog;

  /// Fonte das OPs. O VettiFlow lê daqui; quem cria OP é o Protheus.
  final ProtheusOrderRepository _protheus;

  /// O empenho real (SD4) de uma OP — usado para saber a razão de consumo de
  /// cada componente quando a OP produz.
  final EmpenhoRepository _empenhos;

  /// Onde a baixa de produção entra na fila, junto com as outras mutações.
  final PendingMutationStore _pendingMutations;

  /// A filial em que se está operando, lida a cada chamada.
  ///
  /// É função e não valor porque o operador troca de filial pela barra
  /// superior: guardar o valor no construtor congelaria a lista na filial em
  /// que o app abriu.
  final String Function() _filial;

  static const _meses = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];

  // ── Leitura ────────────────────────────────────────────────────────────

  @override
  Future<List<OrdemProducao>> fetchOrdens() async {
    final all = [..._store.activeOrders, ..._store.recentCompleted];
    return all.map(_toOrdem).toList();
  }

  @override
  Future<List<OrdemArmazenada>> fetchOrdensArmazenadas() async {
    return _store
        .ordersAtStage(ProductionStage.storage)
        .map(
          (order) => OrdemArmazenada(
            numero: order.number,
            produto: order.productLabel,
            quantidadeOriginal: order.quantity,
            quantidadeArmazenada: order.storedQuantity,
            responsavel: _responsavel(order),
            data: _fmtDate(order.updatedAt),
          ),
        )
        .toList();
  }

  @override
  Future<List<Responsavel>> fetchResponsaveis() async => Responsavel.todos;

  @override
  Future<List<OrdemDisponivel>> fetchOrdensDisponiveis() async {
    final adotadas = _store.adoptedKeys;
    return _protheus
        .openIn(_filial())
        .where((op) => !adotadas.contains(op.key))
        .map(
          (op) => OrdemDisponivel(
            numero: op.displayNumber,
            numeroLegivel: op.numeroLegivel,
            produtoCodigo: op.productCode,
            produto:
                _catalog.findByCode(op.productCode)?.label ?? op.productCode,
            quantidade: op.quantity,
            previsao: op.dueAt,
          ),
        )
        .toList();
  }

  // ── Ações ──────────────────────────────────────────────────────────────

  @override
  Future<OrdemProducao> adotarOrdem(AdocaoOrdemDTO dto) async {
    final filial = _filial();
    final source = _protheus.openIn(filial).firstWhere(
      (op) => op.displayNumber == dto.numero,
      orElse: () => throw ArgumentError.value(
        dto.numero,
        'numero',
        'OP não está em aberto no Protheus para a filial $filial',
      ),
    );
    final order = _store.adoptOrder(
      source,
      priority: dto.prioridade,
      responsavel: dto.responsavel,
    );
    return _toOrdem(order);
  }

  @override
  Future<void> avancarStatus(
    String numero, {
    int quantidadeArmazenada = 0,
  }) async {
    final order = _find(numero);
    if (order == null) return;
    if (order.currentStage == ProductionStage.expedition) {
      _store.completeExpedition(numero, storedQuantity: quantidadeArmazenada);
      _enfileirarBaixaProducao(order);
    } else {
      _store.completeStage(numero);
    }
  }

  /// Aponta a produção desta OP no Protheus: entrada do produto acabado e
  /// consumo dos componentes, proporcional ao empenho real da OP.
  ///
  /// Até 03/08/2026 o VettiFlow terminava a expedição sem escrever nada de
  /// volta — `SC2.C2_QUJE` e o consumo real de componente (SD3) nunca
  /// refletiam a produção. Dispara só aqui: é o único ponto do fluxo que
  /// corresponde a "produção terminou" no sentido do Protheus, já que etapas
  /// internas (solda, mecânica) não têm contrapartida real lá.
  ///
  /// Silencioso quando falta contexto para apontar algo de verdade: OP sem
  /// vínculo com o Protheus (criada localmente antes da integração), sem
  /// nenhuma quantidade fechada, ou cujo empenho não tem para onde ratear.
  void _enfileirarBaixaProducao(ProductionOrderFlow order) {
    if (order.closedQuantity <= 0) return;
    final key = order.protheusKey;
    if (key == null) return;

    final filial = _filial();
    final protheusOrder = _protheus.byKey(key);
    if (protheusOrder == null || protheusOrder.quantity <= 0) return;

    final op = key.opConcatenada;
    final base = _empenhos.byOp(op, filial: filial);
    final efetivo = _pendingMutations.empenhosEfetivos(op, base);

    final componentes = [
      for (final e in efetivo)
        BaixaComponente(
          produto: e.produto,
          local: e.local,
          // Proporcional ao empenho **real** da OP (D4_QTDEORI ÷ C2_QUANT),
          // não à estrutura padrão do produto — respeita ajustes que a
          // Gestora já fez no empenho. Uma linha incluída pela fila e ainda
          // sem D4_QTDEORI (nunca existiu na SD4 real) usa a própria
          // quantidade como razão: não há histórico anterior para ratear.
          quantidade:
              order.closedQuantity *
              (e.quantidadeOriginal ?? e.quantidade) /
              protheusOrder.quantity,
        ),
    ];
    if (componentes.isEmpty) return;

    _pendingMutations.enqueue(
      (id, agora) => BaixaProducaoMutation(
        id: id,
        filial: filial,
        criadoEm: agora,
        autor: _responsavel(order),
        op: op,
        produto: order.productCode,
        produtoDescricao: order.productName,
        quantidadeProduzida: order.closedQuantity,
        localProducao: protheusOrder.localProducao,
        componentes: componentes,
      ),
    );
  }

  @override
  Future<void> voltarStatus(String numero) async {
    _store.regressStage(numero);
  }

  @override
  Future<void> cancelarOrdem(String numero) async {
    _store.cancelOrder(numero);
  }

  // ── Mapeamento ProductionOrderFlow → OrdemProducao ─────────────────────

  OrdemProducao _toOrdem(ProductionOrderFlow order) {
    final status = _statusFrom(order);
    final finalizada = status == StatusOP.finalizada;
    return OrdemProducao(
      numero: order.number,
      produto: order.productLabel,
      qtd: order.quantity,
      responsavel: _responsavel(order),
      dataAbertura: _fmtDate(order.createdAt),
      prazo: order.prazo ?? '—',
      status: status,
      progresso: _progresso(order, finalizada),
      mes: _meses[order.createdAt.month - 1],
      atrasada: _atrasada(order.prazo, finalizada),
      prioridade: order.priority,
      stage: order.currentStage,
      materiais: _store
          .catalogItem(order.productCode)
          .components
          .map((c) => (c.description, c.quantity))
          .toList(),
    );
  }

  StatusOP _statusFrom(ProductionOrderFlow order) {
    if (order.currentStage == ProductionStage.completed ||
        order.currentStage == ProductionStage.storage) {
      return StatusOP.finalizada;
    }
    final started = order.timings.values.any((t) => t.startedAt != null);
    if (order.status == ProductionRunStatus.active ||
        order.status == ProductionRunStatus.paused ||
        order.currentStage != ProductionStage.warehouse ||
        started) {
      return StatusOP.emAndamento;
    }
    return StatusOP.naoIniciada;
  }

  int _progresso(ProductionOrderFlow order, bool finalizada) {
    if (finalizada) return 100;
    final total = ProductionStage.productionFlow.length;
    return (order.currentStage.progressIndex / total * 100).round();
  }

  String _responsavel(ProductionOrderFlow order) {
    final resp = order.responsavel;
    if (resp != null && resp.isNotEmpty) return resp;
    final op = order.operatorName;
    if (op != null && op.isNotEmpty) return op;
    return '—';
  }

  bool _atrasada(String? prazo, bool finalizada) {
    if (finalizada || prazo == null) return false;
    final parts = prazo.split('/');
    if (parts.length != 3) return false;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return false;
    return DateTime(y, m, d).isBefore(DateTime.now());
  }

  ProductionOrderFlow? _find(String numero) {
    for (final order in [..._store.activeOrders, ..._store.recentCompleted]) {
      if (order.number == numero) return order;
    }
    return null;
  }

  String _fmtDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }
}
