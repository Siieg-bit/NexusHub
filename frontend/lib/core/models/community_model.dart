/// Modelo de comunidade da plataforma.
/// Baseado na engenharia reversa do modelo Community do Amino original.
class CommunityModel {
  final String id;
  final String name;
  final String? tagline;
  final String? description;
  final String? iconUrl;
  final String? bannerUrl;
  final String ownerId;
  final String primaryLanguage;
  final String joinType;
  final bool isSearchable;
  final bool isActive;
  final int membersCount;
  final int postsCount;
  final int onlineMembersCount;
  final String themeColor;
  final Map<String, dynamic> themeConfig;
  final String? guidelines;
  final DateTime createdAt;
  final bool? isMember;

  const CommunityModel({
    required this.id,
    required this.name,
    this.tagline,
    this.description,
    this.iconUrl,
    this.bannerUrl,
    required this.ownerId,
    this.primaryLanguage = 'pt-BR',
    this.joinType = 'open',
    this.isSearchable = true,
    this.isActive = true,
    this.membersCount = 0,
    this.postsCount = 0,
    this.onlineMembersCount = 0,
    this.themeColor = '#6C5CE7',
    this.themeConfig = const {},
    this.guidelines,
    required this.createdAt,
    this.isMember,
  });

  factory CommunityModel.fromJson(Map<String, dynamic> json) {
    return CommunityModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      tagline: json['tagline'] as String?,
      description: json['description'] as String?,
      iconUrl: json['icon_url'] as String?,
      bannerUrl: json['banner_url'] as String?,
      ownerId: json['owner_id'] as String? ?? '',
      primaryLanguage: json['primary_language'] as String? ?? 'pt-BR',
      joinType: json['join_type'] as String? ?? 'open',
      isSearchable: json['is_searchable'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      membersCount: json['members_count'] as int? ?? 0,
      postsCount: json['posts_count'] as int? ?? 0,
      onlineMembersCount: json['online_members_count'] as int? ?? 0,
      themeColor: json['theme_color'] as String? ?? '#6C5CE7',
      themeConfig: json['theme_config'] as Map<String, dynamic>? ?? {},
      guidelines: json['guidelines'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
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
      'owner_id': ownerId,
      'primary_language': primaryLanguage,
      'join_type': joinType,
      'is_searchable': isSearchable,
      'theme_color': themeColor,
      'guidelines': guidelines,
    };
  }
}
