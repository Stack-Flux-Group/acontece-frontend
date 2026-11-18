// =============================================================================
// formatters.dart - FORMATACAO PARA EXIBICAO (datas, CPF, CEP, telefone...)
// =============================================================================
//
// Transforma dados "crus" da API em texto bonito para a tela. Nunca altera o
// que e enviado de volta a API.
// =============================================================================

// DateFormat: formata datas segundo um padrao e um idioma.
import 'package:intl/intl.dart';

// Usa `Validators.digits` para limpar pontuacao antes de formatar.
import 'validators.dart';

/// Formatacao para exibicao (pt-BR).
///
/// A API devolve os dados crus: `cpf` com 11 digitos sem pontuacao, `email`
/// sempre em minusculas, `cep` normalmente ja formatado pelo ViaCEP. O
/// mascaramento acontece so na tela; o que vai para a API segue cru.
///
/// `Fmt` e so uma "caixa de funcoes": construtor privado, tudo `static`.
class Fmt {
  const Fmt._();

  // Formatos de data reutilizaveis. `static final` = criados uma vez so (na
  // primeira vez que forem usados) e compartilhados.
  // dd=dia, MM=mes numerico, yyyy=ano, HH=hora 24h, mm=minuto.
  static final DateFormat _data = DateFormat('dd/MM/yyyy');
  static final DateFormat _hora = DateFormat('HH:mm');
  static final DateFormat _dataHora = DateFormat('dd/MM/yyyy HH:mm');
  // MMMM = nome do mes por extenso ("dezembro"); 'de' entre aspas = texto
  // literal. O segundo argumento e o idioma ('pt_BR').
  static final DateFormat _diaMes = DateFormat("d 'de' MMMM", 'pt_BR');
  static final DateFormat _diaMesAno = DateFormat(
    "d 'de' MMMM 'de' y",
    'pt_BR',
  );

  /// "04/12/2026".
  static String data(DateTime value) => _data.format(value);

  /// "17:06".
  static String hora(DateTime value) => _hora.format(value);

  /// "04/12/2026 17:06".
  static String dataHora(DateTime value) => _dataHora.format(value);

  /// Lista fixa dos meses abreviados (indice 0 = janeiro).
  /// `const` = lista imutavel criada em tempo de compilacao.
  static const _meses = [
    'JAN',
    'FEV',
    'MAR',
    'ABR',
    'MAI',
    'JUN',
    'JUL',
    'AGO',
    'SET',
    'OUT',
    'NOV',
    'DEZ',
  ];

  /// Mes abreviado em maiusculas: "DEZ".
  /// `month` vai de 1 a 12, por isso `- 1` para virar indice da lista.
  static String mesCurto(DateTime value) => _meses[value.month - 1];

  /// Data em texto longo: "4 de dezembro de 2026".
  static String dataLonga(DateTime value) => _diaMesAno.format(value);

  /// Periodo de um evento, encurtado quando faz sentido.
  ///
  /// Mesmo dia: "4 de dezembro, 17:06 as 19:00".
  /// Dias diferentes: "4 de dezembro, 17:06 ate 8 de dezembro, 17:06".
  static String periodo(DateTime inicio, DateTime fim) {
    // Compara ano, mes e dia (ignora a hora) para saber se e o mesmo dia.
    // `&&` = "e": so e verdadeiro se as tres comparacoes forem.
    final mesmoDia =
        inicio.year == fim.year &&
        inicio.month == fim.month &&
        inicio.day == fim.day;
    if (mesmoDia) {
      // `${...}` insere o resultado de uma expressao dentro do texto.
      return '${_diaMes.format(inicio)}, ${hora(inicio)} às ${hora(fim)}';
    }
    // Textos literais vizinhos (sem `+`) sao juntados pelo Dart.
    return '${_diaMes.format(inicio)}, ${hora(inicio)} até '
        '${_diaMes.format(fim)}, ${hora(fim)}';
  }

  /// Periodo compacto, para cartoes: cabe em uma linha.
  ///
  /// Mesmo dia: "04/12 · 17:06 às 19:00". Dias diferentes:
  /// "01/11 17:00 até 10/11 17:00".
  static String periodoCurto(DateTime inicio, DateTime fim) {
    // Formato so com dia/mes.
    final dia = DateFormat('dd/MM');
    final mesmoDia =
        inicio.year == fim.year &&
        inicio.month == fim.month &&
        inicio.day == fim.day;
    if (mesmoDia) {
      return '${dia.format(inicio)} · ${hora(inicio)} às ${hora(fim)}';
    }
    return '${dia.format(inicio)} ${hora(inicio)} até '
        '${dia.format(fim)} ${hora(fim)}';
  }

  /// `52998224725` -> `529.982.247-25`. Deixa como esta se nao tiver 11 digitos.
  static String cpf(String value) {
    // Remove qualquer pontuacao que ja exista, ficando so os numeros.
    final d = Validators.digits(value);
    // Tamanho inesperado: devolve o texto original, sem mexer.
    if (d.length != 11) return value;
    // `substring(a, b)` pega os caracteres da posicao a ate b-1;
    // `substring(9)` pega do 9 ate o fim.
    return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}'
        '-${d.substring(9)}';
  }

  /// `85601000` -> `85601-000`.
  static String cep(String value) {
    final d = Validators.digits(value);
    if (d.length != 8) return value;
    return '${d.substring(0, 5)}-${d.substring(5)}';
  }

  /// `46999887766` -> `(46) 99988-7766`; 10 digitos -> `(46) 9988-7766`.
  static String telefone(String? value) {
    // `value ?? ''` trata telefone nulo (campo opcional) como vazio.
    final d = Validators.digits(value ?? '');
    // Celular: DDD (2 digitos) + 9 digitos.
    if (d.length == 11) {
      return '(${d.substring(0, 2)}) ${d.substring(2, 7)}-${d.substring(7)}';
    }
    // Fixo: DDD (2 digitos) + 8 digitos.
    if (d.length == 10) {
      return '(${d.substring(0, 2)}) ${d.substring(2, 6)}-${d.substring(6)}';
    }
    // Tamanho inesperado: devolve como veio.
    return value ?? '';
  }

  /// Endereco em uma linha, do jeito que o ViaCEP devolveu.
  static String enderecoLinha({
    required String logradouro,
    String? numero,
    required String bairro,
    required String cidade,
    required String uf,
  }) {
    // CONCEITO - `if` dentro de lista literal ("collection if"): o item so
    // entra na lista se a condicao for verdadeira. Assim partes vazias somem.
    final partes = <String>[
      if (logradouro.isNotEmpty)
        // Com numero: "Rua X, 10"; sem numero: so "Rua X".
        numero != null && numero.isNotEmpty
            ? '$logradouro, $numero'
            : logradouro,
      if (bairro.isNotEmpty) bairro,
      // "Cidade - UF" quando ha UF; so a cidade quando nao ha.
      if (cidade.isNotEmpty) uf.isNotEmpty ? '$cidade - $uf' : cidade,
    ];
    // `join` une os itens com o separador.
    return partes.join(' · ');
  }

  /// "1 vaga" / "200 vagas".
  static String vagas(int total) => total == 1 ? '1 vaga' : '$total vagas';

  /// "7/10 vagas preenchidas" (7 das 10 vagas ja foram ocupadas).
  /// `$ocupadas/$total` interpola os dois numeros; o ternario escolhe o singular
  /// quando a capacidade e 1 ("0/1 vaga preenchida").
  static String ocupacao(int ocupadas, int total) =>
      '$ocupadas/$total ${total == 1 ? 'vaga preenchida' : 'vagas preenchidas'}';

  /// "Nenhuma vaga disponível" / "1 vaga disponível" / "3 vagas disponíveis".
  ///
  /// CONCEITO - `switch` como expressao: cada `padrao => valor` e um caso; `0`
  /// e `1` casam com esses numeros e o `_` e o "qualquer outro".
  static String vagasRestantes(int restantes) => switch (restantes) {
    0 => 'Nenhuma vaga disponível',
    1 => '1 vaga disponível',
    _ => '$restantes vagas disponíveis',
  };
}
