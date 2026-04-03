import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'supabase_service.dart';

/// Handler para mensagens em background (deve ser top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[Push] Background message: ${message.messageId}');
}

/// Serviço de Push Notifications via Firebase Cloud Messaging.
///
/// Gerencia:
/// - Registro do FCM token no Supabase
/// - Notificações em foreground via flutter_local_notifications
/// - Deep link handling a partir de notificações
/// - Canais de notificação (Android)
///
/// Para configurar:
/// 1. Crie um projeto Firebase em https://console.firebase.google.com
/// 2. Adicione o app Android com package name "com.nexushub.app"
/// 3. Baixe o google-services.json e coloque em android/app/
/// 4. Execute `flutterfire configure` para gerar firebase_options.dart
class PushNotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static StreamController<Map<String, dynamic>>? _notificationStreamController;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _messageOpenSubscription;

  /// Stream de notificações para a UI reagir
  static Stream<Map<String, dynamic>> get notificationStream {
    _notificationStreamController ??=
        StreamController<Map<String, dynamic>>.broadcast();
    return _notificationStreamController!.stream;
  }

  /// Inicializa o serviço de push notifications
  static Future<void> initialize() async {
    try {
      // Registrar handler de background
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Solicitar permissão
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: true,
        carPlay: false,
        criticalAlert: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[Push] Permissão negada pelo usuário');
        return;
      }

      // Configurar canais de notificação (Android)
      await _setupNotificationChannels();

      // Configurar flutter_local_notifications
      await _setupLocalNotifications();

      // Obter e registrar FCM token
      await _registerToken();

      // Listener para refresh do token
      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(_saveToken);

      // Listener para mensagens em foreground
      _foregroundSubscription?.cancel();
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Listener para quando o usuário toca na notificação
      _messageOpenSubscription?.cancel();
      _messageOpenSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Verificar se o app foi aberto por uma notificação
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      debugPrint('[Push] Serviço inicializado com sucesso');
    } catch (e) {
      debugPrint('[Push] Erro ao inicializar: $e');
    }
  }

  /// Configura os canais de notificação do Android
  static Future<void> _setupNotificationChannels() async {
    const channels = [
      AndroidNotificationChannel(
        'nexushub_default',
        'Geral',
        description: 'Notificações gerais do NexusHub',
        importance: Importance.defaultImportance,
      ),
      AndroidNotificationChannel(
        'nexushub_chat',
        'Mensagens',
        description: 'Notificações de novas mensagens',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'nexushub_social',
        'Social',
        description: 'Curtidas, comentários e seguidores',
        importance: Importance.defaultImportance,
      ),
      AndroidNotificationChannel(
        'nexushub_community',
        'Comunidades',
        description: 'Atualizações das suas comunidades',
        importance: Importance.defaultImportance,
      ),
      AndroidNotificationChannel(
        'nexushub_moderation',
        'Moderação',
        description: 'Alertas de moderação',
        importance: Importance.high,
      ),
    ];

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      for (final channel in channels) {
        await androidPlugin.createNotificationChannel(channel);
      }
    }
  }

  /// Configura flutter_local_notifications
  static Future<void> _setupLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Quando o usuário toca na notificação local
        if (details.payload != null) {
          try {
            final data = jsonDecode(details.payload!);
            _notificationStreamController?.add(data);
          } catch (e) {
            debugPrint('[push_notification_service] Erro: $e');
          }
        }
      },
    );
  }

  /// Registra o FCM token no Supabase
  static Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(token);
      }
    } catch (e) {
      debugPrint('[Push] Erro ao obter token: $e');
    }
  }

  /// Salva o FCM token no perfil do usuário
  static Future<void> _saveToken(String token) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      await SupabaseService.table('profiles').update({
        'fcm_token': token,
      }).eq('id', userId);
      debugPrint('[Push] Token salvo: ${token.substring(0, 20)}...');
    } catch (e) {
      debugPrint('[Push] Erro ao salvar token: $e');
    }
  }

  /// Lida com mensagens recebidas em foreground
  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[Push] Foreground: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    // Determinar o canal baseado no tipo de notificação
    final type = message.data['type'] as String? ?? 'default';
    String channelId;
    switch (type) {
      case 'chat_message':
      case 'chat_mention':
        channelId = 'nexushub_chat';
        break;
      case 'like':
      case 'comment':
      case 'follow':
      case 'wall_post':
        channelId = 'nexushub_social';
        break;
      case 'community_update':
      case 'community_invite':
        channelId = 'nexushub_community';
        break;
      case 'moderation':
      case 'strike':
      case 'ban':
        channelId = 'nexushub_moderation';
        break;
      default:
        channelId = 'nexushub_default';
    }

    // Mostrar notificação local
    _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId.replaceAll('nexushub_', '').toUpperCase(),
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );

    // Emitir para a stream
    _notificationStreamController?.add(message.data);
  }

  /// Lida com toque na notificação (app em background/terminated)
  static void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[Push] Notification tap: ${message.data}');
    _notificationStreamController?.add(message.data);
  }

  /// Inscrever-se em um tópico (ex: comunidade)
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('[Push] Inscrito no tópico: $topic');
    } catch (e) {
      debugPrint('[Push] Erro ao inscrever em tópico: $e');
    }
  }

  /// Desinscrever-se de um tópico
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('[Push] Erro ao desinscrever de tópico: $e');
    }
  }

  /// Remove o token FCM (logout)
  static Future<void> clearToken() async {
    final userId = SupabaseService.currentUserId;
    if (userId != null) {
      try {
        await SupabaseService.table('profiles').update({
          'fcm_token': null,
        }).eq('id', userId);
      } catch (e) {
        debugPrint('[push_notification_service] Erro: $e');
      }
    }
    await _messaging.deleteToken();
  }

  /// Libera recursos
  static void dispose() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _foregroundSubscription?.cancel();
    _foregroundSubscription = null;
    _messageOpenSubscription?.cancel();
    _messageOpenSubscription = null;
    _notificationStreamController?.close();
    _notificationStreamController = null;
  }
}
