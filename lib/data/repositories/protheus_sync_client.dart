import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/repositories/api_settings.dart';

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
      (value) => value.name == json['status'],
      orElse: () => MutationStatus.erro,
    ),
    protheusRef: json['protheusRef'] as String?,
    erro: json['erro'] as String?,
  );
}

class SyncUnavailableException implements Exception {
  const SyncUnavailableException(this.motivo);

  final String motivo;

  @override
  String toString() => 'API do Protheus indisponivel: $motivo';
}

class ProtheusSyncClient {
  ProtheusSyncClient({
    required this.baseUrl,
    this.apiToken = '',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String apiToken;
  final http.Client _http;

  static const _timeout = Duration(seconds: 20);

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> _headers({bool json = false}) {
    final token = apiToken.trim().isNotEmpty
        ? apiToken.trim()
        : ApiSettings.token;
    return {
      if (json) 'Content-Type': 'application/json',
      if (token.isNotEmpty) 'X-API-Token': token,
    };
  }

  Future<bool> health() async {
    try {
      final response = await _http
          .get(_uri('/api/v1/health'), headers: _headers())
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<MutationResult>> push(List<PendingMutation> mutations) async {
    if (mutations.isEmpty) return const [];

    final http.Response response;
    try {
      response = await _http
          .post(
            _uri('/api/v1/mutations'),
            headers: _headers(json: true),
            body: jsonEncode({
              'mutations': [
                for (final mutation in mutations) mutation.toJson(),
              ],
            }),
          )
          .timeout(_timeout);
    } catch (error) {
      throw SyncUnavailableException(error.toString());
    }

    if (response.statusCode != 200) {
      throw SyncUnavailableException(
        'HTTP ${response.statusCode}: ${response.body}',
      );
    }

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (body['results'] as List<dynamic>?) ?? const [];
      return results
          .map((item) => MutationResult.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } catch (error) {
      throw SyncUnavailableException('resposta ilegivel: $error');
    }
  }

  Future<List<MutationResult>> finalizar(List<String> ids) async {
    if (ids.isEmpty) return const [];

    final http.Response response;
    try {
      response = await _http
          .post(
            _uri('/api/v1/finalizar'),
            headers: _headers(json: true),
            body: jsonEncode({'ids': ids}),
          )
          .timeout(_timeout);
    } catch (error) {
      throw SyncUnavailableException(error.toString());
    }

    if (response.statusCode != 200) {
      throw SyncUnavailableException(
        'HTTP ${response.statusCode}: ${response.body}',
      );
    }

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (body['results'] as List<dynamic>?) ?? const [];
      return results
          .map((item) => MutationResult.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } catch (error) {
      throw SyncUnavailableException('resposta ilegivel: $error');
    }
  }

  void dispose() => _http.close();
}
