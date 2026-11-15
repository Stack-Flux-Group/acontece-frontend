/// Espelha `enums/StatusInscricao.kt`. Serializado como string em maiusculas.
enum StatusInscricao {
  pendente('PENDENTE', 'Pendente'),
  confirmada('CONFIRMADA', 'Confirmada'),
  cancelada('CANCELADA', 'Cancelada');

  const StatusInscricao(this.wire, this.rotulo);

  /// Valor exato enviado e recebido pela API.
  final String wire;

  /// Texto para a interface.
  final String rotulo;

  static StatusInscricao fromWire(String raw) => values.firstWhere(
    (s) => s.wire == raw.toUpperCase(),
    orElse: () => throw ArgumentError('Status desconhecido: $raw'),
  );

  /// Ocupa vaga. Espelha `STATUS_ATIVOS` do `InscricaoService`:
  /// `PENDENTE` e `CONFIRMADA` ocupam, `CANCELADA` libera.
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
  Set<StatusInscricao> get proximos => switch (this) {
    pendente => const {confirmada, cancelada},
    confirmada => const {cancelada},
    cancelada => const {},
  };

  bool get terminal => proximos.isEmpty;
}
