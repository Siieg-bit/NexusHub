/// Modelo de comunidade da plataforma.
/// Baseado no schema v5 — engenharia reversa do APK Amino (Community.smali).
class CommunityModel {
  final String id;
  final String name;
  final String tagline;
  final String description;
  final String? iconUrl;
  final String? bannerUrl;
  final String? endpoint; // slug único da comunidade
  final String? link; // link de convite

  // Configuração de acesso
  final String joinType; // enum: open, request, invite
  final String listedStatus; // enum: none, unlisted, listed
  final bool isSearchable;

  // Estatísticas
  final int membersCount;
  final int postsCount;
  final double communityHeat;

  // Idioma e categoria
  final String primaryLanguage;
  final String category;

  // Referência ao Agent (criador/dono)
  final String agentId; // era owner_id

  // Tema visual customizado (ACM)
  final String themeColor;
  final Map<String, dynamic> themePack;

  // Módulos configuráveis
  final Map<String, dynamic> configuration;

  // Status
  final String status; // enum: ok, pending, closed, disabled, deleted
  final int probationStatus;

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  // Campos calculados (não na tabela)
  final bool? isMember;

  // ── Novos campos: Banners múltiplos por contexto ──
  /// Banner exibido no header da tela de detalhe da comunidade
  final String? bannerHeaderUrl;
  /// Banner exibido no drawer lateral da comunidade
  final String? bannerDrawerUrl;
  /// Banner exibido no card da lista de comunidades
  final String? bannerCardUrl;
  /// Banner exibido na tela de informações/sobre da comunidade
  final String? bannerInfoUrl;

  // ── Novos campos: Tema avançado ──
  /// Cor final do gradiente do tema (opcional)
  final String? themeGradientEnd;
  /// Como a cor predominante é aplicada: accent, full, gradient
  final String themeApplyMode;

  // ── Novos campos: Conteúdo editorial ──
  /// Regras da comunidade em formato Markdown
  final String rules;
  /// Texto de descrição expandida da comunidade
  final String aboutText;
  /// Tags/categorias da comunidade
  final List<String> communityTags;
  /// Número máximo de posts que podem ser fixados simultaneamente
  final int maxPinnedPosts;
  /// Mensagem de boas-vindas exibida para novos membros
  final String welcomeMessage;

  const CommunityModel({
    required this.id,
    required this.name,
    this.tagline = '',
    this.description = '',
    this.iconUrl,
    this.bannerUrl,
    this.endpoint,
    this.link,
    this.joinType = 'open',
    this.listedStatus = 'listed',
    this.isSearchable = true,
    this.membersCount = 0,
    this.postsCount = 0,
    this.communityHeat = 0.0,
    this.primaryLanguage = 'pt',
    this.category = 'general',
    required this.agentId,
    this.themeColor = '#0B0B0B',
    this.themePack = const {},
    this.configuration = const {},
    this.status = 'ok',
    this.probationStatus = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isMember,
    // Novos campos
    this.bannerHeaderUrl,
    this.bannerDrawerUrl,
    this.bannerCardUrl,
    this.bannerInfoUrl,
    this.themeGradientEnd,
    this.themeApplyMode = 'accent',
    this.rules = '',
    this.aboutText = '',
    this.communityTags = const [],
    this.maxPinnedPosts = 5,
    this.welcomeMessage = '',
  });

  factory CommunityModel.fromJson(Map<String, dynamic> json) {
    List<String> parseTags(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return [];
    }
    return CommunityModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      description: json['description'] as String? ?? '',
      iconUrl: json['icon_url'] as String?,
      bannerUrl: json['banner_url'] as String?,
      endpoint: json['endpoint'] as String?,
      link: json['link'] as String?,
      joinType: json['join_type'] as String? ?? 'open',
      listedStatus: json['listed_status'] as String? ?? 'listed',
      isSearchable: json['is_searchable'] as bool? ?? true,
      membersCount: json['members_count'] as int? ?? 0,
      postsCount: json['posts_count'] as int? ?? 0,
      communityHeat: (json['community_heat'] as num?)?.toDouble() ?? 0.0,
      primaryLanguage: json['primary_language'] as String? ?? 'pt',
      category: json['category'] as String? ?? 'general',
      agentId: json['agent_id'] as String? ?? '',
      themeColor: json['theme_color'] as String? ?? '#0B0B0B',
      themePack: json['theme_pack'] as Map<String, dynamic>? ?? {},
      configuration: json['configuration'] as Map<String, dynamic>? ?? {},
      status: json['status'] as String? ?? 'ok',
      probationStatus: json['probation_status'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
      isMember: json['is_member'] as bool?,
      // Novos campos
      bannerHeaderUrl: json['banner_header_url'] as String?,
      bannerDrawerUrl: json['banner_drawer_url'] as String?,
      bannerCardUrl: json['banner_card_url'] as String?,
      bannerInfoUrl: json['banner_info_url'] as String?,
      themeGradientEnd: json['theme_gradient_end'] as String?,
      themeApplyMode: json['theme_apply_mode'] as String? ?? 'accent',
      rules: json['rules'] as String? ?? '',
      aboutText: json['about_text'] as String? ?? '',
      communityTags: parseTags(json['community_tags']),
      maxPinnedPosts: json['max_pinned_posts'] as int? ?? 5,
      welcomeMessage: json['welcome_message'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'tagline': tagline,
      'description': description,
      'icon_url': iconUrl,
      'banner_url': bannerUrl,
      'endpoint': endpoint,
      'agent_id': agentId,
      'primary_language': primaryLanguage,
      'category': category,
      'join_type': joinType,
      'is_searchable': isSearchable,
      'theme_color': themeColor,
      // Novos campos
      'banner_header_url': bannerHeaderUrl,
      'banner_drawer_url': bannerDrawerUrl,
      'banner_card_url': bannerCardUrl,
      'banner_info_url': bannerInfoUrl,
      'theme_gradient_end': themeGradientEnd,
      'theme_apply_mode': themeApplyMode,
      'rules': rules,
      'about_text': aboutText,
      'community_tags': communityTags,
      'max_pinned_posts': maxPinnedPosts,
      'welcome_message': welcomeMessage,
    };
  }

  /// Retorna o banner mais adequado para o contexto especificado.
  /// Fallback: bannerUrl genérico.
  String? bannerForContext(String ctx) {
    switch (ctx) {
      case 'header':
        return bannerHeaderUrl ?? bannerUrl;
      case 'drawer':
        return bannerDrawerUrl ?? bannerHeaderUrl ?? bannerUrl;
      case 'card':
        return bannerCardUrl ?? bannerUrl;
      case 'info':
        return bannerInfoUrl ?? bannerHeaderUrl ?? bannerUrl;
      default:
        return bannerUrl;
    }
  }

  CommunityModel copyWith({
    String? id,
    String? name,
    String? tagline,
    String? description,
    String? iconUrl,
    String? bannerUrl,
    String? endpoint,
    String? link,
    String? joinType,
    String? listedStatus,
    bool? isSearchable,
    int? membersCount,
    int? postsCount,
    double? communityHeat,
    String? primaryLanguage,
    String? category,
    String? agentId,
    String? themeColor,
    Map<String, dynamic>? themePack,
    Map<String, dynamic>? configuration,
    String? status,
    int? probationStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isMember,
    String? bannerHeaderUrl,
    String? bannerDrawerUrl,
    String? bannerCardUrl,
    String? bannerInfoUrl,
    String? themeGradientEnd,
    String? themeApplyMode,
    String? rules,
    String? aboutText,
    List<String>? communityTags,
    int? maxPinnedPosts,
  }) {
    return CommunityModel(
      id: id ?? this.id,
      name: name ?? this.name,
      tagline: tagline ?? this.tagline,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      endpoint: endpoint ?? this.endpoint,
      link: link ?? this.link,
      joinType: joinType ?? this.joinType,
      listedStatus: listedStatus ?? this.listedStatus,
      isSearchable: isSearchable ?? this.isSearchable,
      membersCount: membersCount ?? this.membersCount,
      postsCount: postsCount ?? this.postsCount,
      communityHeat: communityHeat ?? this.communityHeat,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      category: category ?? this.category,
      agentId: agentId ?? this.agentId,
      themeColor: themeColor ?? this.themeColor,
      themePack: themePack ?? this.themePack,
      configuration: configuration ?? this.configuration,
      status: status ?? this.status,
      probationStatus: probationStatus ?? this.probationStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isMember: isMember ?? this.isMember,
      bannerHeaderUrl: bannerHeaderUrl ?? this.bannerHeaderUrl,
      bannerDrawerUrl: bannerDrawerUrl ?? this.bannerDrawerUrl,
      bannerCardUrl: bannerCardUrl ?? this.bannerCardUrl,
      bannerInfoUrl: bannerInfoUrl ?? this.bannerInfoUrl,
      themeGradientEnd: themeGradientEnd ?? this.themeGradientEnd,
      themeApplyMode: themeApplyMode ?? this.themeApplyMode,
      rules: rules ?? this.rules,
      aboutText: aboutText ?? this.aboutText,
      communityTags: communityTags ?? this.communityTags,
      maxPinnedPosts: maxPinnedPosts ?? this.maxPinnedPosts,
    );
  }
}
