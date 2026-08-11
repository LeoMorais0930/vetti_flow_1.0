import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vetti_flow_1_0/data/models/pending_mutation.dart';
import 'package:vetti_flow_1_0/data/repositories/api_settings.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_product_repository.dart';
import 'package:vetti_flow_1_0/data/repositories/protheus_sync_client.dart';

/// A API responde 401 sem `X-API-Token`. Estes testes prendem o cabecalho em
/// cada chamada — se um GET novo esquecer dele, a integracao com a maquina do
/// Leonardo quebra em runtime, nao aqui.
void main() {
  test('o cabecalho acompanha o token do build', () {
    // Rode das duas formas — sem define, e com:
    //   flutter test test/api_token_test.dart \
    //     --dart-define=VETTIFLOW_API_TOKEN=token-de-teste
    if (ApiSettings.token.isEmpty) {
      // Modo local: a API nao cobra credencial e so atende o loopback.
      expect(ApiSettings.headers(), isNot(contains('X-API-Token')));
      expect(ApiSettings.headers(json: true), {
        'Content-Type': 'application/json',
      });
    } else {
      expect(ApiSettings.headers()['X-API-Token'], ApiSettings.token);
      expect(ApiSettings.headers(json: true), {
        'Content-Type': 'application/json',
        'X-API-Token': ApiSettings.token,
      });
    }
  });

  test('o sync client manda os cabecalhos em health, push e finalizar', () async {
    final chamadas = <String, Map<String, String>>{};
    final client = ProtheusSyncClient(
      baseUrl: 'http://api.local',
      httpClient: MockClient((request) async {
        chamadas[request.url.path] = request.headers;
        if (request.url.path == '/api/v1/health') {
          return http.Response('{"ok":true}', 200);
        }
        return http.Response(jsonEncode({'results': const []}), 200);
      }),
    );

    await client.health();
    await client.push([
      AberturaOpMutation(
        id: 'op-1',
        filial: '04',
        autor: 'Tatiane',
        criadoEm: DateTime(2026, 8, 11),
        produto: '575-0863',
        produtoDescricao: 'SUB MEC SMART ALARM MONITORADA CENTRAL',
        quantidade: 10,
        localProducao: '05',
      ),
    ]);
    await client.finalizar(const ['op-1']);

    expect(chamadas.keys, containsAll(<String>['/api/v1/health']));
    for (final entrada in chamadas.entries) {
      // `MockClient` normaliza os nomes para minusculo.
      expect(
        entrada.value.containsKey('x-api-token'),
        ApiSettings.token.isNotEmpty,
        reason: 'cabecalho errado em ${entrada.key}',
      );
    }
  });

  test('o repositorio de produtos manda os cabecalhos nas buscas', () async {
    final caminhos = <String>[];
    final repository = ApiProtheusProductRepository(
      baseUrl: 'http://api.local',
      httpClient: MockClient((request) async {
        caminhos.add(request.url.path);
        expect(
          request.headers.containsKey('x-api-token'),
          ApiSettings.token.isNotEmpty,
          reason: 'cabecalho errado em ${request.url.path}',
        );
        return http.Response('[]', 200);
      }),
    );

    await repository.searchProducts('575');
    expect(caminhos, ['/api/v1/produtos']);
  });
}
