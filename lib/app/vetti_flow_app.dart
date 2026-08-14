import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/app/app_routes.dart';
import 'package:vetti_flow_1_0/data/repositories/flow_op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/mutation_sync_service.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/pending_mutation_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_database.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_order_publisher.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_connection_store.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_product_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_sync_client.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_request_database.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_request_store.dart';
import 'package:vetti_flow_1_0/shared/theme/app_theme.dart';

class VettiFlowApp extends StatelessWidget {
  const VettiFlowApp({super.key});

  static const _apiBaseUrl = String.fromEnvironment(
    'VETTIFLOW_API_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const _apiToken = String.fromEnvironment('VETTIFLOW_API_TOKEN');

  static const _connectionMode = String.fromEnvironment(
    'VETTIFLOW_PROTHEUS_CONNECTION_MODE',
  );

  static const _allowDirectPostgresFallback = bool.fromEnvironment(
    'VETTIFLOW_ALLOW_DIRECT_POSTGRES_FALLBACK',
    defaultValue: true,
  );

  static ProtheusConnectionMode _initialConnectionMode() {
    if (_connectionMode.trim().isNotEmpty) {
      return protheusConnectionModeFromName(_connectionMode);
    }
    if (!_allowDirectPostgresFallback) return ProtheusConnectionMode.fastApi;
    return ProtheusConnectionMode.automatic;
  }

  static bool _useDirectPostgres() =>
      _allowDirectPostgresFallback &&
      _initialConnectionMode() != ProtheusConnectionMode.fastApi;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ProductionFlowDatabase>(
          create: (_) => _useDirectPostgres()
              ? PostgresProductionFlowDatabase()
              : const EmptyProductionFlowDatabase(),
        ),
        // A fila de mutacoes nasce antes do fluxo de producao: abrir OP ja
        // manda para o Protheus, entao o store precisa do publicador pronto.
        ChangeNotifierProvider<PendingMutationStore>(
          create: (_) => PendingMutationStore(),
        ),
        Provider<ProtheusSyncClient>(
          create: (_) =>
              ProtheusSyncClient(baseUrl: _apiBaseUrl, apiToken: _apiToken),
          dispose: (_, client) => client.dispose(),
        ),
        ChangeNotifierProvider<MutationSyncService>(
          create: (context) => MutationSyncService(
            store: context.read<PendingMutationStore>(),
            client: context.read<ProtheusSyncClient>(),
          ),
        ),
        ChangeNotifierProvider<ProductionFlowStore>(
          create: (context) => ProductionFlowStore(
            database: context.read<ProductionFlowDatabase>(),
            protheusPublisher: MutationProtheusOrderPublisher(
              mutations: context.read<PendingMutationStore>(),
              sync: context.read<MutationSyncService>(),
            ),
          ),
        ),
        ChangeNotifierProvider<OperatorAssignmentStore>(
          create: (_) => OperatorAssignmentStore(),
        ),
        ChangeNotifierProvider<ProtheusConnectionStore>(
          create: (_) =>
              ProtheusConnectionStore(initialMode: _initialConnectionMode()),
        ),
        ChangeNotifierProvider<WarehouseRequestStore>(
          create: (_) => WarehouseRequestStore(
            database: _useDirectPostgres()
                ? PostgresWarehouseRequestDatabase()
                : const EmptyWarehouseRequestDatabase(),
          ),
        ),
        ProxyProvider<ProtheusConnectionStore, ProtheusProductRepository>(
          update: (_, connection, _) {
            final apiRepository = ApiProtheusProductRepository(
              baseUrl: _apiBaseUrl,
              apiToken: _apiToken,
            );
            switch (connection.mode) {
              case ProtheusConnectionMode.fastApi:
                return apiRepository;
              case ProtheusConnectionMode.localPostgres:
                return PostgresProtheusProductRepository();
              case ProtheusConnectionMode.automatic:
                return ApiFirstProtheusProductRepository(
                  primary: apiRepository,
                  fallback: PostgresProtheusProductRepository(),
                );
            }
          },
        ),
        ProxyProvider3<
          ProductionFlowStore,
          ProtheusProductRepository,
          WarehouseRequestStore,
          OpRepository
        >(
          update: (_, flowStore, protheusProducts, warehouseRequests, _) =>
              FlowOpRepository(
                flowStore,
                protheusProducts: protheusProducts,
                warehouseRequests: warehouseRequests,
              ),
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
