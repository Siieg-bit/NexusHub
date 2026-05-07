/// Constantes estáticas do aplicativo NexusHub.
///
/// NOTA: Limites, paginação, gamificação, links e webhooks foram migrados
/// para RemoteConfigService (tabela app_remote_config). Use RemoteConfigService
/// para acessar esses valores dinâmicos.
class AppConstants {
  AppConstants._();

  // ====================================================================
  // APP INFO
  // ====================================================================
  static const String appName = 'NexusHub';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';

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
  static const String bucketPostMedia = 'post-media';
  static const String bucketChatMedia = 'chat-media';
  static const String bucketCommunityAssets = 'community-assets';
  static const String bucketWikiMedia = 'wiki-media';

  // ====================================================================
  // DEEP LINKS
  // ====================================================================
  static const String deepLinkScheme = 'nexushub';
  static const String deepLinkHost = 'app.nexushub.io';

  // Webhook do Discord migrado para RemoteConfigService:
  //   RemoteConfigService.discordBugReportWebhook
}
