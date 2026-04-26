import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'supabase_service.dart';

/// Serviço para gerenciar Web Push Notifications em navegadores
/// 
/// Responsabilidades:
/// - Registrar Service Worker
/// - Solicitar permissão de notificação
/// - Gerenciar push subscriptions
/// - Sincronizar com Supabase
class WebPushService {
  // VAPID Public Key (gerada via script)
  static const String _vapidPublicKey =
      'cTUHAuasajNV6fcaCehYIJr4SSetxUWSNKnQqa_NjyoYgWTOk_Dd1tuaKFPXCrcRSWoHtTe4iYishpswZyU0Hc';

  static const String _serviceWorkerPath = '/service_worker.js';

  /// Inicializar Web Push
  static Future<void> initialize() async {
    if (!kIsWeb) {
      debugPrint('[WebPush] Não é plataforma web, ignorando');
      return;
    }

    try {
      debugPrint('[WebPush] Inicializando...');

      // Registrar Service Worker
      await _registerServiceWorker();

      // Solicitar permissão
      final permission = await _requestPermission();
      if (permission != 'granted') {
        debugPrint('[WebPush] Permissão negada pelo usuário');
        return;
      }

      // Obter subscription
      final subscription = await _getPushSubscription();
      if (subscription != null) {
        await _savePushSubscription(subscription);
        debugPrint('[WebPush] Subscription salva com sucesso');
      }

      debugPrint('[WebPush] Inicializado com sucesso');
    } catch (e) {
      debugPrint('[WebPush] Erro ao inicializar: $e');
    }
  }

  /// Registrar Service Worker
  static Future<void> _registerServiceWorker() async {
    if (!kIsWeb) return;

    try {
      final serviceWorkerContainer = html.window.navigator.serviceWorker;
      if (serviceWorkerContainer == null) {
        throw Exception('Service Workers não suportados neste navegador');
      }

      final registration = await serviceWorkerContainer.register(_serviceWorkerPath);
      debugPrint('[WebPush] Service Worker registrado: ${registration.scope}');

      // Verificar atualizações periodicamente
      registration.update();
    } catch (e) {
      debugPrint('[WebPush] Erro ao registrar Service Worker: $e');
      rethrow;
    }
  }

  /// Solicitar permissão de notificação
  static Future<String?> _requestPermission() async {
    if (!kIsWeb) return null;

    try {
      final permission = await html.Notification.requestPermission();
      debugPrint('[WebPush] Permissão solicitada: $permission');
      return permission;
    } catch (e) {
      debugPrint('[WebPush] Erro ao solicitar permissão: $e');
      return null;
    }
  }

  /// Obter push subscription do navegador
  static Future<Map<String, dynamic>?> _getPushSubscription() async {
    if (!kIsWeb) return null;

    try {
      final serviceWorkerContainer = html.window.navigator.serviceWorker;
      if (serviceWorkerContainer == null) return null;

      final registration = await serviceWorkerContainer.ready;
      
      // Tentar obter subscription existente
      var subscription = await registration.pushManager?.getSubscription();

      if (subscription != null) {
        debugPrint('[WebPush] Subscription existente encontrada');
        return _extractSubscriptionData(subscription);
      }

      // Se não houver, criar nova
      debugPrint('[WebPush] Criando nova subscription...');
      subscription = await _createPushSubscription(registration);

      if (subscription != null) {
        return _extractSubscriptionData(subscription);
      }
    } catch (e) {
      debugPrint('[WebPush] Erro ao obter subscription: $e');
    }

    return null;
  }

  /// Criar nova push subscription
  static Future<dynamic> _createPushSubscription(dynamic registration) async {
    try {
      final subscription = await registration.pushManager?.subscribe(
        userVisibleOnly: true,
        applicationServerKey: _vapidPublicKey,
      );

      if (subscription != null) {
        debugPrint('[WebPush] Nova subscription criada');
        return subscription;
      }
    } catch (e) {
      debugPrint('[WebPush] Erro ao criar subscription: $e');
    }

    return null;
  }

  /// Extrair dados da subscription
  static Map<String, dynamic> _extractSubscriptionData(dynamic subscription) {
    try {
      // Converter para JSON
      final json = subscription.toJSON() as Map<String, dynamic>;

      return {
        'endpoint': json['endpoint'] as String? ?? '',
        'auth': (json['keys'] as Map<String, dynamic>?)?['auth'] as String? ?? '',
        'p256dh': (json['keys'] as Map<String, dynamic>?)?['p256dh'] as String? ?? '',
      };
    } catch (e) {
      debugPrint('[WebPush] Erro ao extrair dados da subscription: $e');
      return {};
    }
  }

  /// Salvar subscription no Supabase
  static Future<void> _savePushSubscription(
    Map<String, dynamic> subscription,
  ) async {
    try {
      final supabase = SupabaseService.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        debugPrint('[WebPush] Usuário não autenticado');
        return;
      }

      if (subscription['endpoint']?.isEmpty ?? true) {
        debugPrint('[WebPush] Subscription sem endpoint');
        return;
      }

      await supabase.from('push_subscriptions').upsert(
        {
          'user_id': userId,
          'endpoint': subscription['endpoint'],
          'auth': subscription['auth'],
          'p256dh': subscription['p256dh'],
          'platform': 'web',
          'is_active': true,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,platform,endpoint',
      );

      debugPrint('[WebPush] Subscription salva no Supabase');
    } catch (e) {
      debugPrint('[WebPush] Erro ao salvar subscription: $e');
    }
  }

  /// Verificar se Web Push é suportado
  static bool isSupported() {
    if (!kIsWeb) return false;

    return html.window.navigator.serviceWorker != null &&
        html.Notification != null;
  }

  /// Verificar se notificações estão habilitadas
  static Future<bool> isEnabled() async {
    if (!kIsWeb) return false;

    try {
      final permission = html.Notification.permission;
      return permission == 'granted';
    } catch (e) {
      debugPrint('[WebPush] Erro ao verificar permissão: $e');
      return false;
    }
  }

  /// Desabilitar Web Push (remover subscription)
  static Future<void> disable() async {
    if (!kIsWeb) return;

    try {
      final serviceWorkerContainer = html.window.navigator.serviceWorker;
      if (serviceWorkerContainer == null) return;

      final registration = await serviceWorkerContainer.ready;
      final subscription = await registration.pushManager?.getSubscription();

      if (subscription != null) {
        await subscription.unsubscribe();
        debugPrint('[WebPush] Subscription removida');

        // Remover do Supabase
        final supabase = SupabaseService.client;
        final userId = supabase.auth.currentUser?.id;

        if (userId != null) {
          final data = _extractSubscriptionData(subscription);
          await supabase
              .from('push_subscriptions')
              .delete()
              .eq('user_id', userId)
              .eq('platform', 'web')
              .eq('endpoint', data['endpoint']);
        }
      }
    } catch (e) {
      debugPrint('[WebPush] Erro ao desabilitar: $e');
    }
  }

  /// Obter status do Web Push
  static Future<Map<String, dynamic>> getStatus() async {
    if (!kIsWeb) {
      return {
        'supported': false,
        'enabled': false,
        'hasSubscription': false,
      };
    }

    try {
      final supported = isSupported();
      final enabled = await isEnabled();

      bool hasSubscription = false;
      if (supported && enabled) {
        final serviceWorkerContainer = html.window.navigator.serviceWorker;
        if (serviceWorkerContainer != null) {
          final registration = await serviceWorkerContainer.ready;
          final subscription = await registration.pushManager?.getSubscription();
          hasSubscription = subscription != null;
        }
      }

      return {
        'supported': supported,
        'enabled': enabled,
        'hasSubscription': hasSubscription,
      };
    } catch (e) {
      debugPrint('[WebPush] Erro ao obter status: $e');
      return {
        'supported': false,
        'enabled': false,
        'hasSubscription': false,
      };
    }
  }

  /// Enviar mensagem para Service Worker
  static Future<void> sendMessageToServiceWorker(
    Map<String, dynamic> message,
  ) async {
    if (!kIsWeb) return;

    try {
      final serviceWorkerContainer = html.window.navigator.serviceWorker;
      if (serviceWorkerContainer == null) return;

      final controller = serviceWorkerContainer.controller;
      if (controller != null) {
        controller.postMessage(message);
        debugPrint('[WebPush] Mensagem enviada para Service Worker');
      }
    } catch (e) {
      debugPrint('[WebPush] Erro ao enviar mensagem: $e');
    }
  }

  /// Escutar mensagens do Service Worker
  static void listenToServiceWorkerMessages(
    Function(Map<String, dynamic>) onMessage,
  ) {
    if (!kIsWeb) return;

    try {
      html.window.onMessage.listen((event) {
        if (event.data is Map) {
          onMessage(Map<String, dynamic>.from(event.data as Map));
        }
      });
    } catch (e) {
      debugPrint('[WebPush] Erro ao escutar mensagens: $e');
    }
  }
}

/// Provider para status de Web Push
final webPushStatusProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return WebPushService.getStatus();
});

/// Provider para verificar se Web Push é suportado
final webPushSupportedProvider = Provider<bool>((ref) {
  return WebPushService.isSupported();
});

/// Provider para verificar se Web Push está habilitado
final webPushEnabledProvider = FutureProvider<bool>((ref) async {
  return WebPushService.isEnabled();
});
