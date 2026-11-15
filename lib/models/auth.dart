import 'dart:convert';

/// Espelha `enums/Papel.kt`. O papel decide o que cada usuario pode fazer:
///
///  * `PARTICIPANTE` — consulta eventos, se inscreve, ve as proprias
///    inscricoes e cuida do proprio cadastro.
///  * `ORGANIZADOR` — administra eventos, participantes e o status das
///    inscricoes. Nao existe cadastro publico de organizador: o primeiro nasce
///    no back-end a partir de variaveis de ambiente.
enum Papel {
  participante('PARTICIPANTE', 'Participante'),
  organizador('ORGANIZADOR', 'Organizador');

  const Papel(this.wire, this.rotulo);

  final String wire;
  final String rotulo;

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

  final String token;
  final String tipo;
  final int expiraEmSegundos;
  final int usuarioId;
  final Papel papel;

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
  bool expiradoEm(DateTime agoraUtc) =>
      !agoraUtc.add(const Duration(seconds: 15)).isBefore(expiraEm);

  factory UsuarioLogado.fromToken(TokenResponse resposta, {DateTime? agora}) {
    final claims = lerClaimsJwt(resposta.token);
    final exp = claims['exp'];
    final momento = (agora ?? DateTime.now()).toUtc();
    final expiraEm = exp is num
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

  Map<String, dynamic> toJson() => <String, dynamic>{
    'token': token,
    'id': id,
    'papel': papel.wire,
    'email': email,
    'expiraEm': expiraEm.millisecondsSinceEpoch,
  };

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
  final partes = token.split('.');
  if (partes.length != 3) return const {};
  try {
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(partes[1])),
    );
    final json = jsonDecode(payload);
    return json is Map<String, dynamic> ? json : const {};
  } catch (_) {
    return const {};
  }
}
