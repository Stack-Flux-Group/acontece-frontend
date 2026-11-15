import 'package:material_ui/material_ui.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/participante.dart';
import '../../services.dart';
import '../../widgets/error_banner.dart';

/// Cadastro e edicao de participante.
///
/// A criacao manda o `ParticipanteRequest` inteiro. A edicao manda um
/// `ParticipantePatchRequest` com **apenas o que mudou** — e e por isso que o
/// registro original precisa estar em maos, para comparar
/// ([ParticipantePatch.diff]).
class ParticipanteFormScreen extends StatefulWidget {
  const ParticipanteFormScreen({super.key, this.participante});

  /// `null` para cadastrar; preenchido para editar.
  final Participante? participante;

  bool get editando => participante != null;

  @override
  State<ParticipanteFormScreen> createState() => _ParticipanteFormScreenState();
}

class _ParticipanteFormScreenState extends State<ParticipanteFormScreen> {
  final _form = GlobalKey<FormState>();

  late final TextEditingController _nome;
  late final TextEditingController _email;
  late final TextEditingController _cpf;
  late final TextEditingController _telefone;

  bool _salvando = false;
  ApiException? _erro;

  @override
  void initState() {
    super.initState();
    final p = widget.participante;
    _nome = TextEditingController(text: p?.nome ?? '');
    _email = TextEditingController(text: p?.email ?? '');
    _cpf = TextEditingController(text: p == null ? '' : Fmt.cpf(p.cpf));
    _telefone = TextEditingController(
      text: p?.telefone == null ? '' : Fmt.telefone(p!.telefone),
    );
  }

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _cpf.dispose();
    _telefone.dispose();
    super.dispose();
  }

  /// Mensagem de erro que a API devolveu para um campo especifico.
  ///
  /// Quando o 400 vem com `fieldErrors`, mostrar a mensagem junto do campo e
  /// mais util do que so no banner no topo.
  String? _erroDoCampo(String campo) => _erro?.forField(campo);

  Future<void> _salvar() async {
    setState(() => _erro = null);
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() => _salvando = true);
    final repo = Services.of(context).participantes;

    try {
      if (widget.editando) {
        final patch = ParticipantePatch.diff(
          atual: widget.participante!,
          nome: _nome.text,
          email: _email.text,
          cpf: _cpf.text,
          telefone: _telefone.text,
        );
        if (patch.isEmpty) {
          if (!mounted) return;
          mostrarSucesso(context, 'Nada foi alterado.');
          Navigator.of(context).pop(false);
          return;
        }
        await repo.atualizar(widget.participante!.id, patch);
        if (!mounted) return;
        mostrarSucesso(context, 'Participante atualizado.');
      } else {
        final criado = await repo.criar(
          ParticipanteInput(
            nome: _nome.text,
            email: _email.text,
            cpf: _cpf.text,
            telefone: _telefone.text,
          ),
        );
        if (!mounted) return;
        mostrarSucesso(context, '${criado.nome} cadastrado(a).');
      }
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
    final telefoneOriginal = Validators.digits(
      widget.participante?.telefone ?? '',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editando ? 'Editar participante' : 'Novo participante',
        ),
      ),
      body: AbsorbPointer(
        absorbing: _salvando,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 48),
          children: [
            ContentWidth(
              maxWidth: 640,
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
                      controller: _nome,
                      maxLength: 120,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Nome *',
                        errorText: _erroDoCampo('nome'),
                      ),
                      validator: Validators.nome,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'E-mail *',
                        errorText: _erroDoCampo('email'),
                        helperText: 'Precisa ser unico entre os participantes',
                      ),
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _cpf,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'CPF *',
                        hintText: '000.000.000-00',
                        errorText: _erroDoCampo('cpf'),
                        helperText:
                            'Com ou sem pontuacao. Precisa ser unico e valido',
                      ),
                      validator: Validators.cpf,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _telefone,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Telefone',
                        hintText: '(46) 99988-7766',
                        errorText: _erroDoCampo('telefone'),
                        helperText: 'Opcional. 10 ou 11 digitos',
                      ),
                      validator: Validators.telefone,
                    ),

                    if (widget.editando && telefoneOriginal.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Para remover o telefone, deixe o campo vazio e salve.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
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
                                : 'Cadastrar',
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
