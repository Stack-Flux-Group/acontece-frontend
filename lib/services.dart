import 'package:material_ui/material_ui.dart';

import 'core/api_client.dart';
import 'core/sessao.dart';
import 'core/token_storage.dart';
import 'repositories/auth_repository.dart';
import 'repositories/evento_repository.dart';
import 'repositories/inscricao_repository.dart';
import 'repositories/participante_repository.dart';

/// Disponibiliza a sessao e os repositorios para a arvore de widgets.
///
/// Um `InheritedWidget` basta aqui: as dependencias sao criadas uma vez e
/// nunca substituidas. Quem precisa reagir a login/logout escuta a [sessao]
/// (um `ChangeNotifier`), nao este widget.
class Services extends InheritedWidget {
  Services({
    super.key,
    required super.child,
    ApiClient? client,
    TokenStorage? storage,
  }) : client = client ?? ApiClient() {
    auth = AuthRepository(this.client);
    sessao = Sessao(auth: auth, storage: storage ?? TokenStorage.padrao());
    eventos = EventoRepository(this.client);
    participantes = ParticipanteRepository(this.client);
    inscricoes = InscricaoRepository(this.client);

    // Liga o cliente HTTP a sessao: cada pedido le o token do momento, e um
    // 401 em pedido autenticado derruba a sessao (token vencido).
    this.client
      ..tokenProvider = (() => sessao.token)
      ..onUnauthorized = sessao.expirou;
  }

  final ApiClient client;

  late final Sessao sessao;
  late final AuthRepository auth;
  late final EventoRepository eventos;
  late final ParticipanteRepository participantes;
  late final InscricaoRepository inscricoes;

  static Services of(BuildContext context) {
    final services = context.dependOnInheritedWidgetOfExactType<Services>();
    assert(services != null, 'Services nao encontrado acima deste widget.');
    return services!;
  }

  @override
  bool updateShouldNotify(Services old) => old.client != client;
}
