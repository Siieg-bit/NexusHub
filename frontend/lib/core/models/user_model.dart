/// Modelo de usuário/perfil da plataforma.
/// Baseado no schema v5 — engenharia reversa do APK Amino (User.smali).
class UserModel {
  final String id;
  final String aminoId;
  final String nickname;
  final bool isNicknameVerified;
  final String? email; // vem de auth.users, não da tabela profiles
  final String? iconUrl; // avatar (era avatar_url)
  final String? bannerUrl;
  final String bio;

  // Roles globais (Team NexusHub)
  final bool isTeamAdmin;
  final bool isTeamModerator;
  final bool isSystemAccount;

  // Gamificação global
  final int level; // era global_level
  final int reputation;

  // Economia
  final int coins;
  final double coinsFloat;
  final int businessCoins;
  final bool isPremium;
  final DateTime? premiumExpiresAt;

  // Estatísticas globais
  final int blogsCount;
  final int postsCount;
  final int commentsCount;
  final int itemsCount;
  final int joinedCommunitiesCount; // era communities_count
  final int followersCount;
  final int followingCount;

  // Check-in global
  final int consecutiveCheckinDays;
  final DateTime? lastCheckinAt;
  final int brokenStreaks;

  // Onboarding
  final bool hasCompletedOnboarding;

  // Metadata
  final int onlineStatus; // 1=Online, 2=Offline (era String)
  final DateTime? lastSeenAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Campos calculados (não na tabela)
  final bool? isFollowing;
  final bool? isFollowedBy;

  const UserModel({
    required this.id,
    this.aminoId = '',
    required this.nickname,
    this.isNicknameVerified = false,
    this.email,
    this.iconUrl,
    this.bannerUrl,
    this.bio = '',
    this.isTeamAdmin = false,
    this.isTeamModerator = false,
    this.isSystemAccount = false,
    this.level = 1,
    this.reputation = 0,
    this.coins = 0,
    this.coinsFloat = 0.0,
    this.businessCoins = 0,
    this.isPremium = false,
    this.premiumExpiresAt,
    this.blogsCount = 0,
    this.postsCount = 0,
    this.commentsCount = 0,
    this.itemsCount = 0,
    this.joinedCommunitiesCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.consecutiveCheckinDays = 0,
    this.lastCheckinAt,
    this.brokenStreaks = 0,
    this.hasCompletedOnboarding = false,
    this.onlineStatus = 2,
    this.lastSeenAt,
    required this.createdAt,
    required this.updatedAt,
    this.isFollowing,
    this.isFollowedBy,
  });

  /// Indica se o usuário está online (online_status == 1).
  bool get isOnline => onlineStatus == 1;

  /// Indica se o usuário é membro da equipe (admin ou moderador global).
  bool get isTeamMember => isTeamAdmin || isTeamModerator;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      aminoId: json['amino_id'] as String? ?? '',
      nickname: json['nickname'] as String? ?? s.user2,
      isNicknameVerified: json['is_nickname_verified'] as bool? ?? false,
      email: json['email'] as String?,
      iconUrl: json['icon_url'] as String?,
      bannerUrl: json['banner_url'] as String?,
      bio: json['bio'] as String? ?? '',
      isTeamAdmin: json['is_team_admin'] as bool? ?? false,
      isTeamModerator: json['is_team_moderator'] as bool? ?? false,
      isSystemAccount: json['is_system_account'] as bool? ?? false,
      level: json['level'] as int? ?? 1,
      reputation: json['reputation'] as int? ?? 0,
      coins: json['coins'] as int? ?? 0,
      coinsFloat: (json['coins_float'] as num?)?.toDouble() ?? 0.0,
      businessCoins: json['business_coins'] as int? ?? 0,
      isPremium: json['is_premium'] as bool? ?? false,
      premiumExpiresAt: json['premium_expires_at'] != null
          ? DateTime.tryParse(json['premium_expires_at'] as String)
          : null,
      blogsCount: json['blogs_count'] as int? ?? 0,
      postsCount: json['posts_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      itemsCount: json['items_count'] as int? ?? 0,
      joinedCommunitiesCount: json['joined_communities_count'] as int? ?? 0,
      followersCount: json['followers_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      consecutiveCheckinDays: json['consecutive_checkin_days'] as int? ?? 0,
      lastCheckinAt: json['last_checkin_at'] != null
          ? DateTime.tryParse(json['last_checkin_at'] as String)
          : null,
      brokenStreaks: json['broken_streaks'] as int? ?? 0,
      hasCompletedOnboarding:
          json['has_completed_onboarding'] as bool? ?? false,
      onlineStatus: json['online_status'] as int? ?? 2,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.tryParse(json['last_seen_at'] as String)
          : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
      isFollowing: json['is_following'] as bool?,
      isFollowedBy: json['is_followed_by'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amino_id': aminoId,
      'nickname': nickname,
      'is_nickname_verified': isNicknameVerified,
      'icon_url': iconUrl,
      'banner_url': bannerUrl,
      'bio': bio,
      'level': level,
      'reputation': reputation,
      'coins': coins,
      'online_status': onlineStatus,
      'is_premium': isPremium,
    };
  }

  UserModel copyWith({
    String? nickname,
    String? iconUrl,
    String? bannerUrl,
    String? bio,
    int? level,
    int? reputation,
    int? coins,
    int? onlineStatus,
    bool? hasCompletedOnboarding,
  }) {
    return UserModel(
      id: id,
      aminoId: aminoId,
      nickname: nickname ?? this.nickname,
      isNicknameVerified: isNicknameVerified,
      email: email,
      iconUrl: iconUrl ?? this.iconUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      bio: bio ?? this.bio,
      isTeamAdmin: isTeamAdmin,
      isTeamModerator: isTeamModerator,
      isSystemAccount: isSystemAccount,
      level: level ?? this.level,
      reputation: reputation ?? this.reputation,
      coins: coins ?? this.coins,
      coinsFloat: coinsFloat,
      businessCoins: businessCoins,
      isPremium: isPremium,
      premiumExpiresAt: premiumExpiresAt,
      blogsCount: blogsCount,
      postsCount: postsCount,
      commentsCount: commentsCount,
      itemsCount: itemsCount,
      joinedCommunitiesCount: joinedCommunitiesCount,
      followersCount: followersCount,
      followingCount: followingCount,
      consecutiveCheckinDays: consecutiveCheckinDays,
      lastCheckinAt: lastCheckinAt,
      brokenStreaks: brokenStreaks,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      onlineStatus: onlineStatus ?? this.onlineStatus,
      lastSeenAt: lastSeenAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isFollowing: isFollowing,
      isFollowedBy: isFollowedBy,
    );
  }
}
