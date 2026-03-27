import 'user_model.dart';

/// Modelo de post/blog do feed.
/// Baseado no schema v5 — engenharia reversa do APK Amino (Blog.smali).
class PostModel {
  final String id;
  final String communityId;
  final String authorId;
  final String
      type; // enum: normal, crosspost, repost, qa, poll, link, quiz, image, external
  final String? title;
  final String content;
  final String?
      mediaUrl; // era media_urls (array) → agora media_url (single) + media_list
  final List<dynamic> mediaList; // JSONB array de mídias adicionais
  final String? coverImageUrl;
  final String? backgroundUrl;
  final String? categoryId;
  final List<String> tags;
  final String? originalPostId; // para crosspost/repost
  final String? originalCommunityId;
  final String? externalUrl; // para type=link
  final Map<String, dynamic>? linkSummary;
  final Map<String, dynamic>?
      pollData; // JSONB: {options: [{text, votes}], totalVotes, userVote}
  final Map<String, dynamic>?
      quizData; // JSONB: {questions: [{text, options, correctIndex}]}
  final int likesCount;
  final int commentsCount;
  final int viewsCount;
  final int tipsTotal;
  final String status; // enum: ok, pending, closed, disabled, deleted
  final bool isFeatured;
  final bool isPinned;
  final String? featuredBy;
  final DateTime? featuredAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserModel? author;
  final bool isLiked;

  const PostModel({
    required this.id,
    required this.communityId,
    required this.authorId,
    this.type = 'normal',
    this.title,
    required this.content,
    this.mediaUrl,
    this.mediaList = const [],
    this.coverImageUrl,
    this.backgroundUrl,
    this.categoryId,
    this.tags = const [],
    this.originalPostId,
    this.originalCommunityId,
    this.externalUrl,
    this.linkSummary,
    this.pollData,
    this.quizData,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.viewsCount = 0,
    this.tipsTotal = 0,
    this.status = 'ok',
    this.isFeatured = false,
    this.isPinned = false,
    this.featuredBy,
    this.featuredAt,
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
      type: json['type'] as String? ?? 'normal',
      title: json['title'] as String?,
      content: json['content'] as String? ?? '',
      mediaUrl: json['media_url'] as String?,
      mediaList: json['media_list'] as List<dynamic>? ?? [],
      coverImageUrl: json['cover_image_url'] as String?,
      backgroundUrl: json['background_url'] as String?,
      categoryId: json['category_id'] as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              [],
      originalPostId: json['original_post_id'] as String?,
      originalCommunityId: json['original_community_id'] as String?,
      externalUrl: json['external_url'] as String?,
      linkSummary: json['link_summary'] as Map<String, dynamic>?,
      pollData: json['poll_data'] as Map<String, dynamic>?,
      quizData: json['quiz_data'] as Map<String, dynamic>?,
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      viewsCount: json['views_count'] as int? ?? 0,
      tipsTotal: json['tips_total'] as int? ?? 0,
      status: json['status'] as String? ?? 'ok',
      isFeatured: json['is_featured'] as bool? ?? false,
      isPinned: json['is_pinned'] as bool? ?? false,
      featuredBy: json['featured_by'] as String?,
      featuredAt: json['featured_at'] != null
          ? DateTime.tryParse(json['featured_at'] as String)
          : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
      author: json['profiles'] != null
          ? UserModel.fromJson(json['profiles'] as Map<String, dynamic>)
          : (json['author'] != null
              ? UserModel.fromJson(json['author'] as Map<String, dynamic>)
              : null),
      isLiked: json['is_liked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'community_id': communityId,
      'author_id': authorId,
      'type': type,
      'title': title,
      'content': content,
      'media_url': mediaUrl,
      'tags': tags,
      if (pollData != null) 'poll_data': pollData,
      if (quizData != null) 'quiz_data': quizData,
    };
  }

  PostModel copyWith({
    int? likesCount,
    int? commentsCount,
    bool? isLiked,
    bool? isFeatured,
    bool? isPinned,
  }) {
    return PostModel(
      id: id,
      communityId: communityId,
      authorId: authorId,
      type: type,
      title: title,
      content: content,
      mediaUrl: mediaUrl,
      mediaList: mediaList,
      coverImageUrl: coverImageUrl,
      backgroundUrl: backgroundUrl,
      categoryId: categoryId,
      tags: tags,
      originalPostId: originalPostId,
      originalCommunityId: originalCommunityId,
      externalUrl: externalUrl,
      linkSummary: linkSummary,
      pollData: pollData,
      quizData: quizData,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      viewsCount: viewsCount,
      tipsTotal: tipsTotal,
      status: status,
      isFeatured: isFeatured ?? this.isFeatured,
      isPinned: isPinned ?? this.isPinned,
      featuredBy: featuredBy,
      featuredAt: featuredAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      author: author,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}
