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
      mediaUrl; // campo virtual derivado de media_list (não existe no DB)
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
  final DateTime? featuredUntil;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserModel? author;
  final bool isLiked;
  final List<Map<String, dynamic>>? contentBlocks;

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
    this.featuredUntil,
    required this.createdAt,
    required this.updatedAt,
    this.author,
    this.isLiked = false,
    this.contentBlocks,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] as String,
      communityId: json['community_id'] as String? ?? '',
      authorId: json['author_id'] as String? ?? '',
      type: json['type'] as String? ?? 'normal',
      title: json['title'] as String?,
      content: json['content'] as String? ?? '',
      mediaUrl: (json['media_list'] is List && (json['media_list'] as List).isNotEmpty)
          ? ((json['media_list'] as List).first is Map
              ? (json['media_list'] as List).first['url'] as String?
              : (json['media_list'] as List).first as String?)
          : json['cover_image_url'] as String?,
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
      featuredUntil: json['featured_until'] != null
          ? DateTime.tryParse(json['featured_until'] as String)
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
      contentBlocks: (json['content_blocks'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'community_id': communityId,
      'author_id': authorId,
      'type': type,
      'title': title,
      'content': content,
      'media_list': mediaUrl != null ? [{'url': mediaUrl, 'type': 'image'}] : [],
      'cover_image_url': mediaUrl,
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
    DateTime? featuredUntil,
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
      featuredUntil: featuredUntil ?? this.featuredUntil,
      createdAt: createdAt,
      updatedAt: updatedAt,
      author: author,
      isLiked: isLiked ?? this.isLiked,
      contentBlocks: contentBlocks,
    );
  }

  /// Verifica se o post tem conteúdo em blocos (editor rico)
  bool get hasBlockContent => contentBlocks != null && contentBlocks!.isNotEmpty;

  /// Retorna true se o post está em destaque e ainda não expirou
  bool get isFeaturedActive {
    if (!isFeatured) return false;
    if (featuredUntil == null) return true; // sem expiração
    return featuredUntil!.isAfter(DateTime.now());
  }

  /// Extrai lista de URLs de mídia dos blocos e da mediaList
  List<String> get mediaUrls {
    final urls = <String>[];
    if (mediaList.isNotEmpty) {
      for (final m in mediaList) {
        if (m is Map && m['url'] != null) {
          urls.add(m['url'] as String);
        } else if (m is String) {
          urls.add(m);
        }
      }
    }
    if (contentBlocks != null) {
      for (final block in contentBlocks!) {
        if (block['type'] == 'image' && block['url'] != null) {
          urls.add(block['url'] as String);
        }
      }
    }
    return urls;
  }
}
