import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetti_flow_1_0/data/repositories/product_catalog_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_order_repository.dart';

/// Verifica os arquivos reais em assets/protheus/, gerados a partir do banco
/// migrado por ~/vettip12-migracao/gerar_fixture_app.py.
///
/// Serve para o formato do gerador e o do parser não se descolarem em silêncio:
/// se alguém regerar os dados com outra forma, isto quebra aqui e não em
/// produção.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final produtos = File('assets/protheus/produtos.json');
  final ordens = File('assets/protheus/ordens.json');

  test(
    'os assets estão registrados no pubspec e carregam pelo bundle',
    () async {
      // Ler do disco não prova que o app consegue ler: se a entrada em
      // pubspec.yaml faltar, isto falha e o teste de arquivo passaria.
      final catalog = await AssetProductCatalogRepository.load();
      final ordensCarregadas = await AssetProtheusOrderRepository.loadOrders();

      expect(catalog.items, isNotEmpty);
      expect(ordensCarregadas, isNotEmpty);
    },
  );

  test('os assets do Protheus existem', () {
    expect(produtos.existsSync(), isTrue, reason: produtos.path);
    expect(ordens.existsSync(), isTrue, reason: ordens.path);
  });

  test('o catálogo real carrega com estrutura e saldo', () {
    final items = AssetProductCatalogRepository.parse(
      produtos.readAsStringSync(),
    );

    expect(items.length, greaterThan(500));
    expect(items.every((i) => i.code.isNotEmpty), isTrue);
    expect(items.any((i) => i.components.isNotEmpty), isTrue);
    expect(items.any((i) => i.stock > 0), isTrue);

    // Componentes precisam ter descrição resolvida, não só o código repetido.
    final comEstrutura = items.firstWhere((i) => i.components.isNotEmpty);
    expect(
      comEstrutura.components.any((c) => c.description != c.code),
      isTrue,
      reason: 'a descrição do componente deve vir do próprio catálogo',
    );
  });

  test('as ordens reais carregam, com abertas e encerradas', () {
    final all = AssetProtheusOrderRepository.parseOrders(
      ordens.readAsStringSync(),
    );
    final repo = AssetProtheusOrderRepository(all);

    expect(all.length, greaterThan(10000));
    expect(repo.open, isNotEmpty);
    expect(repo.open.length, lessThan(all.length));
    expect(all.where((o) => o.closed), isNotEmpty);
  });

  test('toda OP tem chave completa e número de 11 caracteres', () {
    final all = AssetProtheusOrderRepository.parseOrders(
      ordens.readAsStringSync(),
    );

    for (final order in all.take(200)) {
      expect(order.key.filial, isNotEmpty);
      expect(order.key.numero, isNotEmpty);
      expect(order.productCode, isNotEmpty);
      // 6 de número + 2 de item + 3 de sequência.
      expect(order.displayNumber, hasLength(11), reason: order.displayNumber);
    }
  });

  test('OPs do mesmo produto são distinguíveis na tela', () {
    final repo = AssetProtheusOrderRepository(
      AssetProtheusOrderRepository.parseOrders(ordens.readAsStringSync()),
    );

    // Agrupa as OPs em aberto por produto e confere que, dentro de cada
    // produto, os números legíveis não se repetem — é o que o seletor mostra.
    final porProduto = <String, List<String>>{};
    for (final op in repo.open) {
      porProduto.putIfAbsent(op.productCode, () => []).add(op.numeroLegivel);
    }

    for (final entry in porProduto.entries) {
      expect(
        entry.value.toSet().length,
        entry.value.length,
        reason: 'produto ${entry.key} tem OPs com número repetido',
      );
    }
  });

  test('as OPs em aberto têm produto no catálogo', () {
    final catalog = AssetProductCatalogRepository(
      AssetProductCatalogRepository.parse(produtos.readAsStringSync()),
    );
    final repo = AssetProtheusOrderRepository(
      AssetProtheusOrderRepository.parseOrders(ordens.readAsStringSync()),
    );

    final semProduto = repo.open
        .where((o) => catalog.findByCode(o.productCode) == null)
        .toList();

    expect(
      semProduto,
      isEmpty,
      reason:
          'OP em aberto sem produto no catálogo apareceria na tela só com o '
          'código: ${semProduto.take(5).map((o) => o.productCode).toList()}',
    );
  });
}
