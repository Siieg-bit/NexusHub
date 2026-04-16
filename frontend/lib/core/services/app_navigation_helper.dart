import 'package:go_router/go_router.dart';

/// Helper centralizado de navegação do NexusHub.
///
/// Concentra todas as decisões de destino de rota em um único ponto,
/// evitando duplicação de lógica entre deep links, push notifications,
/// notificações in-app e widgets de URL.
///
/// ## Motivação
/// Antes desta centralização, a mesma lógica de "qual rota abrir para
/// o tipo X" estava replicada em pelo menos cinco arquivos:
///   - `deep_link_service.dart`
///   - `main.dart` (push notifications)
///   - `notifications_screen.dart`
///   - `linkified_text.dart`
///   - `simple_link_preview.dart`
///
/// Qualquer nova rota ou parâmetro precisava ser atualizado em todos
/// esses pontos, criando risco de divergência. Este helper resolve isso.
class AppNavigationHelper {
  AppNavigationHelper._();

  // ─────────────────────────────────────────────────────────────
  // Navegação por tipo de recurso
  // ─────────────────────────────────────────────────────────────

  /// Navega para o perfil de um usuário.
  static void navigateToUser(GoRouter router, String userId) {
    if (userId.isEmpty) return;
    router.push('/user/$userId');
  }

  /// Navega para uma comunidade.
  static void navigateToCommunity(GoRouter router, String communityId) {
    if (communityId.isEmpty) return;
    router.push('/community/$communityId');
  }

  /// Navega para um post.
  static void navigateToPost(GoRouter router, String postId) {
    if (postId.isEmpty) return;
    router.push('/post/$postId');
  }

  /// Navega para um chat.
  static void navigateToChat(GoRouter router, String chatId) {
    if (chatId.isEmpty) return;
    router.push('/chat/$chatId');
  }

  /// Navega para a lista de chats.
  static void navigateToChats(GoRouter router) {
    router.push('/chats');
  }

  /// Navega para o perfil do usuário logado.
  static void navigateToProfile(GoRouter router) {
    router.push('/profile');
  }

  /// Navega para uma wiki.
  static void navigateToWiki(GoRouter router, String wikiId) {
    if (wikiId.isEmpty) return;
    router.push('/wiki/$wikiId');
  }

  // ─────────────────────────────────────────────────────────────
  // Navegação por payload de notificação push
  // ─────────────────────────────────────────────────────────────

  /// Navega para a tela correta com base no payload de uma notificação push.
  ///
  /// Centraliza a lógica que antes estava duplicada em `main.dart` e
  /// `notifications_screen.dart`, garantindo comportamento consistente.
  static void navigateFromNotificationPayload(
    GoRouter router,
    Map<String, dynamic> data,
  ) {
    final type = data['type'] as String? ?? '';
    final postId = data['post_id'] as String?;
    final communityId = data['community_id'] as String?;
    final userId = data['user_id'] as String? ?? data['actor_id'] as String?;
    final chatId = data['chat_id'] as String? ??
        data['thread_id'] as String? ??
        data['chat_thread_id'] as String?;

    switch (type) {
      case 'like':
      case 'comment':
      case 'mention':
        if (postId != null) {
          navigateToPost(router, postId);
        } else if (communityId != null) {
          navigateToCommunity(router, communityId);
        }
        break;

      case 'follow':
        if (userId != null) navigateToUser(router, userId);
        break;

      case 'community_invite':
      case 'community_update':
        if (communityId != null) navigateToCommunity(router, communityId);
        break;

      case 'chat_message':
      case 'chat_mention':
        if (chatId != null) {
          navigateToChat(router, chatId);
        } else if (communityId != null) {
          navigateToCommunity(router, communityId);
        } else {
          navigateToChats(router);
        }
        break;

      case 'dm_invite':
      case 'chat_invite':
        if (chatId != null) {
          navigateToChat(router, chatId);
        } else {
          navigateToChats(router);
        }
        break;

      case 'level_up':
      case 'achievement':
      case 'check_in_streak':
        navigateToProfile(router);
        break;

      case 'wall_post':
        if (userId != null) navigateToUser(router, userId);
        break;

      case 'moderation':
      case 'strike':
      case 'ban':
        if (communityId != null) navigateToCommunity(router, communityId);
        break;

      default:
        // Fallback: navegar para o recurso mais relevante disponível
        if (postId != null) {
          navigateToPost(router, postId);
        } else if (communityId != null) {
          navigateToCommunity(router, communityId);
        } else if (userId != null) {
          navigateToUser(router, userId);
        }
        break;
    }
  }
}
