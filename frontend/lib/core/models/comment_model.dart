import 'user_model.dart';

/// Modelo de comentário em posts.
class CommentModel {
  final String id;
  final String postId;
  final String authorId;
  final String? parentId;
  final String content;
  final String commentType;
  final String? mediaUrl;
  final int likesCount;
  final int repliesCount;
  final bool isHidden;
  final DateTime createdAt;
  final UserModel? author;
  final List<CommentModel> replies;

  const CommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    this.parentId,
    required this.content,
    this.commentType = 'text',
    this.mediaUrl,
    this.likesCount = 0,
    this.repliesCount = 0,
    this.isHidden = false,
    required this.createdAt,
    this.author,
    this.replies = const [],
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] as String,
      postId: json['post_id'] as String? ?? '',
      authorId: json['author_id'] as String? ?? '',
      parentId: json['parent_id'] as String?,
      content: json['content'] as String? ?? '',
      commentType: json['comment_type'] as String? ?? 'text',
      mediaUrl: json['media_url'] as String?,
      likesCount: json['likes_count'] as int? ?? 0,
      repliesCount: json['replies_count'] as int? ?? 0,
      isHidden: json['is_hidden'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      author: json['author'] != null
          ? UserModel.fromJson(json['author'] as Map<String, dynamic>)
          : (json['profiles'] != null
              ? UserModel.fromJson(json['profiles'] as Map<String, dynamic>)
              : null),
    );
  }
}
