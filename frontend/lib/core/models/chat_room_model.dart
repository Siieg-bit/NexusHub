/// Modelo de sala de chat.
class ChatRoomModel {
  final String id;
  final String communityId;
  final String name;
  final String chatType; // 'public', 'private', 'direct', 'screening'
  final String? iconUrl;
  final String? description;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final int membersCount;
  final int unreadCount;
  final bool isPinned;

  ChatRoomModel({
    required this.id,
    required this.communityId,
    required this.name,
    required this.chatType,
    this.iconUrl,
    this.description,
    this.lastMessagePreview,
    this.lastMessageAt,
    required this.createdAt,
    this.membersCount = 0,
    this.unreadCount = 0,
    this.isPinned = false,
  });

  factory ChatRoomModel.fromJson(Map<String, dynamic> json) {
    return ChatRoomModel(
      id: json['id'] as String,
      communityId: json['community_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Chat',
      chatType: json['chat_type'] as String? ?? 'public',
      iconUrl: json['icon_url'] as String?,
      description: json['description'] as String?,
      lastMessagePreview: json['last_message_preview'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'] as String)
          : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      membersCount: json['members_count'] as int? ?? 0,
      unreadCount: json['unread_count'] as int? ?? 0,
      isPinned: json['is_pinned'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'community_id': communityId,
        'name': name,
        'chat_type': chatType,
        'icon_url': iconUrl,
        'description': description,
        'last_message_preview': lastMessagePreview,
        'last_message_at': lastMessageAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'members_count': membersCount,
        'unread_count': unreadCount,
        'is_pinned': isPinned,
      };
}
