// =============================================================================
// pickers.dart - DIALOGOS DE ESCOLHA E DE CONFIRMACAO
// =============================================================================
//
// CONCEITO - dialogo: janelinha modal exibida sobre a tela com `showDialog`.
// `showDialog<T>` devolve um `Future<T?>` que completa quando o dialogo e
// fechado com `Navigator.pop(valor)`; o valor do `pop` e o resultado do Future.
//
// Contem:
//   * escolherParticipante / escolherEvento -> dialogos de busca e selecao
//   * _PickerDialog                         -> dialogo generico reutilizado
//   * confirmar                              -> confirmacao de acao destrutiva
// =============================================================================

import 'package:material_ui/material_ui.dart';

import '../infraestrutura/formatters.dart';
import '../modelos_da_api/evento.dart';
import '../modelos_da_api/participante.dart';
import '../acesso_a_api/evento_repository.dart';
import '../acesso_a_api/participante_repository.dart';
// AsyncView (carregando/erro/vazio) e EmptyState.
import 'async_view.dart';

/// Escolhe um participante (filtro do organizador na aba de inscricoes).
///
/// Depende de `GET /participantes`, que so o organizador pode chamar.
/// Devolve o participante escolhido, ou `null` se o usuario cancelar.
Future<Participante?> escolherParticipante(
  BuildContext context,
  ParticipanteRepository repository,
) => showDialog<Participante>(
  context: context,
  // `_` = parametro (o contexto do dialogo) ignorado.
  builder: (_) => _PickerDialog<Participante>(
    titulo: 'Escolher participante',
    dica: 'Buscar por nome, e-mail ou CPF',
    // Carrega todos (busca vazia = sem filtro).
    load: () => repository.buscar(''),
    vazio: 'Nenhum participante cadastrado ainda.',
    // Regra de filtro local conforme o que for digitado.
    combina: (p, termo) =>
        p.nome.toLowerCase().contains(termo) ||
        p.email.contains(termo) ||
        p.cpf.contains(termo.replaceAll(RegExp(r'[^0-9]'), '')),
    // Como desenhar cada linha da lista.
    constroi: (p) => ListTile(
      // CircleAvatar com a inicial do nome.
      leading: CircleAvatar(
        child: Text(
          p.nome.isEmpty ? '?' : p.nome.substring(0, 1).toUpperCase(),
        ),
      ),
      title: Text(p.nome),
      subtitle: Text('${p.email} · ${Fmt.cpf(p.cpf)}'),
    ),
  ),
);

/// Escolhe um evento (filtro da aba de inscricoes).
Future<Evento?> escolherEvento(
  BuildContext context,
  EventoRepository repository,
) => showDialog<Evento>(
  context: context,
  builder: (_) => _PickerDialog<Evento>(
    titulo: 'Escolher evento',
    dica: 'Buscar por título ou cidade',
    // Todos os eventos (as paginas de 100 sao juntadas pelo repositorio).
    load: () => repository.listarTodos(),
    vazio: 'Nenhum evento cadastrado ainda.',
    combina: (e, termo) =>
        e.titulo.toLowerCase().contains(termo) ||
        e.endereco.cidade.toLowerCase().contains(termo),
    constroi: (e) => ListTile(
      // Icone muda se o evento ja encerrou.
      leading: Icon(
        e.encerrado ? Icons.event_busy : Icons.event_available,
        color: e.encerrado ? Theme.of(context).colorScheme.outline : null,
      ),
      title: Text(e.titulo),
      subtitle: Text(
        '${Fmt.dataHora(e.dataInicio)} · ${e.endereco.cidadeUf} · '
        '${Fmt.vagas(e.vagas)}'
        '${e.encerrado ? ' · encerrado' : ''}',
      ),
    ),
  ),
);

/// Dialogo generico com busca, para escolher um item de qualquer tipo [T].
///
/// Recebe FUNCOES como parametros (`load`, `combina`, `constroi`): quem usa
/// diz como carregar, como filtrar e como desenhar. Isso evita duplicar o
/// dialogo para participante e para evento.
class _PickerDialog<T> extends StatefulWidget {
  const _PickerDialog({
    required this.titulo,
    required this.dica,
    required this.load,
    required this.combina,
    required this.constroi,
    required this.vazio,
  });

  /// Titulo do dialogo.
  final String titulo;

  /// Texto de dica (placeholder) do campo de busca.
  final String dica;

  /// Funcao que carrega a lista (assincrona).
  final Future<List<T>> Function() load;

  /// Decide se um item combina com o termo digitado.
  final bool Function(T item, String termo) combina;

  /// Desenha uma linha da lista para um item.
  final Widget Function(T item) constroi;

  /// Mensagem quando a lista inteira esta vazia.
  final String vazio;

  @override
  State<_PickerDialog<T>> createState() => _PickerDialogState<T>();
}

class _PickerDialogState<T> extends State<_PickerDialog<T>> {
  /// Termo de busca atual (ja em minusculas e sem espacos nas pontas).
  String _termo = '';

  @override
  Widget build(BuildContext context) {
    // Cabe em qualquer tela: no celular o dialogo ocupa quase toda a largura e
    // 70% da altura, em vez dos 520x460 fixos que estouravam.
    // `MediaQuery.sizeOf` = tamanho da janela. `clamp(min, max)` limita o valor.
    final tela = MediaQuery.sizeOf(context);
    final largura = (tela.width - 48).clamp(0.0, 520.0);
    final altura = (tela.height * 0.7).clamp(0.0, 460.0);
    // AlertDialog: dialogo com titulo, conteudo e botoes.
    return AlertDialog(
      title: Text(widget.titulo),
      // SizedBox com tamanho fixo: dialogos precisam de dimensao definida
      // quando contem listas rolaveis.
      content: SizedBox(
        width: largura,
        height: altura,
        child: Column(
          children: [
            // Campo de busca.
            TextField(
              // Ja abre com o cursor no campo.
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.dica,
                prefixIcon: const Icon(Icons.search),
              ),
              // A cada tecla, guarda o termo e redesenha (setState).
              onChanged: (value) =>
                  setState(() => _termo = value.trim().toLowerCase()),
            ),
            const SizedBox(height: 12),
            // Expanded: a lista ocupa o resto da altura da coluna.
            Expanded(
              // AsyncView carrega os dados mostrando carregando/erro/vazio.
              child: AsyncView<List<T>>(
                load: widget.load,
                isEmpty: (itens) => itens.isEmpty,
                emptyTitle: 'Lista vazia',
                emptyMessage: widget.vazio,
                builder: (context, itens, _) {
                  // Sem termo: todos; com termo: so os que combinam.
                  final filtrados = _termo.isEmpty
                      ? itens
                      : itens
                            .where((item) => widget.combina(item, _termo))
                            .toList(growable: false);
                  // Havia itens, mas o filtro eliminou todos.
                  if (filtrados.isEmpty) {
                    return const EmptyState(
                      titulo: 'Nenhum resultado',
                      mensagem: 'Tente outro termo de busca.',
                      icone: Icons.search_off,
                    );
                  }
                  // ListView.separated: lista rolavel com divisor entre itens.
                  // Constroi sob demanda so os itens visiveis (eficiente).
                  return ListView.separated(
                    itemCount: filtrados.length,
                    // `(_, _)` ignora os dois parametros.
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = filtrados[index];
                      // InkWell: area clicavel com efeito de toque.
                      return InkWell(
                        // Fecha o dialogo devolvendo o item escolhido.
                        onTap: () => Navigator.of(context).pop(item),
                        child: widget.constroi(item),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          // `pop()` sem valor => o Future do showDialog devolve null.
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

/// Confirmacao destrutiva (excluir evento / participante).
///
/// Devolve `true` se o usuario confirmar; `false` se cancelar ou fechar o
/// dialogo clicando fora.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  String rotuloConfirmar = 'Excluir',
}) async {
  // `showDialog<bool>` espera um bool do `pop`; clicar fora devolve null.
  final resposta = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: Text(mensagem),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        // Botao de confirmacao em vermelho (cor de erro do tema).
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(rotuloConfirmar),
        ),
      ],
    ),
  );
  // `?? false`: null (clicou fora) conta como "nao confirmou".
  return resposta ?? false;
}
