import 'package:material_ui/material_ui.dart';

import '../../core/api_dates.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/evento.dart';
import '../../services.dart';
import '../../widgets/async_view.dart';
import '../../widgets/evento_card.dart';
import 'evento_detail_screen.dart';
import 'evento_form_screen.dart';

/// Catalogo de eventos: busca por titulo, filtro por periodo e criacao.
class EventosListScreen extends StatefulWidget {
  const EventosListScreen({super.key});

  @override
  State<EventosListScreen> createState() => _EventosListScreenState();
}

/// Qual rota da API alimenta a lista.
///
/// A API tem tres rotas de leitura separadas (listar, buscar por titulo, buscar
/// por periodo) em vez de uma com filtros opcionais, entao o modo escolhido
/// decide qual delas e chamada.
enum _Modo { todos, titulo, periodo }

class _EventosListScreenState extends State<EventosListScreen> {
  final _buscaController = TextEditingController();

  _Modo _modo = _Modo.todos;
  String _titulo = '';
  DateTimeRange? _periodo;

  /// Incrementado depois de criar/editar/excluir para forcar nova busca.
  int _versao = 0;

  /// Muda sempre que o filtro ou a versao muda, fazendo o [AsyncView] recarregar.
  String get _chave =>
      '${_modo.name}|$_titulo|${_periodo?.start}|${_periodo?.end}|$_versao';

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<List<Evento>> _carregar() {
    final repo = Services.of(context).eventos;
    return switch (_modo) {
      _Modo.todos => repo.listar(),
      _Modo.titulo => repo.buscarPorTitulo(_titulo),
      _Modo.periodo => repo.buscarPorPeriodo(
        inicio: _periodo!.start,
        fim: _periodo!.end,
      ),
    };
  }

  void _buscarPorTitulo(String valor) {
    final texto = valor.trim();
    setState(() {
      _titulo = texto;
      _modo = texto.isEmpty ? _Modo.todos : _Modo.titulo;
      _periodo = null;
    });
  }

  Future<void> _escolherPeriodo() async {
    final agora = ApiDates.nowInSaoPaulo();
    final faixa = await showDateRangePicker(
      context: context,
      firstDate: DateTime(agora.year - 5),
      lastDate: DateTime(agora.year + 5),
      initialDateRange: _periodo,
      helpText: 'Eventos que comecam no periodo',
    );
    if (faixa == null) return;
    setState(() {
      // A API compara `dataInicio` com os limites, inclusive nas pontas. Esticar
      // o fim ate 23:59:59 faz o ultimo dia escolhido entrar inteiro.
      _periodo = DateTimeRange(
        start: DateTime(faixa.start.year, faixa.start.month, faixa.start.day),
        end: DateTime(faixa.end.year, faixa.end.month, faixa.end.day, 23, 59, 59),
      );
      _modo = _Modo.periodo;
      _titulo = '';
      _buscaController.clear();
    });
  }

  void _limparFiltros() {
    setState(() {
      _modo = _Modo.todos;
      _titulo = '';
      _periodo = null;
      _buscaController.clear();
    });
  }

  Future<void> _criar() async {
    final criado = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const EventoFormScreen()));
    if (criado == true && mounted) setState(() => _versao++);
  }

  Future<void> _abrir(Evento evento) async {
    final mudou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EventoDetailScreen(eventoId: evento.id)),
    );
    if (mudou == true && mounted) setState(() => _versao++);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Eventos'),
      actions: [
        IconButton(
          onPressed: _escolherPeriodo,
          icon: const Icon(Icons.date_range),
          tooltip: 'Filtrar por periodo',
        ),
        const SizedBox(width: 4),
      ],
    ),
    body: AsyncView<List<Evento>>(
      reloadKey: _chave,
      load: _carregar,
      isEmpty: (eventos) => eventos.isEmpty,
      emptyTitle: _modo == _Modo.todos
          ? 'Nenhum evento cadastrado'
          : 'Nenhum evento encontrado',
      emptyMessage: _modo == _Modo.todos
          ? 'Crie o primeiro evento da plataforma.'
          : 'Ajuste a busca ou limpe os filtros.',
      emptyAction: _modo == _Modo.todos
          ? FilledButton.icon(
              onPressed: _criar,
              icon: const Icon(Icons.add),
              label: const Text('Novo evento'),
            )
          : TextButton.icon(
              onPressed: _limparFiltros,
              icon: const Icon(Icons.close),
              label: const Text('Limpar filtros'),
            ),
      builder: (context, eventos, recarregar) {
        // `GET /evento/listar/` devolve a tabela na ordem do banco; ordenar aqui
        // deixa a lista previsivel. A busca por periodo ja vem ordenada pela API.
        final ordenados = [...eventos]
          ..sort((a, b) => a.dataInicio.compareTo(b.dataInicio));

        return RefreshIndicator(
          onRefresh: recarregar,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _Filtros(
                      controller: _buscaController,
                      periodo: _periodo,
                      onBuscar: _buscarPorTitulo,
                      onLimpar: _modo == _Modo.todos ? null : _limparFiltros,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      ordenados.length == 1
                          ? '1 evento'
                          : '${ordenados.length} eventos',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Grade(eventos: ordenados, onAbrir: _abrir),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
    // As tres abas vivem ao mesmo tempo dentro de um IndexedStack, entao os
    // FABs coexistem. Sem uma heroTag propria em cada um, o Hero reclama de tag
    // duplicada e a navegacao quebra.
    floatingActionButton: FloatingActionButton.extended(
      heroTag: 'fab-eventos',
      onPressed: _criar,
      icon: const Icon(Icons.add),
      label: const Text('Novo evento'),
    ),
  );
}

class _Filtros extends StatelessWidget {
  const _Filtros({
    required this.controller,
    required this.periodo,
    required this.onBuscar,
    required this.onLimpar,
  });

  final TextEditingController controller;
  final DateTimeRange? periodo;
  final ValueChanged<String> onBuscar;
  final VoidCallback? onLimpar;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: onBuscar,
        decoration: InputDecoration(
          hintText: 'Buscar por titulo',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            tooltip: 'Buscar',
            icon: const Icon(Icons.arrow_forward),
            onPressed: () => onBuscar(controller.text),
          ),
        ),
      ),
      if (periodo != null || onLimpar != null) ...[
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (periodo != null)
              Chip(
                avatar: const Icon(Icons.date_range, size: 16),
                label: Text(
                  'Comeca entre ${Fmt.data(periodo!.start)} e '
                  '${Fmt.data(periodo!.end)}',
                ),
              ),
            if (onLimpar != null)
              TextButton.icon(
                onPressed: onLimpar,
                icon: const Icon(Icons.close),
                label: const Text('Limpar filtros'),
              ),
          ],
        ),
      ],
    ],
  );
}

/// Grade responsiva de cartoes.
class _Grade extends StatelessWidget {
  const _Grade({required this.eventos, required this.onAbrir});

  final List<Evento> eventos;
  final ValueChanged<Evento> onAbrir;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final colunas = constraints.maxWidth > 820
          ? 3
          : constraints.maxWidth > 540
          ? 2
          : 1;
      const espaco = 16.0;
      final largura = (constraints.maxWidth - espaco * (colunas - 1)) / colunas;

      return Wrap(
        spacing: espaco,
        runSpacing: espaco,
        children: [
          for (final evento in eventos)
            SizedBox(
              width: largura,
              child: EventoCard(evento: evento, onTap: () => onAbrir(evento)),
            ),
        ],
      );
    },
  );
}
