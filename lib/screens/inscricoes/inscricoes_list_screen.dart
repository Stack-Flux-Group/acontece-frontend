// =============================================================================
// inscricoes_list_screen.dart - ABA DE INSCRICOES (organizador e participante)
// =============================================================================
//
// A MESMA tela serve aos dois papeis, mudando o comportamento:
//   * organizador  -> ve todas, filtra (evento/participante/status) e muda status
//   * participante -> "Minhas inscricoes" (a API ja filtra pelo token), so le
//
// Tambem e aberta a partir do detalhe do evento (`eventoInicial` pre-filtra).
// =============================================================================

import 'package:material_ui/material_ui.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/auth.dart';
import '../../models/evento.dart';
import '../../models/inscricao.dart';
import '../../models/paged_model.dart';
import '../../models/participante.dart';
import '../../models/status_inscricao.dart';
import '../../services.dart';
import '../../widgets/async_view.dart';
import '../../widgets/cabecalho_pagina.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/pickers.dart';
import '../../widgets/status_chip.dart';
import '../eventos/evento_detail_screen.dart';
import '../home_shell.dart';

/// Inscricoes, em dois modos conforme o papel:
///
///  * organizador: todas as inscricoes, com filtros por evento, participante e
///    status, e a mudanca de status respeitando a maquina de estados da API
///  * participante: "Minhas inscricoes". A API ja devolve so as dele, e ele nao
///    pode mudar status (o PATCH e exclusivo do organizador)
///
/// Nao ha "nova inscricao" aqui: o participante se inscreve pelo detalhe do
/// evento, e o organizador nao pode criar inscricao (o POST e so de
/// participante, sempre em nome proprio).
class InscricoesListScreen extends StatefulWidget {
  const InscricoesListScreen({
    super.key,
    required this.usuario,
    this.eventoInicial,
  });

  final UsuarioLogado usuario;

  /// Pre-filtra por evento, quando a tela e aberta a partir do detalhe dele.
  final Evento? eventoInicial;

  @override
  State<InscricoesListScreen> createState() => _InscricoesListScreenState();
}

class _InscricoesListScreenState extends State<InscricoesListScreen> {
  // Filtros atuais (nulo = filtro nao aplicado).
  Evento? _evento;
  Participante? _participante;
  StatusInscricao? _status;

  /// Pagina atual (base zero) e contador de recarga.
  int _pagina = 0;
  int _versao = 0;

  bool get _organizador => widget.usuario.ehOrganizador;

  /// Muda quando QUALQUER filtro/pagina/versao muda => AsyncView recarrega.
  /// (`_evento?.id`: se `_evento` for nulo, vira "null" no texto.)
  String get _chave =>
      '${_evento?.id}|${_participante?.id}|${_status?.wire}|$_pagina|$_versao';

  /// Ha algum filtro aplicado?
  bool get _temFiltro =>
      _evento != null || _participante != null || _status != null;

  @override
  void initState() {
    super.initState();
    // Se veio do detalhe de um evento, ja comeca filtrado por ele.
    _evento = widget.eventoInicial;
  }

  /// Busca a pagina atual com os filtros ativos.
  Future<PagedModel<Inscricao>> _carregar() =>
      Services.of(context).inscricoes.listar(
        eventoId: _evento?.id,
        // Para o participante a API ignora este filtro e usa o id do token.
        participanteId: _organizador ? _participante?.id : null,
        status: _status,
        page: _pagina,
      );

  /// Remove todos os filtros e volta a primeira pagina.
  void _limparFiltros() => setState(() {
    _evento = null;
    _participante = null;
    _status = null;
    _pagina = 0;
  });

  /// Muda o status (so organizador). Cancelar pede confirmacao (irreversivel).
  Future<void> _mudarStatus(Inscricao inscricao, StatusInscricao novo) async {
    if (novo == StatusInscricao.cancelada) {
      final ok = await confirmar(
        context,
        titulo: 'Cancelar inscrição?',
        mensagem:
            'A inscrição de ${inscricao.participanteNome} em '
            '"${inscricao.eventoTitulo}" será cancelada e a vaga, liberada. '
            'Cancelamento não pode ser desfeito.',
        rotuloConfirmar: 'Cancelar inscrição',
      );
      if (!ok || !mounted) return;
    }
    try {
      await Services.of(context).inscricoes.atualizarStatus(inscricao.id, novo);
      if (!mounted) return;
      mostrarSucesso(context, 'Inscrição ${novo.rotulo.toLowerCase()}.');
      // Recarrega a lista para refletir o novo status.
      setState(() => _versao++);
    } on ApiException catch (e) {
      if (!mounted) return;
      mostrarErro(context, e);
    }
  }

  /// Abre o detalhe do evento da inscricao; ao voltar, recarrega (o status ou
  /// a ocupacao podem ter mudado).
  Future<void> _abrirEvento(Inscricao inscricao) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventoDetailScreen(
          eventoId: inscricao.eventoId,
          usuario: widget.usuario,
        ),
      ),
    );
    if (mounted) setState(() => _versao++);
  }

  /// Abre o dialogo de escolha de evento e aplica como filtro.
  Future<void> _filtrarPorEvento() async {
    final evento = await escolherEvento(context, Services.of(context).eventos);
    if (evento != null && mounted) {
      setState(() {
        _evento = evento;
        _pagina = 0;
      });
    }
  }

  /// Abre o dialogo de escolha de participante e aplica como filtro.
  Future<void> _filtrarPorParticipante() async {
    final participante = await escolherParticipante(
      context,
      Services.of(context).participantes,
    );
    if (participante != null && mounted) {
      setState(() {
        _participante = participante;
        _pagina = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Textos mudam conforme o papel.
    final titulo = _organizador ? 'Inscrições' : 'Minhas inscrições';
    final subtitulo = _organizador
        ? 'Confirme ou cancele as inscrições dos participantes.'
        : 'Acompanhe o status das suas inscrições.';

    return Scaffold(
      body: Column(
        children: [
          CabecalhoPagina(
            titulo: titulo,
            subtitulo: subtitulo,
            acoes: [
              AcaoCabecalho(
                icone: Icons.event,
                tooltip: 'Filtrar por evento',
                onPressed: _filtrarPorEvento,
              ),
              // Filtro por participante: so o organizador (a rota exige).
              if (_organizador)
                AcaoCabecalho(
                  icone: Icons.person_search,
                  tooltip: 'Filtrar por participante',
                  onPressed: _filtrarPorParticipante,
                ),
              // Quando aberta por cima do detalhe, ja ha botao "Voltar"; o
              // botao de conta fica so quando a tela e uma aba.
              if (widget.eventoInicial == null)
                ContaBotao(usuario: widget.usuario),
            ],
            rodape: _Filtros(
              evento: _evento,
              participante: _participante,
              status: _status,
              // Trocar o status volta para a primeira pagina.
              onStatus: (valor) => setState(() {
                _status = valor;
                _pagina = 0;
              }),
              onRemoverEvento: () => setState(() {
                _evento = null;
                _pagina = 0;
              }),
              onRemoverParticipante: () => setState(() {
                _participante = null;
                _pagina = 0;
              }),
              // `null` esconde o botao "Limpar" quando nao ha filtro.
              onLimpar: _temFiltro ? _limparFiltros : null,
            ),
          ),
          Expanded(
            child: AsyncView<PagedModel<Inscricao>>(
              reloadKey: _chave,
              load: _carregar,
              isEmpty: (pagina) => pagina.isEmpty,
              // Mensagens do estado vazio dependem de filtro e papel.
              emptyTitle: _temFiltro
                  ? 'Nenhuma inscrição com esses filtros'
                  : _organizador
                  ? 'Nenhuma inscrição ainda'
                  : 'Você ainda não se inscreveu',
              emptyMessage: _temFiltro
                  ? 'Limpe os filtros para ver todas as inscrições.'
                  : _organizador
                  ? 'As inscrições feitas pelos participantes aparecem aqui.'
                  : 'Abra um evento na aba Eventos e toque em '
                        '"Quero me inscrever".',
              emptyAction: _temFiltro
                  ? TextButton.icon(
                      onPressed: _limparFiltros,
                      icon: const Icon(Icons.close),
                      label: const Text('Limpar filtros'),
                    )
                  : null,
              builder: (context, pagina, recarregar) => RefreshIndicator(
                onRefresh: recarregar,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 48),
                  children: [
                    ContentWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          // Ex.: "1-20 de 37".
                          Text(
                            pagina.faixaDescrita,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 14),
                          // Um cartao por inscricao, com espaco entre eles.
                          for (final inscricao in pagina.content) ...[
                            _InscricaoCartao(
                              inscricao: inscricao,
                              organizador: _organizador,
                              onAbrir: () => _abrirEvento(inscricao),
                              onMudarStatus: (novo) =>
                                  _mudarStatus(inscricao, novo),
                            ),
                            const SizedBox(height: 12),
                          ],
                          const SizedBox(height: 8),
                          // `null` desabilita o botao (sem pagina para ir).
                          _Paginacao(
                            pagina: pagina,
                            onAnterior: pagina.hasPrevious
                                ? () => setState(() => _pagina--)
                                : null,
                            onProxima: pagina.hasNext
                                ? () => setState(() => _pagina++)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chips de filtro de status + chips dos filtros ativos (evento/participante).
class _Filtros extends StatelessWidget {
  const _Filtros({
    required this.evento,
    required this.participante,
    required this.status,
    required this.onStatus,
    required this.onRemoverEvento,
    required this.onRemoverParticipante,
    required this.onLimpar,
  });

  final Evento? evento;
  final Participante? participante;
  final StatusInscricao? status;

  /// Recebe o status escolhido (`null` = "Todas").
  final ValueChanged<StatusInscricao?> onStatus;
  final VoidCallback onRemoverEvento;
  final VoidCallback onRemoverParticipante;
  final VoidCallback? onLimpar;

  /// Chip de escolha unica ("Todas", "Pendente"...).
  /// `ChoiceChip` e uma etiqueta que fica "selecionada" quando tocada.
  Widget _opcao(String rotulo, bool selecionado, VoidCallback onTap) =>
      ChoiceChip(
        label: Text(rotulo),
        selected: selecionado,
        // Ao tocar, chama `onTap` (o parametro `_` do Flutter e ignorado).
        onSelected: (_) => onTap(),
        // Sem o "tique" que o Material poe ao lado do texto quando selecionado.
        showCheckmark: false,
        // `color` (e nao `backgroundColor`): no Material 3 o fundo do chip vem
        // de `color`, e um fundo translucido aqui era ignorado, deixando texto
        // branco sobre chip branco. Cores solidas, para nao depender do que
        // esta atras.
        // CONCEITO - WidgetStateProperty: valor que depende do ESTADO do widget
        // (selecionado, hover, desabilitado...). `resolveWith` recebe o conjunto
        // de estados atuais e devolve o valor correspondente.
        color: WidgetStateProperty.resolveWith(
          (estados) => estados.contains(WidgetState.selected)
              ? Paleta.ciano
              : Paleta.petroleo,
        ),
        // Borda ciano: desenha o chip sobre o fundo escuro do cabecalho.
        side: const BorderSide(color: Paleta.ciano),
        labelStyle: TextStyle(
          // Selecionado: texto escuro sobre ciano; senao, branco sobre petroleo.
          color: selecionado ? Paleta.marinho : Colors.white,
          fontWeight: FontWeight.w600,
        ),
      );

  /// Chip removivel que representa um filtro ativo (com "x").
  Widget _filtroAtivo(IconData icone, String rotulo, VoidCallback onDeleted) =>
      InputChip(
        avatar: Icon(icone, size: 16, color: Paleta.marinho),
        label: Text(rotulo, style: const TextStyle(color: Paleta.marinho)),
        backgroundColor: Colors.white,
        side: BorderSide.none,
        deleteIconColor: Paleta.marinho,
        // Mostrar o "x" e chama esta funcao ao toca-lo.
        onDeleted: onDeleted,
      );

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      // Os filtros da API sao independentes e combinaveis: cada um ausente e
      // simplesmente ignorado pela consulta.
      _opcao('Todas', status == null, () => onStatus(null)),
      // Um chip por status do enum.
      for (final valor in StatusInscricao.values)
        _opcao(valor.rotulo, status == valor, () => onStatus(valor)),
      if (evento != null)
        _filtroAtivo(Icons.event, evento!.titulo, onRemoverEvento),
      if (participante != null)
        _filtroAtivo(Icons.person, participante!.nome, onRemoverParticipante),
      if (onLimpar != null)
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          onPressed: onLimpar,
          icon: const Icon(Icons.close),
          label: const Text('Limpar'),
        ),
    ],
  );
}

/// Uma inscricao, como um "ingresso".
class _InscricaoCartao extends StatelessWidget {
  const _InscricaoCartao({
    required this.inscricao,
    required this.organizador,
    required this.onAbrir,
    required this.onMudarStatus,
  });

  final Inscricao inscricao;
  final bool organizador;
  final VoidCallback onAbrir;

  /// Recebe o novo status escolhido no menu.
  final ValueChanged<StatusInscricao> onMudarStatus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;

    // Somente as transicoes que o back-end aceita. `CANCELADA` e terminal, e
    // ate repetir o status atual seria recusado com 409 — por isso o botao
    // desaparece em vez de oferecer uma acao que falharia.
    // Participante nunca ve acoes (lista vazia constante).
    final proximos = organizador
        ? inscricao.status.proximos.toList(growable: false)
        : const <StatusInscricao>[];

    // Cor da faixa lateral conforme o status.
    final corFaixa = switch (inscricao.status) {
      StatusInscricao.pendente => Paleta.turquesa,
      StatusInscricao.confirmada => Paleta.azul,
      StatusInscricao.cancelada => scheme.outlineVariant,
    };

    // Organizador ve o NOME do participante em destaque; participante ve o
    // TITULO do evento.
    final principal = organizador
        ? inscricao.participanteNome
        : inscricao.eventoTitulo;
    final secundario = organizador
        ? inscricao.eventoTitulo
        : 'Inscrição nº ${inscricao.id}';

    final celular = Tela.of(context).ehCelular;
    final selo = StatusInscricaoChip(status: inscricao.status);
    // Menu "tres pontinhos" com as transicoes; `Widget?` pois pode nao existir.
    final Widget? menu = proximos.isNotEmpty
        ? PopupMenuButton<StatusInscricao>(
            tooltip: 'Alterar status',
            icon: const Icon(Icons.more_vert),
            onSelected: onMudarStatus,
            itemBuilder: (_) => [
              for (final destino in proximos)
                PopupMenuItem(
                  value: destino,
                  child: Row(
                    children: [
                      Icon(
                        destino == StatusInscricao.confirmada
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        destino == StatusInscricao.confirmada
                            ? 'Confirmar'
                            : 'Cancelar',
                      ),
                    ],
                  ),
                ),
            ],
          )
        // Sem menu (inscricao cancelada): reserva o espaco para alinhar as
        // colunas dos demais cartoes (so organizador, fora do celular).
        : (organizador && !celular ? const SizedBox(width: 48) : null);

    return Card(
      child: InkWell(
        onTap: onAbrir,
        // IntrinsicHeight: a faixa colorida acompanha a altura do conteudo.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Faixa lateral de 6 px com a cor do status.
              Container(width: 6, color: corFaixa),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: scheme.primaryContainer,
                        foregroundColor: scheme.onPrimaryContainer,
                        child: Icon(
                          organizador
                              ? Icons.person
                              : Icons.confirmation_number_outlined,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              principal,
                              style: texto.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              secundario,
                              style: texto.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Inscrito em '
                              '${Fmt.dataHora(inscricao.dataInscricao)}',
                              style: texto.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            // Celular: o selo desce para sua propria linha em
                            // vez de disputar espaco com o nome.
                            if (celular) ...[const SizedBox(height: 8), selo],
                          ],
                        ),
                      ),
                      if (!celular) ...[const SizedBox(width: 12), selo],
                      // `?menu` (null-aware element): so inclui o item na lista
                      // se `menu` NAO for nulo.
                      ?menu,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Controles "< Pagina X de Y >" (escondidos quando ha uma pagina so).
class _Paginacao extends StatelessWidget {
  const _Paginacao({
    required this.pagina,
    required this.onAnterior,
    required this.onProxima,
  });

  /// `PagedModel<Object?>`: aceita pagina de qualquer tipo (so usa os numeros).
  final PagedModel<Object?> pagina;
  final VoidCallback? onAnterior;
  final VoidCallback? onProxima;

  @override
  Widget build(BuildContext context) {
    // Uma pagina so: nao ha o que paginar.
    if (pagina.totalPages <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.outlined(
          style: IconButton.styleFrom(
            // Cor legivel mesmo quando o botao esta desabilitado.
            disabledForegroundColor: Theme.of(context)
                .colorScheme
                .onSurfaceVariant
                .withValues(alpha: 0.6),
          ),
          tooltip: 'Página anterior',
          onPressed: onAnterior,
          icon: const Icon(Icons.chevron_left),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            // `number` e base zero; mostramos +1 ao usuario.
            'Página ${pagina.number + 1} de ${pagina.totalPages}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        IconButton.outlined(
          style: IconButton.styleFrom(
            disabledForegroundColor: Theme.of(context)
                .colorScheme
                .onSurfaceVariant
                .withValues(alpha: 0.6),
          ),
          tooltip: 'Próxima página',
          onPressed: onProxima,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
