// =============================================================================
// aviso_servidor_lento.dart - AVISO DE "ACORDANDO O SERVIDOR"
// =============================================================================
//
// O servidor gratuito (Render) hiberna e demora ~2,5 min no primeiro acesso.
// Este widget so aparece depois de alguns segundos de espera, para o usuario
// nao achar que o app travou.
// =============================================================================

// Timer (contagem de tempo).
import 'dart:async';

import 'package:material_ui/material_ui.dart';

// `ApiConfig.coldStartHint`: quantos segundos esperar antes de avisar.
import '../core/api_config.dart';

/// Aparece quando uma acao (entrar, criar conta) passa de
/// [ApiConfig.coldStartHint] esperando a API.
///
/// A instancia gratuita do Render hiberna e leva ~2,5 minutos para acordar.
/// Sem este aviso o botao fica girando sem explicacao e parece travado.
///
/// E um StatefulWidget porque precisa lembrar se ja passou tempo demais
/// (`_lento`) e guardar o `Timer`.
class AvisoServidorLento extends StatefulWidget {
  const AvisoServidorLento({super.key, required this.ativo});

  /// `true` enquanto a requisicao esta em andamento.
  final bool ativo;

  @override
  State<AvisoServidorLento> createState() => _AvisoServidorLentoState();
}

class _AvisoServidorLentoState extends State<AvisoServidorLento> {
  /// Cronometro em andamento (nulo se nao ha).
  Timer? _timer;

  /// `true` quando ja passou do tempo e o aviso deve aparecer.
  bool _lento = false;

  /// CICLO DE VIDA - `initState`: roda UMA vez, quando o State e criado.
  @override
  void initState() {
    // Sempre chamar o `super` primeiro em initState.
    super.initState();
    // `widget` e o StatefulWidget associado (da acesso a `ativo`).
    if (widget.ativo) _iniciar();
  }

  /// CICLO DE VIDA - `didUpdateWidget`: roda quando o pai reconstroi este
  /// widget com novos parametros. `old` e a versao anterior.
  @override
  void didUpdateWidget(AvisoServidorLento old) {
    super.didUpdateWidget(old);
    // Passou de inativo para ativo: comeca a contar.
    if (widget.ativo && !old.ativo) _iniciar();
    // Passou de ativo para inativo: para e esconde o aviso.
    if (!widget.ativo && old.ativo) {
      _timer?.cancel();
      _lento = false;
    }
  }

  /// Reinicia a contagem de 8 s.
  void _iniciar() {
    // Cancela qualquer contagem anterior e zera o aviso.
    _timer?.cancel();
    _lento = false;
    // `Timer` executa a funcao depois do tempo informado.
    _timer = Timer(ApiConfig.coldStartHint, () {
      // `mounted`: o widget ainda esta na tela? (evita setState depois de
      // descartado.) `setState` avisa o Flutter para chamar `build` de novo.
      if (mounted && widget.ativo) setState(() => _lento = true);
    });
  }

  /// CICLO DE VIDA - `dispose`: roda quando o widget sai da tela para sempre.
  /// Aqui se liberam recursos (cancelar o Timer evita vazamento).
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ainda nao e hora de avisar: devolve um widget vazio (tamanho zero).
    if (!_lento) return const SizedBox.shrink();
    // Cores do tema atual.
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      // Espaco so em cima (afasta do botao).
      padding: const EdgeInsets.only(top: 14),
      // Container: caixa com padding e decoracao (cor + cantos).
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        // Row: icone e texto lado a lado.
        child: Row(
          children: [
            Icon(
              Icons.hourglass_top,
              size: 18,
              color: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 10),
            // Expanded: o texto ocupa o resto da linha e quebra se precisar.
            Expanded(
              child: Text(
                'Acordando o servidor... O primeiro acesso pode levar até '
                'dois minutos e meio; os seguintes são rápidos.',
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
