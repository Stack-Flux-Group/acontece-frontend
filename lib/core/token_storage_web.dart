import 'package:web/web.dart' as web;

import 'token_storage.dart';

TokenStorage criarStorage() => _LocalStorage();

class _LocalStorage implements TokenStorage {
  static const _chave = 'acontece.sessao';

  @override
  String? ler() {
    try {
      return web.window.localStorage.getItem(_chave);
    } catch (_) {
      // Navegacao privada ou storage bloqueado: segue sem persistir.
      return null;
    }
  }

  @override
  void gravar(String valor) {
    try {
      web.window.localStorage.setItem(_chave, valor);
    } catch (_) {}
  }

  @override
  void apagar() {
    try {
      web.window.localStorage.removeItem(_chave);
    } catch (_) {}
  }
}
