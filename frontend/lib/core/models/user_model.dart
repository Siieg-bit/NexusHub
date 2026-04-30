/// Modelo de usuário/perfil da plataforma.
import '../l10n/locale_provider.dart';

// =============================================================================
// TeamRole — Enum de cargos globais da equipe NexusHub
// =============================================================================
// Hierarquia (rank numérico):
//   100 → founder           (Fundador / CEO)
//    90 → co_founder        (Co-Fundador / CTO)
//    80 → team_admin        (Admin da plataforma)
//    70 → trust_safety      (Trust & Safety)
//    60 → support           (Suporte)
//    50 → bug_bounty        (Bug Bounty / Segurança)
//    40 → community_manager (Community Manager)
//     0 → none              (Usuário normal)
// =============================================================================
enum TeamRole {
  none,
  communityManager,
  bugBounty,
  support,
  trustSafety,
  teamAdmin,
  coFounder,
  founder;

  /// Rank numérico para comparações hierárquicas.
  int get rank => switch (this) {
    TeamRole.founder          => 100,
    TeamRole.coFounder        => 90,
    TeamRole.teamAdmin        => 80,
    TeamRole.trustSafety      => 70,
    TeamRole.support          => 60,
    TeamRole.bugBounty        => 50,
    TeamRole.communityManager => 40,
    TeamRole.none             => 0,
  };

  /// Label exibido na badge do perfil.
  String get label => switch (this) {
    TeamRole.founder          => 'Founder',
    TeamRole.coFounder        => 'Co-Founder',
    TeamRole.teamAdmin        => 'Team Admin',
    TeamRole.trustSafety      => 'Trust & Safety',
    TeamRole.support          => 'Support',
    TeamRole.bugBounty        => 'Bug Bounty',
    TeamRole.communityManager => 'Community Manager',
    TeamRole.none             => '',
  };

  /// Cor da borda da badge (fundo sempre transparente).
  /// Founder → branco exclusivo. Demais → cores distintas.
  String get borderColorHex => switch (this) {
    TeamRole.founder          => '#FFFFFF',   // Branco exclusivo
    TeamRole.coFounder        => '#FFD700',   // Dourado
    TeamRole.teamAdmin        => '#FF4444',   // Vermelho
    TeamRole.trustSafety      => '#3B82F6',   // Azul escuro
    TeamRole.support          => '#60A5FA',   // Azul claro
    TeamRole.bugBounty        => '#22C55E',   // Verde neon
    TeamRole.communityManager => '#A855F7',   // Roxo
    TeamRole.none             => '#FFFFFF',
  };

  /// Converte string do banco para enum.
  static TeamRole fromString(String? value) => switch (value) {
    'founder'           => TeamRole.founder,
    'co_founder'        => TeamRole.coFounder,
    'team_admin'        => TeamRole.teamAdmin,
    'trust_safety'      => TeamRole.trustSafety,
    'support'           => TeamRole.support,
    'bug_bounty'        => TeamRole.bugBounty,
    'community_manager' => TeamRole.communityManager,
    _                   => TeamRole.none,
  };

  /// Converte enum para string do banco.
  String get dbValue => switch (this) {
    TeamRole.founder          => 'founder',
    TeamRole.coFounder        => 'co_founder',
    TeamRole.teamAdmin        => 'team_admin',
    TeamRole.trustSafety      => 'trust_safety',
    TeamRole.support          => 'support',
    TeamRole.bugBounty        => 'bug_bounty',
    TeamRole.communityManager => 'community_manager',
    TeamRole.none             => 'none',
  };
}

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

  // Nova hierarquia de equipe
  final TeamRole teamRole;
  final int teamRank;

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
  final int wallCommentsCount;

  // Check-in global
  final int consecutiveCheckinDays;
  final DateTime? lastCheckinAt;
  final int brokenStreaks;

  // Onboarding
  final bool hasCompletedOnboarding;

  // Metadata
  final int onlineStatus; // 1=Online, 2=Offline (era String)
  final bool isGhostMode; // override manual para aparecer offline
  final DateTime? lastSeenAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Campos calculados (não na tabela)
  final bool? isFollowing;
  final bool? isFollowedBy;

  // Mood/Status
  final String? statusEmoji;
  final String? statusText;

  // Interesses
  final List<String> selectedInterests;

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
    this.teamRole = TeamRole.none,
    this.teamRank = 0,
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
    this.wallCommentsCount = 0,
    this.consecutiveCheckinDays = 0,
    this.lastCheckinAt,
    this.brokenStreaks = 0,
    this.hasCompletedOnboarding = false,
    this.onlineStatus = 2,
    this.isGhostMode = false,
    this.lastSeenAt,
    required this.createdAt,
    required this.updatedAt,
    this.isFollowing,
    this.isFollowedBy,
    this.statusEmoji,
    this.statusText,
    this.selectedInterests = const [],
  });

  static const Duration _presenceWindow = Duration(minutes: 15);

  DateTime? get lastSeenLocal => lastSeenAt?.toLocal();

  /// Indica se o usuário deve ser considerado online no modelo gradual.
  bool get isOnline {
    if (isGhostMode) return false;
    final seenAt = lastSeenAt;
    if (seenAt == null) return onlineStatus == 1;
    final elapsed = DateTime.now().toUtc().difference(seenAt.toUtc());
    return elapsed <= _presenceWindow;
  }

  /// Retorna quantos minutos arredondados em blocos de 15 min se passaram.
  int get lastActiveBucketMinutes {
    final seenAt = lastSeenAt;
    if (seenAt == null) return 0;
    final elapsedMinutes =
        DateTime.now().toUtc().difference(seenAt.toUtc()).inMinutes;
    if (elapsedMinutes <= 0) return 0;
    return ((elapsedMinutes + 14) ~/ 15) * 15;
  }

  /// Texto gradual de última atividade para UI simples.
  String get gradualPresenceLabel {
    if (isOnline) return 'online';
    final seenAt = lastSeenAt;
    if (seenAt == null) return 'offline';
    final elapsed = DateTime.now().toUtc().difference(seenAt.toUtc());
    if (elapsed.inMinutes < 1) return 'agora mesmo';
    if (elapsed.inMinutes < 60) {
      final m = elapsed.inMinutes;
      return 'há $m ${m == 1 ? 'minuto' : 'minutos'}';
    }
    if (elapsed.inHours < 24) {
      final h = elapsed.inHours;
      return 'há $h ${h == 1 ? 'hora' : 'horas'}';
    }
    if (elapsed.inDays < 30) {
      final d = elapsed.inDays;
      return 'há $d ${d == 1 ? 'dia' : 'dias'}';
    }
    if (elapsed.inDays < 365) {
      final mo = (elapsed.inDays / 30).floor();
      return 'há $mo ${mo == 1 ? 'mês' : 'meses'}';
    }
    final y = (elapsed.inDays / 365).floor();
    return 'há $y ${y == 1 ? 'ano' : 'anos'}';
  }

  // ── Getters de hierarquia de equipe ─────────────────────────────────────

  /// Indica se o usuário é membro da equipe (qualquer cargo global).
  bool get isTeamMember => teamRank > 0 || isTeamAdmin || isTeamModerator;

  /// Indica se o usuário é o Fundador da plataforma.
  bool get isFounder => teamRole == TeamRole.founder;

  /// Indica se o usuário é Co-Fundador ou superior.
  bool get isCoFounderOrAbove => teamRank >= 90;

  /// Indica se o usuário tem poder de moderação global (Trust & Safety+).
  bool get hasGlobalModerationPower => teamRank >= 70;

  /// Indica se o usuário pode gerenciar cargos de equipe (Team Admin+).
  bool get canManageTeamRoles => teamRank >= 80;

  /// Indica se o usuário tem um status/mood definido.
  bool get hasStatus =>
      (statusEmoji != null && statusEmoji!.isNotEmpty) ||
      (statusText != null && statusText!.isNotEmpty);

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final s = getStrings();
    final teamRoleStr = json['team_role'] as String?;
    final teamRankRaw = (json['team_rank'] as num?)?.toInt() ?? 0;
    final parsedTeamRole = TeamRole.fromString(teamRoleStr);

    // Retrocompatibilidade: se não tem team_role mas tem is_team_admin/moderator
    TeamRole effectiveTeamRole = parsedTeamRole;
    int effectiveTeamRank = teamRankRaw;
    if (parsedTeamRole == TeamRole.none && teamRankRaw == 0) {
      if (json['is_team_admin'] as bool? ?? false) {
        effectiveTeamRole = TeamRole.teamAdmin;
        effectiveTeamRank = 80;
      } else if (json['is_team_moderator'] as bool? ?? false) {
        effectiveTeamRole = TeamRole.trustSafety;
        effectiveTeamRank = 70;
      }
    }

    return UserModel(
      id: json['id'] as String? ?? '',
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
      teamRole: effectiveTeamRole,
      teamRank: effectiveTeamRank,
      level: (json['level'] as num?)?.toInt() ?? 1,
      reputation: (json['reputation'] as num?)?.toInt() ?? 0,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      coinsFloat: (json['coins_float'] as num?)?.toDouble() ?? 0.0,
      businessCoins: (json['business_coins'] as num?)?.toInt() ?? 0,
      isPremium: json['is_premium'] as bool? ?? false,
      premiumExpiresAt: json['premium_expires_at'] != null
          ? DateTime.tryParse(json['premium_expires_at'] as String)
          : null,
      blogsCount: (json['blogs_count'] as num?)?.toInt() ?? 0,
      postsCount: (json['posts_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      itemsCount: (json['items_count'] as num?)?.toInt() ?? 0,
      joinedCommunitiesCount: (json['joined_communities_count'] as num?)?.toInt() ?? 0,
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
      wallCommentsCount: (json['wall_comments_count'] as num?)?.toInt() ?? 0,
      consecutiveCheckinDays: (json['consecutive_checkin_days'] as num?)?.toInt() ?? 0,
      lastCheckinAt: json['last_checkin_at'] != null
          ? DateTime.tryParse(json['last_checkin_at'] as String)
          : null,
      brokenStreaks: (json['broken_streaks'] as num?)?.toInt() ?? 0,
      hasCompletedOnboarding:
          json['has_completed_onboarding'] as bool? ?? false,
      onlineStatus: (json['online_status'] as num?)?.toInt() ?? 2,
      isGhostMode: json['is_ghost_mode'] as bool? ?? false,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.tryParse(json['last_seen_at'] as String)
          : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
      isFollowing: json['is_following'] as bool?,
      isFollowedBy: json['is_followed_by'] as bool?,
      statusEmoji: json['status_emoji'] as String?,
      statusText: json['status_text'] as String?,
      selectedInterests: (json['selected_interests'] as List?)?.map((e) => e.toString()).toList() ?? [],
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
      'is_ghost_mode': isGhostMode,
      'is_premium': isPremium,
      'status_emoji': statusEmoji,
      'status_text': statusText,
      'team_role': teamRole.dbValue,
      'team_rank': teamRank,
    };
  }

  UserModel copyWith({
    String? aminoId,
    String? nickname,
    String? iconUrl,
    String? bannerUrl,
    String? bio,
    int? level,
    int? reputation,
    int? coins,
    int? onlineStatus,
    bool? isGhostMode,
    DateTime? lastSeenAt,
    bool? hasCompletedOnboarding,
    String? statusEmoji,
    String? statusText,
    List<String>? selectedInterests,
    TeamRole? teamRole,
    int? teamRank,
  }) {
    return UserModel(
      id: id,
      aminoId: aminoId ?? this.aminoId,
      nickname: nickname ?? this.nickname,
      isNicknameVerified: isNicknameVerified,
      email: email,
      iconUrl: iconUrl ?? this.iconUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      bio: bio ?? this.bio,
      isTeamAdmin: isTeamAdmin,
      isTeamModerator: isTeamModerator,
      isSystemAccount: isSystemAccount,
      teamRole: teamRole ?? this.teamRole,
      teamRank: teamRank ?? this.teamRank,
      level: level ?? this.level,
      reputation: reputation ?? this.reputation,
      coins: coins ?? this.coins,
      coinsFloat: coinsFloat,
      businessCoins: businessCoins,
      isPremium: isPremium,
      premiumExpiresAt: premiumExpiresAt,
      isGhostMode: isGhostMode ?? this.isGhostMode,
      blogsCount: blogsCount,
      postsCount: postsCount,
      commentsCount: commentsCount,
      itemsCount: itemsCount,
      joinedCommunitiesCount: joinedCommunitiesCount,
      followersCount: followersCount,
      followingCount: followingCount,
      wallCommentsCount: wallCommentsCount,
      consecutiveCheckinDays: consecutiveCheckinDays,
      lastCheckinAt: lastCheckinAt,
      brokenStreaks: brokenStreaks,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      onlineStatus: onlineStatus ?? this.onlineStatus,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isFollowing: isFollowing,
      isFollowedBy: isFollowedBy,
      statusEmoji: statusEmoji ?? this.statusEmoji,
      statusText: statusText ?? this.statusText,
      selectedInterests: selectedInterests ?? this.selectedInterests,
    );
  }
}
