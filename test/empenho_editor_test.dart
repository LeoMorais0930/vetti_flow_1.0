import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/models/warehouse.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/empenho_editor.dart';

import 'fixtures.dart';

const _produto = '200-052';

const _linhaFolgada = EmpenhoLinha(
  produto: _produto,
  descricao: 'TAMPA SUPERIOR SMART CENTRAL',
  quantidade: 100,
  local: '05',
);

const _linhaFaltando = EmpenhoLinha(
  produto: _produto,
  descricao: 'TAMPA SUPERIOR SMART CENTRAL',
  quantidade: 500,
  local: '05',
);

Widget _harness({
  required EmpenhoLinha linha,
  List<SaldoArmazem> Function(String produto)? saldosPorArmazem,
  void Function(String produto, String localDestino)? onSolicitarTransferencia,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: EmpenhoEditor(
          linhas: [linha],
          armazens: testArmazens(),
          catalogo: TestCatalog(),
          saldosPorArmazem: saldosPorArmazem,
          onSolicitarTransferencia: onSolicitarTransferencia,
          onAlterar: (_, _) {},
          onRemover: (_) {},
          onIncluir: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'sem falta, mostra o disponível aqui e nos outros armazéns automaticamente',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          linha: _linhaFolgada,
          saldosPorArmazem: (_) => const [
            SaldoArmazem(filial: '04', local: '05', saldo: 500, empenhado: 100),
            SaldoArmazem(filial: '04', local: '01', saldo: 200, empenhado: 0),
          ],
        ),
      );

      // 500 - 100 = 400 disponível no 05 (armazém da linha); 200 no 01.
      expect(find.textContaining('Disponível: 400 aqui'), findsOneWidget);
      expect(find.textContaining('Outros: 01: 200'), findsOneWidget);
      expect(find.text('Solicitar transferência'), findsNothing);
    },
  );

  testWidgets(
    'com falta e outro armazém com posição, mostra o botão e ele dispara o callback certo',
    (tester) async {
      String? produtoPedido;
      String? localPedido;

      await tester.pumpWidget(
        _harness(
          linha: _linhaFaltando,
          saldosPorArmazem: (_) => const [
            SaldoArmazem(filial: '04', local: '05', saldo: 50, empenhado: 0),
            SaldoArmazem(filial: '04', local: '01', saldo: 900, empenhado: 0),
          ],
          onSolicitarTransferencia: (produto, local) {
            produtoPedido = produto;
            localPedido = local;
          },
        ),
      );

      expect(find.textContaining('Almox. 05 tem 50 disponível'), findsOneWidget);
      expect(find.textContaining('Outros: 01: 900'), findsOneWidget);

      final botao = find.text('Solicitar transferência');
      expect(botao, findsOneWidget);
      await tester.tap(botao);
      await tester.pump();

      expect(produtoPedido, _produto);
      expect(localPedido, '05');
    },
  );

  testWidgets(
    'com falta mas sem nenhum outro armazém com posição, não mostra o botão',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          linha: _linhaFaltando,
          saldosPorArmazem: (_) => const [
            SaldoArmazem(filial: '04', local: '05', saldo: 50, empenhado: 0),
          ],
          onSolicitarTransferencia: (_, _) {},
        ),
      );

      expect(find.textContaining('Almox. 05 tem 50 disponível'), findsOneWidget);
      expect(find.text('Solicitar transferência'), findsNothing);
    },
  );

  testWidgets(
    'sem saldosPorArmazem nem onSolicitarTransferencia, o recurso fica desligado',
    (tester) async {
      await tester.pumpWidget(_harness(linha: _linhaFaltando));

      expect(find.textContaining('Disponível:'), findsNothing);
      expect(find.textContaining('Outros:'), findsNothing);
      expect(find.textContaining('disponível'), findsNothing);
      expect(find.textContaining('não tem posição'), findsNothing);
      expect(find.text('Solicitar transferência'), findsNothing);
    },
  );
}
