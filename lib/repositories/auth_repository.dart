import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../models/auth.dart';

/// Acesso a `/auth`.
class AuthRepository {
  AuthRepository(this._client);

  final ApiClient _client;

  /// `POST /auth/login` -> `TokenResponse`.
  ///
  /// E-mail inexistente, conta sem senha e senha errada voltam todos como 401
  /// com a mesma mensagem ("E-mail ou senha inválidos"), de proposito: quem
  /// tenta nao descobre quais e-mails estao cadastrados.
  Future<TokenResponse> login(LoginInput input) async {
    final data = await _client.post('/auth/login', body: input.toJson());
    if (data is! Map) throw ApiException.badPayload('/auth/login');
    return TokenResponse.fromJson(data.cast<String, dynamic>());
  }
}
