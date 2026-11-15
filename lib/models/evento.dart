import '../core/api_dates.dart';
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
  final DateTime dataInicio;
  final DateTime dataFim;
  final int vagas;
  final Endereco endereco;
  final String? fotoUrl;

  factory Evento.fromJson(Map<String, dynamic> json) => Evento(
    id: (json['id'] as num).toInt(),
    titulo: (json['titulo'] ?? '').toString(),
    descricao: (json['descricao'] ?? '').toString(),
    dataInicio: ApiDates.parse(json['dataInicio'] as String),
    dataFim: ApiDates.parse(json['dataFim'] as String),
    vagas: (json['vagas'] as num).toInt(),
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
  bool get encerrado => !dataFim.isAfter(ApiDates.nowInSaoPaulo());

  bool get emAndamento {
    final agora = ApiDates.nowInSaoPaulo();
    return !dataInicio.isAfter(agora) && dataFim.isAfter(agora);
  }

  EventoStatus get status {
    if (encerrado) return EventoStatus.encerrado;
    if (emAndamento) return EventoStatus.emAndamento;
    return EventoStatus.agendado;
  }
}

enum EventoStatus {
  agendado('Agendado'),
  emAndamento('Em andamento'),
  encerrado('Encerrado');

  const EventoStatus(this.rotulo);
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
  final String cep;
  final String? numero;
  final String? fotoUrl;

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

  Map<String, dynamic> toJson() => <String, dynamic>{
    'titulo': titulo,
    'descricao': descricao,
    'dataInicio': ApiDates.format(dataInicio),
    'dataFim': ApiDates.format(dataFim),
    'vagas': vagas,
    'cep': cep,
    'numero': (numero ?? '').isEmpty ? null : numero,
    'fotoUrl': (fotoUrl ?? '').isEmpty ? null : fotoUrl,
  };
}
