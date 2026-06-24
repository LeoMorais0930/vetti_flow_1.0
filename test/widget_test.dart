import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/app/vetti_flow_app.dart';

void main() {
  testWidgets('shows the initial login screen', (tester) async {
    await tester.pumpWidget(const VettiFlowApp());

    expect(find.text('Entrar no sistema'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Entrar'), findsOneWidget);
  });
}
