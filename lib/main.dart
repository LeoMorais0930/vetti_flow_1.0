import 'package:flutter/material.dart';
import 'package:vetti_flow_1_0/app/vetti_flow_app.dart';
import 'package:vetti_flow_1_0/data/repositories/empenho_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/product_catalog_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_order_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_repository.dart';

/// Endereço da API que transporta a fila de mutações até o Protheus.
///
/// Sobrescrevível na build para apontar para o servidor de verdade:
/// `flutter run --dart-define=VETTI_API=http://10.0.0.5:8000`
const _apiBaseUrl = String.fromEnvironment(
  'VETTI_API',
  defaultValue: 'http://localhost:8000',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Os dados do Protheus são carregados uma vez, no arranque. Fazer isso aqui
  // evita espalhar estado de carregamento pelas telas, que hoje não sabem
  // lidar com isso.
  final catalog = await AssetProductCatalogRepository.load();
  final protheusOrders = AssetProtheusOrderRepository(
    await AssetProtheusOrderRepository.loadOrders(),
    descriptions: catalog.descriptions,
  );
  final warehouses = await AssetWarehouseRepository.load();
  final empenhos = await AssetEmpenhoRepository.load();

  runApp(
    VettiFlowApp(
      catalog: catalog,
      protheusOrders: protheusOrders,
      warehouses: warehouses,
      empenhos: empenhos,
      apiBaseUrl: _apiBaseUrl,
    ),
  );
}
