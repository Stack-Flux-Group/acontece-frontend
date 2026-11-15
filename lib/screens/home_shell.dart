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
    final largura = MediaQuery.sizeOf(context).width;
    final compacto = largura < AppTheme.compactBreakpoint;

    // As telas sao mantidas vivas para que trocar de aba nao refaca a chamada
    // a API — importante quando o cold start custa minutos.
    final conteudo = IndexedStack(
      index: _aba,
      children: [for (final aba in _abas) aba.tela],
    );

    if (compacto) {
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
    required this.abas,
    required this.selecionada,
    required this.usuario,
    required this.onSelecionar,
  });

  final List<_Aba> abas;
  final int selecionada;
  final UsuarioLogado usuario;
  final ValueChanged<int> onSelecionar;

  @override
  Widget build(BuildContext context) => Container(
    width: 248,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Paleta.marinho, Paleta.petroleo],
      ),
    ),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: LogoAcontece(tamanho: 34, corTexto: Colors.white),
              ),
            ),
            const SizedBox(height: 36),
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 8),
              child: Text(
                usuario.ehOrganizador ? 'GESTÃO' : 'MENU',
                style: TextStyle(
                  color: Paleta.ciano.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            for (var i = 0; i < abas.length; i++)
              _ItemMenu(
                aba: abas[i],
                selecionado: i == selecionada,
                onTap: () => onSelecionar(i),
              ),
            const Spacer(),
            _CartaoUsuario(usuario: usuario),
          ],
        ),
      ),
    ),
  );
}

class _ItemMenu extends StatelessWidget {
  const _ItemMenu({
    required this.aba,
    required this.selecionado,
    required this.onTap,
  });

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
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
                    fontWeight: selecionado ? FontWeight.w700 : FontWeight.w500,
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
  const _CartaoUsuario({required this.usuario});

  final UsuarioLogado usuario;

  @override
  Widget build(BuildContext context) => Container(
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
    if (MediaQuery.sizeOf(context).width >= AppTheme.compactBreakpoint) {
      return const SizedBox.shrink();
    }
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
              Text(
                usuario.email,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(usuario.papel.rotulo),
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
  final IconData icone;
  final IconData iconeSelecionado;
  final Widget tela;
}
