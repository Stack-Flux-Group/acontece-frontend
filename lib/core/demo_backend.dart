import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'api_dates.dart';

/// Back-end falso, em memoria, para visualizar o site sem a `acontece-api`.
///
/// Responde as mesmas rotas e no mesmo formato da API real (envelope de erro,
/// `PagedModel`, datas naive, status HTTP), entao telas e repositorios rodam
/// sem nenhuma alteracao. Os dados vivem so na memoria da aba: recarregar a
/// pagina volta ao estado inicial.
///
/// Ativo por padrao (ver `main.dart`). Para usar a API de verdade:
/// `--dart-define=USE_API=true`.
class DemoBackend {
  DemoBackend() {
    _semear();
  }

  /// Cliente HTTP que o `ApiClient` usa no lugar da rede.
  http.Client get client => MockClient(_responder);

  final _eventos = <int, Map<String, dynamic>>{};
  final _participantes = <int, Map<String, dynamic>>{};
  final _inscricoes = <int, Map<String, dynamic>>{};
  var _proxEvento = 1;
  var _proxParticipante = 1;
  var _proxInscricao = 1;

  // ---------------------------------------------------------------- roteamento

  Future<http.Response> _responder(http.Request req) async {
    // Pequena latencia para os estados de carregamento aparecerem.
    await Future<void>.delayed(const Duration(milliseconds: 250));

    var path = req.url.path;
    final i = path.indexOf('/api/');
    if (i >= 0) path = path.substring(i + 4);
    final q = req.url.queryParameters;
    final body = req.body.isEmpty ? null : jsonDecode(req.body);
    final m = req.method;
    final seg = path.split('/').where((s) => s.isNotEmpty).toList();

    try {
      // Eventos
      if (m == 'GET' && path == '/evento/listar/') {
        return _ok(_eventos.values.toList());
      }
      if (m == 'GET' && path == '/evento/buscar/titulo') {
        final t = (q['titulo'] ?? '').toLowerCase();
        return _ok(_eventos.values
            .where((e) => (e['titulo'] as String).toLowerCase().contains(t))
            .toList());
      }
      if (m == 'GET' && path == '/evento/buscar/periodo') {
        final ini = DateTime.parse(q['inicio']!);
        final fim = DateTime.parse(q['fim']!);
        if (fim.isBefore(ini)) {
          return _erro(400, 'A data final deve ser posterior a data inicial', path);
        }
        final lista = _eventos.values.where((e) {
          final d = DateTime.parse(e['dataInicio'] as String);
          return !d.isBefore(ini) && !d.isAfter(fim);
        }).toList()
          ..sort((a, b) =>
              (a['dataInicio'] as String).compareTo(b['dataInicio'] as String));
        return _ok(lista);
      }
      if (m == 'GET' && seg.length == 3 && seg[0] == 'evento' && seg[1] == 'buscar') {
        return _ok(_evento(int.parse(seg[2]), path));
      }
      if (m == 'POST' && path == '/evento/criar') {
        final e = _montarEvento(_proxEvento++, body as Map, path);
        _eventos[e['id'] as int] = e;
        return _ok(e);
      }
      if (m == 'PUT' && seg.length == 3 && seg[1] == 'atualizar') {
        final id = int.parse(seg[2]);
        _evento(id, path);
        final e = _montarEvento(id, body as Map, path);
        _eventos[id] = e;
        _renomearInscricoes(eventoId: id, titulo: e['titulo'] as String);
        return _ok(e);
      }
      if (m == 'DELETE' && seg.length == 3 && seg[1] == 'deletar') {
        final id = int.parse(seg[2]);
        _evento(id, path);
        if (_inscricoes.values.any((i) => i['eventoId'] == id)) {
          return _erro(409, 'Evento possui inscricoes e nao pode ser excluido', path);
        }
        _eventos.remove(id);
        return http.Response('', 204);
      }

      // Participantes
      if (seg.isNotEmpty && seg[0] == 'participantes') {
        if (m == 'GET' && seg.length == 1) {
          return _ok(_paginar(_participantes.values.toList(), q));
        }
        if (m == 'GET' && seg.length == 2) {
          return _ok(_participante(int.parse(seg[1]), path));
        }
        if (m == 'POST' && seg.length == 1) {
          final dados = (body as Map).cast<String, dynamic>();
          final erro = _validarParticipante(dados, null, path);
          if (erro != null) return erro;
          final p = <String, dynamic>{
            'id': _proxParticipante++,
            'nome': dados['nome'],
            'email': dados['email'],
            'cpf': dados['cpf'],
            'telefone': dados['telefone'],
          };
          _participantes[p['id'] as int] = p;
          return _ok(p, 201);
        }
        if (m == 'PATCH' && seg.length == 2) {
          final id = int.parse(seg[1]);
          final p = _participante(id, path);
          final dados = (body as Map).cast<String, dynamic>();
          final erro = _validarParticipante(dados, id, path);
          if (erro != null) return erro;
          for (final k in ['nome', 'email', 'cpf']) {
            if (dados[k] != null) p[k] = dados[k];
          }
          if (dados['telefone'] != null) {
            final t = dados['telefone'] as String;
            p['telefone'] = t.isEmpty ? null : t;
          }
          _renomearInscricoes(participanteId: id, nome: p['nome'] as String);
          return _ok(p);
        }
        if (m == 'DELETE' && seg.length == 2) {
          final id = int.parse(seg[1]);
          _participante(id, path);
          if (_inscricoes.values.any((i) => i['participanteId'] == id)) {
            return _erro(409,
                'Participante possui inscricoes e nao pode ser excluido', path);
          }
          _participantes.remove(id);
          return http.Response('', 204);
        }
      }

      // Inscricoes
      if (seg.isNotEmpty && seg[0] == 'inscricoes') {
        if (m == 'GET' && seg.length == 1) {
          var lista = _inscricoes.values.where((i) {
            if (q['eventoId'] != null &&
                i['eventoId'] != int.parse(q['eventoId']!)) {
              return false;
            }
            if (q['participanteId'] != null &&
                i['participanteId'] != int.parse(q['participanteId']!)) {
              return false;
            }
            if (q['status'] != null && i['status'] != q['status']) return false;
            return true;
          }).toList();
          return _ok(_paginar(lista, q));
        }
        if (m == 'GET' && seg.length == 2) {
          return _ok(_inscricao(int.parse(seg[1]), path));
        }
        if (m == 'POST' && seg.length == 1) {
          final dados = (body as Map).cast<String, dynamic>();
          final p = _participante((dados['participanteId'] as num).toInt(), path);
          final e = _evento((dados['eventoId'] as num).toInt(), path);
          final agora = ApiDates.nowInSaoPaulo();
          if (!DateTime.parse(e['dataFim'] as String).isAfter(agora)) {
            return _erro(400, 'O evento já foi encerrado', path);
          }
          final ativas = _inscricoes.values.where(
              (i) => i['eventoId'] == e['id'] && i['status'] != 'CANCELADA');
          if (ativas.any((i) => i['participanteId'] == p['id'])) {
            return _erro(409,
                'Participante já possui inscrição ativa neste evento', path);
          }
          if (ativas.length >= (e['vagas'] as int)) {
            return _erro(409, 'Evento sem vagas disponíveis', path);
          }
          final nova = _novaInscricao(p, e, 'PENDENTE', agora);
          return _ok(nova, 201);
        }
        if (m == 'PATCH' && seg.length == 3 && seg[2] == 'status') {
          final i = _inscricao(int.parse(seg[1]), path);
          final novo = (body as Map)['status'] as String;
          const transicoes = {
            'PENDENTE': {'CONFIRMADA', 'CANCELADA'},
            'CONFIRMADA': {'CANCELADA'},
            'CANCELADA': <String>{},
          };
          if (!transicoes[i['status']]!.contains(novo)) {
            return _erro(409,
                'Transição de status inválida: ${i['status']} -> $novo', path);
          }
          i['status'] = novo;
          return _ok(i);
        }
      }

      return _erro(404, 'No static resource ${path.substring(1)}.', path);
    } on _NaoEncontrado catch (e) {
      return _erro(404, e.mensagem, path);
    }
  }

  // ------------------------------------------------------------------ helpers

  Map<String, dynamic> _evento(int id, String path) =>
      _eventos[id] ?? (throw _NaoEncontrado('Evento não encontrado'));

  Map<String, dynamic> _participante(int id, String path) =>
      _participantes[id] ?? (throw _NaoEncontrado('Participante não encontrado'));

  Map<String, dynamic> _inscricao(int id, String path) =>
      _inscricoes[id] ?? (throw _NaoEncontrado('Inscrição não encontrada'));

  http.Response? _validarParticipante(
      Map<String, dynamic> d, int? id, String path) {
    bool usado(String campo) => d[campo] != null &&
        _participantes.values
            .any((p) => p['id'] != id && p[campo] == d[campo]);
    if (usado('cpf')) {
      return _erro(409, 'Já existe um participante com esse CPF', path);
    }
    if (usado('email')) {
      return _erro(409, 'Já existe um participante com esse e-mail', path);
    }
    return null;
  }

  void _renomearInscricoes(
      {int? eventoId, String? titulo, int? participanteId, String? nome}) {
    for (final i in _inscricoes.values) {
      if (eventoId != null && i['eventoId'] == eventoId) i['eventoTitulo'] = titulo;
      if (participanteId != null && i['participanteId'] == participanteId) {
        i['participanteNome'] = nome;
      }
    }
  }

  Map<String, dynamic> _montarEvento(int id, Map dados, String path) {
    final cep = (dados['cep'] ?? '').toString();
    final end = _ceps[cep.replaceAll('-', '')] ??
        const {
          'logradouro': 'Rua de Exemplo',
          'bairro': 'Centro',
          'cidade': 'Francisco Beltrão',
          'uf': 'PR',
        };
    return <String, dynamic>{
      'id': id,
      'titulo': dados['titulo'],
      'descricao': dados['descricao'],
      'dataInicio': dados['dataInicio'],
      'dataFim': dados['dataFim'],
      'vagas': dados['vagas'],
      'endereco': {'cep': cep, ...end, 'numero': dados['numero']},
      'fotoUrl': dados['fotoUrl'],
    };
  }

  Map<String, dynamic> _novaInscricao(Map<String, dynamic> p,
      Map<String, dynamic> e, String status, DateTime quando) {
    final i = <String, dynamic>{
      'id': _proxInscricao++,
      'participanteId': p['id'],
      'participanteNome': p['nome'],
      'eventoId': e['id'],
      'eventoTitulo': e['titulo'],
      'status': status,
      'dataInscricao': ApiDates.format(quando),
    };
    _inscricoes[i['id'] as int] = i;
    return i;
  }

  /// Paginacao e ordenacao no formato `PagedModel` do Spring.
  Map<String, dynamic> _paginar(
      List<Map<String, dynamic>> itens, Map<String, String> q) {
    final page = int.tryParse(q['page'] ?? '') ?? 0;
    final size = int.tryParse(q['size'] ?? '') ?? 20;
    final sort = (q['sort'] ?? 'id').split(',');
    final campo = sort.first;
    final desc = sort.length > 1 && sort[1] == 'desc';
    itens.sort((a, b) {
      final va = a[campo], vb = b[campo];
      final c = va is num && vb is num
          ? va.compareTo(vb)
          : va.toString().toLowerCase().compareTo(vb.toString().toLowerCase());
      return desc ? -c : c;
    });
    final total = itens.length;
    final conteudo = itens.skip(page * size).take(size).toList();
    return {
      'content': conteudo,
      'page': {
        'size': size,
        'number': page,
        'totalElements': total,
        'totalPages': size == 0 ? 0 : (total / size).ceil(),
      },
    };
  }

  http.Response _ok(Object corpo, [int status = 200]) => http.Response.bytes(
        utf8.encode(jsonEncode(corpo)),
        status,
        headers: {'content-type': 'application/json'},
      );

  http.Response _erro(int status, String mensagem, String path) {
    const nomes = {400: 'Bad Request', 404: 'Not Found', 409: 'Conflict'};
    return _ok({
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'status': status,
      'error': nomes[status] ?? 'Error',
      'message': mensagem,
      'path': path,
      'fieldErrors': <Object>[],
    }, status);
  }

  // ------------------------------------------------------------ dados iniciais

  static const _ceps = {
    '85601000': {
      'logradouro': 'Avenida Júlio Assis Cavalheiro',
      'bairro': 'Centro',
      'cidade': 'Francisco Beltrão',
      'uf': 'PR',
    },
    '85601336': {
      'logradouro': 'Rua Sílvia Abdala',
      'bairro': 'Água Branca',
      'cidade': 'Francisco Beltrão',
      'uf': 'PR',
    },
    '80010000': {
      'logradouro': 'Praça Tiradentes',
      'bairro': 'Centro',
      'cidade': 'Curitiba',
      'uf': 'PR',
    },
    '01310100': {
      'logradouro': 'Avenida Paulista',
      'bairro': 'Bela Vista',
      'cidade': 'São Paulo',
      'uf': 'SP',
    },
  };

  void _semear() {
    final hoje = ApiDates.nowInSaoPaulo();
    final base = DateTime(hoje.year, hoje.month, hoje.day);
    String d(int dias, int hora) =>
        ApiDates.format(base.add(Duration(days: dias, hours: hora)));

    void evento(String titulo, String descricao, int iniDia, int iniHora,
        int fimDia, int fimHora, int vagas, String cep, String numero) {
      final e = _montarEvento(_proxEvento++, {
        'titulo': titulo,
        'descricao': descricao,
        'dataInicio': d(iniDia, iniHora),
        'dataFim': d(fimDia, fimHora),
        'vagas': vagas,
        'cep': cep,
        'numero': numero,
        'fotoUrl': null,
      }, '');
      _eventos[e['id'] as int] = e;
    }

    evento('Radar Tech', 'Evento da Semana Acadêmica com palestras e oficinas.',
        19, 17, 23, 22, 200, '85601-000', '02');
    evento('Evento de RAP', 'Batalha de rimas e shows locais.',
        -3, 19, -2, 2, 1, '85601-336', '123');
    evento('Workshop de Flutter', 'Construindo apps web e mobile com Flutter.',
        0, 8, 1, 18, 30, '80010-000', '45');
    evento('Feira de Startups', 'Pitch de startups da região e networking.',
        7, 9, 7, 18, 3, '01310-100', '1578');
    evento('Hackathon Acontece', '48 horas para criar soluções para a cidade.',
        35, 8, 37, 18, 80, '85601-000', '300');

    void participante(String nome, String email, String cpf, String? tel) {
      final p = <String, dynamic>{
        'id': _proxParticipante++,
        'nome': nome,
        'email': email,
        'cpf': cpf,
        'telefone': tel,
      };
      _participantes[p['id'] as int] = p;
    }

    participante('Ana Souza', 'ana.souza@email.com', '52998224725', '46999112233');
    participante('Bruno Lima', 'bruno.lima@email.com', '11144477735', null);
    participante('Carla Mendes', 'carla.mendes@email.com', '39053344705', '41988776655');
    participante('Diego Rocha', 'diego.rocha@email.com', '15350946056', '11977665544');
    participante('Eduarda Alves', 'eduarda.alves@email.com', '46171932009', null);

    void inscricao(int p, int e, String status, int diasAtras) =>
        _novaInscricao(_participantes[p]!, _eventos[e]!, status,
            hoje.subtract(Duration(days: diasAtras)));

    inscricao(1, 1, 'CONFIRMADA', 5);
    inscricao(2, 1, 'PENDENTE', 3);
    inscricao(3, 2, 'CONFIRMADA', 10);
    inscricao(4, 3, 'PENDENTE', 1);
    inscricao(5, 4, 'CANCELADA', 2);
    inscricao(1, 4, 'CONFIRMADA', 2);
  }
}

class _NaoEncontrado implements Exception {
  _NaoEncontrado(this.mensagem);
  final String mensagem;
}
