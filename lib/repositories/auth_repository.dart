// =============================================================================
// auth_repository.dart - REPOSITORIO DE AUTENTICACAO
// =============================================================================
//
// CONCEITO - repositorio: classe que esconde COMO falar com a API. As telas
// chamam metodos com nome de dominio (`login`, `listar`...), e o repositorio
// cuida de rota, verbo HTTP e conversao JSON <-> modelo.
// =============================================================================

// Cliente HTTP (unico ponto de rede).
import '../core/api_client.dart';
// ApiException.badPayload: usada quando a resposta vem num formato inesperado.
import '../core/api_exception.dart';
// LoginInput (o que enviamos) e TokenResponse (o que recebemos).
import '../models/auth.dart';

/// Acesso a `/auth`.
class AuthRepository {
  /// `this._client` = parametro posicional que ja guarda no campo privado.
  AuthRepository(this._client);

  /// Cliente HTTP usado para todas as chamadas deste repositorio.
  final ApiClient _client;

  /// `POST /auth/login` -> `TokenResponse`.
  ///
  /// E-mail inexistente, conta sem senha e senha errada voltam todos como 401
  /// com a mesma mensagem ("E-mail ou senha inválidos"), de proposito: quem
  /// tenta nao descobre quais e-mails estao cadastrados.
  Future<TokenResponse> login(LoginInput input) async {
    // `await` espera a resposta; `toJson()` gera o corpo {email, senha}.
    final data = await _client.post('/auth/login', body: input.toJson());
    // Esperamos um objeto JSON (Map). Outra coisa = resposta inesperada.
    if (data is! Map) throw ApiException.badPayload('/auth/login');
    // `cast` ajusta o tipo do Map para `Map<String, dynamic>`, e o `fromJson`
    // transforma esse Map no objeto TokenResponse.
    return TokenResponse.fromJson(data.cast<String, dynamic>());
  }
}
