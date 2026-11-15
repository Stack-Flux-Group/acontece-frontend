import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

/// Dois campos lado a lado (Inicio/Fim, CEP/Numero). No celular nao cabem os
/// dois na mesma linha, entao empilham.
class ParResponsivo extends StatelessWidget {
  const ParResponsivo({
    super.key,
    required this.esquerda,
    required this.direita,
    this.flexEsquerda = 1,
    this.flexDireita = 1,
  });

  final Widget esquerda;
  final Widget direita;
  final int flexEsquerda;
  final int flexDireita;

  @override
  Widget build(BuildContext context) {
    if (Tela.of(context).ehCelular) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [esquerda, const SizedBox(height: 12), direita],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: flexEsquerda, child: esquerda),
        const SizedBox(width: 12),
        Expanded(flex: flexDireita, child: direita),
      ],
    );
  }
}

/// Botoes de acao de um formulario. Quebram de linha em vez de estourar, e no
/// celular o botao principal ocupa a largura toda (alvo de toque maior).
class AcoesFormulario extends StatelessWidget {
  const AcoesFormulario({
    super.key,
    required this.principal,
    required this.secundario,
  });

  final Widget principal;
  final Widget secundario;

  @override
  Widget build(BuildContext context) {
    if (Tela.of(context).ehCelular) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [principal, const SizedBox(height: 8), secundario],
      );
    }
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [principal, secundario],
    );
  }
}
