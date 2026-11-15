import 'package:material_ui/material_ui.dart';

import '../models/evento.dart';
import '../models/status_inscricao.dart';

/// Selo do status de uma inscricao.
class StatusInscricaoChip extends StatelessWidget {
  const StatusInscricaoChip({super.key, required this.status});

  final StatusInscricao status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color fundo, Color texto, IconData icone) = switch (status) {
      StatusInscricao.pendente => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.schedule,
      ),
      StatusInscricao.confirmada => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        Icons.check_circle_outline,
      ),
      StatusInscricao.cancelada => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
        Icons.cancel_outlined,
      ),
    };

    return _Selo(
      fundo: fundo,
      texto: texto,
      icone: icone,
      rotulo: status.rotulo,
    );
  }
}

/// Selo da situacao de um evento no tempo (agendado / em andamento / encerrado).
class EventoStatusChip extends StatelessWidget {
  const EventoStatusChip({super.key, required this.status});

  final EventoStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color fundo, Color texto, IconData icone) = switch (status) {
      EventoStatus.agendado => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        Icons.event_available,
      ),
      EventoStatus.emAndamento => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        Icons.sensors,
      ),
      EventoStatus.encerrado => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
        Icons.event_busy,
      ),
    };

    return _Selo(
      fundo: fundo,
      texto: texto,
      icone: icone,
      rotulo: status.rotulo,
    );
  }
}

/// Selo de ocupacao de vagas: "12/200" ou "Lotado".
class VagasChip extends StatelessWidget {
  const VagasChip({super.key, required this.ocupadas, required this.vagas});

  final int ocupadas;
  final int vagas;

  bool get lotado => ocupadas >= vagas;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Selo(
      fundo: lotado ? scheme.errorContainer : scheme.surfaceContainerHighest,
      texto: lotado ? scheme.onErrorContainer : scheme.onSurfaceVariant,
      icone: lotado ? Icons.block : Icons.people_outline,
      rotulo: lotado ? 'Lotado ($ocupadas/$vagas)' : '$ocupadas/$vagas vagas',
    );
  }
}

class _Selo extends StatelessWidget {
  const _Selo({
    required this.fundo,
    required this.texto,
    required this.icone,
    required this.rotulo,
  });

  final Color fundo;
  final Color texto;
  final IconData icone;
  final String rotulo;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: fundo,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 14, color: texto),
        const SizedBox(width: 6),
        Text(
          rotulo,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: texto,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
