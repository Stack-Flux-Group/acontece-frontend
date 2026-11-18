// =============================================================================
// token_storage.dart - ONDE O LOGIN FICA GUARDADO ENTRE RECARREGAMENTOS
// =============================================================================
//
// Tres arquivos trabalham juntos:
//   token_storage.dart       -> contrato (classe abstrata) + versao em memoria
//   token_storage_web.dart   -> versao real: localStorage do navegador
//   token_storage_stub.dart  -> versao "de mentira" usada fora do navegador
//
// CONCEITO - import condicional: o `import` abaixo escolhe o arquivo conforme
// a plataforma de compilacao. Se existir a biblioteca `dart.library.js_interop`
// (ou seja, compilando para web), usa token_storage_web.dart; senao, o stub.
// Assim `package:web` nunca e carregado nos testes (que rodam na VM do Dart).
// =============================================================================

// Import padrao e o stub; o `if (...)` troca pela versao web quando aplicavel.
// `as impl` da um apelido para chamar `impl.criarStorage()` mais abaixo.
import 'token_storage_stub.dart'
    if (dart.library.js_interop) 'token_storage_web.dart'
    as impl;

/// Guarda a sessao (token + dados do usuario) entre recarregamentos da pagina.
///
/// No navegador usa o `localStorage`; fora dele (testes na VM) cai para
/// memoria. A escolha e feita por import condicional, para que `package:web`
/// nunca seja carregado fora do navegador.
///
/// CONCEITO - classe `abstract`: define um contrato (quais metodos existem)
/// sem implementa-los. Outras classes o cumprem com `implements`.
abstract class TokenStorage {
  /// Le o texto salvo, ou `null` se nao houver nada.
  String? ler();

  /// Salva [valor] (o JSON da sessao).
  void gravar(String valor);

  /// Remove o que foi salvo (logout).
  void apagar();

  /// Implementacao padrao da plataforma atual.
  ///
  /// CONCEITO - `factory`: construtor que pode devolver um objeto de outra
  /// classe (aqui, a implementacao escolhida pelo import condicional).
  factory TokenStorage.padrao() => impl.criarStorage();
}

/// Armazenamento em memoria: some ao recarregar. Usado nos testes.
class MemoryTokenStorage implements TokenStorage {
  /// `[this._valor]` = parametro posicional OPCIONAL que ja preenche o campo.
  /// Os testes passam um valor para comecar "ja logado".
  MemoryTokenStorage([this._valor]);

  /// Valor guardado (privado, pode ser nulo).
  String? _valor;

  // `@override` marca que o metodo cumpre o contrato da classe abstrata.
  @override
  String? ler() => _valor;

  @override
  void gravar(String valor) => _valor = valor;

  @override
  void apagar() => _valor = null;
}
