import 'dart:convert';

import 'package:acontece_frontend/core/api_client.dart';
import 'package:acontece_frontend/core/token_storage.dart';
import 'package:acontece_frontend/main.dart';
import 'package:acontece_frontend/models/auth.dart';
import 'package:acontece_frontend/services.dart';
import 'package:acontece_frontend/widgets/evento_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// Testes de interface com um cliente HTTP falso que devolve exatamente os
/// corpos que a API em producao devolve. Assim a UI e exercitada de verdade
/// (login, papeis, datas naive com fracao de segundo) sem depender da rede.

/// Resposta real de `GET /evento/listar/`.
const _eventosJson = '''
[{"id":1,"titulo":"Radar Tech","descricao":"Evento da Semana Academica",
  "dataInicio":"2026-12-04T17:06:44.19","dataFim":"2026-12-08T17:06:44.19",
  "vagas":200,
  "endereco":{"cep":"85601-000","logradouro":"Avenida Julio Assis Cavalheiro",
    "bairro":"Centro","cidade":"Francisco Beltrao","uf":"PR","numero":"02"},
  "fotoUrl":null},
 {"id":2,"titulo":"Evento de RAP","descricao":"EVENTO RAP",
  "dataInicio":"2026-11-12T17:29:36.487","dataFim":"2026-11-13T17:29:36.487",
  "vagas":1,
  "endereco":{"cep":"85601-336","logradouro":"Rua Silvia Abdala",
    "bairro":"Agua Branca","cidade":"Francisco Beltrao","uf":"PR",
    "numero":"123"},
  "fotoUrl":null}]
''';

String get _radarTech => jsonEncode((jsonDecode(_eventosJson) as List)[0]);

/// Resposta de `POST /inscricoes`: a inscricao criada, sempre PENDENTE.
const _minhaInscricao =
    '{"id":10,"participanteId":7,"participanteNome":"Maria",'
    '"eventoId":1,"eventoTitulo":"Radar Tech","status":"PENDENTE",'
    '"dataInscricao":"2026-11-15T10:00:00"}';

const _paginaVazia =
    '{"content":[],"page":{"size":20,"number":0,"totalElements":0,'
    '"totalPages":0}}';

/// JWT no formato do `TokenService` (a assinatura nao importa no cliente).
String _jwt(int id, String email, Papel papel) {
  String parte(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${parte({'alg': 'HS256'})}.${parte({'sub': '$id', 'email': email, 'papel': papel.wire, 'exp': 4102444800})}.sig';
}

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
Widget _appCom(
  Map<String, http.Response> Function(http.Request) responder, {
  Papel? logado,
}) {
  _pedidos.clear();
  final mock = MockClient((request) async {
    _pedidos.add(request);
    final respostas = responder(request);
    for (final entry in respostas.entries) {
      if (request.url.path.endsWith(entry.key)) return entry.value;
    }
    return http.Response(
      '{"status":404,"message":"rota nao mapeada no teste",'
      '"path":"${request.url.path}","fieldErrors":[]}',
      404,
    );
  });

  final storage = MemoryTokenStorage(
    logado == null ? null : jsonEncode(_usuario(logado).toJson()),
  );
  return Services(
    client: ApiClient(client: mock),
    storage: storage,
    child: const AconteceApp(),
  );
}

http.Response _ok(String corpo, [int status = 200]) => http.Response.bytes(
  utf8.encode(corpo),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response _erro(String corpo, int status) => _ok(corpo, status);

/// Tela larga (barra lateral) por padrao; [largura] < 900 testa o celular.
void _tela(WidgetTester tester, {double largura = 1400, double altura = 1400}) {
  tester.view.physicalSize = Size(largura, altura);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() {
    initializeDateFormatting('pt_BR');
    Intl.defaultLocale = 'pt_BR';
  });

  group('login', () {
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
            '/evento/listar/': _ok(_eventosJson),
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

      final login = _pedidos.firstWhere((p) => p.url.path == '/auth/login');
      expect(jsonDecode(login.body), {
        'email': 'maria@exemplo.com',
        'senha': 'segredo123',
      });
      expect(login.headers.containsKey('Authorization'), isFalse);

      final eventos = _pedidos.firstWhere(
        (p) => p.url.path == '/evento/listar/',
      );
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
          (_) => {'/evento/listar/': http.Response('', 401)},
          logado: Papel.participante,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bem-vindo de volta'), findsOneWidget);
      expect(find.textContaining('Sua sessão expirou'), findsOneWidget);
    });

    testWidgets('sair volta para a tela de entrada', (tester) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          (_) => {'/evento/listar/': _ok(_eventosJson)},
          logado: Papel.organizador,
        ),
      );
      await tester.pumpAndSettle();

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

      final campos = find.byType(TextFormField);
      await tester.enterText(campos.at(0), 'Maria');
      await tester.enterText(campos.at(1), 'maria@exemplo.com');
      await tester.enterText(campos.at(2), '52998224726'); // digito errado
      await tester.enterText(campos.at(4), 'segredo123');
      await tester.enterText(campos.at(5), 'segredo123');
      await tester.tap(find.text('Criar conta e entrar'));
      await tester.pumpAndSettle();

      expect(find.text('CPF inválido'), findsOneWidget);
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
            '/evento/listar/': _ok(_eventosJson),
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
      expect(find.text('Descubra eventos'), findsOneWidget);
    });
  });

  group('eventos', () {
    testWidgets('lista os eventos vindos da API', (tester) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          (_) => {'/evento/listar/': _ok(_eventosJson)},
          logado: Papel.participante,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Radar Tech'), findsOneWidget);
      expect(find.text('Evento de RAP'), findsOneWidget);
      expect(find.text('2 eventos'), findsOneWidget);
      expect(find.text('Francisco Beltrao - PR'), findsNWidgets(2));
      expect(find.text('200 vagas'), findsOneWidget);
      expect(find.text('1 vaga'), findsOneWidget);

      // "Evento de RAP" terminou em 13/11/2026; hoje, para o back-end, e o
      // relogio de Sao Paulo.
      expect(find.text('Encerrado'), findsOneWidget);
    });

    testWidgets('participante nao ve as acoes de organizador', (tester) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          (_) => {'/evento/listar/': _ok(_eventosJson)},
          logado: Papel.participante,
        ),
      );
      await tester.pumpAndSettle();

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
          (_) => {'/evento/listar/': _ok(_eventosJson)},
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
          (_) => {'/evento/listar/': _ok('[]')},
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
            '/evento/listar/': _erro(
              '{"status":500,"error":"Internal Server Error",'
              '"message":"Erro interno do servidor","path":"/evento/listar/",'
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
            '/evento/listar/': _ok(_eventosJson),
            '/evento/buscar/1': _ok(_radarTech),
            '/inscricoes': request.method == 'POST'
                ? _ok(_minhaInscricao, 201)
                : inscrito
                ? _ok(minha)
                : _ok(_paginaVazia),
          };
        }, logado: Papel.participante),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Radar Tech'));
      await tester.pumpAndSettle();

      expect(find.text('Avenida Julio Assis Cavalheiro, 02'), findsOneWidget);
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
      await tester.pumpWidget(
        _appCom(
          (request) => {
            '/evento/listar/': _ok(_eventosJson),
            '/evento/buscar/1': _ok(_radarTech),
            '/inscricoes': request.method == 'POST'
                ? _erro(
                    '{"status":409,"error":"Conflict",'
                    '"message":"Evento sem vagas disponíveis",'
                    '"path":"/inscricoes","fieldErrors":[]}',
                    409,
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

      expect(find.text('Evento sem vagas disponíveis'), findsOneWidget);
    });

    testWidgets('organizador ve ocupacao e acoes no detalhe', (tester) async {
      _tela(tester);
      const contagem =
          '{"content":[],"page":{"size":1,"number":0,"totalElements":3,'
          '"totalPages":3}}';
      await tester.pumpWidget(
        _appCom(
          (_) => {
            '/evento/listar/': _ok(_eventosJson),
            '/evento/buscar/1': _ok(_radarTech),
            '/inscricoes': _ok(contagem),
          },
          logado: Papel.organizador,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Radar Tech'));
      await tester.pumpAndSettle();

      // 3 pendentes + 3 confirmadas: a contagem soma os status que ocupam vaga.
      expect(find.text('6'), findsOneWidget);
      expect(find.text('de 200 vagas'), findsOneWidget);
      expect(find.text('Ver inscrições'), findsOneWidget);
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Excluir'), findsOneWidget);
      expect(find.text('Quero me inscrever'), findsNothing);
    });
  });

  group('inscricoes', () {
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
            '/evento/listar/': _ok(_eventosJson),
            '/inscricoes': _ok(inscricoes),
          },
          logado: Papel.organizador,
        ),
      );
      await tester.pumpAndSettle();

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

    testWidgets('participante ve as proprias inscricoes, sem mudar status', (
      tester,
    ) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          (_) => {
            '/evento/listar/': _ok(_eventosJson),
            '/inscricoes': _ok(inscricoes),
          },
          logado: Papel.participante,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Minhas inscrições'));
      await tester.pumpAndSettle();

      expect(find.text('Radar Tech'), findsWidgets);
      expect(find.text('Confirmada'), findsWidgets);
      expect(find.byIcon(Icons.more_vert), findsNothing);
      // Nem o filtro por participante, que a API ignora para ele.
      expect(find.byTooltip('Filtrar por participante'), findsNothing);
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
            '/evento/listar/': _ok(_eventosJson),
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
      expect(find.text('CPF 529.982.247-25 · (46) 99988-7766'), findsOneWidget);
    });

    testWidgets('participante ve o proprio perfil', (tester) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          (_) => {
            '/evento/listar/': _ok(_eventosJson),
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
    _tela(tester, largura: 420, altura: 900);
    await tester.pumpWidget(
      _appCom(
        (_) => {'/evento/listar/': _ok(_eventosJson)},
        logado: Papel.participante,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byTooltip('Conta'), findsOneWidget);
  });

  group('layout responsivo', () {
    // Eventos de conteudo bem diferente: titulo curto sem descricao, titulo
    // longo com descricao longa, e um de titulo medio. Os cartoes precisam sair
    // com a mesma altura mesmo assim.
    const eventosVariados = '''
    [{"id":1,"titulo":"Feira","descricao":"",
      "dataInicio":"2026-12-04T17:00:00","dataFim":"2026-12-08T17:00:00",
      "vagas":1,"endereco":{"cep":"85601-000","logradouro":"Rua A","bairro":"Centro",
      "cidade":"Francisco Beltrao","uf":"PR","numero":null},"fotoUrl":null},
     {"id":2,"titulo":"Festival Internacional de Musica e Cultura Popular da Regiao Sudoeste do Parana",
      "descricao":"Tres dias de shows, oficinas, feira gastronomica, exposicoes de arte e apresentacoes para toda a familia, com entrada solidaria e atracoes nacionais.",
      "dataInicio":"2026-12-10T09:00:00","dataFim":"2026-12-12T23:00:00",
      "vagas":2000,"endereco":{"cep":"85601-000","logradouro":"Rua B","bairro":"Centro",
      "cidade":"Francisco Beltrao","uf":"PR","numero":"10"},"fotoUrl":null},
     {"id":3,"titulo":"Workshop de Flutter",
      "descricao":"Curso pratico.",
      "dataInicio":"2026-12-15T14:00:00","dataFim":"2026-12-15T18:00:00",
      "vagas":30,"endereco":{"cep":"85601-000","logradouro":"Rua C","bairro":"Centro",
      "cidade":"Pato Branco","uf":"PR","numero":"5"},"fotoUrl":null},
     {"id":4,"titulo":"Corrida","descricao":"Percurso de 5 km pela orla, com kit e medalha para quem completar a prova.",
      "dataInicio":"2026-12-20T07:00:00","dataFim":"2026-12-20T10:00:00",
      "vagas":500,"endereco":{"cep":"85601-000","logradouro":"Rua D","bairro":"Centro",
      "cidade":"Francisco Beltrao","uf":"PR","numero":null},"fotoUrl":null}]
    ''';

    testWidgets('todos os cartoes de evento tem exatamente o mesmo tamanho', (
      tester,
    ) async {
      _tela(tester);
      await tester.pumpWidget(
        _appCom(
          (_) => {'/evento/listar/': _ok(eventosVariados)},
          logado: Papel.participante,
        ),
      );
      await tester.pumpAndSettle();

      final cartoes = find.byType(EventoCard);
      expect(cartoes, findsNWidgets(4));
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
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        _appCom(
          (_) => {'/evento/listar/': _ok(eventosVariados)},
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
    const faixas = <(String, double, double)>[
      ('celular', 375, 812),
      ('tablet', 768, 1024),
      ('notebook', 1100, 768),
      ('desktop', 1920, 1080),
    ];

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
                '/evento/listar/': _ok(eventosVariados),
                '/evento/buscar/2': _ok(
                  jsonEncode((jsonDecode(eventosVariados) as List)[1]),
                ),
                '/inscricoes': _ok(inscricoes),
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
          await tester.ensureVisible(find.byType(EventoCard).at(1));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(EventoCard).at(1));
          await tester.pumpAndSettle();
          expect(find.text('Sobre o evento'), findsOneWidget);
          await tester.tap(find.byTooltip('Voltar'));
          await tester.pumpAndSettle();

          // As demais abas, pelo rotulo de cada faixa.
          Future<void> irPara(List<String> rotulos) async {
            for (final r in rotulos) {
              final alvo = find.text(r);
              if (alvo.evaluate().isNotEmpty) {
                await tester.tap(alvo.first);
                await tester.pumpAndSettle();
                return;
              }
            }
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
