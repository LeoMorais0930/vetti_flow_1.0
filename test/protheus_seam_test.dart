import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/repositories/product_catalog_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/production_flow_store.dart';

import 'fixtures.dart';

void main() {
  group('costura do catálogo', () {
    test('o store aceita qualquer implementação de catálogo', () {
      final store = ProductionFlowStore(catalog: TestCatalog());

      final order = store.adoptOrder(testOrder(numero: '015961'));

      expect(order.productCode, '730-0863');
      expect(order.productName, 'SMART CENTRAL VETTI');
    });

    test('requireByCode falha alto em código desconhecido', () {
      final catalog = TestCatalog();

      expect(catalog.findByCode('NAO-EXISTE'), isNull);
      expect(
        () => catalog.requireByCode('NAO-EXISTE'),
        throwsA(isA<ProductNotFoundException>()),
      );
    });

    test('produto desconhecido nunca vira outro produto', () {
      final store = ProductionFlowStore(catalog: TestCatalog());

      final item = store.catalogItem('NAO-EXISTE');

      // O fallback antigo devolvia o primeiro item do catálogo, o que exibiria
      // um produto errado como se fosse o da OP.
      expect(item.code, 'NAO-EXISTE');
      expect(item.name, 'NAO-EXISTE');
      expect(item.components, isEmpty);
    });

    test('quantidade fracionária de estrutura não é arredondada', () {
      final catalog = TestCatalog();
      final rateado = catalog
          .requireByCode('203-002')
          .components
          .firstWhere((c) => c.code == 'MOD08010201005');

      expect(rateado.quantity, closeTo(0.001348, 1e-9));
      expect(rateado.quantityLabel, '0.001348 un');
    });
  });

  group('adoção de OP', () {
    test('OP encerrada no Protheus não pode ser adotada', () {
      final store = ProductionFlowStore(catalog: TestCatalog());

      expect(
        () => store.adoptOrder(testOrder(numero: '015900', encerrada: true)),
        throwsA(isA<ArgumentError>()),
      );
      expect(store.orders, isEmpty);
    });

    test('adotar a mesma OP duas vezes não duplica', () {
      final store = ProductionFlowStore(catalog: TestCatalog());
      final source = testOrder(numero: '015961');

      final primeira = store.adoptOrder(source);
      final segunda = store.adoptOrder(source);

      expect(store.orders, hasLength(1));
      expect(identical(primeira.number, segunda.number), isTrue);
    });

    test('a OP adotada herda número, quantidade e previsão do Protheus', () {
      final store = ProductionFlowStore(catalog: TestCatalog());

      final order = store.adoptOrder(
        testOrder(numero: '015960', quantidade: 2000, previsao: '12/08/2026'),
      );

      expect(order.number, '01596001001');
      expect(order.quantity, 2000);
      expect(order.prazo, '12/08/2026');
      expect(order.protheusKey!.filial, '04');
    });

    test('o store começa vazio: nenhuma OP existe sem ser adotada', () {
      expect(ProductionFlowStore(catalog: TestCatalog()).orders, isEmpty);
    });
  });

  group('chave do Protheus', () {
    const chave = ProtheusOrderKey(
      filial: '04',
      numero: '015537',
      item: '01',
      sequencia: '001',
    );

    test('formato legível separa número, item e sequência', () {
      // Os 11 dígitos grudados são o formato do banco. Quem opera vê separado,
      // senão OPs do mesmo produto ficam indistinguíveis na tela.
      expect(chave.numeroLegivel, '015537-01-001');
    });

    test('concatena no formato usado em D3_OP e D4_OP', () {
      // 6 de número + 2 de item + 3 de sequência = 11 caracteres.
      expect(chave.opConcatenada, '01553701001');
      expect(chave.opConcatenada, hasLength(11));
    });

    test('sobrevive à ida e volta em JSON', () {
      expect(ProtheusOrderKey.fromJson(chave.toJson()), chave);
    });

    test('a identidade não se perde ao mutar a OP', () {
      final store = ProductionFlowStore(catalog: TestCatalog());
      final antes = store.adoptOrder(testOrder(numero: '015961'));

      store.startStage(
        antes.number,
        operatorName: 'Teste',
        operatorPin: '1234',
      );

      final depois = store.orders.firstWhere((o) => o.number == antes.number);
      expect(depois.protheusKey, antes.protheusKey);
    });
  });
}
