import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/op_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/pending_mutation_store.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';
import 'package:vetti_flow_1_0/ui/dashboard/views/solicitacoes_view.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/protheus_op_picker.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/solicitacao_op_form.dart';

import 'fixtures.dart';

/// O número da OP nas duas metades do diálogo e no card do pedido.
///
/// Sumiu quando o Protheus virou dono da numeração: o mock antigo gerava um
/// `OP-2026-0188` na criação, e ao tirar a geração o campo foi junto. O número
/// real continua existindo — só chega depois, quando a API aplica o pedido.
void main() {
  test('o número colado do banco vira o formato do Protheus na tela', () {
    expect(formatOpNumber('01596101001'), '015961-01-001');

    // O que não é chave do Protheus volta intacto: OP local do tempo do mock e
    // códigos derivados de outras telas não podem ganhar traço.
    expect(formatOpNumber('OP-2026-0188'), 'OP-2026-0188');
    expect(formatOpNumber('REQ-61001'), 'REQ-61001');
    expect(formatOpNumber(''), '');
  });

  test('a identidade da OP continua colada — é ela que vai para a API', () {
    // Se `number` ganhar traços, o `D3_OP`/`D4_OP` das mutações sai errado e o
    // Protheus não acha a OP. O traço é só de tela.
    final store = ProductionFlowStore(catalog: TestCatalog());
    final adotada = store.adoptOrder(testOrder(numero: '015961'));

    expect(adotada.number, opFirmware);
    expect(adotada.numeroLegivel, opFirmwareLegivel);
  });

  testWidgets('OP existente: o número escolhido aparece em campo próprio', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProtheusOpPicker(
              catalogo: TestCatalog(),
              ordensDisponiveis: const [
                OrdemDisponivel(
                  numero: '01596101001',
                  numeroLegivel: '015961-01-001',
                  produtoCodigo: '730-0863',
                  produto: '730-0863 - SMART CENTRAL VETTI',
                  quantidade: 500,
                  previsao: '10/08/2026',
                ),
              ],
              onSelecionar: (_) {},
            ),
          ),
        ),
      ),
    );

    // Sem OP escolhida o campo existe, vazio.
    expect(find.text('Número da OP'), findsOneWidget);
    expect(find.text('—'), findsWidgets);

    await tester.enterText(find.byType(TextFormField).first, '730-0863');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('015961-01-001').first);
    await tester.pumpAndSettle();

    expect(find.text('015961-01-001'), findsWidgets);
  });

  testWidgets('OP nova: o campo diz que quem numera é o Protheus', (
    tester,
  ) async {
    // Deixar o campo de fora lia como "o VettiFlow perdeu o número". Ele fica,
    // dizendo de quem é a numeração — o VettiFlow nunca inventa um C2_NUM.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SolicitacaoOpForm(
              catalogo: TestCatalog(),
              armazens: testArmazens(),
              onMudar: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Número da OP'), findsOneWidget);
    expect(find.text('O Protheus numera ao aplicar o pedido'), findsOneWidget);
  });

  testWidgets('o card da solicitação mostra o número assim que ele existe', (
    tester,
  ) async {
    final fila = PendingMutationStore();
    fila.enqueue(
      (id, agora) => AberturaOpMutation(
        id: id,
        filial: '04',
        criadoEm: agora,
        autor: 'Tatiane',
        produto: '730-0863',
        produtoDescricao: '730-0863 - SMART CENTRAL VETTI',
        quantidade: 50,
        localProducao: '05',
      ),
    );

    Widget app() => MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<PendingMutationStore>.value(
          value: fila,
          child: const SolicitacoesView(),
        ),
      ),
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Enquanto o pedido só está na fila, não há número para mostrar.
    expect(find.textContaining('OP 0'), findsNothing);

    // A API criou a OP no Protheus e devolveu o número.
    fila.updateStatus(
      fila.aberturasPendentes.single.id,
      status: MutationStatus.armazenado,
      protheusRef: '015961-01-001',
    );
    await tester.pumpAndSettle();

    expect(find.text('OP 015961-01-001'), findsOneWidget);
  });
}
