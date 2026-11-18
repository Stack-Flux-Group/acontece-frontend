// =============================================================================
// home_shell.dart - "CASCA" DO APP LOGADO (menu + abas)
// =============================================================================
//
// Depois do login, tudo acontece dentro desta casca. Ela desenha o menu de
// navegacao e mostra a aba escolhida. O menu muda conforme a largura da tela:
//
//   celular  -> barra INFERIOR (NavigationBar)
//   tablet   -> barra LATERAL compacta (so icones)
//   notebook / desktop -> barra LATERAL completa
//
// Tambem define widgets reutilizados em outras telas: AvatarUsuario e
// ContaBotao (menu "Sair" para o celular).
// =============================================================================

import 'package:material_ui/material_ui.dart';

import '../infraestrutura/theme.dart';
import '../modelos_da_api/auth.dart';
import '../services.dart';
import 'autenticacao/trocar_senha_screen.dart';
import 'eventos/eventos_list_screen.dart';
import 'inscricoes/inscricoes_list_screen.dart';
import 'participantes/participantes_list_screen.dart';
import 'participantes/perfil_screen.dart';

/// Casca do site depois do login. As abas dependem do papel:
///
///  * organizador: Eventos, Inscricoes (todas) e Participantes
///  * participante: Eventos, Minhas inscricoes e Meu perfil
///
/// Em tela larga a navegacao fica numa barra lateral; em tela estreita vai
/// para a barra inferior.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.usuario});

  /// Quem esta logado; repassado para cada aba (por construtor).
  final UsuarioLogado usuario;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  /// Indice da aba selecionada (0 = primeira).
  int _aba = 0;

  /// Lista de abas conforme o papel. `late final`: so e calculada na primeira
  /// vez que e usada (assim ja da para ler `widget.usuario`). Cada `_Aba` guarda
  /// rotulo, icones (normal e selecionado) e a tela correspondente.
  late final List<_Aba> _abas = widget.usuario.ehOrganizador
      ? [
          _Aba(
            'Eventos',
            Icons.event_outlined,
            Icons.event,
            EventosListScreen(usuario: widget.usuario),
          ),
          _Aba(
            'Inscrições',
            Icons.how_to_reg_outlined,
            Icons.how_to_reg,
            InscricoesListScreen(usuario: widget.usuario),
          ),
          _Aba(
            'Participantes',
            Icons.people_outline,
            Icons.people,
            ParticipantesListScreen(usuario: widget.usuario),
          ),
        ]
      : [
          _Aba(
            'Eventos',
            Icons.event_outlined,
            Icons.event,
            EventosListScreen(usuario: widget.usuario),
          ),
          _Aba(
            'Minhas inscrições',
            Icons.confirmation_number_outlined,
            Icons.confirmation_number,
            InscricoesListScreen(usuario: widget.usuario),
          ),
          _Aba(
            'Meu perfil',
            Icons.person_outline,
            Icons.person,
            PerfilScreen(usuario: widget.usuario),
          ),
        ];

  @override
  Widget build(BuildContext context) {
    // Faixa de largura atual (celular, tablet, notebook ou desktop).
    final tela = Tela.of(context);

    // As telas sao mantidas vivas para que trocar de aba nao refaca a chamada
    // a API — importante quando o cold start custa minutos.
    // CONCEITO - IndexedStack: empilha todos os filhos, mas MOSTRA so o do
    // `index`; os demais continuam construidos (mantendo seu estado).
    final conteudo = IndexedStack(
      index: _aba,
      // `for` dentro de lista: um widget por aba.
      children: [for (final aba in _abas) aba.tela],
    );

    // Celular: barra inferior. Tablet: barra lateral so com icones. Notebook e
    // desktop: barra lateral completa.
    if (tela.ehCelular) {
      // Scaffold = estrutura basica de uma tela (corpo, barras, FAB...).
      return Scaffold(
        // SafeArea evita areas do sistema (notch, barra de status).
        body: SafeArea(child: conteudo),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _aba,
          // Ao tocar num destino, guarda o indice e redesenha.
          onDestinationSelected: (i) => setState(() => _aba = i),
          destinations: [
            for (final aba in _abas)
              NavigationDestination(
                icon: Icon(aba.icone),
                selectedIcon: Icon(aba.iconeSelecionado),
                label: aba.rotulo,
              ),
          ],
        ),
      );
    }

    // Telas maiores: barra lateral a esquerda + conteudo a direita.
    return Scaffold(
      body: Row(
        children: [
          _BarraLateral(
            compacta: tela.ehTablet,
            abas: _abas,
            selecionada: _aba,
            usuario: widget.usuario,
            onSelecionar: (i) => setState(() => _aba = i),
          ),
          // Expanded: o conteudo ocupa toda a largura que sobrar.
          Expanded(child: conteudo),
        ],
      ),
    );
  }
}

/// Barra lateral (tablet/notebook/desktop).
class _BarraLateral extends StatelessWidget {
  const _BarraLateral({
    required this.compacta,
    required this.abas,
    required this.selecionada,
    required this.usuario,
    required this.onSelecionar,
  });

  /// Tablet: so icones e um rotulo curto, 88 px de largura.
  final bool compacta;
  final List<_Aba> abas;
  final int selecionada;
  final UsuarioLogado usuario;

  /// `ValueChanged<int>` = funcao que recebe um int (o indice escolhido).
  final ValueChanged<int> onSelecionar;

  @override
  Widget build(BuildContext context) => Container(
    // Largura fixa: 88 (compacta) ou 248 (completa).
    width: compacta ? 88 : 248,
    // Fundo em degrade vertical, do marinho ao petroleo.
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Paleta.marinho, Paleta.petroleo],
      ),
    ),
    child: SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compacta ? 10 : 16,
          28,
          compacta ? 10 : 16,
          16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo no topo (so o icone se compacta).
            Padding(
              padding: EdgeInsets.only(left: compacta ? 0 : 8),
              child: Align(
                alignment: compacta ? Alignment.center : Alignment.centerLeft,
                child: LogoAcontece(
                  tamanho: 34,
                  corTexto: Colors.white,
                  mostrarNome: !compacta,
                ),
              ),
            ),
            const SizedBox(height: 36),
            // Titulo da secao (so na barra completa).
            if (!compacta)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 8),
                child: Text(
                  usuario.ehOrganizador ? 'GESTÃO' : 'MENU',
                  style: TextStyle(
                    color: Paleta.ciano.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            Expanded(
              // Rola se a janela for baixa demais para todas as abas.
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Um item de menu por aba (laco com indice).
                    for (var i = 0; i < abas.length; i++)
                      _ItemMenu(
                        compacta: compacta,
                        aba: abas[i],
                        selecionado: i == selecionada,
                        onTap: () => onSelecionar(i),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Cartao do usuario com o botao Sair, no rodape da barra.
            _CartaoUsuario(usuario: usuario, compacta: compacta),
          ],
        ),
      ),
    ),
  );
}

/// Um item clicavel do menu lateral.
class _ItemMenu extends StatelessWidget {
  const _ItemMenu({
    required this.compacta,
    required this.aba,
    required this.selecionado,
    required this.onTap,
  });

  final bool compacta;
  final _Aba aba;

  /// Este item e a aba atual?
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    // Material: necessario para o InkWell desenhar o efeito sobre a cor de fundo.
    child: Material(
      // Selecionado = fundo ciano; senao transparente.
      color: selecionado ? Paleta.ciano : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        // Leve clareada ao passar o mouse.
        hoverColor: Colors.white.withValues(alpha: 0.06),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compacta ? 4 : 14,
            vertical: compacta ? 10 : 13,
          ),
          // Compacta: icone sobre texto curto. Completa: icone ao lado do texto.
          child: compacta
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      // Icone cheio quando selecionado, so contorno quando nao.
                      selecionado ? aba.iconeSelecionado : aba.icone,
                      size: 22,
                      color: selecionado ? Paleta.marinho : Paleta.ciano,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      aba.rotuloCurto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: selecionado ? Paleta.marinho : Colors.white,
                        fontWeight: selecionado
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Icon(
                      selecionado ? aba.iconeSelecionado : aba.icone,
                      size: 21,
                      color: selecionado ? Paleta.marinho : Paleta.ciano,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        aba.rotulo,
                        style: TextStyle(
                          color: selecionado ? Paleta.marinho : Colors.white,
                          fontWeight: selecionado
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    ),
  );
}

/// Bloco "avatar + nome + papel + Sair + Alterar senha" no rodape da barra
/// lateral. O nome vem de `GET /me`; enquanto ele nao chega (ou se a chamada
/// falhar), mostra o e-mail que esta dentro do token.
class _CartaoUsuario extends StatelessWidget {
  const _CartaoUsuario({required this.usuario, required this.compacta});

  final UsuarioLogado usuario;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    if (compacta) {
      // Tablet: so o avatar e os botoes de conta (so icones), empilhados.
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tooltip: balao de texto ao passar o mouse.
          Tooltip(
            message: '${usuario.rotuloExibicao} (${usuario.papel.rotulo})',
            child: AvatarUsuario(usuario: usuario, raio: 18),
          ),
          IconButton(
            tooltip: 'Alterar senha',
            // `abrirTrocarSenha` (de trocar_senha_screen.dart) empilha a tela
            // do formulario por cima da casca.
            onPressed: () => abrirTrocarSenha(context),
            icon: const Icon(Icons.lock_reset, color: Paleta.ciano, size: 22),
          ),
          IconButton(
            tooltip: 'Sair',
            // `Services.of(context).sessao.sair()` encerra a sessao; main.dart
            // percebe a mudanca e volta para o login.
            onPressed: () => Services.of(context).sessao.sair(),
            icon: const Icon(Icons.logout, color: Paleta.ciano, size: 22),
          ),
        ],
      );
    }
    return _cartaoCompleto(context);
  }

  /// Versao larga do cartao (metodo auxiliar que devolve um Widget).
  Widget _cartaoCompleto(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      // Branco a 7% de opacidade: um "vidro" leve sobre o fundo escuro.
      color: Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AvatarUsuario(usuario: usuario, raio: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    usuario.rotuloExibicao,
                    // Uma linha so; corta com "..." se o nome for longo.
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    usuario.papel.rotulo,
                    style: const TextStyle(color: Paleta.ciano, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Sair',
              onPressed: () => Services.of(context).sessao.sair(),
              icon: const Icon(Icons.logout, color: Paleta.ciano, size: 20),
            ),
          ],
        ),
        // Embaixo, em linha propria: ao lado do nome sobrava pouco espaco
        // (a barra completa tem 248 px; avatar + nome + 2 icones nao cabiam).
        // CONCEITO - Column dentro do cartao: o `Row` de cima guarda avatar,
        // nome e "Sair"; o botao de texto fica logo abaixo, ocupando a largura.
        TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: Paleta.ciano,
            alignment: Alignment.centerLeft,
          ),
          onPressed: () => abrirTrocarSenha(context),
          icon: const Icon(Icons.lock_reset, size: 18),
          label: const Text('Alterar senha'),
        ),
      ],
    ),
  );
}

/// Inicial do nome (ou do e-mail) num circulo da paleta.
class AvatarUsuario extends StatelessWidget {
  const AvatarUsuario({super.key, required this.usuario, this.raio = 16});

  final UsuarioLogado usuario;

  /// Raio do circulo, em pixels logicos.
  final double raio;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: raio,
    // Organizador = turquesa; participante = ciano (cor diferente por papel).
    backgroundColor: usuario.ehOrganizador ? Paleta.turquesa : Paleta.ciano,
    foregroundColor: Paleta.marinho,
    child: Text(
      // Primeira letra do nome (ou do e-mail), em maiuscula; "?" se vazio.
      usuario.rotuloExibicao.isEmpty
          ? '?'
          : usuario.rotuloExibicao[0].toUpperCase(),
      style: TextStyle(fontWeight: FontWeight.w800, fontSize: raio * 0.9),
    ),
  );
}

/// Botao de conta para a barra superior em tela estreita, onde nao ha barra
/// lateral com o "Sair" nem o "Alterar senha". Em tela larga nao aparece.
class ContaBotao extends StatelessWidget {
  const ContaBotao({super.key, required this.usuario});

  final UsuarioLogado usuario;

  @override
  Widget build(BuildContext context) {
    // So no celular: de tablet para cima a barra lateral ja tem o "Sair" e o
    // "Alterar senha".
    // `SizedBox.shrink()` = widget invisivel de tamanho zero.
    if (!Tela.of(context).ehCelular) return const SizedBox.shrink();
    // PopupMenuButton: botao que abre um menu suspenso; `<String>` e o tipo do
    // valor de cada item.
    return PopupMenuButton<String>(
      tooltip: 'Conta',
      // Chamado com o `value` do item escolhido.
      onSelected: (valor) {
        // Dois `if` em vez de `switch`: sao so duas acoes.
        if (valor == 'sair') Services.of(context).sessao.sair();
        if (valor == 'senha') abrirTrocarSenha(context);
      },
      itemBuilder: (_) => [
        // Item informativo (nao clicavel): mostra e-mail e papel.
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cor explicita: o item e "desabilitado" (so informativo) e o
              // Material o pintaria em cinza claro, quase ilegivel.
              Text(
                usuario.rotuloExibicao,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                usuario.papel.rotulo,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        // Linha fina separando as informacoes das acoes.
        const PopupMenuDivider(),
        // Item "Alterar senha": `value: 'senha'` e o que chega em `onSelected`.
        const PopupMenuItem(
          value: 'senha',
          child: Row(
            children: [
              Icon(Icons.lock_reset, size: 18),
              SizedBox(width: 10),
              Text('Alterar senha'),
            ],
          ),
        ),
        // Item "Sair": `value: 'sair'` e o que chega em `onSelected`.
        const PopupMenuItem(
          value: 'sair',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18),
              SizedBox(width: 10),
              Text('Sair'),
            ],
          ),
        ),
      ],
      // O "botao" visivel e o avatar.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: AvatarUsuario(usuario: usuario),
      ),
    );
  }
}

/// Dados de uma aba do menu: rotulo, icones e a tela exibida.
class _Aba {
  const _Aba(this.rotulo, this.icone, this.iconeSelecionado, this.tela);
  final String rotulo;

  /// Rotulo de uma palavra, para a barra lateral compacta do tablet.
  /// `switch` como expressao: troca alguns rotulos por uma versao curta e
  /// devolve o proprio rotulo (`_`) nos demais casos.
  String get rotuloCurto => switch (rotulo) {
    'Minhas inscrições' => 'Inscrições',
    'Meu perfil' => 'Perfil',
    'Participantes' => 'Pessoas',
    _ => rotulo,
  };
  final IconData icone;
  final IconData iconeSelecionado;
  final Widget tela;
}
