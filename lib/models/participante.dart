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
  final String cpf;
  final String? telefone;

  factory Participante.fromJson(Map<String, dynamic> json) => Participante(
    id: (json['id'] as num).toInt(),
    nome: (json['nome'] ?? '').toString(),
    email: (json['email'] ?? '').toString(),
    cpf: (json['cpf'] ?? '').toString(),
    telefone: json['telefone'] as String?,
  );
}

/// Corpo de `POST /participantes` (`ParticipanteRequest`). Todos os campos vao,
/// porque e uma criacao.
class ParticipanteInput {
  const ParticipanteInput({
    required this.nome,
    required this.email,
    required this.cpf,
    this.telefone,
  });

  final String nome;
  final String email;
  final String cpf;
  final String? telefone;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'nome': nome.trim(),
    'email': email.trim().toLowerCase(),
    'cpf': Validators.digits(cpf),
    'telefone': (telefone ?? '').isEmpty ? null : Validators.digits(telefone!),
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
  final bool limparTelefone;

  bool get isEmpty =>
      nome == null &&
      email == null &&
      cpf == null &&
      telefone == null &&
      !limparTelefone;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (nome != null) json['nome'] = nome!.trim();
    if (email != null) json['email'] = email!.trim().toLowerCase();
    if (cpf != null) json['cpf'] = Validators.digits(cpf!);
    if (limparTelefone) {
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
    final novoTelefone = Validators.digits(telefone);
    final telefoneAtual = Validators.digits(atual.telefone ?? '');
    return ParticipantePatch(
      nome: nome.trim() == atual.nome ? null : nome,
      email: email.trim().toLowerCase() == atual.email ? null : email,
      cpf: Validators.digits(cpf) == atual.cpf ? null : cpf,
      telefone: novoTelefone.isEmpty || novoTelefone == telefoneAtual
          ? null
          : telefone,
      limparTelefone: novoTelefone.isEmpty && telefoneAtual.isNotEmpty,
    );
  }
}
