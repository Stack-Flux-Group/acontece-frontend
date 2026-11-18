// =============================================================================
// eventos_list_screen.dart - ABA "EVENTOS" (catalogo em grade)
// =============================================================================
//
// Mostra os eventos em uma grade de cartoes, com busca por titulo e filtro por
// periodo. O organizador tambem ve o botao de criar evento.
//
// Padrao central desta tela (repetido nas outras listas):
//   1. `_chave` junta filtros + `_versao`; muda => AsyncView recarrega sozinho.
//   2. Depois de criar/editar/excluir, `_versao++` forca nova busca.
//   3. As telas empilhadas devolvem `true` no `pop` quando "algo mudou".
// =============================================================================

import 'package:material_ui/material_ui.dart';

import '../../infraestrutura/api_dates.dart';
import '../../infraestrutura/area_selo.dart';
import '../../infraestrutura/formatters.dart';
import '../../infraestrutura/theme.dart';
import '../../modelos_da_api/auth.dart';
import '../../modelos_da_api/evento.dart';
import '../../services.dart';
import '../../componentes_visuais/async_view.dart';
import '../../componentes_visuais/cabecalho_pagina.dart';
import '../../componentes_visuais/evento_card.dart';
import '../home_shell.dart';
import 'evento_detail_screen.dart';
import 'evento_form_screen.dart';

/// Catalogo de eventos: busca por titulo, filtro por periodo e, para o
/// organizador, criacao.
///
/// Qualquer usuario logado pode ler `/eventos`; criar, editar e excluir e so
/// do organizador. O participante nem ve esses botoes.
class EventosListScreen extends StatefulWidget {
  const EventosListScreen({super.key, required this.usuario});

  /// Usuario logado (define o que a tela oferece).
  final UsuarioLogado usuario;

  @override
  State<EventosListScreen> createState() => _EventosListScreenState();
}

class _EventosListScreenState extends State<EventosListScreen> {
  /// CONCEITO - TextEditingController: guarda/controla o texto de um TextField
  /// (ler, limpar). Precisa ser liberado no `dispose`.
  final _buscaController = TextEditingController();

  /// Titulo buscado (vazio = sem filtro). Titulo e periodo se somam: a API
  /// aplica os dois ao mesmo tempo.
  String _titulo = '';

  /// Periodo escolhido (`DateTimeRange` = inicio + fim); nulo = sem filtro.
  DateTimeRange? _periodo;

  /// Incrementado depois de criar/editar/excluir para forcar nova busca.
  int _versao = 0;

  /// Atalho: o usuario e organizador?
  bool get _organizador => widget.usuario.ehOrganizador;

  /// Ha algum filtro aplicado?
  bool get _temFiltro => _titulo.isNotEmpty || _periodo != null;

  /// Muda sempre que o filtro ou a versao muda, fazendo o [AsyncView] recarregar.
  /// (`$x` e `${...}` interpolam valores dentro do texto; `?.` le o campo so se
  /// o periodo existir, senao vira "null" no texto.)
  /// Titulo e periodo entram juntos porque agora sao filtros que se somam.
  String get _chave => '$_titulo|${_periodo?.start}|${_periodo?.end}|$_versao';

  @override
  void dispose() {
    // Libera o controller para evitar vazamento de memoria.
    _buscaController.dispose();
    super.dispose();
  }

  /// Carrega a lista com os filtros ativos (`GET /eventos`).
  /// Chamada pelo AsyncView (`load: _carregar`). Aqui `Services.of(context)`
  /// funciona porque roda depois do primeiro build, nao em `initState`.
  ///
  /// Antes havia tres rotas (listar, por titulo, por periodo) e um `switch` para
  /// escolher uma. Agora e UMA chamada: os filtros vazios (`''` e `null`) sao
  /// simplesmente ignorados pelo repositorio, e os preenchidos se somam.
  /// `listarTodos` junta as paginas de 100 numa lista so.
  Future<List<Evento>> _carregar() => Services.of(context).eventos.listarTodos(
    titulo: _titulo,
    inicio: _periodo?.start,
    fim: _periodo?.end,
  );

  /// Aplica a busca por titulo (texto vazio tira o filtro). O periodo, se
  /// houver, continua valendo.
  void _buscarPorTitulo(String valor) {
    // `setState`: altera o estado e pede um novo `build`. Como `_chave` muda, o
    // AsyncView percebe e chama `_carregar` de novo sozinho.
    setState(() => _titulo = valor.trim());
  }

  /// Abre o seletor de intervalo de datas e aplica o filtro.
  Future<void> _escolherPeriodo() async {
    final agora = ApiDates.nowInSaoPaulo();
    // `showDateRangePicker` abre o calendario de intervalo; devolve null se o
    // usuario cancelar.
    final faixa = await showDateRangePicker(
      context: context,
      // Aceita datas de 5 anos atras ate 5 anos a frente.
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
    });
  }

  /// Limpa a busca e o periodo.
  void _limparFiltros() {
    setState(() {
      _titulo = '';
      _periodo = null;
      _buscaController.clear();
    });
  }

  /// Abre o formulario de novo evento; se foi criado (`true`), recarrega.
  Future<void> _criar() async {
    // CONCEITO - Navigator.push: empilha uma tela. `push<bool>` espera um
    // `bool` de volta quando a tela empilhada der `pop(valor)`.
    final criado = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const EventoFormScreen()));
    // `mounted`: depois de um `await` o widget pode ja ter saido da tela.
    if (criado == true && mounted) setState(() => _versao++);
  }

  /// Abre o detalhe do evento; se algo mudou la dentro, recarrega a lista.
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
        // Faixa de topo com titulo, acoes e a barra de busca no rodape.
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
            // So aparece no celular (menu com "Sair").
            ContaBotao(usuario: widget.usuario),
          ],
          rodape: _Filtros(
            controller: _buscaController,
            periodo: _periodo,
            onBuscar: _buscarPorTitulo,
            // `null` esconde o botao "Limpar filtros" quando nao ha filtro.
            onLimpar: _temFiltro ? _limparFiltros : null,
          ),
        ),
        // O resto da tela e a lista carregada pelo AsyncView.
        Expanded(
          child: AsyncView<List<Evento>>(
            reloadKey: _chave,
            load: _carregar,
            isEmpty: (eventos) => eventos.isEmpty,
            // Textos do estado vazio mudam conforme haja filtro/papel.
            emptyTitle: !_temFiltro
                ? 'Nenhum evento cadastrado'
                : 'Nenhum evento encontrado',
            emptyMessage: _temFiltro
                ? 'Ajuste a busca ou limpe os filtros.'
                : _organizador
                ? 'Crie o primeiro evento da plataforma.'
                : 'Volte em breve: novos eventos aparecem aqui.',
            emptyAction: _temFiltro
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
              // A API ordena por data de inicio; aqui, para o participante, os
              // eventos ainda abertos vem antes dos encerrados (isso so o
              // cliente sabe fazer, por isso a lista inteira e carregada).
              // `[...eventos]` copia a lista (spread) para poder ordenar sem
              // alterar a original; `..sort` (cascata) ordena e devolve a lista.
              final ordenados = [...eventos]
                ..sort((a, b) {
                  // Participante: encerrados vao para o fim.
                  if (!_organizador && a.encerrado != b.encerrado) {
                    return a.encerrado ? 1 : -1;
                  }
                  // Demais casos: mais cedo primeiro.
                  return a.dataInicio.compareTo(b.dataInicio);
                });

              // RefreshIndicator: "puxar para recarregar".
              return RefreshIndicator(
                onRefresh: recarregar,
                child: ListView(
                  // Folga embaixo para o FAB nao cobrir o ultimo cartao.
                  padding: folgaFinalDaLista(context, base: 96),
                  children: [
                    ContentWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          // Contador com singular/plural.
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
    // (FAB = FloatingActionButton, o botao redondo/flutuante de acao.)
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

/// Campo de busca + chips dos filtros ativos, mostrados no cabecalho.
class _Filtros extends StatelessWidget {
  const _Filtros({
    required this.controller,
    required this.periodo,
    required this.onBuscar,
    required this.onLimpar,
  });

  final TextEditingController controller;
  final DateTimeRange? periodo;

  /// Chamado com o texto digitado (Enter ou botao).
  final ValueChanged<String> onBuscar;

  /// `null` = nao ha filtro para limpar.
  final VoidCallback? onLimpar;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Limita a largura do campo de busca a 560 px.
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: TextField(
          controller: controller,
          // Tecla "Enter" do teclado vira "buscar".
          textInputAction: TextInputAction.search,
          onSubmitted: onBuscar,
          decoration: InputDecoration(
            hintText: 'Buscar por título',
            prefixIcon: const Icon(Icons.search),
            // Fundo branco para o campo se destacar do degrade escuro.
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              // Sem linha de borda: so o fundo branco arredondado.
              borderSide: BorderSide.none,
            ),
            // Botao redondo "->" dentro do campo.
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
      // So mostra a linha de chips se ha periodo ou algo a limpar.
      if (periodo != null || onLimpar != null) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (periodo != null)
              // Chip: etiqueta com icone e texto.
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

  /// Largura minima desejada por cartao e espaco entre eles.
  static const double _larguraMinima = 300;
  static const double _espaco = 20;

  @override
  // CONCEITO - LayoutBuilder: da acesso as RESTRICOES de tamanho do pai
  // (`c.maxWidth`), isto e, a largura que sobra ao conteudo (e nao a da janela,
  // pois a barra lateral ocupa 88/248 px).
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      // Quantas colunas cabem; `.floor()` arredonda para baixo; `.clamp(1, 4)`
      // limita entre 1 e 4.
      final colunas = ((c.maxWidth + _espaco) / (_larguraMinima + _espaco))
          .floor()
          .clamp(1, 4);
      // GridView.builder: grade que cria os itens sob demanda.
      return GridView.builder(
        // Dentro de um ListView: a grade nao rola sozinha.
        // `shrinkWrap` = ocupa so a altura necessaria.
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        // Numero FIXO de colunas e altura fixa por celula (nao usar
        // maxCrossAxisExtent; ver CLAUDE.md).
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
