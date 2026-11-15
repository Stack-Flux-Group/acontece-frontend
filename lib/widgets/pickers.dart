import 'package:material_ui/material_ui.dart';

import '../core/formatters.dart';
import '../models/evento.dart';
import '../models/participante.dart';
import '../repositories/evento_repository.dart';
import '../repositories/participante_repository.dart';
import 'async_view.dart';

/// Escolhe um participante (filtro do organizador na aba de inscricoes).
///
/// Depende de `GET /participantes`, que so o organizador pode chamar.
Future<Participante?> escolherParticipante(
  BuildContext context,
  ParticipanteRepository repository,
) => showDialog<Participante>(
  context: context,
  builder: (_) => _PickerDialog<Participante>(
    titulo: 'Escolher participante',
    dica: 'Buscar por nome, e-mail ou CPF',
    load: () => repository.buscar(''),
    vazio: 'Nenhum participante cadastrado ainda.',
    combina: (p, termo) =>
        p.nome.toLowerCase().contains(termo) ||
        p.email.contains(termo) ||
        p.cpf.contains(termo.replaceAll(RegExp(r'[^0-9]'), '')),
    constroi: (p) => ListTile(
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
    load: repository.listar,
    vazio: 'Nenhum evento cadastrado ainda.',
    combina: (e, termo) =>
        e.titulo.toLowerCase().contains(termo) ||
        e.endereco.cidade.toLowerCase().contains(termo),
    constroi: (e) => ListTile(
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

class _PickerDialog<T> extends StatefulWidget {
  const _PickerDialog({
    required this.titulo,
    required this.dica,
    required this.load,
    required this.combina,
    required this.constroi,
    required this.vazio,
  });

  final String titulo;
  final String dica;
  final Future<List<T>> Function() load;
  final bool Function(T item, String termo) combina;
  final Widget Function(T item) constroi;
  final String vazio;

  @override
  State<_PickerDialog<T>> createState() => _PickerDialogState<T>();
}

class _PickerDialogState<T> extends State<_PickerDialog<T>> {
  String _termo = '';

  @override
  Widget build(BuildContext context) {
    // Cabe em qualquer tela: no celular o dialogo ocupa quase toda a largura e
    // 70% da altura, em vez dos 520x460 fixos que estouravam.
    final tela = MediaQuery.sizeOf(context);
    final largura = (tela.width - 48).clamp(0.0, 520.0);
    final altura = (tela.height * 0.7).clamp(0.0, 460.0);
    return AlertDialog(
      title: Text(widget.titulo),
      content: SizedBox(
        width: largura,
        height: altura,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.dica,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _termo = value.trim().toLowerCase()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AsyncView<List<T>>(
                load: widget.load,
                isEmpty: (itens) => itens.isEmpty,
                emptyTitle: 'Lista vazia',
                emptyMessage: widget.vazio,
                builder: (context, itens, _) {
                  final filtrados = _termo.isEmpty
                      ? itens
                      : itens
                            .where((item) => widget.combina(item, _termo))
                            .toList(growable: false);
                  if (filtrados.isEmpty) {
                    return const EmptyState(
                      titulo: 'Nenhum resultado',
                      mensagem: 'Tente outro termo de busca.',
                      icone: Icons.search_off,
                    );
                  }
                  return ListView.separated(
                    itemCount: filtrados.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = filtrados[index];
                      return InkWell(
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

/// Confirmacao destrutiva (excluir evento / participante).
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  String rotuloConfirmar = 'Excluir',
}) async {
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
  return resposta ?? false;
}
