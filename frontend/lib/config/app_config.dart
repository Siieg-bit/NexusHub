import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configurações de infraestrutura do aplicativo NexusHub.
///
/// Esta classe contém APENAS credenciais e configurações de conexão que
/// precisam estar disponíveis antes do Supabase inicializar.
///
/// Constantes de gamificação, paginação, limites e regras de negócio foram
/// migradas para RemoteConfigService (tabela app_remote_config no Supabase).
/// Use RemoteConfigService para acessar esses valores dinâmicos.
class AppConfig {
  AppConfig._();

  // ============================================================================
  // SUPABASE
  // ============================================================================

  /// URL do projeto Supabase
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? 'https://ylvzqqvcanzzswjkqeya.supabase.co';

  /// Publishable API Key do Supabase — substitui a antiga anon key (JWT).
  /// Segura para uso no client-side com RLS habilitado.
  /// Ref: https://supabase.com/dashboard > Settings > API Keys
  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? 'sb_publishable_HYsYzaF8DuBgXpqJAICJ1Q_b73GLUeb';

  // ============================================================================
  // AGORA RTC (Voice Chat — Sala de Projeção)
  // ============================================================================

  /// App ID do Agora RTC — obtenha em https://console.agora.io > Project Management
  /// NUNCA coloque o App Certificate aqui — use apenas nos Supabase Edge Function Secrets.
  static String get agoraAppId => dotenv.env['AGORA_APP_ID'] ?? '';

  /// Indica se o voice chat está habilitado (App ID configurado)
  static bool get isVoiceChatEnabled => agoraAppId.isNotEmpty;

  // ============================================================================
  // APP
  // ============================================================================
  static const String appName = 'NexusHub';
  static const String appVersion = '1.0.0';
}
