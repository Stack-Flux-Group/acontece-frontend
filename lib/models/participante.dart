// =============================================================================
// participante.dart - MODELOS DE PARTICIPANTE (leitura, criacao e edicao)
// =============================================================================

// Validators.digits: remove pontuacao de CPF/telefone antes de enviar.
import '../core/validators.dart';

/// Espelha `ParticipanteResponse`.
///
/// O back-end normaliza antes de gravar (`ParticipanteRequest.normalizado()`):
/// `nome` com trim, `email` em minusculas, `cpf` reduzido a 11 digitos. Entao o
/// que chega aqui ja vem nesse formato — a mascara e so de exibicao.
class Participante {
  const Participante({
    required this.id,
    required this.nome,
    required this.email,
    required this.cpf,
    this.telefone,
  });

  final int id;
  final String nome;
  final String email;

  /// 11 digitos, sem pontuacao.
  final String cpf;

  /// Opcional.
  final String? telefone;

  /// Constroi a partir do JSON da API (`?? ''` troca nulo por vazio).
  factory Participante.fromJson(Map<String, dynamic> json) => Participante(
    id: (json['id'] as num).toInt(),
    nome: (json['nome'] ?? '').toString(),
    email: (json['email'] ?? '').toString(),
    cpf: (json['cpf'] ?? '').toString(),
    // `as String?` aceita texto ou nulo (telefone e opcional).
    telefone: json['telefone'] as String?,
  );
}

/// Corpo de `POST /participantes` (`ParticipanteRequest`). Todos os campos vao,
/// porque e uma criacao.
///
/// E a unica rota aberta sem login: e o "criar conta" do site. A `senha`
/// (8 a 72 caracteres) e o que permite ao participante entrar depois; a API
/// guarda so o hash BCrypt. Nao ha rota para trocar a senha depois.
class ParticipanteInput {
  const ParticipanteInput({
    required this.nome,
    required this.email,
    required this.cpf,
    required this.senha,
    this.telefone,
  });

  final String nome;
  final String email;
  final String cpf;
  final String senha;
  final String? telefone;

  /// Normaliza antes de enviar: nome sem espacos nas pontas, e-mail em
  /// minusculas, CPF/telefone so com digitos. Telefone vazio vira `null`.
  /// (`telefone!` afirma nao-nulo; seguro porque o ternario ja checou.)
  Map<String, dynamic> toJson() => <String, dynamic>{
    'nome': nome.trim(),
    'email': email.trim().toLowerCase(),
    'cpf': Validators.digits(cpf),
    'telefone': (telefone ?? '').isEmpty ? null : Validators.digits(telefone!),
    // A senha vai como foi digitada (a API guarda so o hash).
    'senha': senha,
  };
}

/// Corpo de `PATCH /participantes/{id}` (`ParticipantePatchRequest`).
///
/// Atualizacao parcial de verdade: o back-end aplica apenas os campos nao nulos
/// (`dados.nome?.let { ... }`). Mandar um campo como `null` significa "nao
/// mexer", nao "apagar".
///
/// A excecao e `telefone`, que o back-end trata com
/// `telefone = it.ifEmpty { null }`: para **apagar** o telefone e preciso
/// enviar a string vazia `""`. Por isso [limparTelefone] existe separado de
/// [telefone] — sem essa distincao nao ha como zerar o campo.
class ParticipantePatch {
  /// Todos opcionais: so os informados entram no JSON.
  const ParticipantePatch({
    this.nome,
    this.email,
    this.cpf,
    this.telefone,
    this.limparTelefone = false,
  });

  final String? nome;
  final String? email;
  final String? cpf;
  final String? telefone;

  /// `true` = enviar `""` para apagar o telefone no servidor.
  final bool limparTelefone;

  /// Nada a alterar? (Evita mandar um PATCH vazio.)
  bool get isEmpty =>
      nome == null &&
      email == null &&
      cpf == null &&
      telefone == null &&
      !limparTelefone;

  /// Monta o JSON incluindo SOMENTE os campos preenchidos.
  Map<String, dynamic> toJson() {
    // Map vazio, preenchido condicionalmente.
    final json = <String, dynamic>{};
    if (nome != null) json['nome'] = nome!.trim();
    if (email != null) json['email'] = email!.trim().toLowerCase();
    if (cpf != null) json['cpf'] = Validators.digits(cpf!);
    if (limparTelefone) {
      // Regra do back-end: string vazia apaga o telefone.
      json['telefone'] = '';
    } else if (telefone != null) {
      json['telefone'] = Validators.digits(telefone!);
    }
    return json;
  }

  /// Monta o patch comparando o formulario com o registro atual, para enviar
  /// somente o que mudou de fato.
  factory ParticipantePatch.diff({
    required Participante atual,
    required String nome,
    required String email,
    required String cpf,
    required String telefone,
  }) {
    // Compara so digitos, ignorando mascara.
    final novoTelefone = Validators.digits(telefone);
    final telefoneAtual = Validators.digits(atual.telefone ?? '');
    return ParticipantePatch(
      // Igual ao atual => `null` (nao mexe); diferente => envia o novo valor.
      nome: nome.trim() == atual.nome ? null : nome,
      email: email.trim().toLowerCase() == atual.email ? null : email,
      cpf: Validators.digits(cpf) == atual.cpf ? null : cpf,
      telefone: novoTelefone.isEmpty || novoTelefone == telefoneAtual
          ? null
          : telefone,
      // Campo esvaziado, mas existia telefone: pede para apagar.
      limparTelefone: novoTelefone.isEmpty && telefoneAtual.isNotEmpty,
    );
  }
}
