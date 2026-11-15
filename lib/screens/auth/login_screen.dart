import 'package:material_ui/material_ui.dart';

import '../../core/api_exception.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../models/participante.dart';
import '../../services.dart';
import '../../widgets/aviso_servidor_lento.dart';
import '../../widgets/error_banner.dart';

/// Porta de entrada do site: entrar ou criar conta de participante.
///
/// Toda rota da API, exceto o login e o cadastro de participante, exige token.
/// Por isso nao ha nada do site visivel antes daqui.
///
/// "Criar conta" so existe para participante: a API nao tem cadastro publico
/// de organizador (o primeiro nasce no back-end por variavel de ambiente).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _criandoConta = false;

  @override
  Widget build(BuildContext context) {
    final tela = Tela.of(context);
    // Vitrine ao lado do formulario so de notebook para cima. No tablet e no
    // celular o formulario vem num cartao sobre o degrade.
    final larga = tela.ehLarga;

    final formulario = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _criandoConta
          ? _CadastroForm(
              key: const ValueKey('cadastro'),
              onVoltar: () => setState(() => _criandoConta = false),
            )
          : _EntrarForm(
              key: const ValueKey('entrar'),
              onCriarConta: () => setState(() => _criandoConta = true),
            ),
    );

    if (larga) {
      return Scaffold(
        body: Row(
          children: [
            const Expanded(flex: 5, child: _Vitrine()),
            Expanded(
              flex: 4,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: formulario,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: Paleta.degradeProfundo),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(tela.margem),
              child: Column(
                children: [
                  const LogoAcontece(tamanho: 40, corTexto: Colors.white),
                  const SizedBox(height: 8),
                  Text(
                    'Eventos que fazem a cidade acontecer',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: Paleta.ciano),
                  ),
                  const SizedBox(height: 24),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(tela.ehCelular ? 20 : 32),
                        child: formulario,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lado esquerdo da tela larga: a marca em destaque.
class _Vitrine extends StatelessWidget {
  const _Vitrine();

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Container(
      decoration: const BoxDecoration(gradient: Paleta.degradeProfundo),
      child: Stack(
        children: [
          // Formas decorativas em ciano e turquesa, bem suaves.
          Positioned(
            top: -120,
            right: -80,
            child: _Circulo(320, Paleta.turquesa.withValues(alpha: 0.18)),
          ),
          Positioned(
            bottom: -160,
            left: -100,
            child: _Circulo(420, Paleta.ciano.withValues(alpha: 0.10)),
          ),
          Positioned(
            bottom: 120,
            right: 60,
            child: _Circulo(90, Paleta.ciano.withValues(alpha: 0.16)),
          ),
          // Rola em janela baixa (notebook pequeno) em vez de estourar.
          LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(56, 48, 56, 48),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight - 96),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LogoAcontece(tamanho: 44, corTexto: Colors.white),
                      const Spacer(),
                      Text(
                        'Eventos que fazem\na cidade acontecer.',
                        style: texto.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Text(
                          'Descubra o que está rolando, garanta sua vaga em poucos '
                          'cliques e acompanhe suas inscrições em um só lugar.',
                          style: texto.titleMedium?.copyWith(
                            color: Paleta.ciano,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                      const Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _Destaque(Icons.event_available, 'Agenda de eventos'),
                          _Destaque(Icons.how_to_reg, 'Inscrição rápida'),
                          _Destaque(
                            Icons.verified_outlined,
                            'Vagas garantidas',
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        '© Acontece',
                        style: texto.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Circulo extends StatelessWidget {
  const _Circulo(this.tamanho, this.cor);

  final double tamanho;
  final Color cor;

  @override
  Widget build(BuildContext context) => Container(
    width: tamanho,
    height: tamanho,
    decoration: BoxDecoration(shape: BoxShape.circle, color: cor),
  );
}

class _Destaque extends StatelessWidget {
  const _Destaque(this.icone, this.texto);

  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Paleta.ciano.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 18, color: Paleta.ciano),
        const SizedBox(width: 8),
        Text(
          texto,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.titulo, required this.subtitulo});

  final String titulo;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: texto.headlineMedium),
        const SizedBox(height: 6),
        Text(
          subtitulo,
          style: texto.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

class _EntrarForm extends StatefulWidget {
  const _EntrarForm({super.key, required this.onCriarConta});

  final VoidCallback onCriarConta;

  @override
  State<_EntrarForm> createState() => _EntrarFormState();
}

class _EntrarFormState extends State<_EntrarForm> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _senha = TextEditingController();

  bool _enviando = false;
  bool _mostrarSenha = false;
  ApiException? _erro;
  String? _aviso;
  bool _leuAviso = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // O aviso de sessao expirada vem da Sessao, que so pode ser lida aqui.
    if (!_leuAviso) {
      _leuAviso = true;
      final sessao = Services.of(context).sessao;
      _aviso = sessao.aviso;
      sessao.limparAviso();
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    setState(() {
      _erro = null;
      _aviso = null;
    });
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() => _enviando = true);
    try {
      await Services.of(context).sessao
          .entrar(email: _email.text, senha: _senha.text);
      // Sucesso: a raiz do app troca esta tela pela casca do site sozinha.
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e;
        _enviando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final erro = _erro;
    final aviso = _aviso;
    return AutofillGroup(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Cabecalho(
              titulo: 'Bem-vindo de volta',
              subtitulo: 'Entre com seu e-mail e senha para continuar.',
            ),
            if (aviso != null) ...[
              _Info(texto: aviso, icone: Icons.lock_clock),
              const SizedBox(height: 16),
            ],
            if (erro != null) ...[
              ErrorBanner(error: erro, dense: true),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: Validators.email,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _senha,
              obscureText: !_mostrarSenha,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _enviando ? null : _entrar(),
              decoration: InputDecoration(
                labelText: 'Senha',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _mostrarSenha ? 'Ocultar senha' : 'Mostrar senha',
                  onPressed: () =>
                      setState(() => _mostrarSenha = !_mostrarSenha),
                  icon: Icon(
                    _mostrarSenha ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              validator: Validators.senhaLogin,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _enviando ? null : _entrar,
              child: _enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Entrar'),
            ),
            AvisoServidorLento(ativo: _enviando),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Ainda não tem conta?',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                TextButton(
                  onPressed: _enviando ? null : widget.onCriarConta,
                  child: const Text('Criar conta'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CadastroForm extends StatefulWidget {
  const _CadastroForm({super.key, required this.onVoltar});

  final VoidCallback onVoltar;

  @override
  State<_CadastroForm> createState() => _CadastroFormState();
}

class _CadastroFormState extends State<_CadastroForm> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _cpf = TextEditingController();
  final _telefone = TextEditingController();
  final _senha = TextEditingController();
  final _confirmacao = TextEditingController();

  bool _enviando = false;
  bool _mostrarSenha = false;
  ApiException? _erro;

  @override
  void dispose() {
    for (final c in [_nome, _email, _cpf, _telefone, _senha, _confirmacao]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _erroDoCampo(String campo) => _erro?.forField(campo);

  /// Cadastra (`POST /participantes`, rota aberta) e ja entra com a mesma
  /// senha, para a pessoa nao ter de digitar tudo de novo.
  Future<void> _cadastrar() async {
    setState(() => _erro = null);
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() => _enviando = true);
    final services = Services.of(context);
    try {
      await services.participantes.criar(
        ParticipanteInput(
          nome: _nome.text,
          email: _email.text,
          cpf: _cpf.text,
          telefone: _telefone.text,
          senha: _senha.text,
        ),
      );
      await services.sessao.entrar(email: _email.text, senha: _senha.text);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e;
        _enviando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final erro = _erro;
    return AutofillGroup(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _enviando ? null : widget.onVoltar,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Voltar para entrar'),
              ),
            ),
            const SizedBox(height: 8),
            const _Cabecalho(
              titulo: 'Criar conta',
              subtitulo: 'Cadastre-se como participante para se inscrever nos eventos.',
            ),
            if (erro != null) ...[
              ErrorBanner(error: erro, dense: true),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _nome,
              maxLength: 120,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: InputDecoration(
                labelText: 'Nome completo',
                prefixIcon: const Icon(Icons.person_outline),
                errorText: _erroDoCampo('nome'),
              ),
              validator: Validators.nome,
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: 'E-mail',
                prefixIcon: const Icon(Icons.mail_outline),
                errorText: _erroDoCampo('email'),
              ),
              validator: Validators.email,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _cpf,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'CPF',
                hintText: '000.000.000-00',
                prefixIcon: const Icon(Icons.badge_outlined),
                errorText: _erroDoCampo('cpf'),
              ),
              validator: Validators.cpf,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _telefone,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              decoration: InputDecoration(
                labelText: 'Telefone (opcional)',
                hintText: '(46) 99988-7766',
                prefixIcon: const Icon(Icons.phone_outlined),
                errorText: _erroDoCampo('telefone'),
              ),
              validator: Validators.telefone,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _senha,
              obscureText: !_mostrarSenha,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Senha',
                helperText: 'Entre 8 e 72 caracteres',
                prefixIcon: const Icon(Icons.lock_outline),
                errorText: _erroDoCampo('senha'),
                suffixIcon: IconButton(
                  tooltip: _mostrarSenha ? 'Ocultar senha' : 'Mostrar senha',
                  onPressed: () =>
                      setState(() => _mostrarSenha = !_mostrarSenha),
                  icon: Icon(
                    _mostrarSenha ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              validator: Validators.senha,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmacao,
              obscureText: !_mostrarSenha,
              decoration: const InputDecoration(
                labelText: 'Confirmar senha',
                prefixIcon: Icon(Icons.lock_reset),
              ),
              validator: (valor) =>
                  valor != _senha.text ? 'As senhas não conferem' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _enviando ? null : _cadastrar,
              child: _enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Criar conta e entrar'),
            ),
            AvisoServidorLento(ativo: _enviando),
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.texto, required this.icone});

  final String texto;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icone, color: scheme.onSecondaryContainer, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
