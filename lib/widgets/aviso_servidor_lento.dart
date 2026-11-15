import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/api_config.dart';

/// Aparece quando uma acao (entrar, criar conta) passa de
/// [ApiConfig.coldStartHint] esperando a API.
///
/// A instancia gratuita do Render hiberna e leva ~2,5 minutos para acordar.
/// Sem este aviso o botao fica girando sem explicacao e parece travado.
class AvisoServidorLento extends StatefulWidget {
  const AvisoServidorLento({super.key, required this.ativo});

  /// `true` enquanto a requisicao esta em andamento.
  final bool ativo;

  @override
  State<AvisoServidorLento> createState() => _AvisoServidorLentoState();
}

class _AvisoServidorLentoState extends State<AvisoServidorLento> {
  Timer? _timer;
  bool _lento = false;

  @override
  void initState() {
    super.initState();
    if (widget.ativo) _iniciar();
  }

  @override
  void didUpdateWidget(AvisoServidorLento old) {
    super.didUpdateWidget(old);
    if (widget.ativo && !old.ativo) _iniciar();
    if (!widget.ativo && old.ativo) {
      _timer?.cancel();
      _lento = false;
    }
  }

  void _iniciar() {
    _timer?.cancel();
    _lento = false;
    _timer = Timer(ApiConfig.coldStartHint, () {
      if (mounted && widget.ativo) setState(() => _lento = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_lento) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.hourglass_top,
              size: 18,
              color: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 10),
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
