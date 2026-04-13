import 'user_model.dart';

/// Modelo de comentário em posts, wiki ou mural de perfil.
/// Baseado no schema v5 — engenharia reversa do APK Amino.
class CommentModel {
  final String id;
  final String authorId;
  final String? postId;
  final String? wikiId;
  final String? profileWallId;
  final String? parentId;
  final String content;
  final String? mediaUrl;
  // Campos de sticker (migration 054)
  final String? stickerId;
  final String? stickerUrl;
  final String? stickerName;
  final String? packId;
  final int likesCount;
  final String status; // enum: ok, pending, closed, disabled, deleted
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserModel? author;
  final List<CommentModel> replies;

  /// Nickname do autor dentro da comunidade (sobrepõe author.nickname quando preenchido).
  final String? localNickname;

  /// Avatar URL do autor dentro da comunidade (sobrepõe author.iconUrl quando preenchido).
  final String? localIconUrl;

  const CommentModel({
    required this.id,
    required this.authorId,
    this.postId,
    this.wikiId,
    this.profileWallId,
    this.parentId,
    required this.content,
    this.mediaUrl,
    this.stickerId,
    this.stickerUrl,
    this.stickerName,
    this.packId,
    this.likesCount = 0,
    this.status = 'ok',
    required this.createdAt,
    required this.updatedAt,
    this.author,
    this.replies = const [],
    this.localNickname,
    this.localIconUrl,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] as String,
      authorId: json['author_id'] as String? ?? '',
      postId: json['post_id'] as String?,
      wikiId: json['wiki_id'] as String?,
      profileWallId: json['profile_wall_id'] as String?,
      parentId: json['parent_id'] as String?,
      content: json['content'] as String? ?? '',
      mediaUrl: json['media_url'] as String?,
      stickerId: json['sticker_id'] as String?,
      stickerUrl: json['sticker_url'] as String?,
      stickerName: json['sticker_name'] as String?,
      packId: json['pack_id'] as String?,
      likesCount: json['likes_count'] as int? ?? 0,
      status: json['status'] as String? ?? 'ok',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
      author: json['author'] != null
          ? UserModel.fromJson(json['author'] as Map<String, dynamic>)
          : (json['profiles'] != null
              ? UserModel.fromJson(json['profiles'] as Map<String, dynamic>)
              : null),
      localNickname: json['local_nickname'] as String?,
      localIconUrl: json['local_icon_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'author_id': authorId,
      'post_id': postId,
      'wiki_id': wikiId,
      'profile_wall_id': profileWallId,
      'parent_id': parentId,
      'content': content,
      'media_url': mediaUrl,
      if (stickerId != null) 'sticker_id': stickerId,
      if (stickerUrl != null) 'sticker_url': stickerUrl,
      if (stickerName != null) 'sticker_name': stickerName,
      if (packId != null) 'pack_id': packId,
    };
  }

  /// Retorna o nickname local da comunidade.
  /// Sempre preenchido desde o join (migration 093).
  String effectiveNickname(String fallback) {
    final local = localNickname?.trim();
    if (local != null && local.isNotEmpty) return local;
    return fallback;
  }

  /// Retorna o avatar URL local da comunidade.
  /// Sempre preenchido desde o join (migration 093).
  String? get effectiveIconUrl {
    final local = localIconUrl?.trim();
    if (local != null && local.isNotEmpty) return local;
    return null;
  }

  bool get isSticker =>
      stickerId != null ||
      stickerUrl != null ||
      content == '[sticker]';
}
