import 'user_model.dart';
import 'post_editor_model.dart';

/// Modelo de post/blog do feed.
/// Baseado no schema v5 — engenharia reversa do APK Amino (Blog.smali).
class PostModel {
  final String id;
  final String communityId;
  final String authorId;
  final String? editorType;
  final String? variant;
  final PostEditorModel editorMetadata;
  final Map<String, dynamic>? storyData;
  final Map<String, dynamic>? chatData;
  final Map<String, dynamic>? wikiData;
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
  final Map<String, dynamic>? editorState;
  final int likesCount;
  final int commentsCount;
  final int viewsCount;
  final int tipsTotal;
  final String status; // enum: ok, pending, closed, disabled, deleted
  final bool isFeatured;
  final bool isPinned;
  final bool isPinnedProfile;
  final String? featuredBy;
  final DateTime? featuredAt;
  final DateTime? featuredUntil;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserModel? author;
  final bool isLiked;
  /// Autor do post original (para reposts).
  /// Populado via join com profiles quando type = 'repost'.
  final UserModel? originalAuthor;
  /// Dados completos do post original (para reposts — estilo retweet).
  final PostModel? originalPost;
  final List<Map<String, dynamic>>? contentBlocks;
  /// Nível LOCAL do autor na comunidade deste post.
  /// Populado via community_members.local_level — NUNCA de profiles.level (global).
  final int? authorLocalLevel;
  /// Nickname LOCAL do autor na comunidade deste post.
  final String? authorLocalNickname;
  /// Avatar LOCAL do autor na comunidade deste post.
  final String? authorLocalIconUrl;
  /// Banner LOCAL do autor na comunidade deste post.
  final String? authorLocalBannerUrl;
  /// BlurHash da imagem principal do post — usado como placeholder visual.
  final String? mediaBlurhash;

  const PostModel({
    required this.id,
    required this.communityId,
    required this.authorId,
    this.editorType,
    this.variant,
    this.editorMetadata = const PostEditorModel(),
    this.storyData,
    this.chatData,
    this.wikiData,
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
    this.editorState,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.viewsCount = 0,
    this.tipsTotal = 0,
    this.status = 'ok',
    this.isFeatured = false,
    this.isPinned = false,
    this.isPinnedProfile = false,
    this.featuredBy,
    this.featuredAt,
    this.featuredUntil,
    required this.createdAt,
    required this.updatedAt,
    this.author,
    this.isLiked = false,
    this.contentBlocks,
    this.authorLocalLevel,
    this.authorLocalNickname,
    this.authorLocalIconUrl,
    this.authorLocalBannerUrl,
    this.originalAuthor,
    this.originalPost,
    this.mediaBlurhash,
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id'] as String,
      communityId: json['community_id'] as String? ?? '',
      authorId: json['author_id'] as String? ?? '',
      editorType: json['editor_type'] as String? ??
          (json['editor_metadata'] is Map
              ? (json['editor_metadata'] as Map)['editor_type'] as String?
              : null),
      variant: json['variant'] as String? ?? json['post_variant'] as String?,
      editorMetadata: PostEditorModel.fromJson(
        json['editor_metadata'] as Map<String, dynamic>?,
      ),
      storyData: json['story_data'] as Map<String, dynamic>?,
      chatData: json['chat_data'] as Map<String, dynamic>?,
      wikiData: json['wiki_data'] as Map<String, dynamic>?,
      type: json['type'] as String? ?? 'normal',
      title: json['title'] as String?,
      content: json['content'] as String? ?? '',
      mediaUrl: (json['media_list'] is List &&
              (json['media_list'] as List).isNotEmpty)
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
      editorState: json['editor_state'] as Map<String, dynamic>?,
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      viewsCount: (json['views_count'] as num?)?.toInt() ?? 0,
      tipsTotal: (json['tips_total'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'ok',
      isFeatured: json['is_featured'] as bool? ?? false,
      isPinned: json['is_pinned'] as bool? ?? false,
      isPinnedProfile: json['is_pinned_profile'] as bool? ?? false,
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
      authorLocalLevel: (json['author_local_level'] as num?)?.toInt(),
      authorLocalNickname: json['author_local_nickname'] as String?,
      authorLocalIconUrl: json['author_local_icon_url'] as String?,
      authorLocalBannerUrl: json['author_local_banner_url'] as String?,
      originalAuthor: json['original_author'] != null
          ? UserModel.fromJson(json['original_author'] as Map<String, dynamic>)
          : null,
      originalPost: json['original_post'] != null
          ? PostModel.fromJson(json['original_post'] as Map<String, dynamic>)
          : null,
      contentBlocks: (json['content_blocks'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      mediaBlurhash: json['media_blurhash'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'community_id': communityId,
      'author_id': authorId,
      if (editorType != null) 'editor_type': editorType,
      if (variant != null) 'variant': variant,
      'editor_metadata': editorMetadata.toJson(),
      if (storyData != null) 'story_data': storyData,
      if (chatData != null) 'chat_data': chatData,
      if (wikiData != null) 'wiki_data': wikiData,
      'type': type,
      'title': title,
      'content': content,
      'media_list': mediaUrl != null
          ? [
              {'url': mediaUrl, 'type': 'image'}
            ]
          : [],
      'cover_image_url': mediaUrl,
      'tags': tags,
      if (pollData != null) 'poll_data': pollData,
      if (quizData != null) 'quiz_data': quizData,
      if (editorState != null) 'editor_state': editorState,
    };
  }

  PostModel copyWith({
    int? likesCount,
    int? commentsCount,
    bool? isLiked,
    bool? isFeatured,
    bool? isPinned,
    bool? isPinnedProfile,
    DateTime? featuredUntil,
    Map<String, dynamic>? pollData,
    UserModel? originalAuthor,
    PostModel? originalPost,
  }) {
    return PostModel(
      id: id,
      communityId: communityId,
      authorId: authorId,
      editorType: editorType,
      variant: variant,
      editorMetadata: editorMetadata,
      storyData: storyData,
      chatData: chatData,
      wikiData: wikiData,
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
      pollData: pollData ?? this.pollData,
      quizData: quizData,
      editorState: editorState,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      viewsCount: viewsCount,
      tipsTotal: tipsTotal,
      status: status,
      isFeatured: isFeatured ?? this.isFeatured,
      isPinned: isPinned ?? this.isPinned,
      isPinnedProfile: isPinnedProfile ?? this.isPinnedProfile,
      featuredBy: featuredBy,
      featuredAt: featuredAt,
      featuredUntil: featuredUntil ?? this.featuredUntil,
      createdAt: createdAt,
      updatedAt: updatedAt,
      author: author,
      isLiked: isLiked ?? this.isLiked,
      contentBlocks: contentBlocks,
      authorLocalLevel: authorLocalLevel,
      authorLocalNickname: authorLocalNickname,
      authorLocalIconUrl: authorLocalIconUrl,
      authorLocalBannerUrl: authorLocalBannerUrl,
      originalAuthor: originalAuthor ?? this.originalAuthor,
      originalPost: originalPost ?? this.originalPost,
      mediaBlurhash: mediaBlurhash,
    );
  }

  /// Verifica se o post tem conteúdo em blocos (editor rico)
  bool get hasBlockContent =>
      contentBlocks != null && contentBlocks!.isNotEmpty;

  /// Retorna true se o post está marcado como destaque.
  ///
  /// A vitrine passa a ser controlada por ordem de inserção/substituição,
  /// não mais por vencimento temporal. O campo legado `featuredUntil` é
  /// preservado apenas por compatibilidade de dados.
  bool get isFeaturedActive => isFeatured;

  /// Extrai lista de URLs de mídia dos blocos e da mediaList
  String get effectiveEditorType =>
      editorType ?? variant ?? type;

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
