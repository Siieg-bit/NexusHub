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
      .eq('is_hidden', false)
      .order('created_at', ascending: true);

  return (response as List)
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
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(postDetailProvider(widget.postId));
    final commentsAsync = ref.watch(postCommentsProvider(widget.postId));

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Post',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
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
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: AppTheme.surfaceColor,
                                backgroundImage: post.author?.iconUrl != null
                                    ? CachedNetworkImageProvider(post.author!.iconUrl!)
                                    : null,
                                child: post.author?.iconUrl == null
                                    ? Text(
                                        (post.author?.nickname ?? '?')[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      post.author?.nickname ?? 'Usuário',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (post.author != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              AppTheme.getLevelColor(post.author!.level),
                                              AppTheme.getLevelColor(post.author!.level).withValues(alpha: 0.7),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
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
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  timeago.format(post.createdAt, locale: 'pt_BR'),
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
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
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          post.title!,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),

                    // ======================================================
                    // CONTEÚDO (Block Editor ou texto simples)
                    // ======================================================
                    if (post.hasBlockContent)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: BlockContentRenderer(
                          blocks: post.contentBlocks!,
                          backgroundUrl: post.backgroundUrl,
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          post.content,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.7,
                            color: AppTheme.textPrimary,
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
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
                            borderRadius: BorderRadius.circular(16),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                              Icon(Icons.visibility_outlined, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                '${post.viewsCount}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 16),
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: const Text(
                        'Comentários',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),

                    commentsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                          ),
                        ),
                      ),
                      error: (error, _) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Erro ao carregar comentários: $error',
                          style: const TextStyle(color: AppTheme.errorColor),
                        ),
                      ),
                      data: (comments) {
                        if (comments.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(32),
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

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),

            // ======================================================
            // INPUT DE COMENTÁRIO
            // ======================================================
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
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
                          color: AppTheme.scaffoldBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: TextField(
                          controller: _commentController,
                          focusNode: _commentFocusNode,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Escreva um comentário...',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          maxLines: 3,
                          minLines: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _isSending ? null : _sendComment,
                      child: Container(
                        padding: const EdgeInsets.all(12),
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
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 20,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF3F51B5).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF3F51B5).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text('Q',
                  style: TextStyle(
                      color: Color(0xFF3F51B5),
                      fontWeight: FontWeight.w800,
                      fontSize: 20)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pergunta & Resposta',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF3F51B5))),
                const SizedBox(height: 2),
                Text(
                  'Responda nos coment\u00e1rios abaixo \u2022 ${post.commentsCount} respostas',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _commentFocusNode.requestFocus(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF3F51B5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Responder',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
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
    final comment = widget.comment;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => context.push('/user/${comment.authorId}'),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                backgroundImage: comment.author?.iconUrl != null
                    ? CachedNetworkImageProvider(comment.author!.iconUrl!)
                    : null,
                child: comment.author?.iconUrl == null
                    ? Text(
                        (comment.author?.nickname ?? '?')[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w800,
                        ),
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
                      Text(
                        comment.author?.nickname ?? 'Usuário',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeago.format(comment.createdAt, locale: 'pt_BR'),
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    comment.content,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _toggleCommentLike,
                        child: Row(
                          children: [
                            Icon(
                              _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              size: 16,
                              color: _isLiked ? const Color(0xFFEF4444) : Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$_likesCount',
                              style: TextStyle(
                                color: _isLiked ? const Color(0xFFEF4444) : Colors.grey[500],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      GestureDetector(
                        onTap: () {
                          // Focar no campo de comentário com @mention
                          final authorName = widget.comment.author?['nickname'] ?? 'Usuário';
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
                            fontSize: 12,
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