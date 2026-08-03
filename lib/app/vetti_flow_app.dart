import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/app/app_routes.dart';
import 'package:vetti_flow_1_0/data/repositories/empenho_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/filial_store.dart';
import 'package:vetti_flow_1_0/data/repositories/flow_op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/mutation_sync_service.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/pending_mutation_store.dart';
import 'package:vetti_flow_1_0/data/repositories/product_catalog_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_order_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_sync_client.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_repository.dart';
import 'package:vetti_flow_1_0/shared/theme/app_theme.dart';

class VettiFlowApp extends StatelessWidget {
  const VettiFlowApp({
    super.key,
    required this.catalog,
    required this.protheusOrders,
    required this.warehouses,
    required this.empenhos,
    required this.apiBaseUrl,
  });

  /// Produtos, estrutura e saldo por armazém — SB1/SG1/SB2 no Protheus.
  final ProductCatalogRepository catalog;

  /// Ordens de produção — SC2. Retrato: o dono da OP continua sendo o ERP.
  final ProtheusOrderRepository protheusOrders;

  /// Almoxarifados — NNR.
  final WarehouseRepository warehouses;

  /// Empenhos das OPs em aberto — SD4.
  final EmpenhoRepository empenhos;

  /// Raiz da API que leva a fila de mutações ao Protheus.
  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // As origens de dados do Protheus chegam prontas de fora. Hoje são as
        // implementações que leem o recorte do banco migrado; trocar por
        // implementações que falam com a API não exige mudar tela nenhuma.
        RepositoryProvider<ProductCatalogRepository>.value(value: catalog),
        RepositoryProvider<ProtheusOrderRepository>.value(
          value: protheusOrders,
        ),
        RepositoryProvider<WarehouseRepository>.value(value: warehouses),
        RepositoryProvider<EmpenhoRepository>.value(value: empenhos),
        ChangeNotifierProvider<ProductionFlowStore>(
          create: (context) => ProductionFlowStore(
            catalog: context.read<ProductCatalogRepository>(),
          ),
        ),
        ChangeNotifierProvider<FilialStore>(
          create: (_) => FilialStore(),
        ),
        ChangeNotifierProvider<PendingMutationStore>(
          create: (_) => PendingMutationStore(),
        ),
        RepositoryProvider<ProtheusSyncClient>(
          create: (_) => ProtheusSyncClient(baseUrl: apiBaseUrl),
          dispose: (client) => client.dispose(),
        ),
        ChangeNotifierProvider<MutationSyncService>(
          create: (context) => MutationSyncService(
            store: context.read<PendingMutationStore>(),
            client: context.read<ProtheusSyncClient>(),
          ),
        ),
        ChangeNotifierProvider<OperatorAssignmentStore>(
          create: (_) => OperatorAssignmentStore(),
        ),
        RepositoryProvider<OpRepository>(
          create: (context) {
            // A filial entra como leitura tardia, não como valor: o operador
            // troca de filial na barra superior e a lista de OPs precisa
            // acompanhar sem recriar o repositório.
            final filiais = context.read<FilialStore>();
            return FlowOpRepository(
              context.read<ProductionFlowStore>(),
              catalog: context.read<ProductCatalogRepository>(),
              protheusOrders: context.read<ProtheusOrderRepository>(),
              filial: () => filiais.filial,
            );
          },
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'VettiFlow 1.0',
        theme: AppTheme.light,
        initialRoute: '/login',
        routes: vettiFlowRoutes(),
      ),
    );
  }
}
