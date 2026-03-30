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
import '../widgets/block_content_renderer.dart';
import '../widgets/poll_quiz_widget.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../moderation/widgets/report_dialog.dart';
import '../../../core/utils/responsive.dart';

/// Provider para detalhes de um post.
final postDetailProvider =
    FutureProvider.family<PostModel, String>((ref, postId) async {
  final response = await SupabaseService.table('posts')
      .select('*, profiles!posts_author_id_fkey(*)')
      .eq('id', postId)
      .single();

  final map = Map<String, dynamic>.from(response);
  if (map['profiles'] != null) map['author'] = map['profiles'];
  return PostModel.fromJson(map);
});

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

/// Tela de detalhes de um post com comentários.
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

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isSending = true);
    try {
      // Buscar community_id do post para reputação
      final postData = ref.read(postDetailProvider(widget.postId)).valueOrNull;
      final communityId = postData?.communityId;

      await SupabaseService.rpc('create_comment_with_reputation', params: {
        'p_community_id': communityId,
        'p_author_id': SupabaseService.currentUserId,
        'p_content': _commentController.text.trim(),
        'p_post_id': widget.postId,
      });
      if (!mounted) return;
      _commentController.clear();
      ref.invalidate(postCommentsProvider(widget.postId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao comentar. Tente novamente.')),
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
    } catch (e) {
      // Silenciar erro
    }
  }

  bool _isBookmarked = false;

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
          'Post',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
          ),
        ),
        iconTheme: IconThemeData(color: context.textPrimary),
        actions: [
          IconButton(
            icon: Icon(
              _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: _isBookmarked ? AppTheme.primaryColor : null,
            ),
            onPressed: _toggleBookmark,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              // Share via deep link
              final link = 'https://nexushub.app/p/${widget.postId}';
              Clipboard.setData(ClipboardData(text: link));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Link copiado!'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
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
                          child: Text('Cancelar',
                              style: TextStyle(color: Colors.grey[500])),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Deletar',
                              style: TextStyle(
                                  color: AppTheme.errorColor,
                                  fontWeight: FontWeight.w700)),
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
                        if (!mounted) return;
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
                  Clipboard.setData(ClipboardData(
                      text: 'https://nexushub.app/p/${widget.postId}'));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Link copiado!'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
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
                  child: Row(
                    children: [
                      Icon(Icons.link_rounded, size: r.s(18), color: context.textSecondary),
                      SizedBox(width: r.s(10)),
                      Text('Copiar Link', style: TextStyle(color: context.textPrimary)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag_rounded, size: r.s(18), color: Colors.orange),
                      SizedBox(width: r.s(10)),
                      Text('Reportar', style: TextStyle(color: context.textPrimary)),
                    ],
                  ),
                ),
                if (isAuthor)
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: r.s(18), color: AppTheme.primaryColor),
                        SizedBox(width: r.s(10)),
                        Text('Editar', style: TextStyle(color: context.textPrimary)),
                      ],
                    ),
                  ),
                if (isAuthor)
                  PopupMenuItem(
                    value: 'pin_profile',
                    child: Row(
                      children: [
                        Icon(
                          (post?.isPinned == true)
                              ? Icons.push_pin_rounded
                              : Icons.push_pin_outlined,
                          size: r.s(18),
                          color: AppTheme.primaryColor,
                        ),
                        SizedBox(width: r.s(10)),
                        Text(
                          (post?.isPinned == true)
                              ? 'Desafixar do Perfil'
                              : 'Fixar no Perfil',
                          style: TextStyle(color: context.textPrimary),
                        ),
                      ],
                    ),
                  ),
                if (!isAuthor)
                  PopupMenuItem(
                    value: 'hide',
                    child: Row(
                      children: [
                        Icon(Icons.visibility_off_rounded, size: r.s(18), color: Colors.grey),
                        SizedBox(width: r.s(10)),
                        Text('Ocultar Post', style: TextStyle(color: context.textPrimary)),
                      ],
                    ),
                  ),
                if (isAuthor)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_rounded, size: r.s(18), color: AppTheme.errorColor),
                        SizedBox(width: r.s(10)),
                        Text('Deletar', style: TextStyle(color: AppTheme.errorColor)),
                      ],
                    ),
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
          child: Text(
            'Erro: $error',
            style: const TextStyle(color: AppTheme.errorColor),
          ),
        ),
        data: (post) => Column(
          children: [
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
                    // HEADER DO POST
                    // ======================================================
                    Padding(
                      padding: EdgeInsets.all(r.s(16)),
                      child: Row(
                        children: [
                          CosmeticAvatar(
                            userId: post.authorId,
                            avatarUrl: post.author?.iconUrl,
                            size: r.s(48),
                            onTap: () => context.push('/user/${post.authorId}'),
                          ),
                          SizedBox(width: r.s(12)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      post.author?.nickname ?? 'Usuário',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: context.textPrimary,
                                        fontSize: r.fs(16),
                                      ),
                                    ),
                                    if (post.author != null) ...[
                                      SizedBox(width: r.s(8)),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: r.s(8), vertical: 2),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppTheme.getLevelColor(post.author!.level),
                                              AppTheme.getLevelColor(post.author!.level).withValues(alpha: 0.7),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(r.s(12)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.getLevelColor(post.author!.level).withValues(alpha: 0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
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
                                SizedBox(height: r.s(4)),
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
                        ],
                      ),
                    ),

                    // ======================================================
                    // TÍTULO
                    // ======================================================
                    if (post.title != null && post.title!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: r.s(16)),
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
                    // TAGS
                    // ======================================================
                    if (post.tags.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.fromLTRB(r.s(16), r.s(8), r.s(16), r.s(4)),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: post.tags.map((tag) {
                            return GestureDetector(
                              onTap: () {
                                // Navegar para busca com tag
                                if (!mounted) return;
                                context.push('/search?q=%23$tag');
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: r.s(10), vertical: r.s(4)),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(r.s(12)),
                                  border: Border.all(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.3),
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
                        padding: EdgeInsets.symmetric(vertical: r.s(16)),
                        child: BlockContentRenderer(
                          blocks: post.contentBlocks!,
                          backgroundUrl: post.backgroundUrl,
                        ),
                      )
                    else
                      Padding(
                        padding: EdgeInsets.all(r.s(16)),
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
                        padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(r.s(16)),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(r.s(16)),
                            child: CachedNetworkImage(
                              imageUrl: post.mediaUrl!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),

                    // ======================================================
                    // AÇÕES
                    // ======================================================
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: r.s(8), vertical: r.s(8)),
                      child: Row(
                        children: [
                          TextButton.icon(
                            onPressed: _toggleLike,
                            style: TextButton.styleFrom(
                              foregroundColor: post.isLiked ? AppTheme.errorColor : Colors.grey[500],
                            ),
                            icon: Icon(
                              post.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            ),
                            label: Text(
                              '${post.likesCount}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              // Scroll para a seção de comentários
                              _commentFocusNode.requestFocus();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[500],
                            ),
                            icon: const Icon(Icons.chat_bubble_outline_rounded),
                            label: Text(
                              '${post.commentsCount}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Icon(Icons.visibility_outlined, size: r.s(16), color: Colors.grey[600]),
                              SizedBox(width: r.s(4)),
                              Text(
                                '${post.viewsCount}',
                                style: TextStyle(color: Colors.grey[600], fontSize: r.fs(12), fontWeight: FontWeight.w600),
                              ),
                              SizedBox(width: r.s(16)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Divider(color: Colors.white.withValues(alpha: 0.05), thickness: 1),

                    // ======================================================
                    // COMENTÁRIOS
                    // ======================================================
                    Padding(
                      padding: EdgeInsets.fromLTRB(r.s(16), r.s(16), r.s(16), r.s(8)),
                      child: Text(
                        'Comentários',
                        style: TextStyle(
                          fontSize: r.fs(18),
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                        ),
                      ),
                    ),

                    commentsAsync.when(
                      loading: () => Padding(
                        padding: EdgeInsets.all(r.s(32)),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
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
                            padding: EdgeInsets.all(r.s(32)),
                            child: Center(
                              child: Text(
                                'Nenhum comentário ainda. Seja o primeiro!',
                                style: TextStyle(color: Colors.grey[500]),
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

                    SizedBox(height: r.s(80)),
                  ],
                ),
              ),
              ),
            ),

            // ======================================================
            // INPUT DE COMENTÁRIO
            // ======================================================
            Container(
              padding: EdgeInsets.fromLTRB(r.s(16), r.s(12), r.s(16), r.s(12)),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.scaffoldBg,
                          borderRadius: BorderRadius.circular(r.s(24)),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: TextField(
                          controller: _commentController,
                          focusNode: _commentFocusNode,
                          style: TextStyle(color: context.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Escreva um comentário...',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(12)),
                          ),
                          maxLines: 3,
                          minLines: 1,
                        ),
                      ),
                    ),
                    SizedBox(width: r.s(12)),
                    GestureDetector(
                      onTap: _isSending ? null : _sendComment,
                      child: Container(
                        padding: EdgeInsets.all(r.s(12)),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryColor, AppTheme.accentColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _isSending
                            ? SizedBox(
                                width: r.s(20),
                                height: r.s(20),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: r.s(20),
                              ),
                      ),
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

  Widget _buildQAHeader(PostModel post) {
      final r = context.r;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
      padding: EdgeInsets.all(r.s(16)),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(r.s(14)),
        border: Border.all(
          color: const Color(0xFF3F51B5).withValues(alpha: 0.3),
        ),
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
                      color: Color(0xFF3F51B5),
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
                        color: Color(0xFF3F51B5))),
                const SizedBox(height: 2),
                Text(
                  'Responda nos coment\u00e1rios abaixo \u2022 ${post.commentsCount} respostas',
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

  // =========================================================================
  // EDITAR POST
  // =========================================================================
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
              style: TextStyle(color: context.textPrimary, fontSize: r.fs(15), fontWeight: FontWeight.w700),
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
                    await SupabaseService.table('posts').update({
                      'title': titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : null,
                      'content': contentCtrl.text.trim(),
                      'edited_at': DateTime.now().toIso8601String(),
                    }).eq('id', widget.postId);
                    if (ctx.mounted) Navigator.pop(ctx);
                    ref.invalidate(postDetailProvider(widget.postId));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Post atualizado!'), behavior: SnackBarBehavior.floating),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Ocorreu um erro. Tente novamente.')),
                      );
                    }
                  }
                },
                child: Text('Salvar Alterações',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: r.fs(15))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
      padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(10)),
      child: Container(
        padding: EdgeInsets.all(r.s(12)),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(r.s(16)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CosmeticAvatar(
              userId: comment.authorId,
              avatarUrl: comment.author?.iconUrl,
              size: r.s(36),
              onTap: () => context.push('/user/${comment.authorId}'),
            ),
            SizedBox(width: r.s(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        comment.author?.nickname ?? 'Usuário',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: r.fs(14),
                          color: context.textPrimary,
                        ),
                      ),
                      SizedBox(width: r.s(8)),
                      Text(
                        timeago.format(comment.createdAt, locale: 'pt_BR'),
                        style: TextStyle(color: Colors.grey[600], fontSize: r.fs(11)),
                      ),
                    ],
                  ),
                  SizedBox(height: r.s(6)),
                  Text(
                    comment.content,
                    style: TextStyle(
                      fontSize: r.fs(14),
                      height: 1.4,
                      color: context.textPrimary,
                    ),
                  ),
                  SizedBox(height: r.s(8)),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _toggleCommentLike,
                        child: Row(
                          children: [
                            Icon(
                              _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: r.s(16),
                              color: _isLiked ? const Color(0xFFEF4444) : Colors.grey[500],
                            ),
                            SizedBox(width: r.s(4)),
                            Text(
                              '$_likesCount',
                              style: TextStyle(
                                color: _isLiked ? const Color(0xFFEF4444) : Colors.grey[500],
                                fontSize: r.fs(12),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: r.s(20)),
                      GestureDetector(
                        onTap: () {
                          // Focar no campo de comentário com @mention
                          final authorName = widget.comment.author?.nickname ?? 'Usuário';
                          if (widget.commentController != null) {
                            widget.commentController!.text = '@$authorName ';
                            widget.commentController!.selection = TextSelection.fromPosition(
                              TextPosition(offset: widget.commentController!.text.length),
                            );
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
      ),
    );
  }
}