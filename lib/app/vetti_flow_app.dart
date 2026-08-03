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
    required this.syncClient,
  });

  /// Produtos e estrutura são estáticos (SB1/SG1); o saldo (SB2) atualiza ao
  /// vivo produto a produto — ver [HybridProductCatalogRepository.refreshSaldo].
  final HybridProductCatalogRepository catalog;

  /// Ordens de produção — SC2. O dono da OP continua sendo o ERP; a lista de
  /// abertas atualiza ao vivo — ver [HybridProtheusOrderRepository.refresh].
  final HybridProtheusOrderRepository protheusOrders;

  /// Almoxarifados — NNR. Cadastro puro, não muda: continua estático.
  final WarehouseRepository warehouses;

  /// Empenhos das OPs em aberto — SD4, ao vivo por OP — ver
  /// [HybridEmpenhoRepository.refresh].
  final HybridEmpenhoRepository empenhos;

  /// Cliente da API — leva a fila de mutações e traz a leitura ao vivo.
  /// Construído em `main.dart` porque os repositórios híbridos já precisam
  /// dele antes da árvore de widgets existir.
  final ProtheusSyncClient syncClient;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Registrados nos dois tipos: pela interface, para os ~20 pontos de
        // tela que já leem `context.read<ProtheusOrderRepository>()` etc. sem
        // saber que agora existe atualização ao vivo; e pelo tipo concreto,
        // para quem precisa de `context.watch<HybridX>()` reagir ao refresh.
        // É a mesma instância nos dois — chamar refresh() atualiza os dois
        // lados juntos.
        ChangeNotifierProvider<HybridProductCatalogRepository>.value(
          value: catalog,
        ),
        RepositoryProvider<ProductCatalogRepository>.value(value: catalog),
        ChangeNotifierProvider<HybridProtheusOrderRepository>.value(
          value: protheusOrders,
        ),
        RepositoryProvider<ProtheusOrderRepository>.value(
          value: protheusOrders,
        ),
        RepositoryProvider<WarehouseRepository>.value(value: warehouses),
        ChangeNotifierProvider<HybridEmpenhoRepository>.value(value: empenhos),
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
        RepositoryProvider<ProtheusSyncClient>.value(value: syncClient),
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
              empenhos: context.read<EmpenhoRepository>(),
              pendingMutations: context.read<PendingMutationStore>(),
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
