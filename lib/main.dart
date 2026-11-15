import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'core/theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_shell.dart';
import 'services.dart';

void main() {
  // Carrega os dados de locale do intl antes do primeiro `DateFormat` com
  // nome de mes em portugues ("4 de dezembro de 2026").
  initializeDateFormatting('pt_BR');
  Intl.defaultLocale = 'pt_BR';

  runApp(Services(child: const AconteceApp()));
}

class AconteceApp extends StatefulWidget {
  const AconteceApp({super.key});

  @override
  State<AconteceApp> createState() => _AconteceAppState();
}

class _AconteceAppState extends State<AconteceApp> {
  final _navigator = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final sessao = Services.of(context).sessao;
    return MaterialApp(
      title: 'Acontece',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigator,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,

      // Os textos internos do Material (date picker, "Cancelar", rotulos de
      // acessibilidade) vem do proprio material_ui, que ja inclui 'pt'.
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('pt', 'BR'), Locale('pt')],
      locale: const Locale('pt', 'BR'),

      home: ListenableBuilder(
        listenable: sessao,
        builder: (context, _) {
          final usuario = sessao.usuario;
          if (usuario == null) {
            // Ao sair (ou expirar), fecha telas e dialogos que estavam
            // abertos por cima: eles dependiam do usuario que saiu.
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _navigator.currentState?.popUntil((r) => r.isFirst),
            );
            return const LoginScreen();
          }
          // A chave recria a casca inteira quando muda o usuario, para nao
          // sobrar dado de uma conta na tela da outra.
          return HomeShell(
            key: ValueKey('${usuario.id}-${usuario.papel.wire}'),
            usuario: usuario,
          );
        },
      ),
    );
  }
}
