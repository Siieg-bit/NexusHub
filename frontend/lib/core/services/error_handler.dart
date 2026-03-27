import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ============================================================================
/// ErrorHandler — Tratamento padronizado de erros para o NexusHub.
///
/// Features:
/// - Tradução de erros do Supabase para mensagens amigáveis
/// - SnackBar padronizado (sucesso, erro, warning, info)
/// - Dialog de erro com detalhes
/// - Logging centralizado
/// - Wrapper try/catch para operações async
/// ============================================================================

class ErrorHandler {
  ErrorHandler._();

  static final GlobalKey<ScaffoldMessengerState> scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();

  // ── SnackBars ──

  static void showSuccess(String message) {
    _showSnackBar(message, _SnackType.success);
  }

  static void showError(String message) {
    _showSnackBar(message, _SnackType.error);
  }

  static void showWarning(String message) {
    _showSnackBar(message, _SnackType.warning);
  }

  static void showInfo(String message) {
    _showSnackBar(message, _SnackType.info);
  }

  static void _showSnackBar(String message, _SnackType type) {
    final messenger = scaffoldKey.currentState;
    if (messenger == null) return;

    Color bgColor;
    IconData icon;

    switch (type) {
      case _SnackType.success:
        bgColor = const Color(0xFF4CAF50);
        icon = Icons.check_circle_rounded;
        break;
      case _SnackType.error:
        bgColor = const Color(0xFFE53935);
        icon = Icons.error_rounded;
        break;
      case _SnackType.warning:
        bgColor = const Color(0xFFFFA726);
        icon = Icons.warning_rounded;
        break;
      case _SnackType.info:
        bgColor = const Color(0xFF42A5F5);
        icon = Icons.info_rounded;
        break;
    }

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: Duration(
          seconds: type == _SnackType.error ? 5 : 3,
        ),
        action: type == _SnackType.error
            ? SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () => messenger.hideCurrentSnackBar(),
              )
            : null,
      ),
    );
  }

  // ── Error Translation ──

  static String translateError(dynamic error) {
    if (error is AuthException) {
      return _translateAuthError(error);
    }
    if (error is PostgrestException) {
      return _translatePostgrestError(error);
    }
    if (error is StorageException) {
      return _translateStorageError(error);
    }

    final msg = error.toString().toLowerCase();

    if (msg.contains('socketexception') || msg.contains('network')) {
      return 'Sem conexão com a internet. Verifique sua rede.';
    }
    if (msg.contains('timeout')) {
      return 'A operação demorou muito. Tente novamente.';
    }
    if (msg.contains('permission') || msg.contains('denied')) {
      return 'Você não tem permissão para realizar esta ação.';
    }

    return 'Algo deu errado. Tente novamente.';
  }

  static String _translateAuthError(AuthException error) {
    final msg = error.message.toLowerCase();

    if (msg.contains('invalid login')) {
      return 'Email ou senha incorretos.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Confirme seu email antes de fazer login.';
    }
    if (msg.contains('user already registered')) {
      return 'Este email já está cadastrado.';
    }
    if (msg.contains('password') && msg.contains('weak')) {
      return 'Senha muito fraca. Use pelo menos 8 caracteres com letras e números.';
    }
    if (msg.contains('rate limit') || msg.contains('too many')) {
      return 'Muitas tentativas. Aguarde alguns minutos.';
    }
    if (msg.contains('invalid email')) {
      return 'Email inválido.';
    }
    if (msg.contains('session expired') || msg.contains('refresh_token')) {
      return 'Sua sessão expirou. Faça login novamente.';
    }

    return 'Erro de autenticação: ${error.message}';
  }

  static String _translatePostgrestError(PostgrestException error) {
    final code = error.code ?? '';
    final msg = error.message.toLowerCase();

    // Unique constraint violation
    if (code == '23505') {
      if (msg.contains('nickname')) return 'Este nickname já está em uso.';
      if (msg.contains('email')) return 'Este email já está cadastrado.';
      if (msg.contains('community_members'))
        return 'Você já é membro desta comunidade.';
      return 'Este item já existe.';
    }
    // Foreign key violation
    if (code == '23503') {
      return 'Referência inválida. O item pode ter sido removido.';
    }
    // Not null violation
    if (code == '23502') {
      return 'Preencha todos os campos obrigatórios.';
    }
    // Check constraint violation
    if (code == '23514') {
      if (msg.contains('coins') || msg.contains('balance')) {
        return 'Saldo insuficiente.';
      }
      return 'Valor inválido.';
    }
    // RLS policy violation
    if (code == '42501' || msg.contains('policy')) {
      return 'Você não tem permissão para realizar esta ação.';
    }
    // Function not found
    if (code == '42883') {
      return 'Funcionalidade temporariamente indisponível.';
    }
    // Raised exception (from RPCs)
    if (code == 'P0001') {
      // Tentar extrair mensagem amigável
      if (msg.contains('insufficient')) return 'Saldo insuficiente.';
      if (msg.contains('not a member'))
        return 'Você não é membro desta comunidade.';
      if (msg.contains('already')) return 'Esta ação já foi realizada.';
      if (msg.contains('rate limit')) return 'Muitas tentativas. Aguarde.';
      return error.message;
    }

    return 'Erro no servidor: ${error.message}';
  }

  static String _translateStorageError(StorageException error) {
    final msg = error.message.toLowerCase();

    if (msg.contains('payload too large') || msg.contains('file size')) {
      return 'Arquivo muito grande. Reduza o tamanho e tente novamente.';
    }
    if (msg.contains('not found')) {
      return 'Arquivo não encontrado.';
    }
    if (msg.contains('permission') || msg.contains('policy')) {
      return 'Sem permissão para fazer upload neste local.';
    }
    if (msg.contains('mime') || msg.contains('type')) {
      return 'Tipo de arquivo não permitido.';
    }

    return 'Erro no upload: ${error.message}';
  }

  // ── Async Wrapper ──

  /// Executa uma operação async com tratamento de erro padronizado.
  /// Retorna o resultado ou null em caso de erro.
  static Future<T?> guard<T>({
    required Future<T> Function() action,
    String? successMessage,
    String? errorMessage,
    bool showErrorSnackBar = true,
    bool showSuccessSnackBar = false,
  }) async {
    try {
      final result = await action();
      if (showSuccessSnackBar && successMessage != null) {
        showSuccess(successMessage);
      }
      return result;
    } catch (e) {
      final msg = errorMessage ?? translateError(e);
      if (showErrorSnackBar) {
        showError(msg);
      }
      debugPrint('ErrorHandler.guard: $e');
      return null;
    }
  }

  /// Executa uma operação async que retorna bool (sucesso/falha).
  static Future<bool> guardBool({
    required Future<void> Function() action,
    String? successMessage,
    String? errorMessage,
  }) async {
    try {
      await action();
      if (successMessage != null) {
        showSuccess(successMessage);
      }
      return true;
    } catch (e) {
      final msg = errorMessage ?? translateError(e);
      showError(msg);
      debugPrint('ErrorHandler.guardBool: $e');
      return false;
    }
  }

  // ── Error Dialog ──

  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? details,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (details != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  details,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Loading Dialog ──

  static Future<T?> withLoading<T>(
    BuildContext context, {
    required Future<T> Function() action,
    String message = 'Carregando...',
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Text(message),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await action();
      if (context.mounted) Navigator.of(context).pop();
      return result;
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      showError(translateError(e));
      return null;
    }
  }
}

enum _SnackType { success, error, warning, info }
