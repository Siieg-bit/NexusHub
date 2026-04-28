// =============================================================================
// OgTagsMetaService — Extrai título e thumbnail via Open Graph tags
//
// Estratégia principal: JavaScript injetado no WebView para ler as OG tags
// já presentes na página carregada (zero requisição extra de rede).
//
// Estratégia de fallback: requisição HTTP direta + parsing de <head> com
// regex simples (sem dependência de html_parser).
//
// Usado para plataformas DRM (Netflix, Disney+, Prime, Max, Crunchyroll)
// e URLs genéricas (WEB) onde o usuário já está na página correta.
// =============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

class OgTagsMetaResult {
  final String title;
  final String? thumbnailUrl;

  const OgTagsMetaResult({required this.title, this.thumbnailUrl});
}

class OgTagsMetaService {
  // ── Via WebView (preferido para páginas DRM já abertas) ───────────────────

  /// Injeta JavaScript no WebView para ler as OG tags da página atual.
  /// Retorna null se o WebView não estiver disponível ou se as tags não
  /// existirem.
  static Future<OgTagsMetaResult?> resolveFromWebView(
    InAppWebViewController controller,
  ) async {
    try {
      final result = await controller.evaluateJavascript(source: '''
        (function() {
          function getMeta(property) {
            var el = document.querySelector(
              'meta[property="' + property + '"], meta[name="' + property + '"]'
            );
            return el ? el.getAttribute("content") : null;
          }
          var title = getMeta("og:title")
            || getMeta("twitter:title")
            || document.title
            || null;
          var image = getMeta("og:image")
            || getMeta("twitter:image")
            || getMeta("twitter:image:src")
            || null;
          return JSON.stringify({ title: title, image: image });
        })();
      ''');

      if (result == null) return null;

      final raw = result.toString();
      // O resultado pode vir com aspas extras dependendo do WebView
      final jsonStr = raw.startsWith('"') ? jsonDecode(raw) as String : raw;
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      final title = data['title'] as String?;
      final image = data['image'] as String?;

      if (title == null || title.isEmpty) return null;

      debugPrint('[OgTags] WebView: "$title" image=$image');
      return OgTagsMetaResult(
        title: title.trim(),
        thumbnailUrl: image,
      );
    } catch (e) {
      debugPrint('[OgTags] WebView JS falhou: $e');
      return null;
    }
  }

  // ── Via HTTP (fallback para páginas sem WebView) ───────────────────────────

  /// Faz uma requisição HTTP e extrai OG tags do HTML com regex.
  /// Mais lento que o WebView mas funciona sem contexto de browser.
  static Future<OgTagsMetaResult?> resolveFromHttp(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      // Limitar o HTML ao <head> para evitar parsing de páginas enormes
      final body = response.body;
      final headEnd = body.indexOf('</head>');
      final head = headEnd > 0 ? body.substring(0, headEnd) : body;

      String? title = _extractOgTag(head, 'og:title') ??
          _extractOgTag(head, 'twitter:title') ??
          _extractTitleTag(head);

      String? image = _extractOgTag(head, 'og:image') ??
          _extractOgTag(head, 'twitter:image') ??
          _extractOgTag(head, 'twitter:image:src');

      if (title == null || title.isEmpty) return null;

      // Decodificar entidades HTML básicas
      title = _decodeHtmlEntities(title.trim());

      debugPrint('[OgTags] HTTP: "$title" image=$image');
      return OgTagsMetaResult(title: title, thumbnailUrl: image);
    } catch (e) {
      debugPrint('[OgTags] HTTP falhou para $url: $e');
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String? _extractOgTag(String html, String property) {
    final patterns = [
      RegExp(
        'meta[^>]+property=["\']${RegExp.escape(property)}["\'][^>]+content=["\']([^"\']+)["\']',
        caseSensitive: false,
      ),
      RegExp(
        'meta[^>]+content=["\']([^"\']+)["\'][^>]+property=["\']${RegExp.escape(property)}["\']',
        caseSensitive: false,
      ),
      RegExp(
        'meta[^>]+name=["\']${RegExp.escape(property)}["\'][^>]+content=["\']([^"\']+)["\']',
        caseSensitive: false,
      ),
      RegExp(
        'meta[^>]+content=["\']([^"\']+)["\'][^>]+name=["\']${RegExp.escape(property)}["\']',
        caseSensitive: false,
      ),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(html);
      if (m != null) return m.group(1);
    }
    return null;
  }

  static String? _extractTitleTag(String html) {
    final m = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false)
        .firstMatch(html);
    return m?.group(1);
  }

  static String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'&#(\d+);'), (match) {
          final code = int.tryParse(match.group(1) ?? '');
          return code != null ? String.fromCharCode(code) : match.group(0)!;
        });
  }
}
