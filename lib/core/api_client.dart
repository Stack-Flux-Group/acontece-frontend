import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';

/// Unico ponto do app que fala HTTP.
///
/// Concentra o que nao deve ser repetido em cada repositorio: montagem da URL,
/// o header `Authorization`, timeout, decodificacao UTF-8 e traducao de
/// qualquer falha para [ApiException].
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Devolve o token JWT atual, ou `null` se ninguem estiver logado.
  ///
  /// Preenchido por `Services`, que liga o cliente a `Sessao`. Fica como
  /// callback (e nao como campo com o token) para que cada requisicao leia o
  /// valor do momento, inclusive depois de um novo login.
  String? Function()? tokenProvider;

  /// Chamado quando uma requisicao **autenticada** volta 401: o token expirou
  /// ou foi invalidado. A sessao usa isso para voltar a tela de login.
  ///
  /// O 401 do proprio `POST /auth/login` (senha errada) nao dispara isto,
  /// porque nesse pedido ainda nao ha token.
  void Function()? onUnauthorized;

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

    final token = tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      final streamed = await _client.send(request).timeout(ApiConfig.timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException.timeout(path);
    } on http.ClientException {
      throw ApiException.network(path);
    }

    // A API responde em UTF-8, mas sem `charset` no Content-Type em algumas
    // rotas; `response.body` cairia em latin-1 e quebraria os acentos.
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);

    if (response.statusCode >= 400) {
      if (response.statusCode == 401 && token != null) onUnauthorized?.call();
      throw ApiException.fromResponse(response.statusCode, text, path);
    }

    if (response.statusCode == 204 || text.trim().isEmpty) return null;

    try {
      return jsonDecode(text);
    } on FormatException {
      // Corpo que nao e JSON com status de sucesso quase sempre significa que o
      // pedido nao chegou a API e foi atendido por um servidor de arquivos.
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
  /// Com [ApiConfig.baseUrl] absoluto, usa a base como esta; relativo, resolve
  /// contra a origem da pagina.
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
