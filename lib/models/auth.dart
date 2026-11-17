// =============================================================================
// auth.dart - MODELOS DE AUTENTICACAO (papel, login, token, usuario logado)
// =============================================================================
//
// CONCEITO - JWT (JSON Web Token): texto com 3 partes separadas por ponto,
// `cabecalho.payload.assinatura`. O payload (parte do meio) e um JSON em
// Base64 com "claims" (dados): quem e o usuario, papel, validade (`exp`)...
// O servidor confere a assinatura; o app apenas le o payload para exibir dados.
// =============================================================================

// utf8, base64Url, jsonDecode: decodificar o payload do JWT.
import 'dart:convert';

/// Espelha `enums/Papel.kt`. O papel decide o que cada usuario pode fazer:
///
///  * `PARTICIPANTE` — consulta eventos, se inscreve, ve as proprias
///    inscricoes e cuida do proprio cadastro.
///  * `ORGANIZADOR` — administra eventos, participantes e o status das
///    inscricoes. Nao existe cadastro publico de organizador: o primeiro nasce
///    no back-end a partir de variaveis de ambiente.
enum Papel {
  // Cada valor chama o construtor abaixo: (texto da API, texto da interface).
  participante('PARTICIPANTE', 'Participante'),
  organizador('ORGANIZADOR', 'Organizador');

  const Papel(this.wire, this.rotulo);

  /// Texto usado pela API.
  final String wire;

  /// Texto exibido na interface.
  final String rotulo;

  /// Texto da API -> enum (lanca erro se for desconhecido).
  /// `values` e a lista de todos os valores do enum; `firstWhere` acha o
  /// primeiro que bate; `orElse` roda se nenhum bater.
  static Papel fromWire(String raw) => values.firstWhere(
    (p) => p.wire == raw.toUpperCase(),
    orElse: () => throw ArgumentError('Papel desconhecido: $raw'),
  );
}

/// Corpo de `POST /auth/login` (`LoginRequest`).
class LoginInput {
  const LoginInput({required this.email, required this.senha});

  final String email;
  final String senha;

  /// O back-end faz `trim().lowercase()` no e-mail; a senha vai como digitada.
  /// `toJson` converte o objeto em Map, que o ApiClient transforma em JSON.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'email': email.trim().toLowerCase(),
    'senha': senha,
  };
}

/// Espelha `TokenResponse`.
class TokenResponse {
  const TokenResponse({
    required this.token,
    required this.expiraEmSegundos,
    required this.usuarioId,
    required this.papel,
    this.tipo = 'Bearer',
  });

  /// O JWT em si.
  final String token;

  /// Tipo do token (sempre "Bearer").
  final String tipo;

  /// Duracao do token a partir de agora.
  final int expiraEmSegundos;

  /// Id do usuario logado.
  final int usuarioId;

  /// Papel (participante/organizador).
  final Papel papel;

  /// `(x as num?)?.toInt() ?? 0`: converte para numero anulavel, depois para
  /// int se existir, e usa 0 se for nulo.
  factory TokenResponse.fromJson(Map<String, dynamic> json) => TokenResponse(
    token: (json['token'] ?? '').toString(),
    tipo: (json['tipo'] ?? 'Bearer').toString(),
    expiraEmSegundos: (json['expiraEmSegundos'] as num?)?.toInt() ?? 0,
    usuarioId: (json['usuarioId'] as num).toInt(),
    papel: Papel.fromWire((json['papel'] ?? '').toString()),
  );
}

/// Quem esta logado: o token mais o que o app precisa saber sobre a pessoa.
///
/// O `TokenResponse` nao traz o e-mail, mas o JWT traz (claim `email`), entao
/// ele e lido do proprio token. A assinatura nao e conferida aqui — quem
/// confere e a API; o cliente so le os dados para exibir.
class UsuarioLogado {
  const UsuarioLogado({
    required this.token,
    required this.id,
    required this.papel,
    required this.email,
    required this.expiraEm,
  });

  final String token;
  final int id;
  final Papel papel;
  final String email;

  /// Instante (UTC) em que o token deixa de valer.
  final DateTime expiraEm;

  bool get ehOrganizador => papel == Papel.organizador;
  bool get ehParticipante => papel == Papel.participante;

  /// Considera vencido um pouco antes, para nao mandar um token que expira no
  /// meio do caminho.
  /// Soma 15 s ao "agora"; se isso NAO for anterior a `expiraEm`, esta vencido.
  bool expiradoEm(DateTime agoraUtc) =>
      !agoraUtc.add(const Duration(seconds: 15)).isBefore(expiraEm);

  /// Monta o usuario a partir da resposta do login.
  /// [agora] e opcional (testes). A validade vem do claim `exp` (segundos desde
  /// 1970, o "epoch"); se faltar, usa `agora + expiraEmSegundos`.
  factory UsuarioLogado.fromToken(TokenResponse resposta, {DateTime? agora}) {
    // Le os dados de dentro do JWT (um Map: email, exp, papel...).
    final claims = lerClaimsJwt(resposta.token);
    final exp = claims['exp'];
    // Instante de referencia, sempre em UTC.
    final momento = (agora ?? DateTime.now()).toUtc();
    final expiraEm = exp is num
        // `exp` esta em segundos; DateTime quer milissegundos (* 1000).
        ? DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true)
        : momento.add(Duration(seconds: resposta.expiraEmSegundos));
    return UsuarioLogado(
      token: resposta.token,
      id: resposta.usuarioId,
      papel: resposta.papel,
      email: (claims['email'] ?? '').toString(),
      expiraEm: expiraEm,
    );
  }

  /// Serializa para gravar no storage (localStorage). Guarda a validade em
  /// milissegundos para recriar o DateTime depois.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'token': token,
    'id': id,
    'papel': papel.wire,
    'email': email,
    'expiraEm': expiraEm.millisecondsSinceEpoch,
  };

  /// Reconstroi o usuario a partir do que foi gravado por [toJson].
  factory UsuarioLogado.fromJson(Map<String, dynamic> json) => UsuarioLogado(
    token: json['token'] as String,
    id: (json['id'] as num).toInt(),
    papel: Papel.fromWire(json['papel'] as String),
    email: (json['email'] ?? '').toString(),
    expiraEm: DateTime.fromMillisecondsSinceEpoch(
      (json['expiraEm'] as num).toInt(),
      isUtc: true,
    ),
  );
}

/// Le o payload de um JWT sem conferir a assinatura. Devolve mapa vazio se o
/// token nao tiver o formato esperado.
Map<String, dynamic> lerClaimsJwt(String token) {
  // JWT valido tem exatamente 3 partes.
  final partes = token.split('.');
  if (partes.length != 3) return const {};
  try {
    // Pega a parte do meio (payload): `normalize` completa o preenchimento
    // Base64 (`=`), `decode` gera bytes, `utf8.decode` gera texto.
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(partes[1])),
    );
    // Texto JSON -> Map.
    final json = jsonDecode(payload);
    return json is Map<String, dynamic> ? json : const {};
  } catch (_) {
    // Qualquer falha de decodificacao => sem claims.
    return const {};
  }
}
