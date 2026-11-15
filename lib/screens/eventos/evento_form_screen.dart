import 'package:material_ui/material_ui.dart';

import '../../core/api_dates.dart';
import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/evento.dart';
import '../../services.dart';
import '../../widgets/error_banner.dart';

/// Criacao e edicao de evento.
///
/// Duas coisas do back-end moldam esta tela:
///
/// 1. **O endereco nao e digitado.** O `EventoRequestDTO` aceita apenas `cep` e
///    `numero`; logradouro, bairro, cidade e uf vem do ViaCEP, consultado pelo
///    back-end antes de salvar. Entao o formulario tem um campo de CEP, nao seis
///    de endereco.
/// 2. **`PUT` e substituicao total.** Na edicao, o formulario nasce preenchido
///    com todos os valores atuais ([EventoInput.fromEvento]); qualquer campo
///    deixado de fora voltaria como `null`.
class EventoFormScreen extends StatefulWidget {
  const EventoFormScreen({super.key, this.evento});

  /// `null` para criar; preenchido para editar.
  final Evento? evento;

  bool get editando => evento != null;

  @override
  State<EventoFormScreen> createState() => _EventoFormScreenState();
}

class _EventoFormScreenState extends State<EventoFormScreen> {
  final _form = GlobalKey<FormState>();

  late final TextEditingController _titulo;
  late final TextEditingController _descricao;
  late final TextEditingController _vagas;
  late final TextEditingController _cep;
  late final TextEditingController _numero;
  late final TextEditingController _fotoUrl;

  DateTime? _inicio;
  DateTime? _fim;

  bool _salvando = false;
  ApiException? _erro;

  @override
  void initState() {
    super.initState();
    final evento = widget.evento;
    _titulo = TextEditingController(text: evento?.titulo ?? '');
    _descricao = TextEditingController(text: evento?.descricao ?? '');
    _vagas = TextEditingController(text: evento?.vagas.toString() ?? '');
    _cep = TextEditingController(
      text: evento == null ? '' : Fmt.cep(evento.endereco.cep),
    );
    _numero = TextEditingController(text: evento?.endereco.numero ?? '');
    _fotoUrl = TextEditingController(text: evento?.fotoUrl ?? '');
    _inicio = evento?.dataInicio;
    _fim = evento?.dataFim;
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descricao.dispose();
    _vagas.dispose();
    _cep.dispose();
    _numero.dispose();
    _fotoUrl.dispose();
    super.dispose();
  }

  Future<void> _escolherDataHora({required bool inicio}) async {
    final atual =
        (inicio ? _inicio : _fim) ??
        _inicio ??
        ApiDates.nowInSaoPaulo().add(const Duration(days: 1));

    final data = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: inicio ? 'Data de inicio' : 'Data de fim',
    );
    if (data == null || !mounted) return;

    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: atual.hour, minute: atual.minute),
      helpText: inicio ? 'Hora de inicio' : 'Hora de fim',
    );
    if (!mounted) return;

    final escolhido = DateTime(
      data.year,
      data.month,
      data.day,
      hora?.hour ?? atual.hour,
      hora?.minute ?? atual.minute,
    );

    setState(() {
      if (inicio) {
        _inicio = escolhido;
        // Sugere um fim coerente: o back-end exige fim > inicio.
        if (_fim == null || !_fim!.isAfter(escolhido)) {
          _fim = escolhido.add(const Duration(hours: 2));
        }
      } else {
        _fim = escolhido;
      }
    });
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);

    final formOk = _form.currentState?.validate() ?? false;
    final erroPeriodo = Validators.periodoEvento(_inicio, _fim);
    if (!formOk || erroPeriodo != null) {
      if (erroPeriodo != null) {
        setState(() => _erro = ApiException(message: erroPeriodo));
      }
      return;
    }

    final input = EventoInput(
      titulo: _titulo.text.trim(),
      descricao: _descricao.text.trim(),
      dataInicio: _inicio!,
      dataFim: _fim!,
      vagas: int.parse(_vagas.text.trim()),
      cep: _cep.text.trim(),
      numero: _numero.text.trim(),
      fotoUrl: _fotoUrl.text.trim(),
    );

    setState(() => _salvando = true);
    try {
      final repo = Services.of(context).eventos;
      final evento = widget.editando
          ? await repo.atualizar(widget.evento!.id, input)
          : await repo.criar(input);
      if (!mounted) return;
      mostrarSucesso(
        context,
        widget.editando
            ? 'Evento atualizado.'
            : 'Evento "${evento.titulo}" criado.',
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editando ? 'Editar evento' : 'Novo evento'),
      ),
      body: AbsorbPointer(
        absorbing: _salvando,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 48),
          children: [
            ContentWidth(
              maxWidth: 720,
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    if (erro != null) ...[
                      ErrorBanner(error: erro),
                      const SizedBox(height: 16),
                    ],

                    TextFormField(
                      controller: _titulo,
                      maxLength: 100,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Titulo *',
                        helperText: 'Ate 100 caracteres',
                      ),
                      validator: Validators.tituloEvento,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _descricao,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Descricao',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 20),

                    _Secao('Quando'),
                    Row(
                      children: [
                        Expanded(
                          child: _CampoDataHora(
                            rotulo: 'Inicio *',
                            valor: _inicio,
                            onPressed: () => _escolherDataHora(inicio: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CampoDataHora(
                            rotulo: 'Fim *',
                            valor: _fim,
                            onPressed: () => _escolherDataHora(inicio: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _Nota(
                      'As datas sao interpretadas em horario de Brasilia, como '
                      'no back-end. O fim precisa ser depois do inicio.',
                    ),
                    const SizedBox(height: 20),

                    _Secao('Onde'),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _cep,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'CEP *',
                              hintText: '85601-000',
                            ),
                            validator: Validators.cep,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _numero,
                            decoration: const InputDecoration(
                              labelText: 'Numero',
                              hintText: '123',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _Nota(
                      'Rua, bairro e cidade sao preenchidos pelo servidor a '
                      'partir do CEP (consulta ao ViaCEP), por isso salvar pode '
                      'levar alguns segundos.',
                    ),
                    const SizedBox(height: 20),

                    _Secao('Vagas e imagem'),
                    TextFormField(
                      controller: _vagas,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Vagas *',
                        helperText: 'Precisa ser maior que zero',
                      ),
                      validator: Validators.vagas,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fotoUrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'URL da foto',
                        hintText: 'https://...',
                        helperText: 'A API guarda o endereco da imagem, '
                            'nao faz upload de arquivo',
                      ),
                      validator: Validators.fotoUrl,
                    ),

                    if (widget.editando) ...[
                      const SizedBox(height: 16),
                      _Nota(
                        'A edicao reescreve todos os campos do evento e '
                        'reconsulta o CEP. Os valores acima ja vem carregados '
                        'justamente para que nada se perca.',
                      ),
                    ],

                    const SizedBox(height: 28),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: _salvando ? null : _salvar,
                          icon: _salvando
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _salvando
                                ? 'Salvando...'
                                : widget.editando
                                ? 'Salvar alteracoes'
                                : 'Criar evento',
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
            ),
          ],
        ),
      ),
    );
  }
}

class _CampoDataHora extends StatelessWidget {
  const _CampoDataHora({
    required this.rotulo,
    required this.valor,
    required this.onPressed,
  });

  final String rotulo;
  final DateTime? valor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onPressed,
    borderRadius: BorderRadius.circular(4),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: rotulo,
        suffixIcon: const Icon(Icons.event),
      ),
      child: Text(
        valor == null ? 'Escolher data e hora' : Fmt.dataHora(valor!),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: valor == null
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : null,
        ),
      ),
    ),
  );
}

class _Secao extends StatelessWidget {
  const _Secao(this.titulo);

  final String titulo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      titulo.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Nota extends StatelessWidget {
  const _Nota(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Text(
    texto,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
