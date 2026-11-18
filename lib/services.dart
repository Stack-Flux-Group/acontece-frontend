// =============================================================================
// services.dart - INJECAO DE DEPENDENCIAS (sessao + repositorios)
// =============================================================================
//
// CONCEITO - injecao de dependencias: em vez de cada tela criar por conta
// propria o cliente HTTP e os repositorios, eles sao criados UMA vez aqui e
// "entregues" a quem precisar. Isso facilita testes (nos testes troca-se o
// cliente HTTP por um falso) e evita codigo duplicado.
//
// Como o app acessa: `Services.of(context).eventos.listar(...)`.
// =============================================================================

// Widgets Material. Aqui servem para `InheritedWidget` e `BuildContext`.
import 'package:material_ui/material_ui.dart';

// Cliente HTTP do app (unico ponto de rede).
import 'infraestrutura/api_client.dart';
// Sessao: guarda quem esta logado e o token.
import 'infraestrutura/sessao.dart';
// Armazenamento persistente do token (localStorage no navegador).
import 'infraestrutura/token_storage.dart';
// Repositorios: um por recurso da API (login, eventos, participantes...).
import 'acesso_a_api/auth_repository.dart';
import 'acesso_a_api/evento_repository.dart';
import 'acesso_a_api/inscricao_repository.dart';
import 'acesso_a_api/participante_repository.dart';

/// Disponibiliza a sessao e os repositorios para a arvore de widgets.
///
/// Um `InheritedWidget` basta aqui: as dependencias sao criadas uma vez e
/// nunca substituidas. Quem precisa reagir a login/logout escuta a [sessao]
/// (um `ChangeNotifier`), nao este widget.
///
/// CONCEITO - InheritedWidget: widget especial que fica no alto da arvore e
/// permite que qualquer descendente o encontre com `context`, sem precisar
/// passar os dados de construtor em construtor.
class Services extends InheritedWidget {
  /// Construtor. Os parametros entre `{ }` sao NOMEADOS (chamados pelo nome).
  /// * `super.key` / `required super.child`: repassados ao InheritedWidget.
  /// * `client` e `storage` sao opcionais (`?` = pode ser nulo); os testes os
  ///   informam para trocar o HTTP real e o localStorage por versoes falsas.
  ///
  /// Depois do `:` vem a "lista de inicializacao": roda antes do corpo e aqui
  /// define o campo `client` usando `??` ("se for nulo, use o valor da
  /// direita", ou seja, cria um `ApiClient()` de verdade).
  Services({
    super.key,
    required super.child,
    ApiClient? client,
    TokenStorage? storage,
  }) : client = client ?? ApiClient() {
    // Repositorio de autenticacao (login). `this.client` e o campo da classe,
    // para nao confundir com o parametro `client` (que pode ser nulo).
    auth = AuthRepository(this.client);
    // Sessao: usa o repositorio para logar e o storage para lembrar o token.
    // `TokenStorage.padrao()` escolhe localStorage (web) ou memoria (testes).
    sessao = Sessao(auth: auth, storage: storage ?? TokenStorage.padrao());
    // Repositorio de eventos (rotas /eventos).
    eventos = EventoRepository(this.client);
    // Repositorio de participantes (rotas /participantes).
    participantes = ParticipanteRepository(this.client);
    // Repositorio de inscricoes (rotas /inscricoes).
    inscricoes = InscricaoRepository(this.client);

    // Liga o cliente HTTP a sessao: cada pedido le o token do momento, e um
    // 401 em pedido autenticado derruba a sessao (token vencido).
    // `..` e o operador cascata: executa varias atribuicoes no mesmo objeto
    // sem repetir `this.client` em cada linha.
    this.client
      // Funcao anonima chamada a cada requisicao para obter o token atual.
      ..tokenProvider = (() => sessao.token)
      // Passa o METODO `expirou` (sem parenteses = referencia, nao chamada).
      ..onUnauthorized = sessao.expirou;
  }

  /// Cliente HTTP compartilhado por todos os repositorios.
  final ApiClient client;

  // `late final`: variavel que so recebe valor depois (no corpo do construtor),
  // mas uma unica vez, e nunca e lida antes de receber.
  /// Estado de login (usuario + token); e um ChangeNotifier.
  late final Sessao sessao;

  /// Acesso a `/auth` (login).
  late final AuthRepository auth;

  /// Acesso a `/eventos`.
  late final EventoRepository eventos;

  /// Acesso a `/participantes`.
  late final ParticipanteRepository participantes;

  /// Acesso a `/inscricoes`.
  late final InscricaoRepository inscricoes;

  /// Procura o `Services` mais proximo ACIMA de [context] na arvore.
  ///
  /// `static` = metodo da classe (chama-se `Services.of(context)`), nao de uma
  /// instancia. Nao funciona dentro de `initState` (ver CLAUDE.md): la a arvore
  /// ainda nao esta pronta; use `didChangeDependencies`.
  static Services of(BuildContext context) {
    // Sobe a arvore procurando um widget do tipo Services; registra a
    // dependencia (o contexto sera reconstruido se `updateShouldNotify` for
    // verdadeiro).
    final services = context.dependOnInheritedWidgetOfExactType<Services>();
    // `assert` so vale em modo debug: falha cedo, com uma mensagem clara, se
    // alguem esquecer de colocar o Services no topo da arvore.
    assert(services != null, 'Services nao encontrado acima deste widget.');
    // `!` afirma que nao e nulo (seguro por causa do assert).
    return services!;
  }

  /// Diz ao Flutter se os dependentes precisam ser reconstruidos quando este
  /// widget for recriado. So se o cliente HTTP mudar (na pratica nunca).
  @override
  bool updateShouldNotify(Services old) => old.client != client;
}
