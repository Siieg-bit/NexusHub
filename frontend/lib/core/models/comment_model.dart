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
  final int likesCount;
  final String status; // enum: ok, pending, closed, disabled, deleted
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserModel? author;
  final List<CommentModel> replies;

  const CommentModel({
    required this.id,
    required this.authorId,
    this.postId,
    this.wikiId,
    this.profileWallId,
    this.parentId,
    required this.content,
    this.mediaUrl,
    this.likesCount = 0,
    this.status = 'ok',
    required this.createdAt,
    required this.updatedAt,
    this.author,
    this.replies = const [],
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
      likesCount: json['likes_count'] as int? ?? 0,
      status: json['status'] as String? ?? 'ok',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
      author: json['author'] != null
          ? UserModel.fromJson(json['author'] as Map<String, dynamic>)
          : (json['profiles'] != null
              ? UserModel.fromJson(json['profiles'] as Map<String, dynamic>)
              : null),
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
    };
  }
}
