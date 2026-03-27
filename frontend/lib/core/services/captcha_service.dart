import 'package:flutter/material.dart';
import 'dart:math';

/// Serviço de CAPTCHA — proteção anti-bot para ações sensíveis.
///
/// Implementa um CAPTCHA visual simples (math challenge) como placeholder.
/// Para produção, integrar com hCaptcha ou reCAPTCHA via WebView.
///
/// Ações protegidas:
/// - Registro de conta
/// - Reset de senha
/// - Criação de comunidade
/// - Envio massivo de mensagens (rate limit trigger)
class CaptchaService {
  CaptchaService._();

  static final _random = Random();

  /// Exibe um dialog de CAPTCHA e retorna `true` se resolvido corretamente.
  static Future<bool> showCaptcha(BuildContext context, {String? reason}) async {
    final a = _random.nextInt(20) + 1;
    final b = _random.nextInt(20) + 1;
    final ops = ['+', '-', '×'];
    final opIndex = _random.nextInt(3);
    final op = ops[opIndex];

    int answer;
    switch (opIndex) {
      case 0:
        answer = a + b;
        break;
      case 1:
        answer = a - b;
        break;
      case 2:
        answer = a * b;
        break;
      default:
        answer = a + b;
    }

    final controller = TextEditingController();
    bool? result;

    result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: Color(0xFF6C5CE7)),
            SizedBox(width: 8),
            Text('Verificação de Segurança'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reason != null) ...[
              Text(
                reason,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$a $op $b = ?',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(signed: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Resposta',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              onSubmitted: (value) {
                final userAnswer = int.tryParse(value.trim());
                Navigator.pop(ctx, userAnswer == answer);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final userAnswer = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, userAnswer == answer);
            },
            child: const Text('Verificar'),
          ),
        ],
      ),
    );

    return result == true;
  }

  /// Verifica se CAPTCHA é necessário baseado no rate limit.
  ///
  /// Retorna `true` se o usuário precisa resolver CAPTCHA.
  static Future<bool> isRequired(String action) async {
    // Em produção, verificar server-side via RPC
    // Por enquanto, CAPTCHA é requerido em ações específicas
    const protectedActions = [
      'register',
      'reset_password',
      'create_community',
      'mass_message',
    ];
    return protectedActions.contains(action);
  }

  /// Wrapper que verifica CAPTCHA antes de executar uma ação.
  ///
  /// Retorna `true` se a ação pode prosseguir (CAPTCHA resolvido ou não necessário).
  static Future<bool> verifyBeforeAction(
    BuildContext context,
    String action, {
    String? reason,
  }) async {
    final required = await isRequired(action);
    if (!required) return true;

    return showCaptcha(context, reason: reason ?? 'Resolva para continuar');
  }
}
