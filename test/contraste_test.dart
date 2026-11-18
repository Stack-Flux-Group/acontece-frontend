// =============================================================================
// contraste_test.dart - TESTES DE ACESSIBILIDADE (contraste WCAG das cores)
// =============================================================================
//
// CONCEITO - contraste WCAG: razao entre a luminosidade de duas cores, de 1
// (iguais) a 21 (preto x branco). As diretrizes de acessibilidade pedem:
//   * texto comum          >= 4,5:1  (nivel AA)
//   * icones/bordas/UI     >= 3:1
//
// Estes testes leem os MESMOS pares de cores que as telas usam (tema e funcoes
// `coresStatusInscricao` / `coresEventoStatus`). Se alguem mudar uma cor e ela
// ficar ilegivel, o teste quebra.
// =============================================================================

import 'package:acontece_frontend/infraestrutura/theme.dart';
import 'package:acontece_frontend/modelos_da_api/evento.dart';
import 'package:acontece_frontend/modelos_da_api/status_inscricao.dart';
import 'package:acontece_frontend/componentes_visuais/status_chip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Contraste WCAG entre duas cores opacas (de 1 a 21).
///
/// Formula: (luminancia do mais claro + 0,05) / (luminancia do mais escuro +
/// 0,05). `computeLuminance()` devolve 0 (preto) a 1 (branco).
double contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  // Descobre qual das duas e a mais clara e qual e a mais escura.
  final claro = la > lb ? la : lb;
  final escuro = la > lb ? lb : la;
  return (claro + 0.05) / (escuro + 0.05);
}

/// Texto comum precisa de 4,5:1 (WCAG AA).
const _texto = 4.5;

/// Icones, bordas e elementos de interface precisam de 3:1.
const _ui = 3.0;

void main() {
  group('pares do tema (texto sobre fundo)', () {
    // Percorre os dois temas. `for (final (nome, tema) in [...])` usa a
    // "desestruturacao de record": cada item e um par (nome, tema).
    for (final (nome, tema) in [
      ('claro', AppTheme.light()),
      ('escuro', AppTheme.dark()),
    ]) {
      final s = tema.colorScheme;
      // Mapa "nome do par" -> (cor do texto, cor do fundo).
      final pares = <String, (Color, Color)>{
        'primary': (s.onPrimary, s.primary),
        'primaryContainer': (s.onPrimaryContainer, s.primaryContainer),
        'secondary': (s.onSecondary, s.secondary),
        'secondaryContainer': (s.onSecondaryContainer, s.secondaryContainer),
        'tertiary': (s.onTertiary, s.tertiary),
        'tertiaryContainer': (s.onTertiaryContainer, s.tertiaryContainer),
        'error': (s.onError, s.error),
        'errorContainer': (s.onErrorContainer, s.errorContainer),
        'surface': (s.onSurface, s.surface),
        'surface lowest': (s.onSurface, s.surfaceContainerLowest),
        'onSurfaceVariant sobre surface': (s.onSurfaceVariant, s.surface),
        'onSurfaceVariant sobre branco/lowest': (
          s.onSurfaceVariant,
          s.surfaceContainerLowest,
        ),
        'onSurfaceVariant sobre highest': (
          s.onSurfaceVariant,
          s.surfaceContainerHighest,
        ),
      };
      // Gera um `test` para cada par do mapa.
      pares.forEach((par, cores) {
        test('$nome: $par', () {
          expect(
            // `$1` e `$2` leem o 1o e o 2o valor do record (texto e fundo).
            contraste(cores.$1, cores.$2),
            // Matcher: valor >= minimo.
            greaterThanOrEqualTo(_texto),
            reason: '$par tem contraste ${contraste(cores.$1, cores.$2)}',
          );
        });
      });
    }
  });

  group('botoes desabilitados continuam legiveis', () {
    // O padrao do Material 3 (texto 38% sobre fundo 12%) da 2,3:1 nesta paleta.
    test('FilledButton', () {
      final tema = AppTheme.light();
      // `!` afirma que o estilo existe (o AppTheme o define).
      final estilo = tema.filledButtonTheme.style!;
      // Conjunto de estados "so desabilitado" para resolver a cor.
      const desabilitado = <WidgetState>{WidgetState.disabled};
      final fundo = estilo.backgroundColor!.resolve(desabilitado)!;
      final texto = estilo.foregroundColor!.resolve(desabilitado)!;
      expect(contraste(texto, fundo), greaterThanOrEqualTo(_texto));
    });

    test('OutlinedButton e TextButton sobre a superficie', () {
      final tema = AppTheme.light();
      const desabilitado = <WidgetState>{WidgetState.disabled};
      // Repete a mesma conferencia para os dois estilos.
      for (final estilo in [
        tema.outlinedButtonTheme.style!,
        tema.textButtonTheme.style!,
      ]) {
        final texto = estilo.foregroundColor!.resolve(desabilitado)!;
        expect(
          contraste(texto, tema.colorScheme.surface),
          greaterThanOrEqualTo(_texto),
        );
      }
    });
  });

  group('selos', () {
    final claro = AppTheme.light().colorScheme;

    // Cobre todas as combinacoes: cada status x (fundo claro | fundo escuro).
    for (final status in StatusInscricao.values) {
      for (final escuro in [false, true]) {
        test('inscricao ${status.rotulo} (sobreEscuro: $escuro)', () {
          // O `_` ignora o 3o valor do record (o icone).
          final (fundo, texto, _) = coresStatusInscricao(
            status,
            claro,
            sobreEscuro: escuro,
          );
          expect(contraste(texto, fundo), greaterThanOrEqualTo(_texto));
          // Opaco: um fundo translucido muda de tom conforme o que esta atras.
          // (`.a` e o canal alfa: 1.0 = totalmente opaco.)
          expect(fundo.a, 1.0);

          // Sobre o painel escuro, o selo nao pode se confundir com o fundo
          // (o "Confirmada" azul sobre o degrade azul tinha contraste 1:1).
          if (escuro) {
            for (final painel in [
              Paleta.marinho,
              Paleta.petroleo,
              Paleta.azul,
            ]) {
              expect(
                contraste(fundo, painel),
                greaterThanOrEqualTo(_ui),
                reason: 'selo ${status.rotulo} some sobre $painel',
              );
            }
          }
        });
      }
    }

    // Mesma ideia para os selos de situacao do evento.
    for (final status in EventoStatus.values) {
      for (final sobreFoto in [false, true]) {
        test('evento ${status.rotulo} (sobreFoto: $sobreFoto)', () {
          final (fundo, texto, _) = coresEventoStatus(
            status,
            claro,
            sobreFoto: sobreFoto,
          );
          expect(contraste(texto, fundo), greaterThanOrEqualTo(_texto));
          expect(fundo.a, 1.0);
        });
      }
    }
  });

  group('textos sobre os degrades escuros', () {
    // Mapa nome -> cor, usado para gerar um teste por fundo.
    final fundos = {
      'marinho': Paleta.marinho,
      'petroleo': Paleta.petroleo,
      'azul': Paleta.azul,
    };

    fundos.forEach((nome, fundo) {
      test('branco sobre $nome', () {
        expect(contraste(Colors.white, fundo), greaterThanOrEqualTo(_texto));
      });
      test('ciano sobre $nome', () {
        expect(contraste(Paleta.ciano, fundo), greaterThanOrEqualTo(_texto));
      });
    });

    test('rotulo da barra lateral (ciano 80% sobre marinho)', () {
      // `alphaBlend` simula a cor resultante de uma cor translucida sobre outra.
      final rotulo = Color.alphaBlend(
        Paleta.ciano.withValues(alpha: 0.8),
        Paleta.marinho,
      );
      expect(contraste(rotulo, Paleta.marinho), greaterThanOrEqualTo(_texto));
    });

    test('rodape do login (branco 75% sobre petroleo)', () {
      final rodape = Color.alphaBlend(
        Colors.white.withValues(alpha: 0.75),
        Paleta.petroleo,
      );
      expect(contraste(rodape, Paleta.petroleo), greaterThanOrEqualTo(_texto));
    });
  });

  group('elementos de interface', () {
    test('botao do cabecalho: icone branco sobre fundo claro 18%', () {
      for (final base in [Paleta.marinho, Paleta.petroleo, Paleta.azul]) {
        // Fundo real do botao = branco 18% misturado com o degrade atras.
        final fundo = Color.alphaBlend(
          Colors.white.withValues(alpha: 0.18),
          base,
        );
        expect(contraste(Colors.white, fundo), greaterThanOrEqualTo(_ui));
      }
    });

    test('barra de ocupacao: cor primaria sobre o trilho', () {
      final s = AppTheme.light().colorScheme;
      expect(
        contraste(s.primary, s.surfaceContainerHighest),
        greaterThanOrEqualTo(_ui),
      );
    });

    test('botao voltar da capa: icone branco sobre marinho 60%', () {
      // Pior caso: foto branca atras do botao.
      final fundo = Color.alphaBlend(
        Paleta.marinho.withValues(alpha: 0.6),
        Colors.white,
      );
      expect(contraste(Colors.white, fundo), greaterThanOrEqualTo(_ui));
    });

    test('chip de filtro: texto sobre o fundo solido, selecionado ou nao', () {
      // Nao selecionado: branco sobre petroleo. Selecionado: marinho sobre ciano.
      expect(
        contraste(Colors.white, Paleta.petroleo),
        greaterThanOrEqualTo(_texto),
      );
      expect(
        contraste(Paleta.marinho, Paleta.ciano),
        greaterThanOrEqualTo(_texto),
      );
    });

    test('chip de filtro nao selecionado se destaca do degrade (borda)', () {
      // O fundo petroleo quase se confunde com o degrade; a borda ciano e que
      // desenha o chip.
      const borda = Paleta.ciano;
      for (final base in [Paleta.marinho, Paleta.petroleo, Paleta.azul]) {
        expect(contraste(borda, base), greaterThanOrEqualTo(_ui));
      }
    });
  });
}
