// =============================================================================
// participante_form_screen.dart - FORMULARIO DE PARTICIPANTE
// =============================================================================
//
// Usado em dois contextos:
//   * Organizador cadastrando/editando qualquer participante.
//   * Participante editando o proprio cadastro (a partir de "Meu perfil").
//
// Diferenca importante:
//   criar  -> POST  com TODOS os campos (inclusive senha)
//   editar -> PATCH so com o que MUDOU (ParticipantePatch.diff); senha nao existe
// =============================================================================

import 'package:material_ui/material_ui.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/participante.dart';
import '../../services.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/par_responsivo.dart';

/// Cadastro (pelo organizador) e edicao de participante (pelo organizador ou
/// pelo proprio participante, em "Meu perfil").
///
/// A criacao manda o `ParticipanteRequest` inteiro, inclusive a senha com que
/// a pessoa vai entrar. A edicao manda um
/// `ParticipantePatchRequest` com **apenas o que mudou** — e e por isso que o
/// registro original precisa estar em maos, para comparar
/// ([ParticipantePatch.diff]).
class ParticipanteFormScreen extends StatefulWidget {
  const ParticipanteFormScreen({super.key, this.participante});

  /// `null` para cadastrar; preenchido para editar.
  final Participante? participante;

  /// Atalho: estamos editando?
  bool get editando => participante != null;

  @override
  State<ParticipanteFormScreen> createState() => _ParticipanteFormScreenState();
}

class _ParticipanteFormScreenState extends State<ParticipanteFormScreen> {
  /// Chave do formulario, usada para validar todos os campos de uma vez.
  final _form = GlobalKey<FormState>();

  // `late final`: atribuidos no initState (precisam de `widget`).
  late final TextEditingController _nome;
  late final TextEditingController _email;
  late final TextEditingController _cpf;
  late final TextEditingController _telefone;

  /// A senha nao depende de `widget`, entao pode ser criada na declaracao.
  final _senha = TextEditingController();
  bool _mostrarSenha = false;

  bool _salvando = false;
  ApiException? _erro;

  @override
  void initState() {
    super.initState();
    final p = widget.participante;
    // Preenche com os dados atuais (com mascara de CPF/telefone) ou vazio.
    _nome = TextEditingController(text: p?.nome ?? '');
    _email = TextEditingController(text: p?.email ?? '');
    _cpf = TextEditingController(text: p == null ? '' : Fmt.cpf(p.cpf));
    _telefone = TextEditingController(
      text: p?.telefone == null ? '' : Fmt.telefone(p!.telefone),
    );
  }

  @override
  void dispose() {
    // Todo controller criado precisa ser liberado.
    _nome.dispose();
    _email.dispose();
    _cpf.dispose();
    _telefone.dispose();
    _senha.dispose();
    super.dispose();
  }

  /// Mensagem de erro que a API devolveu para um campo especifico.
  ///
  /// Quando o 400 vem com `fieldErrors`, mostrar a mensagem junto do campo e
  /// mais util do que so no banner no topo.
  String? _erroDoCampo(String campo) => _erro?.forField(campo);

  /// Valida e envia: PATCH (editando) ou POST (criando).
  Future<void> _salvar() async {
    setState(() => _erro = null);
    // Para aqui se algum campo for invalido (os erros aparecem nos campos).
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() => _salvando = true);
    // Captura o repositorio antes de qualquer `await`.
    final repo = Services.of(context).participantes;

    try {
      if (widget.editando) {
        // Compara o formulario com o registro atual e monta so o que mudou.
        final patch = ParticipantePatch.diff(
          atual: widget.participante!,
          nome: _nome.text,
          email: _email.text,
          cpf: _cpf.text,
          telefone: _telefone.text,
        );
        // Nada mudou: nao chama a API.
        if (patch.isEmpty) {
          if (!mounted) return;
          mostrarSucesso(context, 'Nada foi alterado.');
          // `false` = nada mudou, a lista nao precisa recarregar.
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
            senha: _senha.text,
          ),
        );
        if (!mounted) return;
        mostrarSucesso(context, '${criado.nome} cadastrado(a).');
      }
      // Salvou: avisa a tela anterior para recarregar.
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
    // So digitos do telefone original (para decidir se mostra a dica de remover).
    final telefoneOriginal = Validators.digits(
      widget.participante?.telefone ?? '',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editando ? 'Editar participante' : 'Novo participante',
        ),
      ),
      // AbsorbPointer: enquanto salva, engole toques/cliques (evita duplo envio).
      body: AbsorbPointer(
        absorbing: _salvando,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 48),
          children: [
            // Largura maxima de 640 para o formulario nao esticar demais.
            ContentWidth(
              maxWidth: 640,
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Banner de erro no topo, se houver.
                    if (erro != null) ...[
                      ErrorBanner(error: erro),
                      const SizedBox(height: 16),
                    ],

                    // TextFormField = campo de texto com suporte a validacao.
                    TextFormField(
                      controller: _nome,
                      // Limite de 120 caracteres (com contador na tela).
                      maxLength: 120,
                      // Cada palavra comeca em maiuscula.
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Nome *',
                        // Erro do servidor, mostrado junto do campo.
                        errorText: _erroDoCampo('nome'),
                      ),
                      // Funcao que devolve null (ok) ou a mensagem de erro.
                      validator: Validators.nome,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'E-mail *',
                        errorText: _erroDoCampo('email'),
                        // Texto de ajuda fixo, abaixo do campo.
                        helperText: 'Precisa ser único entre os participantes',
                      ),
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _cpf,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'CPF *',
                        // Texto cinza de exemplo, some quando a pessoa digita.
                        hintText: '000.000.000-00',
                        errorText: _erroDoCampo('cpf'),
                        helperText:
                            'Com ou sem pontuação. Precisa ser único e válido',
                      ),
                      validator: Validators.cpf,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _telefone,
                      // Teclado de telefone em dispositivos moveis.
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Telefone',
                        hintText: '(46) 99988-7766',
                        errorText: _erroDoCampo('telefone'),
                        helperText: 'Opcional. 10 ou 11 dígitos',
                      ),
                      validator: Validators.telefone,
                    ),

                    // A senha so existe na criacao: o PATCH da API nao a aceita,
                    // entao nao ha como troca-la depois.
                    if (!widget.editando) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _senha,
                        // `obscureText` esconde os caracteres (bolinhas).
                        obscureText: !_mostrarSenha,
                        decoration: InputDecoration(
                          labelText: 'Senha de acesso *',
                          helperText:
                              'Entre 8 e 72 caracteres. É com ela que o '
                              'participante vai entrar no site',
                          errorText: _erroDoCampo('senha'),
                          // Botao "olhinho" para mostrar/ocultar a senha.
                          suffixIcon: IconButton(
                            tooltip: _mostrarSenha
                                ? 'Ocultar senha'
                                : 'Mostrar senha',
                            onPressed: () =>
                                setState(() => _mostrarSenha = !_mostrarSenha),
                            icon: Icon(
                              _mostrarSenha
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                        validator: Validators.senha,
                      ),
                    ],

                    // Dica: so aparece ao editar quem ja tem telefone.
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
                    AcoesFormulario(
                      principal: FilledButton.icon(
                        // `null` desabilita o botao enquanto salva.
                        onPressed: _salvando ? null : _salvar,
                        // Spinner pequeno enquanto salva; icone normal depois.
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
                              ? 'Salvar alterações'
                              : 'Cadastrar',
                        ),
                      ),
                      secundario: TextButton(
                        onPressed: _salvando
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
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
