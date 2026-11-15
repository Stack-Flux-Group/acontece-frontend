import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';

/// Unico ponto do app que fala HTTP.
///
/// Concentra o que nao deve ser repetido em cada repositorio: montagem da URL
/// (relativa, para manter a mesma origem), timeout, decodificacao UTF-8 e
/// traducao de qualquer falha para [ApiException].
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  void close() => _client.close();

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<void> delete(String path) async => _send('DELETE', path);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    final uri = resolve(path, query);
    final request = http.Request(method, uri);
    request.headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      final streamed = await _client
          .send(request)
          .timeout(ApiConfig.timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException.timeout(path);
    } on http.ClientException {
      throw ApiException.network(path);
    }

    // A API responde em UTF-8, mas sem `charset` no Content-Type em algumas
    // rotas; `response.body` cairia em latin-1 e quebraria os acentos.
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);

    if (response.statusCode == 204 || text.trim().isEmpty) {
      if (response.statusCode >= 400) {
        throw ApiException.fromResponse(response.statusCode, text, path);
      }
      return null;
    }

    if (response.statusCode >= 400) {
      throw ApiException.fromResponse(response.statusCode, text, path);
    }

    try {
      return jsonDecode(text);
    } on FormatException {
      // Corpo que nao e JSON com status de sucesso quase sempre significa que o
      // pedido nao chegou a API e foi atendido pelo servidor de arquivos do
      // site. Detectar isso aqui transforma um erro opaco em instrucao.
      if (_parecePaginaHtml(text)) throw ApiException.misrouted(path);
      throw ApiException.badPayload(path);
    }
  }

  static bool _parecePaginaHtml(String corpo) {
    final inicio = corpo.trimLeft().toLowerCase();
    return inicio.startsWith('<!doctype html') ||
        inicio.startsWith('<html') ||
        inicio.startsWith('<!doctype>');
  }

  /// Monta a URL final. Visivel para teste.
  ///
  /// Com [ApiConfig.baseUrl] relativo (`/api`), resolve contra a origem da
  /// pagina. Com base absoluta, usa a base como esta.
  static Uri resolve(String path, [Map<String, dynamic>? query]) {
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    final full = '$base$path';
    var uri = base.startsWith('http')
        ? Uri.parse(full)
        : Uri.base.resolve(full);

    if (query != null) {
      // Valores nulos sao filtros nao aplicados: a API trata parametro ausente
      // como "ignorar este filtro", entao nunca mandamos a chave vazia.
      final params = <String, dynamic>{};
      query.forEach((key, value) {
        if (value == null) return;
        if (value is Iterable) {
          final items = value.map((e) => e.toString()).toList(growable: false);
          if (items.isNotEmpty) params[key] = items;
        } else {
          params[key] = value.toString();
        }
      });
      if (params.isNotEmpty) {
        uri = uri.replace(queryParameters: params);
      }
    }
    return uri;
  }
}
