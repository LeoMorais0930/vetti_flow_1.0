import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/product_catalog_repository.dart';
import 'package:vetti_flow_1_0/ui/shared/widgets/produto_busca.dart';

import 'fixtures.dart';

/// Produto com bloqueio de tela na SB1 (B1_MSBLQL = '1') no [TestCatalog].
const _bloqueado = '730-0500';
const _liberado = '730-0863';

/// Prefixo que casa com os dois.
const _prefixo = '730-0';

/// Produto com estrutura longa, do tamanho que o cartão truncava em 5 linhas.
///
/// É o caso real do 575-0767 (8 componentes) que motivou mostrar tudo.
const _estruturaLonga = '575-0767';

class _CatalogoEstruturaLonga implements ProductCatalogRepository {
  static final _item = ProductionCatalogItem(
    code: _estruturaLonga,
    name: 'SUB MEC SMART PRESENCA LR',
    unit: 'PC',
    type: 'PI',
    group: '575',
    components: [
      for (var i = 1; i <= 8; i++)
        ProductionComponent(
          code: 'COMP-00$i',
          description: 'COMPONENTE $i',
          quantity: i.toDouble(),
          stock: 100,
          unit: 'PC',
        ),
    ],
  );

  @override
  List<ProductionCatalogItem> get items => [_item];

  @override
  ProductionCatalogItem? findByCode(String code) =>
      code == _item.code ? _item : null;

  @override
  ProductionCatalogItem requireByCode(String code) =>
      findByCode(code) ?? (throw ProductNotFoundException(code));

  @override
  Map<String, String> get descriptions => {_item.code: _item.name};
}

Widget _harness({
  required bool somenteLiberados,
  required ValueChanged<ProductionCatalogItem?> onProduto,
  ProductCatalogRepository? catalogo,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: ProdutoBusca(
          catalogo: catalogo ?? TestCatalog(),
          onProduto: onProduto,
          somenteLiberados: somenteLiberados,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('OP nova não sugere produto bloqueado no Protheus', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(somenteLiberados: true, onProduto: (_) {}),
    );

    await tester.enterText(find.byType(TextFormField), _prefixo);
    await tester.pump();

    expect(find.text(_liberado), findsOneWidget);
    expect(
      find.text(_bloqueado),
      findsNothing,
      reason:
          'o Protheus recusa movimentar item bloqueado — oferecê-lo produz um '
          'pedido de OP que morre na API',
    );
  });

  testWidgets('nem o código exato do bloqueado mostra o item', (tester) async {
    // Decisão do gestor em 04/08/2026: quem pede OP não deve nem enxergar o
    // item bloqueado. Um cartão dizendo "existe, mas está bloqueado" já é
    // enxergar — então o código exato responde como código inexistente.
    ProductionCatalogItem? escolhido;
    var chamadas = 0;
    await tester.pumpWidget(
      _harness(
        somenteLiberados: true,
        onProduto: (p) {
          escolhido = p;
          chamadas++;
        },
      ),
    );

    await tester.enterText(find.byType(TextFormField), _bloqueado);
    await tester.pump();

    expect(chamadas, greaterThan(0));
    expect(escolhido, isNull, reason: 'o formulário não pode montar o pedido');
    expect(find.textContaining('Nenhum produto'), findsOneWidget);

    // Nada do item na tela: nem descrição, nem o próprio código fora do campo
    // que a pessoa digitou.
    expect(find.text('SMART CENTRAL VETTI GERACAO ANTERIOR'), findsNothing);
    expect(
      find.text('$_bloqueado - SMART CENTRAL VETTI GERACAO ANTERIOR'),
      findsNothing,
    );
  });

  testWidgets('o cartão mostra a estrutura inteira, sem "e mais N"', (
    tester,
  ) async {
    // O cartão parava em 5 linhas e resumia o resto. Quem confere a estrutura
    // antes de pedir a OP precisa ver componente por componente.
    await tester.pumpWidget(
      _harness(
        somenteLiberados: true,
        onProduto: (_) {},
        catalogo: _CatalogoEstruturaLonga(),
      ),
    );

    await tester.enterText(find.byType(TextFormField), _estruturaLonga);
    await tester.pump();

    for (var i = 1; i <= 8; i++) {
      expect(
        find.textContaining('COMP-00$i · COMPONENTE $i'),
        findsOneWidget,
        reason: 'componente $i sumiu do cartão',
      );
    }
    expect(find.textContaining('e mais'), findsNothing);
    expect(find.textContaining('8 componentes'), findsOneWidget);
  });

  testWidgets('trazer OP existente continua enxergando o bloqueado', (
    tester,
  ) async {
    // 4 produtos com OP em aberto estão bloqueados na SB1 hoje. Escondê-los
    // aqui travaria trabalho que já está em andamento no chão de fábrica.
    ProductionCatalogItem? escolhido;
    await tester.pumpWidget(
      _harness(somenteLiberados: false, onProduto: (p) => escolhido = p),
    );

    await tester.enterText(find.byType(TextFormField), _prefixo);
    await tester.pump();
    expect(find.text(_bloqueado), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), _bloqueado);
    await tester.pump();
    expect(escolhido?.code, _bloqueado);
  });
}
