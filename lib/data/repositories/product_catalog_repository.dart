import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/warehouse.dart';

/// Lançada quando se pede um produto que não existe no catálogo.
class ProductNotFoundException implements Exception {
  const ProductNotFoundException(this.code);

  final String code;

  @override
  String toString() => 'Produto não encontrado no catálogo: "$code"';
}

/// Fonte dos dados de produto: cadastro (SB1), estrutura (SG1) e saldo (SB2).
///
/// O VettiFlow apenas lê: quem é dono desse dado é o Protheus.
abstract class ProductCatalogRepository {
  List<ProductionCatalogItem> get items;

  ProductionCatalogItem? findByCode(String code);

  /// Produto pelo código. Lança [ProductNotFoundException] se não existir.
  ProductionCatalogItem requireByCode(String code);

  /// Descrição por código, para telas que só precisam do texto.
  Map<String, String> get descriptions;
}

/// Catálogo real da Vetti, embarcado como asset a partir do banco migrado.
///
/// É um retrato de 29/07/2026. O saldo aqui é um instantâneo somado por
/// produto — quando a consulta ao vivo à SB2 existir, saldo sai do catálogo e
/// vira consulta própria, por almoxarifado.
class AssetProductCatalogRepository implements ProductCatalogRepository {
  AssetProductCatalogRepository(this._items)
    : _byCode = {for (final item in _items) item.code: item};

  final List<ProductionCatalogItem> _items;
  final Map<String, ProductionCatalogItem> _byCode;

  static const assetPath = 'assets/protheus/produtos.json';

  static Future<AssetProductCatalogRepository> load() async {
    final raw = await rootBundle.loadString(assetPath);
    return AssetProductCatalogRepository(parse(raw));
  }

  /// Separado de [load] para poder ser testado sem depender do bundle.
  static List<ProductionCatalogItem> parse(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;

    // Indexa primeiro: a descrição e o saldo de um componente vêm da própria
    // lista, já que componente também é produto.
    final base = <String, Map<String, dynamic>>{};
    for (final entry in list) {
      final map = entry as Map<String, dynamic>;
      base[map['codigo'] as String] = map;
    }

    final items = <ProductionCatalogItem>[];
    for (final map in base.values) {
      final rawComponents = (map['componentes'] as List<dynamic>?) ?? const [];
      final components = rawComponents
          .map((c) {
            final comp = c as Map<String, dynamic>;
            final code = comp['componente'] as String? ?? '';
            final ref = base[code];
            return ProductionComponent(
              code: code,
              description: ref?['descricao'] as String? ?? code,
              quantity: (comp['quantidade'] as num?)?.toDouble() ?? 0,
              stock: (ref?['saldo'] as num?)?.toInt() ?? 0,
              unit: ref?['unidade'] as String? ?? '',
            );
          })
          .toList(growable: false);

      final rawSaldos = (map['saldos'] as List<dynamic>?) ?? const [];
      final saldos = rawSaldos
          .map((s) => SaldoArmazem.fromJson(s as Map<String, dynamic>))
          .toList(growable: false);

      items.add(
        ProductionCatalogItem(
          code: map['codigo'] as String? ?? '',
          name: map['descricao'] as String? ?? '',
          unit: map['unidade'] as String? ?? '',
          type: map['tipo'] as String? ?? '',
          group: map['grupo'] as String? ?? '',
          stock: (map['saldo'] as num?)?.toInt() ?? 0,
          committed: (map['empenhado'] as num?)?.toInt() ?? 0,
          components: components,
          saldos: saldos,
        ),
      );
    }

    items.sort((a, b) => a.code.compareTo(b.code));
    return items;
  }

  @override
  List<ProductionCatalogItem> get items => List.unmodifiable(_items);

  @override
  ProductionCatalogItem? findByCode(String code) => _byCode[code];

  @override
  ProductionCatalogItem requireByCode(String code) {
    final item = _byCode[code];
    if (item == null) throw ProductNotFoundException(code);
    return item;
  }

  @override
  Map<String, String> get descriptions => {
    for (final item in _items) item.code: item.name,
  };
}
