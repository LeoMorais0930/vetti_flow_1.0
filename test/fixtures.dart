import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/protheus_order.dart';
import 'package:vetti_flow_1_0/data/models/warehouse.dart';
import 'package:vetti_flow_1_0/data/repositories/product_catalog_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_order_repository.dart';

/// Recorte pequeno de dados reais do Protheus da Vetti, para os testes não
/// dependerem do asset completo (15.318 OPs) nem de dado inventado.
///
/// Códigos, descrições e o formato da chave são os do ambiente real: filial
/// `04`, número de 6 dígitos, item de 2 e sequência de 3.
class TestCatalog implements ProductCatalogRepository {
  TestCatalog();

  static const _componentes = [
    ProductionComponent(
      code: '200-052',
      description: 'TAMPA SUPERIOR SMART CENTRAL',
      quantity: 1,
      stock: 1720,
    ),
    ProductionComponent(
      code: 'MOD08010201005',
      description: 'MAO DE OBRA MONTAGEM',
      // Fracionária de propósito: é assim que a estrutura do Protheus rateia.
      quantity: 0.001348,
      stock: 0,
    ),
  ];

  static const _items = [
    ProductionCatalogItem(
      code: '203-002',
      name: 'CX PLASTICA SMART CENTRAL VETTI COMPLETA',
      unit: 'PC',
      type: 'PI',
      group: '203',
      stock: 1720,
      committed: 1052,
      components: _componentes,
    ),
    ProductionCatalogItem(
      code: '730-0863',
      name: 'SMART CENTRAL VETTI',
      unit: 'PC',
      type: 'PA',
      group: '730',
      stock: 40,
      committed: 0,
    ),
    ProductionCatalogItem(
      code: '575-0863',
      name: 'PLACA SMART CENTRAL',
      unit: 'PC',
      type: 'PI',
      group: '575',
      stock: 300,
      committed: 12,
    ),
    // Bloqueado no Protheus (B1_MSBLQL = '1'): existe no cadastro, mas o ERP
    // recusa movimentar. Compartilha o prefixo `730-0` com o liberado acima,
    // para o teste do filtro exercitar uma busca que casa com os dois.
    ProductionCatalogItem(
      code: '730-0500',
      name: 'SMART CENTRAL VETTI GERACAO ANTERIOR',
      unit: 'PC',
      type: 'PA',
      group: '730',
      stock: 8,
      blocked: true,
    ),
  ];

  @override
  List<ProductionCatalogItem> get items => _items;

  @override
  ProductionCatalogItem? findByCode(String code) {
    for (final item in _items) {
      if (item.code == code) return item;
    }
    return null;
  }

  @override
  ProductionCatalogItem requireByCode(String code) {
    final item = findByCode(code);
    if (item == null) throw ProductNotFoundException(code);
    return item;
  }

  @override
  Map<String, String> get descriptions => {
    for (final item in _items) item.code: item.name,
  };
}

/// Almoxarifados reais da Vetti (NNR), no recorte que os testes usam.
List<Armazem> testArmazens() => const [
  Armazem(codigo: '01', descricao: 'ALMOXARIFADO'),
  Armazem(codigo: '03', descricao: 'PRODUCAO SMD'),
  Armazem(codigo: '05', descricao: 'PRODUCAO MEC'),
  Armazem(codigo: '10', descricao: 'EXPEDICAO'),
];

ProtheusOrder testOrder({
  required String numero,
  String produto = '730-0863',
  int quantidade = 500,
  String sequencia = '001',
  bool encerrada = false,
  String? previsao = '10/08/2026',
  String localProducao = '10',
}) {
  return ProtheusOrder(
    key: ProtheusOrderKey(
      filial: '04',
      numero: numero,
      item: '01',
      sequencia: sequencia,
    ),
    productCode: produto,
    quantity: quantidade,
    localProducao: localProducao,
    issuedAt: '29/07/2026',
    dueAt: previsao,
    closed: encerrada,
  );
}

/// Mesma OP, na outra filial de produção da Vetti.
///
/// Existe para os testes de isolamento: o Protheus numera OP **por filial**, e
/// quem opera na 04 não pode enxergar o que é da 03.
ProtheusOrder testOrderNaFilial03({
  required String numero,
  String produto = '730-0863',
  int quantidade = 500,
  bool encerrada = false,
}) {
  return ProtheusOrder(
    key: ProtheusOrderKey(
      filial: '03',
      numero: numero,
      item: '01',
      sequencia: '001',
    ),
    productCode: produto,
    quantity: quantidade,
    issuedAt: '29/07/2026',
    dueAt: '10/08/2026',
    closed: encerrada,
  );
}

/// Quatro OPs em aberto e uma encerrada, esta última para exercitar a regra
/// de somente leitura.
List<ProtheusOrder> testProtheusOrders() => [
  testOrder(numero: '015961'),
  testOrder(numero: '015960', produto: '575-0863', quantidade: 2000),
  testOrder(numero: '015958', produto: '203-002', quantidade: 300),
  testOrder(numero: '015950', quantidade: 100),
  testOrder(numero: '015900', encerrada: true),
];

AssetProtheusOrderRepository testProtheusRepository([
  List<ProtheusOrder>? orders,
]) {
  final catalog = TestCatalog();
  return AssetProtheusOrderRepository(
    orders ?? testProtheusOrders(),
    descriptions: catalog.descriptions,
  );
}

/// Números das OPs de teste, no formato colado do banco — é a **identidade**
/// da OP no app, o que vai nas chamadas ao store e nas mutações.
const opFirmware = '01596101001';
const opSoldagem = '01596001001';
const opExpedicao = '01595801001';
const opArmazenada = '01595001001';

/// Os mesmos números como a **tela** os mostra, com os traços do Protheus.
/// Ver `formatOpNumber`.
const opFirmwareLegivel = '015961-01-001';
const opSoldagemLegivel = '015960-01-001';
const opExpedicaoLegivel = '015958-01-001';
const opArmazenadaLegivel = '015950-01-001';

/// Avança uma OP pelo fluxo real até a etapa pedida.
void avancarAte(
  ProductionFlowStore store,
  String numero,
  ProductionStage destino,
) {
  while (store.orders.firstWhere((o) => o.number == numero).currentStage !=
      destino) {
    store.completeStage(numero);
  }
}

/// Store com as OPs adotadas e distribuídas pelas etapas, no lugar das OPs
/// semente que existiam antes.
///
/// Nada aqui é inventado: as OPs entram pelo caminho real de adoção e avançam
/// pelas transições reais do fluxo.
ProductionFlowStore storeComOpsAdotadas() {
  final store = ProductionFlowStore(catalog: TestCatalog());
  for (final source in testProtheusOrders().where((op) => !op.closed)) {
    store.adoptOrder(source);
  }

  avancarAte(store, opFirmware, ProductionStage.firmware);
  avancarAte(store, opSoldagem, ProductionStage.soldering);
  avancarAte(store, opExpedicao, ProductionStage.expedition);

  // Uma já armazenada, com as 100 unidades guardadas.
  avancarAte(store, opArmazenada, ProductionStage.expedition);
  store.completeExpedition(opArmazenada, storedQuantity: 100);

  // A de soldagem entra ativa: as telas de operador só mostram as ações de
  // pausar e concluir quando há sessão em andamento.
  store.startStage(opSoldagem, operatorName: 'Bryan', operatorPin: '3003');

  return store;
}
