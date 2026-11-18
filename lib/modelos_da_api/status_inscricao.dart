// =============================================================================
// status_inscricao.dart - SITUACOES POSSIVEIS DE UMA INSCRICAO
// =============================================================================

/// Espelha `enums/StatusInscricao.kt`. Serializado como string em maiusculas.
///
/// CONCEITO - enum com campos: cada valor carrega dados proprios. Ex.:
/// `StatusInscricao.pendente.wire == 'PENDENTE'` e `.rotulo == 'Pendente'`.
enum StatusInscricao {
  // Cada linha chama o construtor `const StatusInscricao(wire, rotulo)`.
  pendente('PENDENTE', 'Pendente'),
  confirmada('CONFIRMADA', 'Confirmada'),
  cancelada('CANCELADA', 'Cancelada');

  /// Construtor do enum (sempre `const`).
  const StatusInscricao(this.wire, this.rotulo);

  /// Valor exato enviado e recebido pela API.
  final String wire;

  /// Texto para a interface.
  final String rotulo;

  /// Converte o texto da API no valor do enum.
  /// `values` = lista de todos os valores; `firstWhere` acha o primeiro que
  /// atende a condicao; `orElse` roda se nenhum atender (aqui, lanca erro).
  static StatusInscricao fromWire(String raw) => values.firstWhere(
    (s) => s.wire == raw.toUpperCase(),
    orElse: () => throw ArgumentError('Status desconhecido: $raw'),
  );

  /// Ocupa vaga. Espelha `STATUS_ATIVOS` do `InscricaoService`:
  /// `PENDENTE` e `CONFIRMADA` ocupam, `CANCELADA` libera.
  /// (`this != cancelada` = "qualquer um, menos o cancelado".)
  bool get ocupaVaga => this != cancelada;

  /// Transicoes permitidas, espelhando o mapa `TRANSICOES` do back-end.
  ///
  /// ```
  /// PENDENTE   -> CONFIRMADA | CANCELADA
  /// CONFIRMADA -> CANCELADA
  /// CANCELADA  -> (terminal)
  /// ```
  ///
  /// Qualquer outra transicao — inclusive para o mesmo status — e recusada com
  /// 409 pela API. A UI so oferece as que estao aqui, para que o usuario nunca
  /// provoque esse erro.
  ///
  /// `Set` = colecao sem repeticao; `const {...}` cria um Set imutavel.
  Set<StatusInscricao> get proximos => switch (this) {
    pendente => const {confirmada, cancelada},
    confirmada => const {cancelada},
    cancelada => const {},
  };

  /// Estado final: nao ha para onde ir depois dele.
  bool get terminal => proximos.isEmpty;
}
