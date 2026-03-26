import 'user_model.dart';

/// Modelo de entrada Wiki (estilo fandom).
/// Baseado no schema v5 — tabela wiki_entries.
class WikiEntryModel {
  final String id;
  final String communityId;
  final String authorId;
  final String? categoryId;
  final String title;
  final String content;
  final String? coverImageUrl;
  final List<dynamic> mediaList;
  final double? myRating;
  final Map<String, dynamic>? customFields;
  final List<String> tags;
  final String status; // enum: ok, pending, closed, disabled, deleted
  final String? submissionNote;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final int likesCount;
  final int commentsCount;
  final int viewsCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserModel? author;

  const WikiEntryModel({
    required this.id,
    required this.communityId,
    required this.authorId,
    this.categoryId,
    required this.title,
    required this.content,
    this.coverImageUrl,
    this.mediaList = const [],
    this.myRating,
    this.customFields,
    this.tags = const [],
    this.status = 'ok',
    this.submissionNote,
    this.reviewedBy,
    this.reviewedAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.viewsCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.author,
  });

  /// Indica se a wiki está publicada (status == 'ok').
  bool get isPublished => status == 'ok';

  factory WikiEntryModel.fromJson(Map<String, dynamic> json) {
    return WikiEntryModel(
      id: json['id'] as String,
      communityId: json['community_id'] as String? ?? '',
      authorId: json['author_id'] as String? ?? '',
      categoryId: json['category_id'] as String?,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      coverImageUrl: json['cover_image_url'] as String?,
      mediaList: json['media_list'] as List<dynamic>? ?? [],
      myRating: (json['my_rating'] as num?)?.toDouble(),
      customFields: json['custom_fields'] as Map<String, dynamic>?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      status: json['status'] as String? ?? 'ok',
      submissionNote: json['submission_note'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.tryParse(json['reviewed_at'] as String)
          : null,
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      viewsCount: json['views_count'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
      author: json['profiles'] != null
          ? UserModel.fromJson(json['profiles'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'community_id': communityId,
      'author_id': authorId,
      'category_id': categoryId,
      'title': title,
      'content': content,
      'cover_image_url': coverImageUrl,
      'tags': tags,
    };
  }
}
