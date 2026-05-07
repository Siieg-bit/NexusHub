import 'package:go_router/go_router.dart';
import '../../features/chat/screens/roleplay_screen.dart';

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

  /// Navega para um post, com opção de rolar até os comentários.
  static void navigateToPost(
    GoRouter router,
    String postId, {
    bool scrollToComments = false,
  }) {
    if (postId.isEmpty) return;
    final query = scrollToComments ? '?scrollToComments=true' : '';
    router.push('/post/$postId$query');
  }

  /// Navega para um chat.
  static void navigateToChat(GoRouter router, String chatId) {
    if (chatId.isEmpty) return;
    final target = '/chat/$chatId';
    if (_isCurrentRoute(router, target)) return;
    router.push(target);
  }

  /// Navega para a lista de chats.
  static void navigateToChats(GoRouter router) {
    router.push('/chats');
  }

  /// Navega para o perfil do usuário logado.
  static void navigateToProfile(GoRouter router) {
    router.push('/profile');
  }

  /// Navega para a tela de conquistas.
  static void navigateToAchievements(GoRouter router) {
    router.push('/achievements');
  }

  /// Navega para uma wiki.
  static void navigateToWiki(GoRouter router, String wikiId) {
    if (wikiId.isEmpty) return;
    router.push('/wiki/$wikiId');
  }

  /// Navega para o mural de um usuário.
  static void navigateToUserWall(GoRouter router, String userId) {
    if (userId.isEmpty) return;
    router.push('/user/$userId/wall');
  }

  /// Navega para a tela de notificações de uma comunidade.
  static void navigateToCommunityNotifications(
    GoRouter router,
    String communityId,
  ) {
    if (communityId.isEmpty) return;
    router.push('/community/$communityId/notifications');
  }

  // ─────────────────────────────────────────────────────────────
  // Navegação por payload de notificação push
  // ─────────────────────────────────────────────────────────────

  /// Navega para a tela correta com base no payload de uma notificação push.
  ///
  /// O payload `data` deve conter os campos enviados pela Edge Function:
  ///   - `type`           — tipo da notificação
  ///   - `post_id`        — ID do post (se aplicável)
  ///   - `comment_id`     — ID do comentário (se aplicável)
  ///   - `wiki_id`        — ID da wiki (se aplicável)
  ///   - `community_id`   — ID da comunidade (se aplicável)
  ///   - `chat_thread_id` — ID do thread de chat (se aplicável)
  ///   - `actor_id`       — ID do usuário que gerou a notificação
  ///   - `action_url`     — URL de ação alternativa (fallback)
  static void navigateFromNotificationPayload(
    GoRouter router,
    Map<String, dynamic> data,
  ) {
    final type = _str(data['type']);
    final postId = _str(data['post_id']);
    final commentId = _str(data['comment_id']);
    final wikiId = _str(data['wiki_id']);
    final communityId = _str(data['community_id']);
    final actorId = _str(data['actor_id']);
    final chatId = _str(data['chat_thread_id']) ??
        _str(data['thread_id']) ??
        _str(data['chat_id']);
    final actionUrl = _str(data['action_url']);

    switch (type) {
      // ── Social: like → abre o post ───────────────────────────
      case 'like':
        if (postId != null) {
          navigateToPost(router, postId);
        } else if (communityId != null) {
          navigateToCommunity(router, communityId);
        }
        break;

      // ── Social: comment/mention → abre o post rolando para comentários
      case 'comment':
      case 'mention':
        if (postId != null) {
          // Se temos comment_id, rolar até comentários para destacar
          navigateToPost(
            router,
            postId,
            scrollToComments: commentId != null,
          );
        } else if (communityId != null) {
          navigateToCommunity(router, communityId);
        }
        break;

      // ── Social: repost → abre o post original ────────────────
      case 'repost':
        if (postId != null) {
          navigateToPost(router, postId);
        } else if (communityId != null) {
          navigateToCommunity(router, communityId);
        }
        break;

      // ── Social: follow → abre o perfil de quem seguiu ────
      case 'follow':
        if (actorId != null) {
          navigateToUser(router, actorId);
        }
        break;

      // ── Social: match mútuo → abre o perfil do usuário que fez match ──
      case 'match':
        if (actorId != null) {
          navigateToUser(router, actorId);
        }
        break;

      // ── Chat: RolePlay com IA ────────────────────────────────
      case 'roleplay':
        final context = router.configuration.navigatorKey.currentContext;
        if (context != null && chatId != null) {
          RolePlayScreen.show(context, chatId);
        }
        break;

      // ── Social: wall_post → abre o mural do usuário ──────────
      case 'wall_post':
        // O mural é do usuário que recebeu a notificação (perfil próprio)
        // ou podemos ir ao perfil do ator. Aqui abrimos o mural do ator.
        if (actorId != null) {
          navigateToUserWall(router, actorId);
        } else if (communityId != null) {
          navigateToCommunity(router, communityId);
        }
        break;

      // ── Chat: mensagem/menção → abre o chat ──────────────────
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

      // ── Chat: convite DM ou grupo → abre o chat ──────────────
      case 'dm_invite':
      case 'chat_invite':
        if (chatId != null) {
          navigateToChat(router, chatId);
        } else {
          navigateToChats(router);
        }
        break;

      // ── Comunidade: convite/atualização → abre a comunidade ──
      case 'community_invite':
      case 'community_update':
      case 'join_request':
        if (communityId != null) {
          navigateToCommunity(router, communityId);
        }
        break;

      // ── Comunidade: mudança de cargo → abre a comunidade ─────
      case 'role_change':
        if (communityId != null) {
          navigateToCommunity(router, communityId);
        }
        break;

      // ── Moderação → abre a comunidade (se houver) ou perfil ──
      case 'moderation':
      case 'strike':
      case 'ban':
        if (communityId != null) {
          navigateToCommunity(router, communityId);
        } else {
          navigateToProfile(router);
        }
        break;

      // ── Wiki aprovada → abre a wiki ───────────────────────────
      case 'wiki_approved':
        if (wikiId != null) {
          navigateToWiki(router, wikiId);
        } else if (communityId != null) {
          navigateToCommunity(router, communityId);
        }
        break;

      // ── Conquistas e nível → abre a tela de conquistas ───────
      case 'achievement':
      case 'level_up':
        navigateToAchievements(router);
        break;

      // ── Check-in → abre o perfil ──────────────────────────────
      case 'check_in':
      case 'check_in_streak':
        navigateToProfile(router);
        break;

      // ── Broadcast → tela inicial ──────────────────────────────
      case 'broadcast':
        router.push('/');
        break;

      // ── Fallback: usar action_url ou recurso mais relevante ───
      default:
        if (actionUrl != null && actionUrl.startsWith('/')) {
          router.push(actionUrl);
        } else if (postId != null) {
          navigateToPost(router, postId);
        } else if (wikiId != null) {
          navigateToWiki(router, wikiId);
        } else if (chatId != null) {
          navigateToChat(router, chatId);
        } else if (communityId != null) {
          navigateToCommunity(router, communityId);
        } else if (actorId != null) {
          navigateToUser(router, actorId);
        }
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Utilitários internos
  // ─────────────────────────────────────────────────────────────

  static bool _isCurrentRoute(GoRouter router, String route) {
    final current = router.routeInformationProvider.value.uri.toString();
    return current == route || current.split('?').first == route;
  }

  /// Extrai string não-vazia de um valor dinâmico.
  /// Retorna null se o valor for null, vazio, "null" ou "undefined".
  static String? _str(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty || s == 'null' || s == 'undefined') return null;
    return s;
  }
}
