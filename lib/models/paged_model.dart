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
class PagedModel<T> {
  const PagedModel({
    required this.content,
    required this.size,
    required this.number,
    required this.totalElements,
    required this.totalPages,
  });

  final List<T> content;

  /// Itens por pagina.
  final int size;

  /// Pagina atual, base zero.
  final int number;

  final int totalElements;
  final int totalPages;

  bool get isEmpty => content.isEmpty;
  bool get hasPrevious => number > 0;
  bool get hasNext => number + 1 < totalPages;

  /// "1-20 de 37"
  String get faixaDescrita {
    if (totalElements == 0) return '0 de 0';
    final inicio = number * size + 1;
    final fim = inicio + content.length - 1;
    return '$inicio-$fim de $totalElements';
  }

  factory PagedModel.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    final rawContent = json['content'];
    final items = rawContent is List
        ? rawContent
              .whereType<Map>()
              .map((e) => itemFromJson(e.cast<String, dynamic>()))
              .toList(growable: false)
        : <T>[];

    final page = json['page'];
    final Map<String, dynamic> meta = page is Map
        ? page.cast<String, dynamic>()
        : const <String, dynamic>{};

    int readInt(String key, int fallback) {
      final value = meta[key];
      return value is num ? value.toInt() : fallback;
    }

    return PagedModel<T>(
      content: items,
      size: readInt('size', items.length),
      number: readInt('number', 0),
      totalElements: readInt('totalElements', items.length),
      totalPages: readInt('totalPages', items.isEmpty ? 0 : 1),
    );
  }

  static PagedModel<T> empty<T>() => PagedModel<T>(
    content: const [],
    size: 0,
    number: 0,
    totalElements: 0,
    totalPages: 0,
  );
}
