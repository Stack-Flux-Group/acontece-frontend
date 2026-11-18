// =============================================================================
// area_selo.dart - ESPACO RESERVADO PARA O SELO DO NETLIFY
// =============================================================================
//
// Em producao o Netlify injeta um selo "Powered by Netlify" fixo no canto
// inferior direito da pagina. Ele e um iframe por cima do app: cobre o que
// estiver ali e captura os cliques. Nao da para controla-lo pelo Flutter, entao
// o app o trata como uma "area segura", igual a barra inferior do iPhone.
//
// CONCEITO - MediaQuery.padding/viewPadding: informam quanto da tela esta
// ocupado por algo externo ao app. FAB, snackbar, SafeArea e NavigationBar ja
// respeitam esses valores sozinhos; as listas usam [folgaFinalDaLista].
// =============================================================================

import 'package:material_ui/material_ui.dart';

/// Altura reservada para o selo: 61 px visiveis (medidos no site publicado,
/// contando a distancia ate a base da janela) mais um respiro.
const double alturaSeloNetlify = 64;

/// Reserva usada quando o app nao recebe outra: so existe selo no Netlify.
/// Em `localhost` e nos testes o resultado e zero.
double reservaInferiorPadrao() =>
    Uri.base.host.endsWith('.netlify.app') ? alturaSeloNetlify : 0;

/// Soma [reserva] a area segura inferior de tudo o que esta abaixo na arvore.
class ReservaInferior extends StatelessWidget {
  const ReservaInferior({
    super.key,
    required this.reserva,
    required this.child,
  });

  /// Altura reservada, em pixels logicos. Zero nao altera nada.
  final double reserva;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reserva <= 0) return child;
    final dados = MediaQuery.of(context);
    final extra = EdgeInsets.only(bottom: reserva);
    return MediaQuery(
      data: dados.copyWith(
        padding: dados.padding + extra,
        viewPadding: dados.viewPadding + extra,
      ),
      child: child,
    );
  }
}

/// Espaco no fim de uma lista rolavel: [base] mais a area segura inferior, para
/// que o ultimo item possa subir acima do selo e do FAB.
EdgeInsets folgaFinalDaLista(BuildContext context, {double base = 48}) =>
    EdgeInsets.only(bottom: base + MediaQuery.paddingOf(context).bottom);
