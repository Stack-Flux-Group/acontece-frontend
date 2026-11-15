import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
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
        Paleta.ciano.withValues(alpha: 0.55),
        Paleta.petroleo,
        Icons.schedule,
      ),
      StatusInscricao.confirmada => (
        Paleta.azul,
        Colors.white,
        Icons.check_circle,
      ),
      StatusInscricao.cancelada => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
        Icons.cancel_outlined,
      ),
    };

    return Selo(
      fundo: fundo,
      texto: texto,
      icone: icone,
      rotulo: status.rotulo,
    );
  }
}

/// Selo da situacao de um evento no tempo (agendado / em andamento / encerrado).
class EventoStatusChip extends StatelessWidget {
  const EventoStatusChip({
    super.key,
    required this.status,
    this.sobreFoto = false,
  });

  final EventoStatus status;

  /// Sobre a foto do evento o selo ganha fundo opaco, para continuar legivel.
  final bool sobreFoto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color fundo, Color texto, IconData icone) = switch (status) {
      EventoStatus.agendado => (
        sobreFoto ? Paleta.ciano : Paleta.ciano.withValues(alpha: 0.6),
        Paleta.marinho,
        Icons.event_available,
      ),
      EventoStatus.emAndamento => (
        Paleta.turquesa,
        Paleta.marinho,
        Icons.sensors,
      ),
      EventoStatus.encerrado => (
        sobreFoto ? Colors.white : scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
        Icons.event_busy,
      ),
    };

    return Selo(
      fundo: fundo,
      texto: texto,
      icone: icone,
      rotulo: status.rotulo,
    );
  }
}

/// Selo de ocupacao de vagas: "12/200 vagas" ou "Lotado".
class VagasChip extends StatelessWidget {
  const VagasChip({super.key, required this.ocupadas, required this.vagas});

  final int ocupadas;
  final int vagas;

  bool get lotado => ocupadas >= vagas;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Selo(
      fundo: lotado ? scheme.errorContainer : scheme.secondaryContainer,
      texto: lotado ? scheme.onErrorContainer : scheme.onSecondaryContainer,
      icone: lotado ? Icons.block : Icons.people_alt_outlined,
      rotulo: lotado ? 'Lotado ($ocupadas/$vagas)' : '$ocupadas/$vagas vagas',
    );
  }
}

/// Pilula com icone e texto, base dos selos acima.
class Selo extends StatelessWidget {
  const Selo({
    super.key,
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
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: texto, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
