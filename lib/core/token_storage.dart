import 'token_storage_stub.dart'
    if (dart.library.js_interop) 'token_storage_web.dart'
    as impl;

/// Guarda a sessao (token + dados do usuario) entre recarregamentos da pagina.
///
/// No navegador usa o `localStorage`; fora dele (testes na VM) cai para
/// memoria. A escolha e feita por import condicional, para que `package:web`
/// nunca seja carregado fora do navegador.
abstract class TokenStorage {
  String? ler();
  void gravar(String valor);
  void apagar();

  /// Implementacao padrao da plataforma atual.
  factory TokenStorage.padrao() => impl.criarStorage();
}

/// Armazenamento em memoria: some ao recarregar. Usado nos testes.
class MemoryTokenStorage implements TokenStorage {
  MemoryTokenStorage([this._valor]);

  String? _valor;

  @override
  String? ler() => _valor;

  @override
  void gravar(String valor) => _valor = valor;

  @override
  void apagar() => _valor = null;
}
