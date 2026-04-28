import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'disney_auth_service.dart';
import 'disney_models.dart';

/// Cliente REST para a API BAMGrid do Disney+.
///
/// Baseado na análise forense do DisneyRestClient e DisneyService do Rave.
/// Usa os headers X-BAMSDK-* para simular o app oficial Android do Disney+.
class DisneyApiService {
  // ── Endpoints BAMGrid (extraídos do Rave via engenharia reversa) ──────────
  static const _baseExplore = 'https://disney.api.edge.bamgrid.com/explore';
  static const _baseImages = 'https://disney.images.edge.bamgrid.com';

  // Versões de API usadas pelo Rave
  static const _v14 = 'v1.4';
  static const _v13 = 'v1.3';
  static const _v12 = 'v1.2';

  // Parâmetros de localização e plataforma
  static const _region = 'BR';
  static const _language = 'pt-BR';
  static const _maturityRating = 'TVPG';

  // ── Headers BAMGrid ───────────────────────────────────────────────────────
  static Map<String, String> _headers(String accessToken) => {
        'Authorization': 'Bearer $accessToken',
        'X-BAMSDK-Client-ID': 'disney-svod-3d9324fc',
        'X-BAMSDK-Platform': 'android/google/handset',
        'X-BAMSDK-Version': '8.3.3',
        'X-Application-Version': '2.16.2-rc2.0',
        'X-DSS-Edge-Accept': 'vnd.dss.edge+json; version=2',
        'Accept': 'application/json',
        'Accept-Language': _language,
        'X-BAMSDK-Device-ID': 'nexushub-android-device',
      };

  // ── Parâmetros comuns de query ────────────────────────────────────────────
  static Map<String, String> _commonParams() => {
        'region': _region,
        'language': _language,
        'maturityRating': _maturityRating,
        'implicitMaturityRating': 'TVPG',
        'kidsModeEnabled': 'false',
        'appLanguage': _language,
      };

  // ── Catálogo / Home ───────────────────────────────────────────────────────

  /// Carrega a página inicial do catálogo Disney+.
  ///
  /// Equivalente ao endpoint `/explore/v1.4/page/home` do Rave.
  static Future<DisneyPage> fetchHomePage() async {
    return _fetchPage('home');
  }

  /// Carrega uma página específica do catálogo por ID.
  static Future<DisneyPage> fetchPage(String pageId) async {
    return _fetchPage(pageId);
  }

  /// Carrega a fila "Continue assistindo" do usuário.
  ///
  /// Equivalente ao endpoint `/explore/v1.4/page/continue-watching` do Rave.
  /// Retorna uma lista de itens que o usuário já começou a assistir.
  static Future<List<DisneyContentItem>> fetchContinueWatching() async {
    try {
      final page = await _fetchPage('continue-watching');
      final items = <DisneyContentItem>[];
      for (final container in page.containers) {
        items.addAll(container.items);
      }
      return items;
    } catch (e) {
      debugPrint('[DisneyApi] fetchContinueWatching falhou: $e');
      return [];
    }
  }

  /// Carrega a watchlist ("Minha Lista") do usuário.
  ///
  /// Equivalente ao endpoint `/explore/v1.4/page/my-list` do Rave.
  static Future<List<DisneyContentItem>> fetchMyList() async {
    try {
      final page = await _fetchPage('my-list');
      final items = <DisneyContentItem>[];
      for (final container in page.containers) {
        items.addAll(container.items);
      }
      return items;
    } catch (e) {
      debugPrint('[DisneyApi] fetchMyList falhou: $e');
      return [];
    }
  }

  static Future<DisneyPage> _fetchPage(String pageId) async {
    final accessToken = await DisneyAuthService.getValidAccessToken();
    final params = _commonParams()
      ..addAll({
        'pageId': pageId,
        'pageSize': '24',
        'setSize': '15',
      });

    final uri = Uri.parse('$_baseExplore/$_v14/page/').replace(
      queryParameters: params,
    );

    debugPrint('[DisneyApi] fetchPage: $pageId');
    final response = await http.get(uri, headers: _headers(accessToken));
    _checkResponse(response, 'fetchPage($pageId)');

    return DisneyPage.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // ── Busca ─────────────────────────────────────────────────────────────────

  /// Busca conteúdo no catálogo Disney+ por query de texto.
  ///
  /// Equivalente ao endpoint `/explore/v1.4/search` do Rave.
  static Future<DisneySearchResult> search(String query) async {
    final accessToken = await DisneyAuthService.getValidAccessToken();
    final params = _commonParams()
      ..addAll({
        'query': query,
        'pageSize': '20',
        'contentClass': 'movie,series',
      });

    final uri = Uri.parse('$_baseExplore/$_v14/search').replace(
      queryParameters: params,
    );

    debugPrint('[DisneyApi] search: "$query"');
    final response = await http.get(uri, headers: _headers(accessToken));
    _checkResponse(response, 'search("$query")');

    return DisneySearchResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // ── Detalhes de série / temporada ─────────────────────────────────────────

  /// Carrega as temporadas de uma série.
  ///
  /// Equivalente ao endpoint `/explore/v1.3/season/{seriesId}` do Rave.
  static Future<List<DisneySeason>> fetchSeasons(String seriesId) async {
    final accessToken = await DisneyAuthService.getValidAccessToken();
    final params = _commonParams()
      ..addAll({
        'seriesId': seriesId,
        'pageSize': '30',
      });

    final uri = Uri.parse('$_baseExplore/$_v13/season/').replace(
      queryParameters: params,
    );

    debugPrint('[DisneyApi] fetchSeasons: $seriesId');
    final response = await http.get(uri, headers: _headers(accessToken));
    _checkResponse(response, 'fetchSeasons($seriesId)');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final seasonsJson = data['data']?['DmcSeriesBundle']?['seasons']
            as List<dynamic>?
        ?? data['data']?['seasons'] as List<dynamic>?
        ?? [];

    return seasonsJson
        .map((s) => DisneySeason.fromJson({'data': s}))
        .toList();
  }

  /// Carrega os episódios de uma temporada específica.
  ///
  /// Equivalente ao endpoint `/explore/v1.3/season/{seasonId}/episodes` do Rave.
  static Future<DisneySeason> fetchEpisodes(
    String seasonId, {
    int page = 1,
  }) async {
    final accessToken = await DisneyAuthService.getValidAccessToken();
    final params = _commonParams()
      ..addAll({
        'seasonId': seasonId,
        'pageSize': '30',
        'page': page.toString(),
      });

    final uri = Uri.parse('$_baseExplore/$_v13/season/$seasonId').replace(
      queryParameters: params,
    );

    debugPrint('[DisneyApi] fetchEpisodes: $seasonId (page $page)');
    final response = await http.get(uri, headers: _headers(accessToken));
    _checkResponse(response, 'fetchEpisodes($seasonId)');

    return DisneySeason.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // ── Deeplink (contentId → playbackId) ────────────────────────────────────

  /// Resolve um contentId para um playbackId via endpoint de deeplink.
  ///
  /// Baseado no fluxo `fetchDeepLinkInfo` do DisneyServer do Rave:
  /// `GET /deeplink?action=playback&refId={contentId}`
  static Future<DisneyDeepLink> fetchDeepLink(
    String contentId, {
    bool isSeries = false,
  }) async {
    final accessToken = await DisneyAuthService.getValidAccessToken();
    final params = _commonParams()
      ..addAll({
        'action': 'playback',
        'refId': contentId,
        'refIdType': isSeries ? 'series' : 'video',
      });

    final uri = Uri.parse(
      'https://disney.api.edge.bamgrid.com/deeplink',
    ).replace(queryParameters: params);

    debugPrint('[DisneyApi] fetchDeepLink: $contentId');
    final response = await http.get(uri, headers: _headers(accessToken));
    _checkResponse(response, 'fetchDeepLink($contentId)');

    return DisneyDeepLink.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // ── Player Experience ─────────────────────────────────────────────────────

  /// Carrega a experiência de player para um conteúdo.
  ///
  /// Equivalente ao endpoint `/explore/v1.2/playerExperience` do Rave.
  /// Retorna metadados do player, URL de manifesto e informações de DRM.
  static Future<Map<String, dynamic>> fetchPlayerExperience(
    String contentId,
  ) async {
    final accessToken = await DisneyAuthService.getValidAccessToken();
    final params = _commonParams()
      ..addAll({
        'contentId': contentId,
      });

    final uri = Uri.parse('$_baseExplore/$_v12/playerExperience/').replace(
      queryParameters: params,
    );

    debugPrint('[DisneyApi] fetchPlayerExperience: $contentId');
    final response = await http.get(uri, headers: _headers(accessToken));
    _checkResponse(response, 'fetchPlayerExperience($contentId)');

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ── URL de imagem via CDN BAMGrid ─────────────────────────────────────────

  /// Gera a URL de imagem via CDN do Disney+ (ripcut-delivery).
  ///
  /// Baseado no endpoint `https://disney.images.edge.bamgrid.com/ripcut-delivery/v1/variant/disney/`
  static String buildImageUrl(
    String imageId, {
    int width = 400,
    String format = 'webp',
  }) {
    return '$_baseImages/ripcut-delivery/v1/variant/disney/$imageId'
        '?format=$format&width=$width&quality=90';
  }

  // ── Helper de verificação de resposta ────────────────────────────────────

  static void _checkResponse(http.Response response, String context) {
    if (response.statusCode == 200) return;

    debugPrint('[DisneyApi] Erro em $context: ${response.statusCode}');
    debugPrint('[DisneyApi] Body: ${response.body.substring(0, response.body.length.clamp(0, 300))}');

    if (response.statusCode == 401) {
      throw DisneyAuthException(
        'Sessão Disney+ expirada. Por favor, faça login novamente.',
        isExpired: true,
      );
    }

    if (response.statusCode == 403) {
      throw Exception(
        'Disney+: acesso negado. '
        'Verifique se sua assinatura está ativa.',
      );
    }

    if (response.statusCode == 404) {
      throw Exception('Disney+: conteúdo não encontrado ($context)');
    }

    throw Exception(
      'Disney+ API erro ${response.statusCode} em $context: '
      '${response.body.substring(0, response.body.length.clamp(0, 200))}',
    );
  }
}
