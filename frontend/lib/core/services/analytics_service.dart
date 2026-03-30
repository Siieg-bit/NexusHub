import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Serviço centralizado de Analytics e Crash Reporting para o NexusHub.
///
/// Encapsula Firebase Analytics e Crashlytics, fornecendo métodos
/// semânticos para rastrear eventos importantes do app.
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  // ─── Inicialização ─────────────────────────────────────────────────────────

  /// Inicializa o serviço. Deve ser chamado após Firebase.initializeApp().
  static Future<void> init() async {
    // Em debug, desabilitar coleta para não poluir dados de produção
    await _analytics.setAnalyticsCollectionEnabled(!kDebugMode);
    await _crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

    // Capturar erros Flutter não tratados
    FlutterError.onError = (errorDetails) {
      _crashlytics.recordFlutterFatalError(errorDetails);
    };

    // Capturar erros assíncronos fora do Flutter
    PlatformDispatcher.instance.onError = (error, stack) {
      _crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // ─── Identificação do usuário ──────────────────────────────────────────────

  static Future<void> setUser(String userId, {String? displayName}) async {
    await _analytics.setUserId(id: userId);
    await _crashlytics.setUserIdentifier(userId);
    if (displayName != null) {
      await _analytics.setUserProperty(name: 'display_name', value: displayName);
    }
  }

  static Future<void> clearUser() async {
    await _analytics.setUserId(id: null);
    await _crashlytics.setUserIdentifier('');
  }

  // ─── Navegação ─────────────────────────────────────────────────────────────

  static Future<void> logScreen(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }

  // ─── Autenticação ──────────────────────────────────────────────────────────

  static Future<void> logLogin(String method) async {
    await _analytics.logLogin(loginMethod: method);
  }

  static Future<void> logSignUp(String method) async {
    await _analytics.logSignUp(signUpMethod: method);
  }

  // ─── Feed & Posts ──────────────────────────────────────────────────────────

  static Future<void> logPostCreated({
    required String type,
    required String communityId,
    bool hasMedia = false,
    bool hasGif = false,
    String visibility = 'public',
  }) async {
    await _analytics.logEvent(
      name: 'post_created',
      parameters: {
        'post_type': type,
        'community_id': communityId,
        'has_media': hasMedia,
        'has_gif': hasGif,
        'visibility': visibility,
      },
    );
  }

  static Future<void> logPostLiked(String postId) async {
    await _analytics.logEvent(
      name: 'post_liked',
      parameters: {'post_id': postId},
    );
  }

  static Future<void> logPostShared(String postId, String method) async {
    await _analytics.logShare(
      contentType: 'post',
      itemId: postId,
      method: method,
    );
  }

  // ─── Chat ──────────────────────────────────────────────────────────────────

  static Future<void> logMessageSent({
    required String chatId,
    required String type, // text, image, video, sticker, gif, audio
  }) async {
    await _analytics.logEvent(
      name: 'message_sent',
      parameters: {
        'chat_id': chatId,
        'message_type': type,
      },
    );
  }

  static Future<void> logCallStarted({
    required String chatId,
    required bool isVideo,
  }) async {
    await _analytics.logEvent(
      name: 'call_started',
      parameters: {
        'chat_id': chatId,
        'is_video': isVideo,
      },
    );
  }

  // ─── Stories ───────────────────────────────────────────────────────────────

  static Future<void> logStoryCreated(String type) async {
    await _analytics.logEvent(
      name: 'story_created',
      parameters: {'story_type': type},
    );
  }

  static Future<void> logStoryViewed(String storyId) async {
    await _analytics.logEvent(
      name: 'story_viewed',
      parameters: {'story_id': storyId},
    );
  }

  // ─── Comunidade ────────────────────────────────────────────────────────────

  static Future<void> logCommunityJoined(String communityId) async {
    await _analytics.logJoinGroup(groupId: communityId);
  }

  static Future<void> logCommunityCreated(String communityId) async {
    await _analytics.logEvent(
      name: 'community_created',
      parameters: {'community_id': communityId},
    );
  }

  // ─── Loja & IAP ────────────────────────────────────────────────────────────

  static Future<void> logPurchase({
    required String itemId,
    required String itemName,
    required double price,
    String currency = 'BRL',
  }) async {
    await _analytics.logPurchase(
      currency: currency,
      value: price,
      items: [
        AnalyticsEventItem(
          itemId: itemId,
          itemName: itemName,
          price: price,
        ),
      ],
    );
  }

  static Future<void> logSubscriptionStarted(String plan) async {
    await _analytics.logEvent(
      name: 'subscription_started',
      parameters: {'plan': plan},
    );
  }

  // ─── Erros manuais ─────────────────────────────────────────────────────────

  static Future<void> recordError(
    dynamic exception,
    StackTrace? stackTrace, {
    bool fatal = false,
    String? reason,
  }) async {
    await _crashlytics.recordError(
      exception,
      stackTrace,
      fatal: fatal,
      reason: reason,
    );
  }

  static Future<void> log(String message) async {
    await _crashlytics.log(message);
  }
}
