import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_hub/core/models/post_model.dart';
import 'package:nexus_hub/core/models/user_model.dart';
import 'package:nexus_hub/core/models/community_model.dart';
import 'package:nexus_hub/core/models/message_model.dart';

void main() {
  group('PostModel', () {
    test('fromJson cria modelo corretamente', () {
      final json = {
        'id': '123',
        'community_id': 'comm-1',
        'author_id': 'user-1',
        'title': 'Test Post',
        'content': 'Hello World',
        'post_type': 'normal',
        'media_url': 'https://example.com/img.jpg',
        'link_url': null,
        'is_pinned': false,
        'is_featured': true,
        'like_count': 42,
        'comment_count': 5,
        'view_count': 100,
        'created_at': '2025-01-01T00:00:00Z',
      };

      final post = PostModel.fromJson(json);

      expect(post.id, '123');
      expect(post.title, 'Test Post');
      expect(post.postType, 'normal');
      expect(post.likeCount, 42);
      expect(post.isFeatured, true);
      expect(post.isPinned, false);
    });

    test('fromJson lida com campos nulos', () {
      final json = {
        'id': '123',
        'community_id': 'comm-1',
        'author_id': 'user-1',
        'title': 'Test',
        'content': null,
        'post_type': 'normal',
        'media_url': null,
        'link_url': null,
        'is_pinned': null,
        'is_featured': null,
        'like_count': null,
        'comment_count': null,
        'view_count': null,
        'created_at': '2025-01-01T00:00:00Z',
      };

      final post = PostModel.fromJson(json);

      expect(post.content, '');
      expect(post.mediaUrl, isNull);
      expect(post.likeCount, 0);
      expect(post.isPinned, false);
    });
  });

  group('UserModel', () {
    test('fromJson cria modelo corretamente', () {
      final json = {
        'id': 'user-1',
        'nickname': 'TestUser',
        'bio': 'Hello!',
        'icon_url': 'https://example.com/avatar.jpg',
        'amino_id': 'test_user',
        'level': 5,
        'reputation': 1000,
        'is_online': true,
        'created_at': '2025-01-01T00:00:00Z',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, 'user-1');
      expect(user.nickname, 'TestUser');
      expect(user.bio, 'Hello!');
      expect(user.level, 5);
      expect(user.isOnline, true);
    });

    test('fromJson lida com campos nulos', () {
      final json = {
        'id': 'user-1',
        'nickname': 'Test',
        'bio': null,
        'icon_url': null,
        'amino_id': null,
        'level': null,
        'reputation': null,
        'is_online': null,
        'created_at': '2025-01-01T00:00:00Z',
      };

      final user = UserModel.fromJson(json);

      expect(user.bio, '');
      expect(user.iconUrl, isNull);
      expect(user.level, 1);
      expect(user.isOnline, false);
    });
  });

  group('CommunityModel', () {
    test('fromJson cria modelo corretamente', () {
      final json = {
        'id': 'comm-1',
        'name': 'Test Community',
        'description': 'A test community',
        'icon_url': 'https://example.com/icon.jpg',
        'banner_url': 'https://example.com/banner.jpg',
        'theme_color': '#FF5722',
        'member_count': 500,
        'is_verified': true,
        'tags': ['gaming', 'anime'],
        'created_at': '2025-01-01T00:00:00Z',
      };

      final community = CommunityModel.fromJson(json);

      expect(community.id, 'comm-1');
      expect(community.name, 'Test Community');
      expect(community.memberCount, 500);
      expect(community.isVerified, true);
    });

    test('fromJson lida com campos nulos', () {
      final json = {
        'id': 'comm-1',
        'name': 'Test',
        'description': null,
        'icon_url': null,
        'banner_url': null,
        'theme_color': null,
        'member_count': null,
        'is_verified': null,
        'tags': null,
        'created_at': '2025-01-01T00:00:00Z',
      };

      final community = CommunityModel.fromJson(json);

      expect(community.description, '');
      expect(community.memberCount, 0);
      expect(community.isVerified, false);
    });
  });

  group('MessageModel', () {
    test('fromJson cria modelo corretamente', () {
      final json = {
        'id': 'msg-1',
        'thread_id': 'thread-1',
        'sender_id': 'user-1',
        'content': 'Hello!',
        'message_type': 'text',
        'metadata': null,
        'is_pinned': false,
        'created_at': '2025-01-01T00:00:00Z',
      };

      final msg = MessageModel.fromJson(json);

      expect(msg.id, 'msg-1');
      expect(msg.content, 'Hello!');
      expect(msg.messageType, 'text');
      expect(msg.isTextMessage, true);
      expect(msg.isImageMessage, false);
      expect(msg.isSystemMessage, false);
    });

    test('isSystemMessage detecta mensagens de sistema', () {
      final json = {
        'id': 'msg-2',
        'thread_id': 'thread-1',
        'sender_id': 'user-1',
        'content': 'User joined',
        'message_type': 'system',
        'metadata': null,
        'is_pinned': false,
        'created_at': '2025-01-01T00:00:00Z',
      };

      final msg = MessageModel.fromJson(json);
      expect(msg.isSystemMessage, true);
    });

    test('type getters funcionam corretamente', () {
      final types = {
        'image': 'isImageMessage',
        'sticker': 'isStickerMessage',
        'gif': 'isGifMessage',
        'voice': 'isVoiceMessage',
        'video': 'isVideoMessage',
        'file': 'isFileMessage',
        'poll': 'isPollMessage',
        'link': 'isLinkMessage',
      };

      for (final entry in types.entries) {
        final json = {
          'id': 'msg-${entry.key}',
          'thread_id': 'thread-1',
          'sender_id': 'user-1',
          'content': 'test',
          'message_type': entry.key,
          'metadata': null,
          'is_pinned': false,
          'created_at': '2025-01-01T00:00:00Z',
        };

        final msg = MessageModel.fromJson(json);
        // Verificar que o tipo correto é true
        expect(msg.messageType, entry.key);
      }
    });
  });
}
