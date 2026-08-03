import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/app/vetti_flow_app.dart';
import 'package:vetti_flow_1_0/data/repositories/empenho_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/product_catalog_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_order_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_sync_client.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_repository.dart';

/// Endereço da API que transporta a fila de mutações até o Protheus — e,
/// desde 03/08/2026, também a leitura ao vivo de OPs abertas, empenho e
/// saldo.
///
/// Sobrescrevível na build para apontar para o servidor de verdade:
/// `flutter run --dart-define=VETTI_API=http://10.0.0.5:8000`
const _apiBaseUrl = String.fromEnvironment(
  'VETTI_API',
  defaultValue: 'http://localhost:8000',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Os três repositórios híbridos (catálogo, OPs, empenho) são ChangeNotifier
  // por dentro — é o que faz o refresh ao vivo reconstruir tela — mas
  // continuam registrados também pela interface de sempre (`ProductCatalogRepository`
  // etc.), sem isso as ~20 telas que já leem por ali teriam que mudar. O
  // `provider` recusa em runtime um valor Listenable exposto fora de
  // ChangeNotifierProvider/ListenableProvider, achando que é engano — aqui é
  // de propósito: o registro concreto (reativo) e o de interface (estável)
  // apontam para a mesma instância em `vetti_flow_app.dart`. Como
  // `ProductCatalogRepository`/`ProtheusOrderRepository`/`EmpenhoRepository`
  // são interfaces simples, não `ChangeNotifier`, não dá para usar
  // `ChangeNotifierProvider<Interface>` diretamente — exigiria toda
  // implementação (inclusive os testes) virar ChangeNotifier só por causa
  // disso. Desligar a checagem é o próprio escape hatch documentado pelo
  // pacote para este caso.
  Provider.debugCheckInvalidValueType = null;

  // O cliente nasce aqui, não dentro do widget: os repositórios híbridos
  // (OPs, empenho, saldo) precisam dele já no arranque para poder atualizar
  // ao vivo depois — não é só a fila de mutações que o usa.
  final syncClient = ProtheusSyncClient(baseUrl: _apiBaseUrl);

  // O retrato embarcado continua sendo a reserva: se a API estiver fora do
  // alcance quando a tela pedir uma atualização, é para este retrato que os
  // repositórios híbridos voltam — o chão de fábrica não pode parar de
  // funcionar por falta de rede.
  final catalogItems = AssetProductCatalogRepository.parse(
    await rootBundle.loadString(AssetProductCatalogRepository.assetPath),
  );
  final catalog = HybridProductCatalogRepository(
    catalogItems,
    client: syncClient,
  );

  final protheusOrders = HybridProtheusOrderRepository(
    await AssetProtheusOrderRepository.loadOrders(),
    client: syncClient,
    descriptions: catalog.descriptions,
  );

  final empenhoLinhas = AssetEmpenhoRepository.parse(
    await rootBundle.loadString(AssetEmpenhoRepository.assetPath),
  );
  final empenhos = HybridEmpenhoRepository(empenhoLinhas, client: syncClient);

  final warehouses = await AssetWarehouseRepository.load();

  runApp(
    VettiFlowApp(
      catalog: catalog,
      protheusOrders: protheusOrders,
      warehouses: warehouses,
      empenhos: empenhos,
      syncClient: syncClient,
    ),
  );
}
