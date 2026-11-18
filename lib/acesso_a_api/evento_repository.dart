// =============================================================================
// evento_repository.dart - REPOSITORIO DE EVENTOS
// =============================================================================

// Cliente HTTP (unico ponto de rede do app).
import '../infraestrutura/api_client.dart';
// ApiDates.format: datas sem fuso nas query strings.
import '../infraestrutura/api_dates.dart';
// ApiException.badPayload: resposta em formato inesperado.
import '../infraestrutura/api_exception.dart';
// Evento (leitura) e EventoInput (envio).
import '../modelos_da_api/evento.dart';
// Resposta paginada do Spring Data.
import '../modelos_da_api/paged_model.dart';

/// Acesso as rotas de evento (`/eventos`).
///
/// A API tem rotas REST novas (`/eventos`, paginadas e com filtros que se
/// somam) e manteve as antigas (`/evento/...`, obsoletas) so para o app
/// publicado antes. Este app usa apenas as novas.
class EventoRepository {
  EventoRepository(this._client);

  final ApiClient _client;

  /// Tamanho maximo de pagina aceito pela API (`max-page-size=100`). Pedir mais
  /// que isso nao da erro: a API simplesmente corta em 100.
  /// `static const` = valor fixo, da classe (nao de cada objeto).
  static const int _tamanhoMaximo = 100;

  /// `GET /eventos?titulo=&inicio=&fim=&page=&size=&sort=`
  ///
  /// Todos os filtros sao opcionais e se somam. `titulo` busca por parte do
  /// titulo; `inicio` e `fim` filtram pela **data de inicio** do evento
  /// (inclusive nas duas pontas). `fim` anterior a `inicio` volta 400. A ordem
  /// padrao e a data de inicio; `sort` aceita dataInicio, dataFim, titulo, vagas
  /// e id (ex.: `titulo,desc`).
  ///
  /// Devolve UMA pagina (`PagedModel`): `content` com os eventos e os numeros
  /// de paginacao. Para a lista inteira, use [listarTodos].
  Future<PagedModel<Evento>> listar({
    String? titulo,
    DateTime? inicio,
    DateTime? fim,
    int page = 0,
    int size = 20,
    String? sort,
  }) async {
    final data = await _client.get(
      '/eventos',
      // O ApiClient descarta os valores nulos do `query` (filtro nao usado), so
      // as chaves preenchidas viram `?chave=valor` na URL.
      query: {
        // Filtro vazio e o mesmo que nenhum: nao vai na URL.
        'titulo': (titulo ?? '').trim().isEmpty ? null : titulo!.trim(),
        // Datas no formato sem fuso exigido pela API.
        'inicio': inicio == null ? null : ApiDates.format(inicio),
        'fim': fim == null ? null : ApiDates.format(fim),
        'page': page,
        'size': size,
        'sort': sort,
      },
    );
    // Esperamos um objeto {content, page}. Outra coisa = resposta inesperada.
    if (data is! Map) throw ApiException.badPayload('/eventos');
    // `Evento.fromJson` (sem parenteses) e passado como FUNCAO: o PagedModel a
    // chama uma vez para cada item de `content`.
    return PagedModel.fromJson(data.cast<String, dynamic>(), Evento.fromJson);
  }

  /// Todos os eventos que casam com os filtros, percorrendo as paginas de 100.
  ///
  /// A tela mostra o catalogo inteiro em grade e, para o participante, coloca
  /// os encerrados no fim; essa ordem so o cliente sabe fazer, entao precisa da
  /// lista completa. Nao ha limite de paginas para nao cortar o resultado.
  ///
  /// Cada pagina e uma ida a API, uma depois da outra (a proxima so e pedida
  /// quando a anterior chega). Com 100 eventos por pagina, um catalogo de ate
  /// 100 eventos custa uma unica chamada.
  Future<List<Evento>> listarTodos({
    String? titulo,
    DateTime? inicio,
    DateTime? fim,
  }) async {
    // Acumulador dos eventos de todas as paginas lidas ate agora.
    final todos = <Evento>[];
    var page = 0;
    // `while (true)` repete ate encontrar o `break` abaixo.
    while (true) {
      final pagina = await listar(
        titulo: titulo,
        inicio: inicio,
        fim: fim,
        page: page,
        size: _tamanhoMaximo,
      );
      // `addAll` junta a lista inteira desta pagina a de cima.
      todos.addAll(pagina.content);
      // Ultima pagina lida: encerra o laco.
      if (!pagina.hasNext) break;
      page++;
    }
    return todos;
  }

  /// `GET /eventos/{id}`
  /// (`$id` dentro do texto insere o valor da variavel.)
  Future<Evento> buscarPorId(int id) async {
    final data = await _client.get('/eventos/$id');
    return Evento.fromJson(_objeto(data));
  }

  /// `POST /eventos` -> 201 + `Location`. O corpo ja traz o evento com o
  /// endereco resolvido pelo ViaCEP.
  ///
  /// Esta chamada bloqueia numa requisicao externa (ViaCEP) feita pelo
  /// back-end: pode demorar, e um CEP com formato valido mas inexistente volta
  /// como 400.
  Future<Evento> criar(EventoInput input) async {
    // `input.toJson()` monta o corpo; a resposta e o evento ja criado.
    final data = await _client.post('/eventos', body: input.toJson());
    return Evento.fromJson(_objeto(data));
  }

  /// `PUT /eventos/{id}`
  ///
  /// Substituicao total: todos os campos do `EventoRequestDTO` sao reescritos, e
  /// o CEP e reconsultado no ViaCEP. Por isso o `input` deve partir de
  /// [EventoInput.fromEvento], senao `fotoUrl` e `numero` viram `null`.
  Future<Evento> atualizar(int id, EventoInput input) async {
    final data = await _client.put('/eventos/$id', body: input.toJson());
    return Evento.fromJson(_objeto(data));
  }

  /// `DELETE /eventos/{id}` -> 204.
  ///
  /// Exclusao fisica. Se houver inscricoes apontando para o evento, a chave
  /// estrangeira derruba a operacao e a API responde 409.
  Future<void> deletar(int id) => _client.delete('/eventos/$id');

  /// Garante que a resposta e um objeto JSON e ajusta o tipo.
  Map<String, dynamic> _objeto(dynamic data) {
    if (data is! Map) throw ApiException.badPayload('/eventos');
    return data.cast<String, dynamic>();
  }
}
