import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/models/protheus_empenho.dart';
import 'package:vetti_flow_1_0/data/models/protheus_order.dart';
import 'package:vetti_flow_1_0/data/models/warehouse.dart';

/// O que a API respondeu sobre uma mutação.
class MutationResult {
  const MutationResult({
    required this.id,
    required this.status,
    this.protheusRef,
    this.erro,
  });

  final String id;
  final MutationStatus status;
  final String? protheusRef;
  final String? erro;

  factory MutationResult.fromJson(Map<String, dynamic> json) => MutationResult(
    id: json['id'] as String? ?? '',
    status: MutationStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => MutationStatus.erro,
    ),
    protheusRef: json['protheusRef'] as String?,
    erro: json['erro'] as String?,
  );
}

/// Falha ao falar com a API — rede fora, servidor fora, resposta ilegível.
///
/// Distinta de uma mutação recusada: recusa vem dentro de uma resposta válida,
/// com motivo. Isto aqui é "não deu para perguntar".
class SyncUnavailableException implements Exception {
  const SyncUnavailableException(this.motivo);

  final String motivo;

  @override
  String toString() => 'API do Protheus indisponível: $motivo';
}

/// Fala com a API que fica entre o VettiFlow e o Protheus — nos dois
/// sentidos: leva a fila de mutações até lá (`push`/`finalizar`) e traz
/// leitura ao vivo de volta (`opsAbertas`/`empenhosDaOp`/`saldosDoProduto`),
/// desde 03/08/2026.
///
/// O transporte é a FastAPI do projeto `vetti_flow_api`, que hoje aplica as
/// mudanças na cópia migrada em PostgreSQL. Quando o Protheus de verdade
/// entrar, muda o que está atrás da API — não isto aqui.
class ProtheusSyncClient {
  ProtheusSyncClient({required this.baseUrl, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  /// Raiz da API, sem barra no fim: `http://localhost:8000`.
  final String baseUrl;

  final http.Client _http;

  static const _timeout = Duration(seconds: 20);

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// A API está no ar?
  ///
  /// Usado pela tela da fila para dizer "dá para enviar agora" sem tentar o
  /// envio e sujar a fila com erro.
  Future<bool> health() async {
    try {
      final resposta = await _http
          .get(_uri('/api/v1/health'))
          .timeout(_timeout);
      return resposta.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Envia um lote de mutações e devolve o resultado de cada uma.
  ///
  /// O lote vai inteiro numa requisição: as mutações de uma mesma OP têm ordem
  /// entre si (incluir empenho antes de alterá-lo), e mandar uma a uma abriria
  /// espaço para aplicar metade.
  ///
  /// O `id` de cada mutação é a chave de idempotência — reenviar um lote já
  /// aplicado devolve o mesmo `protheusRef` em vez de duplicar.
  ///
  /// Lança [SyncUnavailableException] se não conseguiu falar com a API.
  Future<List<MutationResult>> push(List<PendingMutation> mutations) async {
    if (mutations.isEmpty) return const [];

    final http.Response resposta;
    try {
      resposta = await _http
          .post(
            _uri('/api/v1/mutations'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'mutations': [for (final m in mutations) m.toJson()],
            }),
          )
          .timeout(_timeout);
    } catch (e) {
      throw SyncUnavailableException(e.toString());
    }

    if (resposta.statusCode != 200) {
      throw SyncUnavailableException(
        'HTTP ${resposta.statusCode}: ${resposta.body}',
      );
    }

    try {
      final corpo = jsonDecode(resposta.body) as Map<String, dynamic>;
      final results = (corpo['results'] as List<dynamic>?) ?? const [];
      return results
          .map((r) => MutationResult.fromJson(r as Map<String, dynamic>))
          .toList(growable: false);
    } catch (e) {
      throw SyncUnavailableException('resposta ilegível: $e');
    }
  }

  /// Pede à API para aplicar mutações armazenadas no Protheus.
  ///
  /// Chamado quando a Responsável finaliza a OP. A API aplica cada mutação
  /// e devolve o resultado.
  Future<List<MutationResult>> finalizar(List<String> ids) async {
    if (ids.isEmpty) return const [];

    final http.Response resposta;
    try {
      resposta = await _http
          .post(
            _uri('/api/v1/finalizar'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'ids': ids}),
          )
          .timeout(_timeout);
    } catch (e) {
      throw SyncUnavailableException(e.toString());
    }

    if (resposta.statusCode != 200) {
      throw SyncUnavailableException(
        'HTTP ${resposta.statusCode}: ${resposta.body}',
      );
    }

    try {
      final corpo = jsonDecode(resposta.body) as Map<String, dynamic>;
      final results = (corpo['results'] as List<dynamic>?) ?? const [];
      return results
          .map((r) => MutationResult.fromJson(r as Map<String, dynamic>))
          .toList(growable: false);
    } catch (e) {
      throw SyncUnavailableException('resposta ilegível: $e');
    }
  }

  /// As OPs em aberto de uma filial, ao vivo (SC2).
  ///
  /// Quem chama decide o que fazer com [SyncUnavailableException] — o padrão
  /// no app é manter o retrato anterior e avisar que pode estar desatualizado,
  /// não travar a tela.
  Future<List<ProtheusOrder>> opsAbertas({required String filial}) async {
    final corpo = await _getLista('/api/v1/ops/abertas?filial=$filial');
    return corpo
        .map((o) => ProtheusOrder.fromJson(o as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// O empenho real (SD4) de uma OP, ao vivo.
  Future<List<ProtheusEmpenho>> empenhosDaOp(
    String op, {
    required String filial,
  }) async {
    final corpo = await _getLista('/api/v1/ops/$op/empenhos?filial=$filial');
    return corpo
        .map((e) => ProtheusEmpenho.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// O saldo por armazém de um produto, ao vivo (SB2).
  ///
  /// A resposta não traz `filial` (é o próprio parâmetro da consulta) — por
  /// isso monta [SaldoArmazem] na mão em vez de usar `fromJson`.
  Future<List<SaldoArmazem>> saldosDoProduto(
    String produto, {
    required String filial,
  }) async {
    final corpo = await _getLista(
      '/api/v1/produtos/$produto/saldos?filial=$filial',
    );
    return corpo
        .map(
          (s) => SaldoArmazem(
            filial: filial,
            local: s['local'] as String? ?? '',
            saldo: (s['saldo'] as num?)?.toDouble() ?? 0,
            empenhado: (s['empenhado'] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList(growable: false);
  }

  /// GET que devolve uma lista JSON, com o mesmo tratamento de erro de
  /// [push]/[finalizar]: falha de rede ou resposta ilegível vira
  /// [SyncUnavailableException], nunca uma exceção crua de HTTP/JSON.
  Future<List<dynamic>> _getLista(String path) async {
    final http.Response resposta;
    try {
      resposta = await _http.get(_uri(path)).timeout(_timeout);
    } catch (e) {
      throw SyncUnavailableException(e.toString());
    }

    if (resposta.statusCode != 200) {
      throw SyncUnavailableException(
        'HTTP ${resposta.statusCode}: ${resposta.body}',
      );
    }

    try {
      return jsonDecode(resposta.body) as List<dynamic>;
    } catch (e) {
      throw SyncUnavailableException('resposta ilegível: $e');
    }
  }

  void dispose() => _http.close();
}
