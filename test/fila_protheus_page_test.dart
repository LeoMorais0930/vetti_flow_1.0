import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/repositories/mutation_sync_service.dart';
import 'package:vetti_flow_1_0/data/repositories/pending_mutation_store.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_sync_client.dart';
import 'package:vetti_flow_1_0/shared/theme/app_theme.dart';
import 'package:vetti_flow_1_0/ui/protheus/fila_protheus_page.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/vetti_top_bar.dart';

void main() {
  testWidgets('Protheus queue opens with an empty readable state', (
    tester,
  ) async {
    final store = PendingMutationStore();
    final client = ProtheusSyncClient(baseUrl: 'http://localhost:8000');
    addTearDown(client.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PendingMutationStore>.value(value: store),
          ChangeNotifierProvider<MutationSyncService>(
            create: (_) => MutationSyncService(store: store, client: client),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          routes: {FilaProtheusPage.rota: (_) => const FilaProtheusPage()},
          home: const FilaProtheusPage(),
        ),
      ),
    );

    expect(find.text('Fila do Protheus'), findsOneWidget);
    expect(find.text('Nada represado'), findsOneWidget);
    expect(find.text('Nada pendente para o Protheus.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('top bar shows the Protheus queue shortcut and pending count', (
    tester,
  ) async {
    final store = PendingMutationStore();
    store.enqueue(
      (id, criadoEm) => AberturaOpMutation(
        id: id,
        filial: '04',
        criadoEm: criadoEm,
        autor: 'Tatiane',
        produto: '730-0863',
        produtoDescricao: 'SMART ALARM',
        quantidade: 10,
        localProducao: '05',
      ),
    );
    final client = ProtheusSyncClient(baseUrl: 'http://localhost:8000');
    addTearDown(client.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PendingMutationStore>.value(value: store),
          ChangeNotifierProvider<MutationSyncService>(
            create: (_) => MutationSyncService(store: store, client: client),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          routes: {FilaProtheusPage.rota: (_) => const FilaProtheusPage()},
          home: const Scaffold(
            body: VettiTopBar(
              title: 'Producao',
              operatorName: 'Tatiane',
              operatorRole: 'Gestora',
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('1 aguardando envio ao Protheus'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byTooltip('1 aguardando envio ao Protheus'));
    await tester.pumpAndSettle();

    expect(find.text('Fila do Protheus'), findsOneWidget);
    expect(find.text('Aguardando envio para a API'), findsOneWidget);
    expect(find.textContaining('Abrir OP - 730-0863'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
