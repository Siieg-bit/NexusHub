/// Constantes do aplicativo NexusHub.

class AppConstants {
  AppConstants._();

  // ====================================================================
  // APP INFO
  // ====================================================================
  static const String appName = s.nexusHub;
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';

  // ====================================================================
  // LIMITES
  // ====================================================================
  static const int maxPostTitleLength = 200;
  static const int maxPostContentLength = 10000;
  static const int maxCommentLength = 2000;
  static const int maxBioLength = 500;
  static const int maxNicknameLength = 30;
  static const int minNicknameLength = 3;
  static const int maxTagsPerPost = 10;
  static const int maxMediaPerPost = 10;
  static const int maxCommunityNameLength = 50;
  static const int maxCommunityDescLength = 1000;
  static const int maxMessageLength = 5000;
  static const int maxChatMembers = 1000;

  // ====================================================================
  // PAGINAÇÃO
  // ====================================================================
  static const int feedPageSize = 20;
  static const int chatPageSize = 50;
  static const int searchPageSize = 20;
  static const int leaderboardPageSize = 50;
  static const int commentsPageSize = 30;

  // ====================================================================
  // GAMIFICAÇÃO
  // ====================================================================
  static const int xpPerPost = 10;
  static const int xpPerComment = 5;
  static const int xpPerLike = 2;
  static const int xpPerCheckIn = 15;
  static const int xpCheckInStreak7 = 50;
  static const int coinsPerCheckIn = 5;
  static const int coinsCheckInStreak7 = 25;

  // ====================================================================
  // ROLES
  // ====================================================================
  static const String roleLeader = 'leader';
  static const String roleCurator = 'curator';
  static const String roleMember = 'member';

  // ====================================================================
  // POST TYPES
  // ====================================================================
  static const String postTypeBlog = 'blog';
  static const String postTypeImage = 'image';
  static const String postTypePoll = 'poll';
  static const String postTypeQuiz = 'quiz';
  static const String postTypeWiki = 'wiki';

  // ====================================================================
  // CHAT TYPES
  // ====================================================================
  static const String chatTypePublic = 'public';
  static const String chatTypePrivate = 'private';
  static const String chatTypeDirect = 'direct';
  static const String chatTypeScreening = 'screening';

  // ====================================================================
  // STORAGE BUCKETS
  // ====================================================================
  static const String bucketAvatars = 'avatars';
  static const String bucketBanners = 'banners';
  static const String bucketPostMedia = 'post_media';
  static const String bucketChatMedia = 'chat_media';
  static const String bucketCommunityAssets = 'community-assets';
  static const String bucketWikiMedia = 'wiki-media';

  // ====================================================================
  // DEEP LINKS
  // ====================================================================
  static const String deepLinkScheme = 'nexushub';
  static const String deepLinkHost = 'app.nexushub.io';
}
