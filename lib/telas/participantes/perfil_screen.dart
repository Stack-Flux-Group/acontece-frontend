// =============================================================================
// perfil_screen.dart - ABA "MEU PERFIL" (participante)
// =============================================================================
//
// O participante ve o proprio cadastro, edita os dados, altera a senha, sai da
// conta ou exclui a conta. Reaproveita o ParticipanteFormScreen para a edicao e
// a TrocarSenhaScreen para a senha.
// =============================================================================

import 'package:material_ui/material_ui.dart';

import '../../infraestrutura/api_exception.dart';
import '../../infraestrutura/area_selo.dart';
import '../../infraestrutura/formatters.dart';
import '../../infraestrutura/theme.dart';
import '../../modelos_da_api/auth.dart';
import '../../modelos_da_api/participante.dart';
import '../../services.dart';
import '../../componentes_visuais/async_view.dart';
import '../../componentes_visuais/cabecalho_pagina.dart';
import '../../componentes_visuais/error_banner.dart';
import '../../componentes_visuais/pickers.dart';
import '../home_shell.dart';
import '../autenticacao/trocar_senha_screen.dart';
import 'participante_form_screen.dart';

/// "Meu perfil": o participante ve e edita o proprio cadastro, ou exclui a
/// conta.
///
/// Usa `GET|PATCH|DELETE /participantes/{id}` com o proprio id — a API so
/// permite isso quando o id do caminho e o do token (ou para o organizador).
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key, required this.usuario});

  final UsuarioLogado usuario;

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  /// Incrementado apos editar, para recarregar os dados.
  int _versao = 0;

  /// Busca o proprio cadastro (id vem do usuario logado/token).
  Future<Participante> _carregar() =>
      Services.of(context).participantes.buscarPorId(widget.usuario.id);

  /// Abre o formulario de edicao; se salvou, recarrega.
  Future<void> _editar(Participante participante) async {
    // `push<bool>` empilha a tela e espera o `bool` devolvido no `pop`.
    final salvou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ParticipanteFormScreen(participante: participante),
      ),
    );
    if (salvou == true && mounted) {
      setState(() => _versao++);
      // Nome ou e-mail podem ter mudado: atualiza a identificacao na barra.
      // Sem `await` de proposito: roda em segundo plano e nunca lanca.
      Services.of(context).sessao.sincronizar();
    }
  }

  /// Exclui a propria conta (apos confirmar) e encerra a sessao.
  Future<void> _excluirConta(Participante participante) async {
    final confirmado = await confirmar(
      context,
      titulo: 'Excluir sua conta?',
      mensagem:
          'Seu cadastro será apagado de forma definitiva. Se você tiver '
          'inscrições em eventos, a API vai recusar a exclusão.',
      rotuloConfirmar: 'Excluir conta',
    );
    // Cancelou (ou a tela foi fechada): nada a fazer.
    if (!confirmado || !mounted) return;

    // Guarda o Services antes do `await`.
    final services = Services.of(context);
    try {
      await services.participantes.excluir(participante.id);
      // O token continuaria valido ate expirar, mas apontaria para ninguem.
      // `sair(aviso: ...)` volta ao login explicando o motivo.
      services.sessao.sair(aviso: 'Sua conta foi excluída.');
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
          titulo: 'Meu perfil',
          subtitulo: 'Seus dados de cadastro na plataforma.',
          acoes: [ContaBotao(usuario: widget.usuario)],
        ),
        Expanded(
          child: AsyncView<Participante>(
            reloadKey: _versao,
            load: _carregar,
            builder: (context, participante, _) => ListView(
              padding: folgaFinalDaLista(context),
              children: [
                // Largura maxima de 720 para o conteudo nao esticar demais.
                ContentWidth(
                  maxWidth: 720,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      _CartaoPerfil(participante: participante),
                      const SizedBox(height: 20),
                      // Wrap: os botoes ficam lado a lado e quebram de linha
                      // se faltar espaco.
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _editar(participante),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Editar dados'),
                          ),
                          // Abre a tela de troca de senha (a senha nao faz parte
                          // da edicao de dados: tem rota e tela proprias).
                          OutlinedButton.icon(
                            onPressed: () => abrirTrocarSenha(context),
                            icon: const Icon(Icons.lock_reset),
                            label: const Text('Alterar senha'),
                          ),
                          OutlinedButton.icon(
                            // Encerra a sessao; o main.dart volta ao login.
                            onPressed: () => Services.of(context).sessao.sair(),
                            icon: const Icon(Icons.logout),
                            label: const Text('Sair'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 36),
                      _ZonaDePerigo(
                        onExcluir: () => _excluirConta(participante),
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
  );
}

/// Cartao com avatar, nome e linhas de dados (e-mail, CPF, telefone).
class _CartaoPerfil extends StatelessWidget {
  const _CartaoPerfil({required this.participante});

  final Participante participante;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final telefone = participante.telefone;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Faixa superior em degrade com avatar e nome.
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(gradient: Paleta.degradeVivo),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Paleta.ciano,
                  foregroundColor: Paleta.marinho,
                  child: Text(
                    // Primeira letra do nome em maiuscula; "?" se vazio.
                    participante.nome.isEmpty
                        ? '?'
                        : participante.nome[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        participante.nome,
                        style: texto.titleLarge?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Participante',
                        style: TextStyle(color: Paleta.ciano),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Dados do cadastro.
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            child: Column(
              children: [
                _Linha(Icons.mail_outline, 'E-mail', participante.email),
                _Linha(Icons.badge_outlined, 'CPF', Fmt.cpf(participante.cpf)),
                _Linha(
                  Icons.phone_outlined,
                  'Telefone',
                  // Telefone e opcional: mostra "Não informado" se faltar.
                  telefone == null || telefone.isEmpty
                      ? 'Não informado'
                      : Fmt.telefone(telefone),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha "icone + rotulo + valor" do cartao de perfil.
class _Linha extends StatelessWidget {
  /// Tres parametros posicionais: icone, rotulo e valor.
  const _Linha(this.icone, this.rotulo, this.valor);

  final IconData icone;
  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icone, size: 20, color: scheme.primary),
          const SizedBox(width: 14),
          // Largura fixa para alinhar os valores em coluna.
          SizedBox(
            width: 90,
            child: Text(
              rotulo,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Caixa de borda vermelha com a acao destrutiva "Excluir minha conta".
class _ZonaDePerigo extends StatelessWidget {
  const _ZonaDePerigo({required this.onExcluir});

  final VoidCallback onExcluir;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Excluir conta',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: scheme.error),
          ),
          const SizedBox(height: 6),
          Text(
            'Apaga seu cadastro de forma definitiva. Só é possível quando '
            'você não tem inscrições.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onExcluir,
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Excluir minha conta'),
          ),
        ],
      ),
    );
  }
}
