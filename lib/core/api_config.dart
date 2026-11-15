/// Configuracao de rede do app.
///
/// A API (`acontece-api`) nao envia nenhum header `Access-Control-Allow-*`.
/// Por isso o site nunca fala com `https://acontece-api.onrender.com` direto:
/// ele chama um caminho relativo (`/api/...`), que e da MESMA origem do site, e
/// quem repassa para a API e a camada de hospedagem:
///
///   * em desenvolvimento: `tools/dev_proxy.mjs`
///   * em producao: uma regra de rewrite configurada no host do site
///
/// Mesma origem significa que o navegador nem chega a considerar CORS.
///
/// Para apontar para outro lugar (por exemplo um back-end local em
/// `http://localhost:8080`, que tambem contorna o CORS fora do navegador):
///
/// ```sh
/// flutter run -d web-server --dart-define=API_BASE_URL=http://localhost:8080
/// ```
class ApiConfig {
  const ApiConfig._();

  /// Prefixo de todas as chamadas. Relativo por padrao (mesma origem).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '/api',
  );

  /// A instancia gratuita do Render hiberna; o cold start medido foi de ~146 s.
  /// Por isso o timeout e generoso de proposito.
  static const Duration timeout = Duration(seconds: 180);

  /// Passado esse tempo sem resposta, a UI avisa que o servidor esta acordando.
  static const Duration coldStartHint = Duration(seconds: 8);

  /// `true` quando as chamadas sao resolvidas contra a origem do site.
  static bool get isSameOrigin => !baseUrl.startsWith('http');
}
