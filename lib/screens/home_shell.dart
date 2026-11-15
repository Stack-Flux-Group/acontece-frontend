import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import 'eventos/eventos_list_screen.dart';
import 'inscricoes/inscricoes_list_screen.dart';
import 'participantes/participantes_list_screen.dart';

/// Casca do site: as tres areas da plataforma.
///
/// Em tela larga a navegacao fica numa coluna a esquerda (comportamento de
/// site); em tela estreita vai para a barra inferior.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _aba = 0;

  static const _abas = <_Aba>[
    _Aba('Eventos', Icons.event_outlined, Icons.event),
    _Aba('Participantes', Icons.people_outline, Icons.people),
    _Aba('Inscricoes', Icons.how_to_reg_outlined, Icons.how_to_reg),
  ];

  /// As telas sao mantidas vivas para que trocar de aba nao refaca a chamada a
  /// API — importante quando o cold start custa minutos.
  final List<Widget> _telas = const [
    EventosListScreen(),
    ParticipantesListScreen(),
    InscricoesListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.sizeOf(context).width;
    final compacto = largura < AppTheme.compactBreakpoint;
    final conteudo = IndexedStack(index: _aba, children: _telas);

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
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: _aba,
              onDestinationSelected: (i) => setState(() => _aba = i),
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: _Logo(),
              ),
              destinations: [
                for (final aba in _abas)
                  NavigationRailDestination(
                    icon: Icon(aba.icone),
                    selectedIcon: Icon(aba.iconeSelecionado),
                    label: Text(aba.rotulo),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: conteudo),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(Icons.celebration, color: scheme.primary, size: 28),
        const SizedBox(height: 4),
        Text(
          'Acontece',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Aba {
  const _Aba(this.rotulo, this.icone, this.iconeSelecionado);
  final String rotulo;
  final IconData icone;
  final IconData iconeSelecionado;
}
