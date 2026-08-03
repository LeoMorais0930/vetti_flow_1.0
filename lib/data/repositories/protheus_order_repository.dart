import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/protheus_order.dart';

/// Fonte das ordens de produção — o Protheus, via SC2.
///
/// Somente leitura por decisão de arquitetura: o dono da OP é o ERP. O
/// VettiFlow lê daqui e acrescenta o fluxo de etapas em volta.
///
/// O VettiFlow enxerga **todas** as OPs, mas "ver todas" é consulta, não
/// carregamento: quem entra no store de fluxo são apenas as OPs adotadas.
abstract class ProtheusOrderRepository {
  /// Todas as OPs de **todas as filiais**, encerradas inclusive.
  ///
  /// Não use para montar tela: quem opera está em uma filial e não pode ver a
  /// OP da outra. Para tela, use [openIn].
  List<ProtheusOrder> get all;

  /// Só as que podem ser operadas (C2_DATRF vazio), de todas as filiais.
  /// Mesma ressalva de [all].
  List<ProtheusOrder> get open;

  /// As operáveis de uma filial. O Protheus numera OP por filial, então "OP
  /// 015942" só é identidade completa junto com a filial.
  List<ProtheusOrder> openIn(String filial);

  ProtheusOrder? byKey(ProtheusOrderKey key);

  /// Busca por número, produto ou descrição do produto.
  ///
  /// Passe [filial] para restringir ao que a filial corrente enxerga; sem ela a
  /// busca varre a empresa inteira.
  List<ProtheusOrder> search(
    String term, {
    String? filial,
    bool onlyOpen = true,
    int limit = 50,
  });
}

/// Implementação que lê o recorte do banco migrado embarcado como asset.
///
/// É um retrato de 29/07/2026, não um espelho ao vivo. Quando a API do
/// VettiFlow existir, ela entra no lugar desta classe sem que as telas mudem.
class AssetProtheusOrderRepository implements ProtheusOrderRepository {
  AssetProtheusOrderRepository(
    this._orders, {
    Map<String, String>? descriptions,
  }) : _descriptions = descriptions ?? const {};

  final List<ProtheusOrder> _orders;
  final Map<String, String> _descriptions;

  static const assetPath = 'assets/protheus/ordens.json';

  static Future<List<ProtheusOrder>> loadOrders() async {
    return parseOrders(await rootBundle.loadString(assetPath));
  }

  /// Separado de [loadOrders] para poder ser testado sem depender do bundle.
  static List<ProtheusOrder> parseOrders(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => ProtheusOrder.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  List<ProtheusOrder> get all => List.unmodifiable(_orders);

  @override
  List<ProtheusOrder> get open =>
      _orders.where((o) => !o.closed).toList(growable: false);

  @override
  List<ProtheusOrder> openIn(String filial) => _orders
      .where((o) => !o.closed && o.key.filial == filial)
      .toList(growable: false);

  @override
  ProtheusOrder? byKey(ProtheusOrderKey key) {
    for (final order in _orders) {
      if (order.key == key) return order;
    }
    return null;
  }

  @override
  List<ProtheusOrder> search(
    String term, {
    String? filial,
    bool onlyOpen = true,
    int limit = 50,
  }) {
    final needle = term.trim().toLowerCase();
    var source = onlyOpen ? open : _orders;
    if (filial != null) {
      source = source
          .where((o) => o.key.filial == filial)
          .toList(growable: false);
    }
    if (needle.isEmpty) return source.take(limit).toList(growable: false);

    final hits = <ProtheusOrder>[];
    for (final order in source) {
      final description = (_descriptions[order.productCode] ?? '')
          .toLowerCase();
      if (order.displayNumber.toLowerCase().contains(needle) ||
          order.productCode.toLowerCase().contains(needle) ||
          description.contains(needle)) {
        hits.add(order);
        if (hits.length >= limit) break;
      }
    }
    return hits;
  }
}
