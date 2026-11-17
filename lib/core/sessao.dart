// =============================================================================
// sessao.dart - ESTADO DE LOGIN DO APP
// =============================================================================
//
// A `Sessao` responde "quem esta logado?" e executa as transicoes
// entrar / sair / expirar. A raiz do app (main.dart) a escuta e troca de tela.
// =============================================================================

// jsonEncode/jsonDecode: converter objeto <-> texto JSON (para o storage).
import 'dart:convert';

// Traz `ChangeNotifier` (objeto que avisa "mudei" a quem esta escutando).
import 'package:flutter/foundation.dart';

// Modelos de login: LoginInput, UsuarioLogado.
import '../models/auth.dart';
// Repositorio que faz o POST /auth/login.
import '../repositories/auth_repository.dart';
// Onde o token fica guardado entre recarregamentos da pagina.
import 'token_storage.dart';

/// Quem esta logado, e as transicoes entre "logado" e "nao logado".
///
/// E um [ChangeNotifier]: a raiz do app escuta e troca entre a tela de login e
/// a casca do site. O token fica salvo no [TokenStorage] (localStorage no
/// navegador), entao recarregar a pagina nao desloga.
///
/// CONCEITO - ChangeNotifier: guarda uma lista de "ouvintes". Ao chamar
/// `notifyListeners()`, todos sao avisados e (com ListenableBuilder) a UI se
/// redesenha. E o padrao de estado compartilhado mais simples do Flutter.
class Sessao extends ChangeNotifier {
  /// [relogio] e opcional e serve aos testes: permite "avancar o tempo" para
  /// simular um token vencido. Por padrao usa `DateTime.now`.
  /// `DateTime Function()` e o tipo "funcao sem parametros que devolve
  /// DateTime".
  Sessao({
    required this.auth,
    required this.storage,
    DateTime Function()? relogio,
  }) : _relogio = relogio ?? DateTime.now {
    // Ao criar a sessao, tenta recuperar um login salvo antes do recarregamento.
    _restaurar();
  }

  /// Repositorio usado para autenticar (chamar o login na API).
  final AuthRepository auth;

  /// Armazenamento persistente do login (localStorage ou memoria).
  final TokenStorage storage;

  /// Funcao que informa "que horas sao agora" (trocavel nos testes).
  final DateTime Function() _relogio;

  /// Usuario atual; nulo = ninguem logado.
  UsuarioLogado? _usuario;

  /// Motivo da ultima saida involuntaria (ex.: token expirado), para a tela de
  /// login explicar por que a pessoa voltou para ela.
  String? _aviso;

  // Getters publicos somente-leitura sobre o estado privado: quem esta fora da
  // classe pode LER, mas so a propria Sessao consegue alterar.
  UsuarioLogado? get usuario => _usuario;
  bool get logado => _usuario != null;
  String? get aviso => _aviso;

  /// Token para o header `Authorization`, ou `null`.
  ///
  /// Se o token ja venceu, encerra a sessao em vez de mandar um pedido que a
  /// API certamente recusaria com 401.
  String? get token {
    final atual = _usuario;
    // Ninguem logado: nao ha token.
    if (atual == null) return null;
    // Compara a validade (claim `exp`, instante real em UTC) com agora em UTC.
    if (atual.expiradoEm(_relogio().toUtc())) {
      // Adiado: este getter roda no meio de uma requisicao, e notificar ali
      // reconstruiria a arvore durante o build de quem pediu os dados.
      // `Future.microtask` agenda a chamada para logo depois do codigo atual.
      Future.microtask(expirou);
      return null;
    }
    return atual.token;
  }

  /// Tenta reler o login gravado no storage (chamado no construtor).
  void _restaurar() {
    final salvo = storage.ler();
    // Nada salvo: continua deslogado.
    if (salvo == null) return;
    try {
      // Texto JSON -> Map -> UsuarioLogado. O `cast` ajusta o tipo do Map para
      // chave texto e valor qualquer.
      final usuario = UsuarioLogado.fromJson(
        (jsonDecode(salvo) as Map).cast<String, dynamic>(),
      );
      // Token salvo ja venceu: apaga e fica deslogado.
      if (usuario.expiradoEm(_relogio().toUtc())) {
        storage.apagar();
        return;
      }
      // Ainda valido: o usuario volta logado sem digitar senha.
      _usuario = usuario;
    } catch (_) {
      // Formato antigo ou corrompido: descarta.
      storage.apagar();
    }
  }

  /// `POST /auth/login`. Lanca `ApiException` (401 com a mensagem da API)
  /// quando as credenciais nao conferem.
  ///
  /// CONCEITO - `Future`/`async`/`await`: `Future<T>` representa um valor que
  /// chegara depois (a resposta da rede). Funcao `async` pode usar `await`,
  /// que pausa ESTA funcao ate o Future terminar sem travar a interface.
  Future<UsuarioLogado> entrar({
    required String email,
    required String senha,
  }) async {
    // Chama a API; se falhar, a excecao sobe para quem chamou (a tela de login).
    final resposta = await auth.login(LoginInput(email: email, senha: senha));
    // Monta o usuario a partir do token (o e-mail e lido de dentro do JWT).
    final usuario = UsuarioLogado.fromToken(resposta, agora: _relogio());
    _usuario = usuario;
    // Login bem-sucedido: some o aviso antigo.
    _aviso = null;
    // Persiste para sobreviver a recarregar a pagina.
    storage.gravar(jsonEncode(usuario.toJson()));
    // Avisa a UI (main.dart troca LoginScreen por HomeShell).
    notifyListeners();
    return usuario;
  }

  /// Saida pedida pelo usuario (ou depois de excluir a propria conta).
  void sair({String? aviso}) {
    // Ja esta deslogado e o aviso nao muda: nada a fazer (evita notificar a toa).
    if (_usuario == null && aviso == _aviso) return;
    _usuario = null;
    _aviso = aviso;
    // Remove o login salvo.
    storage.apagar();
    notifyListeners();
  }

  /// Chamado quando a API recusa o token (401) ou ele vence.
  void expirou() {
    // Ja deslogado: ignora.
    if (_usuario == null) return;
    sair(aviso: 'Sua sessão expirou. Entre novamente para continuar.');
  }

  /// Limpa o aviso depois que a tela de login o exibiu.
  /// (Sem notifyListeners de proposito: so zera o texto.)
  void limparAviso() => _aviso = null;
}
