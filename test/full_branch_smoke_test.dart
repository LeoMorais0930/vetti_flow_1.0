import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/app/app_routes.dart';
import 'package:vetti_flow_1_0/data/models/ordem_producao.dart';
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/models/protheus_product_lookup.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/responsavel.dart';
import 'package:vetti_flow_1_0/data/models/warehouse_request.dart';
import 'package:vetti_flow_1_0/data/repositories/mutation_sync_service.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_order_publisher.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/pending_mutation_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_connection_store.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_sync_client.dart';
import 'package:vetti_flow_1_0/data/repositories/warehouse_request_store.dart';
import 'package:vetti_flow_1_0/shared/theme/app_theme.dart';

void main() {
  testWidgets(
    'branch smoke: Tatiane creates an OP, Vera reviews cancelation and queue stays visible',
    (tester) async {
      await _setViewport(tester, const Size(1366, 768));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = _FullSmokeRepository();
      final queue = PendingMutationStore()
        ..enqueue(
          (id, criadoEm) => TransferenciaMutation(
            id: id,
            filial: '04',
            criadoEm: criadoEm,
            autor: 'Tatiane',
            produto: '100-010',
            produtoDescricao: 'PARAFUSO 2,9 X 6,5 MM ZI',
            quantidade: 12,
            localOrigem: '01',
            localDestino: '05',
            op: 'OP-TESTE-FILA',
          ),
        );
      final client = ProtheusSyncClient(baseUrl: 'http://localhost:8000');
      addTearDown(client.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ProductionFlowStore>(
              create: (_) => ProductionFlowStore(seedOrders: const []),
            ),
            ChangeNotifierProvider<OperatorAssignmentStore>(
              create: (_) => OperatorAssignmentStore(),
            ),
            ChangeNotifierProvider<ProtheusConnectionStore>(
              create: (_) => ProtheusConnectionStore(),
            ),
            ChangeNotifierProvider<WarehouseRequestStore>(
              create: (_) => WarehouseRequestStore(
                seedRequests: const <WarehouseConfirmationRequest>[],
              ),
            ),
            ChangeNotifierProvider<PendingMutationStore>.value(value: queue),
            ChangeNotifierProvider<MutationSyncService>(
              create: (_) => MutationSyncService(store: queue, client: client),
            ),
            RepositoryProvider<OpRepository>.value(value: repository),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            initialRoute: '/login',
            routes: vettiFlowRoutes(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _login(tester, user: 'tatiane', password: '1001');

      expect(find.text('Painel de Produção'), findsOneWidget);
      expect(find.byTooltip('1 aguardando envio ao Protheus'), findsOneWidget);

      await tester.tap(find.byTooltip('1 aguardando envio ao Protheus'));
      await tester.pumpAndSettle();

      expect(find.text('Fila do Protheus'), findsOneWidget);
      expect(find.text('Aguardando envio para a API'), findsOneWidget);
      expect(find.textContaining('Transferir - 100-010'), findsOneWidget);

      Navigator.of(tester.element(find.text('Fila do Protheus'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Nova OP'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('nova-op-product-code')),
        '730-0863',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('nova-op-quantity')), '12');
      await tester.ensureVisible(find.byKey(const Key('nova-op-operator-pin')));
      await tester.enterText(
        find.byKey(const Key('nova-op-operator-pin')),
        '1001',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Criar OP').last);
      await tester.pumpAndSettle();

      expect(repository.createdDtos, hasLength(1));
      expect(repository.createdDtos.single.productCode, '730-0863');
      expect(repository.createdDtos.single.openedBy, 'Tatiane');
      expect(repository.createdDtos.single.operatorPin, '1001');
      expect(find.text('OP-2026-9000'), findsOneWidget);

      await tester.tap(find.byTooltip('Sair'));
      await tester.pumpAndSettle();

      await _login(tester, user: 'vera', password: '1005');

      expect(find.text('Painel de Produção'), findsOneWidget);
      expect(find.text('OP-2026-9000'), findsOneWidget);

      await tester.tap(find.text('OP-2026-9000'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar OP'));
      await tester.pumpAndSettle();

      expect(find.text('Cancelar OP e devolver empenhos'), findsOneWidget);
      expect(find.text('Retorno por item'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('cancel-op-operator-pin')),
      );
      await tester.enterText(
        find.byKey(const Key('cancel-op-operator-pin')),
        '1005',
      );
      await tester.ensureVisible(find.text('Confirmar cancelamento'));
      await tester.tap(find.text('Confirmar cancelamento'));
      await tester.pumpAndSettle();

      expect(repository.canceledNumbers, ['OP-2026-9000']);
      expect(repository.cancelOperatorName, 'Vera');
      expect(repository.cancelOperatorPin, '1005');
      expect(repository.cancelReturnWarehouses['100-010'], '05');
      expect(find.text('OP-2026-9000'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Vitor API client sends queued mutations and reads stored result',
    () async {
      final mutation = TransferenciaMutation(
        id: 'vf-test-1',
        filial: '04',
        criadoEm: DateTime(2026, 8, 5, 9),
        autor: 'Tatiane',
        produto: '100-010',
        produtoDescricao: 'PARAFUSO 2,9 X 6,5 MM ZI',
        quantidade: 12,
        localOrigem: '01',
        localDestino: '05',
        op: 'OP-2026-9000',
      );

      final client = ProtheusSyncClient(
        baseUrl: 'http://api.test',
        apiToken: 'segredo-teste',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/mutations');
          expect(request.headers['X-API-Token'], 'segredo-teste');

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final mutations = body['mutations'] as List<dynamic>;
          expect(mutations, hasLength(1));
          expect(mutations.single['id'], 'vf-test-1');
          expect(mutations.single['kind'], 'transferencia');

          return http.Response(
            jsonEncode({
              'results': [
                {
                  'id': 'vf-test-1',
                  'status': 'armazenado',
                  'protheusRef': 'MUT-0001',
                },
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(client.dispose);

      final results = await client.push([mutation]);

      expect(results, hasLength(1));
      expect(results.single.id, 'vf-test-1');
      expect(results.single.status, MutationStatus.armazenado);
      expect(results.single.protheusRef, 'MUT-0001');
    },
  );
}

Future<void> _login(
  WidgetTester tester, {
  required String user,
  required String password,
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), user);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
  await tester.pumpAndSettle();
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
}

class _FullSmokeRepository implements OpRepository {
  final createdDtos = <NovaOrdemDTO>[];
  final canceledNumbers = <String>[];
  String? cancelOperatorName;
  String? cancelOperatorPin;
  Map<String, String> cancelReturnWarehouses = const {};
  var _nextNumber = 9000;

  final _orders = <OrdemProducao>[
    const OrdemProducao(
      numero: 'OP-2026-8000',
      produto: '730-0001 - OP EXISTENTE PARA CONTROLE',
      qtd: 20,
      responsavel: 'Vera',
      dataAbertura: '05/08/2026',
      prazo: '05/08/2026',
      status: StatusOP.aAbrir,
      progresso: 0,
      mes: 'ago',
      armazem: '01',
      stage: ProductionStage.warehouse,
    ),
  ];

  @override
  Future<List<OrdemProducao>> fetchOrdens() async => List.unmodifiable(_orders);

  @override
  Future<List<OrdemArmazenada>> fetchOrdensArmazenadas() async => const [];

  @override
  Future<List<Responsavel>> fetchResponsaveis() async => Responsavel.todos;

  @override
  Future<List<String>> fetchProdutos() async => [
    '730-0863 - SMART ALARM - MONITORADA CENTRAL',
    for (final order in _orders) order.produto,
  ];

  @override
  Future<List<ProtheusProduct>> searchProdutos(String query) async {
    if (!'730-0863 - SMART ALARM - MONITORADA CENTRAL'.toLowerCase().contains(
      query.toLowerCase(),
    )) {
      return const [];
    }
    return const [
      ProtheusProduct(
        filial: '04',
        code: '730-0863',
        description: 'SMART ALARM - MONITORADA CENTRAL',
        type: 'PA',
        unit: 'PC',
        group: '730',
      ),
    ];
  }

  @override
  Future<ProtheusProductLookup?> lookupProdutoPorCodigo(String code) async {
    if (code.trim().toUpperCase() != '730-0863') return null;
    return const ProtheusProductLookup(
      filial: '04',
      armazem: '05',
      product: ProtheusProduct(
        filial: '04',
        code: '730-0863',
        description: 'SMART ALARM - MONITORADA CENTRAL',
        type: 'PA',
        unit: 'PC',
        group: '730',
      ),
      components: [
        ProtheusProductComponent(
          filial: '04',
          armazem: '01',
          code: '100-010',
          description: 'PARAFUSO 2,9 X 6,5 MM ZI',
          quantityPerUnit: 1,
          unit: 'PC',
          stockAvailable: 200,
          currentStock: 200,
          committedQuantity: 0,
          warehouseBalances: [
            ProtheusWarehouseBalance(
              filial: '04',
              armazem: '01',
              currentStock: 200,
              committedQuantity: 0,
              reservedQuantity: 0,
              availableQuantity: 200,
            ),
            ProtheusWarehouseBalance(
              filial: '04',
              armazem: '05',
              currentStock: 30,
              committedQuantity: 0,
              reservedQuantity: 0,
              availableQuantity: 30,
            ),
          ],
        ),
        ProtheusProductComponent(
          filial: '04',
          armazem: '05',
          code: 'MOD-001',
          description: 'MAO DE OBRA',
          quantityPerUnit: 1,
          unit: 'HR',
          stockAvailable: -1,
          currentStock: -1,
          committedQuantity: 0,
        ),
      ],
      smdReleaseOrders: [
        ProtheusChildOrder(
          number: 'OP-SMD-001',
          productCode: '575-0845',
          productDescription: 'SUB MEC SMART MODULO SIRENE SF',
          plannedQuantity: 100,
          producedQuantity: 100,
          status: 'FINALIZADA',
        ),
      ],
    );
  }

  @override
  ProtheusPublishOutcome? get ultimoEnvioProtheus => null;

  @override
  Future<OrdemProducao> criarOrdem(NovaOrdemDTO dto) async {
    createdDtos.add(dto);
    final number = 'OP-2026-${_nextNumber.toString().padLeft(4, '0')}';
    _nextNumber++;
    final order = OrdemProducao(
      numero: number,
      produto: dto.produto,
      qtd: dto.qtd,
      responsavel: '—',
      dataAbertura: '05/08/2026',
      prazo: dto.prazo ?? '—',
      status: StatusOP.aAbrir,
      progresso: 0,
      mes: 'ago',
      prioridade: dto.prioridade,
      armazem: dto.armazem,
      stage: ProductionStage.warehouse,
      materiais: [
        for (final component in dto.components)
          (component.description, component.quantityPerUnit.round()),
      ],
      materiaisDetalhados: [
        for (final component in dto.components)
          MaterialOpDetalhe(
            codigo: component.code,
            descricao: component.description,
            quantidadePorUnidade: component.quantityPerUnit.round(),
            quantidadeTotal: (component.quantityPerUnit * dto.qtd).round(),
            filial: component.filial,
            armazem: component.armazem,
            movimentaEstoque: !component.code.toUpperCase().startsWith('MOD'),
          ),
      ],
    );
    _orders.insert(0, order);
    return order;
  }

  @override
  Future<void> cancelarOrdem(
    String numero, {
    Map<String, String> returnWarehouses = const {},
    String? operatorName,
    String? operatorPin,
  }) async {
    canceledNumbers.add(numero);
    cancelOperatorName = operatorName;
    cancelOperatorPin = operatorPin;
    cancelReturnWarehouses = Map.of(returnWarehouses);
    _orders.removeWhere((order) => order.numero == numero);
  }

  @override
  Future<void> avancarStatus(
    String numero, {
    int quantidadeArmazenada = 0,
    String? operatorName,
    String? operatorPin,
  }) async {}

  @override
  Future<void> voltarStatus(String numero) async {}

  @override
  Future<void> atualizarRota(
    String numero,
    List<ProductionStage> stages,
  ) async {
    final index = _orders.indexWhere((order) => order.numero == numero);
    if (index < 0) return;
    _orders[index] = _orders[index].copyWith(plannedStages: stages);
  }
}
