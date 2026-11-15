import 'package:material_ui/material_ui.dart';

import 'core/api_client.dart';
import 'repositories/evento_repository.dart';
import 'repositories/inscricao_repository.dart';
import 'repositories/participante_repository.dart';

/// Disponibiliza os repositorios para a arvore de widgets.
///
/// Um `InheritedWidget` basta aqui: as dependencias sao tres repositorios sem
/// estado, criados uma vez e nunca substituidos. Trazer Provider ou Riverpod
/// para isso seria peso sem retorno.
class Services extends InheritedWidget {
  Services({super.key, required super.child, ApiClient? client})
    : client = client ?? ApiClient(),
      _criado = client == null {
    eventos = EventoRepository(this.client);
    participantes = ParticipanteRepository(this.client);
    inscricoes = InscricaoRepository(this.client);
  }

  final ApiClient client;
  final bool _criado;

  late final EventoRepository eventos;
  late final ParticipanteRepository participantes;
  late final InscricaoRepository inscricoes;

  static Services of(BuildContext context) {
    final services = context
        .dependOnInheritedWidgetOfExactType<Services>();
    assert(services != null, 'Services nao encontrado acima deste widget.');
    return services!;
  }

  /// Os repositorios sao imutaveis, entao nada depende de reconstrucao.
  @override
  bool updateShouldNotify(Services old) => old.client != client;

  /// Fecha o cliente HTTP quando o proprio widget o criou.
  void dispose() {
    if (_criado) client.close();
  }
}
