import 'user_model.dart';

/// Modelo de post/blog do feed.
/// Baseado na engenharia reversa dos modelos Feed e Blog do Amino original.
class PostModel {
  final String id;
  final String communityId;
  final String authorId;
  final String? title;
  final String content;
  final List<String> mediaUrls;
  final String postType;
  final String status;
  final String featureType;
  final int likesCount;
  final int commentsCount;
  final int viewsCount;
  final int shareCount;
  final bool isGlobal;
  final List<dynamic>? pollOptions;
  final List<dynamic>? quizQuestions;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserModel? author;
  final bool isLiked;

  const PostModel({
    required this.id,
    required this.communityId,
    required this.authorId,
    this.title,
    required this.content,
    this.mediaUrls = const [],
    this.postType = 'blog',
    this.status = 'published',
    this.featureType = 'none',
    this.likesCount = 0,
    this.commentsCount = 0,
    this.viewsCount = 0,
    this.shareCount = 0,
    this.isGlobal = false,
    this.pollOptions,
    this.quizQuestions,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.author,
    this.isLiked = false,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] as String,
      communityId: json['community_id'] as String? ?? '',
      authorId: json['author_id'] as String? ?? '',
      title: json['title'] as String?,
      content: json['content'] as String? ?? '',
      mediaUrls: (json['media_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      postType: json['post_type'] as String? ?? 'blog',
      status: json['status'] as String? ?? 'published',
      featureType: json['feature_type'] as String? ?? 'none',
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      viewsCount: json['views_count'] as int? ?? 0,
      shareCount: json['share_count'] as int? ?? 0,
      isGlobal: json['is_global'] as bool? ?? false,
      pollOptions: json['poll_options'] as List<dynamic>?,
      quizQuestions: json['quiz_questions'] as List<dynamic>?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
      author: json['author'] != null
          ? UserModel.fromJson(json['author'] as Map<String, dynamic>)
          : null,
      isLiked: json['is_liked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'community_id': communityId,
      'author_id': authorId,
      'title': title,
      'content': content,
      'media_urls': mediaUrls,
      'post_type': postType,
      'tags': tags,
    };
  }

  PostModel copyWith({
    int? likesCount,
    int? commentsCount,
    bool? isLiked,
  }) {
    return PostModel(
      id: id,
      communityId: communityId,
      authorId: authorId,
      title: title,
      content: content,
      mediaUrls: mediaUrls,
      postType: postType,
      status: status,
      featureType: featureType,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      viewsCount: viewsCount,
      shareCount: shareCount,
      isGlobal: isGlobal,
      pollOptions: pollOptions,
      quizQuestions: quizQuestions,
      tags: tags,
      createdAt: createdAt,
      updatedAt: updatedAt,
      author: author,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}
