import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/repositories/mock_op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/operator_assignment_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/shared/models/operator.dart';
import 'package:vetti_flow_1_0/shared/theme/app_theme.dart';
import 'package:vetti_flow_1_0/ui/dashboard/cubit/dashboard_cubit.dart';
import 'package:vetti_flow_1_0/ui/dashboard/dashboard_page.dart';
import 'package:vetti_flow_1_0/ui/auth/login_page.dart';
import 'package:vetti_flow_1_0/ui/expedition/expedition_page.dart';
import 'package:vetti_flow_1_0/ui/firmware/firmware_page.dart';
import 'package:vetti_flow_1_0/ui/soldering/soldering_page.dart';
import 'package:vetti_flow_1_0/ui/tv/vetti_flow_tv_page.dart';

void main() {
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
    final repository = MockOpRepository();

    await repository.avancarStatus('OP-2026-0179', quantidadeArmazenada: 25);
    final armazenadas = await repository.fetchOrdensArmazenadas();

    expect(armazenadas.first.numero, 'OP-2026-0179');
    expect(armazenadas.first.quantidadeArmazenada, 25);
    expect(armazenadas.first.tipoLabel, 'Armazenada parcial');
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
    expect(find.text('OP-00564-345'), findsWidgets);
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
    expect(find.text('OP-00564-345'), findsOneWidget);
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

    expect(find.text('Retomar OP'), findsOneWidget);
    expect(find.text('Enviar para proxima etapa'), findsOneWidget);
  });

  testWidgets('dashboard shows stored tab and stored orders', (tester) async {
    await _setViewport(tester, const Size(1366, 768));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = MockOpRepository();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProductionFlowStore>(
            create: (_) => ProductionFlowStore(),
          ),
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
    expect(find.text('OP-2026-0172'), findsOneWidget);
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
    expect(find.text('OP-00563-992'), findsWidgets);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Expedir').first);
    await tester.pumpAndSettle();

    expect(find.text('Expedir armazenada'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '80');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Expedir').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('100 un'), findsWidgets);
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

    expect(find.text('OP-00564-352'), findsWidgets);
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

Widget _testApp({String initialRoute = '/login'}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ProductionFlowStore>(
        create: (_) => ProductionFlowStore(),
      ),
      ChangeNotifierProvider<OperatorAssignmentStore>(
        create: (_) => OperatorAssignmentStore(),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      initialRoute: initialRoute,
      routes: {
        '/login': (context) => const LoginPage(),
        '/firmware': (context) => const FirmwarePage(),
        '/soldagem': (context) => const SolderingPage(),
        '/expedicao': (context) => const ExpeditionPage(),
        '/tv': (context) => const VettiFlowTvPage(),
      },
    ),
  );
}
