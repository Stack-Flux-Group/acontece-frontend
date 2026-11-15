import 'package:material_ui/material_ui.dart';

/// Paleta da marca Acontece: cinco tons de azul, do ciano ao marinho.
class Paleta {
  const Paleta._();

  /// #A7EBF2 — azul-claro / ciano suave.
  static const Color ciano = Color(0xFFA7EBF2);

  /// #54ACBF — azul-turquesa.
  static const Color turquesa = Color(0xFF54ACBF);

  /// #26658C — azul medio.
  static const Color azul = Color(0xFF26658C);

  /// #023859 — azul-petroleo escuro.
  static const Color petroleo = Color(0xFF023859);

  /// #011C40 — azul-marinho profundo.
  static const Color marinho = Color(0xFF011C40);

  /// Degrade principal: do marinho ao azul medio. Usado na barra lateral, na
  /// tela de login e nos cabecalhos.
  static const LinearGradient degradeProfundo = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [marinho, petroleo, azul],
    stops: [0, 0.55, 1],
  );

  /// Degrade claro, para destaques (logo, placeholders de foto).
  static const LinearGradient degradeVivo = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [turquesa, azul],
  );

  /// Variacoes de degrade para os eventos sem foto: cada evento ganha sempre a
  /// mesma (pelo id), e a grade fica variada sem sair da paleta.
  static const List<List<Color>> degradesEvento = [
    [azul, marinho],
    [turquesa, petroleo],
    [petroleo, marinho],
    [turquesa, azul],
    [azul, petroleo],
  ];
}

/// Tema do site, construido a partir da paleta da marca, claro e escuro.
class AppTheme {
  const AppTheme._();

  /// Largura maxima do conteudo. Sem isso, em monitor largo as listas esticam
  /// por 2000 px e o site fica ilegivel.
  static const double maxContentWidth = 1100;

  /// Abaixo disso a navegacao vai para a barra inferior.
  static const double compactBreakpoint = 900;

  static ThemeData light() => _base(_claro());
  static ThemeData dark() => _base(_escuro());

  static ColorScheme _claro() =>
      ColorScheme.fromSeed(
        seedColor: Paleta.azul,
        brightness: Brightness.light,
      ).copyWith(
        primary: Paleta.azul,
        onPrimary: Colors.white,
        primaryContainer: Paleta.ciano,
        onPrimaryContainer: Paleta.marinho,
        secondary: Paleta.petroleo,
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFD9F6FA),
        onSecondaryContainer: Paleta.petroleo,
        tertiary: Paleta.turquesa,
        onTertiary: Paleta.marinho,
        tertiaryContainer: const Color(0xFFC9EEF5),
        onTertiaryContainer: Paleta.marinho,
        surface: const Color(0xFFF6FAFC),
        onSurface: Paleta.marinho,
        onSurfaceVariant: const Color(0xFF41606F),
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFF0F7FA),
        surfaceContainer: const Color(0xFFE9F3F7),
        surfaceContainerHigh: const Color(0xFFE2EEF3),
        surfaceContainerHighest: const Color(0xFFDAE9F0),
        outline: const Color(0xFF7FA2B4),
        outlineVariant: const Color(0xFFD2E3EB),
        inversePrimary: Paleta.ciano,
      );

  static ColorScheme _escuro() =>
      ColorScheme.fromSeed(
        seedColor: Paleta.azul,
        brightness: Brightness.dark,
      ).copyWith(
        primary: Paleta.turquesa,
        onPrimary: Paleta.marinho,
        primaryContainer: Paleta.azul,
        onPrimaryContainer: Paleta.ciano,
        secondary: Paleta.ciano,
        onSecondary: Paleta.marinho,
        secondaryContainer: Paleta.petroleo,
        onSecondaryContainer: Paleta.ciano,
        tertiary: Paleta.ciano,
        onTertiary: Paleta.marinho,
        tertiaryContainer: const Color(0xFF0B4A6B),
        onTertiaryContainer: Paleta.ciano,
        surface: const Color(0xFF00142F),
        onSurface: const Color(0xFFE3F4F8),
        onSurfaceVariant: const Color(0xFFA9C6D3),
        surfaceContainerLowest: const Color(0xFF000E24),
        surfaceContainerLow: const Color(0xFF011A3B),
        surfaceContainer: Paleta.marinho,
        surfaceContainerHigh: const Color(0xFF02284D),
        surfaceContainerHighest: Paleta.petroleo,
        outline: const Color(0xFF5E8599),
        outlineVariant: const Color(0xFF1C3F5C),
        inversePrimary: Paleta.azul,
      );

  static ThemeData _base(ColorScheme scheme) {
    final base = ThemeData(colorScheme: scheme);
    final texto = base.textTheme;
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
      textTheme: texto.copyWith(
        headlineLarge: texto.headlineLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        headlineMedium: texto.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        headlineSmall: texto.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleLarge: texto.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: texto.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        scrolledUnderElevation: 1,
        titleTextStyle: texto.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        color: scheme.surfaceContainerLowest,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.primaryContainer,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }
}

/// Centraliza e limita a largura do conteudo, com respiro lateral no celular.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = AppTheme.maxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: child,
      ),
    ),
  );
}

/// Marca do site: icone em degrade e o nome.
class LogoAcontece extends StatelessWidget {
  const LogoAcontece({
    super.key,
    this.tamanho = 36,
    this.corTexto,
    this.mostrarNome = true,
  });

  final double tamanho;
  final Color? corTexto;
  final bool mostrarNome;

  @override
  Widget build(BuildContext context) {
    final icone = Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Paleta.ciano, Paleta.turquesa, Paleta.azul],
        ),
        borderRadius: BorderRadius.circular(tamanho * 0.3),
        boxShadow: [
          BoxShadow(
            color: Paleta.turquesa.withValues(alpha: 0.35),
            blurRadius: tamanho * 0.4,
            offset: Offset(0, tamanho * 0.12),
          ),
        ],
      ),
      child: Icon(
        Icons.celebration_rounded,
        color: Paleta.marinho,
        size: tamanho * 0.58,
      ),
    );
    if (!mostrarNome) return icone;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icone,
        SizedBox(width: tamanho * 0.3),
        Flexible(
          child: Text(
            'Acontece',
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: TextStyle(
              fontSize: tamanho * 0.62,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: corTexto ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
