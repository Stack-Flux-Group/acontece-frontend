import 'package:material_ui/material_ui.dart';

import '../../core/api_exception.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/auth.dart';
import '../../models/evento.dart';
import '../../models/inscricao.dart';
import '../../models/status_inscricao.dart';
import '../../services.dart';
import '../../widgets/async_view.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/evento_card.dart';
import '../../widgets/pickers.dart';
import '../../widgets/status_chip.dart';
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

  final int eventoId;
  final UsuarioLogado usuario;

  @override
  State<EventoDetailScreen> createState() => _EventoDetailScreenState();
}

class _Detalhe {
  const _Detalhe(this.evento, {this.ocupadas, this.minha});

  final Evento evento;

  /// Vagas ocupadas (PENDENTE + CONFIRMADA). So o organizador consegue contar:
  /// para o participante a API devolve apenas as inscricoes dele.
  final int? ocupadas;

  /// Inscricao ativa do participante logado neste evento.
  final Inscricao? minha;
}

class _EventoDetailScreenState extends State<EventoDetailScreen> {
  int _versao = 0;

  /// `true` se algo mudou e a lista anterior precisa recarregar.
  bool _alterou = false;

  bool _inscrevendo = false;

  bool get _organizador => widget.usuario.ehOrganizador;

  Future<_Detalhe> _carregar() async {
    final services = Services.of(context);
    final evento = await services.eventos.buscarPorId(widget.eventoId);
    if (_organizador) {
      final ocupadas = await services.inscricoes.contarAtivasDoEvento(
        evento.id,
      );
      return _Detalhe(evento, ocupadas: ocupadas);
    }
    final minha = await services.inscricoes.minhaAtivaNoEvento(evento.id);
    return _Detalhe(evento, minha: minha);
  }

  void _recarregar() => setState(() {
    _versao++;
    _alterou = true;
  });

  Future<void> _editar(Evento evento) async {
    final salvou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EventoFormScreen(evento: evento)),
    );
    if (salvou == true && mounted) _recarregar();
  }

  Future<void> _excluir(Evento evento) async {
    final confirmado = await confirmar(
      context,
      titulo: 'Excluir "${evento.titulo}"?',
      mensagem:
          'A exclusão é definitiva. Se o evento tiver inscrições, a API vai '
          'recusar a operação.',
    );
    if (!confirmado || !mounted) return;

    try {
      await Services.of(context).eventos.deletar(evento.id);
      if (!mounted) return;
      mostrarSucesso(context, 'Evento excluído.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      mostrarErro(context, e);
    }
  }

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
    } finally {
      if (mounted) setState(() => _inscrevendo = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
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
          onVoltar: () => Navigator.of(context).pop(_alterou),
          onEditar: () => _editar(detalhe.evento),
          onExcluir: () => _excluir(detalhe.evento),
          onVerInscricoes: () => _verInscricoes(detalhe.evento),
          onInscrever: () => _inscrever(detalhe.evento),
        ),
      ),
    ),
  );
}

class _Conteudo extends StatelessWidget {
  const _Conteudo({
    required this.detalhe,
    required this.organizador,
    required this.inscrevendo,
    required this.onVoltar,
    required this.onEditar,
    required this.onExcluir,
    required this.onVerInscricoes,
    required this.onInscrever,
  });

  final _Detalhe detalhe;
  final bool organizador;
  final bool inscrevendo;
  final VoidCallback onVoltar;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;
  final VoidCallback onVerInscricoes;
  final VoidCallback onInscrever;

  @override
  Widget build(BuildContext context) {
    final evento = detalhe.evento;
    final texto = Theme.of(context).textTheme;

    final informacoes = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (evento.descricao.trim().isNotEmpty) ...[
          Text('Sobre o evento', style: texto.titleLarge),
          const SizedBox(height: 10),
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

    final painel = organizador
        ? _PainelOrganizador(
            evento: evento,
            ocupadas: detalhe.ocupadas ?? 0,
            onEditar: onEditar,
            onExcluir: onExcluir,
            onVerInscricoes: onVerInscricoes,
          )
        : _PainelParticipante(
            evento: evento,
            minha: detalhe.minha,
            inscrevendo: inscrevendo,
            onInscrever: onInscrever,
          );

    return ListView(
      padding: const EdgeInsets.only(bottom: 56),
      children: [
        _Capa(evento: evento, onVoltar: onVoltar),
        const SizedBox(height: 28),
        ContentWidth(
          // Decide pela largura que sobrou ao conteudo (e nao pela da tela):
          // com a barra lateral aberta, um notebook de 1000 px deixa so ~700 px
          // para o conteudo, pouco para duas colunas.
          child: LayoutBuilder(
            builder: (context, c) => c.maxWidth >= 820
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: informacoes),
                      const SizedBox(width: 28),
                      SizedBox(width: 340, child: painel),
                    ],
                  )
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
    final alturaMinima = switch (tela) {
      Tela.celular => 270.0,
      Tela.tablet => 290.0,
      _ => 300.0,
    };
    return Stack(
      children: [
        // A foto e o veu preenchem a capa, qualquer que seja a altura final.
        Positioned.fill(
          child: EventoFoto(
            url: evento.fotoUrl,
            altura: alturaMinima,
            semente: evento.id,
          ),
        ),
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
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              // Com a altura minima forcada, o botao fica no topo e o titulo
              // na base; se o conteudo for maior, a capa so cresce.
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style:
                                (tela.ehCelular
                                        ? texto.headlineSmall
                                        : texto.headlineMedium)
                                    ?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 8),
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

class _PainelOrganizador extends StatelessWidget {
  const _PainelOrganizador({
    required this.evento,
    required this.ocupadas,
    required this.onEditar,
    required this.onExcluir,
    required this.onVerInscricoes,
  });

  final Evento evento;
  final int ocupadas;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;
  final VoidCallback onVerInscricoes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    final fracao = evento.vagas == 0
        ? 0.0
        : (ocupadas / evento.vagas).clamp(0.0, 1.0);
    final lotado = ocupadas >= evento.vagas;

    return _Painel(
      children: [
        Text('Ocupação', style: texto.titleMedium),
        const SizedBox(height: 14),
        Row(
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
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fracao,
            minHeight: 10,
            backgroundColor: scheme.surfaceContainerHighest,
            color: lotado ? scheme.error : scheme.primary,
          ),
        ),
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

class _PainelParticipante extends StatelessWidget {
  const _PainelParticipante({
    required this.evento,
    required this.minha,
    required this.inscrevendo,
    required this.onInscrever,
  });

  final Evento evento;
  final Inscricao? minha;
  final bool inscrevendo;
  final VoidCallback onInscrever;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    final inscricao = minha;

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
        ],
      );
    }

    final encerrado = evento.encerrado;
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
                '${Fmt.vagas(evento.vagas)} no total',
                style: texto.bodyLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: encerrado || inscrevendo ? null : onInscrever,
          icon: inscrevendo
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.how_to_reg),
          label: Text(
            encerrado
                ? 'Evento encerrado'
                : inscrevendo
                ? 'Inscrevendo...'
                : 'Quero me inscrever',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          encerrado
              ? 'Este evento já terminou e não aceita novas inscrições.'
              : 'Sua inscrição começa como pendente e é confirmada pelo '
                    'organizador. Se as vagas acabarem, avisamos na hora.',
          style: texto.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

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

class _Item {
  const _Item(this.rotulo, this.valor);
  final String rotulo;
  final String valor;
}

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
