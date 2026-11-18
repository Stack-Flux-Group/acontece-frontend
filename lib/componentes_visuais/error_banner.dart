// =============================================================================
// error_banner.dart - EXIBICAO PADRONIZADA DE ERROS E SUCESSOS
// =============================================================================
//
// Contem:
//   * ErrorBanner     -> caixa de erro dentro da tela (com "Tentar de novo")
//   * mostrarErro     -> snackbar de erro (aviso temporario)
//   * mostrarSucesso  -> snackbar de sucesso
// =============================================================================

import 'package:material_ui/material_ui.dart';

// ApiException e ApiErrorKind.
import '../infraestrutura/api_exception.dart';
// Paleta (cores da marca).
import '../infraestrutura/theme.dart';

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

  /// O erro a exibir.
  final ApiException error;

  /// Se informado, aparece o botao "Tentar de novo" chamando esta funcao.
  final VoidCallback? onRetry;

  /// Versao compacta (menos espaco interno).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Erros por campo (lista pode ser vazia).
    final campos = error.fieldErrors;

    return Container(
      width: double.infinity,
      // Espaco interno menor na versao compacta.
      padding: EdgeInsets.all(dense ? 12 : 16),
      decoration: BoxDecoration(
        // Cores "error*" do tema: vermelho de fundo e texto contrastante.
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha principal: icone + titulo + mensagem.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_icone, color: scheme.onErrorContainer, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titulo curto conforme o tipo de erro.
                    Text(
                      _titulo,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Mensagem exatamente como veio da API.
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
          // Lista de erros por campo, se houver.
          if (campos.isNotEmpty) ...[
            const SizedBox(height: 8),
            // `for` dentro de lista de widgets: gera um widget por campo.
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
          // Botao de tentar novamente (so se `onRetry` foi passado).
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            // Align: posiciona o filho dentro do espaco (aqui: esquerda).
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

  /// Titulo do erro conforme a categoria e o status HTTP.
  /// `switch` aninhado; `_ when condicao` = caso "qualquer outro" com guarda.
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
      429 => 'Muitas tentativas',
      _ when error.isServerError => 'Erro no servidor',
      _ => 'Não foi possível concluir',
    },
  };

  /// Icone que combina com o tipo de erro.
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
///
/// CONCEITO - SnackBar: barra temporaria no rodape. `ScaffoldMessenger` e o
/// gerenciador que sabe exibi-la sobre o Scaffold da tela atual.
void mostrarErro(BuildContext context, ApiException error) {
  final scheme = Theme.of(context).colorScheme;
  // Junta os erros de campo em uma linha: "cpf: CPF invalido · nome: ...".
  // `map` transforma cada erro em texto; `join` une os textos com o separador.
  final detalhe = error.fieldErrors
      .map((f) => '${f.field}: ${f.message}')
      .join(' · ');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: scheme.errorContainer,
      content: Text(
        // Sem detalhes: so a mensagem; com detalhes: mensagem + quebra + detalhes.
        detalhe.isEmpty ? error.message : '${error.message}\n$detalhe',
        style: TextStyle(color: scheme.onErrorContainer),
      ),
      // Erros ficam mais tempo na tela (6 s) para dar tempo de ler.
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
          // Expanded: o texto ocupa o resto da linha e quebra se for longo.
          Expanded(
            child: Text(mensagem, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}
