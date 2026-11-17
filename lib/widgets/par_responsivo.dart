// =============================================================================
// par_responsivo.dart - LAYOUT DE FORMULARIO QUE SE ADAPTA A LARGURA
// =============================================================================
//
// Dois widgets pequenos usados nos formularios:
//   * ParResponsivo   -> dois campos lado a lado (ou empilhados no celular)
//   * AcoesFormulario -> botoes de salvar/cancelar
// =============================================================================

import 'package:material_ui/material_ui.dart';

// `Tela` (faixa de largura) para decidir o layout.
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

  /// Widgets (normalmente campos de texto) de cada lado.
  final Widget esquerda;
  final Widget direita;

  /// Proporcao de largura de cada lado (flex 2 e 1 => 2/3 e 1/3).
  final int flexEsquerda;
  final int flexDireita;

  @override
  Widget build(BuildContext context) {
    // Celular: empilha. Column = widgets em coluna (vertical).
    if (Tela.of(context).ehCelular) {
      return Column(
        // `stretch` faz cada filho ocupar toda a largura disponivel.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        // Um embaixo do outro, com 12 px de espaco no meio.
        children: [esquerda, const SizedBox(height: 12), direita],
      );
    }
    // Telas maiores: lado a lado. Row = widgets em linha (horizontal).
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Expanded: o filho divide o espaco da linha conforme `flex`.
        // (Necessario: campo de texto dentro de Row sem Expanded da erro.)
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

  /// Botao da acao principal (ex.: "Salvar").
  final Widget principal;

  /// Botao da acao secundaria (ex.: "Cancelar").
  final Widget secundario;

  @override
  Widget build(BuildContext context) {
    if (Tela.of(context).ehCelular) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        // Principal em cima, secundario embaixo, 8 px de espaco entre eles.
        children: [principal, const SizedBox(height: 8), secundario],
      );
    }
    // Wrap: como Row, mas quebra para a linha de baixo se nao couber.
    return Wrap(
      // Espaco horizontal entre itens e vertical entre linhas.
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [principal, secundario],
    );
  }
}
