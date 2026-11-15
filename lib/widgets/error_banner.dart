import 'package:material_ui/material_ui.dart';

import '../core/api_exception.dart';
import '../core/theme.dart';

/// Mostra um [ApiException] como o back-end o descreveu.
///
/// As mensagens da API ja vem em portugues e sao especificas ("Evento sem vagas
/// disponiveis", "Ja existe um participante com esse CPF"), entao sao exibidas
/// como estao em vez de trocadas por um texto generico do cliente. Os
/// `fieldErrors` aparecem como lista, porque uma unica requisicao pode reprovar
/// varios campos de uma vez.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({
    super.key,
    required this.error,
    this.onRetry,
    this.dense = false,
  });

  final ApiException error;
  final VoidCallback? onRetry;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final campos = error.fieldErrors;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dense ? 12 : 16),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_icone, color: scheme.onErrorContainer, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titulo,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      error.message,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: scheme.onErrorContainer),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (campos.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final campo in campos)
              Padding(
                padding: const EdgeInsets.only(left: 32, top: 2),
                child: Text(
                  '• ${campo.field}: ${campo.message}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: scheme.onErrorContainer),
                ),
              ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 32),
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar de novo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.onErrorContainer,
                    side: BorderSide(
                      color: scheme.error.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String get _titulo => switch (error.kind) {
    ApiErrorKind.network => 'Sem conexão com a API',
    ApiErrorKind.timeout => 'A API demorou demais',
    ApiErrorKind.payload => 'Resposta inesperada',
    ApiErrorKind.misrouted => 'A requisição não chegou à API',
    ApiErrorKind.http => switch (error.status) {
      400 => 'Dados inválidos',
      401 => 'Acesso não autorizado',
      403 => 'Sem permissão',
      404 => 'Não encontrado',
      409 => 'Operação bloqueada',
      _ when error.isServerError => 'Erro no servidor',
      _ => 'Não foi possível concluir',
    },
  };

  IconData get _icone => switch (error.kind) {
    ApiErrorKind.network => Icons.wifi_off,
    ApiErrorKind.timeout => Icons.hourglass_disabled,
    ApiErrorKind.misrouted => Icons.alt_route,
    ApiErrorKind.http when error.isUnauthorized => Icons.lock_outline,
    ApiErrorKind.http when error.isForbidden => Icons.block,
    _ => Icons.error_outline,
  };
}

/// Mostra um erro da API como snackbar, para acoes pontuais (salvar, excluir).
void mostrarErro(BuildContext context, ApiException error) {
  final scheme = Theme.of(context).colorScheme;
  final detalhe = error.fieldErrors
      .map((f) => '${f.field}: ${f.message}')
      .join(' · ');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: scheme.errorContainer,
      content: Text(
        detalhe.isEmpty ? error.message : '${error.message}\n$detalhe',
        style: TextStyle(color: scheme.onErrorContainer),
      ),
      duration: const Duration(seconds: 6),
    ),
  );
}

/// Confirmacao de sucesso, curta.
void mostrarSucesso(BuildContext context, String mensagem) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: Paleta.petroleo,
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Paleta.ciano, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(mensagem, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}
