import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_theme.dart';
import '../l10n/locale_provider.dart';
import '../../config/nexus_theme_extension.dart';

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
class _DefaultErrorFallback extends ConsumerStatefulWidget {
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback onRetry;

  const _DefaultErrorFallback({
    required this.error,
    this.stackTrace,
    required this.onRetry,
  });

  @override
  ConsumerState<_DefaultErrorFallback> createState() =>
      _DefaultErrorFallbackState();
}

class _DefaultErrorFallbackState extends ConsumerState<_DefaultErrorFallback> {
  bool _copied = false;

  String get _fullErrorText {
    return '${widget.error.toString()}\n\n'
        '=== STACK TRACE ===\n'
        '${widget.stackTrace?.toString() ?? "(sem stack trace)"}';
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _fullErrorText));
    if (mounted) {
      setState(() => _copied = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _copied = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
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
                  color: context.nexusTheme.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: context.nexusTheme.error,
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
              const SizedBox(height: 24),
              // ── Botões: Tentar novamente + Copiar erro ──
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.nexusTheme.accentPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: widget.onRetry,
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white, size: 18),
                      label: Text(
                        s.retry,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _copied
                            ? const Color(0xFF4CAF50)
                            : Colors.grey[800],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _copyToClipboard,
                      icon: Icon(
                        _copied
                            ? Icons.check_rounded
                            : Icons.copy_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: Text(
                        _copied ? 'Copiado!' : 'Copiar erro',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // ── Stack trace expandível ──
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _fullErrorText,
                      style: const TextStyle(
                        color: context.nexusTheme.error,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
