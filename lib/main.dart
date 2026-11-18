// =============================================================================
// main.dart - PONTO DE ENTRADA DO APLICATIVO
// =============================================================================
//
// Todo programa Dart comeca pela funcao `main()`. Em um app Flutter, o papel
// dela e preparar o que for preciso (aqui: datas em portugues) e chamar
// `runApp(...)`, que recebe o widget raiz e o desenha na tela.
//
// CONCEITO BASICO - "widget": no Flutter, TUDO o que aparece na tela e um
// widget (texto, botao, coluna, a tela inteira, o app inteiro). Widgets sao
// montados uns dentro dos outros, formando a "arvore de widgets".
//
// Estrutura da arvore montada aqui:
//
//   Services (entrega sessao e repositorios para todos os filhos)
//     └── AconteceApp (configura tema, idioma e navegacao)
//           └── MaterialApp
//                 └── ListenableBuilder (escuta a sessao)
//                       ├── LoginScreen  (se ninguem estiver logado)
//                       └── HomeShell    (se houver usuario logado)
// =============================================================================

// `import` traz codigo de outro arquivo/pacote para dentro deste arquivo.
// `package:` indica um pacote externo, declarado no pubspec.yaml.

// Traz a funcao `initializeDateFormatting`, que carrega os nomes de meses e
// dias da semana de cada idioma (o pacote intl nao os carrega sozinho).
import 'package:intl/date_symbol_data_local.dart';
// Pacote intl: formata datas e numeros conforme o idioma. Daqui vem a classe
// `Intl`, usada abaixo para escolher o idioma padrao.
import 'package:intl/intl.dart';
// Biblioteca de widgets Material (botoes, cards, tema, MaterialApp...).
// Neste projeto usa-se `material_ui` no lugar de
// `package:flutter/material.dart` (decisao do projeto, ver CLAUDE.md).
import 'package:material_ui/material_ui.dart';

// Imports relativos (sem `package:`) apontam para arquivos do proprio app.
// Espaco reservado para o selo do Netlify no canto inferior da pagina.
import 'infraestrutura/area_selo.dart';
// Tema visual (cores, fontes) do app: daqui vem a classe `AppTheme`.
import 'infraestrutura/theme.dart';
// Tela de login/cadastro, exibida quando ninguem esta logado.
import 'telas/autenticacao/login_screen.dart';
// "Casca" do app logado: menu lateral/inferior + abas.
import 'telas/home_shell.dart';
// Widget que entrega a sessao e os repositorios para a arvore inteira.
import 'services.dart';

/// Funcao principal: e a primeira coisa executada quando o site abre.
///
/// `void` significa que a funcao nao devolve nenhum valor.
void main() {
  // Carrega os dados de locale do intl antes do primeiro `DateFormat` com
  // nome de mes em portugues ("4 de dezembro de 2026").
  // 'pt_BR' = codigo do idioma portugues do Brasil.
  initializeDateFormatting('pt_BR');
  // Define o portugues do Brasil como idioma PADRAO de toda formatacao do
  // intl. Assim um `DateFormat(...)` sem idioma explicito ja sai em pt_BR.
  Intl.defaultLocale = 'pt_BR';

  // `runApp` pega o widget raiz e o coloca na tela; a partir dai o Flutter
  // cuida de desenhar e redesenhar tudo.
  // `Services` fica no topo para que QUALQUER tela consiga pedir a sessao e os
  // repositorios com `Services.of(context)`.
  // `const` diante de um construtor cria o objeto em tempo de compilacao:
  // o Flutter reaproveita a mesma instancia e evita reconstrucoes inuteis.
  runApp(Services(child: const AconteceApp()));
}

/// Widget raiz do app: configura tema, idioma e qual tela aparece primeiro.
///
/// CONCEITO - StatefulWidget x StatelessWidget:
/// * `StatelessWidget` nao guarda estado proprio; so desenha o que recebe.
/// * `StatefulWidget` tem um objeto `State` separado que vive enquanto o widget
///   estiver na tela e pode guardar dados que mudam (ou, como aqui, objetos que
///   precisam sobreviver entre reconstrucoes, como a `GlobalKey`).
///
/// `extends` = heranca: AconteceApp "e um" StatefulWidget e ganha tudo dele.
class AconteceApp extends StatefulWidget {
  /// Construtor. `const` permite criar instancias constantes;
  /// `super.key` repassa a chave opcional (Key) para a classe-mae.
  const AconteceApp({super.key, this.reservaInferior});

  /// Espaco reservado na base da tela. Sem valor, usa [reservaInferiorPadrao]
  /// (o selo do Netlify); os testes informam um valor explicito.
  final double? reservaInferior;

  /// `@override` indica que estamos substituindo um metodo da classe-mae.
  /// `createState` diz ao Flutter qual objeto State usar para este widget.
  /// A sintaxe `=>` e uma "funcao de uma expressao": equivale a
  /// `{ return ...; }`.
  @override
  State<AconteceApp> createState() => _AconteceAppState();
}

/// Estado do [AconteceApp] (onde ficam os dados e o metodo `build`).
///
/// Nomes que comecam com `_` sao PRIVADOS ao arquivo em Dart (nao podem ser
/// usados por outros arquivos).
class _AconteceAppState extends State<AconteceApp> {
  /// Chave global do Navigator (o "gerenciador da pilha de telas").
  ///
  /// CONCEITO - GlobalKey: permite acessar um widget/estado especifico de fora
  /// do metodo `build`. Aqui e usada para chamar `popUntil` no Navigator quando
  /// o usuario sai da conta. `final` = a variavel recebe valor uma unica vez.
  /// `<NavigatorState>` diz o tipo de estado que essa chave aponta.
  final _navigator = GlobalKey<NavigatorState>();

  /// `build` descreve COMO a tela deve ficar. O Flutter chama esse metodo
  /// sempre que precisa redesenhar este widget.
  ///
  /// CONCEITO - BuildContext: e a "posicao" deste widget na arvore. Com ele e
  /// possivel procurar coisas que estao ACIMA na arvore (tema, Services...).
  @override
  Widget build(BuildContext context) {
    // Busca a sessao (quem esta logado) no Services, que esta acima na arvore.
    final sessao = Services.of(context).sessao;
    // MaterialApp configura o app inteiro: tema, idioma, rotas e navegacao.
    // E o widget "base" de qualquer app no estilo Material.
    return MaterialApp(
      // Titulo usado pelo navegador/sistema (texto da aba do navegador).
      title: 'Acontece',
      // Esconde a faixa vermelha "DEBUG" no canto da tela em desenvolvimento.
      debugShowCheckedModeBanner: false,
      // Liga a chave global ao Navigator que o MaterialApp cria por dentro.
      // Sem isso `_navigator.currentState` ficaria sempre nulo.
      navigatorKey: _navigator,
      // Tema claro (cores, fontes, formatos de botoes) de infraestrutura/theme.dart.
      theme: AppTheme.light(),
      // Tema escuro: existe, mas nao e usado (ver `themeMode` abaixo).
      darkTheme: AppTheme.dark(),
      // Forca sempre o tema claro, independentemente do sistema operacional.
      themeMode: ThemeMode.light,

      // Os textos internos do Material (date picker, "Cancelar", rotulos de
      // acessibilidade) vem do proprio material_ui, que ja inclui 'pt'.
      // "Delegates" sao os objetos que fornecem esses textos traduzidos.
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Idiomas que o app declara suportar. `Locale('pt', 'BR')` = portugues
      // do Brasil; `Locale('pt')` = portugues generico (reserva).
      supportedLocales: const [Locale('pt', 'BR'), Locale('pt')],
      // Idioma efetivamente usado: portugues do Brasil.
      locale: const Locale('pt', 'BR'),

      // `builder` envolve o Navigator: a reserva vale para todas as telas,
      // inclusive as empilhadas por cima da casca.
      builder: (context, child) => ReservaInferior(
        reserva: widget.reservaInferior ?? reservaInferiorPadrao(),
        child: child ?? const SizedBox.shrink(),
      ),

      // `home` e a primeira tela do app.
      // CONCEITO - ListenableBuilder: reconstroi o `builder` toda vez que o
      // objeto escutado (`listenable`) avisa que mudou. A sessao avisa ao
      // logar, sair ou expirar, entao a tela troca sozinha entre login e app.
      home: ListenableBuilder(
        // O objeto observado: a sessao (um ChangeNotifier).
        listenable: sessao,
        // Funcao que monta a tela. `(context, _)`: o `_` e um parametro que
        // nao sera usado (o "child" opcional do ListenableBuilder).
        builder: (context, _) {
          // Usuario atualmente logado; `null` se ninguem estiver logado.
          final usuario = sessao.usuario;
          // Ninguem logado?
          if (usuario == null) {
            // Ao sair (ou expirar), fecha telas e dialogos que estavam
            // abertos por cima: eles dependiam do usuario que saiu.
            // `addPostFrameCallback` agenda o codigo para DEPOIS que o quadro
            // atual terminar de ser desenhado (nao se pode navegar durante o
            // `build`). `?.` so chama o metodo se `currentState` nao for nulo.
            // `popUntil((r) => r.isFirst)` remove telas da pilha ate sobrar so
            // a primeira (`r` e cada rota; `isFirst` = e a rota de baixo?).
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _navigator.currentState?.popUntil((r) => r.isFirst),
            );
            // Sem usuario: mostra a tela de entrada.
            return const LoginScreen();
          }
          // A chave recria a casca inteira quando muda o usuario, para nao
          // sobrar dado de uma conta na tela da outra.
          // CONCEITO - Key/ValueKey: quando a chave muda, o Flutter descarta o
          // widget antigo (e seu estado) e cria um novo do zero. A chave aqui
          // e um texto "id-PAPEL", unico por usuario.
          return HomeShell(
            key: ValueKey('${usuario.id}-${usuario.papel.wire}'),
            // Repassa o usuario logado para a casca (e dela para as abas).
            usuario: usuario,
          );
        },
      ),
    );
  }
}
