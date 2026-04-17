// Arquivo com melhorias para draft_provider.dart
// Adicionar suporte a múltiplos rascunhos nomeados e RPCs melhoradas

import 'package:flutter/foundation.dart';
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

    try {
      // Tentar usar RPC get_drafts primeiro
      final result = await SupabaseService.rpc('get_drafts', params: {
        'p_community_id': null,
        'p_draft_type': null,
      });

      if (result is Map<String, dynamic>) {
        final drafts = result['drafts'] as List?;
        if (drafts != null) {
          return drafts
              .map((e) => PostDraftModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      }
    } catch (_) {
      // Fallback para query direta
    }

    // Fallback: query direta na tabela
    final data = await SupabaseService.table('post_drafts')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);

    return (data as List? ?? [])
        .map((e) => PostDraftModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Criar um novo rascunho com suporte ao editor unificado.
  /// Agora usa RPC save_draft para melhor performance e validação.
  Future<PostDraftModel?> createDraft({
    String? communityId,
    String draftName = 'Rascunho sem título',
    String draftType = 'normal', // normal, blog, poll, quiz, wiki, story
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
      // Tentar usar RPC save_draft primeiro
      try {
        final result = await SupabaseService.rpc('save_draft', params: {
          'p_community_id': communityId,
          'p_draft_name': draftName,
          'p_draft_type': draftType,
          'p_title': title,
          'p_content': content,
          'p_content_blocks': contentBlocks,
          'p_media_urls': mediaUrls ?? [],
          'p_tags': tags ?? [],
          'p_visibility': visibility,
          'p_cover_image_url': coverImageUrl,
          'p_editor_metadata': editorMetadata.toJson(),
          'p_editor_state': editorState,
          'p_poll_options': pollData,
          'p_quiz_data': quizData,
          'p_wiki_data': wikiData,
          'p_story_data': storyData,
        });

        if (result is Map<String, dynamic> && result['success'] == true) {
          final draftId = result['draft_id'] as String?;
          if (draftId != null) {
            // Buscar o rascunho criado
            final draftData = await SupabaseService.rpc('get_draft', params: {
              'p_draft_id': draftId,
            });

            if (draftData is Map<String, dynamic>) {
              final draft = PostDraftModel.fromJson(draftData);
              final current = state.valueOrNull ?? [];
              state = AsyncData([draft, ...current]);
              return draft;
            }
          }
        }
      } catch (rpcError) {
        // Fallback para insert direto
      }

      // Fallback: insert direto
      final data = await SupabaseService.table('post_drafts')
          .insert({
            'user_id': userId,
            if (communityId != null) 'community_id': communityId,
            'draft_name': draftName,
            'draft_type': draftType,
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
            if (pollData != null) 'poll_options': pollData,
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
    } catch (e) {
      debugPrint('[draft_provider] Erro ao criar rascunho: $e');
      return null;
    }
  }

  /// Atualizar um rascunho existente com o conjunto completo de campos do editor.
  /// Agora usa RPC save_draft para melhor performance.
  Future<bool> updateDraft(
    String draftId, {
    String? draftName,
    String? draftType,
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
    bool isAutoSave = false,
  }) async {
    try {
      // Tentar usar RPC save_draft primeiro
      try {
        final result = await SupabaseService.rpc('save_draft', params: {
          'p_community_id': communityId,
          'p_draft_name': draftName,
          'p_draft_type': draftType,
          'p_title': title,
          'p_content': content,
          'p_content_blocks': contentBlocks,
          'p_media_urls': mediaUrls,
          'p_tags': tags,
          'p_visibility': visibility,
          'p_cover_image_url': coverImageUrl,
          'p_editor_metadata': editorMetadata?.toJson(),
          'p_editor_state': editorState,
          'p_poll_options': pollData,
          'p_quiz_data': quizData,
          'p_wiki_data': wikiData,
          'p_story_data': storyData,
          'p_draft_id': draftId,
          'p_is_auto_save': isAutoSave,
        });

        if (result is Map<String, dynamic> && result['success'] == true) {
          // Atualizar state local
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
        }
      } catch (rpcError) {
        // Fallback para update direto
      }

      // Fallback: update direto
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (draftName != null) updates['draft_name'] = draftName;
      if (draftType != null) updates['draft_type'] = draftType;
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
      if (pollData != null) updates['poll_options'] = pollData;
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
      if (isAutoSave) {
        updates['is_auto_save'] = true;
        updates['last_auto_save_at'] = DateTime.now().toIso8601String();
      }

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
    } catch (e) {
      debugPrint('[draft_provider] Erro ao atualizar rascunho: $e');
      return false;
    }
  }

  /// Deletar um rascunho.
  /// Agora usa RPC delete_draft para melhor performance.
  Future<bool> deleteDraft(String draftId) async {
    try {
      // Tentar usar RPC delete_draft primeiro
      try {
        final result = await SupabaseService.rpc('delete_draft', params: {
          'p_draft_id': draftId,
        });

        if (result is Map<String, dynamic> && result['success'] == true) {
          final current = state.valueOrNull ?? [];
          state = AsyncData(current.where((d) => d.id != draftId).toList());
          return true;
        }
      } catch (rpcError) {
        // Fallback para delete direto
      }

      // Fallback: delete direto
      await SupabaseService.table('post_drafts').delete().eq('id', draftId);

      final current = state.valueOrNull ?? [];
      state = AsyncData(current.where((d) => d.id != draftId).toList());
      return true;
    } catch (e) {
      debugPrint('[draft_provider] Erro ao deletar rascunho: $e');
      return false;
    }
  }

  /// Deletar todos os rascunhos do usuário atual.
  Future<bool> deleteAllDrafts() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return false;
    try {
      await SupabaseService.table('post_drafts')
          .delete()
          .eq('user_id', userId);
      state = const AsyncData([]);
      return true;
    } catch (e) {
      debugPrint('[draft_provider] Erro ao deletar todos os rascunhos: $e');
      return false;
    }
  }

  /// Recarregar rascunhos do servidor.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetchDrafts());
  }

  /// Obter rascunhos de uma comunidade específica
  Future<List<PostDraftModel>> getDraftsByCommunity(String communityId) async {
    try {
      final result = await SupabaseService.rpc('get_drafts', params: {
        'p_community_id': communityId,
        'p_draft_type': null,
      });

      if (result is Map<String, dynamic>) {
        final drafts = result['drafts'] as List?;
        if (drafts != null) {
          return drafts
              .map((e) => PostDraftModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      }
    } catch (_) {}

    return [];
  }

  /// Obter rascunhos de um tipo específico
  Future<List<PostDraftModel>> getDraftsByType(String draftType) async {
    try {
      final result = await SupabaseService.rpc('get_drafts', params: {
        'p_community_id': null,
        'p_draft_type': draftType,
      });

      if (result is Map<String, dynamic>) {
        final drafts = result['drafts'] as List?;
        if (drafts != null) {
          return drafts
              .map((e) => PostDraftModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      }
    } catch (_) {}

    return [];
  }
}
