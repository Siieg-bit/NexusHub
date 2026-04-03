import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../config/app_theme.dart';
import '../../../core/models/post_model.dart';
import '../../../core/models/comment_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/providers/post_provider.dart';
import '../widgets/block_content_renderer.dart';
import '../widgets/poll_quiz_widget.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../moderation/widgets/report_dialog.dart';
import '../../../core/utils/responsive.dart';

/// Provider para comentários de um post.
final postCommentsProvider =
    FutureProvider.family<List<CommentModel>, String>((ref, postId) async {
  final response = await SupabaseService.table('comments')
      .select('*, profiles!comments_author_id_fkey(*)')
      .eq('post_id', postId)
      .eq('status', 'ok')
      .order('created_at', ascending: true);

  return (response as List? ?? [])
      .map((e) => CommentModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Tela de detalhes de um post com comentários — layout Amino.
class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  bool _isSending = false;
  bool _viewRecorded = false;
  bool _isBookmarked = false;

  /// Incrementa views_count uma única vez por abertura da tela.
  Future<void> _recordView() async {
    if (_viewRecorded) return;
    _viewRecorded = true;
    try {
      final row = await SupabaseService.table('posts')
          .select('views_count')
          .eq('id', widget.postId)
          .maybeSingle();
      final current = (row?['views_count'] as int?) ?? 0;
      await SupabaseService.table('posts')
          .update({'views_count': current + 1})
          .eq('id', widget.postId);
    } catch (e) {
      debugPrint('[NexusHub] Erro ao registrar visualização: $e');
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Você precisa estar logado para comentar.')),
        );
      }
      return;
    }

    setState(() => _isSending = true);
    try {
      var postData = ref.read(postDetailProvider(widget.postId)).valueOrNull;
      String? communityId = postData?.communityId;

      if (communityId == null) {
        try {
          final row = await SupabaseService.table('posts')
              .select('community_id')
              .eq('id', widget.postId)
              .maybeSingle();
          communityId = row?['community_id'] as String?;
        } catch (_) {}
      }

      await SupabaseService.rpc('create_comment_with_reputation', params: {
        'p_community_id': communityId,
        'p_author_id': userId,
        'p_content': _commentController.text.trim(),
        'p_post_id': widget.postId,
      });
      if (!mounted) return;
      _commentController.clear();
      _commentFocusNode.unfocus();
      ref.invalidate(postCommentsProvider(widget.postId));
      ref.invalidate(postDetailProvider(widget.postId));
    } catch (e) {
      debugPrint('[NexusHub] Erro ao comentar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao comentar: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _toggleLike() async {
    try {
      final postData = ref.read(postDetailProvider(widget.postId)).valueOrNull;
      await SupabaseService.rpc('toggle_like_with_reputation', params: {
        'p_community_id': postData?.communityId,
        'p_user_id': SupabaseService.currentUserId,
        'p_post_id': widget.postId,
      });
      ref.invalidate(postDetailProvider(widget.postId));
    } catch (_) {}
  }

  Future<void> _toggleBookmark() async {
    try {
      final result = await SupabaseService.rpc('toggle_bookmark', params: {
        'p_user_id': SupabaseService.currentUserId,
        'p_post_id': widget.postId,
      });
      if (mounted) {
        final bookmarked = (result as Map<String, dynamic>?)?['bookmarked'] == true;
        setState(() => _isBookmarked = bookmarked);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(bookmarked ? 'Post salvo!' : 'Post removido dos salvos'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ocorreu um erro. Tente novamente.')),
        );
      }
    }
  }

  void _sharePost() {
    final link = 'https://nexushub.app/p/${widget.postId}';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copiado!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final postAsync = ref.watch(postDetailProvider(widget.postId));
    final commentsAsync = ref.watch(postCommentsProvider(widget.postId));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          postAsync.valueOrNull?.type == 'blog' ? 'Blog' : 'Post',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
          ),
        ),
        iconTheme: IconThemeData(color: context.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _sharePost,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded),
            color: context.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(r.s(12)),
            ),
            onSelected: (value) async {
              final post = ref.read(postDetailProvider(widget.postId)).valueOrNull;
              if (post == null) return;
              switch (value) {
                case 'report':
                  ReportDialog.show(
                    context,
                    communityId: post.communityId,
                    targetPostId: widget.postId,
                  );
                  break;
                case 'delete':
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: context.surfaceColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(r.s(16)),
                      ),
                      title: Text('Deletar Post',
                          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700)),
                      content: Text(
                        'Tem certeza que deseja deletar este post? Esta ação não pode ser desfeita.',
                        style: TextStyle(color: context.textSecondary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('Cancelar', style: TextStyle(color: Colors.grey[500])),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Deletar',
                              style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && mounted) {
                    try {
                      await SupabaseService.table('posts')
                          .update({'status': 'deleted'})
                          .eq('id', widget.postId);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Post deletado'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        context.pop();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Ocorreu um erro. Tente novamente.')),
                        );
                      }
                    }
                  }
                  break;
                case 'copy_link':
                  _sharePost();
                  break;
                case 'edit':
                  _showEditPostDialog(post);
                  break;
                case 'pin_profile':
                  try {
                    final isPinned = post.isPinned;
                    await SupabaseService.table('posts')
                        .update({'is_pinned_profile': !isPinned})
                        .eq('id', widget.postId);
                    if (!mounted) return;
                    ref.invalidate(postDetailProvider(widget.postId));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(isPinned ? 'Post desafixado do perfil' : 'Post fixado no perfil'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ));
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ocorreu um erro. Tente novamente.')));
                  }
                  break;
                case 'hide':
                  try {
                    final userId = SupabaseService.currentUserId;
                    if (userId != null) {
                      await SupabaseService.table('hidden_posts').upsert({
                        'user_id': userId,
                        'post_id': widget.postId,
                        'hidden_at': DateTime.now().toIso8601String(),
                      }, onConflict: 'user_id,post_id');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Post ocultado do seu feed'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ));
                        context.pop();
                      }
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ocorreu um erro. Tente novamente.')));
                  }
                  break;
              }
            },
            itemBuilder: (context) {
              final post = ref.read(postDetailProvider(widget.postId)).valueOrNull;
              final isAuthor = post?.authorId == SupabaseService.currentUserId;
              return [
                PopupMenuItem(
                  value: 'copy_link',
                  child: Row(children: [
                    Icon(Icons.link_rounded, size: r.s(18), color: context.textSecondary),
                    SizedBox(width: r.s(10)),
                    Text('Copiar Link', style: TextStyle(color: context.textPrimary)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'report',
                  child: Row(children: [
                    Icon(Icons.flag_rounded, size: r.s(18), color: Colors.orange),
                    SizedBox(width: r.s(10)),
                    Text('Reportar', style: TextStyle(color: context.textPrimary)),
                  ]),
                ),
                if (isAuthor)
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_rounded, size: r.s(18), color: AppTheme.primaryColor),
                      SizedBox(width: r.s(10)),
                      Text('Editar', style: TextStyle(color: context.textPrimary)),
                    ]),
                  ),
                if (isAuthor)
                  PopupMenuItem(
                    value: 'pin_profile',
                    child: Row(children: [
                      Icon(
                        (post?.isPinned == true) ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                        size: r.s(18),
                        color: AppTheme.primaryColor,
                      ),
                      SizedBox(width: r.s(10)),
                      Text(
                        (post?.isPinned == true) ? 'Desafixar do Perfil' : 'Fixar no Perfil',
                        style: TextStyle(color: context.textPrimary),
                      ),
                    ]),
                  ),
                if (!isAuthor)
                  PopupMenuItem(
                    value: 'hide',
                    child: Row(children: [
                      Icon(Icons.visibility_off_rounded, size: r.s(18), color: Colors.grey),
                      SizedBox(width: r.s(10)),
                      Text('Ocultar Post', style: TextStyle(color: context.textPrimary)),
                    ]),
                  ),
                if (isAuthor)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_rounded, size: r.s(18), color: AppTheme.errorColor),
                      SizedBox(width: r.s(10)),
                      Text('Deletar', style: TextStyle(color: AppTheme.errorColor)),
                    ]),
                  ),
              ];
            },
          ),
        ],
      ),
      body: postAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
        ),
        error: (error, _) => Center(
          child: Text('Erro: $error', style: const TextStyle(color: AppTheme.errorColor)),
        ),
        data: (post) {
          if (post == null) {
            return Center(
              child: Text('Post não encontrado.',
                  style: TextStyle(color: context.textSecondary)),
            );
          }
          if (!_viewRecorded) _recordView();
          return Column(
            children: [
              // ================================================================
              // CORPO DO POST (scrollável)
              // ================================================================
              Expanded(
                child: RefreshIndicator(
                  color: AppTheme.primaryColor,
                  onRefresh: () async {
                    ref.invalidate(postDetailProvider);
                    ref.invalidate(postCommentsProvider);
                    await Future.delayed(const Duration(milliseconds: 300));
                    if (!mounted) return;
                  },
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ======================================================
                        // TÍTULO
                        // ======================================================
                        if (post.title != null && post.title!.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.fromLTRB(r.s(16), r.s(16), r.s(16), r.s(4)),
                            child: Text(
                              post.title!,
                              style: TextStyle(
                                fontSize: r.fs(22),
                                fontWeight: FontWeight.w800,
                                color: context.textPrimary,
                              ),
                            ),
                          ),

                        // ======================================================
                        // HEADER DO AUTOR (com like no canto direito)
                        // ======================================================
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: r.s(16), vertical: r.s(12)),
                          child: Row(
                            children: [
                              CosmeticAvatar(
                                userId: post.authorId,
                                avatarUrl: post.author?.iconUrl,
                                size: r.s(40),
                                onTap: () => context.push('/user/${post.authorId}'),
                              ),
                              SizedBox(width: r.s(10)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            post.author?.nickname ?? 'Usuário',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: context.textPrimary,
                                              fontSize: r.fs(15),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (post.author != null) ...[
                                          SizedBox(width: r.s(6)),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: r.s(7), vertical: 2),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  AppTheme.getLevelColor(post.author!.level),
                                                  AppTheme.getLevelColor(post.author!.level)
                                                      .withValues(alpha: 0.7),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(r.s(10)),
                                            ),
                                            child: Text(
                                              'Lv.${post.author!.level}',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: r.fs(10),
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    SizedBox(height: r.s(2)),
                                    Text(
                                      timeago.format(post.createdAt, locale: 'pt_BR'),
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: r.fs(12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Botão Like no canto direito do header (estilo Amino)
                              GestureDetector(
                                onTap: _toggleLike,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: r.s(14), vertical: r.s(7)),
                                  decoration: BoxDecoration(
                                    color: post.isLiked
                                        ? AppTheme.errorColor.withValues(alpha: 0.12)
                                        : Colors.grey.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(r.s(20)),
                                    border: Border.all(
                                      color: post.isLiked
                                          ? AppTheme.errorColor.withValues(alpha: 0.4)
                                          : Colors.grey.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        post.isLiked
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        size: r.s(16),
                                        color: post.isLiked
                                            ? AppTheme.errorColor
                                            : Colors.grey[500],
                                      ),
                                      SizedBox(width: r.s(5)),
                                      Text(
                                        'Curtir',
                                        style: TextStyle(
                                          color: post.isLiked
                                              ? AppTheme.errorColor
                                              : Colors.grey[500],
                                          fontSize: r.fs(13),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ======================================================
                        // TAGS
                        // ======================================================
                        if (post.tags.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.fromLTRB(r.s(16), 0, r.s(16), r.s(8)),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: post.tags.map((tag) {
                                return GestureDetector(
                                  onTap: () => context.push('/search?q=%23$tag'),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: r.s(10), vertical: r.s(4)),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(r.s(12)),
                                      border: Border.all(
                                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      '#$tag',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: r.fs(12),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                        // ======================================================
                        // CONTEÚDO (Block Editor ou texto simples)
                        // ======================================================
                        if (post.hasBlockContent)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: r.s(8)),
                            child: BlockContentRenderer(
                              blocks: post.contentBlocks!,
                              backgroundUrl: post.backgroundUrl,
                            ),
                          )
                        else
                          Padding(
                            padding: EdgeInsets.fromLTRB(r.s(16), 0, r.s(16), r.s(16)),
                            child: Text(
                              post.content,
                              style: TextStyle(
                                fontSize: r.fs(15),
                                height: 1.7,
                                color: context.textPrimary,
                              ),
                            ),
                          ),

                        // ======================================================
                        // POLL / QUIZ / Q&A
                        // ======================================================
                        if (post.type == 'poll')
                          PollDetailWidget(
                            post: post,
                            onVoted: () => ref.invalidate(postDetailProvider(widget.postId)),
                          ),
                        if (post.type == 'quiz')
                          QuizDetailWidget(
                            post: post,
                            onCompleted: () => ref.invalidate(postDetailProvider(widget.postId)),
                          ),
                        if (post.type == 'qa')
                          _buildQAHeader(post),

                        // ======================================================
                        // MÍDIA
                        // ======================================================
                        if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: r.s(16), vertical: r.s(8)),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(r.s(12)),
                              child: CachedNetworkImage(
                                imageUrl: post.mediaUrl!,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),

                        // ======================================================
                        // VISUALIZAÇÕES
                        // ======================================================
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: r.s(16), vertical: r.s(4)),
                          child: Row(
                            children: [
                              Icon(Icons.visibility_outlined,
                                  size: r.s(14), color: Colors.grey[600]),
                              SizedBox(width: r.s(4)),
                              Text(
                                '${post.viewsCount} visualizações',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: r.fs(12)),
                              ),
                            ],
                          ),
                        ),

                        Divider(
                          color: Colors.grey.withValues(alpha: 0.15),
                          thickness: 1,
                          height: r.s(24),
                        ),

                        // ======================================================
                        // SEÇÃO DE COMENTÁRIOS — cabeçalho estilo Amino
                        // ======================================================
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: r.s(16), vertical: r.s(4)),
                          child: Row(
                            children: [
                              Text(
                                'Comentários',
                                style: TextStyle(
                                  fontSize: r.fs(15),
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const Spacer(),
                              Icon(Icons.tune_rounded,
                                  size: r.s(20), color: Colors.grey[500]),
                            ],
                          ),
                        ),

                        // Campo "Diga algo..." flat (estilo Amino)
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: r.s(16), vertical: r.s(8)),
                          child: Row(
                            children: [
                              CosmeticAvatar(
                                userId: SupabaseService.currentUserId ?? '',
                                avatarUrl: null,
                                size: r.s(36),
                              ),
                              SizedBox(width: r.s(10)),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _commentFocusNode.requestFocus(),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: r.s(14), vertical: r.s(10)),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(r.s(20)),
                                    ),
                                    child: Text(
                                      'Diga algo...',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: r.fs(14),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Lista de comentários
                        commentsAsync.when(
                          loading: () => Padding(
                            padding: EdgeInsets.all(r.s(32)),
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.primaryColor),
                              ),
                            ),
                          ),
                          error: (error, _) => Padding(
                            padding: EdgeInsets.all(r.s(16)),
                            child: Text(
                              'Erro ao carregar comentários. Tente novamente.',
                              style: const TextStyle(color: AppTheme.errorColor),
                            ),
                          ),
                          data: (comments) {
                            if (comments.isEmpty) {
                              return Padding(
                                padding: EdgeInsets.symmetric(vertical: r.s(32)),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.refresh_rounded,
                                          size: r.s(28), color: Colors.grey[400]),
                                      SizedBox(height: r.s(8)),
                                      Text(
                                        'Nenhum comentário',
                                        style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: r.fs(14)),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: comments.length,
                              itemBuilder: (context, index) => _CommentTile(
                                comment: comments[index],
                                communityId: post.communityId,
                                commentController: _commentController,
                                commentFocusNode: _commentFocusNode,
                              ),
                            );
                          },
                        ),

                        SizedBox(height: r.s(24)),
                      ],
                    ),
                  ),
                ),
              ),

              // ================================================================
              // CAMPO DE COMENTÁRIO (visível quando focado)
              // ================================================================
              AnimatedBuilder(
                animation: _commentFocusNode,
                builder: (context, child) {
                  if (!_commentFocusNode.hasFocus) return const SizedBox.shrink();
                  return Container(
                    padding: EdgeInsets.fromLTRB(r.s(16), r.s(8), r.s(16), r.s(8)),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      border: Border(
                        top: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
                      ),
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              focusNode: _commentFocusNode,
                              style: TextStyle(
                                  color: context.textPrimary, fontSize: r.fs(14)),
                              decoration: InputDecoration(
                                hintText: 'Escreva um comentário...',
                                hintStyle: TextStyle(color: Colors.grey[500]),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: r.s(4), vertical: r.s(8)),
                              ),
                              maxLines: 3,
                              minLines: 1,
                            ),
                          ),
                          SizedBox(width: r.s(8)),
                          GestureDetector(
                            onTap: _isSending ? null : _sendComment,
                            child: Container(
                              padding: EdgeInsets.all(r.s(10)),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: _isSending
                                  ? SizedBox(
                                      width: r.s(18),
                                      height: r.s(18),
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                      ),
                                    )
                                  : Icon(Icons.send_rounded,
                                      color: Colors.white, size: r.s(18)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // ================================================================
              // BARRA INFERIOR FIXA — estilo Amino (Share | Like | Save | Next)
              // ================================================================
              Container(
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  border: Border(
                    top: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      _BottomBarButton(
                        icon: Icons.share_outlined,
                        label: 'Compartilhar',
                        onTap: _sharePost,
                      ),
                      _BottomBarButton(
                        icon: post.isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        label: 'Curtir',
                        color: post.isLiked ? AppTheme.errorColor : null,
                        onTap: _toggleLike,
                      ),
                      _BottomBarButton(
                        icon: _isBookmarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        label: 'Salvar',
                        color: _isBookmarked ? AppTheme.primaryColor : null,
                        onTap: _toggleBookmark,
                      ),
                      _BottomBarButton(
                        icon: Icons.arrow_forward_rounded,
                        label: 'Próximo Post',
                        onTap: () {
                          // Navegar para o próximo post do feed
                          context.pop();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQAHeader(PostModel post) {
    final r = context.r;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
      padding: EdgeInsets.all(r.s(16)),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(r.s(14)),
        border: Border.all(color: const Color(0xFF3F51B5).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: r.s(40),
            height: r.s(40),
            decoration: BoxDecoration(
              color: const Color(0xFF3F51B5).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(r.s(10)),
            ),
            child: Center(
              child: Text('Q',
                  style: TextStyle(
                      color: const Color(0xFF3F51B5),
                      fontWeight: FontWeight.w800,
                      fontSize: r.fs(20))),
            ),
          ),
          SizedBox(width: r.s(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pergunta & Resposta',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: r.fs(14),
                        color: const Color(0xFF3F51B5))),
                const SizedBox(height: 2),
                Text(
                  'Responda nos comentários abaixo • ${post.commentsCount} respostas',
                  style: TextStyle(fontSize: r.fs(12), color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _commentFocusNode.requestFocus(),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(6)),
              decoration: BoxDecoration(
                color: const Color(0xFF3F51B5),
                borderRadius: BorderRadius.circular(r.s(20)),
              ),
              child: Text('Responder',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: r.fs(12),
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditPostDialog(PostModel post) {
    final r = context.r;
    final titleCtrl = TextEditingController(text: post.title ?? '');
    final contentCtrl = TextEditingController(text: post.content);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: r.s(16),
          right: r.s(16),
          top: r.s(20),
          bottom: MediaQuery.of(ctx).viewInsets.bottom + r.s(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Editar Post',
                    style: TextStyle(
                        fontSize: r.fs(18),
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: context.textSecondary),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            SizedBox(height: r.s(12)),
            TextField(
              controller: titleCtrl,
              style: TextStyle(
                  color: context.textPrimary,
                  fontSize: r.fs(15),
                  fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'Título',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: context.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(10)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: r.s(10)),
            TextField(
              controller: contentCtrl,
              style: TextStyle(color: context.textPrimary, fontSize: r.fs(14)),
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Conteúdo',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: context.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(10)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: r.s(16)),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.s(12)),
                  ),
                  padding: EdgeInsets.symmetric(vertical: r.s(14)),
                ),
                onPressed: () async {
                  try {
                    final trimmedTitle = titleCtrl.text.trim();
                    final trimmedContent = contentCtrl.text.trim();

                    await SupabaseService.rpc('edit_post', params: {
                      'p_post_id': widget.postId,
                      'p_title': trimmedTitle.isNotEmpty ? trimmedTitle : null,
                      'p_content': trimmedContent,
                    });

                    if (ctx.mounted) Navigator.pop(ctx);
                    ref.invalidate(postDetailProvider(widget.postId));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Post atualizado!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().contains('Post não encontrado ou sem permissão')
                                ? 'Você não tem permissão para editar este post.'
                                : 'Ocorreu um erro. Tente novamente.',
                          ),
                        ),
                      );
                    }
                  }
                },
                child: Text('Salvar Alterações',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: r.fs(15))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// BOTÃO DA BARRA INFERIOR
// =============================================================================
class _BottomBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _BottomBarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final effectiveColor = color ?? Colors.grey[600]!;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: r.s(10)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: r.s(22), color: effectiveColor),
              SizedBox(height: r.s(3)),
              Text(
                label,
                style: TextStyle(
                  fontSize: r.fs(10),
                  color: effectiveColor,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// TILE DE COMENTÁRIO — flat, sem card com borda (estilo Amino)
// =============================================================================
class _CommentTile extends StatefulWidget {
  final CommentModel comment;
  final String? communityId;
  final TextEditingController? commentController;
  final FocusNode? commentFocusNode;

  const _CommentTile({
    required this.comment,
    this.communityId,
    this.commentController,
    this.commentFocusNode,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  late bool _isLiked;
  late int _likesCount;

  @override
  void initState() {
    super.initState();
    _isLiked = false;
    _likesCount = widget.comment.likesCount;
    _checkIfLiked();
  }

  Future<void> _checkIfLiked() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      final res = await SupabaseService.table('likes')
          .select('id')
          .eq('user_id', userId)
          .eq('comment_id', widget.comment.id)
          .maybeSingle();
      if (mounted && res != null) setState(() => _isLiked = true);
    } catch (_) {}
  }

  Future<void> _toggleCommentLike() async {
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });
    try {
      await SupabaseService.rpc('toggle_like_with_reputation', params: {
        'p_community_id': widget.communityId,
        'p_user_id': SupabaseService.currentUserId,
        'p_comment_id': widget.comment.id,
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likesCount += _isLiked ? 1 : -1;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final comment = widget.comment;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CosmeticAvatar(
            userId: comment.authorId,
            avatarUrl: comment.author?.iconUrl,
            size: r.s(36),
            onTap: () => context.push('/user/${comment.authorId}'),
          ),
          SizedBox(width: r.s(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.author?.nickname ?? 'Usuário',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: r.fs(14),
                          color: context.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: r.s(8)),
                    Text(
                      timeago.format(comment.createdAt, locale: 'pt_BR'),
                      style: TextStyle(color: Colors.grey[500], fontSize: r.fs(11)),
                    ),
                  ],
                ),
                SizedBox(height: r.s(4)),
                Text(
                  comment.content,
                  style: TextStyle(
                    fontSize: r.fs(14),
                    height: 1.4,
                    color: context.textPrimary,
                  ),
                ),
                SizedBox(height: r.s(6)),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _toggleCommentLike,
                      child: Row(
                        children: [
                          Icon(
                            _isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: r.s(15),
                            color: _isLiked
                                ? const Color(0xFFEF4444)
                                : Colors.grey[500],
                          ),
                          SizedBox(width: r.s(4)),
                          Text(
                            '$_likesCount',
                            style: TextStyle(
                              color: _isLiked
                                  ? const Color(0xFFEF4444)
                                  : Colors.grey[500],
                              fontSize: r.fs(12),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: r.s(16)),
                    GestureDetector(
                      onTap: () {
                        final authorName =
                            widget.comment.author?.nickname ?? 'Usuário';
                        if (widget.commentController != null) {
                          widget.commentController!.text = '@$authorName ';
                          widget.commentController!.selection =
                              TextSelection.fromPosition(TextPosition(
                                  offset:
                                      widget.commentController!.text.length));
                        }
                        widget.commentFocusNode?.requestFocus();
                      },
                      child: Text(
                        'Responder',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: r.fs(12),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
