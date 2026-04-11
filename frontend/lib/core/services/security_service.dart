import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import '../l10n/locale_provider.dart';

/// Serviço de Segurança — sanitização e validação.
///
/// Implementa:
/// - Sanitização de input contra XSS
/// - Validação de dados antes de enviar ao servidor
/// - Detecção de spam
/// - Hash SHA-256 para cache keys
///
/// Nota: Toda validação de integridade (HMAC) deve ocorrer no backend
/// via Edge Functions ou RLS policies.
class SecurityService {
  /// Sanitiza texto contra XSS (remove tags HTML perigosas)
  static String sanitizeHtml(String input) {
    // Remove script tags
    var sanitized = input.replaceAll(
        RegExp(r'<script[^>]*>.*?</script>',
            caseSensitive: false, dotAll: true),
        '');

    // Remove event handlers (onclick, onerror, etc.)
    sanitized = sanitized.replaceAll(
        RegExp(r"""\s+on\w+\s*=\s*["'][^"']*["']""", caseSensitive: false), '');

    // Remove javascript: URLs
    sanitized = sanitized.replaceAll(
        RegExp(r'javascript\s*:', caseSensitive: false), '');

    // Remove data: URLs em src/href (podem conter scripts)
    sanitized = sanitized.replaceAll(
        RegExp(r"""(src|href)\s*=\s*["']data:""", caseSensitive: false), '');

    // Remove iframe, object, embed tags
    sanitized = sanitized.replaceAll(
        RegExp(
            r'<(iframe|object|embed|form)[^>]*>.*?</(iframe|object|embed|form)>',
            caseSensitive: false,
            dotAll: true),
        '');

    return sanitized;
  }

  /// Sanitiza texto simples (remove todas as tags HTML)
  static String sanitizePlainText(String input) {
    return input.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }

  /// Valida um nome de usuário
  static String? validateUsername(String username) {
    final s = getStrings();
    if (username.length < 3) return s.min3Chars;
    if (username.length > 24) return s.max24Chars;
    if (!RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(username)) {
      final s = getStrings();
      return s.usernameCharsAllowed;
    }
    // Palavras proibidas
    final banned = ['admin', 'moderator', 'nexushub', 'system', 'support'];
    if (banned.any((w) => username.toLowerCase().contains(w))) {
      final s = getStrings();
      return s.usernameNotAllowed;
    }
    return null;
  }

  /// Valida uma bio/descrição
  static String? validateBio(String bio) {
    final s = getStrings();
    if (bio.length > 500) return s.max500Chars;
    return null;
  }

  /// Valida conteúdo de post
  static String? validatePostContent(String content) {
    final s = getStrings();
    if (content.trim().isEmpty) return s.contentCannotBeEmpty;
    if (content.length > 10000) return s.max10000Chars;
    return null;
  }

  /// Valida URL de imagem
  static bool isValidImageUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme || (!uri.isScheme('https') && !uri.isScheme('http'))) {
        return false;
      }
      final ext = uri.path.toLowerCase();
      return ext.endsWith('.jpg') ||
          ext.endsWith('.jpeg') ||
          ext.endsWith('.png') ||
          ext.endsWith('.gif') ||
          ext.endsWith('.webp') ||
          ext.endsWith('.svg');
    } catch (_) {
      return false;
    }
  }

  /// Gera um hash SHA-256 de uma string (útil para cache keys)
  static String hashString(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }

  /// Verifica se o conteúdo contém spam patterns
  static bool isSpam(String content) {
    final spamPatterns = [
      RegExp(r'(.)\1{10,}'), // Caractere repetido 10+ vezes
      RegExp(r'(https?://\S+\s*){5,}'), // 5+ links seguidos
      RegExp(r'(?:buy|free|click|subscribe|follow)\s+(?:now|here|me)',
          caseSensitive: false),
    ];

    for (final pattern in spamPatterns) {
      if (pattern.hasMatch(content)) return true;
    }
    return false;
  }

  /// Log de ação de segurança
  static Future<void> logSecurityEvent({
    required String event,
    Map<String, dynamic>? details,
  }) async {
    try {
      final userId = SupabaseService.currentUserId;
      await SupabaseService.table('security_logs').insert({
        'user_id': userId,
        'event': event,
        'details': details != null ? jsonEncode(details) : null,
        'ip_address': null, // Não acessível no Flutter
      });
    } catch (e) {
      debugPrint('[Security] Erro ao registrar evento: $e');
    }
  }
}
