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

import 'package:acontece_frontend/core/api_client.dart';
import 'package:acontece_frontend/core/api_dates.dart';
import 'package:acontece_frontend/core/api_exception.dart';
import 'package:acontece_frontend/models/auth.dart';
import 'package:acontece_frontend/models/evento.dart';
import 'package:acontece_frontend/models/inscricao.dart';
import 'package:acontece_frontend/models/paged_model.dart';
import 'package:acontece_frontend/models/participante.dart';
import 'package:acontece_frontend/models/status_inscricao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiDates', () {
    test('le a fracao de segundo que a API realmente devolve', () {
      // Resposta real de GET /evento/listar/.
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
          '"path":"/evento/buscar/9999","fieldErrors":[]}';

      final erro = ApiException.fromResponse(404, corpo, '/evento/buscar/9999');
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
      final semToken = ApiException.fromResponse(401, '', '/evento/listar/');
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
        final erro = ApiException.misrouted('/evento/listar/');
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
        '/evento/listar/',
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

    test('preserva a barra final obrigatoria de /evento/listar/', () {
      // Sem a barra no fim a rota nao casa no Spring.
      expect(
        ApiClient.resolve('/evento/listar/').path,
        endsWith('/evento/listar/'),
      );
    });

    test('nao cria query quando nao ha parametros', () {
      expect(ApiClient.resolve('/evento/listar/').hasQuery, isFalse);
      // Mapa so com valores nulos tambem nao gera "?".
      expect(
        ApiClient.resolve('/evento/listar/', {'x': null}).hasQuery,
        isFalse,
      );
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
}
