// =============================================================================
// api_exception.dart - MODELO DE ERRO DO APP
// =============================================================================
//
// CONCEITO - excecao: quando algo da errado, o codigo "lanca" (`throw`) um
// objeto de erro. Quem chamou pode "pegar" (`try/catch`) e mostrar uma mensagem.
// Aqui TODA falha de rede/HTTP vira uma `ApiException`, para que as telas
// tratem um unico tipo de erro.
// =============================================================================

// jsonDecode: transforma texto JSON em Map/List do Dart.
import 'dart:convert';

// Usado para citar o timeout e a baseUrl nas mensagens de erro.
import 'api_config.dart';

/// Um erro de validacao em um campo especifico.
///
/// Espelha `FieldViolation` de `exception/ApiErrorResponse.kt`. O `field` e o
/// nome da propriedade do DTO (`titulo`, `cpf`, `participanteId`, ...).
class FieldViolation {
  /// `required` obriga a informar o parametro nomeado; `this.field` ja guarda
  /// o valor no campo de mesmo nome.
  const FieldViolation({required this.field, required this.message});

  /// Nome do campo com problema (ex.: "cpf").
  final String field;

  /// Mensagem em portugues vinda do back-end (ex.: "CPF invalido").
  final String message;

  /// Constroi a partir de um JSON ja decodificado (`Map<String, dynamic>` =
  /// dicionario de chave texto para qualquer valor).
  /// `factory` = construtor que pode montar o objeto do jeito que quiser.
  /// `??` usa o valor da direita se o da esquerda for nulo.
  factory FieldViolation.fromJson(Map<String, dynamic> json) => FieldViolation(
    field: (json['field'] ?? '').toString(),
    message: (json['message'] ?? 'Valor invalido').toString(),
  );
}

/// Erro vindo da API, de rede, ou de timeout.
///
/// Toda a API responde erro com o mesmo envelope (`GlobalExceptionHandler`):
///
/// ```json
/// {"timestamp":"...","status":400,"error":"Bad Request",
///  "message":"Dados invalidos na requisicao","path":"/participantes",
///  "fieldErrors":[{"field":"cpf","message":"CPF invalido"}]}
/// ```
///
/// As mensagens vem em portugues do proprio back-end, por isso sao exibidas
/// como estao em vez de serem reescritas no cliente.
/// `implements Exception` marca a classe como uma excecao do Dart.
class ApiException implements Exception {
  /// Construtor principal. Parametros com valor padrao (`= ...`) sao opcionais.
  ApiException({
    required this.message,
    this.status,
    this.path,
    this.fieldErrors = const <FieldViolation>[],
    this.kind = ApiErrorKind.http,
  });

  /// Texto para mostrar ao usuario.
  final String message;

  /// Codigo HTTP (400, 401, 404...). Nulo em erros de rede/timeout.
  final int? status;

  /// Rota que falhou (ex.: "/evento").
  final String? path;

  /// Erros por campo, usados para mostrar erro dentro do formulario.
  final List<FieldViolation> fieldErrors;

  /// Categoria do erro (http, rede, timeout...).
  final ApiErrorKind kind;

  // Getters de conveniencia: respondem "e esse tipo de erro?" lendo o status.
  bool get isNotFound => status == 404;
  bool get isConflict => status == 409;
  bool get isBadRequest => status == 400;

  /// `status!` afirma nao-nulo; o `status != null &&` antes garante isso.
  bool get isServerError => status != null && status! >= 500;
  bool get hasFieldErrors => fieldErrors.isNotEmpty;

  /// Sem token, token vencido ou credenciais erradas no login.
  bool get isUnauthorized => status == 401;

  /// Logado, mas o papel nao permite a operacao.
  bool get isForbidden => status == 403;

  /// Mensagem do erro de um campo, ou `null` se o campo passou.
  String? forField(String field) {
    // `for ... in` percorre cada elemento da lista.
    for (final v in fieldErrors) {
      if (v.field == field) return v.message;
    }
    return null;
  }

  /// Le o envelope de erro da API. Se o corpo nao for o JSON esperado
  /// (um 502 do proxy, um HTML de erro do host), cai para uma mensagem generica.
  factory ApiException.fromResponse(int status, String body, String path) {
    try {
      // Converte o texto em estrutura Dart (Map, List...).
      final decoded = jsonDecode(body);
      // `is Map<...>` testa o tipo e ja "promove" a variavel para esse tipo.
      if (decoded is Map<String, dynamic>) {
        final raw = decoded['fieldErrors'];
        // Se for lista: filtra so os itens Map, converte cada um em
        // FieldViolation e fecha em lista imutavel (`growable: false`).
        final violations = raw is List
            ? raw
                  .whereType<Map<String, dynamic>>()
                  .map(FieldViolation.fromJson)
                  .toList(growable: false)
            : const <FieldViolation>[];
        // Mensagem: prefere `message`, depois `error`, senao vazio.
        final message = (decoded['message'] ?? decoded['error'] ?? '')
            .toString();
        return ApiException(
          status: status,
          // Usa o `path` que o servidor mandou, ou o nosso se faltar.
          path: (decoded['path'] ?? path).toString(),
          // Se vier vazia (401/403 do filtro de seguranca tem corpo vazio),
          // usa a mensagem generica por status.
          message: message.isEmpty ? _genericFor(status) : message,
          fieldErrors: violations,
        );
      }
    } on FormatException {
      // Corpo nao e JSON: segue para a mensagem generica.
    }
    // Chegou aqui: corpo vazio, nao-JSON ou JSON de outro formato.
    return ApiException(
      status: status,
      path: path,
      message: _genericFor(status),
    );
  }

  /// Falha de conexao (sem internet, CORS bloqueado, servidor fora do ar).
  factory ApiException.network(String path) => ApiException(
    kind: ApiErrorKind.network,
    path: path,
    // Textos vizinhos entre aspas sao juntados pelo Dart em um so.
    message:
        'Não foi possível falar com a API. Verifique sua conexão com a '
        'internet. Rodando localmente? O site precisa estar em uma origem '
        'liberada no CORS da API: http://localhost:5173 ou '
        'http://localhost:3000.',
  );

  /// A API demorou mais que `ApiConfig.timeout`.
  factory ApiException.timeout(String path) => ApiException(
    kind: ApiErrorKind.timeout,
    path: path,
    // `${...}` insere o valor de uma expressao dentro do texto.
    message:
        'A API não respondeu em ${ApiConfig.timeout.inSeconds} '
        'segundos. O servidor gratuito hiberna quando fica sem uso e pode '
        'levar alguns minutos para acordar. Tente de novo.',
  );

  /// Resposta de sucesso, mas com corpo que nao e JSON valido.
  factory ApiException.badPayload(String path) => ApiException(
    kind: ApiErrorKind.payload,
    path: path,
    message: 'A API respondeu em um formato inesperado.',
  );

  /// A requisicao nunca chegou a API: voltou uma pagina HTML.
  ///
  /// Acontece quando [ApiConfig.baseUrl] aponta para o servidor de arquivos do
  /// proprio site (um caminho relativo sem proxy, por exemplo), que por ser um
  /// servidor de SPA responde `index.html` com status 200 em vez de 404.
  factory ApiException.misrouted(String path) => ApiException(
    kind: ApiErrorKind.misrouted,
    path: path,
    message:
        'A requisição não chegou à API: voltou uma página HTML em vez de '
        'JSON. Verifique se "${ApiConfig.baseUrl}" é realmente o endereço da '
        'API (configurável com --dart-define=API_BASE_URL).',
  );

  /// Mensagem padrao por codigo HTTP.
  ///
  /// CONCEITO - `switch` como expressao: cada `padrao => valor` e um caso;
  /// `>= 500` casa qualquer numero a partir de 500; `_` e o "qualquer outro".
  static String _genericFor(int status) => switch (status) {
    400 => 'Requisição inválida.',
    401 => 'Sua sessão expirou ou você não está autenticado. Entre novamente.',
    403 => 'Você não tem permissão para esta operação.',
    404 => 'Recurso não encontrado.',
    405 => 'Esta operação não está disponível nesta versão da API.',
    409 => 'Conflito de dados.',
    >= 500 => 'Erro interno do servidor.',
    _ => 'Falha na requisição (HTTP $status).',
  };

  /// Texto usado em logs/depuracao (o que aparece ao imprimir o erro).
  @override
  String toString() => 'ApiException($status): $message';
}

/// Categorias de falha.
///
/// CONCEITO - `enum`: conjunto fixo de valores nomeados.
enum ApiErrorKind {
  /// A API respondeu com status de erro (4xx/5xx).
  http,

  /// Sem conexao / bloqueio de CORS.
  network,

  /// Estourou o tempo limite.
  timeout,

  /// Resposta ilegivel.
  payload,

  /// O pedido nao chegou a API (endereco errado).
  misrouted,
}
