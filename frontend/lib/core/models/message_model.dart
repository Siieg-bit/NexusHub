import 'user_model.dart';

/// Modelo de mensagem de chat.
/// Baseado no schema v5 — tabela chat_messages (ChatMessage.smali).
///
/// Campos mapeados diretamente da tabela `chat_messages`:
/// - id, thread_id, author_id, type, content
/// - media_url, media_type, media_duration, media_thumbnail_url
/// - sticker_id, sticker_url
/// - reply_to_id
/// - shared_user_id, shared_url, shared_link_summary
/// - tip_amount
/// - reactions (JSONB)
/// - is_deleted, deleted_by
/// - created_at, updated_at
///
/// Campos que NÃO existem na tabela (removidos):
/// - metadata (não existe — polls são serializados no content)
/// - is_pinned (não existe — pinned é gerenciado pelo chat_threads.pinned_message_id)
class MessageModel {
  final String id;
  final String threadId;
  final String authorId;
  final String type; // Valores do enum chat_message_type no banco
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
  final DateTime? editedAt;
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
    this.reactions = const {},
    this.isDeleted = false,
    this.deletedBy,
    required this.createdAt,
    required this.updatedAt,
    this.editedAt,
    this.author,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String? ?? '',
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
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
      editedAt: json['edited_at'] != null
          ? DateTime.tryParse(json['edited_at'] as String)
          : null,
      // O autor pode vir de diferentes chaves dependendo do contexto:
      // - 'profiles' quando vem de um JOIN com FK
      // - 'author' quando normalizado pelo provider
      // - 'sender' quando normalizado pelo realtime callback
      author: json['profiles'] != null
          ? UserModel.fromJson(json['profiles'] as Map<String, dynamic>)
          : (json['author'] != null
              ? UserModel.fromJson(json['author'] as Map<String, dynamic>)
              : (json['sender'] != null
                  ? UserModel.fromJson(json['sender'] as Map<String, dynamic>)
                  : null)),
    );
  }

  /// Serializa apenas campos que existem na tabela chat_messages.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'thread_id': threadId,
      'author_id': authorId,
      'type': type,
      'content': content ?? '',
    };
    if (mediaUrl != null) map['media_url'] = mediaUrl;
    if (mediaType != null) map['media_type'] = mediaType;
    if (mediaDuration != null) map['media_duration'] = mediaDuration;
    if (mediaThumbnailUrl != null) map['media_thumbnail_url'] = mediaThumbnailUrl;
    if (stickerId != null) map['sticker_id'] = stickerId;
    if (stickerUrl != null) map['sticker_url'] = stickerUrl;
    if (replyToId != null) map['reply_to_id'] = replyToId;
    if (sharedUserId != null) map['shared_user_id'] = sharedUserId;
    if (sharedUrl != null) map['shared_url'] = sharedUrl;
    if (sharedLinkSummary != null) map['shared_link_summary'] = sharedLinkSummary;
    if (tipAmount != null) map['tip_amount'] = tipAmount;
    return map;
  }

  // Getters de conveniência para identificar o tipo visual da mensagem.
  // Como o banco usa tipos mapeados (ex: 'text' para imagens), estes getters
  // verificam campos adicionais para determinar o tipo real.
  bool get isTextMessage => type == 'text' && mediaUrl == null && replyToId == null;
  bool get isImageMessage => mediaType == 'image' && mediaUrl != null;
  bool get isGifMessage => mediaType == 'gif' && mediaUrl != null;
  bool get isSystemMessage => type == 'system' || type.startsWith('system_');
  bool get isStickerMessage => type == 'sticker' || stickerUrl != null;
  bool get isVoiceNote => type == 'voice_note';
  bool get isGif => mediaType == 'gif';
  bool get isVideo => type == 'video';
  bool get isFile => false; // Não há tipo 'file' no enum do banco
  bool get isLink => type == 'share_url' || sharedUrl != null;
  bool get isPoll => content != null && content!.startsWith('{"question"');
  bool get isQuiz => false; // Quiz não implementado no banco
  bool get isTip => type == 'system_tip' || tipAmount != null;
  bool get isReply => replyToId != null;
  bool get isForward => false; // Forward não implementado no banco
  bool get isEdited => editedAt != null;

  /// Cria uma cópia do modelo com campos alterados.
  MessageModel copyWith({
    String? content,
    String? type,
    bool? isDeleted,
    String? deletedBy,
    DateTime? editedAt,
    String? mediaUrl,
    String? mediaType,
    String? stickerUrl,
    String? stickerId,
    String? sharedUrl,
  }) {
    return MessageModel(
      id: id,
      threadId: threadId,
      authorId: authorId,
      type: type ?? this.type,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      mediaDuration: mediaDuration,
      mediaThumbnailUrl: mediaThumbnailUrl,
      stickerId: stickerId ?? this.stickerId,
      stickerUrl: stickerUrl ?? this.stickerUrl,
      replyToId: replyToId,
      sharedUserId: sharedUserId,
      sharedUrl: sharedUrl ?? this.sharedUrl,
      sharedLinkSummary: sharedLinkSummary,
      tipAmount: tipAmount,
      reactions: reactions,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedBy: deletedBy ?? this.deletedBy,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      editedAt: editedAt ?? this.editedAt,
      author: author,
    );
  }
}
