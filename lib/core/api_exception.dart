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

  /// A rota nao existe nesta build da API (e nao "o registro nao existe").
  ///
  /// O deploy atual responde `404 "No static resource inscricoes."` porque o
  /// modulo de inscricoes ainda nao foi publicado. Distinguir os dois casos
  /// evita mostrar "nao encontrado" quando o certo e "modulo indisponivel".
  bool get isMissingEndpoint =>
      status == 404 && message.toLowerCase().contains('no static resource');

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
        'Nao foi possivel falar com a API. Verifique se o proxy de '
        'desenvolvimento esta rodando (node tools/dev_proxy.mjs).',
  );

  factory ApiException.timeout(String path) => ApiException(
    kind: ApiErrorKind.timeout,
    path: path,
    message:
        'A API nao respondeu em ${ApiConfig.timeout.inSeconds} '
        'segundos. A instancia gratuita do Render hiberna e pode levar '
        'alguns minutos para acordar.',
  );

  factory ApiException.badPayload(String path) => ApiException(
    kind: ApiErrorKind.payload,
    path: path,
    message: 'A API respondeu em um formato inesperado.',
  );

  /// A requisicao nunca chegou a API: voltou uma pagina HTML.
  ///
  /// O sintoma e sempre o mesmo. O app pede `/api/...`, um caminho relativo, e
  /// se nao houver nada repassando esse prefixo o pedido cai no servidor de
  /// arquivos do proprio site, que por ser um servidor de SPA responde
  /// `index.html` com status 200 em vez de 404. Sem distinguir esse caso, o erro
  /// aparece como "formato inesperado", que nao diz o que fazer.
  factory ApiException.misrouted(String path) => ApiException(
    kind: ApiErrorKind.misrouted,
    path: path,
    message: ApiConfig.isSameOrigin
        ? 'A requisicao nao chegou a API: voltou uma pagina HTML em vez de '
              'JSON.\n\nEm desenvolvimento isso quer dizer que o endereco '
              'aberto e o do servidor do Flutter, e nao o do proxy. Abra '
              'http://localhost:8081 e confirme que "node tools/dev_proxy.mjs" '
              'esta rodando.\n\nEm producao, falta a regra de rewrite de '
              '/api/* para a API no host do site.'
        : 'A requisicao nao chegou a API: voltou uma pagina HTML em vez de '
              'JSON. Verifique se ${ApiConfig.baseUrl} e realmente o endereco '
              'da API.',
  );

  static String _genericFor(int status) => switch (status) {
    400 => 'Requisicao invalida.',
    404 => 'Recurso nao encontrado.',
    405 => 'Esta operacao nao esta disponivel nesta versao da API.',
    409 => 'Conflito de dados.',
    >= 500 => 'Erro interno do servidor.',
    _ => 'Falha na requisicao (HTTP $status).',
  };

  @override
  String toString() => 'ApiException($status): $message';
}

enum ApiErrorKind {
  http,
  network,
  timeout,
  payload,

  /// O pedido nao chegou a API (proxy ausente ou endereco errado).
  misrouted,
}
