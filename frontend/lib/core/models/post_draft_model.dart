import '../l10n/locale_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'post_editor_model.dart';

class PostDraftModel {
  final String id;
  final String userId;
  final String? communityId;
  final String? title;
  final String? subtitle;
  final String? content;
  final List<Map<String, dynamic>>? contentBlocks;
  final List<String> mediaUrls;
  final String postType;
  final String? editorType;
  final String? variant;
  final PostEditorModel editorMetadata;
  final String? coverImageUrl;
  final String? backgroundUrl;
  final String? externalUrl;
  final Map<String, dynamic>? pollData;
  final Map<String, dynamic>? quizData;
  final Map<String, dynamic>? storyData;
  final Map<String, dynamic>? chatData;
  final Map<String, dynamic>? wikiData;
  final Map<String, dynamic>? editorState;
  final List<String> tags;
  final String visibility;
  final bool commentsBlocked;
  final bool pinToProfile;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PostDraftModel({
    required this.id,
    required this.userId,
    this.communityId,
    this.title,
    this.subtitle,
    this.content,
    this.contentBlocks,
    this.mediaUrls = const [],
    this.postType = 'text',
    this.editorType,
    this.variant,
    this.editorMetadata = const PostEditorModel(),
    this.coverImageUrl,
    this.backgroundUrl,
    this.externalUrl,
    this.pollData,
    this.quizData,
    this.storyData,
    this.chatData,
    this.wikiData,
    this.editorState,
    this.tags = const [],
    this.visibility = 'public',
    this.commentsBlocked = false,
    this.pinToProfile = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PostDraftModel.fromJson(Map<String, dynamic> json) {
    return PostDraftModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      communityId: json['community_id'] as String?,
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
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
      editorType: json['editor_type'] as String?,
      variant: json['variant'] as String? ?? json['post_variant'] as String?,
      editorMetadata: PostEditorModel.fromJson(
        json['editor_metadata'] as Map<String, dynamic>?,
      ),
      coverImageUrl: json['cover_image_url'] as String?,
      backgroundUrl: json['background_url'] as String?,
      externalUrl: json['external_url'] as String?,
      pollData: json['poll_data'] as Map<String, dynamic>?,
      quizData: json['quiz_data'] as Map<String, dynamic>?,
      storyData: json['story_data'] as Map<String, dynamic>?,
      chatData: json['chat_data'] as Map<String, dynamic>?,
      wikiData: json['wiki_data'] as Map<String, dynamic>?,
      editorState: json['editor_state'] as Map<String, dynamic>?,
      tags: json['tags'] != null
          ? (json['tags'] as List).map((e) => e as String).toList()
          : const [],
      visibility: json['visibility'] as String? ?? 'public',
      commentsBlocked: json['comments_blocked'] == true,
      pinToProfile: json['pin_to_profile'] == true,
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
      if (subtitle != null) 'subtitle': subtitle,
      if (content != null) 'content': content,
      if (contentBlocks != null) 'content_blocks': contentBlocks,
      'media_urls': mediaUrls,
      'post_type': postType,
      if (editorType != null) 'editor_type': editorType,
      if (variant != null) 'variant': variant,
      'editor_metadata': editorMetadata.toJson(),
      if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
      if (backgroundUrl != null) 'background_url': backgroundUrl,
      if (externalUrl != null) 'external_url': externalUrl,
      if (pollData != null) 'poll_data': pollData,
      if (quizData != null) 'quiz_data': quizData,
      if (storyData != null) 'story_data': storyData,
      if (chatData != null) 'chat_data': chatData,
      if (wikiData != null) 'wiki_data': wikiData,
      if (editorState != null) 'editor_state': editorState,
      'tags': tags,
      'visibility': visibility,
      'comments_blocked': commentsBlocked,
      'pin_to_profile': pinToProfile,
    };
  }

  /// Retorna um resumo curto para exibição na lista.
  String get preview {
    if (title != null && title!.isNotEmpty) return title!;
    if (subtitle != null && subtitle!.isNotEmpty) return subtitle!;
    if (content != null && content!.isNotEmpty) {
      return content!.length > 80
          ? '${content!.substring(0, 80)}...'
          : content!;
    }
    return getStrings().untitledDraft;
  }

  String get effectiveEditorType => editorType ?? variant ?? postType;

  PostDraftModel copyWith({
    String? title,
    String? subtitle,
    String? content,
    List<Map<String, dynamic>>? contentBlocks,
    List<String>? mediaUrls,
    String? postType,
    String? editorType,
    String? variant,
    PostEditorModel? editorMetadata,
    String? coverImageUrl,
    String? backgroundUrl,
    String? externalUrl,
    Map<String, dynamic>? pollData,
    Map<String, dynamic>? quizData,
    Map<String, dynamic>? storyData,
    Map<String, dynamic>? chatData,
    Map<String, dynamic>? wikiData,
    Map<String, dynamic>? editorState,
    List<String>? tags,
    String? visibility,
    bool? commentsBlocked,
    bool? pinToProfile,
    String? communityId,
  }) {
    return PostDraftModel(
      id: id,
      userId: userId,
      communityId: communityId ?? this.communityId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      content: content ?? this.content,
      contentBlocks: contentBlocks ?? this.contentBlocks,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      postType: postType ?? this.postType,
      editorType: editorType ?? this.editorType,
      variant: variant ?? this.variant,
      editorMetadata: editorMetadata ?? this.editorMetadata,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      backgroundUrl: backgroundUrl ?? this.backgroundUrl,
      externalUrl: externalUrl ?? this.externalUrl,
      pollData: pollData ?? this.pollData,
      quizData: quizData ?? this.quizData,
      storyData: storyData ?? this.storyData,
      chatData: chatData ?? this.chatData,
      wikiData: wikiData ?? this.wikiData,
      editorState: editorState ?? this.editorState,
      tags: tags ?? this.tags,
      visibility: visibility ?? this.visibility,
      commentsBlocked: commentsBlocked ?? this.commentsBlocked,
      pinToProfile: pinToProfile ?? this.pinToProfile,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
