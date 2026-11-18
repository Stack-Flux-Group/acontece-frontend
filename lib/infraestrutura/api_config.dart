// =============================================================================
// api_config.dart - CONSTANTES DE REDE (URL da API e tempos limite)
// =============================================================================

/// Configuracao de rede do app.
///
/// A API (`acontece-api`) envia CORS para uma lista fixa de origens
/// (`cors.allowed-origins` no back-end). Hoje:
///
///   * `http://localhost:5173` e `http://localhost:3000` (desenvolvimento)
///   * `https://acontece.netlify.app` (producao)
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
///
/// CONCEITO - CORS: regra do navegador que so deixa um site chamar uma API de
/// outra origem se a API autorizar essa origem. Por isso a porta 5173 importa.
class ApiConfig {
  /// Construtor privado e `const`: impede criar instancias. A classe serve so
  /// de "caixa de constantes" (so membros `static`).
  const ApiConfig._();

  /// Endereco da API. Absoluto por padrao; um valor relativo (ex.: `/api`) e
  /// resolvido contra a origem da pagina, caso alguem prefira usar um proxy.
  ///
  /// `String.fromEnvironment` le um valor passado na compilacao com
  /// `--dart-define=API_BASE_URL=...`; sem ele, usa o `defaultValue`.
  /// `static const` = valor fixo, conhecido em tempo de compilacao.
  static const String baseUrl = String.fromEnvironment(
    // Nome da variavel de ambiente que se procura.
    'API_BASE_URL',
    // Valor usado quando ninguem informou nada: o servidor de producao.
    defaultValue: 'https://acontece-api.onrender.com',
  );

  /// A instancia gratuita do Render hiberna; o cold start medido foi de ~146 s.
  /// Por isso o timeout e generoso de proposito.
  /// `Duration` representa um intervalo de tempo (aqui, 180 segundos).
  static const Duration timeout = Duration(seconds: 180);

  /// Passado esse tempo sem resposta, a UI avisa que o servidor esta acordando.
  static const Duration coldStartHint = Duration(seconds: 8);

  /// `true` quando as chamadas sao resolvidas contra a origem do site.
  /// `get` cria um "getter": usado como propriedade (`ApiConfig.isSameOrigin`),
  /// mas calculado a cada leitura. `!` inverte o booleano; entao e "a base NAO
  /// comeca com http", isto e, e um caminho relativo.
  static bool get isSameOrigin => !baseUrl.startsWith('http');
}
