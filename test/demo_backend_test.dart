import 'package:acontece_frontend/core/api_client.dart';
import 'package:acontece_frontend/core/api_exception.dart';
import 'package:acontece_frontend/core/demo_backend.dart';
import 'package:acontece_frontend/models/inscricao.dart';
import 'package:acontece_frontend/models/participante.dart';
import 'package:acontece_frontend/models/status_inscricao.dart';
import 'package:acontece_frontend/repositories/evento_repository.dart';
import 'package:acontece_frontend/repositories/inscricao_repository.dart';
import 'package:acontece_frontend/repositories/participante_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late EventoRepository eventos;
  late ParticipanteRepository participantes;
  late InscricaoRepository inscricoes;

  setUp(() {
    final client = ApiClient(client: DemoBackend().client);
    eventos = EventoRepository(client);
    participantes = ParticipanteRepository(client);
    inscricoes = InscricaoRepository(client);
  });

  test('demo: todas as rotas de leitura respondem', () async {
    expect(await eventos.listar(), hasLength(5));
    expect((await eventos.buscarPorTitulo('flutter')).single.id, 3);
    expect((await participantes.listar()).totalElements, 5);
    expect(await inscricoes.moduloDisponivel(), isTrue);
    expect(await inscricoes.contarAtivasDoEvento(1), 2);
  });

  test('demo: regras de negocio espelham a API', () async {
    // Evento 2 ja encerrou.
    await expectLater(
      inscricoes.criar(const InscricaoInput(participanteId: 2, eventoId: 2)),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 400)),
    );
    // CPF duplicado.
    await expectLater(
      participantes.criar(const ParticipanteInput(
          nome: 'X', email: 'x@x.com', cpf: '52998224725')),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 409)),
    );
    final nova = await inscricoes
        .criar(const InscricaoInput(participanteId: 3, eventoId: 5));
    expect(nova.status, StatusInscricao.pendente);
    final conf = await inscricoes.atualizarStatus(
        nova.id, StatusInscricao.confirmada);
    expect(conf.status, StatusInscricao.confirmada);
  });
}
