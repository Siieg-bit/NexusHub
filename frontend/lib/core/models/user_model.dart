/// Modelo de usuário/perfil da plataforma.
/// Baseado na engenharia reversa do modelo User do Amino original.
class UserModel {
  final String id;
  final String aminoId;
  final String nickname;
  final String? email;
  final String? avatarUrl;
  final String? bannerUrl;
  final String bio;
  final int globalLevel;
  final int reputation;
  final int xp;
  final int coins;
  final String onlineStatus;
  final bool isVerified;
  final bool isPremium;
  final int consecutiveCheckInDays;
  final int postsCount;
  final int commentsCount;
  final int followersCount;
  final int followingCount;
  final int communitiesCount;
  final DateTime createdAt;
  final bool? isFollowing;
  final bool? isFollowedBy;

  const UserModel({
    required this.id,
    required this.aminoId,
    required this.nickname,
    this.email,
    this.avatarUrl,
    this.bannerUrl,
    this.bio = '',
    this.globalLevel = 1,
    this.reputation = 0,
    this.xp = 0,
    this.coins = 0,
    this.onlineStatus = 'offline',
    this.isVerified = false,
    this.isPremium = false,
    this.consecutiveCheckInDays = 0,
    this.postsCount = 0,
    this.commentsCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.communitiesCount = 0,
    required this.createdAt,
    this.isFollowing,
    this.isFollowedBy,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      aminoId: json['amino_id'] as String? ?? '',
      nickname: json['nickname'] as String? ?? 'Usuário',
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bannerUrl: json['banner_url'] as String?,
      bio: json['bio'] as String? ?? '',
      globalLevel: json['global_level'] as int? ?? 1,
      reputation: json['reputation'] as int? ?? 0,
      xp: json['xp'] as int? ?? 0,
      coins: json['coins'] as int? ?? 0,
      onlineStatus: json['online_status'] as String? ?? 'offline',
      isVerified: json['is_verified'] as bool? ?? false,
      isPremium: json['is_premium'] as bool? ?? false,
      consecutiveCheckInDays: json['consecutive_check_in_days'] as int? ?? 0,
      postsCount: json['posts_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      followersCount: json['followers_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      communitiesCount: json['communities_count'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      isFollowing: json['is_following'] as bool?,
      isFollowedBy: json['is_followed_by'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amino_id': aminoId,
      'nickname': nickname,
      'email': email,
      'avatar_url': avatarUrl,
      'banner_url': bannerUrl,
      'bio': bio,
      'global_level': globalLevel,
      'reputation': reputation,
      'xp': xp,
      'coins': coins,
      'online_status': onlineStatus,
      'is_verified': isVerified,
      'is_premium': isPremium,
    };
  }

  UserModel copyWith({
    String? nickname,
    String? avatarUrl,
    String? bannerUrl,
    String? bio,
    int? globalLevel,
    int? reputation,
    int? xp,
    int? coins,
    String? onlineStatus,
  }) {
    return UserModel(
      id: id,
      aminoId: aminoId,
      nickname: nickname ?? this.nickname,
      email: email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      bio: bio ?? this.bio,
      globalLevel: globalLevel ?? this.globalLevel,
      reputation: reputation ?? this.reputation,
      xp: xp ?? this.xp,
      coins: coins ?? this.coins,
      onlineStatus: onlineStatus ?? this.onlineStatus,
      isVerified: isVerified,
      isPremium: isPremium,
      consecutiveCheckInDays: consecutiveCheckInDays,
      postsCount: postsCount,
      commentsCount: commentsCount,
      followersCount: followersCount,
      followingCount: followingCount,
      communitiesCount: communitiesCount,
      createdAt: createdAt,
    );
  }
}
