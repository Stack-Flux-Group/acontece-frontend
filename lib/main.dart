import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'core/api_client.dart';
import 'core/demo_backend.dart';
import 'core/theme.dart';
import 'screens/home_shell.dart';
import 'services.dart';

void main() {
  // Carrega os dados de locale do intl antes do primeiro `DateFormat` com
  // nome de mes em portugues ("4 de dezembro de 2026").
  initializeDateFormatting('pt_BR');
  Intl.defaultLocale = 'pt_BR';

  // Por padrao o app roda com um back-end falso em memoria, para ser
  // visualizado sem a API e sem o proxy. Para usar a API de verdade:
  // `--dart-define=USE_API=true` (e o tools/dev_proxy.mjs na 8081).
  const usarApi = bool.fromEnvironment('USE_API');
  runApp(
    Services(
      client: usarApi ? null : ApiClient(client: DemoBackend().client),
      child: const AconteceApp(),
    ),
  );
}

class AconteceApp extends StatelessWidget {
  const AconteceApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Acontece',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),

    // Os textos internos do Material (date picker, "Cancelar", rotulos de
    // acessibilidade) vem do proprio material_ui, que ja inclui 'pt'.
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('pt', 'BR'), Locale('pt')],
    locale: const Locale('pt', 'BR'),

    home: const HomeShell(),
  );
}
