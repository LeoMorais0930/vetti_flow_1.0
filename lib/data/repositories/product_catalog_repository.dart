import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:vetti_flow_1_0/data/models/production_flow.dart';
import 'package:vetti_flow_1_0/data/models/warehouse.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_sync_client.dart';

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
      // A SG1 traz o mesmo componente em mais de uma linha quando ele aparece
      // em posições diferentes da montagem (o 441-062 do 500-0001 vem como 4 e
      // depois 1). Para empenhar, o que vale é o total por componente: 5.
      //
      // Consolidar aqui, e não em quem consome, é o que mantém o contrato de
      // que o par produto+almoxarifado é único numa lista de empenho —
      // EmpenhoEditor usa esse par como chave de widget e como Set de
      // "já presentes", e linha repetida derruba a lista inteira em runtime.
      final rawComponents = (map['componentes'] as List<dynamic>?) ?? const [];
      final quantidadePorCodigo = <String, double>{};
      for (final c in rawComponents) {
        final comp = c as Map<String, dynamic>;
        final code = comp['componente'] as String? ?? '';
        quantidadePorCodigo[code] =
            (quantidadePorCodigo[code] ?? 0) +
            ((comp['quantidade'] as num?)?.toDouble() ?? 0);
      }
      final components = [
        for (final entry in quantidadePorCodigo.entries)
          ProductionComponent(
            code: entry.key,
            description: base[entry.key]?['descricao'] as String? ?? entry.key,
            quantity: entry.value,
            stock: (base[entry.key]?['saldo'] as num?)?.toInt() ?? 0,
            unit: base[entry.key]?['unidade'] as String? ?? '',
          ),
      ];

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
          // Retrato antigo não tem o campo: sem informação, o produto continua
          // buscável. Bloquear por omissão sumiria com o catálogo inteiro.
          blocked: map['bloqueado'] as bool? ?? false,
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

/// Cadastro embarcado, com saldo (SB2) atualizado ao vivo produto a produto.
///
/// Nome, unidade e estrutura (SB1/SG1) continuam vindo do retrato embarcado —
/// mudam raramente, e reextrair isso ao vivo a cada busca de produto seria
/// custo sem ganho. O que precisa ser ao vivo é o saldo: é ele que diz se dá
/// para empenhar mais um componente, e ficar velho aqui é o tipo de erro que
/// só aparece quando alguém já mexeu na peça errada.
///
/// [refreshSaldo] busca só o produto pedido — não existe "atualizar o
/// catálogo inteiro", ele tem centenas de itens e a tela só precisa de um de
/// cada vez. Se a API estiver fora do alcance, mantém o saldo anterior
/// daquele produto e liga [usandoRetratoDesatualizado].
class HybridProductCatalogRepository extends ChangeNotifier
    implements ProductCatalogRepository {
  HybridProductCatalogRepository(
    List<ProductionCatalogItem> inicial, {
    required ProtheusSyncClient client,
  }) // `this._client` exporia o nome privado do campo na chamada.
    // ignore: prefer_initializing_formals
    : _client = client,
      _byCode = {for (final item in inicial) item.code: item};

  final ProtheusSyncClient _client;
  final Map<String, ProductionCatalogItem> _byCode;

  bool _usandoRetratoDesatualizado = false;
  String? _ultimoErro;

  bool get usandoRetratoDesatualizado => _usandoRetratoDesatualizado;

  String? get ultimoErro => _ultimoErro;

  /// Busca o saldo de [produto] na filial e sobrepõe só essa parte do item.
  /// Sem efeito se o produto não existir no catálogo — não há o que
  /// sobrepor.
  Future<void> refreshSaldo(String produto, String filial) async {
    final atual = _byCode[produto];
    if (atual == null) return;
    try {
      final saldosFrescos = await _client.saldosDoProduto(
        produto,
        filial: filial,
      );
      final deOutrasFiliais = atual.saldos.where((s) => s.filial != filial);
      _byCode[produto] = atual.copyWith(
        saldos: [...deOutrasFiliais, ...saldosFrescos],
      );
      _usandoRetratoDesatualizado = false;
      _ultimoErro = null;
    } on SyncUnavailableException catch (e) {
      _usandoRetratoDesatualizado = true;
      _ultimoErro = e.motivo;
    }
    notifyListeners();
  }

  @override
  List<ProductionCatalogItem> get items => List.unmodifiable(_byCode.values);

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
    for (final item in _byCode.values) item.code: item.name,
  };
}
