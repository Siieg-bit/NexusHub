import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post_draft_model.dart';
import '../services/supabase_service.dart';

/// Provider que lista os rascunhos do usuário atual.
final postDraftsProvider =
    AsyncNotifierProvider<PostDraftsNotifier, List<PostDraftModel>>(
        PostDraftsNotifier.new);

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

  /// Criar um novo rascunho.
  Future<PostDraftModel?> createDraft({
    String? communityId,
    String? title,
    String? content,
    List<Map<String, dynamic>>? contentBlocks,
    List<String>? mediaUrls,
    String postType = 'text',
    List<String>? tags,
    String visibility = 'public',
  }) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return null;

    try {
      final data = await SupabaseService.table('post_drafts').insert({
        'user_id': userId,
        if (communityId != null) 'community_id': communityId,
        if (title != null) 'title': title,
        if (content != null) 'content': content,
        if (contentBlocks != null) 'content_blocks': contentBlocks,
        'media_urls': mediaUrls ?? [],
        'post_type': postType,
        'tags': tags ?? [],
        'visibility': visibility,
      }).select().single();

      final draft = PostDraftModel.fromJson(Map<String, dynamic>.from(data as Map));
      final current = state.valueOrNull ?? [];
      state = AsyncData([draft, ...current]);
      return draft;
    } catch (e) {
      return null;
    }
  }

  /// Atualizar um rascunho existente.
  Future<bool> updateDraft(
    String draftId, {
    String? title,
    String? content,
    List<Map<String, dynamic>>? contentBlocks,
    List<String>? mediaUrls,
    String? postType,
    List<String>? tags,
    String? visibility,
    String? communityId,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (title != null) updates['title'] = title;
      if (content != null) updates['content'] = content;
      if (contentBlocks != null) updates['content_blocks'] = contentBlocks;
      if (mediaUrls != null) updates['media_urls'] = mediaUrls;
      if (postType != null) updates['post_type'] = postType;
      if (tags != null) updates['tags'] = tags;
      if (visibility != null) updates['visibility'] = visibility;
      if (communityId != null) updates['community_id'] = communityId;

      await SupabaseService.table('post_drafts')
          .update(updates)
          .eq('id', draftId);

      // Atualizar localmente
      final current = state.valueOrNull ?? [];
      final index = current.indexWhere((d) => d.id == draftId);
      if (index >= 0) {
        final updated = [...current];
        updated[index] = updated[index].copyWith(
          title: title,
          content: content,
          contentBlocks: contentBlocks,
          mediaUrls: mediaUrls,
          postType: postType,
          tags: tags,
          visibility: visibility,
          communityId: communityId,
        );
        state = AsyncData(updated);
      }
      return true;
    } catch (e) {
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
    } catch (e) {
      return false;
    }
  }

  /// Recarregar rascunhos do servidor.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetchDrafts());
  }
}
