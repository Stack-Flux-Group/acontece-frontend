import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../models/evento.dart';
import '../models/status_inscricao.dart';

/// Cores do selo de uma inscricao: fundo, texto e icone.
///
/// Todas opacas, de proposito: um fundo translucido muda de tom conforme o que
/// esta atras e ja produziu selo ilegivel. Fica separada do widget para o teste
/// de contraste ler os mesmos pares que a tela usa.
///
/// [sobreEscuro] e para o selo dentro de um painel em degrade escuro (o
/// "Voce esta inscrito" do detalhe): la, um selo azul some no fundo azul.
(Color fundo, Color texto, IconData icone) coresStatusInscricao(
  StatusInscricao status,
  ColorScheme scheme, {
  bool sobreEscuro = false,
}) {
  if (sobreEscuro) {
    return switch (status) {
      StatusInscricao.pendente => (
        Paleta.ciano,
        Paleta.marinho,
        Icons.schedule,
      ),
      StatusInscricao.confirmada => (
        Colors.white,
        Paleta.azul,
        Icons.check_circle,
      ),
      StatusInscricao.cancelada => (
        Colors.white,
        const Color(0xFF41606F),
        Icons.cancel_outlined,
      ),
    };
  }
  return switch (status) {
    StatusInscricao.pendente => (
      scheme.secondaryContainer,
      scheme.onSecondaryContainer,
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
}

/// Selo do status de uma inscricao.
class StatusInscricaoChip extends StatelessWidget {
  const StatusInscricaoChip({
    super.key,
    required this.status,
    this.sobreEscuro = false,
  });

  final StatusInscricao status;

  /// Use dentro de painel em degrade escuro.
  final bool sobreEscuro;

  @override
  Widget build(BuildContext context) {
    final (fundo, texto, icone) = coresStatusInscricao(
      status,
      Theme.of(context).colorScheme,
      sobreEscuro: sobreEscuro,
    );
    return Selo(
      fundo: fundo,
      texto: texto,
      icone: icone,
      rotulo: status.rotulo,
    );
  }
}

/// Cores do selo de situacao do evento: fundo, texto e icone. Opacas, e
/// separadas do widget para o teste de contraste.
(Color fundo, Color texto, IconData icone) coresEventoStatus(
  EventoStatus status,
  ColorScheme scheme, {
  bool sobreFoto = false,
}) => switch (status) {
  EventoStatus.agendado => (
    sobreFoto ? Paleta.ciano : scheme.secondaryContainer,
    sobreFoto ? Paleta.marinho : scheme.onSecondaryContainer,
    Icons.event_available,
  ),
  EventoStatus.emAndamento => (Paleta.turquesa, Paleta.marinho, Icons.sensors),
  EventoStatus.encerrado => (
    sobreFoto ? Colors.white : scheme.surfaceContainerHighest,
    scheme.onSurfaceVariant,
    Icons.event_busy,
  ),
};

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
    final (fundo, texto, icone) = coresEventoStatus(
      status,
      Theme.of(context).colorScheme,
      sobreFoto: sobreFoto,
    );
    return Selo(
      fundo: fundo,
      texto: texto,
      icone: icone,
      rotulo: status.rotulo,
      sombra: sobreFoto,
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
    this.sombra = false,
  });

  final Color fundo;
  final Color texto;
  final IconData icone;
  final String rotulo;

  /// Sombra leve, para o selo se destacar sobre uma foto.
  final bool sombra;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: fundo,
      borderRadius: BorderRadius.circular(999),
      boxShadow: sombra
          ? [
              BoxShadow(
                color: Paleta.marinho.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ]
          : null,
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
