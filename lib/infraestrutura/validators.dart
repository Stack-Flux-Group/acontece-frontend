// =============================================================================
// validators.dart - VALIDACAO DE CAMPOS DE FORMULARIO
// =============================================================================

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

  // CONCEITO - RegExp (expressao regular): padrao para testar textos.
  // O prefixo `r` cria uma "raw string" (a barra invertida nao e escape do Dart).
  // `^`=inicio, `$`=fim, `\d`=digito, `{5}`=exatamente 5, `-?`=hifen opcional.
  static final RegExp _cep = RegExp(r'^\d{5}-?\d{3}$');
  // 10 ou 11 digitos seguidos (`{10,11}` = de 10 a 11 repeticoes).
  static final RegExp _telefone = RegExp(r'^\d{10,11}$');
  // E-mail: parte local, `@`, dominio e ao menos um `.sufixo`.
  // `\w` = letra, numero ou `_`; `+` = uma ou mais vezes.
  static final RegExp _email = RegExp(
    r"^[\w.!#$%&'*+/=?^`{|}~-]+@[\w-]+(\.[\w-]+)+$",
  );

  /// Mantem apenas digitos. O back-end normaliza CPF assim antes de gravar.
  /// `[^0-9]` = qualquer caractere que NAO seja digito; e removido.
  static String digits(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

  // --- Evento (EventoRequestDTO) ---

  /// `@NotBlank` + `@Size(max = 100)`.
  static String? tituloEvento(String? value) {
    // `trim()` tira espacos das pontas; `?? ''` trata nulo como vazio.
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'O título do evento é obrigatório';
    if (text.length > 100) return 'No máximo 100 caracteres';
    // `null` = "sem erro".
    return null;
  }

  /// `@Size(max = 2000)` da descricao do evento. Opcional: vazia e valida.
  /// (`(value ?? '')` trata nulo como texto vazio; o resultado do `?:` e o
  /// proprio retorno: mensagem de erro ou `null` = "sem erro".)
  static String? descricaoEvento(String? value) =>
      (value ?? '').length > 2000 ? 'No máximo 2000 caracteres' : null;

  /// `@Positive`: maior que zero. O back-end nao impoe limite superior.
  static String? vagas(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Informe a quantidade de vagas';
    // `tryParse` devolve null se o texto nao for um inteiro.
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
    // `hasMatch` informa se o texto obedece a expressao regular.
    if (!_cep.hasMatch(text)) return 'CEP deve ter 8 dígitos';
    return null;
  }

  /// Espelha `EventoService.validarDatas`: fim **estritamente** depois do inicio.
  static String? periodoEvento(DateTime? inicio, DateTime? fim) {
    if (inicio == null) return 'A data de início é obrigatória';
    if (fim == null) return 'A data de fim é obrigatória';
    // `isAfter` e estrito: fim igual ao inicio tambem e recusado.
    if (!fim.isAfter(inicio)) {
      return 'A data de fim deve ser posterior à data de início';
    }
    return null;
  }

  /// `fotoUrl` e um texto livre na API; so checamos que parece uma URL http(s).
  static String? fotoUrl(String? value) {
    final text = (value ?? '').trim();
    // Campo opcional: vazio e valido.
    if (text.isEmpty) return null;
    // `@Size(max = 1000)` da `fotoUrl` no back-end.
    if (text.length > 1000) return 'No máximo 1000 caracteres';
    // Tenta interpretar como URL (null se for impossivel).
    final uri = Uri.tryParse(text);
    // Invalida se nao for URL, nao tiver esquema (http:) ou o esquema nao for
    // http/https. (`&&` tem precedencia sobre `||`.)
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
    // Ignora parenteses/hifens digitados pelo usuario (fica so com digitos).
    final text = digits(value ?? '');
    // Vazio e valido: o telefone e opcional.
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
    // `isCpfValid` faz a conta dos digitos verificadores (mais abaixo).
    if (!isCpfValid(text)) return 'CPF inválido';
    return null;
  }

  /// `@NotBlank` + `@Size(min = 8, max = 72)` do `ParticipanteRequest`. O teto
  /// existe porque o BCrypt so le os primeiros 72 bytes.
  static String? senha(String? value) {
    // Senha NAO leva trim: espacos fazem parte dela.
    final text = value ?? '';
    if (text.trim().isEmpty) return 'A senha é obrigatória';
    if (text.length < 8 || text.length > 72) {
      return 'A senha deve ter entre 8 e 72 caracteres';
    }
    return null;
  }

  /// Nova senha na troca: as regras do cadastro, e diferente da atual (a API
  /// recusa repetir a mesma). [atual] e o que esta digitado no campo da senha
  /// atual.
  ///
  /// Recebe a senha atual como parametro porque um `validator` de formulario so
  /// ve o valor do PROPRIO campo; a tela passa o outro por uma funcao anonima.
  static String? novaSenha(String? value, String atual) {
    // Reaproveita as regras do cadastro (obrigatoria, 8 a 72 caracteres).
    final erro = senha(value);
    if (erro != null) return erro;
    if (value == atual) return 'A nova senha deve ser diferente da atual';
    return null;
  }

  /// Confirmacao da nova senha: precisa ser igual a digitada acima. Existe so no
  /// app, para evitar gravar uma senha com erro de digitacao; a API nao a recebe.
  static String? confirmacaoSenha(String? value, String nova) =>
      (value ?? '') == nova ? null : 'As senhas não conferem';

  /// Senha do login: o back-end so exige `@NotBlank` ali.
  static String? senhaLogin(String? value) =>
      (value ?? '').isEmpty ? 'Informe a senha' : null;

  /// Confere os dois digitos verificadores do CPF.
  ///
  /// Algoritmo: para cada digito verificador, multiplica os digitos anteriores
  /// por pesos decrescentes, soma, multiplica por 10 e toma o resto da divisao
  /// por 11 (resto 10 vira 0). O resultado deve igualar o digito informado.
  static bool isCpfValid(String raw) {
    final cpf = digits(raw);
    if (cpf.length != 11) return false;
    // `(\d)\1{10}` = um digito seguido de 10 repeticoes dele (ex.: 11111111111).
    // `\1` repete o que o primeiro grupo `( )` capturou.
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false;

    // "52998224725" -> [5,2,9,9,8,2,2,4,7,2,5]. `split('')` separa em letras;
    // `map(int.parse)` converte cada uma em numero.
    final numbers = cpf.split('').map(int.parse).toList(growable: false);

    // position 9 = confere o 10o digito; position 10 = confere o 11o.
    for (final position in <int>[9, 10]) {
      // Acumulador da soma ponderada. `var` = variavel que pode mudar.
      var sum = 0;
      for (var i = 0; i < position; i++) {
        // Pesos: 10..2 para o 1o verificador, 11..2 para o 2o.
        sum += numbers[i] * (position + 1 - i);
      }
      // Regra do modulo 11 (`%` = resto da divisao).
      final remainder = (sum * 10) % 11;
      final check = remainder == 10 ? 0 : remainder;
      // Digito calculado diferente do digitado: CPF invalido.
      if (check != numbers[position]) return false;
    }
    return true;
  }
}
