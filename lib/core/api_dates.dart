import 'package:intl/intl.dart';

/// Conversao de datas no formato da API.
///
/// O back-end usa `java.time.LocalDateTime`: data e hora **sem fuso**, digitadas
/// em horario de Brasilia. O JSON chega como `"2026-12-04T17:06:44.19"` — note
/// a fracao de segundo, que a API realmente devolve — e precisa voltar como
/// `"2026-12-04T17:06:44"`, nunca com `Z` nem com offset: o Jackson recusaria.
///
/// A regra que mantem tudo coerente: **nunca converter fuso**. Os valores sao
/// tratados como hora de parede do inicio ao fim.
class ApiDates {
  const ApiDates._();

  /// Formato aceito pelo `LocalDateTime` do back-end (sem fuso, sem fracao).
  static final DateFormat _wire = DateFormat("yyyy-MM-dd'T'HH:mm:ss");

  /// Le uma data da API. Aceita com ou sem fracao de segundo.
  ///
  /// Como o texto nao tem sufixo de fuso, `DateTime.parse` devolve um
  /// `DateTime` local cujos campos sao exatamente os que a API enviou.
  static DateTime parse(String raw) => DateTime.parse(raw);

  /// Le uma data que pode vir nula ou ausente.
  static DateTime? tryParse(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// Serializa para a API. Descarta milissegundos e qualquer marca de fuso.
  static String format(DateTime value) =>
      _wire.format(value.isUtc ? value.toLocal() : value);

  /// "Agora" no fuso em que o back-end raciocina.
  ///
  /// `ClockConfig.kt` fixa o relogio da API em `America/Sao_Paulo` justamente
  /// porque as datas sao naive e o servidor roda em UTC. Para que o app chegue a
  /// mesma conclusao que a API sobre "o evento ja foi encerrado", ele compara
  /// com Sao Paulo, e nao com o fuso do navegador do visitante.
  ///
  /// O Brasil nao tem mais horario de verao desde 2019, entao o offset e um
  /// UTC-3 fixo.
  static DateTime nowInSaoPaulo() {
    final sp = DateTime.now().toUtc().subtract(const Duration(hours: 3));
    return DateTime(sp.year, sp.month, sp.day, sp.hour, sp.minute, sp.second);
  }
}
