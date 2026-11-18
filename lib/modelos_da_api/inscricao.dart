// =============================================================================
// inscricao.dart - MODELOS DE INSCRICAO (leitura e criacao)
// =============================================================================

// Leitura de datas no formato da API.
import '../infraestrutura/api_dates.dart';
// Enum com os status possiveis.
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

  /// PENDENTE, CONFIRMADA ou CANCELADA.
  final StatusInscricao status;

  /// Quando a inscricao foi feita (sem fuso, horario de Brasilia).
  final DateTime dataInscricao;

  /// Constroi a partir do JSON da API. `(x as num).toInt()` aceita numero
  /// inteiro ou decimal; `?? ''` troca nulo por texto vazio.
  factory Inscricao.fromJson(Map<String, dynamic> json) => Inscricao(
    id: (json['id'] as num).toInt(),
    participanteId: (json['participanteId'] as num).toInt(),
    participanteNome: (json['participanteNome'] ?? '').toString(),
    eventoId: (json['eventoId'] as num).toInt(),
    eventoTitulo: (json['eventoTitulo'] ?? '').toString(),
    // Texto da API ("PENDENTE") -> valor do enum.
    status: StatusInscricao.fromWire((json['status'] ?? '').toString()),
    dataInscricao: ApiDates.parse(json['dataInscricao'] as String),
  );
}

/// Corpo de `POST /inscricoes` (`InscricaoRequest`).
///
/// So o evento vai no corpo. O participante e sempre quem esta logado: o
/// controller sobrescreve `participanteId` com o id do token, para ninguem se
/// inscrever em nome de outro. O status inicial tambem nao e enviado: o
/// back-end sempre cria como `PENDENTE`.
class InscricaoInput {
  const InscricaoInput({required this.eventoId});

  /// Evento em que o participante quer se inscrever.
  final int eventoId;

  /// Vira o JSON `{"eventoId": 1}` que a API espera.
  Map<String, dynamic> toJson() => <String, dynamic>{'eventoId': eventoId};
}
