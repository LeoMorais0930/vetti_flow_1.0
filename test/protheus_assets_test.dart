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

  test('produto sem OP em aberto também traz a estrutura', () {
    // A extração da SG1 já foi restrita aos produtos que tinham OP em aberto,
    // que é o inverso do que a abertura de OP nova precisa: o produto para o
    // qual se vai abrir a OP normalmente ainda não tem nenhuma. A tela
    // explodia zero componente e o operador pedia a OP sem empenho nenhum.
    final catalog = AssetProductCatalogRepository(
      AssetProductCatalogRepository.parse(produtos.readAsStringSync()),
    );
    final repo = AssetProtheusOrderRepository(
      AssetProtheusOrderRepository.parseOrders(ordens.readAsStringSync()),
    );

    final comOpAberta = repo.open.map((o) => o.productCode).toSet();
    final semOpMasComEstrutura = catalog.items
        .where((i) => i.components.isNotEmpty)
        .where((i) => !comOpAberta.contains(i.code))
        .toList();

    expect(
      semOpMasComEstrutura,
      isNotEmpty,
      reason:
          'nenhum produto sem OP em aberto tem estrutura — sinal de que a '
          'extração da SG1 voltou a ser filtrada por OP em aberto',
    );
  });

  test('a estrutura não repete componente', () {
    // A SG1 traz o mesmo componente em linhas separadas quando ele aparece em
    // posições diferentes da montagem. EmpenhoEditor usa produto+almoxarifado
    // como chave de widget e como Set de "já presentes": linha repetida faz o
    // Flutter derrubar a lista inteira com "Duplicate keys found", e a área de
    // empenhos da OP nova aparece vazia para o operador.
    final catalog = AssetProductCatalogRepository(
      AssetProductCatalogRepository.parse(produtos.readAsStringSync()),
    );

    for (final item in catalog.items) {
      final codigos = item.components.map((c) => c.code).toList();
      expect(
        codigos.toSet().length,
        codigos.length,
        reason: 'produto ${item.code} repete componente na estrutura',
      );
    }
  });

  test('componente repetido na SG1 vira uma linha com a soma', () {
    // O 441-062 aparece duas vezes na estrutura do 500-0001, como 4 e como 1.
    // Para empenhar valem 5 numa linha só.
    final catalog = AssetProductCatalogRepository(
      AssetProductCatalogRepository.parse(produtos.readAsStringSync()),
    );

    final item = catalog.findByCode('500-0001');
    expect(item, isNotNull, reason: '500-0001 saiu do catálogo');

    final repetido = item!.components.where((c) => c.code == '441-062');
    expect(repetido, hasLength(1));
    expect(repetido.single.quantity, 5);
  });

  test('todo componente da estrutura tem cadastro no catálogo', () {
    // Sem o cadastro do componente o app cai no fallback do parser: mostra o
    // código no lugar da descrição e saldo zero, sem nada indicar que faltou.
    final catalog = AssetProductCatalogRepository(
      AssetProductCatalogRepository.parse(produtos.readAsStringSync()),
    );

    final orfaos = <String>{
      for (final item in catalog.items)
        for (final c in item.components)
          if (catalog.findByCode(c.code) == null) c.code,
    };

    expect(orfaos, isEmpty, reason: 'componentes fora do catálogo: $orfaos');
  });

  test('o catálogo real traz o bloqueio de tela da SB1', () {
    // B1_MSBLQL = '1' é o que impede a OP nova. Se o gerador parar de trazer o
    // campo, o parser assume "liberado" para todo mundo e o filtro da busca
    // some sem nenhum sinal na tela.
    final catalog = AssetProductCatalogRepository(
      AssetProductCatalogRepository.parse(produtos.readAsStringSync()),
    );

    final bloqueados = catalog.items.where((i) => i.blocked).toList();
    expect(
      bloqueados,
      isNotEmpty,
      reason: 'nenhum produto bloqueado — o campo bloqueado sumiu da extração',
    );
    expect(
      bloqueados.length,
      lessThan(catalog.items.length),
      reason: 'todo o catálogo bloqueado — a busca de OP nova ficaria vazia',
    );

    // Bloqueado continua no catálogo de propósito: parte deles é componente de
    // estrutura vigente, e sumir daqui tiraria descrição e saldo do empenho.
    final componentes = {
      for (final item in catalog.items)
        for (final c in item.components) c.code,
    };
    expect(
      bloqueados.where((i) => componentes.contains(i.code)),
      isNotEmpty,
      reason: 'produto bloqueado que é componente precisa seguir no catálogo',
    );
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
