import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';

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

/// Leva a fila de mutações até o Protheus.
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

  void dispose() => _http.close();
}
