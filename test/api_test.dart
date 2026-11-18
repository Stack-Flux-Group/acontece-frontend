// =============================================================================
// api_test.dart - TESTES UNITARIOS DA CAMADA DE DADOS (sem telas)
// =============================================================================
//
// Cobre, sem desenhar nenhum widget:
//   * ApiDates          -> leitura/escrita de datas sem fuso
//   * ApiException      -> traducao do envelope de erro da API
//   * ApiClient.resolve -> montagem de URL e query string
//   * modelos           -> fromJson / toJson (Evento, Participante, Inscricao...)
//   * ParticipantePatch -> "so envia o que mudou"
//   * StatusInscricao   -> maquina de estados
//   * PagedModel        -> paginacao
//   * auth              -> JWT, UsuarioLogado, LoginInput
//
// Os JSONs de exemplo foram copiados de respostas REAIS da API.
//
// Matchers novos usados aqui (alem de isTrue/isNull):
//   hasLength(n), isEmpty, isNotEmpty, contains(x), endsWith(x),
//   throwsA(isA<Tipo>()) -> espera que a funcao LANCE uma excecao do tipo.
// =============================================================================

// jsonEncode/jsonDecode/base64Url/utf8: montar um JWT de teste.
import 'dart:convert';

import 'package:acontece_frontend/acesso_a_api/evento_repository.dart';
import 'package:acontece_frontend/acesso_a_api/inscricao_repository.dart';
import 'package:acontece_frontend/infraestrutura/api_client.dart';
import 'package:acontece_frontend/infraestrutura/api_dates.dart';
import 'package:acontece_frontend/infraestrutura/api_exception.dart';
import 'package:acontece_frontend/infraestrutura/validators.dart';
import 'package:acontece_frontend/modelos_da_api/auth.dart';
import 'package:acontece_frontend/modelos_da_api/evento.dart';
import 'package:acontece_frontend/modelos_da_api/inscricao.dart';
import 'package:acontece_frontend/modelos_da_api/paged_model.dart';
import 'package:acontece_frontend/modelos_da_api/participante.dart';
import 'package:acontece_frontend/modelos_da_api/status_inscricao.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ApiDates', () {
    test('le a fracao de segundo que a API realmente devolve', () {
      // Resposta real de GET /eventos.
      final data = ApiDates.parse('2026-12-04T17:06:44.19');
      expect(data.year, 2026);
      expect(data.month, 12);
      expect(data.day, 4);
      expect(data.hour, 17);
      expect(data.minute, 6);
      expect(data.second, 44);
    });

    test('le tambem sem fracao de segundo', () {
      final data = ApiDates.parse('2026-12-01T19:00:00');
      expect(data.hour, 19);
      expect(data.minute, 0);
    });

    test('nao desloca fuso: o valor lido e hora de parede', () {
      // Sem sufixo Z/offset, o horario precisa sair igual ao que entrou,
      // independente do fuso da maquina que roda o teste.
      // Ida e volta: parse -> format deve devolver o mesmo texto.
      const texto = '2026-12-04T17:06:44';
      expect(ApiDates.format(ApiDates.parse(texto)), texto);
    });

    test(
      'serializa sem fuso e sem milissegundos, como o LocalDateTime espera',
      () {
        // Ultimo argumento (123) = milissegundos, que devem ser descartados.
        final valor = DateTime(2026, 12, 1, 19, 30, 5, 123);
        expect(ApiDates.format(valor), '2026-12-01T19:30:05');
      },
    );

    test('tryParse devolve null para ausente ou invalido', () {
      expect(ApiDates.tryParse(null), isNull);
      expect(ApiDates.tryParse(''), isNull);
      // Nao-texto (numero) tambem vira null.
      expect(ApiDates.tryParse(42), isNull);
      expect(ApiDates.tryParse('nao e data'), isNull);
    });
  });

  group('ApiException', () {
    test('le o envelope de validacao com fieldErrors', () {
      // Corpo real de POST /participantes com dados invalidos.
      // (Textos literais vizinhos sao concatenados pelo Dart.)
      const corpo =
          '{"timestamp":"2026-11-15T00:18:44.540205442Z","status":400,'
          '"error":"Bad Request","message":"Dados inválidos na requisição",'
          '"path":"/participantes","fieldErrors":['
          '{"field":"nome","message":"O nome é obrigatorio"},'
          '{"field":"cpf","message":"CPF inválido"},'
          '{"field":"email","message":"E-mail inválido"}]}';

      final erro = ApiException.fromResponse(400, corpo, '/participantes');
      expect(erro.status, 400);
      expect(erro.message, 'Dados inválidos na requisição');
      expect(erro.path, '/participantes');
      // `hasLength(3)`: a colecao tem exatamente 3 itens.
      expect(erro.fieldErrors, hasLength(3));
      expect(erro.forField('cpf'), 'CPF inválido');
      expect(erro.forField('telefone'), isNull);
      expect(erro.isBadRequest, isTrue);
      expect(erro.hasFieldErrors, isTrue);
    });

    test('le um 404 de recurso inexistente', () {
      const corpo =
          '{"timestamp":"2026-11-15T00:18:42.485746754Z","status":404,'
          '"error":"Not Found","message":"Evento com id 9999 não encontrado",'
          '"path":"/eventos/9999","fieldErrors":[]}';

      final erro = ApiException.fromResponse(404, corpo, '/eventos/9999');
      expect(erro.isNotFound, isTrue);
      expect(erro.message, 'Evento com id 9999 não encontrado');
      expect(erro.fieldErrors, isEmpty);
    });

    test('le o 401 do login com a mensagem da API', () {
      // Corpo real de POST /auth/login com senha errada.
      const corpo =
          '{"timestamp":"2026-11-15T18:54:25.154969772Z","status":401,'
          '"error":"Unauthorized","message":"E-mail ou senha inválidos",'
          '"path":"/auth/login","fieldErrors":[]}';

      final erro = ApiException.fromResponse(401, corpo, '/auth/login');
      expect(erro.isUnauthorized, isTrue);
      expect(erro.message, 'E-mail ou senha inválidos');
    });

    test('da mensagem propria ao 401 e ao 403 sem corpo', () {
      // O filtro de seguranca do Spring responde 401/403 com corpo vazio
      // quando o token falta, venceu ou o papel nao permite a rota.
      final semToken = ApiException.fromResponse(401, '', '/eventos');
      // `contains`: o texto contem o trecho informado.
      expect(semToken.message, contains('sessão expirou'));

      final semPapel = ApiException.fromResponse(403, '', '/participantes');
      expect(semPapel.isForbidden, isTrue);
      expect(semPapel.message, 'Você não tem permissão para esta operação.');
    });

    test(
      'reconhece HTML no lugar de JSON como pedido que nao chegou a API',
      () {
        // Base relativa sem proxy: o servidor de SPA responde index.html com
        // status 200, nao 404.
        final erro = ApiException.misrouted('/eventos');
        expect(erro.kind, ApiErrorKind.misrouted);

        // A mensagem precisa dizer o que fazer, nao so que algo deu errado.
        expect(erro.message, contains('API_BASE_URL'));
      },
    );

    test('cai para mensagem generica quando o corpo nao e o envelope', () {
      // Pode acontecer com um erro do proxy ou do host (HTML, texto puro).
      final erro = ApiException.fromResponse(
        502,
        '<html>Bad Gateway</html>',
        '/eventos',
      );
      expect(erro.status, 502);
      expect(erro.isServerError, isTrue);
      expect(erro.message, isNotEmpty);
      expect(erro.fieldErrors, isEmpty);
    });
  });

  group('ApiClient.resolve', () {
    test('monta a query e descarta filtros nulos', () {
      final uri = ApiClient.resolve('/inscricoes', {
        'eventoId': 2,
        'participanteId': null, // filtro nao aplicado
        'status': 'CONFIRMADA',
        'page': 0,
      });
      // Numeros viram texto na query string.
      expect(uri.queryParameters['eventoId'], '2');
      expect(uri.queryParameters['status'], 'CONFIRMADA');
      expect(uri.queryParameters['page'], '0');
      // A chave nula nem aparece.
      expect(uri.queryParameters.containsKey('participanteId'), isFalse);
    });

    test('nao cria query quando nao ha parametros', () {
      expect(ApiClient.resolve('/eventos').hasQuery, isFalse);
      // Mapa so com valores nulos tambem nao gera "?".
      expect(ApiClient.resolve('/eventos', {'x': null}).hasQuery, isFalse);
    });
  });

  group('modelos', () {
    test('Evento le a resposta real da API', () {
      // `const {...}`: Map literal constante, copiado de uma resposta real.
      final evento = Evento.fromJson(const {
        'id': 1,
        'titulo': 'Radar Tech',
        'descricao': 'Evento da Semana Academica',
        'dataInicio': '2026-12-04T17:06:44.19',
        'dataFim': '2026-12-08T17:06:44.19',
        'vagas': 200,
        'vagasDisponiveis': 200,
        'endereco': {
          'cep': '85601-000',
          'logradouro': 'Avenida Julio Assis Cavalheiro',
          'bairro': 'Centro',
          'cidade': 'Francisco Beltrao',
          'uf': 'PR',
          'numero': '02',
        },
        'fotoUrl': null,
      });

      expect(evento.id, 1);
      expect(evento.vagas, 200);
      expect(evento.fotoUrl, isNull);
      expect(evento.endereco.cidadeUf, 'Francisco Beltrao - PR');
      expect(
        evento.endereco.linha,
        contains('Avenida Julio Assis Cavalheiro, 02'),
      );
    });

    group('ocupacao do evento', () {
      /// Evento minimo com 10 vagas e [livres] vagas disponiveis.
      Evento evento(int livres) => Evento.fromJson({
        'id': 1,
        'titulo': 'Show',
        'descricao': '',
        'dataInicio': '2026-12-01T19:00:00',
        'dataFim': '2026-12-01T23:00:00',
        'vagas': 10,
        'vagasDisponiveis': livres,
        'endereco': const {
          'cep': '85601-000',
          'logradouro': 'Rua A',
          'bairro': 'Centro',
          'cidade': 'Francisco Beltrao',
          'uf': 'PR',
          'numero': null,
        },
        'fotoUrl': null,
      });

      test('calcula as vagas preenchidas a partir das disponiveis', () {
        final e = evento(3);
        expect(e.vagasDisponiveis, 3);
        expect(e.vagasOcupadas, 7);
        expect(e.lotado, isFalse);
      });

      test('evento sem inscricoes tem todas as vagas livres', () {
        final e = evento(10);
        expect(e.vagasOcupadas, 0);
        expect(e.lotado, isFalse);
      });

      test('fica lotado quando nao sobra nenhuma vaga', () {
        final e = evento(0);
        expect(e.vagasOcupadas, 10);
        expect(e.lotado, isTrue);
      });

      test('exige o campo vagasDisponiveis da API', () {
        expect(
          () => Evento.fromJson(const {
            'id': 1,
            'titulo': 'Show',
            'descricao': '',
            'dataInicio': '2026-12-01T19:00:00',
            'dataFim': '2026-12-01T23:00:00',
            'vagas': 10,
            'endereco': {
              'cep': '85601-000',
              'logradouro': 'Rua A',
              'bairro': 'Centro',
              'cidade': 'Francisco Beltrao',
              'uf': 'PR',
            },
          }),
          throwsA(isA<TypeError>()),
        );
      });
    });

    test('EventoInput.fromEvento preserva fotoUrl e numero no PUT', () {
      // O PUT e substituicao total: partir do evento atual e o que impede
      // esses dois campos de virarem null numa edicao que nao os tocou.
      final evento = Evento.fromJson(const {
        'id': 7,
        'titulo': 'Show',
        'descricao': '',
        'dataInicio': '2026-12-01T19:00:00',
        'dataFim': '2026-12-01T23:00:00',
        'vagas': 50,
        'vagasDisponiveis': 50,
        'endereco': {
          'cep': '85601-336',
          'logradouro': 'Rua Silvia Abdala',
          'bairro': 'Agua Branca',
          'cidade': 'Francisco Beltrao',
          'uf': 'PR',
          'numero': '123',
        },
        'fotoUrl': 'https://exemplo.com/foto.png',
      });

      final json = EventoInput.fromEvento(evento).toJson();
      expect(json['fotoUrl'], 'https://exemplo.com/foto.png');
      expect(json['numero'], '123');
      expect(json['cep'], '85601-336');
      expect(json['dataInicio'], '2026-12-01T19:00:00');
      expect(json['vagas'], 50);
    });

    test('EventoInput manda null em vez de string vazia', () {
      final json = EventoInput(
        titulo: 'X',
        descricao: '',
        dataInicio: DateTime(2026, 1, 1, 10),
        dataFim: DateTime(2026, 1, 1, 12),
        vagas: 1,
        cep: '85601000',
        numero: '',
        fotoUrl: '',
      ).toJson();
      expect(json['numero'], isNull);
      expect(json['fotoUrl'], isNull);
    });

    test('ParticipanteInput normaliza como o back-end faz', () {
      final json = ParticipanteInput(
        nome: '  Maria Silva  ',
        email: '  MARIA@Exemplo.COM  ',
        cpf: '529.982.247-25',
        telefone: '(46) 99988-7766',
        senha: 'segredo123',
      ).toJson();
      expect(json['nome'], 'Maria Silva');
      expect(json['email'], 'maria@exemplo.com');
      expect(json['cpf'], '52998224725');
      expect(json['telefone'], '46999887766');
      // A senha vai como digitada: o back-end so guarda o hash.
      expect(json['senha'], 'segredo123');
    });

    test('ParticipanteInput manda telefone null quando vazio', () {
      final json = ParticipanteInput(
        nome: 'A',
        email: 'a@b.com',
        cpf: '52998224725',
        telefone: '',
        senha: 'segredo123',
      ).toJson();
      expect(json['telefone'], isNull);
    });
  });

  group('ParticipantePatch', () {
    // Registro "atual" compartilhado pelos testes do grupo.
    final atual = Participante.fromJson(const {
      'id': 1,
      'nome': 'Maria Silva',
      'email': 'maria@exemplo.com',
      'cpf': '52998224725',
      'telefone': '46999887766',
    });

    test('envia somente o que mudou', () {
      // Mesmos dados (so com mascara): nada mudou.
      final patch = ParticipantePatch.diff(
        atual: atual,
        nome: 'Maria Silva',
        email: 'maria@exemplo.com',
        cpf: '529.982.247-25',
        telefone: '(46) 99988-7766',
      );
      expect(patch.isEmpty, isTrue);
      expect(patch.toJson(), isEmpty);
    });

    test('detecta troca de nome sem tocar nos outros campos', () {
      final patch = ParticipantePatch.diff(
        atual: atual,
        nome: 'Maria Souza',
        email: 'maria@exemplo.com',
        cpf: '52998224725',
        telefone: '46999887766',
      );
      final json = patch.toJson();
      // Comparar com um Map literal verifica chaves E valores.
      expect(json, {'nome': 'Maria Souza'});
      expect(json.containsKey('telefone'), isFalse);
    });

    test('apaga o telefone com string vazia, nunca com null', () {
      // `null` significa "nao mexer" no back-end; so `""` zera o campo
      // (telefone = it.ifEmpty { null }).
      final patch = ParticipantePatch.diff(
        atual: atual,
        nome: atual.nome,
        email: atual.email,
        cpf: atual.cpf,
        telefone: '',
      );
      expect(patch.limparTelefone, isTrue);
      expect(patch.toJson()['telefone'], '');
    });

    test('nao tenta apagar telefone que ja era vazio', () {
      final semTelefone = Participante.fromJson(const {
        'id': 2,
        'nome': 'Joao',
        'email': 'joao@exemplo.com',
        'cpf': '52998224725',
        'telefone': null,
      });
      final patch = ParticipantePatch.diff(
        atual: semTelefone,
        nome: 'Joao',
        email: 'joao@exemplo.com',
        cpf: '52998224725',
        telefone: '',
      );
      expect(patch.isEmpty, isTrue);
    });
  });

  group('StatusInscricao', () {
    test('converte de e para o valor da API', () {
      expect(StatusInscricao.fromWire('PENDENTE'), StatusInscricao.pendente);
      expect(
        StatusInscricao.fromWire('CONFIRMADA'),
        StatusInscricao.confirmada,
      );
      expect(StatusInscricao.fromWire('CANCELADA'), StatusInscricao.cancelada);
      expect(StatusInscricao.confirmada.wire, 'CONFIRMADA');
      // Para testar que algo LANCA excecao, passa-se uma FUNCAO (`() => ...`)
      // ao `expect`, e o matcher `throwsA` confere o tipo do erro.
      expect(
        () => StatusInscricao.fromWire('OUTRO'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('reproduz a maquina de estados do back-end', () {
      // Comparar Sets ignora a ordem dos elementos.
      expect(StatusInscricao.pendente.proximos, {
        StatusInscricao.confirmada,
        StatusInscricao.cancelada,
      });
      expect(StatusInscricao.confirmada.proximos, {StatusInscricao.cancelada});
      expect(StatusInscricao.cancelada.proximos, isEmpty);
      expect(StatusInscricao.cancelada.terminal, isTrue);

      // Repetir o status atual tambem e recusado pela API (409), entao nunca
      // pode aparecer entre as opcoes oferecidas.
      for (final status in StatusInscricao.values) {
        expect(status.proximos.contains(status), isFalse, reason: status.wire);
      }
    });

    test('apenas CANCELADA libera vaga', () {
      expect(StatusInscricao.pendente.ocupaVaga, isTrue);
      expect(StatusInscricao.confirmada.ocupaVaga, isTrue);
      expect(StatusInscricao.cancelada.ocupaVaga, isFalse);
    });
  });

  group('PagedModel', () {
    test('le o formato do Spring Data', () {
      // Passa `Participante.fromJson` como funcao conversora dos itens.
      final pagina = PagedModel.fromJson(const {
        'content': [
          {
            'id': 1,
            'nome': 'Maria',
            'email': 'maria@exemplo.com',
            'cpf': '52998224725',
            'telefone': null,
          },
        ],
        'page': {'size': 20, 'number': 0, 'totalElements': 1, 'totalPages': 1},
      }, Participante.fromJson);

      expect(pagina.content, hasLength(1));
      expect(pagina.content.first.nome, 'Maria');
      expect(pagina.totalElements, 1);
      expect(pagina.hasNext, isFalse);
      expect(pagina.hasPrevious, isFalse);
      expect(pagina.faixaDescrita, '1-1 de 1');
    });

    test('le a pagina vazia que a API devolve hoje em /participantes', () {
      final pagina = PagedModel.fromJson(const {
        'content': <Map<String, dynamic>>[],
        'page': {'size': 20, 'number': 0, 'totalElements': 0, 'totalPages': 0},
      }, Participante.fromJson);

      expect(pagina.isEmpty, isTrue);
      expect(pagina.hasNext, isFalse);
      expect(pagina.faixaDescrita, '0 de 0');
    });

    test('calcula a faixa de uma pagina do meio', () {
      // `List<int>.filled(20, 0)` = lista de 20 zeros (so para ter 20 itens).
      final pagina = PagedModel<int>(
        content: List<int>.filled(20, 0),
        size: 20,
        number: 2,
        totalElements: 57,
        totalPages: 3,
      );
      expect(pagina.faixaDescrita, '41-60 de 57');
      expect(pagina.hasPrevious, isTrue);
      expect(pagina.hasNext, isFalse);
    });
  });

  group('Inscricao', () {
    test('le a resposta desnormalizada da API', () {
      final inscricao = Inscricao.fromJson(const {
        'id': 10,
        'participanteId': 1,
        'participanteNome': 'Maria Silva',
        'eventoId': 2,
        'eventoTitulo': 'Show de Jazz',
        'status': 'PENDENTE',
        'dataInscricao': '2026-11-13T10:00:00',
      });

      expect(inscricao.id, 10);
      expect(inscricao.participanteNome, 'Maria Silva');
      expect(inscricao.eventoTitulo, 'Show de Jazz');
      expect(inscricao.status, StatusInscricao.pendente);
      expect(inscricao.dataInscricao.hour, 10);
    });

    test('InscricaoInput manda so o evento: o participante vem do token', () {
      expect(const InscricaoInput(eventoId: 2).toJson(), {'eventoId': 2});
    });
  });

  group('auth', () {
    // JWT real no formato que o TokenService gera (HS256), com sub, exp,
    // email e papel. A assinatura nao importa: o cliente nao confere.
    // Funcao auxiliar local: monta "cabecalho.payload.assinatura".
    String jwt(Map<String, dynamic> claims) {
      // Converte objeto -> JSON -> bytes -> Base64 URL, sem o preenchimento `=`.
      String parte(Object json) =>
          base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
      return '${parte({'alg': 'HS256'})}.${parte(claims)}.assinatura';
    }

    test('TokenResponse le a resposta de POST /auth/login', () {
      final token = TokenResponse.fromJson(const {
        'token': 'a.b.c',
        'tipo': 'Bearer',
        'expiraEmSegundos': 7200,
        'usuarioId': 3,
        'papel': 'ORGANIZADOR',
      });
      expect(token.usuarioId, 3);
      expect(token.papel, Papel.organizador);
      expect(token.expiraEmSegundos, 7200);
    });

    test('UsuarioLogado tira e-mail e validade do proprio JWT', () {
      final usuario = UsuarioLogado.fromToken(
        TokenResponse(
          token: jwt({
            'sub': '7',
            'email': 'maria@exemplo.com',
            'papel': 'PARTICIPANTE',
            // `exp` em SEGUNDOS desde 1970 (epoch).
            'exp': 1800000000,
          }),
          expiraEmSegundos: 7200,
          usuarioId: 7,
          papel: Papel.participante,
        ),
      );
      expect(usuario.email, 'maria@exemplo.com');
      expect(usuario.ehParticipante, isTrue);
      expect(usuario.expiraEm.millisecondsSinceEpoch, 1800000000 * 1000);
    });

    test('considera vencido o token no fim da validade', () {
      // `DateTime.utc` cria um instante em UTC (o `exp` do JWT e um instante real).
      final agora = DateTime.utc(2026, 11, 15, 12);
      final usuario = UsuarioLogado(
        token: 'x',
        id: 1,
        papel: Papel.participante,
        email: 'a@b.com',
        expiraEm: agora.add(const Duration(minutes: 1)),
      );
      // Faltando 1 min (> margem de 15 s): ainda vale.
      expect(usuario.expiradoEm(agora), isFalse);
      // Chegou ao fim da validade: vencido.
      expect(usuario.expiradoEm(agora.add(const Duration(minutes: 1))), isTrue);
    });

    test('UsuarioLogado sobrevive a ida e volta pelo storage', () {
      final original = UsuarioLogado(
        token: 'x.y.z',
        id: 9,
        papel: Papel.organizador,
        email: 'org@acontece.com',
        expiraEm: DateTime.utc(2027),
      );
      // Objeto -> Map -> texto JSON -> Map -> objeto (o que o localStorage faz).
      final lido = UsuarioLogado.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(lido.id, 9);
      expect(lido.papel, Papel.organizador);
      expect(lido.expiraEm, DateTime.utc(2027));
    });

    test('LoginInput normaliza o e-mail como o AuthService', () {
      expect(
        const LoginInput(email: '  Org@Acontece.COM ', senha: ' s ').toJson(),
        // A senha NAO e alterada (espacos preservados).
        {'email': 'org@acontece.com', 'senha': ' s '},
      );
    });
  });

  // Testes do repositorio SEM tela: um `MockClient` (cliente HTTP falso) responde
  // no lugar da rede, e o teste confere a URL pedida e o que o repositorio devolve.
  group('EventoRepository', () {
    /// Evento minimo em JSON, com [id] e 10 vagas livres.
    Map<String, dynamic> evento(int id) => {
      'id': id,
      'titulo': 'Evento $id',
      'descricao': '',
      'dataInicio': '2026-12-01T19:00:00',
      'dataFim': '2026-12-01T23:00:00',
      'vagas': 10,
      'vagasDisponiveis': 10,
      'endereco': {
        'cep': '85601-000',
        'logradouro': 'Rua A',
        'bairro': 'Centro',
        'cidade': 'Francisco Beltrao',
        'uf': 'PR',
      },
      'fotoUrl': null,
    };

    /// Pagina do Spring Data com [itens] e a posicao entre [paginas]. Os numeros
    /// de `size` e `totalElements` nao importam aqui: o repositorio decide se ha
    /// proxima pagina por `number` e `totalPages`.
    http.Response pagina(List<int> itens, int numero, int paginas) =>
        http.Response(
          jsonEncode({
            'content': [for (final id in itens) evento(id)],
            'page': {
              'size': 2,
              'number': numero,
              'totalElements': 3,
              'totalPages': paginas,
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );

    test('listar manda os filtros somados e omite os vazios', () async {
      // `late`: recebe valor depois (dentro do MockClient), antes de ser lida.
      late Uri chamada;
      final repo = EventoRepository(
        ApiClient(
          client: MockClient((request) async {
            chamada = request.url;
            return pagina([1], 0, 1);
          }),
        ),
      );

      await repo.listar(
        titulo: '  semana ',
        inicio: DateTime(2026, 12, 1),
        fim: DateTime(2026, 12, 31, 23, 59, 59),
        size: 100,
      );

      expect(chamada.path, '/eventos');
      expect(chamada.queryParameters['titulo'], 'semana');
      // Datas sem fuso, como a API le (LocalDateTime).
      expect(chamada.queryParameters['inicio'], '2026-12-01T00:00:00');
      expect(chamada.queryParameters['fim'], '2026-12-31T23:59:59');
      expect(chamada.queryParameters['size'], '100');
      expect(chamada.queryParameters.containsKey('sort'), isFalse);

      // Titulo so com espacos equivale a nao filtrar: nem vai na URL.
      await repo.listar(titulo: '   ');
      expect(chamada.queryParameters.containsKey('titulo'), isFalse);
      expect(chamada.queryParameters.containsKey('inicio'), isFalse);
    });

    test('listarTodos percorre todas as paginas', () async {
      // Guarda cada pagina pedida, na ordem, para conferir o percurso.
      final paginasPedidas = <String>[];
      final repo = EventoRepository(
        ApiClient(
          client: MockClient((request) async {
            final numero = int.parse(request.url.queryParameters['page']!);
            paginasPedidas.add('$numero');
            return numero == 0 ? pagina([1, 2], 0, 2) : pagina([3], 1, 2);
          }),
        ),
      );

      final todos = await repo.listarTodos();

      // Os eventos das duas paginas vieram juntos, na ordem; e foram pedidas
      // exatamente a pagina 0 e a 1 (parou ao ver que a 1 era a ultima).
      expect(todos.map((e) => e.id), [1, 2, 3]);
      expect(paginasPedidas, ['0', '1']);
    });

    // Garante que criar/editar/ler/apagar usam as rotas novas, e nao mais
    // `/evento/criar`, `/evento/atualizar/{id}` etc.
    test('rotas de escrita usam /eventos', () async {
      // Cada pedido vira um texto "VERBO /caminho" para comparar a lista toda.
      final pedidos = <String>[];
      final repo = EventoRepository(
        ApiClient(
          client: MockClient((request) async {
            pedidos.add('${request.method} ${request.url.path}');
            return request.method == 'DELETE'
                ? http.Response('', 204)
                : http.Response(
                    jsonEncode(evento(5)),
                    request.method == 'POST' ? 201 : 200,
                    headers: {'content-type': 'application/json'},
                  );
          }),
        ),
      );
      final entrada = EventoInput(
        titulo: 'X',
        descricao: '',
        dataInicio: DateTime(2026, 1, 1, 10),
        dataFim: DateTime(2026, 1, 1, 12),
        vagas: 1,
        cep: '85601000',
      );

      await repo.criar(entrada);
      await repo.atualizar(5, entrada);
      await repo.buscarPorId(5);
      await repo.deletar(5);

      expect(pedidos, [
        'POST /eventos',
        'PUT /eventos/5',
        'GET /eventos/5',
        'DELETE /eventos/5',
      ]);
    });
  });

  // O cancelamento do participante tem rota propria: PATCH sem corpo.
  group('InscricaoRepository.cancelar', () {
    test('faz PATCH sem corpo em /inscricoes/{id}/cancelar', () async {
      late http.Request pedido;
      final repo = InscricaoRepository(
        ApiClient(
          client: MockClient((request) async {
            pedido = request;
            return http.Response(
              jsonEncode({
                'id': 10,
                'participanteId': 7,
                'participanteNome': 'Maria',
                'eventoId': 1,
                'eventoTitulo': 'Radar Tech',
                'status': 'CANCELADA',
                'dataInscricao': '2026-11-15T10:00:00',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      final inscricao = await repo.cancelar(10);

      expect(pedido.method, 'PATCH');
      expect(pedido.url.path, '/inscricoes/10/cancelar');
      expect(pedido.body, isEmpty);
      expect(inscricao.status, StatusInscricao.cancelada);
    });
  });

  // 429 (bloqueio por tentativas), o modelo de `GET /me` e o nome na sessao.
  group('429 e UsuarioAtual', () {
    test('429 vira ApiException com mensagem e texto proprio', () {
      final comCorpo = ApiException.fromResponse(
        429,
        '{"status":429,"message":"Muitas tentativas de login. Tente '
            'novamente em alguns minutos.","path":"/auth/login"}',
        '/auth/login',
      );
      expect(comCorpo.isTooManyRequests, isTrue);
      expect(comCorpo.message, startsWith('Muitas tentativas de login'));

      final semCorpo = ApiException.fromResponse(429, '', '/auth/login');
      expect(semCorpo.message, contains('Muitas tentativas'));
    });

    test('UsuarioAtual le a resposta de GET /me', () {
      final atual = UsuarioAtual.fromJson(const {
        'id': 7,
        'nome': 'Maria Silva',
        'email': 'maria@exemplo.com',
        'papel': 'PARTICIPANTE',
        'tokenExpiraEm': '2100-01-01T00:00:00Z',
      });
      expect(atual.nome, 'Maria Silva');
      expect(atual.papel, Papel.participante);
    });

    test('UsuarioLogado guarda o nome e o usa como identificacao', () {
      final usuario = UsuarioLogado(
        token: 'a.b.c',
        id: 7,
        papel: Papel.participante,
        email: 'maria@exemplo.com',
        expiraEm: DateTime.utc(2100),
      );
      // Sem nome (login recem-feito ou sessao antiga): usa o e-mail.
      expect(usuario.rotuloExibicao, 'maria@exemplo.com');
      // Depois do `/me`: uma COPIA com o nome (o objeto original nao muda).

      final atualizado = usuario.comDadosDe(
        const UsuarioAtual(
          id: 7,
          nome: 'Maria Silva',
          email: 'maria@exemplo.com',
          papel: Papel.participante,
        ),
      );
      expect(atualizado.rotuloExibicao, 'Maria Silva');
      expect(atualizado.token, 'a.b.c');
      // Sobrevive a gravar e reler a sessao.
      final relido = UsuarioLogado.fromJson(atualizado.toJson());
      expect(relido.nome, 'Maria Silva');
      // Sessao salva antes do `/me` (sem nome) continua valida.
      final antiga = UsuarioLogado.fromJson(usuario.toJson());
      expect(antiga.nome, isNull);
    });
  });

  // Limites e regras novas do back-end espelhados no cliente (ver validators.dart).
  group('validacoes novas', () {
    test('descricao do evento aceita ate 2000 caracteres', () {
      expect(Validators.descricaoEvento('a' * 2000), isNull);
      expect(Validators.descricaoEvento('a' * 2001), isNotNull);
      expect(Validators.descricaoEvento(null), isNull);
    });

    test('URL da foto aceita ate 1000 caracteres', () {
      final longa = 'https://exemplo.com/${'a' * 980}';
      expect(longa.length, 1000);
      expect(Validators.fotoUrl(longa), isNull);
      expect(Validators.fotoUrl('${longa}b'), isNotNull);
    });

    test('nova senha segue o cadastro e difere da atual', () {
      expect(Validators.novaSenha('novaSenha22', 'antiga123'), isNull);
      expect(Validators.novaSenha('curta', 'antiga123'), isNotNull);
      expect(
        Validators.novaSenha('antiga123', 'antiga123'),
        'A nova senha deve ser diferente da atual',
      );
      expect(Validators.confirmacaoSenha('abc', 'abc'), isNull);
      expect(Validators.confirmacaoSenha('abd', 'abc'), isNotNull);
    });
  });
}
