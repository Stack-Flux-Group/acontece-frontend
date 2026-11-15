import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/api_config.dart';
import '../core/api_exception.dart';
import 'error_banner.dart';

/// Carrega algo da API e cuida dos tres estados chatos: carregando, erro e
/// vazio — para que nenhuma tela precise repetir isso.
///
/// Se a resposta passar de [ApiConfig.coldStartHint], aparece o aviso de que a
/// instancia gratuita do Render esta acordando. Sem isso, o primeiro acesso do
/// dia parece travamento: a chamada inicial medida levou 146 segundos.
class AsyncView<T> extends StatefulWidget {
  const AsyncView({
    super.key,
    required this.load,
    required this.builder,
    this.reloadKey,
    this.isEmpty,
    this.emptyTitle = 'Nada por aqui',
    this.emptyMessage,
    this.emptyAction,
  });

  /// Busca os dados. Trocada por completo a cada recarga.
  final Future<T> Function() load;

  /// Constroi a tela com os dados. `reload` refaz a busca.
  final Widget Function(BuildContext context, T data, Future<void> Function() reload)
  builder;

  /// Quando muda, recarrega. Serve para filtros: basta passar os filtros atuais.
  final Object? reloadKey;

  final bool Function(T data)? isEmpty;
  final String emptyTitle;
  final String? emptyMessage;
  final Widget? emptyAction;

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  T? _data;
  ApiException? _error;
  bool _carregando = true;
  bool _lento = false;
  Timer? _timerLento;

  /// Protege contra resposta de uma busca antiga chegando depois de uma nova
  /// (facil de acontecer quando o usuario digita num filtro).
  int _requisicao = 0;

  @override
  void initState() {
    super.initState();
    _buscar();
  }

  @override
  void didUpdateWidget(AsyncView<T> old) {
    super.didUpdateWidget(old);
    if (old.reloadKey != widget.reloadKey) _buscar();
  }

  @override
  void dispose() {
    _timerLento?.cancel();
    super.dispose();
  }

  Future<void> _buscar() async {
    final id = ++_requisicao;
    setState(() {
      _carregando = true;
      _error = null;
      _lento = false;
    });

    _timerLento?.cancel();
    _timerLento = Timer(ApiConfig.coldStartHint, () {
      if (mounted && _carregando) setState(() => _lento = true);
    });

    try {
      final resultado = await widget.load();
      if (!mounted || id != _requisicao) return;
      setState(() {
        _data = resultado;
        _carregando = false;
      });
    } on ApiException catch (e) {
      if (!mounted || id != _requisicao) return;
      setState(() {
        _error = e;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted || id != _requisicao) return;
      setState(() {
        _error = ApiException(message: e.toString());
        _carregando = false;
      });
    } finally {
      _timerLento?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) return _Carregando(lento: _lento);

    final erro = _error;
    if (erro != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topCenter,
          child: ErrorBanner(error: erro, onRetry: _buscar),
        ),
      );
    }

    final dados = _data as T;
    final vazio = widget.isEmpty?.call(dados) ?? false;
    if (vazio) {
      return EmptyState(
        titulo: widget.emptyTitle,
        mensagem: widget.emptyMessage,
        acao: widget.emptyAction,
        onRecarregar: _buscar,
      );
    }
    return widget.builder(context, dados, _buscar);
  }
}

class _Carregando extends StatelessWidget {
  const _Carregando({required this.lento});

  final bool lento;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (lento) ...[
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Text(
                    'Acordando o servidor...',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A API esta hospedada em uma instancia gratuita que hiberna '
                    'quando fica sem uso. O primeiro acesso pode levar alguns '
                    'minutos; os seguintes sao rapidos.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Estado vazio padrao, com recarga e uma acao opcional.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.titulo,
    this.mensagem,
    this.acao,
    this.onRecarregar,
    this.icone = Icons.inbox_outlined,
  });

  final String titulo;
  final String? mensagem;
  final Widget? acao;
  final VoidCallback? onRecarregar;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, size: 48, color: scheme.outline),
              const SizedBox(height: 16),
              Text(
                titulo,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (mensagem != null) ...[
                const SizedBox(height: 8),
                Text(
                  mensagem!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (acao != null) ...[const SizedBox(height: 20), acao!],
              if (onRecarregar != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onRecarregar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recarregar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
