import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/shared/theme/app_theme.dart';
import 'package:vetti_flow_1_0/ui/auth/login_page.dart';
import 'package:vetti_flow_1_0/ui/firmware/firmware_page.dart';
import 'package:vetti_flow_1_0/ui/soldering/soldering_page.dart';

void main() {
  testWidgets('shows the initial login screen', (tester) async {
    await tester.pumpWidget(_testApp());

    expect(find.text('Entrar no sistema'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('navigates from login to firmware screen', (tester) async {
    await tester.pumpWidget(_testApp());

    await tester.enterText(find.byType(TextFormField).first, 'fernando');
    await tester.enterText(find.byType(TextFormField).last, '5643');
    await tester.ensureVisible(find.text('Entrar'));
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Gravacao de Firmware'), findsOneWidget);
    expect(find.text('OP-00564-345'), findsWidgets);
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
    expect(find.text('Iniciar OP'), findsOneWidget);
    expect(find.text('Pausar OP'), findsNothing);
    expect(find.text('Enviar para proxima etapa'), findsNothing);

    await tester.ensureVisible(find.text('Iniciar OP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar OP'));
    await tester.pumpAndSettle();

    expect(find.text('Pausar OP'), findsOneWidget);
    expect(find.text('Enviar para proxima etapa'), findsOneWidget);
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
}

Widget _testApp({String initialRoute = '/login'}) {
  return MaterialApp(
    theme: AppTheme.light,
    initialRoute: initialRoute,
    routes: {
      '/login': (context) => const LoginPage(),
      '/firmware': (context) => const FirmwarePage(),
      '/soldagem': (context) => const SolderingPage(),
    },
  );
}
