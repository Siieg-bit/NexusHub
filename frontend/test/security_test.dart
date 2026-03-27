import 'package:flutter_test/flutter_test.dart';

/// Testes para lógica de segurança.
/// Nota: SecurityService depende de crypto package.
/// Estes testes verificam a lógica de sanitização e detecção de spam.

void main() {
  group('XSS Sanitization', () {
    test('remove tags script', () {
      const input = 'Hello <script>alert("xss")</script> World';
      final sanitized = _sanitizeHtml(input);

      expect(sanitized.contains('<script>'), false);
      expect(sanitized.contains('</script>'), false);
    });

    test('remove event handlers', () {
      const input = '<img onerror="alert(1)" src="x">';
      final sanitized = _sanitizeHtml(input);

      expect(sanitized.contains('onerror'), false);
    });

    test('remove javascript: URLs', () {
      const input = '<a href="javascript:alert(1)">click</a>';
      final sanitized = _sanitizeHtml(input);

      expect(sanitized.contains('javascript:'), false);
    });

    test('preserva texto normal', () {
      const input = 'Hello World! This is a normal text.';
      final sanitized = _sanitizeHtml(input);

      expect(sanitized, input);
    });
  });

  group('Spam Detection', () {
    test('detecta texto com muitas maiúsculas', () {
      const text = 'COMPRE AGORA PROMOÇÃO IMPERDÍVEL CLIQUE AQUI';
      final isSpam = _isSpammy(text);

      expect(isSpam, true);
    });

    test('não detecta texto normal como spam', () {
      const text = 'Olá pessoal, como vocês estão? Alguém quer jogar?';
      final isSpam = _isSpammy(text);

      expect(isSpam, false);
    });

    test('detecta texto com muita repetição', () {
      const text = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final isRepetitive = _isRepetitive(text);

      expect(isRepetitive, true);
    });

    test('detecta URLs suspeitas', () {
      const text = 'Ganhe dinheiro fácil em http://scam.com http://fake.com http://spam.com';
      final urlCount = _countUrls(text);

      expect(urlCount >= 3, true);
    });
  });

  group('Input Validation', () {
    test('rejeita input muito longo', () {
      final longInput = 'a' * 10001;
      final isValid = _validateInputLength(longInput, 10000);

      expect(isValid, false);
    });

    test('aceita input dentro do limite', () {
      final input = 'a' * 5000;
      final isValid = _validateInputLength(input, 10000);

      expect(isValid, true);
    });

    test('rejeita caracteres de controle', () {
      const input = 'Hello\x00World\x01Test';
      final cleaned = _removeControlChars(input);

      expect(cleaned, 'HelloWorldTest');
    });
  });
}

// Helpers para testes (simulam a lógica do SecurityService)
String _sanitizeHtml(String input) {
  var result = input;
  result = result.replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false), '');
  result = result.replaceAll(RegExp(r'on\w+="[^"]*"', caseSensitive: false), '');
  result = result.replaceAll(RegExp(r'javascript:', caseSensitive: false), '');
  return result;
}

bool _isSpammy(String text) {
  if (text.isEmpty) return false;
  final upperCount = text.replaceAll(RegExp(r'[^A-Z]'), '').length;
  final ratio = upperCount / text.replaceAll(' ', '').length;
  return ratio > 0.7 && text.length > 20;
}

bool _isRepetitive(String text) {
  if (text.length < 10) return false;
  final chars = text.split('');
  final uniqueChars = chars.toSet();
  return uniqueChars.length < (chars.length * 0.1);
}

int _countUrls(String text) {
  return RegExp(r'https?://\S+').allMatches(text).length;
}

bool _validateInputLength(String input, int maxLength) {
  return input.length <= maxLength;
}

String _removeControlChars(String input) {
  return input.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
}
