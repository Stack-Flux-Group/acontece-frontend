import 'package:material_ui/material_ui.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/evento.dart';
import '../../models/inscricao.dart';
import '../../models/participante.dart';
import '../../services.dart';
import '../../widgets/async_view.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/evento_card.dart';
import '../../widgets/pickers.dart';
import '../../widgets/status_chip.dart';
import 'evento_form_screen.dart';

/// Detalhe do evento: dados, endereco resolvido pelo CEP, ocupacao de vagas e
/// acoes (editar, excluir, inscrever).
class EventoDetailScreen extends StatefulWidget {
  const EventoDetailScreen({super.key, required this.eventoId});

  final int eventoId;

  @override
  State<EventoDetailScreen> createState() => _EventoDetailScreenState();
}

/// O evento mais a ocupacao de vagas, quando o modulo de inscricoes existir.
class _Detalhe {
  const _Detalhe(this.evento, this.ocupadas);

  final Evento evento;

  /// `null` quando a API publicada nao tem `/inscricoes` — nesse caso nao da
  /// para saber a ocupacao, e a tela mostra apenas o total de vagas.
  final int? ocupadas;
}

class _EventoDetailScreenState extends State<EventoDetailScreen> {
  int _versao = 0;

  /// `true` se algo mudou e a lista anterior precisa recarregar.
  bool _alterou = false;

  Future<_Detalhe> _carregar() async {
    final services = Services.of(context);
    final evento = await services.eventos.buscarPorId(widget.eventoId);
    int? ocupadas;
    try {
      ocupadas = await services.inscricoes.contarAtivasDoEvento(evento.id);
    } on ApiException catch (e) {
      // Modulo de inscricoes ausente nesta build da API: segue sem a ocupacao.
      if (!e.isMissingEndpoint) rethrow;
    }
    return _Detalhe(evento, ocupadas);
  }

  Future<void> _editar(Evento evento) async {
    final salvou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EventoFormScreen(evento: evento)),
    );
    if (salvou == true && mounted) {
      setState(() {
        _versao++;
        _alterou = true;
      });
    }
  }

  Future<void> _excluir(Evento evento) async {
    final confirmado = await confirmar(
      context,
      titulo: 'Excluir "${evento.titulo}"?',
      mensagem:
          'A exclusao e definitiva. Se o evento tiver inscricoes, a API vai '
          'recusar a operacao.',
    );
    if (!confirmado || !mounted) return;

    try {
      await Services.of(context).eventos.deletar(evento.id);
      if (!mounted) return;
      mostrarSucesso(context, 'Evento excluido.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      mostrarErro(context, e);
    }
  }

  Future<void> _inscrever(Evento evento) async {
    final services = Services.of(context);
    final Participante? participante = await escolherParticipante(
      context,
      services.participantes,
    );
    if (participante == null || !mounted) return;

    try {
      await services.inscricoes.criar(
        InscricaoInput(participanteId: participante.id, eventoId: evento.id),
      );
      if (!mounted) return;
      mostrarSucesso(
        context,
        '${participante.nome} inscrito(a). Status inicial: pendente.',
      );
      setState(() {
        _versao++;
        _alterou = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      mostrarErro(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Detalhe do evento'),
      leading: BackButton(onPressed: () => Navigator.of(context).pop(_alterou)),
    ),
    body: AsyncView<_Detalhe>(
      reloadKey: _versao,
      load: _carregar,
      builder: (context, detalhe, _) => _Conteudo(
        detalhe: detalhe,
        onEditar: () => _editar(detalhe.evento),
        onExcluir: () => _excluir(detalhe.evento),
        onInscrever: () => _inscrever(detalhe.evento),
      ),
    ),
  );
}

class _Conteudo extends StatelessWidget {
  const _Conteudo({
    required this.detalhe,
    required this.onEditar,
    required this.onExcluir,
    required this.onInscrever,
  });

  final _Detalhe detalhe;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;
  final VoidCallback onInscrever;

  @override
  Widget build(BuildContext context) {
    final evento = detalhe.evento;
    final texto = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final ocupadas = detalhe.ocupadas;
    final lotado = ocupadas != null && ocupadas >= evento.vagas;

    return ListView(
      padding: const EdgeInsets.only(bottom: 48),
      children: [
        ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: EventoFoto(url: evento.fotoUrl, altura: 240),
              ),
              const SizedBox(height: 20),
              Text(evento.titulo, style: texto.headlineSmall),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  EventoStatusChip(status: evento.status),
                  if (ocupadas != null)
                    VagasChip(ocupadas: ocupadas, vagas: evento.vagas)
                  else
                    Chip(
                      avatar: const Icon(Icons.people_outline, size: 16),
                      label: Text(Fmt.vagas(evento.vagas)),
                    ),
                ],
              ),
              if (evento.descricao.trim().isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(evento.descricao, style: texto.bodyLarge),
              ],
              const SizedBox(height: 24),
              _Bloco(
                titulo: 'Quando',
                linhas: [
                  _Item(
                    Icons.play_arrow,
                    'Inicio',
                    '${Fmt.dataLonga(evento.dataInicio)}, '
                        '${Fmt.hora(evento.dataInicio)}',
                  ),
                  _Item(
                    Icons.stop,
                    'Fim',
                    '${Fmt.dataLonga(evento.dataFim)}, '
                        '${Fmt.hora(evento.dataFim)}',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // O endereco nao e digitado: o back-end preenche via ViaCEP a
              // partir do CEP, entao aqui ele e sempre somente leitura.
              _Bloco(
                titulo: 'Onde',
                linhas: [
                  _Item(Icons.markunread_mailbox_outlined, 'CEP',
                      Fmt.cep(evento.endereco.cep)),
                  _Item(Icons.signpost_outlined, 'Logradouro',
                      evento.endereco.numero == null ||
                              evento.endereco.numero!.isEmpty
                          ? evento.endereco.logradouro
                          : '${evento.endereco.logradouro}, '
                                '${evento.endereco.numero}'),
                  _Item(Icons.holiday_village_outlined, 'Bairro',
                      evento.endereco.bairro),
                  _Item(Icons.location_city, 'Cidade',
                      evento.endereco.cidadeUf),
                ],
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: evento.encerrado || lotado ? null : onInscrever,
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Inscrever participante'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onEditar,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onExcluir,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Excluir'),
                  ),
                ],
              ),
              if (evento.encerrado) ...[
                const SizedBox(height: 12),
                _Aviso(
                  'Este evento ja foi encerrado, por isso a API nao aceita '
                  'novas inscricoes.',
                ),
              ] else if (lotado) ...[
                const SizedBox(height: 12),
                _Aviso(
                  'Todas as $ocupadas vagas estao ocupadas. Cancelar uma '
                  'inscricao libera vaga.',
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Item {
  const _Item(this.icone, this.rotulo, this.valor);
  final IconData icone;
  final String rotulo;
  final String valor;
}

class _Bloco extends StatelessWidget {
  const _Bloco({required this.titulo, required this.linhas});

  final String titulo;
  final List<_Item> linhas;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          for (final linha in linhas)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(linha.icone, size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 92,
                    child: Text(
                      linha.rotulo,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      linha.valor.isEmpty ? '—' : linha.valor,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
