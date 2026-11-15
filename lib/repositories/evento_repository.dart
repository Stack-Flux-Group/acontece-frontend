import '../core/api_client.dart';
import '../core/api_dates.dart';
import '../core/api_exception.dart';
import '../models/evento.dart';

/// Acesso as rotas de evento.
///
/// Essas rotas fogem do padrao REST do resto da API (verbo no caminho, recurso
/// no singular, uma delas com barra final obrigatoria). Toda essa estranheza
/// fica contida aqui; a UI so chama metodos com nome de dominio.
class EventoRepository {
  EventoRepository(this._client);

  final ApiClient _client;

  /// `GET /evento/listar/`
  ///
  /// A **barra final e obrigatoria** — sem ela a rota nao casa. Devolve um array
  /// cru, sem paginacao: a tabela inteira de uma vez. Paginar e ordenar fica a
  /// cargo do cliente.
  Future<List<Evento>> listar() async {
    final data = await _client.get('/evento/listar/');
    return _lista(data);
  }

  /// `GET /evento/buscar/{id}`
  Future<Evento> buscarPorId(int id) async {
    final data = await _client.get('/evento/buscar/$id');
    return Evento.fromJson(_objeto(data));
  }

  /// `GET /evento/buscar/titulo?titulo=...`
  ///
  /// `LIKE %titulo%` ignorando maiusculas (mas sensivel a acento, porque a
  /// comparacao e feita pelo banco). Array cru, sem paginacao.
  Future<List<Evento>> buscarPorTitulo(String titulo) async {
    final data = await _client.get(
      '/evento/buscar/titulo',
      query: {'titulo': titulo},
    );
    return _lista(data);
  }

  /// `GET /evento/buscar/periodo?inicio=...&fim=...`
  ///
  /// Atencao ao criterio: filtra os eventos cuja **`dataInicio`** cai no
  /// intervalo (inclusive nas duas pontas), e nao os que se sobrepoem a ele. Um
  /// evento que comecou antes de `inicio` e termina dentro dele **nao** aparece.
  /// O resultado ja vem ordenado por `dataInicio`.
  ///
  /// `fim` anterior a `inicio` resulta em 400 com a mensagem do back-end.
  Future<List<Evento>> buscarPorPeriodo({
    required DateTime inicio,
    required DateTime fim,
  }) async {
    final data = await _client.get(
      '/evento/buscar/periodo',
      query: {'inicio': ApiDates.format(inicio), 'fim': ApiDates.format(fim)},
    );
    return _lista(data);
  }

  /// `POST /evento/criar`
  ///
  /// Responde **200, nao 201**, e sem header `Location` — ao contrario de
  /// `/participantes` e `/inscricoes`. O corpo ja traz o evento com o endereco
  /// resolvido pelo ViaCEP.
  ///
  /// Esta chamada bloqueia numa requisicao externa (ViaCEP) feita pelo
  /// back-end: pode demorar, e um CEP com formato valido mas inexistente volta
  /// como 400.
  Future<Evento> criar(EventoInput input) async {
    final data = await _client.post('/evento/criar', body: input.toJson());
    return Evento.fromJson(_objeto(data));
  }

  /// `PUT /evento/atualizar/{id}`
  ///
  /// Substituicao total: todos os campos do `EventoRequestDTO` sao reescritos, e
  /// o CEP e reconsultado no ViaCEP. Por isso o `input` deve partir de
  /// [EventoInput.fromEvento], senao `fotoUrl` e `numero` viram `null`.
  Future<Evento> atualizar(int id, EventoInput input) async {
    final data = await _client.put(
      '/evento/atualizar/$id',
      body: input.toJson(),
    );
    return Evento.fromJson(_objeto(data));
  }

  /// `DELETE /evento/deletar/{id}` -> 204.
  ///
  /// Exclusao fisica. Se houver inscricoes apontando para o evento, a chave
  /// estrangeira derruba a operacao e a API responde 409.
  Future<void> deletar(int id) => _client.delete('/evento/deletar/$id');

  List<Evento> _lista(dynamic data) {
    if (data is! List) throw ApiException.badPayload('/evento');
    return data
        .whereType<Map>()
        .map((e) => Evento.fromJson(e.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Map<String, dynamic> _objeto(dynamic data) {
    if (data is! Map) throw ApiException.badPayload('/evento');
    return data.cast<String, dynamic>();
  }
}
