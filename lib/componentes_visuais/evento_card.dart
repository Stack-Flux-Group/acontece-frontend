// =============================================================================
// evento_card.dart - CARTAO DE EVENTO (grade) E FOTO DO EVENTO
// =============================================================================
//
// Contem:
//   * EventoCard  -> cartao clicavel da grade de eventos (altura fixa)
//   * _DataSelo   -> "04 DEZ" no canto da foto
//   * EventoFoto  -> foto da URL, ou degrade quando nao ha foto
//   * _Linha      -> linha "icone + texto" do cartao
// =============================================================================

import 'package:material_ui/material_ui.dart';

import '../infraestrutura/formatters.dart';
import '../infraestrutura/theme.dart';
import '../modelos_da_api/evento.dart';
import 'status_chip.dart';

/// Cartao de evento na listagem.
///
/// **Altura fixa.** Todos os cartoes ocupam exatamente a mesma celula da grade
/// ([EventoCard.altura]), qualquer que seja o conteudo: o titulo reserva duas
/// linhas, a descricao reserva duas linhas (vazia, se nao houver) e o rodape
/// "Ver detalhes" fica sempre colado na base. Sem isso as fileiras da grade
/// ficavam desalinhadas.
///
/// E StatefulWidget so para lembrar se o mouse esta em cima (efeito hover).
class EventoCard extends StatefulWidget {
  const EventoCard({super.key, required this.evento, required this.onTap});

  /// Evento exibido.
  final Evento evento;

  /// Chamado ao clicar no cartao (a tela abre o detalhe).
  final VoidCallback onTap;

  /// Altura da foto no topo do cartao.
  static const double alturaFoto = 150;

  /// Altura total do cartao. Cresce com o tamanho de fonte do sistema, para
  /// que texto ampliado nao seja cortado.
  static double altura(BuildContext context) {
    const fixo = 210.0; // foto, espacamentos, divisor
    const texto = 170.0; // titulo, informacoes, descricao e rodape
    // `textScalerOf(context).scale(1)` = fator de ampliacao de texto (1.0 = normal).
    return fixo + texto * MediaQuery.textScalerOf(context).scale(1);
  }

  @override
  State<EventoCard> createState() => _EventoCardState();
}

class _EventoCardState extends State<EventoCard> {
  /// `true` enquanto o ponteiro do mouse esta sobre o cartao.
  bool _sobre = false;

  @override
  Widget build(BuildContext context) {
    // Atalho para o evento do widget.
    final evento = widget.evento;
    final texto = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    // Duas linhas de titulo, sempre reservadas, para os cartoes de titulo curto
    // nao ficarem com a base mais alta que os de titulo longo.
    final estiloTitulo = texto.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    // Altura de 2 linhas = (tamanho da fonte x altura da linha) x 2, ja
    // ajustada pela ampliacao de texto do sistema.
    final alturaTitulo =
        MediaQuery.textScalerOf(context).scale(
          (estiloTitulo?.fontSize ?? 16) * (estiloTitulo?.height ?? 1.5),
        ) *
        2;

    // MouseRegion detecta o mouse entrando/saindo e define o cursor (mao).
    return MouseRegion(
      onEnter: (_) => setState(() => _sobre = true),
      onExit: (_) => setState(() => _sobre = false),
      cursor: SystemMouseCursors.click,
      // AnimatedContainer anima suavemente as mudancas de suas propriedades
      // (sombra e deslocamento) ao longo de 180 ms.
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        // No hover, o cartao "sobe" 4 px.
        transform: Matrix4.translationValues(0, _sobre ? -4 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          // Sombra mais forte e maior no hover.
          boxShadow: [
            BoxShadow(
              color: Paleta.marinho.withValues(alpha: _sobre ? 0.16 : 0.06),
              blurRadius: _sobre ? 24 : 12,
              offset: Offset(0, _sobre ? 10 : 4),
            ),
          ],
        ),
        child: Card(
          // InkWell: torna o cartao clicavel, com efeito "ondulacao".
          child: InkWell(
            onTap: widget.onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Foto com selos sobrepostos.
                Stack(
                  children: [
                    EventoFoto(
                      url: evento.fotoUrl,
                      altura: EventoCard.alturaFoto,
                      // O id define qual degrade usar quando nao ha foto.
                      semente: evento.id,
                    ),
                    // Data no canto superior esquerdo.
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _DataSelo(data: evento.dataInicio),
                    ),
                    // Situacao do evento no canto superior direito.
                    Positioned(
                      top: 12,
                      right: 12,
                      child: EventoStatusChip(
                        status: evento.status,
                        sobreFoto: true,
                      ),
                    ),
                  ],
                ),
                // Expanded: o texto ocupa a altura que sobrou apos a foto.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Caixa de altura fixa (2 linhas) para o titulo.
                        SizedBox(
                          height: alturaTitulo,
                          child: Text(
                            evento.titulo,
                            style: estiloTitulo,
                            maxLines: 2,
                            // Corta com "..." se passar de 2 linhas.
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _Linha(
                          icone: Icons.schedule,
                          texto: Fmt.periodoCurto(
                            evento.dataInicio,
                            evento.dataFim,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _Linha(
                          icone: Icons.place_outlined,
                          texto: evento.endereco.cidadeUf,
                        ),
                        const SizedBox(height: 4),
                        _Linha(
                          icone: Icons.people_alt_outlined,
                          texto: _textoVagas(evento),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          evento.descricao.trim(),
                          style: texto.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Spacer empurra o que vem depois para o fim da coluna
                        // (rodape sempre colado na base).
                        const Spacer(),
                        Divider(color: scheme.outlineVariant),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            // Texto na esquerda e seta na direita.
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Ver detalhes',
                                style: texto.labelLarge?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward,
                                size: 18,
                                color: scheme.primary,
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
          ),
        ),
      ),
    );
  }
}

/// Texto da linha de vagas do cartao: "7/10 vagas preenchidas" ou, com todas
/// as vagas ocupadas, "Lotado (10/10)".
///
/// Funcao solta (fora da classe) e privada ao arquivo por causa do `_`. Fica
/// aqui, e nao no `Fmt`, porque mistura duas regras: o texto muda quando o
/// evento esta lotado. O tamanho do cartao nao muda (a linha tem altura fixa e
/// o texto e cortado com "..." se for longo).
String _textoVagas(Evento evento) => evento.lotado
    ? 'Lotado (${evento.vagasOcupadas}/${evento.vagas})'
    : Fmt.ocupacao(evento.vagasOcupadas, evento.vagas);

/// "04 DEZ" no canto da foto, como num ingresso.
class _DataSelo extends StatelessWidget {
  const _DataSelo({required this.data});

  final DateTime data;

  @override
  Widget build(BuildContext context) => Container(
    width: 50,
    padding: const EdgeInsets.symmetric(vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Paleta.marinho.withValues(alpha: 0.2),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: [
        Text(
          // `padLeft(2, '0')` completa com zero a esquerda: 4 -> "04".
          data.day.toString().padLeft(2, '0'),
          style: const TextStyle(
            fontSize: 18,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: Paleta.marinho,
          ),
        ),
        Text(
          // Mes abreviado em maiusculas ("DEZ").
          Fmt.mesCurto(data),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Paleta.azul,
          ),
        ),
      ],
    ),
  );
}

/// Foto do evento.
///
/// `fotoUrl` e um texto livre na API (sem upload, sem validacao), entao a URL
/// pode estar nula, quebrada ou bloqueada. Em qualquer desses casos cai para um
/// degrade da paleta, sempre o mesmo para o mesmo evento ([semente]).
class EventoFoto extends StatelessWidget {
  const EventoFoto({
    super.key,
    required this.url,
    required this.altura,
    this.semente = 0,
  });

  /// Endereco da imagem (pode ser nulo/vazio/invalido).
  final String? url;

  /// Altura em pixels logicos.
  final double altura;

  /// Numero que escolhe qual degrade usar (normalmente o id do evento).
  final int semente;

  @override
  Widget build(BuildContext context) {
    // Escolhe um degrade da lista pelo resto da divisao (`%`): sempre o
    // mesmo para o mesmo id. `abs()` evita indice negativo.
    final cores =
        Paleta.degradesEvento[semente.abs() % Paleta.degradesEvento.length];
    // Imagem "de mentira": degrade + icone de festa.
    final placeholder = Container(
      height: altura,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: cores,
        ),
      ),
      child: Stack(
        children: [
          // Icone grande e translucido de fundo, cortado no canto.
          Positioned(
            right: -altura * 0.15,
            bottom: -altura * 0.2,
            child: Icon(
              Icons.celebration_rounded,
              size: altura * 0.9,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          // Icone menor centralizado.
          Center(
            child: Icon(
              Icons.celebration_outlined,
              size: altura / 3.2,
              color: Paleta.ciano.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );

    // `?.trim() ?? ''`: sem URL vira texto vazio.
    final endereco = url?.trim() ?? '';
    // Sem URL: usa so o degrade.
    if (endereco.isEmpty) return placeholder;

    // Com URL: baixa a imagem da internet.
    return Image.network(
      endereco,
      height: altura,
      width: double.infinity,
      // `cover` preenche toda a area, cortando o excesso (sem distorcer).
      fit: BoxFit.cover,
      // Falha ao carregar (URL quebrada/bloqueada): mostra o degrade.
      errorBuilder: (_, _, _) => placeholder,
      // Enquanto baixa (`progress != null`), tambem mostra o degrade.
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder,
    );
  }
}

/// Linha "icone + texto" de uma informacao do cartao.
class _Linha extends StatelessWidget {
  const _Linha({required this.icone, required this.texto});

  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icone, size: 15, color: scheme.primary),
        const SizedBox(width: 8),
        // Expanded + ellipsis: texto longo e cortado, nunca estoura a linha.
        Expanded(
          child: Text(
            texto,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
