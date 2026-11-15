import 'dart:convert';

import 'api_config.dart';

/// Um erro de validacao em um campo especifico.
///
/// Espelha `FieldViolation` de `exception/ApiErrorResponse.kt`. O `field` e o
/// nome da propriedade do DTO (`titulo`, `cpf`, `participanteId`, ...).
class FieldViolation {
  const FieldViolation({required this.field, required this.message});

  final String field;
  final String message;

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
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.status,
    this.path,
    this.fieldErrors = const <FieldViolation>[],
    this.kind = ApiErrorKind.http,
  });

  final String message;
  final int? status;
  final String? path;
  final List<FieldViolation> fieldErrors;
  final ApiErrorKind kind;

  bool get isNotFound => status == 404;
  bool get isConflict => status == 409;
  bool get isBadRequest => status == 400;
  bool get isServerError => status != null && status! >= 500;
  bool get hasFieldErrors => fieldErrors.isNotEmpty;

  /// Sem token, token vencido ou credenciais erradas no login.
  bool get isUnauthorized => status == 401;

  /// Logado, mas o papel nao permite a operacao.
  bool get isForbidden => status == 403;

  /// Mensagem do erro de um campo, ou `null` se o campo passou.
  String? forField(String field) {
    for (final v in fieldErrors) {
      if (v.field == field) return v.message;
    }
    return null;
  }

  /// Le o envelope de erro da API. Se o corpo nao for o JSON esperado
  /// (um 502 do proxy, um HTML de erro do host), cai para uma mensagem generica.
  factory ApiException.fromResponse(int status, String body, String path) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final raw = decoded['fieldErrors'];
        final violations = raw is List
            ? raw
                  .whereType<Map<String, dynamic>>()
                  .map(FieldViolation.fromJson)
                  .toList(growable: false)
            : const <FieldViolation>[];
        final message = (decoded['message'] ?? decoded['error'] ?? '')
            .toString();
        return ApiException(
          status: status,
          path: (decoded['path'] ?? path).toString(),
          message: message.isEmpty ? _genericFor(status) : message,
          fieldErrors: violations,
        );
      }
    } on FormatException {
      // Corpo nao e JSON: segue para a mensagem generica.
    }
    return ApiException(
      status: status,
      path: path,
      message: _genericFor(status),
    );
  }

  factory ApiException.network(String path) => ApiException(
    kind: ApiErrorKind.network,
    path: path,
    message:
        'Não foi possível falar com a API. Verifique sua conexão com a '
        'internet. Rodando localmente? O site precisa estar em uma origem '
        'liberada no CORS da API: http://localhost:5173 ou '
        'http://localhost:3000.',
  );

  factory ApiException.timeout(String path) => ApiException(
    kind: ApiErrorKind.timeout,
    path: path,
    message:
        'A API não respondeu em ${ApiConfig.timeout.inSeconds} '
        'segundos. O servidor gratuito hiberna quando fica sem uso e pode '
        'levar alguns minutos para acordar. Tente de novo.',
  );

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

  @override
  String toString() => 'ApiException($status): $message';
}

enum ApiErrorKind {
  http,
  network,
  timeout,
  payload,

  /// O pedido nao chegou a API (endereco errado).
  misrouted,
}
