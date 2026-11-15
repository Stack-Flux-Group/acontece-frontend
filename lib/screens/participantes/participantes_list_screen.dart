import 'package:material_ui/material_ui.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/paged_model.dart';
import '../../models/participante.dart';
import '../../services.dart';
import '../../widgets/async_view.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/pickers.dart';
import 'participante_form_screen.dart';

/// Lista paginada de participantes.
///
/// `GET /participantes` e paginado de verdade (`PagedModel`), entao aqui a
/// paginacao e do servidor — diferente da aba de eventos, cuja rota devolve a
/// tabela inteira.
class ParticipantesListScreen extends StatefulWidget {
  const ParticipantesListScreen({super.key});

  @override
  State<ParticipantesListScreen> createState() =>
      _ParticipantesListScreenState();
}

class _ParticipantesListScreenState extends State<ParticipantesListScreen> {
  static const _tamanhoPagina = 20;

  int _pagina = 0;
  String _ordem = 'nome,asc';
  int _versao = 0;

  String get _chave => '$_pagina|$_ordem|$_versao';

  Future<PagedModel<Participante>> _carregar() => Services.of(
    context,
  ).participantes.listar(page: _pagina, size: _tamanhoPagina, sort: _ordem);

  void _recarregar() => setState(() => _versao++);

  Future<void> _criar() async {
    final salvou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ParticipanteFormScreen()),
    );
    if (salvou == true && mounted) {
      setState(() {
        _pagina = 0;
        _versao++;
      });
    }
  }

  Future<void> _editar(Participante participante) async {
    final salvou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ParticipanteFormScreen(participante: participante),
      ),
    );
    if (salvou == true && mounted) _recarregar();
  }

  Future<void> _excluir(Participante participante) async {
    final confirmado = await confirmar(
      context,
      titulo: 'Excluir ${participante.nome}?',
      mensagem:
          'A exclusao e definitiva. Se o participante tiver inscricoes, a API '
          'vai recusar a operacao.',
    );
    if (!confirmado || !mounted) return;

    try {
      await Services.of(context).participantes.excluir(participante.id);
      if (!mounted) return;
      mostrarSucesso(context, 'Participante excluido.');
      _recarregar();
    } on ApiException catch (e) {
      if (!mounted) return;
      mostrarErro(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Participantes'),
      actions: [
        PopupMenuButton<String>(
          tooltip: 'Ordenar',
          icon: const Icon(Icons.sort),
          initialValue: _ordem,
          onSelected: (valor) => setState(() {
            _ordem = valor;
            _pagina = 0;
          }),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'nome,asc', child: Text('Nome (A-Z)')),
            PopupMenuItem(value: 'nome,desc', child: Text('Nome (Z-A)')),
            PopupMenuItem(value: 'id,desc', child: Text('Mais recentes')),
            PopupMenuItem(value: 'email,asc', child: Text('E-mail (A-Z)')),
          ],
        ),
        const SizedBox(width: 4),
      ],
    ),
    body: AsyncView<PagedModel<Participante>>(
      reloadKey: _chave,
      load: _carregar,
      isEmpty: (pagina) => pagina.isEmpty,
      emptyTitle: 'Nenhum participante cadastrado',
      emptyMessage:
          'Cadastre participantes para poder inscreve-los nos eventos.',
      emptyAction: FilledButton.icon(
        onPressed: _criar,
        icon: const Icon(Icons.add),
        label: const Text('Novo participante'),
      ),
      builder: (context, pagina, recarregar) => ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
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
                        _ParticipanteLinha(
                          participante: pagina.content[i],
                          onEditar: () => _editar(pagina.content[i]),
                          onExcluir: () => _excluir(pagina.content[i]),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
    floatingActionButton: FloatingActionButton.extended(
      heroTag: 'fab-participantes',
      onPressed: _criar,
      icon: const Icon(Icons.add),
      label: const Text('Novo participante'),
    ),
  );
}

class _ParticipanteLinha extends StatelessWidget {
  const _ParticipanteLinha({
    required this.participante,
    required this.onEditar,
    required this.onExcluir,
  });

  final Participante participante;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: Text(
          participante.nome.isEmpty
              ? '?'
              : participante.nome.substring(0, 1).toUpperCase(),
        ),
      ),
      title: Text(participante.nome),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(participante.email),
          Text(
            'CPF ${Fmt.cpf(participante.cpf)}'
            '${participante.telefone == null || participante.telefone!.isEmpty ? '' : ' · ${Fmt.telefone(participante.telefone)}'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Editar',
            onPressed: onEditar,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Excluir',
            onPressed: onExcluir,
            icon: Icon(Icons.delete_outline, color: scheme.error),
          ),
        ],
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

  final PagedModel<Participante> pagina;
  final VoidCallback? onAnterior;
  final VoidCallback? onProxima;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        onPressed: onAnterior,
        icon: const Icon(Icons.chevron_left),
        tooltip: 'Pagina anterior',
      ),
      Text(
        pagina.totalPages == 0
            ? 'Pagina 1 de 1'
            : 'Pagina ${pagina.number + 1} de ${pagina.totalPages}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      IconButton(
        onPressed: onProxima,
        icon: const Icon(Icons.chevron_right),
        tooltip: 'Proxima pagina',
      ),
    ],
  );
}
