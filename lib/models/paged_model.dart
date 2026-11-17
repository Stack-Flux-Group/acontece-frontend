// =============================================================================
// paged_model.dart - RESPOSTA PAGINADA (lista dividida em paginas)
// =============================================================================

/// Espelha o `PagedModel` do Spring Data, usado por `GET /participantes` e
/// `GET /inscricoes`:
///
/// ```json
/// {"content":[...],
///  "page":{"size":20,"number":0,"totalElements":1,"totalPages":1}}
/// ```
///
/// As rotas de evento **nao** usam isso: `GET /evento/listar/` devolve um array
/// cru com a tabela inteira.
///
/// CONCEITO - generics (`<T>`): a classe serve para qualquer tipo de item.
/// `PagedModel<Inscricao>` e uma pagina de inscricoes; `PagedModel<Participante>`,
/// de participantes. `T` e um "tipo a ser informado depois".
class PagedModel<T> {
  const PagedModel({
    required this.content,
    required this.size,
    required this.number,
    required this.totalElements,
    required this.totalPages,
  });

  /// Itens desta pagina.
  final List<T> content;

  /// Itens por pagina.
  final int size;

  /// Pagina atual, base zero.
  final int number;

  /// Total de itens em TODAS as paginas.
  final int totalElements;

  /// Quantidade de paginas.
  final int totalPages;

  bool get isEmpty => content.isEmpty;

  /// Existe pagina anterior? (a primeira e a 0)
  bool get hasPrevious => number > 0;

  /// Existe proxima pagina? (`number` e base zero, por isso `+ 1`)
  bool get hasNext => number + 1 < totalPages;

  /// "1-20 de 37"
  String get faixaDescrita {
    if (totalElements == 0) return '0 de 0';
    // Posicao do primeiro item desta pagina (contando de 1 para o usuario).
    final inicio = number * size + 1;
    // Posicao do ultimo item exibido.
    final fim = inicio + content.length - 1;
    return '$inicio-$fim de $totalElements';
  }

  /// Constroi a partir do JSON, recebendo uma funcao que sabe converter CADA
  /// item (`itemFromJson`). Assim a mesma classe serve para qualquer modelo.
  /// `T Function(Map<String, dynamic>)` = tipo "funcao que recebe Map e devolve T".
  factory PagedModel.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    final rawContent = json['content'];
    // Se `content` for lista: pega so os itens Map, converte cada um com
    // `itemFromJson` e fecha em lista fixa. Senao, lista vazia de T.
    final items = rawContent is List
        ? rawContent
              .whereType<Map>()
              .map((e) => itemFromJson(e.cast<String, dynamic>()))
              .toList(growable: false)
        : <T>[];

    // Metadados de paginacao ficam dentro de "page".
    final page = json['page'];
    final Map<String, dynamic> meta = page is Map
        ? page.cast<String, dynamic>()
        : const <String, dynamic>{};

    // Funcao local (declarada dentro de outra): le um inteiro de `meta` ou
    // devolve um valor padrao. `num` e a superclasse de int e double (o JSON
    // pode trazer 20 ou 20.0).
    int readInt(String key, int fallback) {
      final value = meta[key];
      return value is num ? value.toInt() : fallback;
    }

    return PagedModel<T>(
      content: items,
      // Cada numero tem um valor reserva caso a API nao o envie.
      size: readInt('size', items.length),
      number: readInt('number', 0),
      totalElements: readInt('totalElements', items.length),
      totalPages: readInt('totalPages', items.isEmpty ? 0 : 1),
    );
  }

  /// Pagina vazia (usada como valor inicial/fallback).
  /// `<T>` depois do nome torna o METODO generico tambem.
  static PagedModel<T> empty<T>() => PagedModel<T>(
    content: const [],
    size: 0,
    number: 0,
    totalElements: 0,
    totalPages: 0,
  );
}
