import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:vetti_flow_1_0/data/models/protheus_empenho.dart';

/// Fonte dos empenhos das OPs — o Protheus, via SD4.
///
/// O retrato embarcado traz só as OPs em aberto: empenho de OP encerrada não
/// pode ser alterado, então carregá-lo seria peso morto.
///
/// Este repositório é o **retrato**; o que o operador alterou vive na
/// `PendingMutationStore`, e é ela que projeta um sobre o outro.
abstract class EmpenhoRepository {
  /// Empenhos de uma OP, na chave concatenada (número + item + sequência).
  ///
  /// [filial] restringe ao que aquela filial enxerga. Hoje o número da OP não
  /// se repete entre filiais no recorte embarcado, mas o Protheus numera **por
  /// filial**: sem esse filtro, o dia em que repetir, uma filial passa a ver o
  /// empenho da outra sem nenhum sinal de que isso aconteceu.
  List<ProtheusEmpenho> byOp(String op, {String? filial});

  /// Todas as OPs que têm empenho carregado.
  Set<String> get opsComEmpenho;
}

class AssetEmpenhoRepository implements EmpenhoRepository {
  AssetEmpenhoRepository(List<ProtheusEmpenho> empenhos)
    : _porOp = _agrupar(empenhos);

  final Map<String, List<ProtheusEmpenho>> _porOp;

  static const assetPath = 'assets/protheus/empenhos.json';

  static Future<AssetEmpenhoRepository> load() async {
    return AssetEmpenhoRepository(parse(await rootBundle.loadString(assetPath)));
  }

  /// Separado de [load] para poder ser testado sem depender do bundle.
  static List<ProtheusEmpenho> parse(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => ProtheusEmpenho.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  static Map<String, List<ProtheusEmpenho>> _agrupar(
    List<ProtheusEmpenho> empenhos,
  ) {
    final mapa = <String, List<ProtheusEmpenho>>{};
    for (final e in empenhos) {
      mapa.putIfAbsent(e.op, () => []).add(e);
    }
    for (final linhas in mapa.values) {
      linhas.sort((a, b) => a.produto.compareTo(b.produto));
    }
    return mapa;
  }

  @override
  List<ProtheusEmpenho> byOp(String op, {String? filial}) {
    final linhas = _porOp[op] ?? const <ProtheusEmpenho>[];
    if (filial == null) return List.unmodifiable(linhas);
    return List.unmodifiable(linhas.where((e) => e.filial == filial));
  }

  @override
  Set<String> get opsComEmpenho => _porOp.keys.toSet();
}
