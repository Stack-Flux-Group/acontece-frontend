import 'package:material_ui/material_ui.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/evento.dart';
import '../../models/inscricao.dart';
import '../../models/participante.dart';
import '../../services.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/pickers.dart';

/// Nova inscricao: escolher um participante e um evento.
///
/// Como a API nao tem login, nao existe "me inscrever": toda inscricao diz
/// explicitamente quem e o participante.
///
/// Toda a regra fica no servidor, e de proposito. O cliente nao tenta adivinhar
/// se ha vaga nem se ja existe inscricao: ele envia o pedido e mostra a recusa
/// da API, que e a unica que enxerga o estado real (a contagem de vagas roda
/// dentro de uma transacao com a linha do evento travada, para que inscricoes
/// simultaneas nao furem o limite).
class InscricaoFormScreen extends StatefulWidget {
  const InscricaoFormScreen({super.key, this.eventoInicial});

  /// Pre-seleciona o evento, quando a inscricao parte do detalhe dele.
  final Evento? eventoInicial;

  @override
  State<InscricaoFormScreen> createState() => _InscricaoFormScreenState();
}

class _InscricaoFormScreenState extends State<InscricaoFormScreen> {
  Participante? _participante;
  Evento? _evento;

  bool _salvando = false;
  ApiException? _erro;

  @override
  void initState() {
    super.initState();
    _evento = widget.eventoInicial;
  }

  bool get _pronto => _participante != null && _evento != null;

  Future<void> _selecionarParticipante() async {
    final escolhido = await escolherParticipante(
      context,
      Services.of(context).participantes,
    );
    if (escolhido != null && mounted) {
      setState(() => _participante = escolhido);
    }
  }

  Future<void> _selecionarEvento() async {
    final escolhido = await escolherEvento(
      context,
      Services.of(context).eventos,
    );
    if (escolhido != null && mounted) setState(() => _evento = escolhido);
  }

  Future<void> _salvar() async {
    if (!_pronto) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });

    try {
      await Services.of(context).inscricoes.criar(
        InscricaoInput(
          participanteId: _participante!.id,
          eventoId: _evento!.id,
        ),
      );
      if (!mounted) return;
      mostrarSucesso(
        context,
        'Inscricao criada com status pendente.',
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e;
        _salvando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final erro = _erro;
    final evento = _evento;

    return Scaffold(
      appBar: AppBar(title: const Text('Nova inscricao')),
      body: AbsorbPointer(
        absorbing: _salvando,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 48),
          children: [
            ContentWidth(
              maxWidth: 640,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  if (erro != null) ...[
                    ErrorBanner(error: erro),
                    const SizedBox(height: 16),
                  ],

                  _Escolha(
                    icone: Icons.person_outline,
                    rotulo: 'Participante',
                    valor: _participante?.nome,
                    detalhe: _participante == null
                        ? null
                        : '${_participante!.email} · '
                              '${Fmt.cpf(_participante!.cpf)}',
                    onPressed: _selecionarParticipante,
                  ),
                  const SizedBox(height: 12),
                  _Escolha(
                    icone: Icons.event_outlined,
                    rotulo: 'Evento',
                    valor: evento?.titulo,
                    detalhe: evento == null
                        ? null
                        : '${Fmt.dataHora(evento.dataInicio)} · '
                              '${evento.endereco.cidadeUf} · '
                              '${Fmt.vagas(evento.vagas)}',
                    onPressed: _selecionarEvento,
                  ),

                  if (evento != null && evento.encerrado) ...[
                    const SizedBox(height: 16),
                    ErrorBanner(
                      dense: true,
                      error: ApiException(
                        message:
                            'Este evento terminou em '
                            '${Fmt.dataHora(evento.dataFim)}. A API recusa '
                            'inscricoes em eventos encerrados.',
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  _Explicacao(),

                  const SizedBox(height: 28),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _pronto && !_salvando ? _salvar : null,
                        icon: _salvando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.how_to_reg),
                        label: Text(
                          _salvando ? 'Inscrevendo...' : 'Criar inscricao',
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: _salvando
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Explicacao extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'O que o servidor valida',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          for (final regra in const [
            'O evento nao pode estar encerrado.',
            'O participante nao pode ter inscricao ativa no mesmo evento '
                '(pendente ou confirmada).',
            'Precisa haver vaga: cancelar uma inscricao libera vaga de volta.',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $regra',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'A inscricao nasce como pendente; confirmar ou cancelar e feito '
            'depois, na lista.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Escolha extends StatelessWidget {
  const _Escolha({
    required this.icone,
    required this.rotulo,
    required this.valor,
    required this.detalhe,
    required this.onPressed,
  });

  final IconData icone;
  final String rotulo;
  final String? valor;
  final String? detalhe;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final vazio = valor == null;
    return Card(
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icone, color: scheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rotulo,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vazio ? 'Toque para escolher' : valor!,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: vazio ? scheme.onSurfaceVariant : null,
                        fontWeight: vazio ? null : FontWeight.w600,
                      ),
                    ),
                    if (detalhe != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        detalhe!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
