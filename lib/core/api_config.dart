/// Configuracao de rede do app.
///
/// A API (`acontece-api`) envia CORS para uma lista fixa de origens
/// (`cors.allowed-origins` no back-end). Hoje:
///
///   * `http://localhost:5173` e `http://localhost:3000` (desenvolvimento)
///   * `https://acontece-frontend.vercel.app` (producao)
///
/// Por isso o site fala direto com a API, sem proxy, desde que seja servido de
/// uma dessas origens. Em desenvolvimento:
///
/// ```sh
/// flutter run -d chrome --web-port=5173
/// ```
///
/// Para apontar para outro back-end (por exemplo o local):
///
/// ```sh
/// flutter run -d chrome --web-port=5173 --dart-define=API_BASE_URL=http://localhost:8080
/// ```
class ApiConfig {
  const ApiConfig._();

  /// Endereco da API. Absoluto por padrao; um valor relativo (ex.: `/api`) e
  /// resolvido contra a origem da pagina, caso alguem prefira usar um proxy.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://acontece-api.onrender.com',
  );

  /// A instancia gratuita do Render hiberna; o cold start medido foi de ~146 s.
  /// Por isso o timeout e generoso de proposito.
  static const Duration timeout = Duration(seconds: 180);

  /// Passado esse tempo sem resposta, a UI avisa que o servidor esta acordando.
  static const Duration coldStartHint = Duration(seconds: 8);

  /// `true` quando as chamadas sao resolvidas contra a origem do site.
  static bool get isSameOrigin => !baseUrl.startsWith('http');
}
