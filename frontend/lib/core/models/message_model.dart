import 'user_model.dart';

/// Modelo de mensagem de chat.
/// Baseado na análise do sistema de chat do Amino original.
class MessageModel {
  final String id;
  final String chatRoomId;
  final String senderId;
  final String? content;
  final String messageType;
  final String? mediaUrl;
  final String? stickerId;
  final String? replyToId;
  final bool isDeleted;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final UserModel? sender;

  const MessageModel({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    this.content,
    this.messageType = 'text',
    this.mediaUrl,
    this.stickerId,
    this.replyToId,
    this.isDeleted = false,
    this.metadata = const {},
    required this.createdAt,
    this.sender,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      chatRoomId: json['chat_room_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      content: json['content'] as String?,
      messageType: json['message_type'] as String? ?? 'text',
      mediaUrl: json['media_url'] as String?,
      stickerId: json['sticker_id'] as String?,
      replyToId: json['reply_to_id'] as String?,
      isDeleted: json['is_deleted'] as bool? ?? false,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      sender: json['sender'] != null
          ? UserModel.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chat_room_id': chatRoomId,
      'sender_id': senderId,
      'content': content,
      'message_type': messageType,
      'media_url': mediaUrl,
      'reply_to_id': replyToId,
    };
  }

  bool get isTextMessage => messageType == 'text';
  bool get isImageMessage => messageType == 'image';
  bool get isSystemMessage => messageType == 'system';
}

/// Modelo de sala de chat.
class ChatRoomModel {
  final String id;
  final String? communityId;
  final String name;
  final String? description;
  final String? iconUrl;
  final String? backgroundUrl;
  final String chatType;
  final String creatorId;
  final bool isActive;
  final int membersCount;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final DateTime createdAt;
  final int unreadCount;

  const ChatRoomModel({
    required this.id,
    this.communityId,
    required this.name,
    this.description,
    this.iconUrl,
    this.backgroundUrl,
    this.chatType = 'community',
    required this.creatorId,
    this.isActive = true,
    this.membersCount = 0,
    this.lastMessageAt,
    this.lastMessagePreview,
    required this.createdAt,
    this.unreadCount = 0,
  });

  factory ChatRoomModel.fromJson(Map<String, dynamic> json) {
    return ChatRoomModel(
      id: json['id'] as String,
      communityId: json['community_id'] as String?,
      name: json['name'] as String? ?? 'Chat',
      description: json['description'] as String?,
      iconUrl: json['icon_url'] as String?,
      backgroundUrl: json['background_url'] as String?,
      chatType: json['chat_type'] as String? ?? 'community',
      creatorId: json['creator_id'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      membersCount: json['members_count'] as int? ?? 0,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'] as String)
          : null,
      lastMessagePreview: json['last_message_preview'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
