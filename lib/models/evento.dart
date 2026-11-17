// =============================================================================
// evento.dart - MODELOS DE EVENTO (leitura, status e envio)
// =============================================================================

// ApiDates: leitura/escrita de datas e "agora" em Sao Paulo.
import '../core/api_dates.dart';
// Endereco aninhado dentro do evento.
import 'endereco.dart';

/// Espelha `EventoResponseDTO`.
class Evento {
  const Evento({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.dataInicio,
    required this.dataFim,
    required this.vagas,
    required this.endereco,
    this.fotoUrl,
  });

  final int id;
  final String titulo;
  final String descricao;

  /// Inicio e fim: horario de parede de Brasilia, sem fuso (ver ApiDates).
  final DateTime dataInicio;
  final DateTime dataFim;

  /// Capacidade total do evento.
  final int vagas;

  /// Local (preenchido pelo back-end via ViaCEP).
  final Endereco endereco;

  /// Foto de capa opcional.
  final String? fotoUrl;

  /// Constroi a partir do JSON. `as num` + `.toInt()` aceita 5 ou 5.0.
  factory Evento.fromJson(Map<String, dynamic> json) => Evento(
    id: (json['id'] as num).toInt(),
    titulo: (json['titulo'] ?? '').toString(),
    descricao: (json['descricao'] ?? '').toString(),
    // As datas chegam como texto; `as String` garante o tipo antes de ler.
    dataInicio: ApiDates.parse(json['dataInicio'] as String),
    dataFim: ApiDates.parse(json['dataFim'] as String),
    vagas: (json['vagas'] as num).toInt(),
    // O endereco chega como objeto JSON aninhado: converte `Map` generico em
    // `Map<String, dynamic>` e delega ao `Endereco.fromJson`.
    endereco: Endereco.fromJson(
      (json['endereco'] as Map).cast<String, dynamic>(),
    ),
    fotoUrl: json['fotoUrl'] as String?,
  );

  /// Mesma conclusao do `InscricaoService`: encerrado quando `dataFim` ja passou,
  /// comparando com o horario de Sao Paulo (o fuso do `Clock` da API).
  ///
  /// Enquanto nao estiver encerrado, a API aceita inscricao — inclusive em
  /// evento que ja comecou.
  /// (`!dataFim.isAfter(agora)` = "fim nao e depois de agora" = fim <= agora.)
  bool get encerrado => !dataFim.isAfter(ApiDates.nowInSaoPaulo());

  /// Ja comecou e ainda nao terminou.
  bool get emAndamento {
    final agora = ApiDates.nowInSaoPaulo();
    // Comecou (inicio nao e depois de agora) E ainda nao acabou (fim e depois).
    return !dataInicio.isAfter(agora) && dataFim.isAfter(agora);
  }

  /// Resume a situacao em um valor do enum [EventoStatus].
  /// A ordem dos `if` importa: encerrado vem antes de em andamento.
  EventoStatus get status {
    if (encerrado) return EventoStatus.encerrado;
    if (emAndamento) return EventoStatus.emAndamento;
    return EventoStatus.agendado;
  }
}

/// Situacao calculada de um evento (nao vem da API; e derivada das datas).
enum EventoStatus {
  agendado('Agendado'),
  emAndamento('Em andamento'),
  encerrado('Encerrado');

  const EventoStatus(this.rotulo);

  /// Texto exibido no selo (chip).
  final String rotulo;
}

/// Corpo de `POST /evento/criar` e `PUT /evento/atualizar/{id}`
/// (`EventoRequestDTO`).
///
/// Cuidado: o `PUT` e **substituicao total**. Montar esta classe a partir de um
/// [Evento] existente (via [EventoInput.fromEvento]) e o que impede `fotoUrl` e
/// `numero` de virarem `null` numa edicao que nao os tocou.
class EventoInput {
  const EventoInput({
    required this.titulo,
    required this.descricao,
    required this.dataInicio,
    required this.dataFim,
    required this.vagas,
    required this.cep,
    this.numero,
    this.fotoUrl,
  });

  final String titulo;
  final String descricao;
  final DateTime dataInicio;
  final DateTime dataFim;
  final int vagas;

  /// So CEP e numero sao enviados; o restante do endereco o servidor descobre.
  final String cep;
  final String? numero;
  final String? fotoUrl;

  /// Copia os dados de um evento existente (usado ao editar).
  factory EventoInput.fromEvento(Evento evento) => EventoInput(
    titulo: evento.titulo,
    descricao: evento.descricao,
    dataInicio: evento.dataInicio,
    dataFim: evento.dataFim,
    vagas: evento.vagas,
    cep: evento.endereco.cep,
    numero: evento.endereco.numero,
    fotoUrl: evento.fotoUrl,
  );

  /// Objeto -> Map pronto para virar JSON. Datas passam por `ApiDates.format`
  /// (sem fuso). Texto vazio em `numero`/`fotoUrl` vira `null`.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'titulo': titulo,
    'descricao': descricao,
    'dataInicio': ApiDates.format(dataInicio),
    'dataFim': ApiDates.format(dataFim),
    'vagas': vagas,
    'cep': cep,
    // `(numero ?? '').isEmpty`: nulo ou vazio => manda `null` para a API.
    'numero': (numero ?? '').isEmpty ? null : numero,
    'fotoUrl': (fotoUrl ?? '').isEmpty ? null : fotoUrl,
  };
}
