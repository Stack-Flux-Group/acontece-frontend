// =============================================================================
// participantes_list_screen.dart - ABA "PARTICIPANTES" (so organizador)
// =============================================================================
//
// Lista paginada pelo SERVIDOR (20 por pagina) com ordenacao, criacao, edicao
// e exclusao. Mesmo padrao das outras listas: `_chave` + AsyncView.
// =============================================================================

import 'package:material_ui/material_ui.dart';

import '../../infraestrutura/api_exception.dart';
import '../../infraestrutura/formatters.dart';
import '../../infraestrutura/theme.dart';
import '../../modelos_da_api/auth.dart';
import '../../modelos_da_api/paged_model.dart';
import '../../modelos_da_api/participante.dart';
import '../../services.dart';
import '../../componentes_visuais/async_view.dart';
import '../../componentes_visuais/cabecalho_pagina.dart';
import '../../componentes_visuais/error_banner.dart';
import '../../componentes_visuais/pickers.dart';
import '../home_shell.dart';
import 'participante_form_screen.dart';

/// Lista paginada de participantes. So o organizador chega aqui:
/// `GET /participantes` e exclusivo dele.
///
/// `GET /participantes` e paginado de verdade (`PagedModel`), entao aqui a
/// paginacao e do servidor — diferente da aba de eventos, cuja rota devolve a
/// tabela inteira.
class ParticipantesListScreen extends StatefulWidget {
  const ParticipantesListScreen({super.key, required this.usuario});

  final UsuarioLogado usuario;

  @override
  State<ParticipantesListScreen> createState() =>
      _ParticipantesListScreenState();
}

class _ParticipantesListScreenState extends State<ParticipantesListScreen> {
  /// `static const`: constante da classe (itens por pagina).
  static const _tamanhoPagina = 20;

  /// Pagina atual (base zero).
  int _pagina = 0;

  /// Ordenacao no formato do Spring: "campo,asc|desc".
  String _ordem = 'nome,asc';

  /// Incrementado para forcar recarga (apos criar/editar/excluir).
  int _versao = 0;

  /// Qualquer mudanca em pagina/ordem/versao faz o AsyncView recarregar.
  String get _chave => '$_pagina|$_ordem|$_versao';

  /// Busca a pagina atual no servidor.
  Future<PagedModel<Participante>> _carregar() =>
      Services.of(context).participantes
          .listar(page: _pagina, size: _tamanhoPagina, sort: _ordem);

  /// Soma 1 na versao: muda a `_chave` e o AsyncView busca de novo.
  void _recarregar() => setState(() => _versao++);

  /// Abre o formulario de novo participante; ao salvar, volta a pagina 1.
  Future<void> _criar() async {
    // `push<bool>` empilha a tela e espera o `bool` devolvido no `pop`.
    final salvou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ParticipanteFormScreen()),
    );
    // `mounted`: depois de um `await`, confirma que a tela ainda existe.
    if (salvou == true && mounted) {
      setState(() {
        _pagina = 0;
        _versao++;
      });
    }
  }

  /// Abre o formulario ja preenchido para edicao.
  Future<void> _editar(Participante participante) async {
    final salvou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ParticipanteFormScreen(participante: participante),
      ),
    );
    if (salvou == true && mounted) _recarregar();
  }

  /// Confirma e exclui. A API recusa (409) se houver inscricoes.
  Future<void> _excluir(Participante participante) async {
    final confirmado = await confirmar(
      context,
      titulo: 'Excluir ${participante.nome}?',
      mensagem:
          'A exclusão é definitiva. Se o participante tiver inscrições, a API '
          'vai recusar a operação.',
    );
    // Cancelou (ou a tela foi fechada): nada a fazer.
    if (!confirmado || !mounted) return;

    try {
      await Services.of(context).participantes.excluir(participante.id);
      if (!mounted) return;
      mostrarSucesso(context, 'Participante excluído.');
      _recarregar();
    } on ApiException catch (e) {
      if (!mounted) return;
      mostrarErro(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        CabecalhoPagina(
          titulo: 'Participantes',
          subtitulo: 'Pessoas cadastradas na plataforma.',
          acoes: [
            // Menu de ordenacao.
            PopupMenuButton<String>(
              tooltip: 'Ordenar',
              // Cor explicita: sem ela o icone herdaria a cor escura do tema e
              // sumiria sobre o degrade do cabecalho.
              icon: const Icon(Icons.sort, color: Colors.white),
              style: estiloBotaoCabecalho,
              // Marca a opcao atual no menu.
              initialValue: _ordem,
              onSelected: (valor) => setState(() {
                _ordem = valor;
                // Trocar a ordem volta para a primeira pagina.
                _pagina = 0;
              }),
              // Cada item tem um `value` (o que vai para a API) e um texto.
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'nome,asc', child: Text('Nome (A-Z)')),
                PopupMenuItem(value: 'nome,desc', child: Text('Nome (Z-A)')),
                PopupMenuItem(value: 'id,desc', child: Text('Mais recentes')),
                PopupMenuItem(value: 'email,asc', child: Text('E-mail (A-Z)')),
              ],
            ),
            ContaBotao(usuario: widget.usuario),
          ],
        ),
        Expanded(
          child: AsyncView<PagedModel<Participante>>(
            reloadKey: _chave,
            load: _carregar,
            isEmpty: (pagina) => pagina.isEmpty,
            emptyTitle: 'Nenhum participante cadastrado',
            emptyMessage: 'Os participantes podem criar a própria conta na tela de entrada.',
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
                      const SizedBox(height: 20),
                      // Ex.: "1-20 de 37".
                      Text(
                        pagina.faixaDescrita,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Um unico Card com as linhas separadas por Divider.
                      Card(
                        child: Column(
                          children: [
                            // `...[ ]` dentro do `for`: cada volta adiciona
                            // (divisor opcional + linha).
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
                      // Botoes anterior/proxima (null desabilita).
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
      ],
    ),
    // heroTag proprio: as abas coexistem no IndexedStack (ver CLAUDE.md).
    floatingActionButton: FloatingActionButton.extended(
      heroTag: 'fab-participantes',
      onPressed: _criar,
      icon: const Icon(Icons.add),
      label: const Text('Novo participante'),
    ),
  );
}

/// Uma linha da lista: avatar, nome, e-mail, CPF/telefone e acoes.
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
    // ListTile: linha padrao do Material (leading, title, subtitle, trailing).
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: Text(
          // Inicial do nome em maiuscula; "?" se o nome estiver vazio.
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
          // CPF sempre; telefone so se existir (concatenado por interpolacao).
          Text(
            'CPF ${Fmt.cpf(participante.cpf)}'
            '${participante.telefone == null || participante.telefone!.isEmpty ? '' : ' · ${Fmt.telefone(participante.telefone)}'}',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      // Celular: editar e excluir viram um menu, para nao apertar o nome.
      trailing: Tela.of(context).ehCelular
          ? PopupMenuButton<String>(
              tooltip: 'Ações',
              // Ternario que chama uma das duas funcoes.
              onSelected: (valor) =>
                  valor == 'editar' ? onEditar() : onExcluir(),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'editar',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Editar'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'excluir',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: scheme.error),
                      const SizedBox(width: 10),
                      Text('Excluir', style: TextStyle(color: scheme.error)),
                    ],
                  ),
                ),
              ],
            )
          // Telas maiores: dois botoes de icone lado a lado.
          : Row(
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

/// Controles "< Pagina X de Y >".
class _Paginacao extends StatelessWidget {
  const _Paginacao({
    required this.pagina,
    required this.onAnterior,
    required this.onProxima,
  });

  final PagedModel<Participante> pagina;

  /// `null` desabilita o botao correspondente.
  final VoidCallback? onAnterior;
  final VoidCallback? onProxima;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton.outlined(
        style: IconButton.styleFrom(
          // Cor legivel mesmo quando desabilitado.
          disabledForegroundColor: Theme.of(context)
              .colorScheme
              .onSurfaceVariant
              .withValues(alpha: 0.6),
        ),
        onPressed: onAnterior,
        icon: const Icon(Icons.chevron_left),
        tooltip: 'Página anterior',
      ),
      Text(
        // `number` e base zero; mostramos +1 ao usuario.
        pagina.totalPages == 0
            ? 'Página 1 de 1'
            : 'Página ${pagina.number + 1} de ${pagina.totalPages}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      IconButton.outlined(
        style: IconButton.styleFrom(
          disabledForegroundColor: Theme.of(context)
              .colorScheme
              .onSurfaceVariant
              .withValues(alpha: 0.6),
        ),
        onPressed: onProxima,
        icon: const Icon(Icons.chevron_right),
        tooltip: 'Próxima página',
      ),
    ],
  );
}
