import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:vetti_flow_1_0/data/models/protheus_empenho.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_sync_client.dart';

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

/// Retrato do asset, atualizado ao vivo quando a API responde.
///
/// [refresh] busca o empenho real (SD4) de **uma** OP só — é assim que o
/// editor de empenho conhece o estado atual antes de a Gestora editar. Se a
/// API estiver fora do alcance, mantém o retrato anterior daquela OP e liga
/// [usandoRetratoDesatualizado] em vez de travar a tela. Ver
/// [HybridProtheusOrderRepository] para o mesmo padrão aplicado à lista de OPs.
class HybridEmpenhoRepository extends ChangeNotifier
    implements EmpenhoRepository {
  HybridEmpenhoRepository(
    List<ProtheusEmpenho> inicial, {
    required ProtheusSyncClient client,
  }) // `this._client` exporia o nome privado do campo na chamada.
    // ignore: prefer_initializing_formals
    : _client = client,
      _todasLinhas = [...inicial],
      _atual = AssetEmpenhoRepository(inicial);

  final ProtheusSyncClient _client;
  final List<ProtheusEmpenho> _todasLinhas;
  AssetEmpenhoRepository _atual;

  bool _usandoRetratoDesatualizado = false;
  String? _ultimoErro;

  bool get usandoRetratoDesatualizado => _usandoRetratoDesatualizado;

  String? get ultimoErro => _ultimoErro;

  /// Busca o empenho de [op] na API e substitui só as linhas dessa OP — o
  /// resto do retrato (outras OPs) fica como estava.
  Future<void> refresh(String op, String filial) async {
    try {
      final linhas = await _client.empenhosDaOp(op, filial: filial);
      _todasLinhas
        ..removeWhere((e) => e.op == op)
        ..addAll(linhas);
      _atual = AssetEmpenhoRepository(_todasLinhas);
      _usandoRetratoDesatualizado = false;
      _ultimoErro = null;
    } on SyncUnavailableException catch (e) {
      _usandoRetratoDesatualizado = true;
      _ultimoErro = e.motivo;
    }
    notifyListeners();
  }

  @override
  List<ProtheusEmpenho> byOp(String op, {String? filial}) =>
      _atual.byOp(op, filial: filial);

  @override
  Set<String> get opsComEmpenho => _atual.opsComEmpenho;
}
