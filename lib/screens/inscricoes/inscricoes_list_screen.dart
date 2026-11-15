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
  Evento? _evento;
  Participante? _participante;
  StatusInscricao? _status;

  int _pagina = 0;
  int _versao = 0;

  bool get _organizador => widget.usuario.ehOrganizador;

  String get _chave =>
      '${_evento?.id}|${_participante?.id}|${_status?.wire}|$_pagina|$_versao';

  bool get _temFiltro =>
      _evento != null || _participante != null || _status != null;

  @override
  void initState() {
    super.initState();
    _evento = widget.eventoInicial;
  }

  Future<PagedModel<Inscricao>> _carregar() =>
      Services.of(context).inscricoes.listar(
        eventoId: _evento?.id,
        // Para o participante a API ignora este filtro e usa o id do token.
        participanteId: _organizador ? _participante?.id : null,
        status: _status,
        page: _pagina,
      );

  void _limparFiltros() => setState(() {
    _evento = null;
    _participante = null;
    _status = null;
    _pagina = 0;
  });

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
      setState(() => _versao++);
    } on ApiException catch (e) {
      if (!mounted) return;
      mostrarErro(context, e);
    }
  }

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

  Future<void> _filtrarPorEvento() async {
    final evento = await escolherEvento(context, Services.of(context).eventos);
    if (evento != null && mounted) {
      setState(() {
        _evento = evento;
        _pagina = 0;
      });
    }
  }

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
              if (_organizador)
                AcaoCabecalho(
                  icone: Icons.person_search,
                  tooltip: 'Filtrar por participante',
                  onPressed: _filtrarPorParticipante,
                ),
              if (widget.eventoInicial == null)
                ContaBotao(usuario: widget.usuario),
            ],
            rodape: _Filtros(
              evento: _evento,
              participante: _participante,
              status: _status,
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
              onLimpar: _temFiltro ? _limparFiltros : null,
            ),
          ),
          Expanded(
            child: AsyncView<PagedModel<Inscricao>>(
              reloadKey: _chave,
              load: _carregar,
              isEmpty: (pagina) => pagina.isEmpty,
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
  final ValueChanged<StatusInscricao?> onStatus;
  final VoidCallback onRemoverEvento;
  final VoidCallback onRemoverParticipante;
  final VoidCallback? onLimpar;

  Widget _opcao(String rotulo, bool selecionado, VoidCallback onTap) =>
      ChoiceChip(
        label: Text(rotulo),
        selected: selecionado,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: Paleta.ciano,
        backgroundColor: Colors.white.withValues(alpha: 0.1),
        side: BorderSide(color: Paleta.ciano.withValues(alpha: 0.35)),
        labelStyle: TextStyle(
          color: selecionado ? Paleta.marinho : Colors.white,
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _filtroAtivo(IconData icone, String rotulo, VoidCallback onDeleted) =>
      InputChip(
        avatar: Icon(icone, size: 16, color: Paleta.marinho),
        label: Text(rotulo, style: const TextStyle(color: Paleta.marinho)),
        backgroundColor: Colors.white,
        side: BorderSide.none,
        deleteIconColor: Paleta.marinho,
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
  final ValueChanged<StatusInscricao> onMudarStatus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;

    // Somente as transicoes que o back-end aceita. `CANCELADA` e terminal, e
    // ate repetir o status atual seria recusado com 409 — por isso o botao
    // desaparece em vez de oferecer uma acao que falharia.
    final proximos = organizador
        ? inscricao.status.proximos.toList(growable: false)
        : const <StatusInscricao>[];

    final corFaixa = switch (inscricao.status) {
      StatusInscricao.pendente => Paleta.turquesa,
      StatusInscricao.confirmada => Paleta.azul,
      StatusInscricao.cancelada => scheme.outlineVariant,
    };

    final principal = organizador
        ? inscricao.participanteNome
        : inscricao.eventoTitulo;
    final secundario = organizador
        ? inscricao.eventoTitulo
        : 'Inscrição nº ${inscricao.id}';

    return Card(
      child: InkWell(
        onTap: onAbrir,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      StatusInscricaoChip(status: inscricao.status),
                      if (proximos.isNotEmpty)
                        PopupMenuButton<StatusInscricao>(
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
                      else if (organizador)
                        const SizedBox(width: 48),
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

class _Paginacao extends StatelessWidget {
  const _Paginacao({
    required this.pagina,
    required this.onAnterior,
    required this.onProxima,
  });

  final PagedModel<Object?> pagina;
  final VoidCallback? onAnterior;
  final VoidCallback? onProxima;

  @override
  Widget build(BuildContext context) {
    if (pagina.totalPages <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.outlined(
          tooltip: 'Página anterior',
          onPressed: onAnterior,
          icon: const Icon(Icons.chevron_left),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Página ${pagina.number + 1} de ${pagina.totalPages}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        IconButton.outlined(
          tooltip: 'Próxima página',
          onPressed: onProxima,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
