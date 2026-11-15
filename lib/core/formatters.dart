import 'package:intl/intl.dart';

import 'validators.dart';

/// Formatacao para exibicao (pt-BR).
///
/// A API devolve os dados crus: `cpf` com 11 digitos sem pontuacao, `email`
/// sempre em minusculas, `cep` normalmente ja formatado pelo ViaCEP. O
/// mascaramento acontece so na tela; o que vai para a API segue cru.
class Fmt {
  const Fmt._();

  static final DateFormat _data = DateFormat('dd/MM/yyyy');
  static final DateFormat _hora = DateFormat('HH:mm');
  static final DateFormat _dataHora = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _diaMes = DateFormat("d 'de' MMMM", 'pt_BR');
  static final DateFormat _diaMesAno = DateFormat(
    "d 'de' MMMM 'de' y",
    'pt_BR',
  );

  static String data(DateTime value) => _data.format(value);
  static String hora(DateTime value) => _hora.format(value);
  static String dataHora(DateTime value) => _dataHora.format(value);

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
  static String mesCurto(DateTime value) => _meses[value.month - 1];

  /// Data em texto longo: "4 de dezembro de 2026".
  static String dataLonga(DateTime value) => _diaMesAno.format(value);

  /// Periodo de um evento, encurtado quando faz sentido.
  ///
  /// Mesmo dia: "4 de dezembro, 17:06 as 19:00".
  /// Dias diferentes: "4 de dezembro, 17:06 ate 8 de dezembro, 17:06".
  static String periodo(DateTime inicio, DateTime fim) {
    final mesmoDia =
        inicio.year == fim.year &&
        inicio.month == fim.month &&
        inicio.day == fim.day;
    if (mesmoDia) {
      return '${_diaMes.format(inicio)}, ${hora(inicio)} às ${hora(fim)}';
    }
    return '${_diaMes.format(inicio)}, ${hora(inicio)} até '
        '${_diaMes.format(fim)}, ${hora(fim)}';
  }

  /// Periodo compacto, para cartoes: cabe em uma linha.
  ///
  /// Mesmo dia: "04/12 · 17:06 às 19:00". Dias diferentes:
  /// "01/11 17:00 até 10/11 17:00".
  static String periodoCurto(DateTime inicio, DateTime fim) {
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
    final d = Validators.digits(value);
    if (d.length != 11) return value;
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
    final d = Validators.digits(value ?? '');
    if (d.length == 11) {
      return '(${d.substring(0, 2)}) ${d.substring(2, 7)}-${d.substring(7)}';
    }
    if (d.length == 10) {
      return '(${d.substring(0, 2)}) ${d.substring(2, 6)}-${d.substring(6)}';
    }
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
    final partes = <String>[
      if (logradouro.isNotEmpty)
        numero != null && numero.isNotEmpty
            ? '$logradouro, $numero'
            : logradouro,
      if (bairro.isNotEmpty) bairro,
      if (cidade.isNotEmpty) uf.isNotEmpty ? '$cidade - $uf' : cidade,
    ];
    return partes.join(' · ');
  }

  /// "1 vaga" / "200 vagas".
  static String vagas(int total) => total == 1 ? '1 vaga' : '$total vagas';
}
