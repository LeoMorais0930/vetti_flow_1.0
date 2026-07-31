import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:vetti_flow_1_0/data/models/warehouse.dart';

/// Cadastro de almoxarifados do Protheus (NNR).
///
/// Só leitura: criar almoxarifado é ato de configuração do ERP, não de chão de
/// fábrica. O que o VettiFlow faz é mover saldo entre os que já existem.
abstract class WarehouseRepository {
  List<Armazem> get armazens;

  Armazem? byCode(String codigo);

  /// Descrição do almoxarifado, ou o próprio código quando desconhecido —
  /// nunca a descrição de outro.
  String describe(String codigo);
}

class AssetWarehouseRepository implements WarehouseRepository {
  AssetWarehouseRepository(this._armazens)
    : _byCode = {for (final a in _armazens) a.codigo: a};

  final List<Armazem> _armazens;
  final Map<String, Armazem> _byCode;

  static const assetPath = 'assets/protheus/armazens.json';

  static Future<AssetWarehouseRepository> load() async {
    return AssetWarehouseRepository(
      parse(await rootBundle.loadString(assetPath)),
    );
  }

  /// Separado de [load] para poder ser testado sem depender do bundle.
  static List<Armazem> parse(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Armazem.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  List<Armazem> get armazens => List.unmodifiable(_armazens);

  @override
  Armazem? byCode(String codigo) => _byCode[codigo];

  @override
  String describe(String codigo) => _byCode[codigo]?.descricao ?? codigo;
}
