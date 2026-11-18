// =============================================================================
// cabecalho_pagina.dart - FAIXA DE TOPO (em degrade) DAS PAGINAS
// =============================================================================

import 'package:material_ui/material_ui.dart';

// Paleta (cores), Tela (responsivo) e ContentWidth (centraliza conteudo).
import '../infraestrutura/theme.dart';

/// Faixa de topo das paginas principais, no degrade da marca.
///
/// Substitui a `AppBar` nas abas: titulo grande, um subtitulo, acoes a direita
/// e, opcionalmente, algo embaixo (a busca de eventos, por exemplo).
class CabecalhoPagina extends StatelessWidget {
  const CabecalhoPagina({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.acoes = const [],
    this.rodape,
  });

  /// Titulo grande.
  final String titulo;

  /// Linha menor abaixo do titulo (opcional).
  final String? subtitulo;

  /// Botoes a direita (ex.: `AcaoCabecalho`, `ContaBotao`).
  final List<Widget> acoes;

  /// Widget extra embaixo (ex.: campo de busca).
  final Widget? rodape;

  @override
  Widget build(BuildContext context) {
    // Estilos de texto do tema.
    final texto = Theme.of(context).textTheme;
    final tela = Tela.of(context);
    // No celular usa espacos e fontes menores.
    final compacto = tela.ehCelular;

    // Container largo com o degrade como fundo.
    return Container(
      // `double.infinity` = ocupar toda a largura disponivel.
      width: double.infinity,
      decoration: const BoxDecoration(gradient: Paleta.degradeProfundo),
      // Stack: empilha widgets uns sobre os outros (camadas). Aqui: bolhas
      // decorativas ao fundo e o conteudo por cima.
      child: Stack(
        children: [
          // Positioned: posiciona o filho em coordenadas dentro do Stack
          // (valores negativos deixam parte da bolha "vazar" para fora).
          Positioned(
            top: -60,
            right: -40,
            child: _Bolha(200, Paleta.turquesa.withValues(alpha: 0.16)),
          ),
          Positioned(
            bottom: -90,
            right: 180,
            child: _Bolha(160, Paleta.ciano.withValues(alpha: 0.08)),
          ),
          Padding(
            // `fromLTRB`: esquerda, topo, direita, base.
            padding: EdgeInsets.fromLTRB(
              0,
              compacto ? 16 : 36,
              0,
              compacto ? 20 : 28,
            ),
            // ContentWidth centraliza e limita a largura do conteudo.
            child: ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Aberta por cima de outra tela (e nao como aba): volta.
                      // `canPop()` = existe tela abaixo na pilha do Navigator?
                      // (`if` dentro de lista: item condicional.)
                      if (Navigator.of(context).canPop())
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: IconButton(
                            tooltip: 'Voltar',
                            // `maybePop` fecha a tela atual se for possivel.
                            onPressed: () => Navigator.of(context).maybePop(),
                            style: estiloBotaoCabecalho,
                            icon: const Icon(Icons.arrow_back),
                          ),
                        ),
                      // Expanded: titulo/subtitulo ocupam o espaco restante,
                      // deixando as acoes na ponta direita.
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titulo,
                              // Fonte menor no celular. `copyWith` copia o
                              // estilo trocando so a cor (branco).
                              style:
                                  (compacto
                                          ? texto.headlineSmall
                                          : texto.headlineMedium)
                                      ?.copyWith(color: Colors.white),
                            ),
                            // `...[ ]` (spread): espalha varios widgets dentro
                            // da lista; aqui so entram se houver subtitulo.
                            if (subtitulo != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                // `!` afirma nao-nulo (checado no `if`).
                                subtitulo!,
                                style: texto.bodyLarge?.copyWith(
                                  color: Paleta.ciano,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // No celular as acoes encolhem para o titulo ter espaco.
                      // Espalha cada botao de `acoes` na linha.
                      ...acoes,
                    ],
                  ),
                  // Rodape opcional, com espaco acima.
                  if (rodape != null) ...[const SizedBox(height: 20), rodape!],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botao redondo e claro, para acoes sobre o degrade escuro do cabecalho.
class AcaoCabecalho extends StatelessWidget {
  const AcaoCabecalho({
    super.key,
    required this.icone,
    required this.tooltip,
    required this.onPressed,
  });

  /// Icone do botao (ex.: `Icons.refresh`).
  final IconData icone;

  /// Texto que aparece ao passar o mouse (e leitores de tela).
  final String tooltip;

  /// `VoidCallback` = funcao sem parametros e sem retorno (`void Function()`).
  /// `null` desabilita o botao.
  final VoidCallback? onPressed;

  /// Aqui `build` usa `=>` direto: o corpo e uma unica expressao.
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: estiloBotaoCabecalho,
      icon: Icon(icone),
    ),
  );
}

/// Circulo decorativo do fundo do cabecalho (privado a este arquivo).
class _Bolha extends StatelessWidget {
  /// Parametros posicionais (sem nome): `_Bolha(200, cor)`.
  const _Bolha(this.tamanho, this.cor);

  final double tamanho;
  final Color cor;

  @override
  Widget build(BuildContext context) => Container(
    width: tamanho,
    height: tamanho,
    // `BoxShape.circle` transforma o quadrado em circulo.
    decoration: BoxDecoration(shape: BoxShape.circle, color: cor),
  );
}

/// Botao redondo sobre o degrade escuro: fundo e borda claros o bastante para
/// o botao nao se perder no fundo, e icone branco.
/// (Variavel global `final`, reutilizada pelos botoes do cabecalho.)
/// `IconButton.styleFrom` monta um estilo de botao: fundo, cor do icone e borda.
final ButtonStyle estiloBotaoCabecalho = IconButton.styleFrom(
  backgroundColor: Colors.white.withValues(alpha: 0.18),
  foregroundColor: Colors.white,
  side: BorderSide(color: Paleta.ciano.withValues(alpha: 0.5)),
);
