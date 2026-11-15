import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../models/inscricao.dart';
import '../models/paged_model.dart';
import '../models/status_inscricao.dart';

/// Acesso as rotas de inscricao — o nucleo da regra de negocio.
///
/// O back-end carrega o evento com trava pessimista (`SELECT ... FOR UPDATE`)
/// durante a criacao, de modo que inscricoes simultaneas no mesmo evento sao
/// serializadas e o limite de vagas nunca e furado. Para o cliente isso aparece
/// como um 409 honesto em vez de uma vaga fantasma.
class InscricaoRepository {
  InscricaoRepository(this._client);

  final ApiClient _client;

  /// Diz se esta build da API tem o modulo de inscricoes.
  ///
  /// O deploy atual nao tem: responde `404 "No static resource inscricoes."`.
  /// Sondar uma vez evita que a aba inteira mostre erro de rota como se fosse
  /// falha de dados.
  Future<bool> moduloDisponivel() async {
    try {
      await _client.get('/inscricoes', query: {'size': 1});
      return true;
    } on ApiException catch (e) {
      if (e.isMissingEndpoint || e.status == 405) return false;
      rethrow;
    }
  }

  /// `POST /inscricoes` -> 201 + `Location`.
  ///
  /// Sempre nasce como `PENDENTE`, com `dataInscricao` no horario de Sao Paulo.
  /// Os erros possiveis, na ordem em que o back-end verifica:
  ///
  ///  * 404 — participante inexistente
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
      query: {
        'eventoId': eventoId,
        'participanteId': participanteId,
        'status': status?.wire,
        'page': page,
        'size': size,
        'sort': sort,
      },
    );
    if (data is! Map) throw ApiException.badPayload('/inscricoes');
    return PagedModel.fromJson(data.cast<String, dynamic>(), Inscricao.fromJson);
  }

  /// Conta as inscricoes de um evento que **ocupam vaga** (`PENDENTE` +
  /// `CONFIRMADA`), para mostrar "ocupadas/vagas".
  ///
  /// Usa `totalElements` com `size=1`: so o contador interessa, nao as linhas.
  Future<int> contarAtivasDoEvento(int eventoId) async {
    var total = 0;
    for (final status in StatusInscricao.values.where((s) => s.ocupaVaga)) {
      final pagina = await listar(eventoId: eventoId, status: status, size: 1);
      total += pagina.totalElements;
    }
    return total;
  }

  /// `PATCH /inscricoes/{id}/status`
  ///
  /// Apenas as transicoes de [StatusInscricao.proximos] sao aceitas; qualquer
  /// outra, inclusive para o mesmo status, volta 409. `CANCELADA` e terminal e
  /// nao ha DELETE: cancelar e a unica forma de encerrar uma inscricao.
  Future<Inscricao> atualizarStatus(int id, StatusInscricao status) async {
    final data = await _client.patch(
      '/inscricoes/$id/status',
      body: <String, dynamic>{'status': status.wire},
    );
    return Inscricao.fromJson(_objeto(data, '/inscricoes/$id/status'));
  }

  Map<String, dynamic> _objeto(dynamic data, String path) {
    if (data is! Map) throw ApiException.badPayload(path);
    return data.cast<String, dynamic>();
  }
}
