import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/empenho_editor.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/solicitacao_op_form.dart';

import 'fixtures.dart';

/// Único produto do catálogo de teste com estrutura: 200-052 em 1 por peça e
/// MOD08010201005 em 0,001348 (fração de custo indireto, como o Protheus
/// rateia).
const _comEstrutura = '203-002';

/// Campo de código do produto e o de quantidade da OP, nessa ordem na tela.
Finder get _codigo => find.byType(TextFormField).first;
Finder get _quantidade => find.byType(TextField).at(1);

/// Campo de quantidade da i-ésima linha de empenho.
///
/// Ancorado no [EmpenhoEditor] de propósito: buscar pelo texto casaria também
/// com o campo de quantidade da OP quando os dois mostram o mesmo número.
Finder _linhaEmpenho(int i) => find
    .descendant(of: find.byType(EmpenhoEditor), matching: find.byType(TextField))
    .at(i);

SolicitacaoOp? _ultimoPedido;

Widget _harness() {
  _ultimoPedido = null;
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SolicitacaoOpForm(
          catalogo: TestCatalog(),
          armazens: testArmazens(),
          onMudar: (p) => _ultimoPedido = p,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('quantidade digitada depois do produto reexplode os empenhos', (
    tester,
  ) async {
    // A ordem natural é essa: primeiro o código que a produção sabe de cor,
    // depois quanto vai fazer. O campo da linha ficava preso no valor da
    // primeira explosão (zero) porque o controller nascia com a linha e nunca
    // mais ressincronizava.
    await tester.pumpWidget(_harness());

    await tester.enterText(_codigo, _comEstrutura);
    await tester.pumpAndSettle();
    await tester.enterText(_quantidade, '10');
    await tester.pumpAndSettle();

    // 1 por peça × 10 e 0,001348 × 10, nos campos das linhas e no pedido.
    expect(tester.widget<TextField>(_linhaEmpenho(0)).controller!.text, '10');
    expect(
      tester.widget<TextField>(_linhaEmpenho(1)).controller!.text,
      '0.01348',
    );

    final empenhos = _ultimoPedido!.empenhos;
    expect(empenhos, hasLength(2));
    expect(empenhos.firstWhere((e) => e.produto == '200-052').quantidade, 10);
  });

  testWidgets('mudar a quantidade de novo continua reexplodindo', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());

    await tester.enterText(_codigo, _comEstrutura);
    await tester.pumpAndSettle();
    await tester.enterText(_quantidade, '10');
    await tester.pumpAndSettle();
    await tester.enterText(_quantidade, '25');
    await tester.pumpAndSettle();

    expect(
      _ultimoPedido!.empenhos
          .firstWhere((e) => e.produto == '200-052')
          .quantidade,
      25,
    );
    expect(tester.widget<TextField>(_linhaEmpenho(0)).controller!.text, '25');
  });

  testWidgets('ajuste manual da linha sobrevive à mudança de quantidade', (
    tester,
  ) async {
    // A regra que já existia: depois que o operador mexe numa linha, refazer a
    // explosão apagaria o ajuste dele. O conserto do campo não pode reabrir
    // essa porta.
    await tester.pumpWidget(_harness());

    await tester.enterText(_codigo, _comEstrutura);
    await tester.pumpAndSettle();
    await tester.enterText(_quantidade, '10');
    await tester.pumpAndSettle();

    // Mexe na linha do 200-052, que a explosão tinha deixado em 10.
    await tester.enterText(_linhaEmpenho(0), '7');
    await tester.pumpAndSettle();
    await tester.enterText(_quantidade, '20');
    await tester.pumpAndSettle();

    expect(
      _ultimoPedido!.empenhos
          .firstWhere((e) => e.produto == '200-052')
          .quantidade,
      7,
      reason: 'a quantidade ajustada à mão foi sobrescrita pela reexplosão',
    );
  });
}
