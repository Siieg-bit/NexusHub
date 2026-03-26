/// Configurações globais do aplicativo NexusHub.
/// Credenciais do Supabase configuradas para o projeto de produção.
class AppConfig {
  AppConfig._();

  // ============================================================================
  // SUPABASE
  // ============================================================================

  /// URL do projeto Supabase
  static const String supabaseUrl = 'https://SEU_PROJETO.supabase.co';

  /// Chave anônima do Supabase (publishable key — segura para uso no client)
  static const String supabaseAnonKey =
      'SUA_SUPABASE_ANON_KEY_AQUI';

  // ============================================================================
  // APP
  // ============================================================================

  static const String appName = 'NexusHub';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Conecte-se com suas comunidades favoritas';

  // ============================================================================
  // GAMIFICAÇÃO
  // ============================================================================

  /// XP necessário para cada nível (índice = nível - 1)
  static const List<int> xpThresholds = [
    0,     // Nível 1
    100,   // Nível 2
    300,   // Nível 3
    600,   // Nível 4
    1000,  // Nível 5
    1500,  // Nível 6
    2200,  // Nível 7
    3000,  // Nível 8
    4000,  // Nível 9
    5200,  // Nível 10
    6500,  // Nível 11
    8000,  // Nível 12
    9700,  // Nível 13
    11600, // Nível 14
    13700, // Nível 15
    16000, // Nível 16
    18500, // Nível 17
    21200, // Nível 18
    24100, // Nível 19
    27200, // Nível 20
  ];

  /// XP ganho por ação
  static const int xpPerPost = 10;
  static const int xpPerComment = 3;
  static const int xpPerLikeReceived = 2;
  static const int xpPerCheckIn = 5;
  static const int xpPerJoinCommunity = 5;

  // ============================================================================
  // PAGINAÇÃO
  // ============================================================================

  static const int defaultPageSize = 20;
  static const int chatPageSize = 50;
  static const int searchPageSize = 15;

  // ============================================================================
  // LIMITES
  // ============================================================================

  static const int maxPostTitleLength = 300;
  static const int maxPostContentLength = 10000;
  static const int maxCommentLength = 2000;
  static const int maxMessageLength = 5000;
  static const int maxBioLength = 500;
  static const int maxCommunityNameLength = 100;
  static const int maxMediaPerPost = 10;
  static const int maxAvatarSizeBytes = 5 * 1024 * 1024; // 5MB
}
