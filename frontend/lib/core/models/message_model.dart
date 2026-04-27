import 'package:flutter/foundation.dart';
import 'user_model.dart';

/// Modelo de mensagem de chat.
/// Baseado no schema v5 — tabela chat_messages (ChatMessage.smali).
///
/// Campos mapeados diretamente da tabela `chat_messages`:
/// - id, thread_id, author_id, type, content
/// - media_url, media_type, media_duration, media_thumbnail_url
/// - sticker_id, sticker_url, sticker_name, pack_id
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
Map<String, dynamic>? _extractUserMap(dynamic rawUser) {
  if (rawUser is Map<String, dynamic>) return rawUser;
  if (rawUser is Map) return Map<String, dynamic>.from(rawUser);
  if (rawUser is List && rawUser.isNotEmpty) {
    final first = rawUser.first;
    if (first is Map<String, dynamic>) return first;
    if (first is Map) return Map<String, dynamic>.from(first);
  }
  return null;
}

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
  final String? stickerName;
  final String? packId;
  final String? replyToId;
  final String? sharedUserId;
  final String? sharedUrl;
  final Map<String, dynamic>? sharedLinkSummary;
  final Map<String, dynamic>? extraData;
  final int? tipAmount;
  final Map<String, dynamic> reactions;
  final bool isDeleted;
  final String? deletedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? editedAt;
  final UserModel? author;
  /// BlurHash da mídia da mensagem — usado como placeholder visual.
  final String? mediaBlurhash;

  // ── Campos de upload otimista (apenas em memória, não persistidos) ──────────
  /// Caminho local do arquivo sendo enviado (antes do upload concluir).
  final String? localPath;
  /// Estado do upload: null = mensagem real, 'uploading' = enviando, 'error' = falhou.
  final String? uploadState;
  /// Mensagem de erro do upload (quando uploadState == 'error').
  final String? uploadError;
  /// Callback de retry (quando uploadState == 'error').
  final VoidCallback? onRetry;
  /// Callback de cancelamento (quando uploadState == 'uploading').
  final VoidCallback? onCancel;

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
    this.stickerName,
    this.packId,
    this.replyToId,
    this.sharedUserId,
    this.sharedUrl,
    this.sharedLinkSummary,
    this.extraData,
    this.tipAmount,
    this.reactions = const {},
    this.isDeleted = false,
    this.deletedBy,
    required this.createdAt,
    required this.updatedAt,
    this.editedAt,
    this.author,
    this.mediaBlurhash,
    this.localPath,
    this.uploadState,
    this.uploadError,
    this.onRetry,
    this.onCancel,
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
      stickerName: json['sticker_name'] as String?,
      packId: json['pack_id'] as String?,
      replyToId: json['reply_to_id'] as String?,
      sharedUserId: json['shared_user_id'] as String?,
      sharedUrl: json['shared_url'] as String?,
      sharedLinkSummary: json['shared_link_summary'] is Map
          ? Map<String, dynamic>.from(json['shared_link_summary'] as Map)
          : null,
      extraData: json['extra_data'] is Map
          ? Map<String, dynamic>.from(json['extra_data'] as Map)
          : (json['extraData'] is Map
              ? Map<String, dynamic>.from(json['extraData'] as Map)
              : null),
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
      author: _extractUserMap(json['profiles']) != null
          ? UserModel.fromJson(_extractUserMap(json['profiles'])!)
          : (_extractUserMap(json['author']) != null
              ? UserModel.fromJson(_extractUserMap(json['author'])!)
              : (_extractUserMap(json['sender']) != null
                  ? UserModel.fromJson(_extractUserMap(json['sender'])!)
                  : null)),
      mediaBlurhash: json['media_blurhash'] as String?,
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
    if (mediaThumbnailUrl != null)
      map['media_thumbnail_url'] = mediaThumbnailUrl;
    if (stickerId != null) map['sticker_id'] = stickerId;
    if (stickerUrl != null) map['sticker_url'] = stickerUrl;
    if (stickerName != null) map['sticker_name'] = stickerName;
    if (packId != null) map['pack_id'] = packId;
    if (replyToId != null) map['reply_to_id'] = replyToId;
    if (sharedUserId != null) map['shared_user_id'] = sharedUserId;
    if (sharedUrl != null) map['shared_url'] = sharedUrl;
    if (sharedLinkSummary != null)
      map['shared_link_summary'] = sharedLinkSummary;
    if (extraData != null) map['extra_data'] = extraData;
    if (tipAmount != null) map['tip_amount'] = tipAmount;
    return map;
  }

  // Getters de conveniência para identificar o tipo visual da mensagem.
  // Bug fix (migration 058): os tipos image, gif, audio agora existem nativamente
  // no enum. Detectar pelo type nativo OU pelo mediaType para retrocompatibilidade.
  bool get isTextMessage =>
      type == 'text' && mediaUrl == null && replyToId == null;
  // image: tipo nativo 'image' OU legado 'text' com mediaType == 'image'
  bool get isImageMessage =>
      type == 'image' || (mediaType == 'image' && mediaUrl != null);
  // gif: tipo nativo 'gif' OU legado 'text' com mediaType == 'gif'
  bool get isGifMessage =>
      type == 'gif' || (mediaType == 'gif' && mediaUrl != null);
  bool get isSystemMessage => type == 'system' || type.startsWith('system_');
  bool get isStickerMessage => type == 'sticker' || stickerUrl != null;
  // voice_note: tipo nativo 'voice_note' (legado) ou 'audio' (novo)
  bool get isVoiceNote => type == 'voice_note' || type == 'audio';
  bool get isGif => type == 'gif' || mediaType == 'gif';
  bool get isVideo => type == 'video';
  bool get isFile => type == 'file';
  bool get isLink => type == 'share_url' || sharedUrl != null;
  bool get isPoll => content != null && content!.startsWith('{"question"');
  bool get isQuiz => type == 'quiz' ||
      (isPoll &&
          content != null &&
          (content!.contains('"correctIndex"') ||
              content!.contains('"correct_option_index"')));
  bool get isTip => type == 'system_tip' || tipAmount != null;
  bool get isReply => replyToId != null;
  bool get isForward => type == 'forward';
  bool get isAudio => type == 'audio' || type == 'voice_note';
  bool get isEdited => editedAt != null;

  /// True quando esta é uma mensagem otimista aguardando upload.
  bool get isUploading => uploadState == 'uploading';
  /// True quando o upload desta mensagem falhou.
  bool get hasUploadError => uploadState == 'error';

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
    String? stickerName,
    String? packId,
    String? sharedUrl,
    Map<String, dynamic>? extraData,
    String? localPath,
    String? uploadState,
    String? uploadError,
    VoidCallback? onRetry,
    VoidCallback? onCancel,
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
      stickerName: stickerName ?? this.stickerName,
      packId: packId ?? this.packId,
      replyToId: replyToId,
      sharedUserId: sharedUserId,
      sharedUrl: sharedUrl ?? this.sharedUrl,
      sharedLinkSummary: sharedLinkSummary,
      extraData: extraData ?? this.extraData,
      tipAmount: tipAmount,
      reactions: reactions,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedBy: deletedBy ?? this.deletedBy,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      editedAt: editedAt ?? this.editedAt,
      author: author,
      mediaBlurhash: mediaBlurhash,
      localPath: localPath ?? this.localPath,
      uploadState: uploadState ?? this.uploadState,
      uploadError: uploadError ?? this.uploadError,
      onRetry: onRetry ?? this.onRetry,
      onCancel: onCancel ?? this.onCancel,
    );
  }
}
