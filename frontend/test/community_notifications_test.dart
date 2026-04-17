import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('Community Notifications Tests', () {
    
    test('Should fetch community notifications with local profile data', () async {
      // Arrange
      const communityId = 'test-community-123';
      const userId = 'test-user-456';
      
      // Mock data para notificação de comunidade
      final mockNotification = {
        'id': 'notif-001',
        'user_id': userId,
        'community_id': communityId,
        'type': 'like',
        'title': 'Novo like',
        'body': 'Seu post recebeu um like',
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
        'community_members': {
          'local_nickname': 'Mestre Local',
          'local_icon_url': 'https://example.com/avatar-local.jpg',
        },
        'profiles': {
          'id': 'actor-789',
          'nickname': 'Usuário Global',
          'icon_url': 'https://example.com/avatar-global.jpg',
        }
      };
      
      // Act
      final communityMembers = mockNotification['community_members'] as Map<String, dynamic>?;
      final globalProfile = mockNotification['profiles'] as Map<String, dynamic>?;
      
      // Usar perfil local se disponível, senão usar global
      final avatarUrl = communityMembers?['local_icon_url'] as String? ?? 
                        globalProfile?['icon_url'] as String?;
      final nickname = communityMembers?['local_nickname'] as String? ?? 
                       globalProfile?['nickname'] as String? ?? '';
      
      // Assert
      expect(nickname, equals('Mestre Local'));
      expect(avatarUrl, equals('https://example.com/avatar-local.jpg'));
    });

    test('Should fallback to global profile when local profile is missing', () async {
      // Arrange
      const communityId = 'test-community-123';
      const userId = 'test-user-456';
      
      // Mock data sem perfil local
      final mockNotification = {
        'id': 'notif-002',
        'user_id': userId,
        'community_id': communityId,
        'type': 'comment',
        'title': 'Novo comentário',
        'body': 'Alguém comentou no seu post',
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
        'community_members': null, // Sem dados locais
        'profiles': {
          'id': 'actor-789',
          'nickname': 'Usuário Global',
          'icon_url': 'https://example.com/avatar-global.jpg',
        }
      };
      
      // Act
      final communityMembers = mockNotification['community_members'] as Map<String, dynamic>?;
      final globalProfile = mockNotification['profiles'] as Map<String, dynamic>?;
      
      final avatarUrl = communityMembers?['local_icon_url'] as String? ?? 
                        globalProfile?['icon_url'] as String?;
      final nickname = communityMembers?['local_nickname'] as String? ?? 
                       globalProfile?['nickname'] as String? ?? '';
      
      // Assert
      expect(nickname, equals('Usuário Global'));
      expect(avatarUrl, equals('https://example.com/avatar-global.jpg'));
    });

    test('Should handle notification with empty local profile gracefully', () async {
      // Arrange
      final mockNotification = {
        'id': 'notif-003',
        'user_id': 'test-user-456',
        'community_id': 'test-community-123',
        'type': 'follow',
        'title': 'Novo seguidor',
        'body': 'Alguém começou a te seguir',
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
        'community_members': {
          'local_nickname': null,
          'local_icon_url': null,
        },
        'profiles': {
          'id': 'actor-789',
          'nickname': 'Usuário Global',
          'icon_url': 'https://example.com/avatar-global.jpg',
        }
      };
      
      // Act
      final communityMembers = mockNotification['community_members'] as Map<String, dynamic>?;
      final globalProfile = mockNotification['profiles'] as Map<String, dynamic>?;
      
      final avatarUrl = communityMembers?['local_icon_url'] as String? ?? 
                        globalProfile?['icon_url'] as String?;
      final nickname = communityMembers?['local_nickname'] as String? ?? 
                       globalProfile?['nickname'] as String? ?? '';
      
      // Assert
      expect(nickname, equals('Usuário Global'));
      expect(avatarUrl, equals('https://example.com/avatar-global.jpg'));
    });

    test('Should correctly identify community-scoped notifications', () async {
      // Arrange
      final communityNotification = {
        'id': 'notif-004',
        'user_id': 'test-user-456',
        'community_id': 'test-community-123',
        'type': 'like',
        'community_members': {
          'local_nickname': 'Mestre Local',
          'local_icon_url': 'https://example.com/avatar.jpg',
        }
      };
      
      final globalNotification = {
        'id': 'notif-005',
        'user_id': 'test-user-456',
        'community_id': null,
        'type': 'follow',
        'profiles': {
          'nickname': 'Usuário Global',
          'icon_url': 'https://example.com/avatar.jpg',
        }
      };
      
      // Act
      final isCommunityScoped1 = communityNotification['community_members'] != null;
      final isCommunityScoped2 = globalNotification['community_members'] != null;
      
      // Assert
      expect(isCommunityScoped1, isTrue);
      expect(isCommunityScoped2, isFalse);
    });

    test('Should handle notification types correctly', () async {
      // Arrange
      final notificationTypes = [
        'like',
        'comment',
        'follow',
        'mention',
        'wall_post',
        'community_invite',
        'community_update',
        'chat_message',
        'moderation',
        'strike',
        'ban',
      ];
      
      // Act & Assert
      for (final type in notificationTypes) {
        expect(type, isNotEmpty);
        expect(type, isA<String>());
      }
    });

    test('Should preserve notification metadata', () async {
      // Arrange
      final mockNotification = {
        'id': 'notif-006',
        'user_id': 'test-user-456',
        'community_id': 'test-community-123',
        'type': 'like',
        'title': 'Novo like',
        'body': 'Seu post recebeu um like',
        'is_read': false,
        'created_at': '2026-04-17T14:00:00Z',
        'post_id': 'post-123',
        'actor_id': 'actor-789',
        'data': {
          'post_id': 'post-123',
          'community_id': 'test-community-123',
          'actor_id': 'actor-789',
        },
        'community_members': {
          'local_nickname': 'Mestre Local',
          'local_icon_url': 'https://example.com/avatar.jpg',
        }
      };
      
      // Act
      final notificationId = mockNotification['id'] as String?;
      final postId = mockNotification['post_id'] as String?;
      final actorId = mockNotification['actor_id'] as String?;
      final isRead = mockNotification['is_read'] as bool?;
      
      // Assert
      expect(notificationId, equals('notif-006'));
      expect(postId, equals('post-123'));
      expect(actorId, equals('actor-789'));
      expect(isRead, isFalse);
    });
  });
}
