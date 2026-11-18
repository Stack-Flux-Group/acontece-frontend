// Versao web do armazenamento: usa o `localStorage` do navegador, que
// sobrevive a recarregar a pagina e a fechar a aba.
// (Usa package:web direto porque plugins como shared_preferences exigem Modo
// de Desenvolvedor no Windows; ver CLAUDE.md.)

// Acesso as APIs do navegador (window, localStorage...), apelidado de `web`.
import 'package:web/web.dart' as web;

// Contrato que esta classe cumpre.
import 'token_storage.dart';

/// Fabrica usada na web: devolve o armazenamento em localStorage.
TokenStorage criarStorage() => _LocalStorage();

/// Implementacao privada (`_`) sobre o localStorage.
class _LocalStorage implements TokenStorage {
  /// Nome da "gaveta" dentro do localStorage onde a sessao e salva.
  static const _chave = 'acontece.sessao';

  @override
  String? ler() {
    // `try/catch`: se algo der erro dentro do `try`, o codigo salta para o catch.
    try {
      // getItem devolve o texto salvo ou null.
      return web.window.localStorage.getItem(_chave);
    } catch (_) {
      // Navegacao privada ou storage bloqueado: segue sem persistir.
      return null;
    }
  }

  @override
  void gravar(String valor) {
    // O navegador pode negar o acesso ao localStorage (ex.: aba privada).
    try {
      // setItem grava (ou sobrescreve) o valor na chave.
      web.window.localStorage.setItem(_chave, valor);
      // `catch (_) {}` abaixo ignora a falha de proposito (bloco vazio): o app
      // segue funcionando, so nao lembra o login.
    } catch (_) {}
  }

  @override
  void apagar() {
    try {
      // removeItem apaga a chave (usado ao sair da conta).
      web.window.localStorage.removeItem(_chave);
      // Mesma ideia: falha de storage nao deve derrubar o app.
    } catch (_) {}
  }
}
