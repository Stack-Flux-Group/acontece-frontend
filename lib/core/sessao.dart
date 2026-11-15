import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/auth.dart';
import '../repositories/auth_repository.dart';
import 'token_storage.dart';

/// Quem esta logado, e as transicoes entre "logado" e "nao logado".
///
/// E um [ChangeNotifier]: a raiz do app escuta e troca entre a tela de login e
/// a casca do site. O token fica salvo no [TokenStorage] (localStorage no
/// navegador), entao recarregar a pagina nao desloga.
class Sessao extends ChangeNotifier {
  Sessao({
    required this.auth,
    required this.storage,
    DateTime Function()? relogio,
  }) : _relogio = relogio ?? DateTime.now {
    _restaurar();
  }

  final AuthRepository auth;
  final TokenStorage storage;
  final DateTime Function() _relogio;

  UsuarioLogado? _usuario;

  /// Motivo da ultima saida involuntaria (ex.: token expirado), para a tela de
  /// login explicar por que a pessoa voltou para ela.
  String? _aviso;

  UsuarioLogado? get usuario => _usuario;
  bool get logado => _usuario != null;
  String? get aviso => _aviso;

  /// Token para o header `Authorization`, ou `null`.
  ///
  /// Se o token ja venceu, encerra a sessao em vez de mandar um pedido que a
  /// API certamente recusaria com 401.
  String? get token {
    final atual = _usuario;
    if (atual == null) return null;
    if (atual.expiradoEm(_relogio().toUtc())) {
      // Adiado: este getter roda no meio de uma requisicao, e notificar ali
      // reconstruiria a arvore durante o build de quem pediu os dados.
      Future.microtask(expirou);
      return null;
    }
    return atual.token;
  }

  void _restaurar() {
    final salvo = storage.ler();
    if (salvo == null) return;
    try {
      final usuario = UsuarioLogado.fromJson(
        (jsonDecode(salvo) as Map).cast<String, dynamic>(),
      );
      if (usuario.expiradoEm(_relogio().toUtc())) {
        storage.apagar();
        return;
      }
      _usuario = usuario;
    } catch (_) {
      // Formato antigo ou corrompido: descarta.
      storage.apagar();
    }
  }

  /// `POST /auth/login`. Lanca `ApiException` (401 com a mensagem da API)
  /// quando as credenciais nao conferem.
  Future<UsuarioLogado> entrar({
    required String email,
    required String senha,
  }) async {
    final resposta = await auth.login(LoginInput(email: email, senha: senha));
    final usuario = UsuarioLogado.fromToken(resposta, agora: _relogio());
    _usuario = usuario;
    _aviso = null;
    storage.gravar(jsonEncode(usuario.toJson()));
    notifyListeners();
    return usuario;
  }

  /// Saida pedida pelo usuario (ou depois de excluir a propria conta).
  void sair({String? aviso}) {
    if (_usuario == null && aviso == _aviso) return;
    _usuario = null;
    _aviso = aviso;
    storage.apagar();
    notifyListeners();
  }

  /// Chamado quando a API recusa o token (401) ou ele vence.
  void expirou() {
    if (_usuario == null) return;
    sair(aviso: 'Sua sessão expirou. Entre novamente para continuar.');
  }

  /// Limpa o aviso depois que a tela de login o exibiu.
  void limparAviso() => _aviso = null;
}
