import 'package:material_ui/material_ui.dart';

import '../../core/api_dates.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/auth.dart';
import '../../models/evento.dart';
import '../../services.dart';
import '../../widgets/async_view.dart';
import '../../widgets/cabecalho_pagina.dart';
import '../../widgets/evento_card.dart';
import '../home_shell.dart';
import 'evento_detail_screen.dart';
import 'evento_form_screen.dart';

/// Catalogo de eventos: busca por titulo, filtro por periodo e, para o
/// organizador, criacao.
///
/// Qualquer usuario logado pode ler `/evento/**`; criar, editar e excluir e so
/// do organizador. O participante nem ve esses botoes.
class EventosListScreen extends StatefulWidget {
  const EventosListScreen({super.key, required this.usuario});

  final UsuarioLogado usuario;

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

  bool get _organizador => widget.usuario.ehOrganizador;

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
      helpText: 'Eventos que começam no período',
    );
    if (faixa == null) return;
    setState(() {
      // A API compara `dataInicio` com os limites, inclusive nas pontas. Esticar
      // o fim ate 23:59:59 faz o ultimo dia escolhido entrar inteiro.
      _periodo = DateTimeRange(
        start: DateTime(faixa.start.year, faixa.start.month, faixa.start.day),
        end: DateTime(
          faixa.end.year,
          faixa.end.month,
          faixa.end.day,
          23,
          59,
          59,
        ),
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
      MaterialPageRoute(
        builder: (_) =>
            EventoDetailScreen(eventoId: evento.id, usuario: widget.usuario),
      ),
    );
    if (mudou == true && mounted) setState(() => _versao++);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        CabecalhoPagina(
          titulo: _organizador ? 'Eventos' : 'Descubra eventos',
          subtitulo: _organizador
              ? 'Crie, edite e acompanhe a agenda da plataforma.'
              : 'Encontre algo para fazer e garanta sua vaga.',
          acoes: [
            AcaoCabecalho(
              icone: Icons.date_range,
              tooltip: 'Filtrar por período',
              onPressed: _escolherPeriodo,
            ),
            ContaBotao(usuario: widget.usuario),
          ],
          rodape: _Filtros(
            controller: _buscaController,
            periodo: _periodo,
            onBuscar: _buscarPorTitulo,
            onLimpar: _modo == _Modo.todos ? null : _limparFiltros,
          ),
        ),
        Expanded(
          child: AsyncView<List<Evento>>(
            reloadKey: _chave,
            load: _carregar,
            isEmpty: (eventos) => eventos.isEmpty,
            emptyTitle: _modo == _Modo.todos
                ? 'Nenhum evento cadastrado'
                : 'Nenhum evento encontrado',
            emptyMessage: _modo != _Modo.todos
                ? 'Ajuste a busca ou limpe os filtros.'
                : _organizador
                ? 'Crie o primeiro evento da plataforma.'
                : 'Volte em breve: novos eventos aparecem aqui.',
            emptyAction: _modo != _Modo.todos
                ? TextButton.icon(
                    onPressed: _limparFiltros,
                    icon: const Icon(Icons.close),
                    label: const Text('Limpar filtros'),
                  )
                : _organizador
                ? FilledButton.icon(
                    onPressed: _criar,
                    icon: const Icon(Icons.add),
                    label: const Text('Novo evento'),
                  )
                : null,
            builder: (context, eventos, recarregar) {
              // `GET /evento/listar/` devolve a tabela na ordem do banco;
              // ordenar aqui deixa a lista previsivel. Para o participante, os
              // eventos ainda abertos vem antes dos encerrados.
              final ordenados = [...eventos]
                ..sort((a, b) {
                  if (!_organizador && a.encerrado != b.encerrado) {
                    return a.encerrado ? 1 : -1;
                  }
                  return a.dataInicio.compareTo(b.dataInicio);
                });

              return RefreshIndicator(
                onRefresh: recarregar,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    ContentWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          Text(
                            ordenados.length == 1
                                ? '1 evento'
                                : '${ordenados.length} eventos',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 14),
                          _Grade(eventos: ordenados, onAbrir: _abrir),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
    // As abas vivem ao mesmo tempo dentro de um IndexedStack, entao os FABs
    // coexistem. Sem uma heroTag propria em cada um, o Hero reclama de tag
    // duplicada e a navegacao quebra.
    floatingActionButton: _organizador
        ? FloatingActionButton.extended(
            heroTag: 'fab-eventos',
            onPressed: _criar,
            icon: const Icon(Icons.add),
            label: const Text('Novo evento'),
          )
        : null,
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
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          onSubmitted: onBuscar,
          decoration: InputDecoration(
            hintText: 'Buscar por título',
            prefixIcon: const Icon(Icons.search),
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            suffixIcon: Padding(
              padding: const EdgeInsets.all(6),
              child: IconButton.filled(
                tooltip: 'Buscar',
                // Cores explicitas: o icone precisa contrastar com o circulo.
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.arrow_forward),
                onPressed: () => onBuscar(controller.text),
              ),
            ),
          ),
        ),
      ),
      if (periodo != null || onLimpar != null) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (periodo != null)
              Chip(
                backgroundColor: Paleta.ciano,
                side: BorderSide.none,
                avatar: const Icon(
                  Icons.date_range,
                  size: 16,
                  color: Paleta.marinho,
                ),
                label: Text(
                  'Começa entre ${Fmt.data(periodo!.start)} e '
                  '${Fmt.data(periodo!.end)}',
                  style: const TextStyle(color: Paleta.marinho),
                ),
              ),
            if (onLimpar != null)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
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

/// Grade responsiva de cartoes, todos com a mesma largura e a mesma altura.
///
/// O numero de colunas sai da largura disponivel, com no minimo
/// [_larguraMinima] por cartao: 1 coluna no celular, 2 no tablet e no notebook
/// com a barra lateral aberta, 3 e 4 em tela larga. A altura vem de
/// [EventoCard.altura], e nao do conteudo.
class _Grade extends StatelessWidget {
  const _Grade({required this.eventos, required this.onAbrir});

  final List<Evento> eventos;
  final ValueChanged<Evento> onAbrir;

  static const double _larguraMinima = 300;
  static const double _espaco = 20;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final colunas = ((c.maxWidth + _espaco) / (_larguraMinima + _espaco))
          .floor()
          .clamp(1, 4);
      return GridView.builder(
        // Dentro de um ListView: a grade nao rola sozinha.
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: colunas,
          mainAxisExtent: EventoCard.altura(context),
          crossAxisSpacing: _espaco,
          mainAxisSpacing: _espaco,
        ),
        itemCount: eventos.length,
        itemBuilder: (context, i) =>
            EventoCard(evento: eventos[i], onTap: () => onAbrir(eventos[i])),
      );
    },
  );
}
