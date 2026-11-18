// =============================================================================
// inscricao_repository.dart - REPOSITORIO DE INSCRICOES
// =============================================================================

import '../infraestrutura/api_client.dart';
import '../infraestrutura/api_exception.dart';
import '../modelos_da_api/inscricao.dart';
// Resposta paginada (conteudo + numero de paginas).
import '../modelos_da_api/paged_model.dart';
import '../modelos_da_api/status_inscricao.dart';

/// Acesso as rotas de inscricao — o nucleo da regra de negocio.
///
/// Permissoes:
///
///  * `POST /inscricoes` — so participante, sempre em nome proprio
///  * `GET /inscricoes` — participante enxerga **so as proprias** (o filtro
///    `participanteId` que ele mandar e ignorado); organizador enxerga todas
///  * `GET /inscricoes/{id}` — organizador, ou o dono da inscricao
///  * `PATCH /inscricoes/{id}/status` — so organizador
///
/// O back-end carrega o evento com trava pessimista (`SELECT ... FOR UPDATE`)
/// durante a criacao, de modo que inscricoes simultaneas no mesmo evento sao
/// serializadas e o limite de vagas nunca e furado. Para o cliente isso aparece
/// como um 409 honesto em vez de uma vaga fantasma.
class InscricaoRepository {
  InscricaoRepository(this._client);

  final ApiClient _client;

  /// `POST /inscricoes` -> 201 + `Location`.
  ///
  /// Sempre nasce como `PENDENTE`, com `dataInscricao` no horario de Sao Paulo.
  /// Os erros possiveis, na ordem em que o back-end verifica:
  ///
  ///  * 403 — quem esta logado nao e participante
  ///  * 404 — participante inexistente (conta excluida com token ainda valido)
  ///  * 404 — evento inexistente
  ///  * 400 — "O evento ja foi encerrado" (`dataFim` no passado)
  ///  * 409 — "Participante ja possui inscricao ativa neste evento"
  ///  * 409 — "Evento sem vagas disponiveis"
  Future<Inscricao> criar(InscricaoInput input) async {
    final data = await _client.post('/inscricoes', body: input.toJson());
    return Inscricao.fromJson(_objeto(data, '/inscricoes'));
  }

  /// `GET /inscricoes/{id}`
  Future<Inscricao> buscarPorId(int id) async {
    final data = await _client.get('/inscricoes/$id');
    return Inscricao.fromJson(_objeto(data, '/inscricoes/$id'));
  }

  /// `GET /inscricoes?eventoId=&participanteId=&status=&page=&size=&sort=`
  ///
  /// Filtros opcionais e combinaveis: cada um que vier nulo e simplesmente
  /// ignorado pela consulta. Default do back-end: `size=20`, `sort=id`.
  ///
  /// Parametros nomeados com valor padrao (`page = 0`) sao opcionais.
  Future<PagedModel<Inscricao>> listar({
    int? eventoId,
    int? participanteId,
    StatusInscricao? status,
    int page = 0,
    int size = 20,
    String sort = 'id,desc',
  }) async {
    final data = await _client.get(
      '/inscricoes',
      // Valores nulos sao descartados pelo ApiClient.resolve (filtro nao usado).
      query: {
        'eventoId': eventoId,
        'participanteId': participanteId,
        // `status?.wire`: se status for nulo, o resultado e nulo (sem erro).
        'status': status?.wire,
        'page': page,
        'size': size,
        'sort': sort,
      },
    );
    if (data is! Map) throw ApiException.badPayload('/inscricoes');
    // Passa `Inscricao.fromJson` como funcao conversora de cada item
    // (referencia a funcao, sem parenteses).
    return PagedModel.fromJson(
      data.cast<String, dynamic>(),
      Inscricao.fromJson,
    );
  }

  /// A inscricao ativa (`PENDENTE` ou `CONFIRMADA`) do participante logado
  /// neste evento, ou `null`.
  ///
  /// Funciona porque, para o participante, `GET /inscricoes` ja vem filtrado
  /// pelo id do token. A API permite so uma ativa por participante e evento.
  Future<Inscricao?> minhaAtivaNoEvento(int eventoId) async {
    final pagina = await listar(eventoId: eventoId, size: 50);
    // Devolve a primeira inscricao que ocupa vaga (nao cancelada).
    for (final inscricao in pagina.content) {
      if (inscricao.status.ocupaVaga) return inscricao;
    }
    // Nenhuma ativa encontrada.
    return null;
  }

  /// `PATCH /inscricoes/{id}/status`
  ///
  /// Apenas as transicoes de [StatusInscricao.proximos] sao aceitas; qualquer
  /// outra, inclusive para o mesmo status, volta 409. `CANCELADA` e terminal e
  /// nao ha DELETE: cancelar e a unica forma de encerrar uma inscricao.
  Future<Inscricao> atualizarStatus(int id, StatusInscricao status) async {
    final data = await _client.patch(
      '/inscricoes/$id/status',
      // O corpo e so o novo status, no texto que a API espera (`wire`).
      body: <String, dynamic>{'status': status.wire},
    );
    return Inscricao.fromJson(_objeto(data, '/inscricoes/$id/status'));
  }

  /// `PATCH /inscricoes/{id}/cancelar` — o participante cancela a **propria**
  /// inscricao. Sem corpo: o novo status e sempre `CANCELADA`.
  ///
  /// Funciona com a inscricao `PENDENTE` ou `CONFIRMADA` e libera a vaga. Erros:
  /// 403 se for de outro participante, 404 se nao existir, 409 se ja estiver
  /// cancelada e 400 ("O evento ja foi encerrado") depois do fim do evento.
  ///
  /// Nao confundir com [atualizarStatus]: aquela e do organizador e manda o
  /// novo status no corpo; esta e do participante e nao manda nada, porque o
  /// destino e sempre `CANCELADA`. A API ainda confere que a inscricao e dele.
  Future<Inscricao> cancelar(int id) async {
    // Sem `body`: o ApiClient nao envia corpo nem o cabecalho Content-Type.
    final data = await _client.patch('/inscricoes/$id/cancelar');
    return Inscricao.fromJson(_objeto(data, '/inscricoes/$id/cancelar'));
  }

  /// Garante que a resposta e um objeto JSON; [path] so identifica a rota na
  /// mensagem de erro.
  Map<String, dynamic> _objeto(dynamic data, String path) {
    if (data is! Map) throw ApiException.badPayload(path);
    return data.cast<String, dynamic>();
  }
}
