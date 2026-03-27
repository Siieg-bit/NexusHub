import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../config/app_theme.dart';
import '../../../core/models/post_model.dart';
import '../../../core/models/comment_model.dart';
import '../../../core/services/supabase_service.dart';

/// Provider para detalhes de um post.
final postDetailProvider = FutureProvider.family<PostModel, String>((ref, postId) async {
  final response = await SupabaseService.table('posts')
      .select('*, profiles!posts_author_id_fkey(*)')
      .eq('id', postId)
      .single();

  final map = Map<String, dynamic>.from(response);
  if (map['profiles'] != null) map['author'] = map['profiles'];
  return PostModel.fromJson(map);
});

/// Provider para comentários de um post.
final postCommentsProvider = FutureProvider.family<List<CommentModel>, String>((ref, postId) async {
  final response = await SupabaseService.table('comments')
      .select('*, profiles!comments_author_id_fkey(*)')
      .eq('post_id', postId)
      .eq('is_hidden', false)
      .order('created_at', ascending: true);

  return (response as List).map((e) => CommentModel.fromJson(e as Map<String, dynamic>)).toList();
});

/// Tela de detalhes de um post com comentários.
class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isSending = true);
    try {
      await SupabaseService.table('comments').insert({
        'post_id': widget.postId,
        'author_id': SupabaseService.currentUserId,
        'content': _commentController.text.trim(),
      });
      _commentController.clear();
      ref.invalidate(postCommentsProvider(widget.postId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao comentar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _toggleLike() async {
    try {
      await SupabaseService.rpc('toggle_post_like', params: {'p_post_id': widget.postId});
      ref.invalidate(postDetailProvider(widget.postId));
    } catch (e) {
      // Silenciar erro
    }
  }

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(postDetailProvider(widget.postId));
    final commentsAsync = ref.watch(postCommentsProvider(widget.postId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border_rounded),
            onPressed: () {/* TODO: Bookmark */},
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {/* TODO: Share */},
          ),
        ],
      ),
      body: postAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (post) => Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ======================================================
                    // HEADER DO POST
                    // ======================================================
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => context.push('/user/${post.authorId}'),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                              backgroundImage: post.author?.iconUrl != null
                                  ? CachedNetworkImageProvider(post.author!.iconUrl!)
                                  : null,
                              child: post.author?.iconUrl == null
                                  ? Text(
                                      (post.author?.nickname ?? '?')[0].toUpperCase(),
                                      style: const TextStyle(
                                          color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(post.author?.nickname ?? 'Usuário',
                                        style: const TextStyle(fontWeight: FontWeight.w600)),
                                    if (post.author != null) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.getLevelColor(post.author!.level)
                                              .withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Lv.${post.author!.level}',
                                          style: TextStyle(
                                            color: AppTheme.getLevelColor(post.author!.level),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  timeago.format(post.createdAt, locale: 'pt_BR'),
                                  style: const TextStyle(color: AppTheme.textHint, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ======================================================
                    // TÍTULO
                    // ======================================================
                    if (post.title != null && post.title!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(post.title!,
                            style: Theme.of(context).textTheme.headlineSmall),
                      ),

                    // ======================================================
                    // CONTEÚDO
                    // ======================================================
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        post.content,
                        style: const TextStyle(fontSize: 15, height: 1.7, color: AppTheme.textPrimary),
                      ),
                    ),

                    // ======================================================
                    // MÍDIA
                    // ======================================================
                    if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: post.mediaUrl!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                    // ======================================================
                    // AÇÕES
                    // ======================================================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        children: [
                          TextButton.icon(
                            onPressed: _toggleLike,
                            icon: Icon(
                              post.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: post.isLiked ? AppTheme.errorColor : AppTheme.textSecondary,
                            ),
                            label: Text('${post.likesCount}',
                                style: TextStyle(
                                    color: post.isLiked ? AppTheme.errorColor : AppTheme.textSecondary)),
                          ),
                          TextButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.chat_bubble_outline_rounded,
                                color: AppTheme.textSecondary),
                            label: Text('${post.commentsCount}',
                                style: const TextStyle(color: AppTheme.textSecondary)),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              const Icon(Icons.visibility_outlined, size: 16, color: AppTheme.textHint),
                              const SizedBox(width: 4),
                              Text('${post.viewsCount}',
                                  style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Divider(color: AppTheme.dividerColor),

                    // ======================================================
                    // COMENTÁRIOS
                    // ======================================================
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text('Comentários',
                          style: Theme.of(context).textTheme.titleMedium),
                    ),

                    commentsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      error: (error, _) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Erro ao carregar comentários: $error'),
                      ),
                      data: (comments) {
                        if (comments.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text('Nenhum comentário ainda. Seja o primeiro!',
                                  style: TextStyle(color: AppTheme.textHint)),
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: comments.length,
                          itemBuilder: (context, index) => _CommentTile(comment: comments[index]),
                        );
                      },
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),

            // ======================================================
            // INPUT DE COMENTÁRIO
            // ======================================================
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceColor,
                border: Border(top: BorderSide(color: AppTheme.dividerColor)),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: 'Escreva um comentário...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        maxLines: 3,
                        minLines: 1,
                      ),
                    ),
                    IconButton(
                      onPressed: _isSending ? null : _sendComment,
                      icon: _isSending
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, color: AppTheme.primaryColor),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommentModel comment;

  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.push('/user/${comment.authorId}'),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.3),
              backgroundImage: comment.author?.iconUrl != null
                  ? CachedNetworkImageProvider(comment.author!.iconUrl!)
                  : null,
              child: comment.author?.iconUrl == null
                  ? Text(
                      (comment.author?.nickname ?? '?')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(comment.author?.nickname ?? 'Usuário',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(width: 8),
                    Text(
                      timeago.format(comment.createdAt, locale: 'pt_BR'),
                      style: const TextStyle(color: AppTheme.textHint, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.content,
                    style: const TextStyle(fontSize: 13, height: 1.4)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {},
                      child: Row(
                        children: [
                          const Icon(Icons.favorite_border_rounded, size: 14, color: AppTheme.textHint),
                          const SizedBox(width: 4),
                          Text('${comment.likesCount}',
                              style: const TextStyle(color: AppTheme.textHint, fontSize: 11)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {},
                      child: const Text('Responder',
                          style: TextStyle(color: AppTheme.textHint, fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
