import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'notification_channel_config_service.dart';
import 'supabase_service.dart';
import '../../firebase_options.dart';
import '../l10n/locale_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show CountOption;

/// Handler para mensagens em background (deve ser top-level function).
/// Chamado quando o app está em background ou terminado e chega uma mensagem FCM.
/// Para mensagens com payload 'notification', o FCM exibe automaticamente na bandeja.
/// Para mensagens 'data-only', precisamos exibir a notificação manualmente.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  debugPrint('[Push] Background message: ${message.messageId}');

  // Se a mensagem não tem payload 'notification' (data-only),
  // precisamos exibir a notificação local manualmente.
  if (message.notification == null && message.data.isNotEmpty) {
    final plugin = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );
    await plugin.initialize(initSettings);

    final title = message.data['title'] as String? ?? 'NexusHub';
    final body = message.data['content'] as String? ??
        message.data['body'] as String? ?? '';
    final type = message.data['type'] as String? ?? 'default';

    final channelId = NotificationChannelConfigService.channelIdForType(type);
    final channelName =
        NotificationChannelConfigService.channelNameForId(channelId);

    await plugin.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }
}

/// Handler top-level para toque em notificação local quando o app estava terminado.
/// Deve ser top-level function (não pode ser método estático) para funcionar
/// com flutter_local_notifications em background.
@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse details) {
  // Não há como navegar aqui pois o app pode não estar inicializado.
  // O payload é salvo em _pendingLocalPayload e processado quando o app abre
  // e o listener é registrado via consumePendingNotification().
  debugPrint('[Push] Background notification response: ${details.payload}');
  if (details.payload != null) {
    PushNotificationService._pendingLocalPayload = details.payload;
  }
}

/// Serviço de Push Notifications via Firebase Cloud Messaging.
///
/// Gerencia:
/// - Registro do FCM token no Supabase
/// - Notificações em foreground via flutter_local_notifications
/// - Deep link handling a partir de notificações
/// - Canais de notificação (Android)
///
/// Serviço centralizado de push via Firebase para o app.
/// A configuração Android já está versionada no projeto e a inicialização
/// em foreground/background usa as opções definidas em `firebase_options.dart`.
class PushNotificationService {

  /// ID da thread de chat atualmente aberta pelo usuário.
  /// Quando preenchido, notificações locais de `chat_message` para
  /// esse chat específico são suprimidas (usuário já está vendo as mensagens).
  static String? activeChatThreadId;

  /// Payload pendente de notificação local (app estava terminado ao tocar).
  /// Armazenado pelo _onBackgroundNotificationResponse e consumido em
  /// consumePendingNotification() quando o listener da UI já está registrado.
  static String? _pendingLocalPayload;

  /// Payload pendente de mensagem FCM inicial (app terminado, aberto via tap).
  /// Armazenado quando getInitialMessage() retorna antes do listener estar pronto.
  static Map<String, dynamic>? _pendingFcmData;

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
      _foregroundSubscription =
          FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Listener para quando o usuário toca na notificação (app em background)
      _messageOpenSubscription?.cancel();
      _messageOpenSubscription =
          FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Verificar se o app foi aberto por uma notificação FCM (app terminado).
      // O getInitialMessage() pode ser chamado antes do listener da UI estar
      // registrado (race condition com unawaited). Armazenamos o dado em
      // _pendingFcmData e o consumimos em consumePendingNotification().
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[Push] initialMessage detectado — armazenando para consumo posterior');
        _pendingFcmData = initialMessage.data;
        clearAppBadge();
      }

      // Verificar se há notificação local pendente (app terminado, tap local).
      // O _onBackgroundNotificationResponse armazena em _pendingLocalPayload.
      // Tentamos também via getNotificationAppLaunchDetails para cobrir o caso
      // em que o app foi aberto diretamente pelo toque na notificação local.
      final launchDetails =
          await _localNotifications.getNotificationAppLaunchDetails();
      if (launchDetails != null &&
          launchDetails.didNotificationLaunchApp &&
          launchDetails.notificationResponse?.payload != null) {
        debugPrint('[Push] launchDetails detectado — armazenando para consumo posterior');
        _pendingLocalPayload ??= launchDetails.notificationResponse!.payload;
      }

      debugPrint('[Push] Serviço inicializado com sucesso');
    } catch (e) {
      debugPrint('[Push] Erro ao inicializar: $e');
    }
  }

  /// Consome notificações pendentes (FCM inicial e local) e as emite no stream.
  ///
  /// Deve ser chamado pelo widget raiz após registrar o listener no
  /// notificationStream, garantindo que o payload não seja perdido por
  /// race condition entre initialize() e didChangeDependencies().
  static void consumePendingNotification() {
    // Consumir payload FCM pendente
    final fcmData = _pendingFcmData;
    if (fcmData != null) {
      _pendingFcmData = null;
      debugPrint('[Push] Emitindo FCM pendente: $fcmData');
      _notificationStreamController?.add(fcmData);
    }

    // Consumir payload de notificação local pendente
    final localPayload = _pendingLocalPayload;
    if (localPayload != null) {
      _pendingLocalPayload = null;
      try {
        final data = jsonDecode(localPayload) as Map<String, dynamic>;
        debugPrint('[Push] Emitindo notificação local pendente: $data');
        _notificationStreamController?.add(data);
      } catch (e) {
        debugPrint('[Push] Erro ao decodificar payload local pendente: $e');
      }
    }
  }

  /// Configura os canais de notificação do Android
  static Future<void> _setupNotificationChannels() async {
    final s = getStrings();
    final channels = NotificationChannelConfigService.getChannels(
      generalDescription: s.generalNotifications,
      chatDescription: s.newMessageNotifications,
      socialDescription: s.likesCommentsFollowers,
      communityDescription: s.communityUpdates,
      moderationName: s.moderationLabel,
      moderationDescription: s.moderationAlerts,
    ).map((channel) => channel.toAndroidChannel()).toList(growable: false);

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

    // iOS: solicitar permissões de exibição de notificações locais
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Quando o usuário toca na notificação local (app em foreground ou background)
        if (details.payload != null) {
          try {
            final data = jsonDecode(details.payload!) as Map<String, dynamic>;
            _notificationStreamController?.add(data);
          } catch (e) {
            debugPrint('[Push] Erro ao decodificar payload local: $e');
          }
        }
      },
      // Quando o app estava terminado e o usuário tocou na notificação local.
      // O payload é armazenado em _pendingLocalPayload e consumido via
      // consumePendingNotification() quando o listener da UI estiver pronto.
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
    );

    // iOS: configurar apresentação de notificações em foreground
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
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

    // Suprimir notificação local se o usuário já está naquele chat
    final type = message.data['type'] as String? ?? 'default';
    final chatTypes = {'chat_message', 'chat_mention', 'chat', 'dm_invite', 'chat_invite'};
    if (chatTypes.contains(type) && activeChatThreadId != null) {
      final incomingThreadId = message.data['chat_thread_id'] as String?;
      if (incomingThreadId != null && incomingThreadId == activeChatThreadId) {
        debugPrint('[Push] Suprimindo notificação local — usuário já está no chat $incomingThreadId');
        // Não emitir no stream global: ele é usado para navegação de taps.
        // A mensagem já chega pelo realtime do chat aberto; emitir aqui faz
        // o router empilhar/reabrir a mesma sala, causando refresh visual.
        return;
      }
    }

    // Determinar o canal versionado baseado no tipo de notificação.
    final channelId = NotificationChannelConfigService.channelIdForType(type);
    final channelName =
        NotificationChannelConfigService.channelNameForId(channelId);

    // Mostrar notificação local com configurações otimizadas
    _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          enableLights: true,
          playSound: true,
          ticker: notification.title,
        ),
      ),
      payload: jsonEncode(message.data),
    );

    // Não emitir para a stream global em foreground. Esse stream é consumido
    // pelo app como navegação de toque em notificação; emitir no recebimento
    // faz a tela atual navegar/recarregar sem ação do usuário. A navegação de
    // foreground continua acontecendo pelo callback de tap da notificação local.
    // Incrementar badge no ícone do app
    _incrementAppBadge();
  }

  /// Lida com toque na notificação FCM (app em background — não terminado).
  /// Para app terminado, o payload é capturado via getInitialMessage() em
  /// initialize() e emitido via consumePendingNotification().
  static void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[Push] Notification tap (background): ${message.data}');
    _notificationStreamController?.add(message.data);
    // Limpar badge ao abrir notificação
    clearAppBadge();
  }

  /// Incrementa o badge do ícone do app
  static Future<void> _incrementAppBadge() async {
    try {
      final supported = await FlutterAppBadger.isAppBadgeSupported();
      if (!supported) return;
      // Buscar contagem real de não lidas do Supabase
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final res = await SupabaseService.client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false)
          .count(CountOption.exact);
      final count = res.count;
      await FlutterAppBadger.updateBadgeCount(count);
    } catch (e) {
      debugPrint('[Push] Erro ao atualizar badge: $e');
    }
  }

  /// Limpa o badge do ícone do app
  static Future<void> clearAppBadge() async {
    try {
      final supported = await FlutterAppBadger.isAppBadgeSupported();
      if (supported) await FlutterAppBadger.removeBadge();
    } catch (e) {
      debugPrint('[Push] Erro ao limpar badge: $e');
    }
  }

  /// Atualiza o badge com a contagem atual de não lidas
  static Future<void> updateBadgeFromUnreadCount(int count) async {
    try {
      final supported = await FlutterAppBadger.isAppBadgeSupported();
      if (!supported) return;
      if (count > 0) {
        await FlutterAppBadger.updateBadgeCount(count);
      } else {
        await FlutterAppBadger.removeBadge();
      }
    } catch (e) {
      debugPrint('[Push] Erro ao atualizar badge: $e');
    }
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
        debugPrint('[Push] Erro ao remover token: $e');
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
