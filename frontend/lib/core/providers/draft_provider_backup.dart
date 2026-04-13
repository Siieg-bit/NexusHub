import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post_draft_model.dart';
import '../models/post_editor_model.dart';
import '../services/supabase_service.dart';

/// Provider que lista os rascunhos do usuário atual.
final postDraftsProvider =
    AsyncNotifierProvider<PostDraftsNotifier, List<PostDraftModel>>(
  PostDraftsNotifier.new,
);

class PostDraftsNotifier extends AsyncNotifier<List<PostDraftModel>> {
  @override
  Future<List<PostDraftModel>> build() async {
    return _fetchDrafts();
  }

  Future<List<PostDraftModel>> _fetchDrafts() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return [];

    final data = await SupabaseService.table('post_drafts')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);

    return (data as List? ?? [])
        .map((e) => PostDraftModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Criar um novo rascunho com suporte ao editor unificado.
  Future<PostDraftModel?> createDraft({
    String? communityId,
    String? title,
    String? subtitle,
    String? content,
    List<Map<String, dynamic>>? contentBlocks,
    List<String>? mediaUrls,
    String postType = 'text',
    String? editorType,
    String? variant,
    PostEditorModel editorMetadata = const PostEditorModel(),
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
    String visibility = 'public',
    bool commentsBlocked = false,
    bool pinToProfile = false,
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return null;

    try {
      final data = await SupabaseService.table('post_drafts')
          .insert({
            'user_id': userId,
            if (communityId != null) 'community_id': communityId,
            if (title != null) 'title': title,
            if (subtitle != null) 'subtitle': subtitle,
            if (content != null) 'content': content,
            if (contentBlocks != null) 'content_blocks': contentBlocks,
            'media_urls': mediaUrls ?? [],
            'post_type': postType,
            if (editorType != null) 'editor_type': editorType,
            if (variant != null) 'post_variant': variant,
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
            'tags': tags ?? [],
            'visibility': visibility,
            'comments_blocked': commentsBlocked,
            'pin_to_profile': pinToProfile,
          })
          .select()
          .single();

      final draft =
          PostDraftModel.fromJson(Map<String, dynamic>.from(data as Map));
      final current = state.valueOrNull ?? [];
      state = AsyncData([draft, ...current]);
      return draft;
    } catch (_) {
      return null;
    }
  }

  /// Atualizar um rascunho existente com o conjunto completo de campos do editor.
  Future<bool> updateDraft(
    String draftId, {
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
    String? communityId,
    bool? commentsBlocked,
    bool? pinToProfile,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (title != null) updates['title'] = title;
      if (subtitle != null) updates['subtitle'] = subtitle;
      if (content != null) updates['content'] = content;
      if (contentBlocks != null) updates['content_blocks'] = contentBlocks;
      if (mediaUrls != null) updates['media_urls'] = mediaUrls;
      if (postType != null) updates['post_type'] = postType;
      if (editorType != null) updates['editor_type'] = editorType;
      if (variant != null) updates['post_variant'] = variant;
      if (editorMetadata != null) {
        updates['editor_metadata'] = editorMetadata.toJson();
      }
      if (coverImageUrl != null) updates['cover_image_url'] = coverImageUrl;
      if (backgroundUrl != null) updates['background_url'] = backgroundUrl;
      if (externalUrl != null) updates['external_url'] = externalUrl;
      if (pollData != null) updates['poll_data'] = pollData;
      if (quizData != null) updates['quiz_data'] = quizData;
      if (storyData != null) updates['story_data'] = storyData;
      if (chatData != null) updates['chat_data'] = chatData;
      if (wikiData != null) updates['wiki_data'] = wikiData;
      if (editorState != null) updates['editor_state'] = editorState;
      if (tags != null) updates['tags'] = tags;
      if (visibility != null) updates['visibility'] = visibility;
      if (communityId != null) updates['community_id'] = communityId;
      if (commentsBlocked != null) {
        updates['comments_blocked'] = commentsBlocked;
      }
      if (pinToProfile != null) updates['pin_to_profile'] = pinToProfile;

      await SupabaseService.table('post_drafts').update(updates).eq('id', draftId);

      final current = state.valueOrNull ?? [];
      final index = current.indexWhere((d) => d.id == draftId);
      if (index >= 0) {
        final updated = [...current];
        updated[index] = updated[index].copyWith(
          title: title,
          subtitle: subtitle,
          content: content,
          contentBlocks: contentBlocks,
          mediaUrls: mediaUrls,
          postType: postType,
          editorType: editorType,
          variant: variant,
          editorMetadata: editorMetadata,
          coverImageUrl: coverImageUrl,
          backgroundUrl: backgroundUrl,
          externalUrl: externalUrl,
          pollData: pollData,
          quizData: quizData,
          storyData: storyData,
          chatData: chatData,
          wikiData: wikiData,
          editorState: editorState,
          tags: tags,
          visibility: visibility,
          communityId: communityId,
          commentsBlocked: commentsBlocked,
          pinToProfile: pinToProfile,
        );
        state = AsyncData(updated);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Deletar um rascunho.
  Future<bool> deleteDraft(String draftId) async {
    try {
      await SupabaseService.table('post_drafts').delete().eq('id', draftId);

      final current = state.valueOrNull ?? [];
      state = AsyncData(current.where((d) => d.id != draftId).toList());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Recarregar rascunhos do servidor.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetchDrafts());
  }
}
