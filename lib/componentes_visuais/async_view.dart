// =============================================================================
// async_view.dart - CARREGANDO / ERRO / VAZIO PADRONIZADOS
// =============================================================================
//
// Quase toda tela precisa: mostrar um "carregando", tratar erro com botao de
// tentar de novo e tratar lista vazia. `AsyncView` faz tudo isso uma vez so.
//
// Como usar (ideia): `AsyncView<List<Evento>>(load: repo.listar, builder: ...)`.
// O `builder` so e chamado quando ha dados.
// =============================================================================

// Traz `Timer` (cronometro usado para o aviso de servidor lento).
import 'dart:async';

import 'package:material_ui/material_ui.dart';

// `ApiConfig.coldStartHint`: quanto esperar antes de avisar que esta lento.
import '../infraestrutura/api_config.dart';
// ApiException: o tipo de erro guardado quando a carga falha.
import '../infraestrutura/api_exception.dart';
import 'error_banner.dart';

/// Carrega algo da API e cuida dos tres estados chatos: carregando, erro e
/// vazio — para que nenhuma tela precise repetir isso.
///
/// Se a resposta passar de [ApiConfig.coldStartHint], aparece o aviso de que a
/// instancia gratuita do Render esta acordando. Sem isso, o primeiro acesso do
/// dia parece travamento: a chamada inicial medida levou 146 segundos.
///
/// `<T>` = generico: o tipo dos dados carregados (ex.: `List<Evento>`).
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
  final Widget Function(
    BuildContext context,
    T data,
    Future<void> Function() reload,
  )
  builder;

  /// Quando muda, recarrega. Serve para filtros: basta passar os filtros atuais.
  /// (E o idioma do projeto: ver `_chave` em eventos_list_screen.dart.)
  final Object? reloadKey;

  /// Diz se os dados carregados contam como "vazio". Opcional.
  final bool Function(T data)? isEmpty;

  /// Textos/acao do estado vazio.
  final String emptyTitle;
  final String? emptyMessage;
  final Widget? emptyAction;

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  /// Ultimo resultado carregado com sucesso.
  T? _data;

  /// Ultimo erro (nulo se nao ha).
  ApiException? _error;

  /// `true` enquanto a requisicao esta em andamento.
  bool _carregando = true;

  /// `true` quando passou do tempo e vale mostrar "acordando o servidor".
  bool _lento = false;

  /// Cronometro do aviso de lentidao.
  Timer? _timerLento;

  /// Protege contra resposta de uma busca antiga chegando depois de uma nova
  /// (facil de acontecer quando o usuario digita num filtro).
  /// Cada busca incrementa o contador; so a ultima tem seu resultado aceito.
  int _requisicao = 0;

  /// CICLO DE VIDA - `initState`: roda UMA vez, quando o State e criado.
  /// Aqui ja dispara a primeira busca.
  @override
  void initState() {
    super.initState();
    _buscar();
  }

  /// CICLO DE VIDA - `didUpdateWidget`: roda quando o pai reconstroi este
  /// widget com novos parametros. Se o `reloadKey` mudou (ex.: filtro novo),
  /// busca de novo.
  @override
  void didUpdateWidget(AsyncView<T> old) {
    super.didUpdateWidget(old);
    if (old.reloadKey != widget.reloadKey) _buscar();
  }

  /// CICLO DE VIDA - `dispose`: roda quando o widget sai da tela para sempre.
  /// Cancela o cronometro para ele nao disparar depois (evita vazamento).
  @override
  void dispose() {
    _timerLento?.cancel();
    super.dispose();
  }

  /// Executa (ou refaz) a carga.
  Future<void> _buscar() async {
    // `++x` incrementa ANTES de usar: `id` identifica ESTA busca.
    final id = ++_requisicao;
    // Entra no estado "carregando" e limpa erro antigo.
    // `setState` avisa o Flutter para chamar `build` de novo com os novos
    // valores.
    setState(() {
      _carregando = true;
      _error = null;
      _lento = false;
    });

    // Reinicia o cronometro do aviso de servidor lento.
    _timerLento?.cancel();
    _timerLento = Timer(ApiConfig.coldStartHint, () {
      // `mounted`: o widget ainda esta na tela? So marca "lento" se sim e se
      // ainda estiver carregando.
      if (mounted && _carregando) setState(() => _lento = true);
    });

    try {
      // Espera a API responder.
      final resultado = await widget.load();
      // Widget saiu da tela OU ja existe busca mais nova: ignora este resultado.
      if (!mounted || id != _requisicao) return;
      setState(() {
        _data = resultado;
        _carregando = false;
      });
    } on ApiException catch (e) {
      // Erro conhecido da API/rede: guarda para exibir o ErrorBanner.
      if (!mounted || id != _requisicao) return;
      setState(() {
        _error = e;
        _carregando = false;
      });
    } catch (e) {
      // Qualquer outro erro inesperado (bug de parse, por exemplo).
      if (!mounted || id != _requisicao) return;
      setState(() {
        _error = ApiException(message: e.toString());
        _carregando = false;
      });
    } finally {
      // `finally` roda SEMPRE (sucesso, erro ou return antecipado).
      _timerLento?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Estado 1: carregando.
    if (_carregando) return _Carregando(lento: _lento);

    // Estado 2: erro (com botao de tentar de novo).
    final erro = _error;
    if (erro != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        // Align: posiciona o filho; aqui, no topo e centralizado.
        child: Align(
          alignment: Alignment.topCenter,
          child: ErrorBanner(error: erro, onRetry: _buscar),
        ),
      );
    }

    // Estado 3: sucesso. `_data as T` converte (T pode ser anulavel).
    final dados = _data as T;
    // `isEmpty?.call(dados) ?? false`: chama a funcao se existir; senao falso.
    final vazio = widget.isEmpty?.call(dados) ?? false;
    if (vazio) {
      return EmptyState(
        titulo: widget.emptyTitle,
        mensagem: widget.emptyMessage,
        acao: widget.emptyAction,
        onRecarregar: _buscar,
      );
    }
    // Estado 4: ha dados; a tela decide como mostra-los.
    return widget.builder(context, dados, _buscar);
  }
}

/// Indicador de carregamento (e aviso, se estiver demorando).
class _Carregando extends StatelessWidget {
  const _Carregando({required this.lento});

  final bool lento;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        // Centraliza verticalmente os itens da coluna.
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Circulo girando, na cor principal do tema.
          CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
          // So depois de 8 s aparece a explicacao sobre o servidor.
          // `...[ ]` (spread) espalha varios widgets dentro da lista.
          if (lento) ...[
            const SizedBox(height: 24),
            // Limita a largura do texto para leitura confortavel.
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
                    'O servidor é gratuito e hiberna quando fica sem uso. O '
                    'primeiro acesso pode levar até dois minutos; os seguintes '
                    'são rápidos.',
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

  /// Titulo (ex.: "Nenhum evento").
  final String titulo;

  /// Explicacao opcional.
  final String? mensagem;

  /// Widget de acao opcional (ex.: botao "Criar evento").
  final Widget? acao;

  /// Se informado, mostra o botao "Recarregar".
  final VoidCallback? onRecarregar;

  /// Icone grande no topo.
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
              // Circulo colorido com o icone dentro.
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  // `withValues(alpha: 0.55)` = 55% de opacidade.
                  color: scheme.primaryContainer.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: Icon(icone, size: 40, color: scheme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                titulo,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              // Mensagem so aparece se foi informada (`!` afirma nao-nulo).
              if (mensagem != null) ...[
                const SizedBox(height: 8),
                Text(
                  mensagem!,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
              if (acao != null) ...[const SizedBox(height: 20), acao!],
              // Botao "Recarregar" so aparece se ha o que chamar.
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
