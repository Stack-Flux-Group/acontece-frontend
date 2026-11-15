import 'package:material_ui/material_ui.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/evento.dart';
import 'status_chip.dart';

/// Cartao de evento na listagem.
///
/// **Altura fixa.** Todos os cartoes ocupam exatamente a mesma celula da grade
/// ([EventoCard.altura]), qualquer que seja o conteudo: o titulo reserva duas
/// linhas, a descricao reserva duas linhas (vazia, se nao houver) e o rodape
/// "Ver detalhes" fica sempre colado na base. Sem isso as fileiras da grade
/// ficavam desalinhadas.
class EventoCard extends StatefulWidget {
  const EventoCard({super.key, required this.evento, required this.onTap});

  final Evento evento;
  final VoidCallback onTap;

  /// Altura da foto no topo do cartao.
  static const double alturaFoto = 150;

  /// Altura total do cartao. Cresce com o tamanho de fonte do sistema, para
  /// que texto ampliado nao seja cortado.
  static double altura(BuildContext context) {
    const fixo = 210.0; // foto, espacamentos, divisor
    const texto = 170.0; // titulo, informacoes, descricao e rodape
    return fixo + texto * MediaQuery.textScalerOf(context).scale(1);
  }

  @override
  State<EventoCard> createState() => _EventoCardState();
}

class _EventoCardState extends State<EventoCard> {
  bool _sobre = false;

  @override
  Widget build(BuildContext context) {
    final evento = widget.evento;
    final texto = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    // Duas linhas de titulo, sempre reservadas, para os cartoes de titulo curto
    // nao ficarem com a base mais alta que os de titulo longo.
    final estiloTitulo = texto.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final alturaTitulo =
        MediaQuery.textScalerOf(context).scale(
          (estiloTitulo?.fontSize ?? 16) * (estiloTitulo?.height ?? 1.5),
        ) *
        2;

    return MouseRegion(
      onEnter: (_) => setState(() => _sobre = true),
      onExit: (_) => setState(() => _sobre = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, _sobre ? -4 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Paleta.marinho.withValues(alpha: _sobre ? 0.16 : 0.06),
              blurRadius: _sobre ? 24 : 12,
              offset: Offset(0, _sobre ? 10 : 4),
            ),
          ],
        ),
        child: Card(
          child: InkWell(
            onTap: widget.onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    EventoFoto(
                      url: evento.fotoUrl,
                      altura: EventoCard.alturaFoto,
                      semente: evento.id,
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _DataSelo(data: evento.dataInicio),
                    ),
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
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: alturaTitulo,
                          child: Text(
                            evento.titulo,
                            style: estiloTitulo,
                            maxLines: 2,
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
                          texto: Fmt.vagas(evento.vagas),
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
                        const Spacer(),
                        Divider(color: scheme.outlineVariant),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
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
          data.day.toString().padLeft(2, '0'),
          style: const TextStyle(
            fontSize: 18,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: Paleta.marinho,
          ),
        ),
        Text(
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

  final String? url;
  final double altura;
  final int semente;

  @override
  Widget build(BuildContext context) {
    final cores =
        Paleta.degradesEvento[semente.abs() % Paleta.degradesEvento.length];
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
          Positioned(
            right: -altura * 0.15,
            bottom: -altura * 0.2,
            child: Icon(
              Icons.celebration_rounded,
              size: altura * 0.9,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
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

    final endereco = url?.trim() ?? '';
    if (endereco.isEmpty) return placeholder;

    return Image.network(
      endereco,
      height: altura,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => placeholder,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder,
    );
  }
}

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
