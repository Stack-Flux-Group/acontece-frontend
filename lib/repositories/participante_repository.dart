// =============================================================================
// participante_repository.dart - REPOSITORIO DE PARTICIPANTES
// =============================================================================

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../models/paged_model.dart';
import '../models/participante.dart';

/// Acesso as rotas de participante.
///
/// Permissoes (SecurityConfig + @PreAuthorize no back-end):
///
///  * `POST /participantes` — aberto, sem login (e o "criar conta")
///  * `GET /participantes` — so organizador
///  * `GET|PATCH|DELETE /participantes/{id}` — organizador, ou o proprio
///    participante (o id do token precisa ser o do caminho)
class ParticipanteRepository {
  ParticipanteRepository(this._client);

  final ApiClient _client;

  /// `GET /participantes?page=&size=&sort=`
  ///
  /// Paginado de verdade (`PagedModel`). Diferente de `/inscricoes`, esta rota
  /// **nao tem ordenacao padrao** no back-end, entao o `sort` vai explicito —
  /// sem ele a ordem das paginas nao e estavel.
  Future<PagedModel<Participante>> listar({
    int page = 0,
    int size = 20,
    String sort = 'nome,asc',
  }) async {
    final data = await _client.get(
      '/participantes',
      query: {'page': page, 'size': size, 'sort': sort},
    );
    if (data is! Map) throw ApiException.badPayload('/participantes');
    // Converte o JSON paginado, usando `Participante.fromJson` para cada item.
    return PagedModel.fromJson(
      data.cast<String, dynamic>(),
      Participante.fromJson,
    );
  }

  /// Busca por nome, e-mail ou CPF.
  ///
  /// A API nao tem rota de busca de participante, so a listagem paginada. Para
  /// nao reimplementar busca no servidor, isto varre as paginas (em lotes
  /// grandes) e filtra no cliente. Serve bem para a escala deste projeto; se a
  /// base crescer, o certo e adicionar o filtro no back-end.
  Future<List<Participante>> buscar(
    String termo, {
    int limitePaginas = 5,
  }) async {
    // Termo normalizado: sem espacos nas pontas e em minusculas.
    final alvo = termo.trim().toLowerCase();
    // Acumula os participantes de todas as paginas lidas.
    final encontrados = <Participante>[];
    var page = 0;
    // Le ate `limitePaginas` paginas de 100 itens.
    while (page < limitePaginas) {
      final pagina = await listar(page: page, size: 100);
      // `addAll` junta uma lista inteira a outra.
      encontrados.addAll(pagina.content);
      // `break` sai do laco quando nao ha proxima pagina.
      if (!pagina.hasNext) break;
      page++;
    }
    // Sem termo: devolve todos.
    if (alvo.isEmpty) return encontrados;
    return encontrados
        // `where` mantem so quem atende a condicao.
        .where(
          (p) =>
              p.nome.toLowerCase().contains(alvo) ||
              p.email.contains(alvo) ||
              // Para CPF, compara so os digitos digitados.
              p.cpf.contains(alvo.replaceAll(RegExp(r'[^0-9]'), '')),
        )
        .toList(growable: false);
  }

  /// `GET /participantes/{id}`
  ///
  /// O participante usa para ler o proprio cadastro (tela "Meu perfil").
  Future<Participante> buscarPorId(int id) async {
    final data = await _client.get('/participantes/$id');
    if (data is! Map) throw ApiException.badPayload('/participantes/$id');
    return Participante.fromJson(data.cast<String, dynamic>());
  }

  /// `POST /participantes` -> 201 + `Location`.
  ///
  /// 409 quando o CPF ja existe, e depois 409 quando o e-mail ja existe (o
  /// back-end checa nessa ordem). A mensagem da API diz qual dos dois foi.
  Future<Participante> criar(ParticipanteInput input) async {
    final data = await _client.post('/participantes', body: input.toJson());
    if (data is! Map) throw ApiException.badPayload('/participantes');
    return Participante.fromJson(data.cast<String, dynamic>());
  }

  /// `PATCH /participantes/{id}`
  ///
  /// Atualizacao parcial: so os campos presentes no corpo sao aplicados. A
  /// senha nao faz parte do PATCH: nao ha como troca-la pela API.
  Future<Participante> atualizar(int id, ParticipantePatch patch) async {
    final data = await _client.patch(
      '/participantes/$id',
      // So os campos que mudaram (ver `ParticipantePatch.toJson`).
      body: patch.toJson(),
    );
    if (data is! Map) throw ApiException.badPayload('/participantes/$id');
    return Participante.fromJson(data.cast<String, dynamic>());
  }

  /// `DELETE /participantes/{id}` -> 204.
  ///
  /// Exclusao fisica; 409 se o participante tiver inscricoes (a chave
  /// estrangeira barra). Quando o proprio participante se exclui, o token
  /// continua valido ate expirar, mas aponta para ninguem — por isso a tela
  /// encerra a sessao logo depois.
  Future<void> excluir(int id) => _client.delete('/participantes/$id');
}
