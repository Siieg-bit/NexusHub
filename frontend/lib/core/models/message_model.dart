import 'user_model.dart';

/// Modelo de mensagem de chat.
/// Baseado no schema v5 — tabela chat_messages (ChatMessage.smali).
class MessageModel {
  final String id;
  final String threadId; // era chat_room_id
  final String authorId; // era sender_id
  final String type; // enum: text, strike, voice_note, sticker, video, share_url, etc.
  final String? content;
  final String? mediaUrl;
  final String? mediaType;
  final int? mediaDuration;
  final String? mediaThumbnailUrl;
  final String? stickerId;
  final String? stickerUrl;
  final String? replyToId;
  final String? sharedUserId;
  final String? sharedUrl;
  final Map<String, dynamic>? sharedLinkSummary;
  final int? tipAmount;
  final Map<String, dynamic> reactions;
  final bool isDeleted;
  final String? deletedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserModel? author; // era sender

  const MessageModel({
    required this.id,
    required this.threadId,
    required this.authorId,
    this.type = 'text',
    this.content,
    this.mediaUrl,
    this.mediaType,
    this.mediaDuration,
    this.mediaThumbnailUrl,
    this.stickerId,
    this.stickerUrl,
    this.replyToId,
    this.sharedUserId,
    this.sharedUrl,
    this.sharedLinkSummary,
    this.tipAmount,
    this.reactions = const {},
    this.isDeleted = false,
    this.deletedBy,
    required this.createdAt,
    required this.updatedAt,
    this.author,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      threadId: json['thread_id'] as String? ?? '',
      authorId: json['author_id'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      content: json['content'] as String?,
      mediaUrl: json['media_url'] as String?,
      mediaType: json['media_type'] as String?,
      mediaDuration: json['media_duration'] as int?,
      mediaThumbnailUrl: json['media_thumbnail_url'] as String?,
      stickerId: json['sticker_id'] as String?,
      stickerUrl: json['sticker_url'] as String?,
      replyToId: json['reply_to_id'] as String?,
      sharedUserId: json['shared_user_id'] as String?,
      sharedUrl: json['shared_url'] as String?,
      sharedLinkSummary: json['shared_link_summary'] as Map<String, dynamic>?,
      tipAmount: json['tip_amount'] as int?,
      reactions: json['reactions'] as Map<String, dynamic>? ?? {},
      isDeleted: json['is_deleted'] as bool? ?? false,
      deletedBy: json['deleted_by'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
      author: json['profiles'] != null
          ? UserModel.fromJson(json['profiles'] as Map<String, dynamic>)
          : (json['author'] != null
              ? UserModel.fromJson(json['author'] as Map<String, dynamic>)
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'thread_id': threadId,
      'author_id': authorId,
      'type': type,
      'content': content,
      'media_url': mediaUrl,
      'reply_to_id': replyToId,
    };
  }

  bool get isTextMessage => type == 'text';
  bool get isImageMessage => type == 'video' || mediaUrl != null;
  bool get isSystemMessage => type.startsWith('system_');
  bool get isStickerMessage => type == 'sticker';
  bool get isVoiceNote => type == 'voice_note';
}
