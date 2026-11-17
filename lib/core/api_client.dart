// =============================================================================
// api_client.dart - UNICO PONTO DE REDE DO APP
// =============================================================================
//
// Toda chamada HTTP do app passa por aqui. Os repositorios chamam
// `client.get('/evento')`, `client.post(...)` etc. e recebem o JSON ja
// decodificado (Map/List) ou uma `ApiException`.
// =============================================================================

// Traz `Future` (valor que chega depois) e `TimeoutException` (estouro de
// tempo limite).
import 'dart:async';
// Traz `utf8` (converte bytes em texto) e `jsonEncode/jsonDecode` (converte
// objeto <-> texto JSON).
import 'dart:convert';

// Pacote `http`: cliente HTTP simples para falar com a API. `as http` da um
// apelido, para escrever `http.Client` e nao misturar nomes com outras coisas.
import 'package:http/http.dart' as http;

// Constantes de rede (URL base e timeout).
import 'api_config.dart';
// Tipo de erro unico do app: toda falha vira uma `ApiException`.
import 'api_exception.dart';

/// Unico ponto do app que fala HTTP.
///
/// Concentra o que nao deve ser repetido em cada repositorio: montagem da URL,
/// o header `Authorization`, timeout, decodificacao UTF-8 e traducao de
/// qualquer falha para [ApiException].
class ApiClient {
  /// [client] opcional: os testes passam um `MockClient` que devolve respostas
  /// prontas, sem rede de verdade. `??` cria o cliente real se vier nulo.
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  /// Cliente HTTP que de fato envia os pedidos (privado ao arquivo).
  final http.Client _client;

  /// Devolve o token JWT atual, ou `null` se ninguem estiver logado.
  ///
  /// Preenchido por `Services`, que liga o cliente a `Sessao`. Fica como
  /// callback (e nao como campo com o token) para que cada requisicao leia o
  /// valor do momento, inclusive depois de um novo login.
  /// O tipo `String? Function()?` le-se: "funcao sem parametros que devolve
  /// texto anulavel", e a propria variavel tambem pode ser nula.
  String? Function()? tokenProvider;

  /// Chamado quando uma requisicao **autenticada** volta 401: o token expirou
  /// ou foi invalidado. A sessao usa isso para voltar a tela de login.
  ///
  /// O 401 do proprio `POST /auth/login` (senha errada) nao dispara isto,
  /// porque nesse pedido ainda nao ha token.
  void Function()? onUnauthorized;

  /// Libera os recursos do cliente HTTP (fecha conexoes abertas).
  void close() => _client.close();

  // Os 5 metodos abaixo sao atalhos: cada um chama `_send` com o verbo HTTP.
  // `Future<dynamic>`: resultado futuro de tipo variavel (o JSON decodificado,
  // que pode ser Map, List...).

  /// GET: le dados. [query] vira `?chave=valor` na URL.
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  /// POST: cria um recurso (o [body] vai como JSON).
  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  /// PUT: substitui um recurso inteiro.
  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  /// PATCH: altera so uma parte de um recurso.
  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  /// DELETE: remove. Nao devolve nada (`Future<void>`).
  Future<void> delete(String path) async => _send('DELETE', path);

  /// Nucleo: monta, envia e interpreta uma requisicao.
  /// `async` permite usar `await` aqui dentro (esperar a rede sem travar a
  /// tela).
  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    // 1) Monta a URL completa (base + caminho + query string).
    final uri = resolve(path, query);
    // 2) Cria a requisicao com o verbo (GET, POST...) e a URL.
    final request = http.Request(method, uri);
    // Pede resposta em JSON (cabecalho `Accept`).
    request.headers['Accept'] = 'application/json';

    // 3) Anexa o token JWT, se houver alguem logado.
    // `?.call()` chama a funcao so se `tokenProvider` existir.
    final token = tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      // Formato padrao "Bearer <token>" esperado pelo Spring Security.
      request.headers['Authorization'] = 'Bearer $token';
    }

    // 4) Se ha corpo, envia como JSON em UTF-8.
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      // `jsonEncode` converte Map/List em texto JSON.
      request.body = jsonEncode(body);
    }

    // 5) Envia e espera. A variavel e declarada aqui e recebe valor dentro do
    // `try` (o Dart garante que so e lida depois de preenchida).
    final http.Response response;
    try {
      // `send` devolve a resposta em fluxo (stream); `.timeout` aborta se
      // passar do limite (180 s, por causa do cold start do servidor gratis).
      final streamed = await _client.send(request).timeout(ApiConfig.timeout);
      // Junta o fluxo em uma resposta completa (status, headers, bytes).
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      // `on Tipo` captura so esse tipo de excecao: passou do tempo limite.
      throw ApiException.timeout(path);
    } on http.ClientException {
      // Falha de conexao/CORS: o navegador nao diz qual dos dois foi.
      throw ApiException.network(path);
    }

    // A API responde em UTF-8, mas sem `charset` no Content-Type em algumas
    // rotas; `response.body` cairia em latin-1 e quebraria os acentos.
    // `bodyBytes` sao os bytes crus; `allowMalformed` troca bytes invalidos por
    // um caractere substituto em vez de lancar erro.
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);

    // 6) Status 400 ou maior = erro (4xx = culpa do pedido, 5xx = do servidor).
    if (response.statusCode >= 400) {
      // 401 COM token = sessao venceu: avisa a Sessao.
      if (response.statusCode == 401 && token != null) onUnauthorized?.call();
      // Converte o envelope de erro da API em ApiException e lanca.
      throw ApiException.fromResponse(response.statusCode, text, path);
    }

    // 7) Sucesso sem corpo (204 No Content) => nao ha nada a devolver.
    if (response.statusCode == 204 || text.trim().isEmpty) return null;

    // 8) Sucesso com corpo: decodifica o JSON.
    try {
      // `jsonDecode` transforma o texto em Map/List/numero/texto do Dart.
      return jsonDecode(text);
    } on FormatException {
      // Corpo que nao e JSON com status de sucesso quase sempre significa que o
      // pedido nao chegou a API e foi atendido por um servidor de arquivos.
      if (_parecePaginaHtml(text)) throw ApiException.misrouted(path);
      throw ApiException.badPayload(path);
    }
  }

  /// Heuristica (palpite): o texto comeca como uma pagina HTML?
  static bool _parecePaginaHtml(String corpo) {
    // Remove espacos do inicio e passa para minusculas, para comparar.
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
    // Tira a barra final da base para nao gerar "//" ao concatenar.
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    // `$base$path` = interpolacao de texto (junta as duas partes).
    final full = '$base$path';
    // Base absoluta (http...) vira Uri direto; relativa usa a origem da pagina
    // (`Uri.base` = endereco da pagina aberta no navegador).
    var uri = base.startsWith('http')
        ? Uri.parse(full)
        : Uri.base.resolve(full);

    if (query != null) {
      // Valores nulos sao filtros nao aplicados: a API trata parametro ausente
      // como "ignorar este filtro", entao nunca mandamos a chave vazia.
      final params = <String, dynamic>{};
      // `forEach` percorre cada par chave/valor do mapa.
      query.forEach((key, value) {
        // Dentro de uma funcao anonima, `return;` so sai dela (pula este item).
        if (value == null) return;
        if (value is Iterable) {
          // Lista vira parametro repetido (?status=A&status=B).
          final items = value.map((e) => e.toString()).toList(growable: false);
          if (items.isNotEmpty) params[key] = items;
        } else {
          // Numero, booleano etc. viram texto.
          params[key] = value.toString();
        }
      });
      if (params.isNotEmpty) {
        // `replace` devolve uma nova Uri com a query string preenchida e
        // com os caracteres especiais codificados corretamente.
        uri = uri.replace(queryParameters: params);
      }
    }
    return uri;
  }
}
