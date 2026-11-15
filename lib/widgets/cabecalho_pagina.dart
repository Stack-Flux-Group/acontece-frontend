import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

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

  final String titulo;
  final String? subtitulo;
  final List<Widget> acoes;
  final Widget? rodape;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final tela = Tela.of(context);
    final compacto = tela.ehCelular;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: Paleta.degradeProfundo),
      child: Stack(
        children: [
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
            padding: EdgeInsets.fromLTRB(
              0,
              compacto ? 16 : 36,
              0,
              compacto ? 20 : 28,
            ),
            child: ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Aberta por cima de outra tela (e nao como aba): volta.
                      if (Navigator.of(context).canPop())
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: IconButton(
                            tooltip: 'Voltar',
                            onPressed: () => Navigator.of(context).maybePop(),
                            style: estiloBotaoCabecalho,
                            icon: const Icon(Icons.arrow_back),
                          ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titulo,
                              style:
                                  (compacto
                                          ? texto.headlineSmall
                                          : texto.headlineMedium)
                                      ?.copyWith(color: Colors.white),
                            ),
                            if (subtitulo != null) ...[
                              const SizedBox(height: 6),
                              Text(
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
                      ...acoes,
                    ],
                  ),
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

  final IconData icone;
  final String tooltip;
  final VoidCallback? onPressed;

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

class _Bolha extends StatelessWidget {
  const _Bolha(this.tamanho, this.cor);

  final double tamanho;
  final Color cor;

  @override
  Widget build(BuildContext context) => Container(
    width: tamanho,
    height: tamanho,
    decoration: BoxDecoration(shape: BoxShape.circle, color: cor),
  );
}

/// Botao redondo sobre o degrade escuro: fundo e borda claros o bastante para
/// o botao nao se perder no fundo, e icone branco.
final ButtonStyle estiloBotaoCabecalho = IconButton.styleFrom(
  backgroundColor: Colors.white.withValues(alpha: 0.18),
  foregroundColor: Colors.white,
  side: BorderSide(color: Paleta.ciano.withValues(alpha: 0.5)),
);
