import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../models/auth.dart';
import '../services.dart';
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

  final UsuarioLogado usuario;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _aba = 0;

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
    final tela = Tela.of(context);

    // As telas sao mantidas vivas para que trocar de aba nao refaca a chamada
    // a API — importante quando o cold start custa minutos.
    final conteudo = IndexedStack(
      index: _aba,
      children: [for (final aba in _abas) aba.tela],
    );

    // Celular: barra inferior. Tablet: barra lateral so com icones. Notebook e
    // desktop: barra lateral completa.
    if (tela.ehCelular) {
      return Scaffold(
        body: SafeArea(child: conteudo),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _aba,
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
          Expanded(child: conteudo),
        ],
      ),
    );
  }
}

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
  final ValueChanged<int> onSelecionar;

  @override
  Widget build(BuildContext context) => Container(
    width: compacta ? 88 : 248,
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
            _CartaoUsuario(usuario: usuario, compacta: compacta),
          ],
        ),
      ),
    ),
  );
}

class _ItemMenu extends StatelessWidget {
  const _ItemMenu({
    required this.compacta,
    required this.aba,
    required this.selecionado,
    required this.onTap,
  });

  final bool compacta;
  final _Aba aba;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Material(
      color: selecionado ? Paleta.ciano : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: Colors.white.withValues(alpha: 0.06),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compacta ? 4 : 14,
            vertical: compacta ? 10 : 13,
          ),
          child: compacta
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
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

class _CartaoUsuario extends StatelessWidget {
  const _CartaoUsuario({required this.usuario, required this.compacta});

  final UsuarioLogado usuario;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    if (compacta) {
      // Tablet: so o avatar e o botao de sair, empilhados.
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: '${usuario.email} (${usuario.papel.rotulo})',
            child: AvatarUsuario(usuario: usuario, raio: 18),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: () => Services.of(context).sessao.sair(),
            icon: const Icon(Icons.logout, color: Paleta.ciano, size: 22),
          ),
        ],
      );
    }
    return _cartaoCompleto(context);
  }

  Widget _cartaoCompleto(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: Row(
      children: [
        AvatarUsuario(usuario: usuario, raio: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                usuario.email,
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
  );
}

/// Inicial do e-mail num circulo da paleta.
class AvatarUsuario extends StatelessWidget {
  const AvatarUsuario({super.key, required this.usuario, this.raio = 16});

  final UsuarioLogado usuario;
  final double raio;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: raio,
    backgroundColor: usuario.ehOrganizador ? Paleta.turquesa : Paleta.ciano,
    foregroundColor: Paleta.marinho,
    child: Text(
      usuario.email.isEmpty ? '?' : usuario.email[0].toUpperCase(),
      style: TextStyle(fontWeight: FontWeight.w800, fontSize: raio * 0.9),
    ),
  );
}

/// Botao de conta para a barra superior em tela estreita, onde nao ha barra
/// lateral com o "Sair". Em tela larga nao aparece.
class ContaBotao extends StatelessWidget {
  const ContaBotao({super.key, required this.usuario});

  final UsuarioLogado usuario;

  @override
  Widget build(BuildContext context) {
    // So no celular: de tablet para cima a barra lateral ja tem o "Sair".
    if (!Tela.of(context).ehCelular) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: 'Conta',
      onSelected: (valor) {
        if (valor == 'sair') Services.of(context).sessao.sair();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cor explicita: o item e "desabilitado" (so informativo) e o
              // Material o pintaria em cinza claro, quase ilegivel.
              Text(
                usuario.email,
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
        const PopupMenuDivider(),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: AvatarUsuario(usuario: usuario),
      ),
    );
  }
}

class _Aba {
  const _Aba(this.rotulo, this.icone, this.iconeSelecionado, this.tela);
  final String rotulo;

  /// Rotulo de uma palavra, para a barra lateral compacta do tablet.
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
