import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'core/theme.dart';
import 'screens/home_shell.dart';
import 'services.dart';

void main() {
  // Carrega os dados de locale do intl antes do primeiro `DateFormat` com
  // nome de mes em portugues ("4 de dezembro de 2026").
  initializeDateFormatting('pt_BR');
  Intl.defaultLocale = 'pt_BR';

  runApp(Services(child: const AconteceApp()));
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
