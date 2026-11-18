// =============================================================================
// app_test.dart - TESTES DE INTERFACE (widget tests) DO APP INTEIRO
// =============================================================================
//
// CONCEITO - widget test: monta o app de verdade (telas reais), mas dentro do
// ambiente de teste do Flutter, sem navegador. Em vez de clicar com o mouse, o
// teste usa o `WidgetTester` para "tocar" e "digitar", e depois confere o que
// apareceu na tela.
//
// CONCEITO - cliente HTTP falso (MockClient): a rede NAO e usada. Cada pedido
// recebe uma resposta pronta (copiada de respostas reais da API). Assim o teste
// e rapido, repetivel e nao depende de internet.
//
// Ferramentas do `WidgetTester` usadas aqui:
//   * pumpWidget(w)      monta o widget `w` na tela de teste
//   * pumpAndSettle()    avanca o tempo ate nao haver mais animacao/atualizacao
//   * tap(finder)        simula um toque/clique
//   * enterText(f, txt)  digita texto num campo
//   * getSize/getTopLeft mede um widget ja desenhado
// "Finders" localizam widgets: find.text, find.byType, find.byIcon,
// find.byTooltip, find.textContaining. Matchers: findsOneWidget, findsNothing,
// findsWidgets, findsNWidgets(n).
// =============================================================================

import 'dart:convert';

import 'package:acontece_frontend/infraestrutura/api_client.dart';
import 'package:acontece_frontend/infraestrutura/token_storage.dart';
import 'package:acontece_frontend/main.dart';
import 'package:acontece_frontend/modelos_da_api/auth.dart';
import 'package:acontece_frontend/services.dart';
import 'package:acontece_frontend/componentes_visuais/evento_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
// `MockClient`: cliente HTTP de mentira, vindo do pacote http.
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// Testes de interface com um cliente HTTP falso que devolve exatamente os
/// corpos que a API em producao devolve. Assim a UI e exercitada de verdade
/// (login, papeis, datas naive com fracao de segundo) sem depender da rede.

/// Eventos no formato de `GET /eventos` (itens de `content`).
/// (Texto de varias linhas com ''' ... '''.)
const _eventosJson = '''
[{"id":1,"titulo":"Radar Tech","descricao":"Evento da Semana Academica",
  "dataInicio":"2026-12-04T17:06:44.19","dataFim":"2026-12-08T17:06:44.19",
  "vagas":200,"vagasDisponiveis":200,
  "endereco":{"cep":"85601-000","logradouro":"Avenida Julio Assis Cavalheiro",
    "bairro":"Centro","cidade":"Francisco Beltrao","uf":"PR","numero":"02"},
  "fotoUrl":null},
 {"id":2,"titulo":"Evento de RAP","descricao":"EVENTO RAP",
  "dataInicio":"2026-11-12T17:29:36.487","dataFim":"2026-11-13T17:29:36.487",
  "vagas":1,"vagasDisponiveis":1,
  "endereco":{"cep":"85601-336","logradouro":"Rua Silvia Abdala",
    "bairro":"Agua Branca","cidade":"Francisco Beltrao","uf":"PR",
    "numero":"123"},
  "fotoUrl":null}]
''';

/// Apenas o primeiro evento (resposta de `GET /eventos/1`): decodifica a
/// lista, pega o item 0 e volta a transformar em texto JSON.
String get _radarTech => jsonEncode((jsonDecode(_eventosJson) as List)[0]);

/// O mesmo evento com [ocupadas] vagas preenchidas: a API manda `vagas` e
/// `vagasDisponiveis` (capacidade menos as inscricoes ativas).
///
/// Os parametros entre `{ }` sao nomeados (`vagas: 200`); `vagas = 10` e o valor
/// usado quando o teste nao informa. O `...` (spread) copia todos os campos do
/// evento original, e as chaves seguintes SOBRESCREVEM `vagas` e
/// `vagasDisponiveis`. `clamp(0, vagas)` impede numero negativo.
String _radarTechCom(int ocupadas, {int vagas = 10}) => jsonEncode({
  ...(jsonDecode(_eventosJson) as List)[0] as Map<String, dynamic>,
  'vagas': vagas,
  'vagasDisponiveis': (vagas - ocupadas).clamp(0, vagas),
});

/// Resposta paginada de `GET /eventos` ({content, page}) a partir de uma lista
/// JSON de eventos. E o formato do Spring Data, igual ao de `/inscricoes` e
/// `/participantes`: os itens ficam em `content` e os numeros de paginacao em
/// `page`. [numero] e [totalPaginas] permitem simular varias paginas.
String _paginaEventos(String lista, {int numero = 0, int totalPaginas = 1}) {
  final itens = jsonDecode(lista) as List;
  return jsonEncode({
    'content': itens,
    'page': {
      'size': 100,
      'number': numero,
      'totalElements': itens.length,
      'totalPages': totalPaginas,
    },
  });
}

/// Resposta 200 de `GET /eventos` com todos os eventos de [lista] numa pagina.
/// Os testes usam `'/eventos': _okLista(...)` no lugar da antiga rota de lista.
http.Response _okLista(String lista) => _ok(_paginaEventos(lista));

/// Botao preenchido que contem [rotulo], para o teste conferir se esta
/// habilitado (`onPressed != null`) ou desabilitado (`onPressed == null`).
/// Usa predicado porque
/// `FilledButton.icon` cria uma subclasse, que `find.byType` nao encontraria.
FilledButton _botao(WidgetTester tester, String rotulo) =>
    tester.widget<FilledButton>(
      find.ancestor(
        of: find.text(rotulo),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );

/// Resposta 409 da API com a [mensagem] informada (mesmo envelope de erro que o
/// back-end usa: status, error, message, path e fieldErrors).
http.Response _conflito(String mensagem) => _erro(
  '{"status":409,"error":"Conflict","message":"$mensagem",'
  '"path":"/inscricoes","fieldErrors":[]}',
  409,
);

/// Resposta de `POST /inscricoes`: a inscricao criada, sempre PENDENTE.
const _minhaInscricao =
    '{"id":10,"participanteId":7,"participanteNome":"Maria",'
    '"eventoId":1,"eventoTitulo":"Radar Tech","status":"PENDENTE",'
    '"dataInscricao":"2026-11-15T10:00:00"}';

/// Pagina vazia no formato do Spring Data.
const _paginaVazia =
    '{"content":[],"page":{"size":20,"number":0,"totalElements":0,'
    '"totalPages":0}}';

/// JWT no formato do `TokenService` (a assinatura nao importa no cliente).
/// `exp: 4102444800` = ano 2100 (nunca vence durante o teste).
String _jwt(int id, String email, Papel papel) {
  String parte(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${parte({'alg': 'HS256'})}.${parte({'sub': '$id', 'email': email, 'papel': papel.wire, 'exp': 4102444800})}.sig';
}

/// Usuario "ja logado" de teste: id 1 = organizador, id 7 = participante.
UsuarioLogado _usuario(Papel papel) {
  final id = papel == Papel.organizador ? 1 : 7;
  final email = papel == Papel.organizador
      ? 'org@acontece.com'
      : 'maria@exemplo.com';
  return UsuarioLogado(
    token: _jwt(id, email, papel),
    id: id,
    papel: papel,
    email: email,
    expiraEm: DateTime.utc(2100),
  );
}

/// Requisicoes que o app fez, para os testes conferirem rota, metodo e token.
final _pedidos = <http.Request>[];

/// Monta o app com um cliente que responde conforme [rotas]. Com [logado], a
/// sessao ja comeca salva no storage, como depois de recarregar a pagina.
///
/// [responder] e uma funcao que, dado o pedido, devolve um mapa
/// "final do caminho" -> resposta. O primeiro caminho que terminar com a chave
/// vence; se nenhum casar, responde 404.
Widget _appCom(
  Map<String, http.Response> Function(http.Request) responder, {
  Papel? logado,
}) {
  // Zera o historico de pedidos a cada teste.
  _pedidos.clear();
  final mock = MockClient((request) async {
    // Registra o pedido para conferencia posterior.
    _pedidos.add(request);
    final respostas = responder(request);
    for (final entry in respostas.entries) {
      if (request.url.path.endsWith(entry.key)) return entry.value;
    }
    // Rota que o teste nao previu: 404 explicito (ajuda a achar o erro).
    return http.Response(
      '{"status":404,"message":"rota nao mapeada no teste",'
      '"path":"${request.url.path}","fieldErrors":[]}',
      404,
    );
  });

  // Armazenamento em memoria; com `logado`, ja nasce com a sessao salva.
  final storage = MemoryTokenStorage(
    logado == null ? null : jsonEncode(_usuario(logado).toJson()),
  );
  // Mesmo `Services` do app real, mas com o HTTP e o storage de teste
  // (e por isso que a injecao de dependencias existe).
  return Services(
    client: ApiClient(client: mock),
    storage: storage,
    child: const AconteceApp(),
  );
}

/// Resposta HTTP de sucesso em UTF-8 (para os acentos chegarem certos).
http.Response _ok(String corpo, [int status = 200]) => http.Response.bytes(
  utf8.encode(corpo),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Resposta de erro (mesmo formato; so muda o status).
http.Response _erro(String corpo, int status) => _ok(corpo, status);

/// Tela larga (barra lateral) por padrao; [largura] < 900 testa o celular.
///
/// Sem isto o teste roda em 800x600, no layout estreito. `devicePixelRatio = 1`
/// faz 1 pixel fisico = 1 pixel logico (medidas previsiveis). `addTearDown`
/// restaura a janela ao fim do teste.
void _tela(WidgetTester tester, {double largura = 1400, double altura = 1400}) {
  tester.view.physicalSize = Size(largura, altura);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  // `setUpAll` roda UMA vez antes de todos os testes: prepara os dados de
  // idioma (datas em portugues) exigidos pelo `intl`.
  setUpAll(() {
    initializeDateFormatting('pt_BR');
    Intl.defaultLocale = 'pt_BR';
  });

  group('login', () {
    // `testWidgets` e o `test` dos widgets: recebe o `tester`.
    testWidgets('sem sessao, o site abre na tela de entrada', (tester) async {
      _tela(tester);
      await tester.pumpWidget(_appCom((_) => {}));
      await tester.pumpAndSettle();

      expect(find.text('Bem-vindo de volta'), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
      expect(find.text('Criar conta'), findsOneWidget);
      // Nenhuma rota protegida foi chamada sem token.
      expect(_pedidos, isEmpty);
    });

    testWidgets('mostra a recusa da API quando a senha esta errada', (
      tester,
    ) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          (_) => {
            '/auth/login': _erro(
              '{"status":401,"error":"Unauthorized",'
              '"message":"E-mail ou senha inválidos","path":"/auth/login",'
              '"fieldErrors":[]}',
              401,
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Digita nos dois primeiros campos de texto (e-mail e senha).
      await tester.enterText(find.byType(TextFormField).at(0), 'x@x.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'errada123');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(find.text('E-mail ou senha inválidos'), findsOneWidget);
      expect(find.text('Bem-vindo de volta'), findsOneWidget);
    });

    testWidgets('entra, guarda o token e o envia nas chamadas seguintes', (
      tester,
    ) async {
      _tela(tester);
      final token = _jwt(7, 'maria@exemplo.com', Papel.participante);
      await tester.pumpWidget(
        _appCom(
          (_) => {
            '/auth/login': _ok(
              '{"token":"$token","tipo":"Bearer","expiraEmSegundos":7200,'
              '"usuarioId":7,"papel":"PARTICIPANTE"}',
            ),
            '/eventos': _okLista(_eventosJson),
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Maria@Exemplo.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'segredo123');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      // Procura, no historico, o pedido de login e confere o corpo enviado
      // (e-mail normalizado para minusculas).
      final login = _pedidos.firstWhere((p) => p.url.path == '/auth/login');
      expect(jsonDecode(login.body), {
        'email': 'maria@exemplo.com',
        'senha': 'segredo123',
      });
      // O login em si nao leva token (ainda nao existe).
      expect(login.headers.containsKey('Authorization'), isFalse);

      // O pedido seguinte ja leva o token no header.
      final eventos = _pedidos.firstWhere((p) => p.url.path == '/eventos');
      expect(eventos.headers['Authorization'], 'Bearer $token');

      expect(find.text('Descubra eventos'), findsOneWidget);
      expect(find.text('maria@exemplo.com'), findsOneWidget);
    });

    testWidgets('token recusado (401) volta para a entrada com aviso', (
      tester,
    ) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          // 401 com corpo vazio, como o filtro de seguranca do Spring.
          (_) => {'/eventos': http.Response('', 401)},
          logado: Papel.participante,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bem-vindo de volta'), findsOneWidget);
      // `textContaining`: acha o texto que CONTEM o trecho.
      expect(find.textContaining('Sua sessão expirou'), findsOneWidget);
    });

    testWidgets('sair volta para a tela de entrada', (tester) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          (_) => {'/eventos': _okLista(_eventosJson)},
          logado: Papel.organizador,
        ),
      );
      await tester.pumpAndSettle();

      // `byTooltip` acha o botao "Sair" da barra lateral.
      await tester.tap(find.byTooltip('Sair'));
      await tester.pumpAndSettle();

      expect(find.text('Bem-vindo de volta'), findsOneWidget);
    });

    testWidgets('criar conta valida o CPF antes de chamar a API', (
      tester,
    ) async {
      _tela(tester);
      await tester.pumpWidget(_appCom((_) => {}));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Criar conta'));
      await tester.pumpAndSettle();

      // Campos do cadastro, em ordem: 0 nome, 1 e-mail, 2 CPF, 3 telefone,
      // 4 senha, 5 confirmacao.
      final campos = find.byType(TextFormField);
      await tester.enterText(campos.at(0), 'Maria');
      await tester.enterText(campos.at(1), 'maria@exemplo.com');
      await tester.enterText(campos.at(2), '52998224726'); // digito errado
      await tester.enterText(campos.at(4), 'segredo123');
      await tester.enterText(campos.at(5), 'segredo123');
      await tester.tap(find.text('Criar conta e entrar'));
      await tester.pumpAndSettle();

      expect(find.text('CPF inválido'), findsOneWidget);
      // Validacao local barrou: a API nem foi chamada.
      expect(_pedidos, isEmpty);
    });

    testWidgets('criar conta cadastra com senha e ja entra', (tester) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          (_) => {
            '/participantes': _ok(
              '{"id":7,"nome":"Maria","email":"maria@exemplo.com",'
              '"cpf":"52998224725","telefone":null}',
              201,
            ),
            '/auth/login': _ok(
              '{"token":"${_jwt(7, 'maria@exemplo.com', Papel.participante)}",'
              '"tipo":"Bearer","expiraEmSegundos":7200,"usuarioId":7,'
              '"papel":"PARTICIPANTE"}',
            ),
            '/eventos': _okLista(_eventosJson),
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Criar conta'));
      await tester.pumpAndSettle();

      final campos = find.byType(TextFormField);
      await tester.enterText(campos.at(0), 'Maria');
      await tester.enterText(campos.at(1), 'maria@exemplo.com');
      await tester.enterText(campos.at(2), '529.982.247-25');
      await tester.enterText(campos.at(4), 'segredo123');
      await tester.enterText(campos.at(5), 'segredo123');
      await tester.tap(find.text('Criar conta e entrar'));
      await tester.pumpAndSettle();

      // O corpo do POST deve vir normalizado (CPF so digitos, telefone null).
      final cadastro = _pedidos.firstWhere(
        (p) => p.url.path == '/participantes',
      );
      expect(jsonDecode(cadastro.body), {
        'nome': 'Maria',
        'email': 'maria@exemplo.com',
        'cpf': '52998224725',
        'telefone': null,
        'senha': 'segredo123',
      });
      // Depois do cadastro, entrou sozinho.
      expect(find.text('Descubra eventos'), findsOneWidget);
    });
  });

  group('eventos', () {
    testWidgets('lista os eventos vindos da API', (tester) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          (_) => {'/eventos': _okLista(_eventosJson)},
          logado: Papel.participante,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Radar Tech'), findsOneWidget);
      expect(find.text('Evento de RAP'), findsOneWidget);
      expect(find.text('2 eventos'), findsOneWidget);
      // `findsNWidgets(2)`: exatamente 2 ocorrencias (um por cartao).
      expect(find.text('Francisco Beltrao - PR'), findsNWidgets(2));
      // Cada cartao mostra a ocupacao que a API calculou.
      expect(find.text('0/200 vagas preenchidas'), findsOneWidget);
      expect(find.text('0/1 vaga preenchida'), findsOneWidget);

      // "Evento de RAP" terminou em 13/11/2026; hoje, para o back-end, e o
      // relogio de Sao Paulo.
      expect(find.text('Encerrado'), findsOneWidget);
    });

    testWidgets('participante nao ve as acoes de organizador', (tester) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          (_) => {'/eventos': _okLista(_eventosJson)},
          logado: Papel.participante,
        ),
      );
      await tester.pumpAndSettle();

      // `findsNothing`: nao pode existir nenhum widget com esse texto.
      expect(find.text('Novo evento'), findsNothing);
      expect(find.text('Participantes'), findsNothing);
      expect(find.text('Minhas inscrições'), findsOneWidget);
      expect(find.text('Meu perfil'), findsOneWidget);
    });

    testWidgets('organizador ve criar evento e a aba de participantes', (
      tester,
    ) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          (_) => {'/eventos': _okLista(_eventosJson)},
          logado: Papel.organizador,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Novo evento'), findsOneWidget);
      expect(find.text('Participantes'), findsOneWidget);
      expect(find.text('Inscrições'), findsOneWidget);
    });

    testWidgets('mostra o estado vazio quando a API nao tem eventos', (
      tester,
    ) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          // `[]` = lista JSON vazia.
          (_) => {'/eventos': _okLista('[]')},
          logado: Papel.organizador,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nenhum evento cadastrado'), findsOneWidget);
    });

    testWidgets('mostra o erro da API e permite tentar de novo', (
      tester,
    ) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          (_) => {
            '/eventos': _erro(
              '{"status":500,"error":"Internal Server Error",'
              '"message":"Erro interno do servidor","path":"/eventos",'
              '"fieldErrors":[]}',
              500,
            ),
          },
          logado: Papel.participante,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Erro no servidor'), findsOneWidget);
      expect(find.text('Erro interno do servidor'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
    });

    testWidgets('participante se inscreve pelo detalhe do evento', (
      tester,
    ) async {
      _tela(tester);
      // Flag que muda de false para true quando o POST acontece, fazendo as
      // respostas seguintes de GET /inscricoes mudarem (simula o servidor).
      var inscrito = false;
      const minha =
          '{"content":[{"id":10,"participanteId":7,'
          '"participanteNome":"Maria","eventoId":1,"eventoTitulo":"Radar Tech",'
          '"status":"PENDENTE","dataInscricao":"2026-11-15T10:00:00"}],'
          '"page":{"size":50,"number":0,"totalElements":1,"totalPages":1}}';

      await tester.pumpWidget(
        _appCom((request) {
          if (request.method == 'POST' && request.url.path == '/inscricoes') {
            inscrito = true;
          }
          return {
            '/eventos': _okLista(_eventosJson),
            '/eventos/1': _ok(_radarTech),
            // Para POST devolve a inscricao criada; para GET, vazio antes de
            // se inscrever e com a inscricao depois.
            '/inscricoes': request.method == 'POST'
                ? _ok(_minhaInscricao, 201)
                : inscrito
                ? _ok(minha)
                : _ok(_paginaVazia),
          };
        }, logado: Papel.participante),
      );
      await tester.pumpAndSettle();

      // Abre o detalhe clicando no cartao.
      await tester.tap(find.text('Radar Tech'));
      await tester.pumpAndSettle();

      expect(find.text('Avenida Julio Assis Cavalheiro, 02'), findsOneWidget);
      // Participante nao ve editar/excluir.
      expect(find.text('Editar'), findsNothing);
      expect(find.text('Excluir'), findsNothing);

      await tester.tap(find.text('Quero me inscrever'));
      await tester.pumpAndSettle();

      final post = _pedidos.firstWhere((p) => p.method == 'POST');
      // So o evento vai no corpo: o participante vem do token.
      expect(jsonDecode(post.body), {'eventoId': 1});

      expect(find.text('Você está inscrito'), findsOneWidget);
      expect(find.text('Pendente'), findsOneWidget);
    });

    testWidgets('mostra a recusa da API ao se inscrever em evento lotado', (
      tester,
    ) async {
      _tela(tester);
      // Ao abrir ainda ha 1 vaga; outra pessoa a toma antes do POST chegar.
      var lotou = false;
      await tester.pumpWidget(
        _appCom((request) {
          if (request.method == 'POST') lotou = true;
          return {
            '/eventos': _okLista('[${_radarTechCom(9)}]'),
            '/eventos/1': _ok(_radarTechCom(lotou ? 10 : 9)),
            '/inscricoes': request.method == 'POST'
                // 409: a regra de negocio (vagas) e do servidor; o app so exibe.
                ? _conflito('Evento sem vagas disponíveis')
                : _ok(_paginaVazia),
          };
        }, logado: Papel.participante),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Radar Tech'));
      await tester.pumpAndSettle();
      expect(find.text('1 vaga disponível'), findsOneWidget);

      await tester.tap(find.text('Quero me inscrever'));
      await tester.pumpAndSettle();

      // A mensagem aparece (no snackbar) exatamente como veio da API.
      expect(find.text('Evento sem vagas disponíveis'), findsOneWidget);
      // E a tela recarregou o evento: agora mostra a situacao real.
      expect(find.text('10/10 vagas preenchidas'), findsOneWidget);
      expect(_botao(tester, 'Vagas esgotadas').onPressed, isNull);
    });

    testWidgets('inscricao duplicada recusada nao trava o botao por vagas', (
      tester,
    ) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          (request) => {
            '/eventos': _okLista(_eventosJson),
            '/eventos/1': _ok(_radarTech),
            '/inscricoes': request.method == 'POST'
                ? _conflito(
                    'Participante já possui inscrição ativa neste evento',
                  )
                : _ok(_paginaVazia),
          },
          logado: Papel.participante,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Radar Tech'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quero me inscrever'));
      await tester.pumpAndSettle();

      // Duplicada nao e falta de vaga: o botao continua disponivel.
      expect(find.text('Vagas esgotadas'), findsNothing);
      expect(_botao(tester, 'Quero me inscrever').onPressed, isNotNull);
    });

    testWidgets('participante ve vagas preenchidas e disponiveis', (
      tester,
    ) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          (_) => {
            '/eventos': _okLista('[${_radarTechCom(7)}]'),
            '/eventos/1': _ok(_radarTechCom(7)),
            '/inscricoes': _ok(_paginaVazia),
          },
          logado: Papel.participante,
        ),
      );
      await tester.pumpAndSettle();

      // O cartao da lista ja mostra a ocupacao.
      expect(find.text('7/10 vagas preenchidas'), findsOneWidget);

      await tester.tap(find.text('Radar Tech'));
      await tester.pumpAndSettle();

      expect(find.text('7/10 vagas preenchidas'), findsOneWidget);
      expect(find.text('3 vagas disponíveis'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(_botao(tester, 'Quero me inscrever').onPressed, isNotNull);
    });

    testWidgets('evento lotado bloqueia o botao e nao envia inscricao', (
      tester,
    ) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          (_) => {
            '/eventos': _okLista('[${_radarTechCom(10)}]'),
            '/eventos/1': _ok(_radarTechCom(10)),
            '/inscricoes': _ok(_paginaVazia),
          },
          logado: Papel.participante,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lotado (10/10)'), findsOneWidget);

      await tester.tap(find.text('Radar Tech'));
      await tester.pumpAndSettle();

      expect(find.text('10/10 vagas preenchidas'), findsOneWidget);
      expect(find.text('Nenhuma vaga disponível'), findsOneWidget);
      expect(find.text('Quero me inscrever'), findsNothing);
      expect(_botao(tester, 'Vagas esgotadas').onPressed, isNull);

      // O toque no botao desabilitado nao pode gerar pedido.
      await tester.tap(find.text('Vagas esgotadas'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_pedidos.where((p) => p.method == 'POST'), isEmpty);
    });

    testWidgets('organizador ve ocupacao e acoes no detalhe', (tester) async {
      _tela(tester);
      // A ocupacao vem no proprio evento (`vagasDisponiveis`): 6 de 200.
      final evento = _radarTechCom(6, vagas: 200);
      await tester.pumpWidget(
        _appCom(
          (_) => {'/eventos': _okLista('[$evento]'), '/eventos/1': _ok(evento)},
          logado: Papel.organizador,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Radar Tech'));
      await tester.pumpAndSettle();

      expect(find.text('6'), findsOneWidget);
      expect(find.text('de 200 vagas'), findsOneWidget);
      expect(find.text('Ver inscrições'), findsOneWidget);
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Excluir'), findsOneWidget);
      expect(find.text('Quero me inscrever'), findsNothing);
      // Sem as antigas consultas de contagem (`size=1`) em /inscricoes.
      expect(
        _pedidos.where(
          (p) =>
              p.url.path == '/inscricoes' &&
              p.url.queryParameters['size'] == '1',
        ),
        isEmpty,
      );
    });

    testWidgets('participante cancela a propria inscricao no detalhe', (
      tester,
    ) async {
      _tela(tester);
      var cancelada = false;
      const minha =
          '{"content":[{"id":10,"participanteId":7,"participanteNome":"Maria",'
          '"eventoId":1,"eventoTitulo":"Radar Tech","status":"CONFIRMADA",'
          '"dataInscricao":"2026-11-15T10:00:00"}],'
          '"page":{"size":50,"number":0,"totalElements":1,"totalPages":1}}';
      await tester.pumpWidget(
        _appCom((request) {
          if (request.method == 'PATCH') cancelada = true;
          return {
            '/eventos': _okLista('[${_radarTechCom(1)}]'),
            '/eventos/1': _ok(_radarTechCom(cancelada ? 0 : 1)),
            '/inscricoes/10/cancelar': _ok(
              '{"id":10,"participanteId":7,"participanteNome":"Maria",'
              '"eventoId":1,"eventoTitulo":"Radar Tech","status":"CANCELADA",'
              '"dataInscricao":"2026-11-15T10:00:00"}',
            ),
            // Depois de cancelar, a API deixa de ver inscricao ativa.
            '/inscricoes': _ok(cancelada ? _paginaVazia : minha),
          };
        }, logado: Papel.participante),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Radar Tech'));
      await tester.pumpAndSettle();

      expect(find.text('Você está inscrito'), findsOneWidget);
      await tester.tap(find.text('Cancelar inscrição'));
      await tester.pumpAndSettle();

      // Confirmacao antes de cancelar: nada foi enviado ainda.
      expect(find.text('Cancelar sua inscrição?'), findsOneWidget);
      expect(_pedidos.where((p) => p.method == 'PATCH'), isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, 'Cancelar inscrição'));
      await tester.pumpAndSettle();

      // PATCH sem corpo na rota propria do participante.
      final patch = _pedidos.firstWhere((p) => p.method == 'PATCH');
      expect(patch.url.path, '/inscricoes/10/cancelar');
      expect(patch.body, isEmpty);
      // A vaga voltou e a pessoa pode se inscrever de novo.
      expect(find.text('Quero me inscrever'), findsOneWidget);
      expect(find.text('Você está inscrito'), findsNothing);
    });
  });

  group('inscricoes', () {
    // Duas inscricoes: uma CONFIRMADA e uma CANCELADA (terminal).
    const inscricoes = '''
    {"content":[
      {"id":10,"participanteId":1,"participanteNome":"Maria Silva",
       "eventoId":1,"eventoTitulo":"Radar Tech","status":"CONFIRMADA",
       "dataInscricao":"2026-11-13T10:00:00"},
      {"id":11,"participanteId":2,"participanteNome":"Joao Souza",
       "eventoId":1,"eventoTitulo":"Radar Tech","status":"CANCELADA",
       "dataInscricao":"2026-11-14T09:30:00"}],
     "page":{"size":20,"number":0,"totalElements":2,"totalPages":1}}
    ''';

    testWidgets('organizador lista e so ve transicoes validas', (tester) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          (_) => {
            '/eventos': _okLista(_eventosJson),
            '/inscricoes': _ok(inscricoes),
          },
          logado: Papel.organizador,
        ),
      );
      await tester.pumpAndSettle();

      // Troca para a aba "Inscricoes" tocando no item do menu.
      await tester.tap(find.text('Inscrições'));
      await tester.pumpAndSettle();

      expect(find.text('Maria Silva'), findsOneWidget);
      expect(find.text('Joao Souza'), findsOneWidget);
      expect(find.text('1-2 de 2'), findsOneWidget);

      // CANCELADA e terminal: so a CONFIRMADA tem menu.
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // CONFIRMADA so pode ir para CANCELADA.
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Confirmar'), findsNothing);
    });

    testWidgets('participante ve as proprias inscricoes e so pode cancelar', (
      tester,
    ) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          (_) => {
            '/eventos': _okLista(_eventosJson),
            '/inscricoes': _ok(inscricoes),
          },
          logado: Papel.participante,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Minhas inscrições'));
      await tester.pumpAndSettle();

      // `findsWidgets`: um ou mais.
      expect(find.text('Radar Tech'), findsWidgets);
      expect(find.text('Confirmada'), findsWidgets);
      // So a inscricao ativa tem menu; a CANCELADA e terminal.
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      // Nunca "Confirmar": isso e do organizador.
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Confirmar'), findsNothing);
      // Nem o filtro por participante, que a API ignora para ele.
      expect(find.byTooltip('Filtrar por participante'), findsNothing);
    });

    testWidgets('participante cancela a inscricao pela lista', (tester) async {
      _tela(tester);
      var cancelada = false;
      String lista() => cancelada
          ? inscricoes.replaceFirst('"CONFIRMADA"', '"CANCELADA"')
          : inscricoes;
      await tester.pumpWidget(
        _appCom((request) {
          if (request.method == 'PATCH') cancelada = true;
          return {
            '/eventos': _okLista(_eventosJson),
            '/inscricoes/10/cancelar': _ok(
              '{"id":10,"participanteId":1,"participanteNome":"Maria Silva",'
              '"eventoId":1,"eventoTitulo":"Radar Tech","status":"CANCELADA",'
              '"dataInscricao":"2026-11-13T10:00:00"}',
            ),
            '/inscricoes': _ok(lista()),
          };
        }, logado: Papel.participante),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Minhas inscrições'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      // Confirmacao: o texto fala da propria inscricao.
      expect(
        find.textContaining('Sua inscrição em "Radar Tech" será cancelada'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Cancelar inscrição'));
      await tester.pumpAndSettle();

      expect(
        _pedidos.where(
          (p) => p.method == 'PATCH' && p.url.path == '/inscricoes/10/cancelar',
        ),
        hasLength(1),
      );
      // Cancelada: sumiu o menu (estado terminal).
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });
  });

  group('participantes', () {
    testWidgets('organizador lista participantes paginados', (tester) async {
      _tela(tester);
      const participantes = '''
      {"content":[
        {"id":1,"nome":"Maria Silva","email":"maria@exemplo.com",
         "cpf":"52998224725","telefone":"46999887766"}],
       "page":{"size":20,"number":0,"totalElements":1,"totalPages":1}}
      ''';

      await tester.pumpWidget(
        _appCom(
          (_) => {
            '/eventos': _okLista(_eventosJson),
            '/participantes': _ok(participantes),
          },
          logado: Papel.organizador,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Participantes'));
      await tester.pumpAndSettle();

      expect(find.text('Maria Silva'), findsOneWidget);
      expect(find.text('maria@exemplo.com'), findsOneWidget);
      // CPF e telefone exibidos ja com mascara.
      expect(find.text('CPF 529.982.247-25 · (46) 99988-7766'), findsOneWidget);
    });

    testWidgets('participante ve o proprio perfil', (tester) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          (_) => {
            '/eventos': _okLista(_eventosJson),
            '/participantes/7': _ok(
              '{"id":7,"nome":"Maria Silva","email":"maria@exemplo.com",'
              '"cpf":"52998224725","telefone":null}',
            ),
          },
          logado: Papel.participante,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Meu perfil'));
      await tester.pumpAndSettle();

      expect(find.text('Maria Silva'), findsOneWidget);
      expect(find.text('529.982.247-25'), findsOneWidget);
      expect(find.text('Não informado'), findsOneWidget);
      expect(find.text('Excluir minha conta'), findsOneWidget);
    });
  });

  testWidgets('em tela estreita a navegacao vai para a barra inferior', (
    tester,
  ) async {
    // 420 px de largura = faixa "celular".
    _tela(tester, largura: 420, altura: 900);
    await tester.pumpWidget(
      _appCom(
        (_) => {'/eventos': _okLista(_eventosJson)},
        logado: Papel.participante,
      ),
    );
    await tester.pumpAndSettle();

    // `find.byType` procura por CLASSE de widget.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byTooltip('Conta'), findsOneWidget);
  });

  // Cobre o que veio da API nova: nome por `GET /me`, troca de senha por
  // `PATCH /me/senha` e o bloqueio 429. Os testes montam o app logado, sem passar
  // pela tela de entrada.
  group('conta e senha', () {
    // Resposta de `GET /participantes/7`: a tela "Meu perfil" a carrega.
    const perfil =
        '{"id":7,"nome":"Maria Silva","email":"maria@exemplo.com",'
        '"cpf":"52998224725","telefone":null}';

    /// Achador de um botao (inclusive os `.icon`, subclasses) pelo rotulo.
    ///
    /// CONCEITO - generics (`<T>`): `botao<FilledButton>('x')` e
    /// `botao<OutlinedButton>('x')` reaproveitam o mesmo codigo para tipos de
    /// botao diferentes. `w is T` testa se o widget e (ou herda de) `T`.
    Finder botao<T extends Widget>(String rotulo) => find.ancestor(
      of: find.text(rotulo),
      matching: find.byWidgetPredicate((w) => w is T),
    );

    /// Abre "Meu perfil" e dali a tela de troca de senha. [senha] e a funcao que
    /// diz o que a API responde ao `PATCH /me/senha` (204, 400, 429...).
    Future<void> abrirTrocaDeSenha(
      WidgetTester tester,
      http.Response Function(http.Request) senha,
    ) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          (request) => {
            '/eventos': _okLista(_eventosJson),
            '/participantes/7': _ok(perfil),
            '/me/senha': senha(request),
          },
          logado: Papel.participante,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Meu perfil'));
      await tester.pumpAndSettle();
      await tester.tap(botao<OutlinedButton>('Alterar senha'));
      await tester.pumpAndSettle();
    }

    /// Preenche os tres campos (atual, nova e confirmacao) e toca em enviar.
    /// Se [confirmacao] nao for informada, repete a [nova] (confirmacao certa).
    Future<void> enviar(
      WidgetTester tester, {
      String atual = 'senhaAtual1',
      String nova = 'novaSenha22',
      String? confirmacao,
    }) async {
      // `at(n)` pega o n-esimo campo de texto da tela, de cima para baixo.
      final campos = find.byType(TextFormField);
      await tester.enterText(campos.at(0), atual);
      await tester.enterText(campos.at(1), nova);
      await tester.enterText(campos.at(2), confirmacao ?? nova);
      await tester.tap(botao<FilledButton>('Alterar senha'));
      await tester.pumpAndSettle();
    }

    testWidgets('mostra o nome vindo de GET /me', (tester) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          (_) => {
            '/eventos': _okLista(_eventosJson),
            '/me': _ok(
              '{"id":7,"nome":"Maria Silva","email":"maria@exemplo.com",'
              '"papel":"PARTICIPANTE","tokenExpiraEm":"2100-01-01T00:00:00Z"}',
            ),
          },
          logado: Papel.participante,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Maria Silva'), findsWidgets);
      final me = _pedidos.firstWhere((p) => p.url.path == '/me');
      expect(me.method, 'GET');
      // Vai com o token da sessao.
      expect(me.headers['Authorization'], startsWith('Bearer '));
    });

    // Garante que o `/me` e so um "bonus": se falhar, o app segue funcionando
    // com o que o token ja tem (o e-mail).
    testWidgets('falha em GET /me nao derruba a sessao', (tester) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          (_) => {
            '/eventos': _okLista(_eventosJson),
            '/me': _erro('{"status":500,"message":"Erro interno"}', 500),
          },
          logado: Papel.participante,
        ),
      );
      await tester.pumpAndSettle();

      // Segue logado, identificado pelo e-mail.
      expect(find.text('maria@exemplo.com'), findsWidgets);
      expect(find.text('Bem-vindo de volta'), findsNothing);
    });

    // 401 = token recusado pela API (vencido ou conta excluida). O ApiClient
    // avisa a Sessao, que apaga o login e a raiz do app troca para o login.
    testWidgets('401 em GET /me volta para a tela de entrada', (tester) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          (_) => {
            '/eventos': _okLista(_eventosJson),
            '/me': http.Response('', 401),
          },
          logado: Papel.participante,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bem-vindo de volta'), findsOneWidget);
    });

    testWidgets('troca a senha e avisa', (tester) async {
      await abrirTrocaDeSenha(tester, (_) => http.Response('', 204));
      await enviar(tester);

      final patch = _pedidos.firstWhere((p) => p.url.path == '/me/senha');
      expect(patch.method, 'PATCH');
      expect(jsonDecode(patch.body), {
        'senhaAtual': 'senhaAtual1',
        'novaSenha': 'novaSenha22',
      });
      expect(find.text('Senha alterada.'), findsOneWidget);
      // Voltou ao perfil e continua logada.
      expect(find.text('Confirmar nova senha *'), findsNothing);
      expect(find.text('Meu perfil'), findsWidgets);
    });

    // Cada `enviar` abaixo tenta uma combinacao invalida; nenhuma pode gerar
    // pedido. O `expect` final confere isso olhando o historico de `_pedidos`.
    testWidgets('valida a nova senha antes de chamar a API', (tester) async {
      await abrirTrocaDeSenha(tester, (_) => http.Response('', 204));

      await enviar(tester, atual: 'mesmaSenha1', nova: 'mesmaSenha1');
      expect(
        find.text('A nova senha deve ser diferente da atual'),
        findsOneWidget,
      );

      await enviar(tester, nova: 'curta');
      expect(
        find.text('A senha deve ter entre 8 e 72 caracteres'),
        findsOneWidget,
      );

      await enviar(tester, nova: 'novaSenha22', confirmacao: 'outraSenha33');
      expect(find.text('As senhas não conferem'), findsOneWidget);

      // Nenhuma dessas tentativas chegou a API.
      expect(_pedidos.where((p) => p.url.path == '/me/senha'), isEmpty);
    });

    testWidgets('mostra a recusa da API para a senha atual errada', (
      tester,
    ) async {
      await abrirTrocaDeSenha(
        tester,
        (_) => _erro(
          '{"status":400,"error":"Bad Request",'
          '"message":"A senha atual está incorreta","path":"/me/senha",'
          '"fieldErrors":[]}',
          400,
        ),
      );
      await enviar(tester);

      expect(find.text('A senha atual está incorreta'), findsOneWidget);
      // Continua na tela, com o botao liberado para tentar de novo.
      expect(find.text('Confirmar nova senha *'), findsOneWidget);
    });

    testWidgets('mostra o bloqueio por tentativas demais (429)', (
      tester,
    ) async {
      await abrirTrocaDeSenha(
        tester,
        (_) => _erro(
          '{"status":429,"error":"Too Many Requests",'
          '"message":"Muitas tentativas de login. Tente novamente em alguns '
          'minutos.","path":"/me/senha","fieldErrors":[]}',
          429,
        ),
      );
      await enviar(tester);

      expect(find.text('Muitas tentativas'), findsOneWidget);
      expect(
        find.text(
          'Muitas tentativas de login. Tente novamente em alguns minutos.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('organizador tambem altera a senha, pela barra lateral', (
      tester,
    ) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          (_) => {'/eventos': _okLista(_eventosJson)},
          logado: Papel.organizador,
        ),
      );
      await tester.pumpAndSettle();

      // Na barra larga o acesso e um botao de texto no cartao do usuario (no
      // tablet e um icone com tooltip; no celular, um item do menu de conta).
      await tester.tap(find.text('Alterar senha'));
      await tester.pumpAndSettle();

      expect(find.text('Confirmar nova senha *'), findsOneWidget);
    });
  });

  group('layout responsivo', () {
    // Eventos de conteudo bem diferente: titulo curto sem descricao, titulo
    // longo com descricao longa, e um de titulo medio. Os cartoes precisam sair
    // com a mesma altura mesmo assim.
    const eventosVariados = '''
    [{"id":1,"titulo":"Feira","descricao":"",
      "dataInicio":"2026-12-04T17:00:00","dataFim":"2026-12-08T17:00:00",
      "vagas":1,"vagasDisponiveis":1,"endereco":{"cep":"85601-000","logradouro":"Rua A","bairro":"Centro",
      "cidade":"Francisco Beltrao","uf":"PR","numero":null},"fotoUrl":null},
     {"id":2,"titulo":"Festival Internacional de Musica e Cultura Popular da Regiao Sudoeste do Parana",
      "descricao":"Tres dias de shows, oficinas, feira gastronomica, exposicoes de arte e apresentacoes para toda a familia, com entrada solidaria e atracoes nacionais.",
      "dataInicio":"2026-12-10T09:00:00","dataFim":"2026-12-12T23:00:00",
      "vagas":2000,"vagasDisponiveis":2000,"endereco":{"cep":"85601-000","logradouro":"Rua B","bairro":"Centro",
      "cidade":"Francisco Beltrao","uf":"PR","numero":"10"},"fotoUrl":null},
     {"id":3,"titulo":"Workshop de Flutter",
      "descricao":"Curso pratico.",
      "dataInicio":"2026-12-15T14:00:00","dataFim":"2026-12-15T18:00:00",
      "vagas":30,"vagasDisponiveis":30,"endereco":{"cep":"85601-000","logradouro":"Rua C","bairro":"Centro",
      "cidade":"Pato Branco","uf":"PR","numero":"5"},"fotoUrl":null},
     {"id":4,"titulo":"Corrida","descricao":"Percurso de 5 km pela orla, com kit e medalha para quem completar a prova.",
      "dataInicio":"2026-12-20T07:00:00","dataFim":"2026-12-20T10:00:00",
      "vagas":500,"vagasDisponiveis":500,"endereco":{"cep":"85601-000","logradouro":"Rua D","bairro":"Centro",
      "cidade":"Francisco Beltrao","uf":"PR","numero":null},"fotoUrl":null}]
    ''';

    testWidgets('todos os cartoes de evento tem exatamente o mesmo tamanho', (
      tester,
    ) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          (_) => {'/eventos': _okLista(eventosVariados)},
          logado: Papel.participante,
        ),
      );
      await tester.pumpAndSettle();

      final cartoes = find.byType(EventoCard);
      expect(cartoes, findsNWidgets(4));
      // Mede o tamanho (largura x altura) de cada um dos 4 cartoes.
      final tamanhos = [
        for (var i = 0; i < 4; i++) tester.getSize(cartoes.at(i)),
      ];
      expect(tamanhos[1], tamanhos[0]);
      expect(tamanhos[2], tamanhos[0]);
      expect(tamanhos[3], tamanhos[0]);
    });

    testWidgets('mantem o mesmo tamanho com a fonte do sistema ampliada', (
      tester,
    ) async {
      _tela(tester, largura: 375, altura: 812);
      // Simula o usuario ter aumentado a fonte do sistema em 40%.
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        _appCom(
          (_) => {'/eventos': _okLista(eventosVariados)},
          logado: Papel.participante,
        ),
      );
      await tester.pumpAndSettle();

      final cartoes = find.byType(EventoCard);
      final primeiro = tester.getSize(cartoes.at(0));
      expect(tester.getSize(cartoes.at(1)), primeiro);
      expect(tester.getSize(cartoes.at(2)), primeiro);
      expect(tester.getSize(cartoes.at(3)), primeiro);
    });

    /// Colunas da grade: quantos cartoes ficam na mesma linha.
    /// Conta quantos cartoes tem a mesma posicao vertical (`dy`) do primeiro.
    int colunas(WidgetTester tester) {
      final cartoes = find.byType(EventoCard);
      final topo = tester.getTopLeft(cartoes.at(0)).dy;
      var n = 0;
      for (var i = 0; i < tester.widgetList(cartoes).length; i++) {
        if ((tester.getTopLeft(cartoes.at(i)).dy - topo).abs() < 1) n++;
      }
      return n;
    }

    // celular, tablet, notebook e desktop.
    // Lista de "records": (nome, largura, altura).
    const faixas = <(String, double, double)>[
      ('celular', 375, 812),
      ('tablet', 768, 1024),
      ('notebook', 1100, 768),
      ('desktop', 1920, 1080),
    ];

    /// Abre a troca de senha pelo acesso que existe na largura atual: menu de
    /// conta no celular; botao/icone da barra lateral nas demais.
    /// `evaluate().isNotEmpty` pergunta "existe algum widget assim na tela agora?".
    Future<void> abrirSenhaPorAcesso(WidgetTester tester) async {
      if (find.byTooltip('Conta').evaluate().isNotEmpty) {
        await tester.tap(find.byTooltip('Conta'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Alterar senha'));
      } else if (find.byTooltip('Alterar senha').evaluate().isNotEmpty) {
        await tester.tap(find.byTooltip('Alterar senha'));
      } else {
        await tester.tap(find.text('Alterar senha'));
      }
      await tester.pumpAndSettle();
    }

    // Vagas e botao bloqueado precisam caber do celular ao desktop.
    for (final (nome, largura, altura) in faixas) {
      testWidgets('$nome (${largura.toInt()} px): evento lotado sem overflow', (
        tester,
      ) async {
        _tela(tester, largura: largura, altura: altura);
        await tester.pumpWidget(
          _appCom(
            (_) => {
              '/eventos': _okLista('[${_radarTechCom(2000, vagas: 2000)}]'),
              '/eventos/1': _ok(_radarTechCom(2000, vagas: 2000)),
              '/inscricoes': _ok(_paginaVazia),
            },
            logado: Papel.participante,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Lotado (2000/2000)'), findsOneWidget);

        await tester.ensureVisible(find.text('Radar Tech'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Radar Tech'));
        await tester.pumpAndSettle();

        expect(find.text('2000/2000 vagas preenchidas'), findsOneWidget);
        expect(find.text('Vagas esgotadas'), findsOneWidget);
      });
    }

    // Detalhe com "Cancelar inscricao" e a tela de senha, do celular ao desktop.
    for (final (nome, largura, altura) in faixas) {
      testWidgets('$nome (${largura.toInt()} px): inscrito e troca de senha '
          'sem overflow', (tester) async {
        _tela(tester, largura: largura, altura: altura);
        const minha =
            '{"content":[{"id":10,"participanteId":7,'
            '"participanteNome":"Maria","eventoId":1,'
            '"eventoTitulo":"Radar Tech","status":"PENDENTE",'
            '"dataInscricao":"2026-11-15T10:00:00"}],'
            '"page":{"size":50,"number":0,"totalElements":1,"totalPages":1}}';
        await tester.pumpWidget(
          _appCom(
            (_) => {
              '/eventos': _okLista('[${_radarTechCom(1)}]'),
              '/eventos/1': _ok(_radarTechCom(1)),
              '/inscricoes': _ok(minha),
            },
            logado: Papel.participante,
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Radar Tech'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Radar Tech'));
        await tester.pumpAndSettle();
        expect(find.text('Cancelar inscrição'), findsOneWidget);

        // Volta e abre a troca de senha pelo acesso da propria largura.
        await tester.tap(find.byTooltip('Voltar'));
        await tester.pumpAndSettle();
        await abrirSenhaPorAcesso(tester);
        expect(find.text('Confirmar nova senha *'), findsOneWidget);
      });
    }

    // Gera testes automaticamente: 4 faixas x 2 papeis (+ 4 de login).
    // Se QUALQUER tela estourar (overflow) em alguma largura, o teste falha.
    for (final (nome, largura, altura) in faixas) {
      for (final papel in Papel.values) {
        testWidgets('$nome (${largura.toInt()} px), ${papel.rotulo}: telas '
            'sem overflow e com a navegacao certa', (tester) async {
          _tela(tester, largura: largura, altura: altura);
          const inscricoes = '''
          {"content":[
            {"id":10,"participanteId":7,"participanteNome":"Maria Aparecida da Silva Santos",
             "eventoId":2,"eventoTitulo":"Festival Internacional de Musica e Cultura Popular",
             "status":"PENDENTE","dataInscricao":"2026-11-13T10:00:00"},
            {"id":11,"participanteId":8,"participanteNome":"Joao Souza",
             "eventoId":1,"eventoTitulo":"Feira","status":"CONFIRMADA",
             "dataInscricao":"2026-11-14T09:30:00"}],
           "page":{"size":20,"number":0,"totalElements":2,"totalPages":1}}
          ''';
          const participantes = '''
          {"content":[
            {"id":1,"nome":"Maria Aparecida da Silva Santos","email":"maria.aparecida.santos@exemplo.com.br",
             "cpf":"52998224725","telefone":"46999887766"}],
           "page":{"size":20,"number":0,"totalElements":1,"totalPages":1}}
          ''';
          await tester.pumpWidget(
            _appCom(
              (_) => {
                '/eventos': _okLista(eventosVariados),
                '/eventos/2': _ok(
                  jsonEncode((jsonDecode(eventosVariados) as List)[1]),
                ),
                '/inscricoes': _ok(inscricoes),
                // A ordem importa: `/participantes/7` vem antes de
                // `/participantes` (o primeiro que casar vence).
                '/participantes/7': _ok(
                  '{"id":7,"nome":"Maria Silva","email":"maria@exemplo.com",'
                  '"cpf":"52998224725","telefone":"46999887766"}',
                ),
                '/participantes': _ok(participantes),
              },
              logado: papel,
            ),
          );
          await tester.pumpAndSettle();

          // Navegacao: barra inferior so no celular; barra lateral completa
          // (com o rotulo de secao) so de notebook para cima.
          expect(
            find.byType(NavigationBar),
            nome == 'celular' ? findsOneWidget : findsNothing,
          );
          final secao = papel == Papel.organizador ? 'GESTÃO' : 'MENU';
          expect(
            find.text(secao),
            nome == 'notebook' || nome == 'desktop'
                ? findsOneWidget
                : findsNothing,
          );

          // Colunas da grade conforme a largura que sobra ao conteudo.
          final esperadas = switch (nome) {
            'celular' => 1,
            'tablet' => 2,
            'notebook' => 2,
            _ => 4,
          };
          expect(colunas(tester), esperadas);

          // Detalhe do evento (titulo longo e descricao longa).
          // `ensureVisible` rola ate o widget aparecer antes de tocar.
          await tester.ensureVisible(find.byType(EventoCard).at(1));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(EventoCard).at(1));
          await tester.pumpAndSettle();
          expect(find.text('Sobre o evento'), findsOneWidget);
          await tester.tap(find.byTooltip('Voltar'));
          await tester.pumpAndSettle();

          // As demais abas, pelo rotulo de cada faixa.
          // Funcao local: tenta cada rotulo ate achar um existente na tela.
          Future<void> irPara(List<String> rotulos) async {
            for (final r in rotulos) {
              final alvo = find.text(r);
              // `evaluate()` consulta agora se existe algum widget.
              if (alvo.evaluate().isNotEmpty) {
                await tester.tap(alvo.first);
                await tester.pumpAndSettle();
                return;
              }
            }
            // `fail` reprova o teste com uma mensagem.
            fail('Nenhuma aba encontrada entre $rotulos');
          }

          await irPara(['Minhas inscrições', 'Inscrições']);
          expect(
            find.text('Joao Souza'),
            papel == Papel.organizador ? findsOneWidget : findsNothing,
          );
          if (papel == Papel.organizador) {
            await irPara(['Participantes', 'Pessoas']);
            expect(find.textContaining('maria.aparecida'), findsOneWidget);
          } else {
            await irPara(['Meu perfil', 'Perfil']);
            expect(find.text('Excluir minha conta'), findsOneWidget);
          }
        });
      }

      testWidgets('$nome (${largura.toInt()} px): tela de entrada e cadastro '
          'sem overflow', (tester) async {
        _tela(tester, largura: largura, altura: altura);
        await tester.pumpWidget(_appCom((_) => {}));
        await tester.pumpAndSettle();
        expect(find.text('Bem-vindo de volta'), findsOneWidget);

        await tester.tap(find.text('Criar conta'));
        await tester.pumpAndSettle();
        expect(find.text('Criar conta e entrar'), findsOneWidget);
      });
    }
  });
}
