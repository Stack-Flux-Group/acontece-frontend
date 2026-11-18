// =============================================================================
// trocar_senha_screen.dart - TROCA DA PROPRIA SENHA
// =============================================================================
//
// Serve aos dois papeis (participante e organizador): `PATCH /me/senha`.
// A API exige a senha atual mesmo com o token valido, e a nova precisa ter de
// 8 a 72 caracteres e ser diferente da atual. O token em uso continua valendo
// depois da troca, entao a pessoa segue logada.
//
// Estrutura do arquivo:
//   abrirTrocarSenha          -> atalho que empilha esta tela (usado por 3 lugares)
//   TrocarSenhaScreen (+State) -> formulario: valida, envia e mostra o erro da API
//
// Quem chama esta tela: o botao "Alterar senha" de "Meu perfil", a barra lateral
// (home_shell.dart) e o menu de conta do celular.
// =============================================================================

import 'package:material_ui/material_ui.dart';

import '../../infraestrutura/api_exception.dart';
import '../../infraestrutura/area_selo.dart';
import '../../infraestrutura/theme.dart';
import '../../infraestrutura/validators.dart';
import '../../modelos_da_api/auth.dart';
import '../../services.dart';
import '../../componentes_visuais/aviso_servidor_lento.dart';
import '../../componentes_visuais/error_banner.dart';
import '../../componentes_visuais/par_responsivo.dart';

/// Abre a tela de troca de senha por cima da atual. Os pontos de acesso (perfil,
/// barra lateral, menu de conta) chamam esta funcao em vez de repetir o push.
///
/// CONCEITO - Navigator.push: empilha uma tela nova sobre a atual. O botao
/// "voltar" (ou `Navigator.pop`) desempilha e volta para a de baixo.
/// `MaterialPageRoute` e a animacao/rota padrao do Material para essa troca.
/// `push<void>`: esta tela nao devolve nenhum valor ao fechar.
Future<void> abrirTrocarSenha(BuildContext context) => Navigator.of(context)
    .push<void>(MaterialPageRoute(builder: (_) => const TrocarSenhaScreen()));

/// Formulario com a senha atual, a nova e a confirmacao da nova.
///
/// E um `StatefulWidget` porque guarda coisas que mudam enquanto a pessoa usa a
/// tela: o texto dos campos, qual "olhinho" esta aberto, se esta enviando e o
/// erro devolvido pela API.
class TrocarSenhaScreen extends StatefulWidget {
  const TrocarSenhaScreen({super.key});

  @override
  State<TrocarSenhaScreen> createState() => _TrocarSenhaScreenState();
}

class _TrocarSenhaScreenState extends State<TrocarSenhaScreen> {
  /// Chave do formulario, usada para validar todos os campos de uma vez
  /// (`_form.currentState.validate()` roda o `validator` de cada campo).
  final _form = GlobalKey<FormState>();

  /// Controllers guardam (e permitem ler) o texto digitado em cada campo.
  final _atual = TextEditingController();
  final _nova = TextEditingController();
  final _confirmacao = TextEditingController();

  // Um "olhinho" por campo. A confirmacao acompanha o da nova senha: se uma
  // esta visivel, a outra tambem, para a pessoa poder comparar.
  bool _mostrarAtual = false;
  bool _mostrarNova = false;

  /// `true` enquanto o PATCH esta em andamento (desabilita o botao e a tela).
  bool _salvando = false;

  /// Ultimo erro devolvido pela API (ou de rede); nulo = sem erro.
  ApiException? _erro;

  @override
  void dispose() {
    // Todo controller criado precisa ser liberado, senao vaza memoria.
    _atual.dispose();
    _nova.dispose();
    _confirmacao.dispose();
    super.dispose();
  }

  /// Valida no cliente e envia `PATCH /me/senha`.
  ///
  /// A ordem importa: primeiro as regras que o cliente ja conhece (campo vazio,
  /// tamanho, confirmacao diferente); so se tudo passar a API e chamada. Assim
  /// os erros obvios aparecem na hora, sem ida a rede, e os erros que so o
  /// servidor sabe (senha atual errada, 429) vem do corpo da resposta.
  Future<void> _salvar() async {
    // Limpa o erro da tentativa anterior antes de comecar outra.
    setState(() => _erro = null);
    // Para aqui se algum campo for invalido (os erros aparecem nos campos).
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() => _salvando = true);
    // Captura o repositorio antes de qualquer `await`: depois da espera a tela
    // pode ter sido fechada, e `Services.of(context)` nao deve ser usado entao.
    final auth = Services.of(context).auth;
    try {
      // A API devolve 204 (sem corpo); se nao lancar, a troca deu certo.
      await auth.trocarSenha(
        TrocarSenhaInput(senhaAtual: _atual.text, novaSenha: _nova.text),
      );
      // `mounted`: depois de um `await` a tela pode nao existir mais.
      if (!mounted) return;
      mostrarSucesso(context, 'Senha alterada.');
      // Volta para a tela de baixo (perfil ou lista de eventos).
      Navigator.of(context).pop();
      // `on ApiException catch (e)`: pega so esse tipo de erro e o chama de `e`.
    } on ApiException catch (e) {
      if (!mounted) return;
      // Senha atual errada (400), limite de tentativas (429) ou nova invalida:
      // a mensagem da API aparece como veio, e os campos recebem o seu erro.
      setState(() {
        _erro = e;
        _salvando = false;
      });
    }
  }

  /// Botao "olhinho" que mostra/oculta o texto de um campo de senha.
  /// Recebe o estado atual ([visivel]) e a funcao que o inverte ([alternar]).
  Widget _olhinho(bool visivel, VoidCallback alternar) => IconButton(
    tooltip: visivel ? 'Ocultar senha' : 'Mostrar senha',
    onPressed: alternar,
    icon: Icon(visivel ? Icons.visibility_off : Icons.visibility),
  );

  @override
  Widget build(BuildContext context) {
    final erro = _erro;
    return Scaffold(
      appBar: AppBar(title: const Text('Alterar senha')),
      // AbsorbPointer: enquanto salva, engole toques/cliques (evita duplo envio).
      body: AbsorbPointer(
        absorbing: _salvando,
        child: ListView(
          padding: folgaFinalDaLista(context),
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
                      controller: _atual,
                      // `obscureText` esconde os caracteres (bolinhas).
                      obscureText: !_mostrarAtual,
                      decoration: InputDecoration(
                        labelText: 'Senha atual *',
                        // Erro do servidor, mostrado junto do campo (so aparece
                        // se a API mandou `fieldErrors` com este nome).
                        errorText: erro?.forField('senhaAtual'),
                        suffixIcon: _olhinho(
                          _mostrarAtual,
                          () => setState(() => _mostrarAtual = !_mostrarAtual),
                        ),
                      ),
                      // O back-end so exige "nao vazia" para a senha atual.
                      validator: Validators.senhaLogin,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _nova,
                      obscureText: !_mostrarNova,
                      decoration: InputDecoration(
                        labelText: 'Nova senha *',
                        // Texto de ajuda fixo, abaixo do campo.
                        helperText:
                            'Entre 8 e 72 caracteres, diferente da atual',
                        errorText: erro?.forField('novaSenha'),
                        suffixIcon: _olhinho(
                          _mostrarNova,
                          () => setState(() => _mostrarNova = !_mostrarNova),
                        ),
                      ),
                      // O validator e uma funcao anonima porque precisa do que
                      // esta digitado em OUTRO campo (a senha atual), para
                      // recusar uma nova senha igual a ela.
                      validator: (v) => Validators.novaSenha(v, _atual.text),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _confirmacao,
                      // Acompanha o olhinho da nova senha.
                      obscureText: !_mostrarNova,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar nova senha *',
                      ),
                      // So existe no app: a API nao recebe este campo. Serve
                      // para a pessoa nao gravar uma senha digitada errado.
                      validator: (v) =>
                          Validators.confirmacaoSenha(v, _nova.text),
                    ),
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
                            : const Icon(Icons.lock_reset),
                        label: Text(
                          _salvando ? 'Salvando...' : 'Alterar senha',
                        ),
                      ),
                      secundario: TextButton(
                        onPressed: _salvando
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    // Aparece se a espera passar de 8 s (servidor hibernando).
                    AvisoServidorLento(ativo: _salvando),
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
