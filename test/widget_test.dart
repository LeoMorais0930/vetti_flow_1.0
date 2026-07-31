import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/app/app_routes.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/flow_op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_order_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/product_catalog_repository.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/theme/app_theme.dart';
import 'package:vetti_flow_1_0/ui/dashboard/cubit/dashboard_cubit.dart';
import 'package:vetti_flow_1_0/ui/dashboard/dashboard_page.dart';
import 'package:vetti_flow_1_0/ui/dashboard/widgets/nova_op_dialog.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/protheus_op_picker.dart';

import 'fixtures.dart';

void main() {
  test('every work stage has a registered app route', () {
    final routes = vettiFlowRoutes();

    for (final stage in WorkStage.values) {
      expect(
        routes.keys,
        contains(stage.route),
        reason: '${stage.label} precisa abrir ${stage.route}',
      );
    }
  });

  test('dashboard operator routes to dashboard', () {
    final operator = Operator.authenticate('tatiane', '1001');

    expect(operator, isNotNull);
    expect(operator!.stage, WorkStage.dashboard);
    expect(operator.stage.route, '/dashboard');
  });

  test('tv operator routes to VettiFlow TV', () {
    final operator = Operator.authenticate('tv', '2026');

    expect(operator, isNotNull);
    expect(operator!.stage, WorkStage.tv);
    expect(operator.stage.route, '/tv');
  });

  test('coordinators and production users have real credentials', () {
    final assignments = OperatorAssignmentStore();

    final tatianeDashboard = assignments.authenticate('tatiane', '1001');
    final tatianeProduction = assignments.authenticate('tatiane', '2001');
    final sabrina = assignments.authenticate('sabrina', '3002');

    expect(tatianeDashboard, isNotNull);
    expect(tatianeDashboard!.stage, WorkStage.dashboard);
    expect(tatianeProduction, isNotNull);
    expect(tatianeProduction!.canManageAssignments, isTrue);
    expect(sabrina, isNotNull);

    assignments.assignStage('sabrina', WorkStage.firmware);
    expect(
      assignments.authenticate('sabrina', '3002')!.stage,
      WorkStage.firmware,
    );
    expect(assignments.findByPin('3002')!.stage, WorkStage.firmware);
  });

  test('assignment managers only see their own sector', () {
    final assignments = OperatorAssignmentStore();

    assignments.authenticate('tatiane', '1001');
    expect(assignments.currentManagedArea, WorkArea.production);
    expect(
      assignments.visibleAssignableOperators.every(
        (operator) => operator.area == WorkArea.production,
      ),
      isTrue,
    );
    assignments.assignStage('rose', WorkStage.firmware);
    expect(
      assignments.authenticate('rose', '4005')!.stage,
      WorkStage.warehouse,
    );

    assignments.authenticate('bruno', '1004');
    expect(assignments.currentManagedArea, WorkArea.support);
    expect(
      assignments.visibleAssignableOperators.map((operator) => operator.name),
      containsAll(['Bruno', 'Douglas', 'David', 'Vinicius', 'Matheus']),
    );

    assignments.authenticate('paula', '1003');
    expect(assignments.currentManagedArea, WorkArea.smd);
    expect(
      assignments.visibleAssignableOperators.map((operator) => operator.name),
      containsAll(['Paula', 'Leandro']),
    );

    assignments.authenticate('vera', '1005');
    expect(assignments.currentManagedArea, WorkArea.warehouse);
    expect(
      assignments.visibleAssignableOperators.map((operator) => operator.name),
      containsAll(['Vera', 'Luis', 'Rose']),
    );
  });

  test('stores a partial quantity when finishing an OP', () async {
    final store = ProductionFlowStore(catalog: TestCatalog());
    final protheus = testProtheusRepository();
    final repository = FlowOpRepository(
      store,
      catalog: TestCatalog(),
      protheusOrders: protheus,
    );
    final order = store.adoptOrder(testOrder(numero: '015961'));
    while (store.orders.first.currentStage != ProductionStage.expedition) {
      store.completeStage(order.number);
    }

    await repository.avancarStatus(order.number, quantidadeArmazenada: 25);
    final armazenadas = await repository.fetchOrdensArmazenadas();

    expect(armazenadas.first.numero, order.number);
    expect(armazenadas.first.quantidadeArmazenada, 25);
    expect(armazenadas.first.tipoLabel, 'Armazenada parcial');
  });

  testWidgets('digitar parte do codigo sugere produtos e mostra OPs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: NovaOpDialog(
            ordensDisponiveis: [
              OrdemDisponivel(
                numero: '01596101001',
                numeroLegivel: '015961-01-001',
                produtoCodigo: '730-0863',
                produto: '730-0863 - SMART CENTRAL VETTI',
                quantidade: 500,
                previsao: '10/08/2026',
              ),
            ],
            catalogo: TestCatalog(),
            armazens: testArmazens(),
            responsaveis: const ['Tatiane'],
            onCreate: (_) {},
            onSolicitar: (_, _, _) {},
            onClose: () {},
          ),
        ),
      ),
    );

    // Um dígito já filtra: no catálogo de teste, só 575-0863 começa com 5.
    await tester.enterText(find.byType(TextFormField).first, '5');
    await tester.pumpAndSettle();

    expect(find.text('575-0863'), findsOneWidget);
    expect(find.text('730-0863'), findsNothing);
    // Esse produto não tem OP em aberto na lista passada.
    expect(find.text('sem OP'), findsOneWidget);

    // Trocando para 7, aparece o que tem OP, com a contagem.
    await tester.enterText(find.byType(TextFormField).first, '7');
    await tester.pumpAndSettle();

    expect(find.text('730-0863'), findsOneWidget);
    expect(find.text('1 OP'), findsOneWidget);

    // Tocar na sugestão preenche o código e troca a lista pelo cartão.
    await tester.tap(find.text('730-0863'));
    await tester.pumpAndSettle();

    expect(find.textContaining('SMART CENTRAL VETTI'), findsWidgets);
    expect(find.textContaining('1 OP em aberto'), findsOneWidget);
  });

  testWidgets('a lista de OPs mostra o numero legivel que as separa', (
    tester,
  ) async {
    // Invertido em 31/07/2026. O dropdown antigo rotulava a OP por quantidade
    // e prazo, e escondia o numero: duas OPs do mesmo produto com a mesma
    // quantidade e o mesmo prazo ficavam indistinguiveis — 12 casos em 298 nos
    // dados reais. A lista que entrou no lugar mostra o numero legivel.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: NovaOpDialog(
            ordensDisponiveis: [
              OrdemDisponivel(
                numero: '01596101001',
                numeroLegivel: '015961-01-001',
                produtoCodigo: '730-0863',
                produto: '730-0863 - SMART CENTRAL VETTI',
                quantidade: 500,
                previsao: '10/08/2026',
              ),
              OrdemDisponivel(
                numero: '01499201001',
                numeroLegivel: '014992-01-001',
                produtoCodigo: '730-0863',
                produto: '730-0863 - SMART CENTRAL VETTI',
                quantidade: 500,
                previsao: '10/08/2026',
              ),
            ],
            catalogo: TestCatalog(),
            armazens: testArmazens(),
            responsaveis: const ['Tatiane'],
            onCreate: (_) {},
            onSolicitar: (_, _, _) {},
            onClose: () {},
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, '730-0863');
    await tester.pumpAndSettle();

    // As duas OPs aparecem de uma vez, cada uma com o proprio numero: e o que
    // as distingue quando quantidade e prazo coincidem.
    expect(find.text('015961-01-001'), findsOneWidget);
    expect(find.text('014992-01-001'), findsOneWidget);
    expect(find.textContaining('500 un · prazo 10/08/2026'), findsNWidgets(2));

    // O campo "Produto encontrado" saiu: repetia o cartao logo acima.
    expect(find.text('Produto encontrado'), findsNothing);
  });

  testWidgets('almoxarifado busca OP pelo codigo do produto, igual ao painel', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Store vazio: nenhuma OP adotada, todas disponiveis para trazer.
    final store = ProductionFlowStore(catalog: TestCatalog());
    await tester.pumpWidget(
      _testApp(initialRoute: '/almoxarifado', store: store),
    );
    await tester.pumpAndSettle();

    // A tela abre na fila de separacao; a aba leva ao seletor.
    await tester.tap(find.text('Trazer OP').first);
    await tester.pumpAndSettle();

    // O seletor compartilhado precisa estar ali, com busca por codigo.
    expect(find.byType(ProtheusOpPicker), findsOneWidget);
    expect(find.text('Código Protheus'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '575');
    await tester.pumpAndSettle();

    // Sugestao com a contagem de OPs em aberto do produto.
    expect(find.text('575-0863'), findsOneWidget);
    expect(find.text('1 OP'), findsOneWidget);
  });

  testWidgets('adoption dialog submits the selected OP and priority', (
    tester,
  ) async {
    AdocaoOrdemDTO? adotada;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: NovaOpDialog(
            ordensDisponiveis: [
              OrdemDisponivel(
                numero: '01596101001',
                numeroLegivel: '015961-01-001',
                produtoCodigo: '730-0863',
                produto: '730-0863 - SMART CENTRAL VETTI',
                quantidade: 500,
                previsao: '10/08/2026',
              ),
            ],
            catalogo: TestCatalog(),
            armazens: testArmazens(),
            responsaveis: const ['Tatiane'],
            onCreate: (dto) => adotada = dto,
            onSolicitar: (_, _, _) {},
            onClose: () {},
          ),
        ),
      ),
    );

    // A busca é pelo código do produto, não pelo número da OP.
    await tester.enterText(find.byType(TextFormField).first, '730-0863');
    await tester.pumpAndSettle();

    // O cartão do produto aparece com identificação e OPs em aberto.
    expect(find.textContaining('SMART CENTRAL VETTI'), findsWidgets);
    expect(find.textContaining('1 OP em aberto'), findsOneWidget);

    // Quantidade e previsão vêm do Protheus e são só exibidas.
    expect(find.text('500'), findsOneWidget);
    expect(find.text('10/08/2026'), findsOneWidget);

    // O formulário agora rola: a prioridade pode estar fora da área visível.
    await tester.ensureVisible(find.text('Media'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Media'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alta').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trazer OP para o fluxo'));
    await tester.pumpAndSettle();

    expect(adotada, isNotNull);
    expect(adotada!.numero, '01596101001');
    expect(adotada!.prioridade, 'Alta');
  });

  test('flow repository adopts dashboard OPs with selected priority', () async {
    final store = ProductionFlowStore(catalog: TestCatalog());
    final repository = FlowOpRepository(
      store,
      catalog: TestCatalog(),
      protheusOrders: testProtheusRepository(),
    );

    final created = await repository.adotarOrdem(
      const AdocaoOrdemDTO(
        numero: '01596101001',
        responsavel: 'Tatiane',
        prioridade: 'Alta',
      ),
    );

    final flowOrder = store.orders.firstWhere(
      (order) => order.number == created.numero,
    );

    expect(flowOrder.priority, 'Alta');
    expect(flowOrder.isHighPriority, isTrue);
  });

  test('stage pause records operator pin, reason and optional quantity', () {
    final store = ProductionFlowStore(catalog: TestCatalog());
    final adotada = store.adoptOrder(testOrder(numero: '015961'));
    store.completeStage(adotada.number); // almoxarifado -> firmware
    final order = store.ordersAtStage(ProductionStage.firmware).first;

    store.startStage(
      order.number,
      operatorName: 'Juliana',
      operatorPin: '3001',
    );
    store.pauseStage(
      order.number,
      operatorName: 'Juliana',
      operatorPin: '3001',
      reason: PauseReason.cafe,
      producedQuantity: 18,
    );

    final paused = store.orders.firstWhere((op) => op.number == order.number);
    final session = paused.operatorSessions.singleWhere(
      (item) => item.operatorPin == '3001',
    );

    expect(paused.pauseEvents, hasLength(1));
    expect(paused.pauseEvents.single.reason, PauseReason.cafe);
    expect(paused.pauseEvents.single.operatorPin, '3001');
    expect(session.producedQuantity, 18);
    expect(session.pausedAt, isNotNull);
    expect(paused.status, ProductionRunStatus.paused);

    store.startStage(
      order.number,
      operatorName: 'Juliana',
      operatorPin: '3001',
    );
    final resumed = store.orders.firstWhere((op) => op.number == order.number);
    expect(resumed.pauseEvents.single.resumedAt, isNotNull);
    expect(
      resumed.pauseEvents.single.pauseDuration(DateTime.now()).inMilliseconds,
      greaterThanOrEqualTo(0),
    );
  });

  test('OP stage advances only after all active operators complete', () {
    final store = ProductionFlowStore(catalog: TestCatalog());
    final adotada = store.adoptOrder(testOrder(numero: '015961'));
    store.completeStage(adotada.number); // almoxarifado -> firmware
    store.completeStage(adotada.number); // firmware -> soldagem
    final order = store.ordersAtStage(ProductionStage.soldering).first;

    store.startStage(order.number, operatorName: 'Bryan', operatorPin: '3003');
    store.startStage(order.number, operatorName: 'Katlyn', operatorPin: '3007');

    store.completeStage(
      order.number,
      operatorName: 'Bryan',
      operatorPin: '3003',
    );

    final waitingForKatlyn = store.orders.firstWhere(
      (op) => op.number == order.number,
    );
    expect(waitingForKatlyn.currentStage, ProductionStage.soldering);
    expect(waitingForKatlyn.status, ProductionRunStatus.active);
    expect(
      waitingForKatlyn.operatorSessions
          .singleWhere((item) => item.operatorPin == '3003')
          .completedAt,
      isNotNull,
    );
    expect(
      waitingForKatlyn.operatorSessions
          .singleWhere((item) => item.operatorPin == '3003')
          .workedDuration(DateTime.now())
          .inMilliseconds,
      greaterThanOrEqualTo(0),
    );
    expect(
      waitingForKatlyn.operatorSessions
          .singleWhere((item) => item.operatorPin == '3007')
          .completedAt,
      isNull,
    );

    store.completeStage(
      order.number,
      operatorName: 'Katlyn',
      operatorPin: '3007',
    );

    final completed = store.orders.firstWhere(
      (op) => op.number == order.number,
    );
    expect(completed.currentStage, ProductionStage.testing);
    expect(completed.status, ProductionRunStatus.waiting);
  });

  testWidgets('shows the initial login screen', (tester) async {
    await tester.pumpWidget(_testApp());

    expect(find.text('Entrar no sistema'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('navigates from login to firmware screen', (tester) async {
    await tester.pumpWidget(_testApp());

    await tester.enterText(find.byType(TextFormField).first, 'juliana');
    await tester.enterText(find.byType(TextFormField).last, '3001');
    await tester.ensureVisible(find.text('Entrar'));
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Gravacao de Firmware'), findsOneWidget);
    expect(find.text(opFirmware), findsWidgets);
  });

  testWidgets('navigates from login to tv dashboard', (tester) async {
    await _setViewport(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());

    await tester.enterText(find.byType(TextFormField).first, 'tv');
    await tester.enterText(find.byType(TextFormField).last, '2026');
    await tester.ensureVisible(find.text('Entrar'));
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('VETTIFLOW TV'), findsOneWidget);
    expect(find.text('Producao em andamento'), findsOneWidget);
  });

  testWidgets('firmware screen renders on mobile viewport', (tester) async {
    await _setViewport(tester, const Size(430, 932));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(initialRoute: '/firmware'));
    await tester.pumpAndSettle();

    expect(find.text('OPs disponiveis'), findsOneWidget);
    // Mobile: cards aparecem, acoes so no bottom sheet ao tocar.
    expect(find.text(opFirmware), findsOneWidget);
  });

  testWidgets('firmware screen renders on desktop viewport', (tester) async {
    await _setViewport(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(initialRoute: '/firmware'));
    await tester.pumpAndSettle();

    expect(find.text('Quantidade'), findsOneWidget);
    expect(find.text('Acoes da OP'), findsOneWidget);
  });

  testWidgets('soldering screen renders core actions', (tester) async {
    await _setViewport(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(initialRoute: '/soldagem'));
    await tester.pumpAndSettle();

    expect(find.text('Soldagem'), findsWidgets);
    expect(find.text('OPs para soldagem'), findsOneWidget);
    expect(find.text('Pausar OP'), findsOneWidget);
    expect(find.text('Enviar para proxima etapa'), findsOneWidget);

    await tester.ensureVisible(find.text('Pausar OP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pausar OP'));
    await tester.pumpAndSettle();

    expect(find.text('Motivo da pausa'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '3003');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Pausar'));
    await tester.pumpAndSettle();

    expect(find.text('Retomar OP'), findsOneWidget);
    expect(find.text('Enviar para proxima etapa'), findsOneWidget);
  });

  testWidgets('pause reason outro requires an explanation', (tester) async {
    await _setViewport(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(initialRoute: '/soldagem'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pausar OP'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pause-reason-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Outro').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pause-custom-reason')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('pause-pin')), '3003');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Pausar'));
    await tester.pumpAndSettle();

    expect(find.text('Informe o motivo da pausa.'), findsOneWidget);
    expect(find.text('Pausar OP'), findsWidgets);
  });

  testWidgets('dashboard shows stored tab and stored orders', (tester) async {
    await _setViewport(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = ProductionFlowStore(catalog: TestCatalog());
    final protheusRepo = testProtheusRepository();
    final adotada = store.adoptOrder(testOrder(numero: '015961'));
    while (store.orders.first.currentStage != ProductionStage.expedition) {
      store.completeStage(adotada.number);
    }
    store.completeExpedition(adotada.number, storedQuantity: 25);
    final numeroArmazenado = adotada.number;
    final repository = FlowOpRepository(
      store,
      catalog: TestCatalog(),
      protheusOrders: protheusRepo,
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          RepositoryProvider<ProductCatalogRepository>.value(
            value: TestCatalog(),
          ),
          RepositoryProvider<ProtheusOrderRepository>.value(
            value: protheusRepo,
          ),
          ChangeNotifierProvider<ProductionFlowStore>.value(value: store),
          ChangeNotifierProvider<OperatorAssignmentStore>(
            create: (_) => OperatorAssignmentStore(),
          ),
          RepositoryProvider<OpRepository>.value(value: repository),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: BlocProvider(
            create: (_) => DashboardCubit(repository),
            child: const DashboardPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Armazenadas'), findsOneWidget);

    await tester.tap(find.text('Armazenadas'));
    await tester.pumpAndSettle();

    expect(find.text('OPs armazenadas'), findsOneWidget);
    expect(find.text(numeroArmazenado), findsOneWidget);
  });

  testWidgets('expedition dispatches partial and full stored quantity', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(initialRoute: '/expedicao'));
    await tester.pumpAndSettle();

    expect(find.text('Armazenadas'), findsOneWidget);

    await tester.tap(find.text('Armazenadas'));
    await tester.pumpAndSettle();

    expect(find.text('OPs armazenadas'), findsOneWidget);
    expect(find.text('Expedidas'), findsOneWidget);
    expect(find.text(opArmazenada), findsWidgets);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Expedir').first);
    await tester.pumpAndSettle();

    expect(find.text('Expedir armazenada'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '80');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Expedir').last);
    await tester.pumpAndSettle();

    // 80 das 100 armazenadas foram expedidas: restam 20 em estoque.
    expect(find.textContaining('20 un'), findsWidgets);
    expect(find.textContaining('80 un'), findsWidgets);
    expect(find.textContaining('Armazenamento'), findsWidgets);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Expedir').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Expedir').last);
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma OP armazenada.'), findsWidgets);
  });

  testWidgets('expedition finish preview shows stored and dispatched split', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(initialRoute: '/expedicao'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Iniciar conferencia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalizar despacho'));
    await tester.pumpAndSettle();

    expect(find.text('Disponivel'), findsOneWidget);
    expect(find.text('Vai armazenar'), findsOneWidget);
    expect(find.text('Sera expedido'), findsOneWidget);
    expect(find.text('300 un'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, '100');
    await tester.pumpAndSettle();

    expect(find.text('100 un'), findsOneWidget);
    expect(find.text('200 un'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '3006');
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Finalizar'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Finalizar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Armazenadas'));
    await tester.pumpAndSettle();

    expect(find.text(opExpedicao), findsWidgets);
    expect(find.textContaining('100 un'), findsWidgets);
    expect(find.textContaining('200 un'), findsWidgets);
  });

  testWidgets('tv dashboard rotates through production panels', (tester) async {
    await _setViewport(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(initialRoute: '/tv'));
    await tester.pumpAndSettle();

    expect(find.text('VETTIFLOW TV'), findsOneWidget);
    expect(find.text('Producao em andamento'), findsOneWidget);

    await tester.pump(const Duration(seconds: 12));
    await tester.pumpAndSettle();

    expect(find.text('Fluxo por etapa'), findsOneWidget);
  });

  testWidgets('tv dashboard fits compact desktop viewport', (tester) async {
    await _setViewport(tester, const Size(1024, 600));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(initialRoute: '/tv'));
    await tester.pumpAndSettle();

    expect(find.text('VETTIFLOW TV'), findsOneWidget);
    expect(find.text('Producao em andamento'), findsOneWidget);
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
}

Widget _testApp({String initialRoute = '/login', ProductionFlowStore? store}) {
  final flowStore = store ?? storeComOpsAdotadas();
  final protheus = testProtheusRepository();
  return MultiProvider(
    providers: [
      RepositoryProvider<ProductCatalogRepository>.value(value: TestCatalog()),
      RepositoryProvider<ProtheusOrderRepository>.value(value: protheus),
      ChangeNotifierProvider<ProductionFlowStore>.value(value: flowStore),
      ChangeNotifierProvider<OperatorAssignmentStore>(
        create: (_) => OperatorAssignmentStore(),
      ),
      RepositoryProvider<OpRepository>(
        create: (_) => FlowOpRepository(
          flowStore,
          catalog: TestCatalog(),
          protheusOrders: protheus,
        ),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      initialRoute: initialRoute,
      routes: vettiFlowRoutes(),
    ),
  );
}
