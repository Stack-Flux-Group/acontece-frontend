// =============================================================================
// auth_repository.dart - REPOSITORIO DE AUTENTICACAO
// =============================================================================
//
// CONCEITO - repositorio: classe que esconde COMO falar com a API. As telas
// chamam metodos com nome de dominio (`login`, `listar`...), e o repositorio
// cuida de rota, verbo HTTP e conversao JSON <-> modelo.
// =============================================================================

// Cliente HTTP (unico ponto de rede).
import '../infraestrutura/api_client.dart';
// ApiException.badPayload: usada quando a resposta vem num formato inesperado.
import '../infraestrutura/api_exception.dart';
// LoginInput (o que enviamos) e TokenResponse (o que recebemos).
import '../modelos_da_api/auth.dart';

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

  /// `GET /me` -> quem e o dono do token (id, nome, e-mail e papel).
  ///
  /// 401 sem token, com token vencido ou se a conta deixou de existir (o token
  /// continua valido ate expirar, mesmo que a conta seja excluida nesse meio
  /// tempo). O 401 aqui faz o ApiClient derrubar a sessao e voltar ao login.
  Future<UsuarioAtual> me() async {
    // O ApiClient ja anexa o token (`Authorization: Bearer ...`) sozinho.
    final data = await _client.get('/me');
    // Esperamos um objeto JSON (Map). Outra coisa = resposta inesperada.
    if (data is! Map) throw ApiException.badPayload('/me');
    return UsuarioAtual.fromJson(data.cast<String, dynamic>());
  }

  /// `PATCH /me/senha` -> 204 (participante ou organizador).
  ///
  /// 400 se a senha atual estiver errada ou a nova for igual a atual; 400 com
  /// `fieldErrors` se a nova nao tiver de 8 a 72 caracteres. Os erros da senha
  /// atual contam no mesmo limite do login: depois de 5, vem 429 por 15 minutos.
  /// O token atual continua valendo.
  ///
  /// `Future<void>`: nao ha nada a devolver, so "deu certo" (nao lancou) ou
  /// "deu erro" (lancou `ApiException`). O ApiClient trata o 204 (sem corpo)
  /// devolvendo `null`, e aqui esse valor e descartado.
  Future<void> trocarSenha(TrocarSenhaInput input) =>
      _client.patch('/me/senha', body: input.toJson());
}
