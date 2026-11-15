import 'dart:convert';

import 'package:acontece_frontend/core/api_client.dart';
import 'package:acontece_frontend/main.dart';
import 'package:acontece_frontend/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// Testes de interface com um cliente HTTP falso que devolve exatamente os
/// corpos que a API em producao devolve. Assim a UI e exercitada de verdade
/// (incluindo a leitura das datas naive com fracao de segundo e a sondagem do
/// modulo de inscricoes) sem depender da rede.

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

/// Resposta real de `GET /inscricoes` no deploy atual, que nao tem o modulo.
const _inscricoesAusente = '''
{"timestamp":"2026-11-15T00:49:16.412392651Z","status":404,"error":"Not Found",
 "message":"No static resource inscricoes.","path":"/inscricoes",
 "fieldErrors":[]}
''';

/// Monta o app com um cliente que responde conforme [rotas].
///
/// A chave e casada contra o caminho da requisicao, o que torna visivel qual
/// rota cada tela realmente chama.
Widget _appCom(Map<String, http.Response> Function(http.Request) responder) {
  final mock = MockClient((request) async {
    final respostas = responder(request);
    for (final entry in respostas.entries) {
      if (request.url.path.endsWith(entry.key)) return entry.value;
    }
    return http.Response('{"status":404,"message":"rota nao mapeada no teste",'
        '"path":"${request.url.path}","fieldErrors":[]}', 404);
  });

  return Services(client: ApiClient(client: mock), child: const AconteceApp());
}

http.Response _ok(String corpo) => http.Response.bytes(
  utf8.encode(corpo),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response _erro(String corpo, int status) => http.Response.bytes(
  utf8.encode(corpo),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  setUpAll(() {
    initializeDateFormatting('pt_BR');
    Intl.defaultLocale = 'pt_BR';
  });

  testWidgets('lista os eventos vindos da API', (tester) async {
    await tester.pumpWidget(
      _appCom((_) => {'/evento/listar/': _ok(_eventosJson)}),
    );
    await tester.pumpAndSettle();

    expect(find.text('Radar Tech'), findsOneWidget);
    expect(find.text('Evento de RAP'), findsOneWidget);

    // Contador da lista.
    expect(find.text('2 eventos'), findsOneWidget);

    // Cidade formatada a partir do endereco que o ViaCEP preencheu.
    expect(find.text('Francisco Beltrao - PR'), findsNWidgets(2));

    // Vagas no plural e no singular.
    expect(find.text('200 vagas'), findsOneWidget);
    expect(find.text('1 vaga'), findsOneWidget);
  });

  testWidgets('marca como encerrado o evento cuja dataFim ja passou', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appCom((_) => {'/evento/listar/': _ok(_eventosJson)}),
    );
    await tester.pumpAndSettle();

    // "Evento de RAP" terminou em 13/11/2026; "Radar Tech" termina em
    // 08/12/2026. Hoje, para o back-end, e o relogio de Sao Paulo.
    expect(find.text('Encerrado'), findsOneWidget);
  });

  testWidgets('mostra o estado vazio quando a API nao tem eventos', (
    tester,
  ) async {
    await tester.pumpWidget(_appCom((_) => {'/evento/listar/': _ok('[]')}));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum evento cadastrado'), findsOneWidget);
    expect(find.text('Novo evento'), findsWidgets);
  });

  testWidgets('mostra o erro da API, com a mensagem dela, e permite tentar de novo', (
    tester,
  ) async {
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
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Erro no servidor'), findsOneWidget);
    expect(find.text('Erro interno do servidor'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('explica o que fazer quando o pedido cai no servidor de arquivos', (
    tester,
  ) async {
    // Reproduz abrir o site na porta do `flutter run` em vez da do proxy: a
    // rota /api e atendida pelo servidor de SPA, que devolve index.html com
    // status 200.
    await tester.pumpWidget(
      _appCom(
        (_) => {
          '/evento/listar/': _ok(
            '<!DOCTYPE html>\n<html>\n<head><title>Acontece</title></head>\n'
            '<body><script src="flutter_bootstrap.js"></script></body>\n</html>',
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A requisicao nao chegou a API'), findsOneWidget);
    expect(find.textContaining('http://localhost:8081'), findsOneWidget);
    expect(find.textContaining('dev_proxy.mjs'), findsOneWidget);

    // E nao a mensagem antiga, que nao dizia o que fazer.
    expect(find.text('Resposta inesperada'), findsNothing);
  });

  testWidgets('abre o detalhe do evento com endereco e acoes', (tester) async {
    await tester.pumpWidget(
      _appCom(
        (_) => {
          '/evento/listar/': _ok(_eventosJson),
          '/evento/buscar/1': _ok(jsonEncode(jsonDecode(_eventosJson)[0])),
          // O detalhe tenta contar as vagas ocupadas; aqui o modulo nao existe,
          // e a tela precisa seguir funcionando sem essa informacao.
          '/inscricoes': _erro(_inscricoesAusente, 404),
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Radar Tech'));
    await tester.pumpAndSettle();

    expect(find.text('Detalhe do evento'), findsOneWidget);
    expect(find.text('Avenida Julio Assis Cavalheiro, 02'), findsOneWidget);
    expect(find.text('Centro'), findsOneWidget);
    expect(find.text('85601-000'), findsOneWidget);
    expect(find.text('Inscrever participante'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Excluir'), findsOneWidget);
  });

  testWidgets('avisa que o modulo de inscricoes nao esta publicado', (
    tester,
  ) async {
    await tester.pumpWidget(
      _appCom(
        (_) => {
          '/evento/listar/': _ok(_eventosJson),
          '/inscricoes': _erro(_inscricoesAusente, 404),
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inscricoes'));
    await tester.pumpAndSettle();

    // Em vez de "nao encontrado", que sugeriria falta de dados, a aba explica
    // que a rota nao existe nesta build da API.
    expect(find.text('Modulo de inscricoes nao publicado'), findsOneWidget);
    expect(find.textContaining('Republique o acontece-api'), findsOneWidget);
  });

  testWidgets('lista as inscricoes quando o modulo existe', (tester) async {
    const inscricoes = '''
    {"content":[
      {"id":10,"participanteId":1,"participanteNome":"Maria Silva",
       "eventoId":1,"eventoTitulo":"Radar Tech","status":"PENDENTE",
       "dataInscricao":"2026-11-13T10:00:00"},
      {"id":11,"participanteId":2,"participanteNome":"Joao Souza",
       "eventoId":1,"eventoTitulo":"Radar Tech","status":"CANCELADA",
       "dataInscricao":"2026-11-14T09:30:00"}],
     "page":{"size":20,"number":0,"totalElements":2,"totalPages":1}}
    ''';

    await tester.pumpWidget(
      _appCom(
        (_) => {
          '/evento/listar/': _ok(_eventosJson),
          '/inscricoes': _ok(inscricoes),
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inscricoes'));
    await tester.pumpAndSettle();

    expect(find.text('Maria Silva'), findsOneWidget);
    expect(find.text('Joao Souza'), findsOneWidget);
    expect(find.text('Pendente'), findsWidgets);
    expect(find.text('Cancelada'), findsWidgets);
    expect(find.text('1-2 de 2'), findsOneWidget);
  });

  testWidgets('oferece so as transicoes de status que a API aceita', (
    tester,
  ) async {
    const inscricoes = '''
    {"content":[
      {"id":10,"participanteId":1,"participanteNome":"Maria Silva",
       "eventoId":1,"eventoTitulo":"Radar Tech","status":"CONFIRMADA",
       "dataInscricao":"2026-11-13T10:00:00"}],
     "page":{"size":20,"number":0,"totalElements":1,"totalPages":1}}
    ''';

    await tester.pumpWidget(
      _appCom(
        (_) => {
          '/evento/listar/': _ok(_eventosJson),
          '/inscricoes': _ok(inscricoes),
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inscricoes'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    // CONFIRMADA so pode ir para CANCELADA. Oferecer "Confirmar" de novo
    // resultaria em 409 ("Transicao de status invalida").
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Confirmar'), findsNothing);
  });

  testWidgets('lista participantes paginados', (tester) async {
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
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Participantes'));
    await tester.pumpAndSettle();

    expect(find.text('Maria Silva'), findsOneWidget);
    expect(find.text('maria@exemplo.com'), findsOneWidget);

    // CPF e telefone chegam crus da API e sao mascarados so na exibicao.
    expect(
      find.text('CPF 529.982.247-25 · (46) 99988-7766'),
      findsOneWidget,
    );
  });

  testWidgets('valida o formulario de participante antes de chamar a API', (
    tester,
  ) async {
    var chamouCriar = false;

    await tester.pumpWidget(
      _appCom((request) {
        if (request.method == 'POST') chamouCriar = true;
        return {
          '/evento/listar/': _ok(_eventosJson),
          '/participantes': _ok(
            '{"content":[],"page":{"size":20,"number":0,'
            '"totalElements":0,"totalPages":0}}',
          ),
        };
      }),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Participantes'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Novo participante').first);
    await tester.pumpAndSettle();

    // CPF com digito verificador errado: o cliente barra antes de ir a rede.
    await tester.enterText(find.byType(TextFormField).at(0), 'Maria');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'maria@exemplo.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), '52998224726');
    await tester.tap(find.text('Cadastrar'));
    await tester.pumpAndSettle();

    expect(find.text('CPF invalido'), findsOneWidget);
    expect(chamouCriar, isFalse);
  });
}
