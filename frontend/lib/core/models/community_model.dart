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
  });

  factory CommunityModel.fromJson(Map<String, dynamic> json) {
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
    };
  }
}
