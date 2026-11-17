// =============================================================================
// api_dates.dart - LEITURA/ESCRITA DE DATAS NO FORMATO DA API
// =============================================================================

// DateFormat: monta/le texto de data conforme um padrao ("yyyy-MM-dd'T'...").
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
  /// Construtor privado: classe so com membros estaticos, nao se instancia.
  const ApiDates._();

  /// Formato aceito pelo `LocalDateTime` do back-end (sem fuso, sem fracao).
  /// Letras: yyyy=ano, MM=mes, dd=dia, HH=hora(0-23), mm=minuto, ss=segundo.
  /// O `'T'` entre aspas simples e um T literal (separador data/hora do ISO).
  /// `static final` = criado uma vez so e reaproveitado em todas as chamadas.
  static final DateFormat _wire = DateFormat("yyyy-MM-dd'T'HH:mm:ss");

  /// Le uma data da API. Aceita com ou sem fracao de segundo.
  ///
  /// Como o texto nao tem sufixo de fuso, `DateTime.parse` devolve um
  /// `DateTime` local cujos campos sao exatamente os que a API enviou.
  /// (`parse` lanca FormatException se o texto for invalido.)
  static DateTime parse(String raw) => DateTime.parse(raw);

  /// Le uma data que pode vir nula ou ausente.
  ///
  /// `Object?` aceita qualquer tipo (inclusive nulo), porque vem de JSON.
  /// Devolve `DateTime?` (nulo se nao houver data valida).
  static DateTime? tryParse(Object? raw) {
    // `is!` testa "NAO e do tipo". Texto vazio ou nao-texto => sem data.
    if (raw is! String || raw.isEmpty) return null;
    // `tryParse` devolve null em vez de lancar excecao quando o texto e invalido.
    return DateTime.tryParse(raw);
  }

  /// Serializa para a API. Descarta milissegundos e qualquer marca de fuso.
  ///
  /// Se por acaso o DateTime estiver em UTC, converte para local antes de
  /// formatar (`? :` = operador ternario: condicao ? se_verdadeiro : se_falso).
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
    // Pega o instante atual, converte para UTC e subtrai 3 horas (UTC-3).
    final sp = DateTime.now().toUtc().subtract(const Duration(hours: 3));
    // Recria como DateTime "local" (sem marca UTC) com os mesmos campos, para
    // poder ser comparado com as datas da API, que tambem nao tem fuso.
    return DateTime(sp.year, sp.month, sp.day, sp.hour, sp.minute, sp.second);
  }
}
