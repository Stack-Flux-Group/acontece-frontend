import 'package:material_ui/material_ui.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/evento.dart';
import '../../models/inscricao.dart';
import '../../models/paged_model.dart';
import '../../models/participante.dart';
import '../../models/status_inscricao.dart';
import '../../services.dart';
import '../../widgets/async_view.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/pickers.dart';
import '../../widgets/status_chip.dart';
import 'inscricao_form_screen.dart';

/// Inscricoes: filtros por evento, participante e status, mais a mudanca de
/// status respeitando a maquina de estados do back-end.
class InscricoesListScreen extends StatefulWidget {
  const InscricoesListScreen({super.key});

  @override
  State<InscricoesListScreen> createState() => _InscricoesListScreenState();
}

class _InscricoesListScreenState extends State<InscricoesListScreen> {
  Evento? _evento;
  Participante? _participante;
  StatusInscricao? _status;

  int _pagina = 0;
  int _versao = 0;

  /// Resultado da sondagem do modulo. `null` enquanto nao se sabe.
  bool? _moduloDisponivel;

  String get _chave =>
      '${_evento?.id}|${_participante?.id}|${_status?.wire}|$_pagina|$_versao';

  bool get _temFiltro =>
      _evento != null || _participante != null || _status != null;

  bool _sondou = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A sondagem depende de `Services`, que so pode ser lido aqui (e nao em
    // initState).
    if (!_sondou) {
      _sondou = true;
      _sondar();
    }
  }

  /// Descobre se esta build da API tem `/inscricoes`.
  ///
  /// O deploy atual nao tem, e responde `404 "No static resource inscricoes."`.
  /// Sem essa checagem a aba mostraria "nao encontrado", como se o problema
  /// fosse de dados, quando na verdade a rota nao existe.
  Future<void> _sondar() async {
    try {
      final disponivel = await Services.of(
        context,
      ).inscricoes.moduloDisponivel();
      if (mounted) setState(() => _moduloDisponivel = disponivel);
    } on ApiException {
      // Falha de rede: deixa a tela normal tratar e exibir o erro com retry.
      if (mounted) setState(() => _moduloDisponivel = true);
    }
  }

  Future<PagedModel<Inscricao>> _carregar() => Services.of(context)
      .inscricoes
      .listar(
        eventoId: _evento?.id,
        participanteId: _participante?.id,
        status: _status,
        page: _pagina,
      );

  void _limparFiltros() => setState(() {
    _evento = null;
    _participante = null;
    _status = null;
    _pagina = 0;
  });

  Future<void> _nova() async {
    final criou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const InscricaoFormScreen()),
    );
    if (criou == true && mounted) {
      setState(() {
        _pagina = 0;
        _versao++;
      });
    }
  }

  Future<void> _mudarStatus(Inscricao inscricao, StatusInscricao novo) async {
    try {
      await Services.of(
        context,
      ).inscricoes.atualizarStatus(inscricao.id, novo);
      if (!mounted) return;
      mostrarSucesso(context, 'Inscricao ${novo.rotulo.toLowerCase()}.');
      setState(() => _versao++);
    } on ApiException catch (e) {
      if (!mounted) return;
      mostrarErro(context, e);
    }
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
    if (_moduloDisponivel == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inscricoes')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_moduloDisponivel == false) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inscricoes')),
        body: const _ModuloIndisponivel(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inscricoes'),
        actions: [
          IconButton(
            tooltip: 'Filtrar por evento',
            onPressed: _filtrarPorEvento,
            icon: const Icon(Icons.event),
          ),
          IconButton(
            tooltip: 'Filtrar por participante',
            onPressed: _filtrarPorParticipante,
            icon: const Icon(Icons.person_search),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AsyncView<PagedModel<Inscricao>>(
        reloadKey: _chave,
        load: _carregar,
        isEmpty: (pagina) => pagina.isEmpty,
        emptyTitle: _temFiltro
            ? 'Nenhuma inscricao com esses filtros'
            : 'Nenhuma inscricao ainda',
        emptyMessage: _temFiltro
            ? 'Limpe os filtros para ver todas as inscricoes.'
            : 'Inscreva um participante em um evento para comecar.',
        emptyAction: _temFiltro
            ? TextButton.icon(
                onPressed: _limparFiltros,
                icon: const Icon(Icons.close),
                label: const Text('Limpar filtros'),
              )
            : FilledButton.icon(
                onPressed: _nova,
                icon: const Icon(Icons.add),
                label: const Text('Nova inscricao'),
              ),
        builder: (context, pagina, recarregar) => ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _Filtros(
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
                  const SizedBox(height: 10),
                  Text(
                    pagina.faixaDescrita,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < pagina.content.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _InscricaoLinha(
                            inscricao: pagina.content[i],
                            onMudarStatus: (novo) =>
                                _mudarStatus(pagina.content[i], novo),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Pagina anterior',
                        onPressed: pagina.hasPrevious
                            ? () => setState(() => _pagina--)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        'Pagina ${pagina.number + 1} de '
                        '${pagina.totalPages == 0 ? 1 : pagina.totalPages}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      IconButton(
                        tooltip: 'Proxima pagina',
                        onPressed: pagina.hasNext
                            ? () => setState(() => _pagina++)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-inscricoes',
        onPressed: _nova,
        icon: const Icon(Icons.add),
        label: const Text('Nova inscricao'),
      ),
    );
  }
}

/// Aviso de que a API publicada nao traz o modulo de inscricoes.
class _ModuloIndisponivel extends StatelessWidget {
  const _ModuloIndisponivel();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_off, size: 48, color: scheme.outline),
              const SizedBox(height: 16),
              Text(
                'Modulo de inscricoes nao publicado',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'A API que este site consome nao expoe as rotas /inscricoes: '
                'ela responde 404 em todas elas. O codigo do back-end tem o '
                'modulo completo (vagas com trava, uma inscricao ativa por '
                'participante, maquina de estados), mas a versao publicada esta '
                'atras do codigo-fonte.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Republique o acontece-api e esta aba passa a funcionar sozinha, '
                'sem nenhuma alteracao no site.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
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

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      // Os filtros da API sao independentes e combinaveis: cada um ausente e
      // simplesmente ignorado pela consulta.
      ChoiceChip(
        label: const Text('Todos'),
        selected: status == null,
        onSelected: (_) => onStatus(null),
      ),
      for (final valor in StatusInscricao.values)
        ChoiceChip(
          label: Text(valor.rotulo),
          selected: status == valor,
          onSelected: (_) => onStatus(valor),
        ),
      if (evento != null)
        InputChip(
          avatar: const Icon(Icons.event, size: 16),
          label: Text(evento!.titulo),
          onDeleted: onRemoverEvento,
        ),
      if (participante != null)
        InputChip(
          avatar: const Icon(Icons.person, size: 16),
          label: Text(participante!.nome),
          onDeleted: onRemoverParticipante,
        ),
      if (onLimpar != null)
        TextButton.icon(
          onPressed: onLimpar,
          icon: const Icon(Icons.close),
          label: const Text('Limpar'),
        ),
    ],
  );
}

class _InscricaoLinha extends StatelessWidget {
  const _InscricaoLinha({
    required this.inscricao,
    required this.onMudarStatus,
  });

  final Inscricao inscricao;
  final ValueChanged<StatusInscricao> onMudarStatus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Somente as transicoes que o back-end aceita. `CANCELADA` e terminal, e
    // ate repetir o status atual seria recusado com 409 — por isso o menu
    // desaparece em vez de oferecer uma acao que falharia.
    final proximos = inscricao.status.proximos.toList(growable: false);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurfaceVariant,
        child: Text('#${inscricao.id}', style: const TextStyle(fontSize: 11)),
      ),
      title: Text(inscricao.participanteNome),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(inscricao.eventoTitulo),
          Text(
            'Inscrito em ${Fmt.dataHora(inscricao.dataInscricao)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}
