import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../l10n/locale_provider.dart';

/// Error Boundary global — captura erros de widgets filhos e exibe
/// uma tela de fallback amigável em vez de crashar o app.
///
/// **Política de erros:**
/// - Erros de layout (`RenderFlex overflow`) são **silenciados em produção**
///   e apenas logados em debug — nunca travam a tela.
/// - Erros reais (exceções não tratadas, null pointer, etc.) exibem o
///   fallback de erro com botão "Tentar novamente".
///
/// Este widget deve ficar DENTRO do [MaterialApp] (via `builder`) para
/// herdar automaticamente [Directionality], [Theme], [MediaQuery] e
/// demais InheritedWidgets. Nunca o coloque acima do [MaterialApp].
class ErrorBoundary extends ConsumerStatefulWidget {
  final Widget child;
  final Widget? fallback;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallback,
  });

  @override
  ConsumerState<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends ConsumerState<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  // Guarda o handler original para restaurar ao desmontar
  void Function(FlutterErrorDetails)? _previousErrorHandler;

  /// Retorna true se o erro é apenas um overflow de layout (RenderFlex).
  /// Esses erros NÃO devem travar a tela — são avisos de layout.
  static bool _isLayoutOverflow(FlutterErrorDetails details) {
    final s = getStrings();
    final summary = details.exceptionAsString();
    return summary.contains(s.renderFlexOverflowed) ||
        summary.contains(s.renderFlex) ||
        summary.contains('overflowed by') ||
        (details.exception is FlutterError &&
            (details.exception as FlutterError).message.contains('overflowed'));
  }

  @override
  void initState() {
    final s = getStrings();
    super.initState();
    _previousErrorHandler = FlutterError.onError;

    FlutterError.onError = (FlutterErrorDetails details) {
      // ── Overflow de layout: nunca travar a tela ──────────────────────────
      if (_isLayoutOverflow(details)) {
        // Em debug: loga de forma clara para facilitar o diagnóstico
        assert(() {
          debugPrint(
            '\n╔══════════════════════════════════════════════════════════╗\n'
            '║  ⚠️  OVERFLOW DE LAYOUT DETECTADO                         ║\n'
            '╠══════════════════════════════════════════════════════════╣\n'
            '║  ${details.exceptionAsString().split('\n').first.padRight(56)}║\n'
            '║                                                          ║\n'
            '║  Corrija adicionando Expanded, Flexible ou overflow:     ║\n'
            '${s.textOverflowHint}\n╚══════════════════════════════════════════════════════════╝\n',
          );
          return true;
        }());
        // Em produção: silencioso — o usuário não vê nada, o app continua
        return;
      }

      // ── Erro real: reportar e exibir fallback ────────────────────────────
      // Chama o handler anterior (ex: Firebase Crashlytics) se existir
      if (_previousErrorHandler != null) {
        _previousErrorHandler!(details);
      } else {
        FlutterError.presentError(details);
      }

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _error = details.exception;
              _stackTrace = details.stack;
            });
          }
        });
      }
    };
  }

  @override
  void dispose() {
    FlutterError.onError = _previousErrorHandler;
    super.dispose();
  }

  void _reset() {
    setState(() {
      _error = null;
      _stackTrace = null;
    });
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    if (_error != null) {
      return widget.fallback ??
          _DefaultErrorFallback(
            error: _error!,
            stackTrace: _stackTrace,
            onRetry: _reset,
          );
    }
    return widget.child;
  }
}

/// Tela de fallback padrão exibida quando ocorre um erro não tratado.
class _DefaultErrorFallback extends ConsumerWidget {
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback onRetry;

  const _DefaultErrorFallback({
    required this.error,
    this.stackTrace,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: AppTheme.errorColor,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
               Text(
                s.somethingWentWrong,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                s.unexpectedError,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  label:  Text(
                    s.retry,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Detalhes do erro (apenas em debug)
              if (const bool.fromEnvironment('dart.vm.product') == false)
                ExpansionTile(
                  title: Text(
                    s.errorDetails,
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        error.toString(),
                        style: const TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
