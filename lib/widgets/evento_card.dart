import 'package:material_ui/material_ui.dart';

import '../core/formatters.dart';
import '../models/evento.dart';
import 'status_chip.dart';

/// Cartao de evento na listagem.
class EventoCard extends StatelessWidget {
  const EventoCard({super.key, required this.evento, required this.onTap});

  final Evento evento;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EventoFoto(url: evento.fotoUrl, altura: 140),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          evento.titulo,
                          style: texto.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      EventoStatusChip(status: evento.status),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _Linha(
                    icone: Icons.calendar_today,
                    texto: Fmt.periodo(evento.dataInicio, evento.dataFim),
                  ),
                  const SizedBox(height: 4),
                  _Linha(
                    icone: Icons.place_outlined,
                    texto: evento.endereco.cidadeUf,
                  ),
                  const SizedBox(height: 4),
                  _Linha(
                    icone: Icons.people_outline,
                    texto: Fmt.vagas(evento.vagas),
                  ),
                  if (evento.descricao.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      evento.descricao,
                      style: texto.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Foto do evento.
///
/// `fotoUrl` e um texto livre na API (sem upload, sem validacao), entao a URL
/// pode estar nula, quebrada ou bloqueada por CORS de imagem. Em qualquer desses
/// casos cai para um fundo neutro em vez de deixar um erro na tela.
class EventoFoto extends StatelessWidget {
  const EventoFoto({super.key, required this.url, required this.altura});

  final String? url;
  final double altura;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      height: altura,
      width: double.infinity,
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.celebration_outlined,
        size: altura / 3,
        color: scheme.outline,
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
        Icon(icone, size: 15, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
