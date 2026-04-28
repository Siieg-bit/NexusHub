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
  // O Rave usa apenas 3 headers nas chamadas de catálogo (getMetadataRequest do DisneyServer.smali):
  // Authorization, Accept, Content-Type — sem X-BAMSDK-* nos endpoints /explore/.
  static Map<String, String> _headers(String accessToken) => {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
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

    final uri = Uri.parse(
      '$_baseExplore/$_v14/page/$pageId'
      '?disableSmartFocus=true&enchancedContainersLimit=24&limit=100',
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

    // Endpoint de busca: getSiteSearch do BAM SDK config v4
    // GET /svc/search/DisneySearch/version/5.1/region/BR/audience/k-false,l-true/maturity/1850/language/pt-BR/query/{query}
    final uri = Uri.parse(
      'https://disney.content.edge.bamgrid.com/svc/search/DisneySearch'
      '/version/5.1/region/$_region/audience/k-false,l-true'
      '/maturity/1850/language/$_language/query/${Uri.encodeComponent(query)}',
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

    // Endpoint getDmcSeries do BAM SDK config v4
    final uri = Uri.parse(
      'https://disney.content.edge.bamgrid.com/svc/content/DmcSeries'
      '/version/5.1/region/$_region/audience/k-false,l-true'
      '/maturity/1850/language/$_language/encodedSeriesId/$seriesId',
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

    // Endpoint getDmcEpisodes do BAM SDK config v4
    final uri = Uri.parse(
      'https://disney.content.edge.bamgrid.com/svc/content/DmcEpisodes'
      '/version/5.1/region/$_region/audience/k-false,l-true'
      '/maturity/1850/language/$_language'
      '/seasonId/$seasonId/pageSize/30/page/$page',
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

    // BAM SDK v4: GET /explore/v1.0/deeplink?refIdType=dmcContentId&refId={contentId}
    // Rave smali: /deeplink?refId={id}&refIdType=dmcContentId (vídeo)
    //             /deeplink?action=playback&refId={id}&refIdType=deeplinkId (série)
    final refIdType = isSeries ? 'deeplinkId' : 'dmcContentId';
    final uri = Uri.parse(
      'https://disney.content.edge.bamgrid.com/explore/v1.0/deeplink'
      '?refIdType=$refIdType&refId=$contentId',
    );

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

    // Rave usa: GET /explore/v1.2/playerExperience/{contentId}?region=BR&language=pt-BR
    final uri = Uri.parse(
      '$_baseExplore/$_v12/playerExperience/$contentId'
      '?region=$_region&language=$_language',
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
