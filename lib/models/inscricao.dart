import '../core/api_dates.dart';
import 'status_inscricao.dart';

/// Espelha `InscricaoResponse`.
///
/// A resposta ja traz `participanteNome` e `eventoTitulo` desnormalizados, o que
/// dispensa buscar as entidades para montar a lista.
class Inscricao {
  const Inscricao({
    required this.id,
    required this.participanteId,
    required this.participanteNome,
    required this.eventoId,
    required this.eventoTitulo,
    required this.status,
    required this.dataInscricao,
  });

  final int id;
  final int participanteId;
  final String participanteNome;
  final int eventoId;
  final String eventoTitulo;
  final StatusInscricao status;
  final DateTime dataInscricao;

  factory Inscricao.fromJson(Map<String, dynamic> json) => Inscricao(
    id: (json['id'] as num).toInt(),
    participanteId: (json['participanteId'] as num).toInt(),
    participanteNome: (json['participanteNome'] ?? '').toString(),
    eventoId: (json['eventoId'] as num).toInt(),
    eventoTitulo: (json['eventoTitulo'] ?? '').toString(),
    status: StatusInscricao.fromWire((json['status'] ?? '').toString()),
    dataInscricao: ApiDates.parse(json['dataInscricao'] as String),
  );
}

/// Corpo de `POST /inscricoes` (`InscricaoRequest`).
///
/// O status inicial nao e enviado: o back-end sempre cria como `PENDENTE`.
class InscricaoInput {
  const InscricaoInput({required this.participanteId, required this.eventoId});

  final int participanteId;
  final int eventoId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'participanteId': participanteId,
    'eventoId': eventoId,
  };
}
