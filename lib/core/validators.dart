/// Validacoes do cliente, espelhando o Bean Validation do back-end.
///
/// Cada regra aqui existe tambem na API — `EventoDTOs.kt`, `ParticipanteDTOs.kt`
/// e os `require` dos services. Validar no cliente nao substitui o servidor
/// (que continua sendo a autoridade, e cujos erros sao exibidos como vem); serve
/// para dar resposta imediata e evitar uma ida a API que ja se sabe que falha.
///
/// Todas as funcoes devolvem `null` quando o valor e valido e a mensagem de erro
/// quando nao e, no formato que o `TextFormField.validator` espera.
class Validators {
  const Validators._();

  static final RegExp _cep = RegExp(r'^\d{5}-?\d{3}$');
  static final RegExp _telefone = RegExp(r'^\d{10,11}$');
  static final RegExp _email = RegExp(
    r"^[\w.!#$%&'*+/=?^`{|}~-]+@[\w-]+(\.[\w-]+)+$",
  );

  /// Mantem apenas digitos. O back-end normaliza CPF assim antes de gravar.
  static String digits(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

  // --- Evento (EventoRequestDTO) ---

  /// `@NotBlank` + `@Size(max = 100)`.
  static String? tituloEvento(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'O título do evento é obrigatório';
    if (text.length > 100) return 'No máximo 100 caracteres';
    return null;
  }

  /// `@Positive`: maior que zero. O back-end nao impoe limite superior.
  static String? vagas(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Informe a quantidade de vagas';
    final parsed = int.tryParse(text);
    if (parsed == null) return 'Use apenas números inteiros';
    if (parsed <= 0) return 'Vagas deve ser maior que zero';
    return null;
  }

  /// `@Pattern(\d{5}-?\d{3})`. Aceita `01001000` e `01001-000`.
  ///
  /// Formato valido nao significa CEP existente: quem decide isso e o ViaCEP,
  /// chamado pelo back-end, que devolve 400 quando o CEP nao existe.
  static String? cep(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'O CEP é obrigatório';
    if (!_cep.hasMatch(text)) return 'CEP deve ter 8 dígitos';
    return null;
  }

  /// Espelha `EventoService.validarDatas`: fim **estritamente** depois do inicio.
  static String? periodoEvento(DateTime? inicio, DateTime? fim) {
    if (inicio == null) return 'A data de início é obrigatória';
    if (fim == null) return 'A data de fim é obrigatória';
    if (!fim.isAfter(inicio)) {
      return 'A data de fim deve ser posterior à data de início';
    }
    return null;
  }

  /// `fotoUrl` e um texto livre na API; so checamos que parece uma URL http(s).
  static String? fotoUrl(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.isScheme('http') && !uri.isScheme('https')) {
      return 'Informe uma URL começando com http:// ou https://';
    }
    return null;
  }

  // --- Participante (ParticipanteDTOs.kt) ---

  /// `@NotBlank` + `@Size(max = 120)`.
  static String? nome(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'O nome é obrigatório';
    if (text.length > 120) return 'No máximo 120 caracteres';
    return null;
  }

  /// `@NotBlank` + `@Email`.
  static String? email(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'O e-mail é obrigatório';
    if (!_email.hasMatch(text)) return 'E-mail inválido';
    return null;
  }

  /// `@Pattern(^\d{10,11}$)`, opcional.
  static String? telefone(String? value) {
    final text = digits(value ?? '');
    if (text.isEmpty) return null;
    if (!_telefone.hasMatch(text)) {
      return 'O telefone deve ter 10 ou 11 dígitos';
    }
    return null;
  }

  /// `@CPF` do Hibernate Validator: 11 digitos com digitos verificadores
  /// corretos. Sequencias de digito repetido (`111.111.111-11`) sao recusadas,
  /// como no back-end.
  static String? cpf(String? value) {
    final text = digits(value ?? '');
    if (text.isEmpty) return 'O CPF é obrigatório';
    if (!isCpfValid(text)) return 'CPF inválido';
    return null;
  }

  /// `@NotBlank` + `@Size(min = 8, max = 72)` do `ParticipanteRequest`. O teto
  /// existe porque o BCrypt so le os primeiros 72 bytes.
  static String? senha(String? value) {
    final text = value ?? '';
    if (text.trim().isEmpty) return 'A senha é obrigatória';
    if (text.length < 8 || text.length > 72) {
      return 'A senha deve ter entre 8 e 72 caracteres';
    }
    return null;
  }

  /// Senha do login: o back-end so exige `@NotBlank` ali.
  static String? senhaLogin(String? value) =>
      (value ?? '').isEmpty ? 'Informe a senha' : null;

  /// Confere os dois digitos verificadores do CPF.
  static bool isCpfValid(String raw) {
    final cpf = digits(raw);
    if (cpf.length != 11) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false;

    final numbers = cpf.split('').map(int.parse).toList(growable: false);

    for (final position in <int>[9, 10]) {
      var sum = 0;
      for (var i = 0; i < position; i++) {
        sum += numbers[i] * (position + 1 - i);
      }
      final remainder = (sum * 10) % 11;
      final check = remainder == 10 ? 0 : remainder;
      if (check != numbers[position]) return false;
    }
    return true;
  }
}
