// =============================================================================
// evento_detail_screen.dart - DETALHE DE UM EVENTO
// =============================================================================
//
// Tela empilhada aberta ao clicar num cartao. Mostra capa, descricao, datas e
// endereco, e um painel lateral que DEPENDE DO PAPEL:
//   * organizador  -> ocupacao de vagas + ver inscricoes / editar / excluir
//   * participante -> a propria inscricao (com "Cancelar inscricao"), ou as
//                     vagas preenchidas e o botao "Quero me inscrever"
//                     (bloqueado quando nao ha vaga)
//
// Estrutura do arquivo:
//   EventoDetailScreen (+ State)  -> carrega dados e executa as acoes
//   _Detalhe                      -> dados carregados (evento + extras do papel)
//   _Conteudo                     -> layout (1 ou 2 colunas)
//   _Capa, _InfoCapa              -> cabecalho com foto
//   _PainelOrganizador / _PainelParticipante / _Painel -> caixa de acoes
//   _BarraOcupacao                -> barra de vagas preenchidas dos dois paineis
//   _Bloco, _Item                 -> cartoes "Quando" e "Onde"
// =============================================================================

import 'package:material_ui/material_ui.dart';

import '../../infraestrutura/api_exception.dart';
import '../../infraestrutura/area_selo.dart';
import '../../infraestrutura/formatters.dart';
import '../../infraestrutura/theme.dart';
import '../../modelos_da_api/auth.dart';
import '../../modelos_da_api/evento.dart';
import '../../modelos_da_api/inscricao.dart';
import '../../modelos_da_api/status_inscricao.dart';
import '../../services.dart';
import '../../componentes_visuais/async_view.dart';
import '../../componentes_visuais/error_banner.dart';
import '../../componentes_visuais/evento_card.dart';
import '../../componentes_visuais/pickers.dart';
import '../../componentes_visuais/status_chip.dart';
import '../inscricoes/inscricoes_list_screen.dart';
import 'evento_form_screen.dart';

/// Detalhe do evento: dados, endereco resolvido pelo CEP e as acoes que o papel
/// permite.
///
///  * organizador: ocupacao de vagas, ver inscricoes, editar e excluir
///  * participante: a propria inscricao neste evento, ou o botao de inscrever-se
class EventoDetailScreen extends StatefulWidget {
  const EventoDetailScreen({
    super.key,
    required this.eventoId,
    required this.usuario,
  });

  /// Recebe so o id: a tela busca o evento atualizado na API.
  final int eventoId;
  final UsuarioLogado usuario;

  @override
  State<EventoDetailScreen> createState() => _EventoDetailScreenState();
}

/// Tudo o que a tela precisa para desenhar: o evento (que ja traz a ocupacao,
/// `vagasDisponiveis`) e, para o participante, a inscricao dele.
///
/// Antes o organizador precisava de uma segunda chamada para contar as
/// inscricoes. Agora a API manda `vagasDisponiveis` dentro do proprio evento,
/// entao os dois papeis leem a ocupacao do mesmo lugar.
class _Detalhe {
  /// `{this.minha}`: parametro nomeado e opcional (fica nulo se omitido).
  const _Detalhe(this.evento, {this.minha});

  final Evento evento;

  /// Inscricao ativa do participante logado neste evento (nula para o
  /// organizador e para quem ainda nao se inscreveu).
  final Inscricao? minha;
}

class _EventoDetailScreenState extends State<EventoDetailScreen> {
  /// Contador que, ao mudar, faz o AsyncView recarregar (ver `reloadKey`).
  int _versao = 0;

  /// `true` se algo mudou e a lista anterior precisa recarregar.
  bool _alterou = false;

  /// `true` enquanto o POST de inscricao esta em andamento.
  bool _inscrevendo = false;

  /// `true` enquanto o cancelamento da propria inscricao esta em andamento
  /// (desabilita o botao, para um segundo toque nao enviar o PATCH de novo).
  bool _cancelando = false;

  bool get _organizador => widget.usuario.ehOrganizador;

  /// Carrega o evento e, para o participante, a inscricao dele.
  Future<_Detalhe> _carregar() async {
    final services = Services.of(context);
    // 1) Dados do evento, ja com as vagas disponiveis.
    final evento = await services.eventos.buscarPorId(widget.eventoId);
    // Organizador nao tem inscricao propria: nao ha nada mais a buscar.
    if (_organizador) return _Detalhe(evento);
    // 2) Participante: procura a inscricao ativa dele neste evento.
    final minha = await services.inscricoes.minhaAtivaNoEvento(evento.id);
    return _Detalhe(evento, minha: minha);
  }

  /// Recarrega a tela e marca que a lista de tras tambem precisa recarregar.
  void _recarregar() => setState(() {
    _versao++;
    _alterou = true;
  });

  /// Abre o formulario de edicao; se salvou, recarrega.
  Future<void> _editar(Evento evento) async {
    // `push<bool>` empilha a tela e espera o `bool` que ela devolver no `pop`.
    final salvou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EventoFormScreen(evento: evento)),
    );
    if (salvou == true && mounted) _recarregar();
  }

  /// Pede confirmacao e exclui o evento.
  Future<void> _excluir(Evento evento) async {
    final confirmado = await confirmar(
      context,
      titulo: 'Excluir "${evento.titulo}"?',
      mensagem:
          'A exclusão é definitiva. Se o evento tiver inscrições, a API vai '
          'recusar a operação.',
    );
    // Cancelou (ou a tela foi fechada): nada a fazer.
    if (!confirmado || !mounted) return;

    try {
      await Services.of(context).eventos.deletar(evento.id);
      if (!mounted) return;
      mostrarSucesso(context, 'Evento excluído.');
      // Volta para a lista avisando que algo mudou.
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      // Ex.: 409 quando ha inscricoes apontando para o evento.
      mostrarErro(context, e);
    }
  }

  /// Abre a lista de inscricoes ja filtrada por este evento.
  Future<void> _verInscricoes(Evento evento) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => InscricoesListScreen(
          usuario: widget.usuario,
          eventoInicial: evento,
        ),
      ),
    );
    // O organizador pode ter cancelado inscricoes: a ocupacao mudou.
    if (mounted) setState(() => _versao++);
  }

  /// `POST /inscricoes` em nome de quem esta logado. A regra (vagas, duplicada,
  /// encerrado) e toda do servidor; a recusa dele e mostrada como vem.
  ///
  /// O botao ja fica desabilitado quando `vagasDisponiveis` e 0, mas a tela pode
  /// estar desatualizada: outra pessoa pode ter tomado a ultima vaga depois que
  /// este evento foi carregado. Por isso o 409 continua sendo tratado abaixo.
  Future<void> _inscrever(Evento evento) async {
    setState(() => _inscrevendo = true);
    try {
      await Services.of(context).inscricoes
          .criar(InscricaoInput(eventoId: evento.id));
      if (!mounted) return;
      mostrarSucesso(
        context,
        'Inscrição feita! Ela fica pendente até o organizador confirmar.',
      );
      _recarregar();
    } on ApiException catch (e) {
      if (!mounted) return;
      mostrarErro(context, e);
      // 409 = a situacao mudou desde que a tela abriu: a ultima vaga foi
      // tomada ("sem vagas") ou a inscricao ja existia. Recarregar mostra o
      // estado de agora: "Vagas esgotadas" ou "Voce esta inscrito".
      // (Nao se confere o TEXTO da mensagem: os dois casos pedem a mesma coisa,
      // buscar o evento de novo.)
      if (e.isConflict) _recarregar();
    } finally {
      // `finally`: sempre desliga o "inscrevendo", dando certo ou nao.
      if (mounted) setState(() => _inscrevendo = false);
    }
  }

  /// `PATCH /inscricoes/{id}/cancelar`: o participante desiste da propria
  /// inscricao e a vaga volta para o evento. Pede confirmacao antes.
  ///
  /// Fluxo: confirmar -> enviar -> recarregar a tela. Ao recarregar, o evento
  /// vem com uma vaga a mais, a inscricao ativa some e o botao "Quero me
  /// inscrever" volta (a API permite se inscrever de novo no mesmo evento).
  Future<void> _cancelarInscricao(Inscricao inscricao) async {
    // `confirmar` abre o dialogo e devolve true so se a pessoa confirmar.
    final ok = await confirmar(
      context,
      titulo: 'Cancelar sua inscrição?',
      mensagem:
          'Sua vaga em "${inscricao.eventoTitulo}" será liberada. O '
          'cancelamento não pode ser desfeito, mas você pode se inscrever '
          'de novo se ainda houver vaga.',
      rotuloConfirmar: 'Cancelar inscrição',
    );
    // Desistiu do cancelamento (ou a tela foi fechada): nada a fazer.
    if (!ok || !mounted) return;

    setState(() => _cancelando = true);
    try {
      // A resposta (a inscricao ja CANCELADA) nao e usada: a tela recarrega.
      await Services.of(context).inscricoes.cancelar(inscricao.id);
      if (!mounted) return;
      mostrarSucesso(context, 'Inscrição cancelada. A vaga foi liberada.');
      _recarregar();
    } on ApiException catch (e) {
      if (!mounted) return;
      // Ex.: 409 (ja cancelada, ex.: pelo organizador) e 400 (evento encerrado).
      mostrarErro(context, e);
      // 409: o organizador ja a cancelou. Recarregar mostra a situacao real.
      if (e.isConflict) _recarregar();
    } finally {
      // Sempre libera o botao, dando certo ou nao.
      if (mounted) setState(() => _cancelando = false);
    }
  }

  /// CONCEITO - PopScope: intercepta o "voltar" (botao do navegador/sistema).
  /// Com `canPop: false` ele nao fecha sozinho; em vez disso chamamos
  /// `pop(_alterou)` para devolver o bool a tela anterior.
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      // `didPop == false` => o sistema tentou voltar e foi bloqueado.
      if (!didPop) Navigator.of(context).pop(_alterou);
    },
    child: Scaffold(
      body: AsyncView<_Detalhe>(
        reloadKey: _versao,
        load: _carregar,
        builder: (context, detalhe, _) => _Conteudo(
          detalhe: detalhe,
          organizador: _organizador,
          inscrevendo: _inscrevendo,
          cancelando: _cancelando,
          onVoltar: () => Navigator.of(context).pop(_alterou),
          onEditar: () => _editar(detalhe.evento),
          onExcluir: () => _excluir(detalhe.evento),
          onVerInscricoes: () => _verInscricoes(detalhe.evento),
          onInscrever: () => _inscrever(detalhe.evento),
          onCancelar: () {
            final minha = detalhe.minha;
            if (minha != null) _cancelarInscricao(minha);
          },
        ),
      ),
    ),
  );
}

/// Layout da tela com os dados ja carregados (sem logica de rede).
class _Conteudo extends StatelessWidget {
  const _Conteudo({
    required this.detalhe,
    required this.organizador,
    required this.inscrevendo,
    required this.cancelando,
    required this.onVoltar,
    required this.onEditar,
    required this.onExcluir,
    required this.onVerInscricoes,
    required this.onInscrever,
    required this.onCancelar,
  });

  final _Detalhe detalhe;
  final bool organizador;
  final bool inscrevendo;
  final bool cancelando;

  // Callbacks: a tela-pai passa as funcoes; este widget so as dispara.
  final VoidCallback onVoltar;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;
  final VoidCallback onVerInscricoes;
  final VoidCallback onInscrever;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    final evento = detalhe.evento;
    final texto = Theme.of(context).textTheme;

    // Coluna principal de informacoes (descricao, quando, onde).
    final informacoes = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // So mostra "Sobre o evento" se a descricao nao for vazia.
        if (evento.descricao.trim().isNotEmpty) ...[
          Text('Sobre o evento', style: texto.titleLarge),
          const SizedBox(height: 10),
          // `height: 1.6` aumenta o espaco entre as linhas do texto.
          Text(evento.descricao, style: texto.bodyLarge?.copyWith(height: 1.6)),
          const SizedBox(height: 28),
        ],
        _Bloco(
          titulo: 'Quando',
          icone: Icons.calendar_month,
          linhas: [
            _Item(
              'Início',
              '${Fmt.dataLonga(evento.dataInicio)}, '
                  '${Fmt.hora(evento.dataInicio)}',
            ),
            _Item(
              'Fim',
              '${Fmt.dataLonga(evento.dataFim)}, ${Fmt.hora(evento.dataFim)}',
            ),
          ],
        ),
        const SizedBox(height: 16),
        // O endereco nao e digitado: o back-end preenche via ViaCEP a partir
        // do CEP, entao aqui ele e sempre somente leitura.
        _Bloco(
          titulo: 'Onde',
          icone: Icons.place,
          linhas: [
            _Item(
              'Logradouro',
              // Acrescenta ", numero" so se houver numero.
              evento.endereco.numero == null || evento.endereco.numero!.isEmpty
                  ? evento.endereco.logradouro
                  : '${evento.endereco.logradouro}, ${evento.endereco.numero}',
            ),
            _Item('Bairro', evento.endereco.bairro),
            _Item('Cidade', evento.endereco.cidadeUf),
            _Item('CEP', Fmt.cep(evento.endereco.cep)),
          ],
        ),
      ],
    );

    // Painel de acoes conforme o papel.
    final painel = organizador
        ? _PainelOrganizador(
            evento: evento,
            onEditar: onEditar,
            onExcluir: onExcluir,
            onVerInscricoes: onVerInscricoes,
          )
        : _PainelParticipante(
            evento: evento,
            minha: detalhe.minha,
            inscrevendo: inscrevendo,
            cancelando: cancelando,
            onInscrever: onInscrever,
            onCancelar: onCancelar,
          );

    return ListView(
      padding: folgaFinalDaLista(context, base: 56),
      children: [
        _Capa(evento: evento, onVoltar: onVoltar),
        const SizedBox(height: 28),
        ContentWidth(
          // Decide pela largura que sobrou ao conteudo (e nao pela da tela):
          // com a barra lateral aberta, um notebook de 1000 px deixa so ~700 px
          // para o conteudo, pouco para duas colunas.
          child: LayoutBuilder(
            builder: (context, c) => c.maxWidth >= 820
                // Largo: informacoes a esquerda e painel (340 px) a direita.
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: informacoes),
                      const SizedBox(width: 28),
                      SizedBox(width: 340, child: painel),
                    ],
                  )
                // Estreito: uma coluna, painel primeiro (acao em destaque).
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [painel, const SizedBox(height: 28), informacoes],
                  ),
          ),
        ),
      ],
    );
  }
}

/// Foto (ou degrade) com o titulo por cima, num veu escuro da paleta.
///
/// A altura e um **minimo**: a capa cresce se o titulo e as informacoes
/// ocuparem mais (titulo de 3 linhas num tablet, por exemplo). Com altura fixa,
/// o conteudo subia por cima do botao "voltar".
class _Capa extends StatelessWidget {
  const _Capa({required this.evento, required this.onVoltar});

  final Evento evento;
  final VoidCallback onVoltar;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final tela = Tela.of(context);
    // Altura minima por faixa de tela. `switch` com padroes de enum;
    // `_` cobre notebook e desktop.
    final alturaMinima = switch (tela) {
      Tela.celular => 270.0,
      Tela.tablet => 290.0,
      _ => 300.0,
    };
    // Stack: camadas (1 foto, 2 veu escuro, 3 conteudo).
    return Stack(
      children: [
        // A foto e o veu preenchem a capa, qualquer que seja a altura final.
        // Positioned.fill = ocupa todo o espaco do Stack.
        Positioned.fill(
          child: EventoFoto(
            url: evento.fotoUrl,
            altura: alturaMinima,
            semente: evento.id,
          ),
        ),
        // Veu: degrade transparente -> quase opaco, para o texto branco ler bem.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Paleta.marinho.withValues(alpha: 0.25),
                  Paleta.marinho.withValues(alpha: 0.9),
                ],
              ),
            ),
          ),
        ),
        ConstrainedBox(
          // minWidth infinito: a capa ocupa a largura toda. Sem isso a Stack solta a
          // largura e o conteudo ficava centralizado, desalinhado do corpo.
          constraints: BoxConstraints(
            minHeight: alturaMinima,
            minWidth: double.infinity,
          ),
          child: SafeArea(
            // Sem protecao embaixo: so o topo precisa fugir do notch.
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              // Com a altura minima forcada, o botao fica no topo e o titulo
              // na base; se o conteudo for maior, a capa so cresce.
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Botao de voltar no canto superior esquerdo.
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: IconButton(
                      tooltip: 'Voltar',
                      onPressed: onVoltar,
                      // Fundo escuro: um branco translucido some em foto clara.
                      style: IconButton.styleFrom(
                        backgroundColor: Paleta.marinho.withValues(alpha: 0.6),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),
                ),
                // Bloco de titulo/infos na base da capa.
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 28),
                  child: ContentWidth(
                    // Largura toda: o ContentWidth centraliza, e sem isto o
                    // titulo curto ficava centrado, fora do alinhamento do corpo.
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          EventoStatusChip(
                            status: evento.status,
                            sobreFoto: true,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            evento.titulo,
                            // Ate 3 linhas; depois corta com "...".
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style:
                                (tela.ehCelular
                                        ? texto.headlineSmall
                                        : texto.headlineMedium)
                                    ?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          // Wrap: periodo e cidade quebram de linha se faltar espaco.
                          Wrap(
                            spacing: 18,
                            runSpacing: 6,
                            children: [
                              _InfoCapa(
                                Icons.schedule,
                                Fmt.periodo(evento.dataInicio, evento.dataFim),
                              ),
                              _InfoCapa(
                                Icons.place_outlined,
                                evento.endereco.cidadeUf,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Linha pequena "icone + texto" sobre a capa.
class _InfoCapa extends StatelessWidget {
  const _InfoCapa(this.icone, this.texto);

  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icone, size: 16, color: Paleta.ciano),
      const SizedBox(width: 6),
      // Flexible: um periodo longo ("10 de dezembro, 09:00 ate 12 de
      // dezembro, 23:00") nao cabe numa linha de celular e precisa quebrar.
      Flexible(
        child: Text(texto, style: const TextStyle(color: Paleta.ciano)),
      ),
    ],
  );
}

/// Painel do organizador: barra de ocupacao + botoes de gestao.
class _PainelOrganizador extends StatelessWidget {
  const _PainelOrganizador({
    required this.evento,
    required this.onEditar,
    required this.onExcluir,
    required this.onVerInscricoes,
  });

  final Evento evento;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;
  final VoidCallback onVerInscricoes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    // Calculado no modelo a partir de `vagasDisponiveis` (da API): pendentes +
    // confirmadas. Nao e mais preciso contar inscricoes por aqui.
    final ocupadas = evento.vagasOcupadas;
    final lotado = evento.lotado;

    return _Painel(
      children: [
        Text('Ocupação', style: texto.titleMedium),
        const SizedBox(height: 14),
        Row(
          // `end` alinha pela base: numero grande e texto pequeno juntos.
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$ocupadas',
              style: texto.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 6),
              child: Text(
                'de ${Fmt.vagas(evento.vagas)}',
                style: texto.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _BarraOcupacao(ocupadas: ocupadas, vagas: evento.vagas),
        const SizedBox(height: 8),
        Text(
          lotado
              ? 'Lotado. Cancelar uma inscrição libera vaga.'
              : 'Pendentes e confirmadas ocupam vaga; canceladas liberam.',
          style: texto.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: onVerInscricoes,
          icon: const Icon(Icons.how_to_reg),
          label: const Text('Ver inscrições'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onEditar,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar'),
        ),
        const SizedBox(height: 10),
        // Botao "Excluir" em vermelho (cor de erro) para indicar perigo.
        OutlinedButton.icon(
          onPressed: onExcluir,
          style: OutlinedButton.styleFrom(
            foregroundColor: scheme.error,
            side: BorderSide(color: scheme.error.withValues(alpha: 0.4)),
          ),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Excluir'),
        ),
      ],
    );
  }
}

/// Barra horizontal com a fracao de vagas preenchidas (vermelha quando lotado).
class _BarraOcupacao extends StatelessWidget {
  const _BarraOcupacao({required this.ocupadas, required this.vagas});

  final int ocupadas;
  final int vagas;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Fracao 0..1 para a barra; `clamp` impede passar de 100%.
    final fracao = vagas == 0 ? 0.0 : (ocupadas / vagas).clamp(0.0, 1.0);
    // ClipRRect: recorta o filho com cantos arredondados.
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: fracao,
        minHeight: 10,
        backgroundColor: scheme.surfaceContainerHighest,
        // Vermelha quando lotado.
        color: ocupadas >= vagas ? scheme.error : scheme.primary,
      ),
    );
  }
}

/// Painel do participante: situacao da inscricao ou botao de se inscrever.
class _PainelParticipante extends StatelessWidget {
  const _PainelParticipante({
    required this.evento,
    required this.minha,
    required this.inscrevendo,
    required this.cancelando,
    required this.onInscrever,
    required this.onCancelar,
  });

  final Evento evento;

  /// Inscricao ativa do participante (nula = ainda nao inscrito).
  final Inscricao? minha;
  final bool inscrevendo;

  /// `true` enquanto o cancelamento da inscricao esta em andamento.
  final bool cancelando;
  final VoidCallback onInscrever;

  /// Disparado pelo botao "Cancelar inscricao" (a tela-pai pede confirmacao e
  /// chama a API; este widget so desenha).
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    final inscricao = minha;

    // Caso 1: ja inscrito -> painel escuro com o status.
    if (inscricao != null) {
      return _Painel(
        destaque: true,
        children: [
          Row(
            children: [
              const Icon(Icons.confirmation_number, color: Paleta.ciano),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Você está inscrito',
                  style: texto.titleMedium?.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            // `sobreEscuro: true` usa as cores do selo para fundo escuro.
            child: StatusInscricaoChip(
              status: inscricao.status,
              sobreEscuro: true,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            inscricao.status == StatusInscricao.pendente
                ? 'Sua inscrição aguarda a confirmação do organizador.'
                : 'Sua vaga está confirmada. Até lá!',
            style: texto.bodyMedium?.copyWith(color: Paleta.ciano),
          ),
          const SizedBox(height: 8),
          Text(
            'Inscrição feita em ${Fmt.dataHora(inscricao.dataInscricao)}',
            style: texto.bodySmall?.copyWith(color: Paleta.ciano),
          ),
          // Evento encerrado vira historico: a API nao deixa mais cancelar
          // (responderia 400), entao o botao nem aparece.
          // `if (...) ...[ ]` insere os widgets da lista so quando a condicao
          // e verdadeira.
          if (!evento.encerrado) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              // `null` desabilita o botao enquanto o cancelamento esta em curso.
              onPressed: cancelando ? null : onCancelar,
              // Cores claras: o painel e escuro (o padrao do botao ficaria
              // escuro sobre escuro, ilegivel).
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Paleta.ciano,
                side: const BorderSide(color: Paleta.ciano),
              ),
              icon: cancelando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.event_busy),
              label: Text(cancelando ? 'Cancelando...' : 'Cancelar inscrição'),
            ),
          ],
        ],
      );
    }

    // Caso 2: nao inscrito -> vagas e botao de inscricao.
    final encerrado = evento.encerrado;
    // Sem vaga: todas as vagas ja foram preenchidas (`vagasDisponiveis == 0`).
    // O botao fica travado ANTES do clique, em vez de so mostrar o erro depois.
    final esgotado = evento.lotado;
    return _Painel(
      children: [
        Text('Inscrição', style: texto.titleMedium),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.people_alt_outlined, color: scheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                // "7/10 vagas preenchidas".
                Fmt.ocupacao(evento.vagasOcupadas, evento.vagas),
                style: texto.bodyLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // A mesma barra do painel do organizador (vermelha quando lotado).
        _BarraOcupacao(ocupadas: evento.vagasOcupadas, vagas: evento.vagas),
        const SizedBox(height: 8),
        // "7 vagas disponiveis" / "Nenhuma vaga disponivel".
        Text(
          Fmt.vagasRestantes(evento.vagasDisponiveis),
          style: texto.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          // Desabilitado (null) se encerrado, sem vaga ou ja enviando.
          onPressed: encerrado || esgotado || inscrevendo ? null : onInscrever,
          icon: inscrevendo
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.how_to_reg),
          // A ordem dos testes importa: encerrado ganha de esgotado, que ganha
          // de "inscrevendo".
          label: Text(
            encerrado
                ? 'Evento encerrado'
                : esgotado
                ? 'Vagas esgotadas'
                : inscrevendo
                ? 'Inscrevendo...'
                : 'Quero me inscrever',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          encerrado
              ? 'Este evento já terminou e não aceita novas inscrições.'
              : esgotado
              ? 'Todas as vagas foram preenchidas. Se uma inscrição for '
                    'cancelada, a vaga volta a ficar disponível.'
              : 'Sua inscrição começa como pendente e é confirmada pelo '
                    'organizador. Se as vagas acabarem, avisamos na hora.',
          style: texto.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Caixa arredondada com sombra que agrupa o conteudo do painel.
/// [destaque] troca o fundo claro pelo degrade escuro da marca.
class _Painel extends StatelessWidget {
  const _Painel({required this.children, this.destaque = false});

  final List<Widget> children;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        // `color` e `gradient` sao alternativos: um dos dois fica nulo.
        color: destaque ? null : scheme.surfaceContainerLowest,
        gradient: destaque ? Paleta.degradeProfundo : null,
        borderRadius: BorderRadius.circular(20),
        border: destaque ? null : Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Paleta.marinho.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Par "rotulo: valor" exibido nos blocos "Quando" e "Onde".
class _Item {
  const _Item(this.rotulo, this.valor);
  final String rotulo;
  final String valor;
}

/// Cartao com titulo + icone e uma lista de [_Item].
class _Bloco extends StatelessWidget {
  const _Bloco({
    required this.titulo,
    required this.icone,
    required this.linhas,
  });

  final String titulo;
  final IconData icone;
  final List<_Item> linhas;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecalho do bloco: quadradinho com icone + titulo.
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icone, size: 18, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Text(titulo, style: texto.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          // Uma linha por item: rotulo (largura fixa) + valor (resto).
          for (final linha in linhas)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: Tela.of(context).ehCelular ? 84 : 100,
                    child: Text(
                      linha.rotulo,
                      style: texto.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      // Valor vazio aparece como travessao.
                      linha.valor.isEmpty ? '—' : linha.valor,
                      style: texto.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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
