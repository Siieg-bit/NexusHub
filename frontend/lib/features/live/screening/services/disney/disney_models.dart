/// Modelos de dados para a API BAMGrid do Disney+.
///
/// Estrutura baseada na análise forense dos modelos do Rave:
/// - DisneyPageData, DisneyPageItem, DisneyPageVisuals
/// - DisneyMetadataStandard, DisneyMetadataImage
/// - StreamsResponse, DisneyStreamsSourceComplete
/// - DeepLinkResponse, PlayerExperience

// ── Modelo de item de catálogo (filme ou série) ───────────────────────────

class DisneyContentItem {
  final String contentId;
  final String title;
  final String? description;
  final String? imageUrl;
  final String? backgroundImageUrl;
  final String contentType; // 'movie' | 'series' | 'episode'
  final String? releaseYear;
  final String? rating;
  final String? seriesId;
  final int? seasonNumber;
  final int? episodeNumber;
  final int? runtimeMs;

  const DisneyContentItem({
    required this.contentId,
    required this.title,
    required this.contentType,
    this.description,
    this.imageUrl,
    this.backgroundImageUrl,
    this.releaseYear,
    this.rating,
    this.seriesId,
    this.seasonNumber,
    this.episodeNumber,
    this.runtimeMs,
  });

  String get runtimeFormatted {
    if (runtimeMs == null) return '';
    final total = Duration(milliseconds: runtimeMs!);
    final h = total.inHours;
    final m = total.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}min';
    return '${m}min';
  }

  bool get isSeries => contentType == 'series' || contentType == 'DmcSeries';
  bool get isMovie => contentType == 'movie' || contentType == 'DmcVideo' || contentType == 'StandardCollection';

  factory DisneyContentItem.fromPageItem(Map<String, dynamic> json) {
    // Estrutura do explore/v1.4/page/ — baseada nos modelos DisneyPageItem do Rave
    final text = json['text'] as Map<String, dynamic>?;
    final title = _extractText(text, 'title') ?? 'Sem título';

    final image = json['image'] as Map<String, dynamic>?;
    final imageUrl = _extractImage(image, 'tile') ?? _extractImage(image, 'thumbnail');
    final bgUrl = _extractImage(image, 'background') ?? _extractImage(image, 'hero_tile');

    final contentId = json['contentId'] as String?
        ?? json['id'] as String?
        ?? '';

    final contentType = json['type'] as String? ?? 'unknown';

    final ratings = json['ratings'] as List<dynamic>?;
    final rating = ratings?.isNotEmpty == true
        ? (ratings!.first as Map<String, dynamic>)['value'] as String?
        : null;

    final releases = json['releases'] as List<dynamic>?;
    final releaseYear = releases?.isNotEmpty == true
        ? (releases!.first as Map<String, dynamic>)['releaseYear']?.toString()
        : null;

    final seriesId = json['seriesId'] as String?;
    final seasonNumber = json['seasonSequenceNumber'] as int?;
    final episodeNumber = json['episodeSequenceNumber'] as int?;

    final mediaMetadata = json['mediaMetadata'] as Map<String, dynamic>?;
    final runtimeMs = mediaMetadata?['runtimeMillis'] as int?;

    final description = _extractText(text, 'description')
        ?? _extractText(text, 'brief');

    return DisneyContentItem(
      contentId: contentId,
      title: title,
      contentType: contentType,
      description: description,
      imageUrl: imageUrl,
      backgroundImageUrl: bgUrl,
      releaseYear: releaseYear,
      rating: rating,
      seriesId: seriesId,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      runtimeMs: runtimeMs,
    );
  }

  static String? _extractText(Map<String, dynamic>? text, String key) {
    if (text == null) return null;
    final field = text[key] as Map<String, dynamic>?;
    if (field == null) return null;
    // Tentar 'full', 'brief', 'slug' em ordem
    for (final subKey in ['full', 'brief', 'slug', 'standard']) {
      final sub = field[subKey] as Map<String, dynamic>?;
      if (sub != null) {
        final content = sub['content'] as String?;
        if (content != null && content.isNotEmpty) return content;
      }
    }
    return null;
  }

  static String? _extractImage(Map<String, dynamic>? image, String key) {
    if (image == null) return null;
    final field = image[key] as Map<String, dynamic>?;
    if (field == null) return null;
    // Navegar pela estrutura: image.tile.1.33.default.url
    for (final aspectKey in field.keys) {
      final aspect = field[aspectKey] as Map<String, dynamic>?;
      if (aspect == null) continue;
      for (final sizeKey in aspect.keys) {
        final size = aspect[sizeKey] as Map<String, dynamic>?;
        if (size == null) continue;
        final defaultEntry = size['default'] as Map<String, dynamic>?;
        if (defaultEntry != null) {
          final url = defaultEntry['url'] as String?;
          if (url != null && url.isNotEmpty) return url;
        }
      }
    }
    return null;
  }
}

// ── Modelo de página do catálogo ──────────────────────────────────────────

class DisneyPage {
  final String? pageId;
  final String? title;
  final List<DisneyContainer> containers;
  final String? nextPageId;

  const DisneyPage({
    this.pageId,
    this.title,
    required this.containers,
    this.nextPageId,
  });

  factory DisneyPage.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    final page = data?['StandardCollection'] as Map<String, dynamic>?
        ?? data?['CuratedSet'] as Map<String, dynamic>?
        ?? data;

    final containers = <DisneyContainer>[];
    final containersJson = page?['containers'] as List<dynamic>?
        ?? page?['items'] as List<dynamic>?;

    if (containersJson != null) {
      for (final c in containersJson) {
        try {
          containers.add(DisneyContainer.fromJson(c as Map<String, dynamic>));
        } catch (_) {}
      }
    }

    return DisneyPage(
      pageId: page?['contentId'] as String?,
      title: page?['title'] as String?,
      containers: containers,
    );
  }
}

class DisneyContainer {
  final String? title;
  final List<DisneyContentItem> items;

  const DisneyContainer({this.title, required this.items});

  factory DisneyContainer.fromJson(Map<String, dynamic> json) {
    final set = json['set'] as Map<String, dynamic>?;
    final setItems = set?['items'] as List<dynamic>?
        ?? json['items'] as List<dynamic>?;

    final items = <DisneyContentItem>[];
    if (setItems != null) {
      for (final item in setItems) {
        try {
          items.add(DisneyContentItem.fromPageItem(item as Map<String, dynamic>));
        } catch (_) {}
      }
    }

    final textMap = set?['text'] as Map<String, dynamic>?
        ?? json['text'] as Map<String, dynamic>?;
    final titleMap = textMap?['title'] as Map<String, dynamic>?;
    final fullTitle = (titleMap?['full'] as Map<String, dynamic>?)?['set']
        as Map<String, dynamic>?;
    final title = fullTitle?['content'] as String?
        ?? fullTitle?['default'] as String?;

    return DisneyContainer(title: title, items: items);
  }
}

// ── Modelo de temporada ───────────────────────────────────────────────────

class DisneySeason {
  final String seasonId;
  final int seasonNumber;
  final String? title;
  final List<DisneyContentItem> episodes;

  const DisneySeason({
    required this.seasonId,
    required this.seasonNumber,
    this.title,
    required this.episodes,
  });

  factory DisneySeason.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    final season = data?['DmcEpisodes'] as Map<String, dynamic>?
        ?? data?['DmcSeason'] as Map<String, dynamic>?
        ?? data;

    final episodes = <DisneyContentItem>[];
    final itemsJson = season?['videos'] as List<dynamic>?
        ?? season?['items'] as List<dynamic>?;

    if (itemsJson != null) {
      for (final ep in itemsJson) {
        try {
          episodes.add(DisneyContentItem.fromPageItem(ep as Map<String, dynamic>));
        } catch (_) {}
      }
    }

    return DisneySeason(
      seasonId: season?['seasonId'] as String? ?? '',
      seasonNumber: season?['seasonSequenceNumber'] as int? ?? 1,
      title: season?['title'] as String?,
      episodes: episodes,
    );
  }
}

// ── Modelo de deeplink (resolve contentId → playbackId) ──────────────────

class DisneyDeepLink {
  final String? playbackId;
  final String? resourceId;

  const DisneyDeepLink({this.playbackId, this.resourceId});

  factory DisneyDeepLink.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    final deeplink = data?['deeplink'] as Map<String, dynamic>?;
    final actions = deeplink?['actions'] as List<dynamic>?;

    String? resourceId;
    if (actions != null && actions.isNotEmpty) {
      final action = actions.first as Map<String, dynamic>;
      resourceId = action['resourceId'] as String?;
    }

    return DisneyDeepLink(
      playbackId: deeplink?['playbackId'] as String?,
      resourceId: resourceId,
    );
  }
}

// ── Modelo de streams (URL do manifesto) ─────────────────────────────────

class DisneyStream {
  final String manifestUrl;
  final String? licenseUrl;
  final bool isDrm;
  /// Título do conteúdo (preenchido pelo DisneyPlaybackService)
  final String? title;
  /// URL da thumbnail (preenchido pelo DisneyPlaybackService)
  final String? thumbnailUrl;
  /// PSSH box em base64 para inicialização DRM mais rápida (opcional)
  final String? pssh;
  /// Headers HTTP adicionais para o manifesto e segmentos (ex: Authorization)
  final Map<String, String>? headers;

  const DisneyStream({
    required this.manifestUrl,
    this.licenseUrl,
    this.isDrm = true,
    this.title,
    this.thumbnailUrl,
    this.pssh,
    this.headers,
  });

  factory DisneyStream.fromJson(Map<String, dynamic> json) {
    // Estrutura baseada em StreamsResponse e DisneyStreamsSourceComplete do Rave
    final stream = json['stream'] as Map<String, dynamic>?;
    final complete = stream?['complete'] as Map<String, dynamic>?;
    final url = complete?['url'] as String? ?? json['url'] as String? ?? '';

    return DisneyStream(
      manifestUrl: url,
      licenseUrl: json['licenseUrl'] as String?,
      isDrm: json['isDrm'] as bool? ?? true,
      title: json['title'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      pssh: json['pssh'] as String?,
    );
  }

  /// Cria uma cópia com campos adicionais preenchidos
  DisneyStream copyWith({
    String? title,
    String? thumbnailUrl,
    String? pssh,
    Map<String, String>? headers,
  }) {
    return DisneyStream(
      manifestUrl: manifestUrl,
      licenseUrl: licenseUrl,
      isDrm: isDrm,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      pssh: pssh ?? this.pssh,
      headers: headers ?? this.headers,
    );
  }
}

// ── Modelo de resultado de busca ──────────────────────────────────────────

class DisneySearchResult {
  final List<DisneyContentItem> hits;
  final int total;

  const DisneySearchResult({required this.hits, required this.total});

  factory DisneySearchResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    final search = data?['search'] as Map<String, dynamic>?
        ?? data?['SearchResult'] as Map<String, dynamic>?;

    final hitsJson = search?['hits'] as List<dynamic>?
        ?? search?['items'] as List<dynamic>?
        ?? [];

    final hits = <DisneyContentItem>[];
    for (final h in hitsJson) {
      try {
        final hit = h as Map<String, dynamic>;
        final content = hit['hit'] as Map<String, dynamic>? ?? hit;
        hits.add(DisneyContentItem.fromPageItem(content));
      } catch (_) {}
    }

    return DisneySearchResult(
      hits: hits,
      total: search?['total'] as int? ?? hits.length,
    );
  }
}
