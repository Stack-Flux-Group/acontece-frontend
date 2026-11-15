import 'package:acontece_frontend/core/api_client.dart';
import 'package:acontece_frontend/core/api_dates.dart';
import 'package:acontece_frontend/core/api_exception.dart';
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
      const texto = '2026-12-04T17:06:44';
      expect(ApiDates.format(ApiDates.parse(texto)), texto);
    });

    test('serializa sem fuso e sem milissegundos, como o LocalDateTime espera', () {
      final valor = DateTime(2026, 12, 1, 19, 30, 5, 123);
      expect(ApiDates.format(valor), '2026-12-01T19:30:05');
    });

    test('tryParse devolve null para ausente ou invalido', () {
      expect(ApiDates.tryParse(null), isNull);
      expect(ApiDates.tryParse(''), isNull);
      expect(ApiDates.tryParse(42), isNull);
      expect(ApiDates.tryParse('nao e data'), isNull);
    });
  });

  group('ApiException', () {
    test('le o envelope de validacao com fieldErrors', () {
      // Corpo real de POST /participantes com dados invalidos.
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

      // Registro ausente nao e rota ausente.
      expect(erro.isMissingEndpoint, isFalse);
    });

    test('distingue rota ausente de registro ausente', () {
      // Corpo real de GET /inscricoes no deploy atual, que nao tem o modulo.
      const corpo =
          '{"timestamp":"2026-11-15T00:18:25.838503940Z","status":404,'
          '"error":"Not Found","message":"No static resource inscricoes.",'
          '"path":"/inscricoes","fieldErrors":[]}';

      final erro = ApiException.fromResponse(404, corpo, '/inscricoes');
      expect(erro.isMissingEndpoint, isTrue);
    });

    test('reconhece HTML no lugar de JSON como pedido que nao chegou a API', () {
      // Caso real: o app aberto na porta do `flutter run` em vez da do proxy.
      // O servidor de SPA responde index.html com status 200, nao 404.
      final erro = ApiException.misrouted('/evento/listar/');
      expect(erro.kind, ApiErrorKind.misrouted);

      // A mensagem precisa dizer o que fazer, nao so que algo deu errado.
      expect(erro.message, contains('8081'));
      expect(erro.message, contains('dev_proxy'));
    });

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
      expect(uri.queryParameters['eventoId'], '2');
      expect(uri.queryParameters['status'], 'CONFIRMADA');
      expect(uri.queryParameters['page'], '0');
      expect(uri.queryParameters.containsKey('participanteId'), isFalse);
    });

    test('preserva a barra final obrigatoria de /evento/listar/', () {
      // Sem a barra no fim a rota nao casa no Spring.
      expect(ApiClient.resolve('/evento/listar/').path, endsWith('/evento/listar/'));
    });

    test('nao cria query quando nao ha parametros', () {
      expect(ApiClient.resolve('/evento/listar/').hasQuery, isFalse);
      expect(ApiClient.resolve('/evento/listar/', {'x': null}).hasQuery, isFalse);
    });
  });

  group('modelos', () {
    test('Evento le a resposta real da API', () {
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
      expect(evento.endereco.linha, contains('Avenida Julio Assis Cavalheiro, 02'));
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
      ).toJson();
      expect(json['nome'], 'Maria Silva');
      expect(json['email'], 'maria@exemplo.com');
      expect(json['cpf'], '52998224725');
      expect(json['telefone'], '46999887766');
    });

    test('ParticipanteInput manda telefone null quando vazio', () {
      final json = ParticipanteInput(
        nome: 'A',
        email: 'a@b.com',
        cpf: '52998224725',
        telefone: '',
      ).toJson();
      expect(json['telefone'], isNull);
    });
  });

  group('ParticipantePatch', () {
    final atual = Participante.fromJson(const {
      'id': 1,
      'nome': 'Maria Silva',
      'email': 'maria@exemplo.com',
      'cpf': '52998224725',
      'telefone': '46999887766',
    });

    test('envia somente o que mudou', () {
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
      expect(StatusInscricao.fromWire('CONFIRMADA'), StatusInscricao.confirmada);
      expect(StatusInscricao.fromWire('CANCELADA'), StatusInscricao.cancelada);
      expect(StatusInscricao.confirmada.wire, 'CONFIRMADA');
      expect(
        () => StatusInscricao.fromWire('OUTRO'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('reproduz a maquina de estados do back-end', () {
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
        'page': {
          'size': 20,
          'number': 0,
          'totalElements': 1,
          'totalPages': 1,
        },
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
        'page': {
          'size': 20,
          'number': 0,
          'totalElements': 0,
          'totalPages': 0,
        },
      }, Participante.fromJson);

      expect(pagina.isEmpty, isTrue);
      expect(pagina.hasNext, isFalse);
      expect(pagina.faixaDescrita, '0 de 0');
    });

    test('calcula a faixa de uma pagina do meio', () {
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

    test('InscricaoInput manda apenas os dois ids', () {
      expect(
        const InscricaoInput(participanteId: 1, eventoId: 2).toJson(),
        {'participanteId': 1, 'eventoId': 2},
      );
    });
  });
}
