import 'user_model.dart';

/// Modelo de mensagem de chat.
/// Baseado no schema v5 — tabela chat_messages (ChatMessage.smali).
class MessageModel {
  final String id;
  final String threadId;
  final String authorId;
  final String type; // text, image, audio, video, sticker, gif, file, link,
  //                    reply, forward, poll, quiz, voice_chat, video_chat,
  //                    screening_room, tip, shared_post, shared_user,
  //                    shared_community, system
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
  final Map<String, dynamic>? metadata; // poll options, quiz data, etc.
  final Map<String, dynamic> reactions;
  final bool isPinned;
  final bool isDeleted;
  final String? deletedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserModel? author;

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
    this.metadata,
    this.reactions = const {},
    this.isPinned = false,
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
      metadata: json['metadata'] as Map<String, dynamic>?,
      reactions: json['reactions'] as Map<String, dynamic>? ?? {},
      isPinned: json['is_pinned'] as bool? ?? false,
      isDeleted: json['is_deleted'] as bool? ?? false,
      deletedBy: json['deleted_by'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
      author: json['profiles'] != null
          ? UserModel.fromJson(json['profiles'] as Map<String, dynamic>)
          : (json['author'] != null
              ? UserModel.fromJson(json['author'] as Map<String, dynamic>)
              : (json['sender'] != null
                  ? UserModel.fromJson(json['sender'] as Map<String, dynamic>)
                  : null)),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'thread_id': threadId,
      'author_id': authorId,
      'type': type,
      'content': content,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'media_duration': mediaDuration,
      'media_thumbnail_url': mediaThumbnailUrl,
      'sticker_id': stickerId,
      'sticker_url': stickerUrl,
      'reply_to_id': replyToId,
      'shared_user_id': sharedUserId,
      'shared_url': sharedUrl,
      'shared_link_summary': sharedLinkSummary,
      'tip_amount': tipAmount,
      'metadata': metadata,
    };
  }

  bool get isTextMessage => type == 'text';
  bool get isImageMessage => type == 'image';
  bool get isSystemMessage => type == 'system' || type.startsWith('system_');
  bool get isStickerMessage => type == 'sticker';
  bool get isVoiceNote => type == 'voice_note' || type == 'audio';
  bool get isGif => type == 'gif';
  bool get isVideo => type == 'video';
  bool get isFile => type == 'file';
  bool get isLink => type == 'link';
  bool get isPoll => type == 'poll';
  bool get isQuiz => type == 'quiz';
  bool get isTip => type == 'tip';
  bool get isReply => type == 'reply';
  bool get isForward => type == 'forward';
}
