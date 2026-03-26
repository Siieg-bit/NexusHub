import 'user_model.dart';

/// Modelo de entrada Wiki (estilo fandom).
class WikiEntryModel {
  final String id;
  final String communityId;
  final String authorId;
  final String title;
  final String content;
  final String? coverImageUrl;
  final String? category;
  final List<String> tags;
  final int viewsCount;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserModel? author;

  const WikiEntryModel({
    required this.id,
    required this.communityId,
    required this.authorId,
    required this.title,
    required this.content,
    this.coverImageUrl,
    this.category,
    this.tags = const [],
    this.viewsCount = 0,
    this.isPublished = true,
    required this.createdAt,
    required this.updatedAt,
    this.author,
  });

  factory WikiEntryModel.fromJson(Map<String, dynamic> json) {
    return WikiEntryModel(
      id: json['id'] as String,
      communityId: json['community_id'] as String? ?? '',
      authorId: json['author_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      coverImageUrl: json['cover_image_url'] as String?,
      category: json['category'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      viewsCount: json['views_count'] as int? ?? 0,
      isPublished: json['is_published'] as bool? ?? true,
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
      'title': title,
      'content': content,
      'cover_image_url': coverImageUrl,
      'category': category,
      'tags': tags,
    };
  }
}
