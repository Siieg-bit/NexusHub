import 'package:http/http.dart' as http;
import 'dart:convert';

import '../services/supabase_service.dart';

/// Dados Open Graph extraídos de uma URL.
class OgTagsData {
  final String? title;
  final String? description;
  final String? image;
  final String? siteName;
  final String? domain;
  final String? favicon;
  final String? url;

  const OgTagsData({
    this.title,
    this.description,
    this.image,
    this.siteName,
    this.domain,
    this.favicon,
    this.url,
  });

  factory OgTagsData.fromJson(Map<String, dynamic> json) => OgTagsData(
        title: json['title'] as String?,
        description: json['description'] as String?,
        image: json['image'] as String?,
        siteName: json['site_name'] as String?,
        domain: json['domain'] as String?,
        favicon: json['favicon'] as String?,
        url: json['url'] as String?,
      );

  bool get isEmpty =>
      title == null && description == null && image == null;
}

/// Serviço para buscar OG tags de URLs externas.
///
/// Usa a Edge Function `fetch-og-tags` do Supabase como proxy
/// para evitar problemas de CORS no Flutter Web e manter a
/// chave de API segura.
class OgTagsService {
  static const _functionName = 'fetch-og-tags';

  /// Cache simples em memória para evitar re-fetch da mesma URL.
  static final Map<String, OgTagsData> _cache = {};

  /// Busca OG tags para a URL fornecida.
  ///
  /// Retorna [OgTagsData] com os metadados encontrados ou
  /// [OgTagsData] vazio se não for possível extrair.
  static Future<OgTagsData> fetch(String url) async {
    // Verificar cache
    if (_cache.containsKey(url)) return _cache[url]!;

    try {
      // Tentar via Edge Function do Supabase
      final response = await SupabaseService.client.functions.invoke(
        _functionName,
        body: {'url': url},
      );

      if (response.status == 200 && response.data != null) {
        final data = response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : json.decode(response.data.toString()) as Map<String, dynamic>;

        if (data.containsKey('error')) {
          return const OgTagsData();
        }

        final result = OgTagsData.fromJson(data);
        _cache[url] = result;
        return result;
      }
    } catch (_) {
      // Fallback: fetch direto via HTTP (funciona em mobile, pode falhar em web por CORS)
      try {
        return await _fetchDirect(url);
      } catch (_) {}
    }

    return const OgTagsData();
  }

  /// Fallback: fetch direto da página e parse manual dos meta tags.
  static Future<OgTagsData> _fetchDirect(String url) async {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; NexusHub/1.0)',
      },
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return const OgTagsData();

    final html = response.body;
    final uri = Uri.parse(url);

    final result = OgTagsData(
      title: _extractMeta(html, 'og:title') ?? _extractTitle(html),
      description:
          _extractMeta(html, 'og:description') ?? _extractDescription(html),
      image: _extractMeta(html, 'og:image'),
      siteName: _extractMeta(html, 'og:site_name'),
      domain: uri.host,
      favicon: '${uri.scheme}://${uri.host}/favicon.ico',
      url: _extractMeta(html, 'og:url') ?? url,
    );

    _cache[url] = result;
    return result;
  }

  static String? _extractMeta(String html, String property) {
    final patterns = [
      RegExp(
        '<meta[^>]+(?:property|name)=["\']$property["\'][^>]+content=["\']([^"\']+)["\']',
        caseSensitive: false,
      ),
      RegExp(
        '<meta[^>]+content=["\']([^"\']+)["\'][^>]+(?:property|name)=["\']$property["\']',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim();
      }
    }
    return null;
  }

  static String? _extractTitle(String html) {
    final match = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false)
        .firstMatch(html);
    return match?.group(1)?.trim();
  }

  static String? _extractDescription(String html) {
    return _extractMeta(html, 'description');
  }

  /// Limpar cache (útil ao sair da tela).
  static void clearCache() => _cache.clear();
}
