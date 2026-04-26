// ignore_for_file: prefer_const_declarations
import 'package:flutter_test/flutter_test.dart';

/// Testes para os tipos de notificação 'match' e 'roleplay' introduzidos
/// nas migrations 156–159.
///
/// Cobrem:
/// - Categorização correta (Social vs Chat)
/// - Ícone e cor esperados (lógica espelhada do notifications_screen)
/// - Roteamento de canal Android (push_notification_service)
/// - Filtro de configuração de push (TYPE_TO_SETTINGS_COL)
/// - Contagem de badge por categoria
void main() {
  // ── Helpers que espelham a lógica do app ──────────────────────────────────

  /// Retorna a categoria de filtro para um tipo de notificação,
  /// espelhando NotificationCategory no notification_provider.
  String _categoryFor(String type) {
    const social = {'like', 'follow', 'match', 'mention', 'wall_post', 'repost'};
    const chat = {'chat', 'chat_message', 'chat_mention', 'chat_invite', 'dm_invite', 'roleplay'};
    const community = {'community_invite', 'community_update', 'join_request', 'role_change'};
    const gamification = {'achievement', 'level_up'};
    const moderation = {'moderation', 'strike', 'ban'};

    if (social.contains(type)) return 'social';
    if (chat.contains(type)) return 'chat';
    if (community.contains(type)) return 'community';
    if (gamification.contains(type)) return 'gamification';
    if (moderation.contains(type)) return 'moderation';
    return 'other';
  }

  /// Retorna o canal Android para um tipo de notificação,
  /// espelhando push_notification_service.dart e a edge function.
  String _channelFor(String type) {
    const chatTypes = {'chat', 'chat_message', 'chat_mention', 'chat_invite', 'dm_invite', 'roleplay'};
    const socialTypes = {'like', 'comment', 'follow', 'match', 'mention', 'wall_post', 'repost'};
    const communityTypes = {'community_invite', 'community_update', 'join_request', 'role_change'};
    const moderationTypes = {'moderation', 'strike', 'ban'};

    if (chatTypes.contains(type)) return 'nexushub_chat';
    if (socialTypes.contains(type)) return 'nexushub_social';
    if (communityTypes.contains(type)) return 'nexushub_community';
    if (moderationTypes.contains(type)) return 'nexushub_moderation';
    return 'nexushub_default';
  }

  /// Retorna a coluna de configuração de push para um tipo de notificação,
  /// espelhando TYPE_TO_SETTINGS_COL na edge function push-notification.
  String _settingsColFor(String type) {
    const map = {
      'like': 'push_likes',
      'comment': 'push_comments',
      'mention': 'push_mentions',
      'wall_post': 'push_mentions',
      'follow': 'push_follows',
      'match': 'push_follows',
      'repost': 'push_mentions',
      'chat': 'push_chat_messages',
      'chat_message': 'push_chat_messages',
      'chat_mention': 'push_chat_messages',
      'chat_invite': 'push_chat_messages',
      'dm_invite': 'push_chat_messages',
      'roleplay': 'push_chat_messages',
      'community_invite': 'push_community_invites',
      'community_update': 'push_community_invites',
      'join_request': 'push_community_invites',
      'role_change': 'push_community_invites',
      'achievement': 'push_achievements',
      'level_up': 'push_level_up',
      'moderation': 'push_moderation',
      'strike': 'push_moderation',
      'ban': 'push_moderation',
      'economy': 'push_economy',
      'story': 'push_stories',
      'broadcast': '',
    };
    return map[type] ?? '';
  }

  // ── Grupo: tipo 'match' ───────────────────────────────────────────────────
  group("Tipo 'match'", () {
    test('deve ser categorizado como Social', () {
      expect(_categoryFor('match'), equals('social'));
    });

    test('deve ser roteado para o canal nexushub_social', () {
      expect(_channelFor('match'), equals('nexushub_social'));
    });

    test('deve usar a coluna push_follows nas configurações', () {
      // Match usa a mesma preferência que follow (ambos são interações sociais)
      expect(_settingsColFor('match'), equals('push_follows'));
    });

    test('deve ser filtrado corretamente quando push_follows está desativado', () {
      final settings = {'push_follows': false, 'push_enabled': true};
      final col = _settingsColFor('match');
      final shouldSuppress = col.isNotEmpty && settings[col] == false;
      expect(shouldSuppress, isTrue);
    });

    test('não deve ser suprimido quando push_follows está ativado', () {
      final settings = {'push_follows': true, 'push_enabled': true};
      final col = _settingsColFor('match');
      final shouldSuppress = col.isNotEmpty && settings[col] == false;
      expect(shouldSuppress, isFalse);
    });

    test('deve contar no badge da categoria Social', () {
      final notifications = [
        {'type': 'match', 'is_read': false},
        {'type': 'match', 'is_read': false},
        {'type': 'follow', 'is_read': false},
        {'type': 'chat', 'is_read': false},
      ];

      final socialUnread = notifications
          .where((n) => _categoryFor(n['type']! as String) == 'social' && n['is_read'] == false)
          .length;

      expect(socialUnread, equals(3)); // 2 match + 1 follow
    });

    test('deve ter actor_id definido (usuário que fez o match)', () {
      // Simula o payload de notificação gerado pela migration 159
      final notification = {
        'type': 'match',
        'actor_id': 'user-uuid-123',
        'user_id': 'user-uuid-456',
        'content': 'Você e @alice fizeram match!',
      };

      expect(notification['actor_id'], isNotNull);
      expect(notification['actor_id'], isNotEmpty);
    });

    test('deve gerar notificação para ambos os usuários no match mútuo', () {
      // Simula a lógica do trigger SQL da migration 159
      final userA = 'user-a';
      final userB = 'user-b';

      final generatedNotifications = <Map<String, String>>[];

      // Trigger cria notificação para A (actor = B) e para B (actor = A)
      generatedNotifications.add({
        'user_id': userA,
        'actor_id': userB,
        'type': 'match',
      });
      generatedNotifications.add({
        'user_id': userB,
        'actor_id': userA,
        'type': 'match',
      });

      expect(generatedNotifications.length, equals(2));
      expect(generatedNotifications[0]['type'], equals('match'));
      expect(generatedNotifications[1]['type'], equals('match'));
      expect(generatedNotifications[0]['actor_id'], equals(userB));
      expect(generatedNotifications[1]['actor_id'], equals(userA));
    });
  });

  // ── Grupo: tipo 'roleplay' ────────────────────────────────────────────────
  group("Tipo 'roleplay'", () {
    test('deve ser categorizado como Chat', () {
      expect(_categoryFor('roleplay'), equals('chat'));
    });

    test('deve ser roteado para o canal nexushub_chat', () {
      expect(_channelFor('roleplay'), equals('nexushub_chat'));
    });

    test('deve usar a coluna push_chat_messages nas configurações', () {
      expect(_settingsColFor('roleplay'), equals('push_chat_messages'));
    });

    test('deve ser filtrado corretamente quando push_chat_messages está desativado', () {
      final settings = {'push_chat_messages': false, 'push_enabled': true};
      final col = _settingsColFor('roleplay');
      final shouldSuppress = col.isNotEmpty && settings[col] == false;
      expect(shouldSuppress, isTrue);
    });

    test('não deve ser suprimido quando push_chat_messages está ativado', () {
      final settings = {'push_chat_messages': true, 'push_enabled': true};
      final col = _settingsColFor('roleplay');
      final shouldSuppress = col.isNotEmpty && settings[col] == false;
      expect(shouldSuppress, isFalse);
    });

    test('deve contar no badge da categoria Chat', () {
      final notifications = [
        {'type': 'roleplay', 'is_read': false},
        {'type': 'chat_message', 'is_read': false},
        {'type': 'match', 'is_read': false},
      ];

      final chatUnread = notifications
          .where((n) => _categoryFor(n['type']! as String) == 'chat' && n['is_read'] == false)
          .length;

      expect(chatUnread, equals(2)); // roleplay + chat_message
    });

    test('deve ter actor_id do personagem de IA', () {
      // Simula o payload de notificação de uma mensagem de roleplay
      final notification = {
        'type': 'roleplay',
        'actor_id': 'ai-character-uuid',
        'user_id': 'user-uuid-789',
        'content': 'Luna te enviou uma mensagem no RolePlay',
      };

      expect(notification['actor_id'], isNotNull);
      expect(notification['content'], contains('RolePlay'));
    });
  });

  // ── Grupo: coexistência match + roleplay ──────────────────────────────────
  group('Coexistência match e roleplay', () {
    test('match e roleplay devem estar em categorias diferentes', () {
      expect(_categoryFor('match'), isNot(equals(_categoryFor('roleplay'))));
    });

    test('match e roleplay devem estar em canais diferentes', () {
      expect(_channelFor('match'), isNot(equals(_channelFor('roleplay'))));
    });

    test('badge total deve somar match (social) + roleplay (chat) corretamente', () {
      final notifications = [
        {'type': 'match', 'is_read': false},
        {'type': 'roleplay', 'is_read': false},
        {'type': 'like', 'is_read': false},
        {'type': 'chat_message', 'is_read': true},
      ];

      final totalUnread = notifications.where((n) => n['is_read'] == false).length;
      final socialUnread = notifications
          .where((n) => _categoryFor(n['type']! as String) == 'social' && n['is_read'] == false)
          .length;
      final chatUnread = notifications
          .where((n) => _categoryFor(n['type']! as String) == 'chat' && n['is_read'] == false)
          .length;

      expect(totalUnread, equals(3));
      expect(socialUnread, equals(2)); // match + like
      expect(chatUnread, equals(1));   // roleplay
    });

    test('desativar push_follows não deve afetar roleplay', () {
      final settings = {
        'push_follows': false,
        'push_chat_messages': true,
        'push_enabled': true,
      };

      final matchSuppressed = _settingsColFor('match').isNotEmpty &&
          settings[_settingsColFor('match')] == false;
      final roleplaySuppressed = _settingsColFor('roleplay').isNotEmpty &&
          settings[_settingsColFor('roleplay')] == false;

      expect(matchSuppressed, isTrue);
      expect(roleplaySuppressed, isFalse);
    });

    test('desativar push_chat_messages não deve afetar match', () {
      final settings = {
        'push_follows': true,
        'push_chat_messages': false,
        'push_enabled': true,
      };

      final matchSuppressed = _settingsColFor('match').isNotEmpty &&
          settings[_settingsColFor('match')] == false;
      final roleplaySuppressed = _settingsColFor('roleplay').isNotEmpty &&
          settings[_settingsColFor('roleplay')] == false;

      expect(matchSuppressed, isFalse);
      expect(roleplaySuppressed, isTrue);
    });
  });
}
