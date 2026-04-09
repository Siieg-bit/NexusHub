/// Modelo de rascunho de post.
class PostDraftModel {
  final String id;
  final String userId;
  final String? communityId;
  final String? title;
  final String? content;
  final List<Map<String, dynamic>>? contentBlocks;
  final List<String> mediaUrls;
  final String postType;
  final List<String> tags;
  final String visibility;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PostDraftModel({
    required this.id,
    required this.userId,
    this.communityId,
    this.title,
    this.content,
    this.contentBlocks,
    this.mediaUrls = const [],
    this.postType = 'text',
    this.tags = const [],
    this.visibility = 'public',
    required this.createdAt,
    required this.updatedAt,
  });

  factory PostDraftModel.fromJson(Map<String, dynamic> json) {
    return PostDraftModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      communityId: json['community_id'] as String?,
      title: json['title'] as String?,
      content: json['content'] as String?,
      contentBlocks: json['content_blocks'] != null
          ? (json['content_blocks'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : null,
      mediaUrls: json['media_urls'] != null
          ? (json['media_urls'] as List).map((e) => e as String).toList()
          : const [],
      postType: json['post_type'] as String? ?? 'text',
      tags: json['tags'] != null
          ? (json['tags'] as List).map((e) => e as String).toList()
          : const [],
      visibility: json['visibility'] as String? ?? 'public',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      if (communityId != null) 'community_id': communityId,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (contentBlocks != null) 'content_blocks': contentBlocks,
      'media_urls': mediaUrls,
      'post_type': postType,
      'tags': tags,
      'visibility': visibility,
    };
  }

  /// Retorna um resumo curto para exibição na lista.
  String get preview {
    if (title != null && title!.isNotEmpty) return title!;
    if (content != null && content!.isNotEmpty) {
      return content!.length > 80
          ? '${content!.substring(0, 80)}...'
          : content!;
    }
    return s.untitledDraft;
  }

  PostDraftModel copyWith({
    String? title,
    String? content,
    List<Map<String, dynamic>>? contentBlocks,
    List<String>? mediaUrls,
    String? postType,
    List<String>? tags,
    String? visibility,
    String? communityId,
  }) {
    return PostDraftModel(
      id: id,
      userId: userId,
      communityId: communityId ?? this.communityId,
      title: title ?? this.title,
      content: content ?? this.content,
      contentBlocks: contentBlocks ?? this.contentBlocks,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      postType: postType ?? this.postType,
      tags: tags ?? this.tags,
      visibility: visibility ?? this.visibility,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
