// =============================================================================
// theme.dart - IDENTIDADE VISUAL: paleta, faixas de tela, tema e logo
// =============================================================================
//
// Reune quatro coisas:
//   * Paleta        -> as cores da marca
//   * Tela (enum)   -> faixas de largura (celular/tablet/notebook/desktop)
//   * AppTheme      -> ThemeData claro e escuro derivados da paleta
//   * ContentWidth / LogoAcontece -> widgets de apoio visual
// =============================================================================

// Widgets Material (Color, ThemeData, Container, Row, Text...).
import 'package:material_ui/material_ui.dart';

/// Paleta da marca Acontece: cinco tons de azul, do ciano ao marinho.
class Paleta {
  /// Construtor privado: so membros estaticos, nunca se cria um objeto.
  const Paleta._();

  // `Color(0xFFRRGGBB)`: cor em hexadecimal. `0x` = hexa; os dois primeiros
  // digitos (FF) sao a opacidade (FF = 100% opaco); os outros seis, RGB.

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
  /// `begin`/`end` = direcao; `colors` = cores; `stops` = onde (0 a 1) cada
  /// cor "chega" ao seu tom puro.
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
  /// Lista de listas: cada item interno e um par [cor inicial, cor final].
  static const List<List<Color>> degradesEvento = [
    [azul, marinho],
    [turquesa, petroleo],
    [petroleo, marinho],
    [turquesa, azul],
    [azul, petroleo],
  ];
}

/// Faixas de largura de tela. Todo layout responsivo do site decide por aqui,
/// em vez de comparar larguras soltas em cada tela.
///
///  * celular: < 600 — navegacao inferior, uma coluna
///  * tablet: 600 a 899 — barra lateral compacta, so icones
///  * notebook: 900 a 1279 — barra lateral completa
///  * desktop: >= 1280 — barra lateral completa e conteudo mais largo
///
/// CONCEITO - "enum com membros" (Dart moderno): alem de listar valores, o
/// enum pode ter metodos e getters. O `;` apos o ultimo valor abre essa parte.
enum Tela {
  celular,
  tablet,
  notebook,
  desktop;

  /// Converte uma largura em pixels na faixa correspondente.
  /// Ternarios encadeados: "se < 600 celular, senao se < 900 tablet, ...".
  static Tela daLargura(double largura) => largura < 600
      ? celular
      : largura < 900
      ? tablet
      : largura < 1280
      ? notebook
      : desktop;

  /// Faixa da janela atual. `MediaQuery.sizeOf(context)` le o tamanho da janela
  /// (e reconstroi o widget se ele mudar, por exemplo ao redimensionar).
  static Tela of(BuildContext context) =>
      daLargura(MediaQuery.sizeOf(context).width);

  // `this` aqui e o proprio valor do enum.
  bool get ehCelular => this == celular;
  bool get ehTablet => this == tablet;

  /// Notebook ou desktop: cabe barra lateral completa e layout em colunas.
  bool get ehLarga => this == notebook || this == desktop;

  /// Respiro lateral do conteudo.
  /// `switch` como expressao: devolve um valor conforme o caso.
  double get margem => switch (this) {
    celular => 16,
    tablet => 24,
    notebook => 32,
    desktop => 40,
  };

  /// Largura maxima do conteudo. Sem limite, em monitor largo as listas
  /// esticariam por 2000 px e o site ficaria ilegivel.
  double get larguraMaxima => this == desktop ? 1280 : 1100;
}

/// Tema do site, construido a partir da paleta da marca, claro e escuro.
///
/// CONCEITO - ThemeData/ColorScheme: o Flutter le o tema para pintar todos os
/// widgets. Definir cores/formatos aqui evita repetir estilo em cada tela.
class AppTheme {
  const AppTheme._();

  /// Tema claro (o unico usado de fato; ver main.dart).
  static ThemeData light() => _base(_claro());

  /// Tema escuro (pronto, mas desligado em main.dart).
  static ThemeData dark() => _base(_escuro());

  /// Esquema de cores claro.
  /// `fromSeed` gera um esquema inteiro a partir de uma cor "semente"; em
  /// seguida `copyWith` sobrescreve so os papeis que queremos fixar na paleta.
  /// Papeis: primary (cor de destaque), secondary, tertiary, surface (fundos),
  /// onX (cor do texto/icone sobre X), outline (bordas), etc.
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

  /// Esquema de cores escuro (mesma ideia, tons invertidos).
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

  /// Monta o ThemeData completo a partir de um esquema de cores.
  /// Cada `xxxTheme` abaixo define o visual PADRAO daquele tipo de widget.
  static ThemeData _base(ColorScheme scheme) {
    // Tema temporario so para obter os estilos de texto padrao do Material.
    final base = ThemeData(colorScheme: scheme);
    final texto = base.textTheme;
    return ThemeData(
      colorScheme: scheme,
      // Cor de fundo das telas (Scaffold).
      scaffoldBackgroundColor: scheme.surface,
      // Espacamento padrao dos widgets (nem compacto, nem folgado).
      visualDensity: VisualDensity.standard,
      // Ajusta pesos/espacamento dos titulos. `?.` evita erro se o estilo for
      // nulo; `w800` = negrito extra; `letterSpacing` negativo aproxima as
      // letras.
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
      // Barra superior (AppBar): fundo, cor do texto/icone e estilo do titulo.
      appBarTheme: AppBarThemeData(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        // Sem tom colorido de "elevacao" do Material 3.
        surfaceTintColor: Colors.transparent,
        // Titulo alinhado a esquerda (e nao centralizado).
        centerTitle: false,
        // Sombra leve so quando o conteudo rola por baixo da barra.
        scrolledUnderElevation: 1,
        titleTextStyle: texto.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
      // Cartoes: sem sombra, borda fina, cantos de 18 px.
      cardTheme: CardThemeData(
        // Recorta o conteudo (imagens) nos cantos arredondados.
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        color: scheme.surfaceContainerLowest,
        // Sem margem externa: quem usa o Card decide o espacamento.
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      // Campos de texto: preenchidos, borda arredondada, borda mais grossa
      // quando em foco.
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        // `border` = padrao; `enabledBorder` = campo habilitado;
        // `focusedBorder` = campo com o cursor dentro.
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
      // Estados desabilitados com contraste legivel. O padrao do Material 3
      // (texto 38% sobre fundo 12%) da 2,3:1 nesta paleta, e botoes como
      // "Evento encerrado" ficavam ilegiveis.
      // Botao preenchido (acao principal).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          disabledBackgroundColor: scheme.surfaceContainerHighest,
          disabledForegroundColor: scheme.onSurfaceVariant,
          // Espaco interno: 22 px nos lados, 18 px em cima e embaixo.
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      // Botao com contorno (acao secundaria).
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          disabledForegroundColor: scheme.onSurfaceVariant,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      // Botao de texto (acao terciaria).
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          disabledForegroundColor: scheme.onSurfaceVariant,
        ),
      ),
      // Indicadores de progresso (circulo/barra de carregamento).
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        // Cor do "trilho" (parte ainda nao preenchida) da barra linear.
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
      // Botao flutuante (FAB).
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      // Chips (selos/filtros): 999 de raio = formato de pilula.
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      // Barra de navegacao inferior (celular): fundo e cor do "indicador" que
      // marca o item selecionado.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.primaryContainer,
      ),
      // Mensagens temporarias (SnackBar) "flutuam" em vez de colar embaixo.
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      // Caixas de dialogo com cantos arredondados.
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      // Linhas divisorias finas (`space: 1` = ocupam 1 px de altura).
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }
}

/// Centraliza e limita a largura do conteudo, com respiro lateral que cresce
/// do celular ao desktop.
///
/// CONCEITO - StatelessWidget: widget sem estado interno; `build` apenas
/// descreve a interface a partir dos parametros recebidos.
class ContentWidth extends StatelessWidget {
  /// `required this.child`: o filho e obrigatorio; `this.maxWidth` e opcional.
  const ContentWidth({super.key, required this.child, this.maxWidth});

  /// Widget que sera centralizado e limitado em largura.
  final Widget child;

  /// Teto de largura. Sem valor, usa o da faixa de tela ([Tela.larguraMaxima]);
  /// formularios passam um valor menor para nao ficarem esticados.
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    // Faixa da tela atual (celular, tablet...).
    final tela = Tela.of(context);
    // Center: centraliza o filho (e por isso um filho estreito fica no meio;
    // ver aviso no CLAUDE.md sobre `SizedBox(width: double.infinity)`).
    return Center(
      // ConstrainedBox: impoe largura maxima ao filho.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          // Largura do conteudo + margem dos dois lados.
          maxWidth: (maxWidth ?? tela.larguraMaxima) + tela.margem * 2,
        ),
        // Padding: afastamento lateral conforme a faixa.
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: tela.margem),
          child: child,
        ),
      ),
    );
  }
}

/// Marca do site: icone em degrade e o nome.
class LogoAcontece extends StatelessWidget {
  const LogoAcontece({
    super.key,
    this.tamanho = 36,
    this.corTexto,
    this.mostrarNome = true,
  });

  /// Lado do quadrado do icone, em pixels logicos; o texto escala junto.
  final double tamanho;

  /// Cor do nome; nulo = cor padrao do tema.
  final Color? corTexto;

  /// Se `false`, mostra so o icone (barra lateral compacta).
  final bool mostrarNome;

  @override
  Widget build(BuildContext context) {
    // Quadrado com degrade, cantos arredondados e sombra, contendo um icone.
    final icone = Container(
      width: tamanho,
      height: tamanho,
      // BoxDecoration: fundo (degrade), borda arredondada e sombra.
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Paleta.ciano, Paleta.turquesa, Paleta.azul],
        ),
        // Raio proporcional ao tamanho (30%).
        borderRadius: BorderRadius.circular(tamanho * 0.3),
        boxShadow: [
          BoxShadow(
            // `withValues(alpha:)` aplica transparencia (0 a 1) a cor.
            color: Paleta.turquesa.withValues(alpha: 0.35),
            // Quanto a sombra e "borrada" (espalhada).
            blurRadius: tamanho * 0.4,
            // Deslocamento da sombra (x, y).
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
    // So o icone: devolve cedo.
    if (!mostrarNome) return icone;

    // Row = widgets lado a lado (horizontal).
    return Row(
      // `min`: a linha ocupa so o espaco necessario, nao a largura toda.
      mainAxisSize: MainAxisSize.min,
      children: [
        icone,
        // SizedBox: espaco vazio de tamanho fixo entre icone e texto.
        SizedBox(width: tamanho * 0.3),
        // Flexible: deixa o texto encolher em vez de estourar a linha
        // (evita overflow em telas estreitas).
        Flexible(
          child: Text(
            'Acontece',
            // Uma linha so; sem quebrar.
            maxLines: 1,
            // Se nao couber, desvanece o fim em vez de quebrar linha.
            overflow: TextOverflow.fade,
            softWrap: false,
            style: TextStyle(
              fontSize: tamanho * 0.62,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              // Cor informada, ou a cor de texto do tema atual.
              color: corTexto ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
