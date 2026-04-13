import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
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
import '../../moderation/widgets/post_moderation_menu.dart';
import '../../stickers/stickers.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/services/deep_link_service.dart';
import '../../../core/widgets/image_viewer.dart';
import '../../../core/widgets/comment_media_menu_button.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

enum _CommentSortOrder { mostRecent, oldest, mostPopular }

/// Provider para comentários de um post.
/// Recebe um Record (postId, communityId) para poder enriquecer os comentários
/// com os dados do perfil local de comunidade (local_nickname, local_icon_url).
final postCommentsProvider =
    FutureProvider.family<List<CommentModel>, (String, String)>(
        (ref, args) async {
  final (postId, communityId) = args;

  final response = await SupabaseService.table('comments')
      .select(
        '*, profiles!comments_author_id_fkey(id, nickname, icon_url, amino_id)',
      )
      .eq('post_id', postId)
      .eq('status', 'ok')
      .order('created_at', ascending: true);

  final maps = List<Map<String, dynamic>>.from(
    (response as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
  );

  // Enriquecer com dados do perfil local de comunidade quando disponível.
  if (communityId.isNotEmpty && maps.isNotEmpty) {
    try {
      final authorIds = maps
          .map((m) => m['author_id'] as String?)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (authorIds.isNotEmpty) {
        final memberships = await SupabaseService.table('community_members')
            .select('user_id, local_nickname, local_icon_url')
            .eq('community_id', communityId)
            .inFilter('user_id', authorIds);

        final memberMap = <String, Map<String, dynamic>>{
          for (final row in (memberships as List? ?? []))
            (row['user_id'] as String): Map<String, dynamic>.from(row as Map),
        };

        for (final map in maps) {
          final authorId = map['author_id'] as String?;
          if (authorId == null) continue;
          final membership = memberMap[authorId];
          if (membership == null) continue;
          final localNickname =
              (membership['local_nickname'] as String?)?.trim();
          final localIconUrl =
              (membership['local_icon_url'] as String?)?.trim();
          if (localNickname != null && localNickname.isNotEmpty) {
            map['local_nickname'] = localNickname;
          }
          if (localIconUrl != null && localIconUrl.isNotEmpty) {
            map['local_icon_url'] = localIconUrl;
          }
        }
      }
    } catch (e) {
      debugPrint('[postCommentsProvider] enrich error: $e');
    }
  }

  return maps.map((e) => CommentModel.fromJson(e)).toList();
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
  _CommentSortOrder _commentSortOrder = _CommentSortOrder.oldest;
  // communityId do post — preenchido quando o postDetailProvider carrega.
  // Usado para enriquecer os comentários com dados locais de comunidade.
  String _postCommunityId = '';
  // Cache do role do usuário na comunidade atual
  String? _cachedCommunityId;
  String? _cachedUserRole;

  bool _isStaffOf(String communityId) {
    const staffRoles = ['agent', 'leader', 'curator', 'moderator'];
    return staffRoles.contains(_cachedUserRole);
  }

  Future<void> _loadUserRole(String communityId) async {
    if (_cachedCommunityId == communityId) return;
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final row = await SupabaseService.table('community_members')
          .select('role')
          .eq('community_id', communityId)
          .eq('user_id', userId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _cachedCommunityId = communityId;
          _cachedUserRole = row?['role'] as String?;
        });
      }
    } catch (_) {}
  }
  CommentModel? _replyingToComment;
  String? _pendingStickerUrl;
  String? _pendingMediaUrl;
  bool _showEmojiPicker = false;
  String? _pendingVideoUrl;

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
          .update({'views_count': current + 1}).eq('id', widget.postId);
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

  void _focusCommentComposer({CommentModel? replyTo}) {
    final s = getStrings();
    if (replyTo != null) {
      final authorName = replyTo.author?.nickname ?? s.user;
      final prefix = '@$authorName ';
      if (_replyingToComment?.id != replyTo.id ||
          !_commentController.text.startsWith(prefix)) {
        _commentController.text = prefix;
        _commentController.selection = TextSelection.fromPosition(
          TextPosition(offset: _commentController.text.length),
        );
      }
      setState(() => _replyingToComment = replyTo);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _commentFocusNode.requestFocus();
    });
  }

  void _clearReplyTarget() {
    if (_replyingToComment == null) return;
    setState(() => _replyingToComment = null);
  }

  int _compareComments(CommentModel a, CommentModel b) {
    switch (_commentSortOrder) {
      case _CommentSortOrder.mostRecent:
        return b.createdAt.compareTo(a.createdAt);
      case _CommentSortOrder.mostPopular:
        final popularity = b.likesCount.compareTo(a.likesCount);
        if (popularity != 0) return popularity;
        final replyCount = b.replies.length.compareTo(a.replies.length);
        if (replyCount != 0) return replyCount;
        return b.createdAt.compareTo(a.createdAt);
      case _CommentSortOrder.oldest:
        return a.createdAt.compareTo(b.createdAt);
    }
  }

  CommentModel _copyCommentWithSortedReplies(CommentModel comment) {
    final replies = comment.replies
        .map(_copyCommentWithSortedReplies)
        .toList()
      ..sort(_compareComments);

    return CommentModel(
      id: comment.id,
      authorId: comment.authorId,
      postId: comment.postId,
      wikiId: comment.wikiId,
      profileWallId: comment.profileWallId,
      parentId: comment.parentId,
      content: comment.content,
      mediaUrl: comment.mediaUrl,
      stickerId: comment.stickerId,
      stickerUrl: comment.stickerUrl,
      stickerName: comment.stickerName,
      packId: comment.packId,
      likesCount: comment.likesCount,
      status: comment.status,
      createdAt: comment.createdAt,
      updatedAt: comment.updatedAt,
      author: comment.author,
      replies: replies,
      localNickname: comment.localNickname,
      localIconUrl: comment.localIconUrl,
    );
  }

  List<CommentModel> _buildCommentTree(List<CommentModel> comments) {
    final repliesByParent = <String, List<CommentModel>>{};
    final rootComments = <CommentModel>[];

    for (final comment in comments) {
      final parentId = comment.parentId;
      if (parentId == null || parentId.isEmpty) {
        rootComments.add(comment);
      } else {
        repliesByParent.putIfAbsent(parentId, () => []).add(comment);
      }
    }

    CommentModel attachReplies(CommentModel comment) {
      final replies = [...(repliesByParent[comment.id] ?? const <CommentModel>[])];
      replies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return CommentModel(
        id: comment.id,
        authorId: comment.authorId,
        postId: comment.postId,
        wikiId: comment.wikiId,
        profileWallId: comment.profileWallId,
        parentId: comment.parentId,
        content: comment.content,
        mediaUrl: comment.mediaUrl,
        stickerId: comment.stickerId,
        stickerUrl: comment.stickerUrl,
        stickerName: comment.stickerName,
        packId: comment.packId,
        likesCount: comment.likesCount,
        status: comment.status,
        createdAt: comment.createdAt,
        updatedAt: comment.updatedAt,
        author: comment.author,
        replies: replies.map(attachReplies).toList(),
        localNickname: comment.localNickname,
        localIconUrl: comment.localIconUrl,
      );
    }

    final threadedComments = rootComments.map(attachReplies).toList()
      ..sort(_compareComments);

    return threadedComments.map(_copyCommentWithSortedReplies).toList();
  }

  Future<void> _deleteComment(CommentModel comment) async {
    final r = context.r;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r.s(16)),
        ),
        title: Text(
          'Excluir comentário',
          style: TextStyle(
            color: context.nexusTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Deseja excluir este comentário? Esta ação não pode ser desfeita.',
          style: TextStyle(color: context.nexusTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[500])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Excluir',
              style: TextStyle(
                color: context.nexusTheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupabaseService.table('comments').delete().eq('id', comment.id);
      if (_replyingToComment?.id == comment.id) {
        _commentController.clear();
        _clearReplyTarget();
      }
      ref.invalidate(postCommentsProvider((widget.postId, _postCommunityId)));
      ref.invalidate(postDetailProvider(widget.postId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Comentário excluído.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: context.surfaceColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível excluir o comentário.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: context.nexusTheme.error,
        ),
      );
    }
  }

  Future<void> _sendComment({
    String? stickerUrl,
    String? stickerId,
    String? stickerName,
    String? packId,
  }) async {
    final s = getStrings();
    final textContent = _commentController.text.trim();
    final mediaUrl = stickerUrl ?? _pendingStickerUrl ?? _pendingMediaUrl;
    final isSticker = stickerId != null || stickerUrl != null;

    // Precisa ter texto ou mídia
    if (textContent.isEmpty && mediaUrl == null) return;

    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(s.needLoginToComment)),
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
        } catch (e) {
          debugPrint('[post_detail_screen.dart] $e');
        }
      }

      // Sticker: usar RPC dedicado com suporte a sticker_id, sticker_url, pack_id
      if (isSticker) {
        await SupabaseService.rpc('send_comment_with_sticker', params: {
          'p_post_id': widget.postId,
          'p_content': textContent.isNotEmpty ? textContent : '',
          'p_parent_id': _replyingToComment?.id,
          'p_sticker_id': stickerId,
          'p_sticker_url': stickerUrl,
          'p_sticker_name': stickerName,
          'p_pack_id': packId,
        });
      } else if (mediaUrl != null) {
        // Imagem ou vídeo
        final isVideo = _pendingVideoUrl != null;
        await SupabaseService.table('comments').insert({
          'post_id': widget.postId,
          'author_id': userId,
          'content': textContent.isNotEmpty ? textContent : (isVideo ? '[video]' : '[image]'),
          'media_url': mediaUrl,
          'media_type': isVideo ? 'video' : 'image',
          'parent_id': _replyingToComment?.id,
        });
      } else {
        await SupabaseService.rpc('create_comment_with_reputation', params: {
          'p_community_id': communityId,
          'p_author_id': userId,
          'p_content': textContent,
          'p_post_id': widget.postId,
          'p_parent_id': _replyingToComment?.id,
        });
      }

      if (!mounted) return;
      _commentController.clear();
      _commentFocusNode.unfocus();
      _clearReplyTarget();
      setState(() {
        _pendingStickerUrl = null;
        _pendingMediaUrl = null;
        _pendingVideoUrl = null;
        _showEmojiPicker = false;
      });
      ref.invalidate(postCommentsProvider((widget.postId, _postCommunityId)));
      ref.invalidate(postDetailProvider(widget.postId));
    } catch (e) {
      debugPrint('[NexusHub] Erro ao comentar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Erro ao comentar: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickCommentImage() async {
    final s = getStrings();
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final path = 'comments/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final rawBytes = await image.readAsBytes();
      final bytes = await MediaUtils.compressImage(rawBytes);

      await SupabaseService.storage.from('post_media').uploadBinary(path, bytes);
      if (!mounted) return;

      final url = SupabaseService.storage.from('post_media').getPublicUrl(path);
      if (!mounted) return;
      setState(() => _pendingMediaUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorUploadTryAgain),
            backgroundColor: context.nexusTheme.error,
          ),
        );
      }
    }
  }

  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
      if (_showEmojiPicker) _commentFocusNode.unfocus();
    });
  }

  Future<void> _openStickerPicker() async {
    if (!mounted) return;
    setState(() => _showEmojiPicker = false);
    await StickerPickerV2.show(
      context,
      onStickerSelected: (sticker) {
        _sendComment(
          stickerUrl: sticker.imageUrl,
          stickerId: sticker.id,
          stickerName: sticker.name,
          packId: sticker.packId.isNotEmpty ? sticker.packId : null,
        );
      },
    );
  }

  Future<void> _toggleLike() async {
    final postData = ref.read(postDetailProvider(widget.postId)).valueOrNull;
    final currentUserId = SupabaseService.currentUserId;
    final params = {
      'p_community_id': postData?.communityId,
      'p_user_id': currentUserId,
      'p_post_id': widget.postId,
    };

    debugPrint(
      '[post_detail_screen][like] start postId=${widget.postId} '
      'communityId=${postData?.communityId} userId=$currentUserId '
      'isLiked=${postData?.isLiked} likesCount=${postData?.likesCount}',
    );

    try {
      final result = await SupabaseService.rpc(
        'toggle_like_with_reputation',
        params: params,
      );
      debugPrint(
        '[post_detail_screen][like] success postId=${widget.postId} '
        'result=$result',
      );
      ref.invalidate(postDetailProvider(widget.postId));
      debugPrint(
        '[post_detail_screen][like] invalidated postDetailProvider '
        'postId=${widget.postId}',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[post_detail_screen][like] error postId=${widget.postId} '
        'params=$params error=$e',
      );
      debugPrint('[post_detail_screen][like] stackTrace=$stackTrace');
    }
  }

  Future<void> _toggleBookmark() async {
    final s = getStrings();
    try {
      final result = await SupabaseService.rpc('toggle_bookmark', params: {
        'p_user_id': SupabaseService.currentUserId,
        'p_post_id': widget.postId,
      });
      if (mounted) {
        final bookmarked =
            (result as Map<String, dynamic>?)?['bookmarked'] == true;
        setState(() => _isBookmarked = bookmarked);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(bookmarked ? 'Post salvo!' : 'Post removido dos salvos'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.anErrorOccurredTryAgain)),
        );
      }
    }
  }

  // ── REPOST ──
  Future<void> _doRepost(PostModel post) async {
    final s = ref.read(stringsProvider);
    final currentUserId = SupabaseService.currentUserId;
    debugPrint(
      '[post_detail_screen][repost] start postId=${post.id} '
      'communityId=${post.communityId} authorId=${post.authorId} '
      'currentUserId=$currentUserId type=${post.type}',
    );
    if (currentUserId == null) {
      debugPrint('[post_detail_screen][repost] aborted: currentUserId is null');
      return;
    }

    if (post.authorId == currentUserId) {
      debugPrint('[post_detail_screen][repost] aborted: own post postId=${post.id}');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Não é possível republicar seu próprio post.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: context.nexusTheme.error,
      ));
      return;
    }

    if (post.type == 'repost') {
      debugPrint('[post_detail_screen][repost] aborted: post already is repost postId=${post.id}');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Não é possível republicar um repost.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: context.nexusTheme.error,
      ));
      return;
    }

    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _RepostConfirmSheetDetail(post: post),
    );

    debugPrint('[post_detail_screen][repost] confirmResult=$confirm postId=${post.id}');
    if (confirm != true || !mounted) {
      debugPrint(
        '[post_detail_screen][repost] aborted after confirmation '
        'confirm=$confirm mounted=$mounted postId=${post.id}',
      );
      return;
    }

    final params = {
      'p_original_post_id': post.id,
      'p_community_id': post.communityId,
    };

    try {
      final result = await SupabaseService.rpc('repost_post', params: params);
      debugPrint(
        '[post_detail_screen][repost] success postId=${post.id} result=$result',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.repostSuccess),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF4CAF50),
        ));
      }
    } catch (e, stackTrace) {
      debugPrint(
        '[post_detail_screen][repost] error postId=${post.id} '
        'params=$params error=$e',
      );
      debugPrint('[post_detail_screen][repost] stackTrace=$stackTrace');
      if (!mounted) return;
      final msg = e.toString();
      final isAlreadyReposted = msg.contains('já republicou');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isAlreadyReposted ? s.repostAlreadyExists : s.anErrorOccurredTryAgain),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isAlreadyReposted ? context.nexusTheme.warning : context.nexusTheme.error,
      ));
    }
  }

  Future<void> _sharePost() async {
    final s = getStrings();
    await DeepLinkService.shareUrl(
      type: 'post',
      targetId: widget.postId,
      title: s.sharePost,
      text: s.sharePost,
    );
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final postAsync = ref.watch(postDetailProvider(widget.postId));
     final post = postAsync.valueOrNull;
    // Atualizar _postCommunityId quando o post carregar (sem setState para evitar rebuild).
    if (post != null && post.communityId.isNotEmpty && _postCommunityId != post.communityId) {
      _postCommunityId = post.communityId;
    }
    final commentsAsync = ref.watch(postCommentsProvider((widget.postId, _postCommunityId)));
    final currentUser = ref.watch(currentUserProvider);
    // Avatar reativo do usuário logado (já considera local_icon_url via authProvider)
    final currentUserAvatar = ref.watch(currentUserAvatarProvider);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: context.nexusTheme.backgroundPrimary,
      // Barra Share/Like/Save/Next fora do body para não ser afetada pelo teclado
      bottomNavigationBar: post == null
          ? null
          : Container(
              decoration: BoxDecoration(
                color: context.surfaceColor,
                border: Border(
                  top: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    _BottomBarButton(
                      icon: Icons.share_outlined,
                      label: s.share,
                      onTap: _sharePost,
                    ),
                    _BottomBarButton(
                      icon: post.isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      label: s.like,
                      color: post.isLiked ? context.nexusTheme.error : null,
                      onTap: _toggleLike,
                    ),
                    _BottomBarButton(
                      icon: _isBookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      label: s.save,
                      color: _isBookmarked ? context.nexusTheme.accentPrimary : null,
                      onTap: _toggleBookmark,
                    ),
                    _BottomBarButton(
                      icon: Icons.arrow_forward_rounded,
                      label: s.nextPost,
                      onTap: () {
                        context.pop();
                      },
                    ),
                  ],
                ),
              ),
            ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          postAsync.valueOrNull?.type == 'blog' ? s.blog : s.post,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: context.nexusTheme.textPrimary,
          ),
        ),
        iconTheme: IconThemeData(color: context.nexusTheme.textPrimary),
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
              final post =
                  ref.read(postDetailProvider(widget.postId)).valueOrNull;
              if (post == null) return;
              switch (value) {
                case 'moderation_menu':
                  final changed = await showPostModerationMenu(
                    context: context,
                    ref: ref,
                    communityId: post.communityId,
                    postId: widget.postId,
                    isPinned: post.isPinned,
                    isFeatured: post.isFeatured,
                    postTitle: post.title ?? '',
                  );
                  if (changed == true && mounted) {
                    ref.invalidate(postDetailProvider(widget.postId));
                  }
                  break;
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
                      title: Text(s.deletePost2,
                          style: TextStyle(
                              color: context.nexusTheme.textPrimary,
                              fontWeight: FontWeight.w700)),
                      content: Text(
                        s.confirmDeletePost,
                        style: TextStyle(color: context.nexusTheme.textSecondary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(s.cancel,
                              style: TextStyle(color: Colors.grey[500])),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(s.deleteAction2,
                              style: TextStyle(
                                  color: context.nexusTheme.error,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && mounted) {
                    try {
                      await SupabaseService.table('posts').update(
                          {'status': 'deleted'}).eq('id', widget.postId);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(
                            content: Text(s.postDeleted2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        context.pop();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text(s.anErrorOccurredTryAgain)),
                        );
                      }
                    }
                  }
                  break;
                case 'repost':
                  _doRepost(post);
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
                        .update({'is_pinned_profile': !isPinned}).eq(
                            'id', widget.postId);
                    if (!mounted) return;
                    ref.invalidate(postDetailProvider(widget.postId));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(isPinned
                            ? 'Post desafixado do perfil'
                            : 'Post fixado no perfil'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ));
                    }
                  } catch (e) {
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(s.anErrorOccurredTryAgain)));
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
                        ScaffoldMessenger.of(context)
                            .showSnackBar( SnackBar(
                          content: Text(s.postHiddenFromFeed),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ));
                        context.pop();
                      }
                    }
                  } catch (e) {
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(s.anErrorOccurredTryAgain)));
                  }
                  break;
              }
            },
            itemBuilder: (context) {
              final post =
                  ref.read(postDetailProvider(widget.postId)).valueOrNull;
              final isAuthor = post?.authorId == SupabaseService.currentUserId;
              // Carregar role se necessário
              if (post != null) _loadUserRole(post.communityId);
              return [
                if (!isAuthor && post?.type != 'repost')
                  PopupMenuItem(
                    value: 'repost',
                    child: Row(children: [
                      Icon(Icons.repeat_rounded,
                          size: r.s(18), color: const Color(0xFF607D8B)),
                      SizedBox(width: r.s(10)),
                      Text(s.repostAction,
                          style: TextStyle(color: context.nexusTheme.textPrimary)),
                    ]),
                  ),
                PopupMenuItem(
                  value: 'copy_link',
                  child: Row(children: [
                    Icon(Icons.link_rounded,
                        size: r.s(18), color: context.nexusTheme.textSecondary),
                    SizedBox(width: r.s(10)),
                    Text(s.copyLink,
                        style: TextStyle(color: context.nexusTheme.textPrimary)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'report',
                  child: Row(children: [
                    Icon(Icons.flag_rounded,
                        size: r.s(18), color: Colors.orange),
                    SizedBox(width: r.s(10)),
                    Text(s.reportAction,
                        style: TextStyle(color: context.nexusTheme.textPrimary)),
                  ]),
                ),
                if (isAuthor)
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_rounded,
                          size: r.s(18), color: context.nexusTheme.accentPrimary),
                      SizedBox(width: r.s(10)),
                      Text(s.edit,
                          style: TextStyle(color: context.nexusTheme.textPrimary)),
                    ]),
                  ),
                if (isAuthor)
                  PopupMenuItem(
                    value: 'pin_profile',
                    child: Row(children: [
                      Icon(
                        (post?.isPinned == true)
                            ? Icons.push_pin_rounded
                            : Icons.push_pin_outlined,
                        size: r.s(18),
                        color: context.nexusTheme.accentPrimary,
                      ),
                      SizedBox(width: r.s(10)),
                      Text(
                        (post?.isPinned == true)
                            ? 'Desafixar do Perfil'
                            : 'Fixar no Perfil',
                        style: TextStyle(color: context.nexusTheme.textPrimary),
                      ),
                    ]),
                  ),
                if (!isAuthor)
                  PopupMenuItem(
                    value: 'hide',
                    child: Row(children: [
                      Icon(Icons.visibility_off_rounded,
                          size: r.s(18), color: Colors.grey),
                      SizedBox(width: r.s(10)),
                      Text(s.hidePost,
                          style: TextStyle(color: context.nexusTheme.textPrimary)),
                    ]),
                  ),
                if (isAuthor)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_rounded,
                          size: r.s(18), color: context.nexusTheme.error),
                      SizedBox(width: r.s(10)),
                      Text(s.deleteAction2,
                          style: TextStyle(color: context.nexusTheme.error)),
                    ]),
                  ),
                // Menu de Moderação — visível apenas para staff
                if (post != null && _isStaffOf(post.communityId))
                  PopupMenuItem(
                    value: 'moderation_menu',
                    child: Row(children: [
                      Icon(Icons.admin_panel_settings_rounded,
                          size: r.s(18), color: context.nexusTheme.accentPrimary),
                      SizedBox(width: r.s(10)),
                      Text('Menu de Moderação',
                          style: TextStyle(color: context.nexusTheme.textPrimary)),
                    ]),
                  ),
              ];
            },
          ),
        ],
      ),
      body: postAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(context.nexusTheme.accentPrimary),
          ),
        ),
        error: (error, _) => Center(
          child: Text(s.errorGeneric(error.toString()),
              style: TextStyle(color: context.nexusTheme.error)),
        ),
        data: (post) {
          if (post == null) {
            return Center(
              child: Text(s.postNotFoundMsg,
                  style: TextStyle(color: context.nexusTheme.textSecondary)),
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
                  color: context.nexusTheme.accentPrimary,
                  onRefresh: () async {
                    ref.invalidate(postDetailProvider);
                    ref.invalidate(postCommentsProvider((widget.postId, _postCommunityId)));
                    await Future.delayed(const Duration(milliseconds: 300));
                    if (!mounted) return;
                  },
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ======================================================
                        // TÍTULO (oculto para reposts — título fica no card aninhado)
                        // ======================================================
                        if (post.type != 'repost' &&
                            post.title != null &&
                            post.title!.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                                r.s(16), r.s(16), r.s(16), r.s(4)),
                            child: Text(
                              post.title!,
                              style: TextStyle(
                                fontSize: r.fs(22),
                                fontWeight: FontWeight.w800,
                                color: context.nexusTheme.textPrimary,
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
                                avatarUrl:
                                    post.authorLocalIconUrl?.trim().isNotEmpty ==
                                            true
                                        ? post.authorLocalIconUrl!.trim()
                                        : post.author?.iconUrl,
                                size: r.s(40),
                                onTap: () => context.push(
                                  '/community/${post.communityId}/profile/${post.authorId}',
                                ),
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
                                            post.authorLocalNickname
                                                        ?.trim()
                                                        .isNotEmpty ==
                                                    true
                                                ? post.authorLocalNickname!.trim()
                                                : (post.author?.nickname ?? s.user),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: context.nexusTheme.textPrimary,
                                              fontSize: r.fs(15),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (post.author != null && (post.authorLocalLevel ?? 0) > 0) ...[
                                          SizedBox(width: r.s(6)),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: r.s(7),
                                                vertical: 2),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  AppTheme.getLevelColor(
                                                      post.authorLocalLevel ?? 0),
                                                  AppTheme.getLevelColor(
                                                          post.authorLocalLevel ?? 0)
                                                      .withValues(alpha: 0.7),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      r.s(10)),
                                            ),
                                            child: Text(
                                              s.lvBadge(post.authorLocalLevel ?? 0),
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
                                      timeago.format(post.createdAt,
                                          locale: 'pt_BR'),
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
                                        ? context.nexusTheme.error
                                            .withValues(alpha: 0.12)
                                        : Colors.grey.withValues(alpha: 0.12),
                                    borderRadius:
                                        BorderRadius.circular(r.s(20)),
                                    border: Border.all(
                                      color: post.isLiked
                                          ? context.nexusTheme.error
                                              .withValues(alpha: 0.4)
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
                                            ? context.nexusTheme.error
                                            : Colors.grey[500],
                                      ),
                                      SizedBox(width: r.s(5)),
                                      Text(
                                        s.like,
                                        style: TextStyle(
                                          color: post.isLiked
                                              ? context.nexusTheme.error
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
                            padding: EdgeInsets.fromLTRB(
                                r.s(16), 0, r.s(16), r.s(8)),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: post.tags.map((tag) {
                                return GestureDetector(
                                  onTap: () =>
                                      context.push('/search?q=%23$tag'),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: r.s(10), vertical: r.s(4)),
                                    decoration: BoxDecoration(
                                      color: context.nexusTheme.accentPrimary
                                          .withValues(alpha: 0.15),
                                      borderRadius:
                                          BorderRadius.circular(r.s(12)),
                                      border: Border.all(
                                        color: context.nexusTheme.accentPrimary
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      '#$tag',
                                      style: TextStyle(
                                        color: context.nexusTheme.accentPrimary,
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
                        // REPOST — Card do post original (estilo Twitter)
                        // ======================================================
                        if (post.type == 'repost')
                          _buildOriginalPostCard(post, r, s),
                        // ======================================================
                        // CONTEÚDO (Block Editor ou texto simples)
                        // Oculto para reposts — conteúdo fica no card aninhado
                        // ======================================================
                        if (post.type != 'repost' && post.hasBlockContent)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: r.s(8)),
                            child: BlockContentRenderer(
                              blocks: post.contentBlocks!,
                              backgroundUrl: post.backgroundUrl,
                            ),
                          )
                        else if (post.type != 'repost')
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                                r.s(16), 0, r.s(16), r.s(16)),
                            child: Text(
                              post.content,
                              style: TextStyle(
                                fontSize: r.fs(15),
                                height: 1.7,
                                color: context.nexusTheme.textPrimary,
                              ),
                            ),
                          ),

                        // ======================================================
                        // POLL / QUIZ / Q&A
                        // ======================================================
                        if (post.type == 'poll')
                          PollDetailWidget(
                            post: post,
                            onVoted: () => ref
                                .invalidate(postDetailProvider(widget.postId)),
                          ),
                        if (post.type == 'quiz')
                          QuizDetailWidget(
                            post: post,
                            onCompleted: () => ref
                                .invalidate(postDetailProvider(widget.postId)),
                          ),
                        if (post.type == 'qa') _buildQAHeader(post),

                        // ======================================================
                        // MÍDIA
                        // ======================================================
                        if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: r.s(16), vertical: r.s(8)),
                            child: GestureDetector(
                              onTap: () => showSingleImageViewer(
                                context,
                                imageUrl: post.mediaUrl!,
                                heroTag: 'post_media_${post.id}',
                              ),
                              onLongPress: () => showSingleImageViewer(
                                context,
                                imageUrl: post.mediaUrl!,
                                heroTag: 'post_media_${post.id}',
                              ),
                              child: Hero(
                                tag: 'post_media_${post.id}',
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(r.s(12)),
                                  child: CachedNetworkImage(
                                    imageUrl: post.mediaUrl!,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
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
                                s.viewsCountLabel(post.viewsCount),
                                style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: r.fs(12)),
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
                                s.comments,
                                style: TextStyle(
                                  fontSize: r.fs(15),
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const Spacer(),
                              PopupMenuButton<_CommentSortOrder>(
                                tooltip: s.sortBy,
                                initialValue: _commentSortOrder,
                                onSelected: (value) {
                                  setState(() => _commentSortOrder = value);
                                },
                                color: context.surfaceColor,
                                elevation: 8,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(r.s(14)),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: _CommentSortOrder.mostRecent,
                                    child: Text(
                                      s.mostRecent,
                                      style: TextStyle(color: context.nexusTheme.textPrimary),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: _CommentSortOrder.oldest,
                                    child: Text(
                                      s.oldest,
                                      style: TextStyle(color: context.nexusTheme.textPrimary),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: _CommentSortOrder.mostPopular,
                                    child: Text(
                                      s.mostPopular,
                                      style: TextStyle(color: context.nexusTheme.textPrimary),
                                    ),
                                  ),
                                ],
                                child: Container(
                                  padding: EdgeInsets.all(r.s(6)),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(r.s(10)),
                                  ),
                                  child: Icon(
                                    Icons.tune_rounded,
                                    size: r.s(20),
                                    color: _commentSortOrder == _CommentSortOrder.oldest
                                        ? Colors.grey[500]
                                        : context.nexusTheme.accentPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ================================================================
                        // COMPOSER DE COMENTÁRIO INLINE (unificado)
                        // ================================================================
                        Container(
                          padding: EdgeInsets.fromLTRB(r.s(16), r.s(8), r.s(16), r.s(8)),
                          decoration: BoxDecoration(
                            color: context.surfaceColor,
                            border: Border(
                              top: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.15),
                              ),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Reply indicator
                              if (_replyingToComment != null)
                                Container(
                                  margin: EdgeInsets.only(bottom: r.s(8)),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: r.s(12),
                                    vertical: r.s(8),
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.nexusTheme.accentPrimary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(r.s(12)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Respondendo a @${_replyingToComment!.author?.nickname ?? s.user}',
                                          style: TextStyle(
                                            color: context.nexusTheme.accentPrimary,
                                            fontSize: r.fs(12),
                                            fontWeight: FontWeight.w700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: _clearReplyTarget,
                                        child: Icon(
                                          Icons.close_rounded,
                                          color: Colors.grey[600],
                                          size: r.s(18),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              // Preview de mídia pendente
                              if (_pendingMediaUrl != null || _pendingStickerUrl != null)
                                Container(
                                  margin: EdgeInsets.only(bottom: r.s(8)),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(r.s(8)),
                                        child: Image.network(
                                          _pendingStickerUrl ?? _pendingMediaUrl!,
                                          width: r.s(60),
                                          height: r.s(60),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      SizedBox(width: r.s(8)),
                                      Expanded(
                                        child: Text(
                                          _pendingStickerUrl != null ? 'Sticker' : 'Imagem anexada',
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: r.fs(12),
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => setState(() {
                                          _pendingMediaUrl = null;
                                          _pendingStickerUrl = null;
                                        }),
                                        child: Icon(Icons.close_rounded,
                                            color: Colors.grey[600], size: r.s(18)),
                                      ),
                                    ],
                                  ),
                                ),
                              // Emoji Picker
                              if (_showEmojiPicker)
                                SizedBox(
                                  height: 250,
                                  child: EmojiPicker(
                                    onEmojiSelected: (_, emoji) {
                                      _commentController.text += emoji.emoji;
                                      _commentController.selection = TextSelection.fromPosition(
                                        TextPosition(offset: _commentController.text.length),
                                      );
                                    },
                                    config: Config(
                                      columns: 8,
                                      emojiSizeMax: 28,
                                      bgColor: context.surfaceColor,
                                      indicatorColor: context.nexusTheme.accentPrimary,
                                      iconColorSelected: context.nexusTheme.accentPrimary,
                                      iconColor: Colors.grey[600] ?? Colors.grey,
                                      checkPlatformCompatibility: true,
                                      recentTabBehavior: RecentTabBehavior.RECENT,
                                      recentsLimit: 20,
                                      noRecents: Text(
                                        'Sem recentes',
                                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ),
                              // Input row: avatar + botões + campo + enviar
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CosmeticAvatar(
                                    userId: currentUser?.id ?? SupabaseService.currentUserId ?? '',
                                    avatarUrl: currentUserAvatar ?? currentUser?.iconUrl,
                                    size: r.s(32),
                                  ),
                                  SizedBox(width: r.s(8)),
                                  // Botão unificado: emoji + figurinha + mídia
                                  Padding(
                                    padding: EdgeInsets.only(right: r.s(6)),
                                    child: CommentMediaMenuButton(
                                      isUploadingMedia: _pendingMediaUrl != null,
                                      showEmojiPicker: _showEmojiPicker,
                                      onToggleEmoji: _toggleEmojiPicker,
                                      onOpenSticker: () async {
                                        _commentFocusNode.unfocus();
                                        await _openStickerPicker();
                                      },
                                      onPickMedia: _pickCommentImage,
                                    ),
                                  ),
                                  // Campo de texto
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(r.s(20)),
                                      ),
                                      child: TextField(
                                        controller: _commentController,
                                        focusNode: _commentFocusNode,
                                        style: TextStyle(
                                          color: context.nexusTheme.textPrimary,
                                          fontSize: r.fs(14),
                                        ),
                                        decoration: InputDecoration(
                                          hintText: _replyingToComment == null
                                              ? s.saySomethingHint
                                              : 'Escreva uma resposta...',
                                          hintStyle: TextStyle(color: Colors.grey[500]),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: r.s(14),
                                            vertical: r.s(10),
                                          ),
                                        ),
                                        maxLines: 4,
                                        minLines: 1,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: r.s(8)),
                                  // Botão enviar
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(r.s(22)),
                                      onTap: _isSending ? null : _sendComment,
                                      child: Container(
                                        padding: EdgeInsets.all(r.s(9)),
                                        decoration: BoxDecoration(
                                          color: context.nexusTheme.accentPrimary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: _isSending
                                            ? SizedBox(
                                                width: r.s(16),
                                                height: r.s(16),
                                                child: const CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              )
                                            : Icon(Icons.send_rounded,
                                                color: Colors.white, size: r.s(16)),
                                      ),
                                    ),
                                  ),
                                ],
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
                                    context.nexusTheme.accentPrimary),
                              ),
                            ),
                          ),
                          error: (error, _) => Padding(
                            padding: EdgeInsets.all(r.s(16)),
                            child: Text(
                              'Erro ao carregar comentários. Tente novamente.',
                              style:
                                  TextStyle(color: context.nexusTheme.error),
                            ),
                          ),
                          data: (comments) {
                            final threadedComments = _buildCommentTree(comments);
                            if (threadedComments.isEmpty) {
                              return Padding(
                                padding:
                                    EdgeInsets.symmetric(vertical: r.s(32)),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.refresh_rounded,
                                          size: r.s(28),
                                          color: Colors.grey[400]),
                                      SizedBox(height: r.s(8)),
                                      Text(
                                        s.noComments,
                                        style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: r.fs(14)),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return Column(
                              children: threadedComments
                                  .map(
                                    (comment) => _CommentTile(
                                      comment: comment,
                                      communityId: post.communityId,
                                      depth: 0,
                                      onReply: (selectedComment) =>
                                          _focusCommentComposer(
                                        replyTo: selectedComment,
                                      ),
                                      onDelete: _deleteComment,
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),

                        SizedBox(height: r.s(24)),
                      ],
                    ),
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
    final s = getStrings();
    final r = context.r;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
      padding: EdgeInsets.all(r.s(16)),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(r.s(14)),
        border:
            Border.all(color: const Color(0xFF3F51B5).withValues(alpha: 0.3)),
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
                Text(s.questionAndAnswer,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: r.fs(14),
                        color: const Color(0xFF3F51B5))),
                const SizedBox(height: 2),
                Text(
                  s.replyInComments(post.commentsCount),
                  style: TextStyle(fontSize: r.fs(12), color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _focusCommentComposer(),
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(6)),
              decoration: BoxDecoration(
                color: const Color(0xFF3F51B5),
                borderRadius: BorderRadius.circular(r.s(20)),
              ),
              child: Text(s.reply,
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
    // Navegar para a tela de edição correta baseado no tipo do post
    final type = post.editorType ?? post.type;
    final communityId = post.communityId;
    final extra = {'editingPost': post};

    switch (type) {
      case 'blog':
        context.push('/community/$communityId/create-blog', extra: extra);
        break;
      case 'image':
        context.push('/community/$communityId/create-image', extra: extra);
        break;
      case 'link':
        context.push('/community/$communityId/create-link', extra: extra);
        break;
      case 'poll':
        context.push('/community/$communityId/create-poll', extra: extra);
        break;
      case 'quiz':
        context.push('/community/$communityId/create-quiz', extra: extra);
        break;
      case 'qa':
      case 'question':
        context.push('/community/$communityId/create-question', extra: extra);
        break;
      case 'wiki':
        context.push('/community/$communityId/wiki/create', extra: extra);
        break;
      case 'story':
        context.push('/community/$communityId/create-story', extra: extra);
        break;
      default:
        // Tipo normal ou desconhecido — usar o editor genérico
        context.push(
          '/community/$communityId/create-post',
          extra: {
            'editingPost': post,
            'initialType': type,
          },
        );
    }
  }

  // ======================================================
  // REPOST — Card do post original (estilo Twitter/X)
  // ======================================================
  Widget _buildOriginalPostCard(PostModel post, Responsive r, AppStrings s) {
    final originalPost = post.originalPost;
    final originalAuthor = post.originalAuthor ?? originalPost?.author;

    return Padding(
      padding: EdgeInsets.fromLTRB(r.s(16), 0, r.s(16), r.s(16)),
      child: GestureDetector(
        onTap: () {
          if (post.originalPostId != null) {
            context.push('/post/${post.originalPostId}');
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(r.s(12)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header do post original
              Padding(
                padding:
                    EdgeInsets.fromLTRB(r.s(12), r.s(12), r.s(12), r.s(6)),
                child: Row(
                  children: [
                    if (originalAuthor?.iconUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(r.s(16)),
                        child: CachedNetworkImage(
                          imageUrl: originalAuthor!.iconUrl!,
                          width: r.s(32),
                          height: r.s(32),
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => CircleAvatar(
                            radius: r.s(16),
                            backgroundColor:
                                context.nexusTheme.accentPrimary.withValues(alpha: 0.3),
                            child: Icon(Icons.person_rounded,
                                size: r.s(16),
                                color: context.nexusTheme.accentPrimary),
                          ),
                        ),
                      )
                    else
                      CircleAvatar(
                        radius: r.s(16),
                        backgroundColor:
                            context.nexusTheme.accentPrimary.withValues(alpha: 0.3),
                        child: Icon(Icons.person_rounded,
                            size: r.s(16),
                            color: context.nexusTheme.accentPrimary),
                      ),
                    SizedBox(width: r.s(10)),
                    Expanded(
                      child: Text(
                        originalAuthor?.nickname ?? s.user,
                        style: TextStyle(
                          color: context.nexusTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: r.fs(14),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.open_in_new_rounded,
                        size: r.s(14), color: Colors.grey[600]),
                  ],
                ),
              ),
              // Título do post original
              if ((originalPost?.title ?? '').isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(r.s(12), 0, r.s(12), r.s(6)),
                  child: Text(
                    originalPost!.title!,
                    style: TextStyle(
                      color: context.nexusTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: r.fs(15),
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              // Conteúdo do post original
              if (originalPost != null && originalPost.content.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(r.s(12), 0, r.s(12), r.s(10)),
                  child: Text(
                    originalPost.content,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: r.fs(14),
                      height: 1.5,
                    ),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              // Imagem de capa do post original
              if (originalPost?.coverImageUrl != null ||
                  originalPost?.mediaUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(r.s(12)),
                    bottomRight: Radius.circular(r.s(12)),
                  ),
                  child: CachedNetworkImage(
                    imageUrl:
                        originalPost?.coverImageUrl ?? originalPost!.mediaUrl!,
                    width: double.infinity,
                    height: r.s(200),
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                )
              else if (originalPost == null)
                Padding(
                  padding: EdgeInsets.fromLTRB(r.s(12), 0, r.s(12), r.s(12)),
                  child: Text(
                    s.postNotFoundMsg,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: r.fs(13),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                SizedBox(height: r.s(4)),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// BOTÃO DA BARRA INFERIOR
// =============================================================================
class _BottomBarButton extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
class _CommentTile extends ConsumerStatefulWidget {
  final CommentModel comment;
  final String? communityId;
  final int depth;
  final ValueChanged<CommentModel>? onReply;
  final Future<void> Function(CommentModel comment)? onDelete;

  const _CommentTile({
    required this.comment,
    this.communityId,
    this.depth = 0,
    this.onReply,
    this.onDelete,
  });

  @override
  ConsumerState<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends ConsumerState<_CommentTile> {
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
      if (mounted && res != null) {
        setState(() => _isLiked = true);
      }
    } catch (e) {
      debugPrint('[post_detail_screen.dart] $e');
    }
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

  Future<void> _handleMenuSelection(String value) async {
    final s = ref.read(stringsProvider);
    switch (value) {
      case 'reply':
        widget.onReply?.call(widget.comment);
        break;
      case 'copy':
        await Clipboard.setData(ClipboardData(text: widget.comment.content));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comentário copiado.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
      case 'delete':
        await widget.onDelete?.call(widget.comment);
        break;
      default:
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.anErrorOccurredTryAgain),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final comment = widget.comment;
    final isOwner = SupabaseService.currentUserId == comment.authorId;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        r.s(16 + (widget.depth * 20)),
        r.s(8),
        r.s(16),
        r.s(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CosmeticAvatar(
                userId: comment.authorId,
                avatarUrl: comment.effectiveIconUrl,
                size: r.s(widget.depth > 0 ? 30 : 36),
                onTap: () => context.push(
                  widget.communityId?.isNotEmpty == true
                      ? '/community/${widget.communityId}/profile/${comment.authorId}'
                      : '/user/${comment.authorId}',
                ),
              ),
              SizedBox(width: r.s(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: r.s(8),
                            runSpacing: r.s(2),
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                comment.effectiveNickname(s.user),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: r.fs(14),
                                  color: context.nexusTheme.textPrimary,
                                ),
                              ),
                              Text(
                                timeago.format(comment.createdAt,
                                    locale: 'pt_BR'),
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: r.fs(11),
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          iconSize: r.s(18),
                          color: context.surfaceColor,
                          onSelected: _handleMenuSelection,
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              value: 'reply',
                              child: Text(s.reply),
                            ),
                            const PopupMenuItem<String>(
                              value: 'copy',
                              child: Text('Copiar comentário'),
                            ),
                            if (isOwner)
                              const PopupMenuItem<String>(
                                value: 'delete',
                                child: Text('Excluir comentário'),
                              ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: r.s(4)),
                    // Texto do comentário (ocultar se for apenas marcador de sticker/imagem)
                    if (comment.content != '[sticker]' && comment.content != '[image]' && !comment.isSticker)
                      Text(
                        comment.content,
                        style: TextStyle(
                          fontSize: r.fs(14),
                          height: 1.4,
                          color: context.nexusTheme.textPrimary,
                        ),
                      ),
                    // Sticker com suporte a favoritar/salvar pack
                    if (comment.isSticker && (comment.stickerUrl ?? comment.mediaUrl) != null)
                      Padding(
                        padding: EdgeInsets.only(top: r.s(6)),
                        child: StickerMessageBubble(
                          stickerId: comment.stickerId ?? (comment.stickerUrl ?? comment.mediaUrl)!,
                          stickerUrl: comment.stickerUrl ?? comment.mediaUrl!,
                          stickerName: comment.stickerName ?? '',
                          packId: comment.packId,
                          isSentByMe: comment.authorId == SupabaseService.currentUserId,
                          size: r.s(100),
                        ),
                      )
                    // Vídeo
                    else if (!comment.isSticker && comment.mediaUrl != null &&
                        (comment.mediaUrl!.contains('.mp4') ||
                         comment.mediaUrl!.contains('.mov') ||
                         comment.mediaUrl!.contains('.webm')))
                      Padding(
                        padding: EdgeInsets.only(top: r.s(6)),
                        child: GestureDetector(
                          onTap: () {
                            // Abrir vídeo em tela cheia
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                backgroundColor: Colors.black,
                                insetPadding: EdgeInsets.zero,
                                child: Stack(
                                  alignment: Alignment.topRight,
                                  children: [
                                    AspectRatio(
                                      aspectRatio: 16 / 9,
                                      child: Icon(Icons.play_circle_fill_rounded,
                                          color: Colors.white, size: 64),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(r.s(10)),
                            child: Container(
                              width: r.s(200),
                              height: r.s(120),
                              color: Colors.black,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(Icons.play_circle_fill_rounded,
                                      color: Colors.white.withValues(alpha: 0.9),
                                      size: r.s(48)),
                                  Positioned(
                                    bottom: r.s(6),
                                    left: r.s(6),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: r.s(6), vertical: r.s(2)),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(r.s(4)),
                                      ),
                                      child: Text('Vídeo',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: r.fs(10))),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    // Imagem genérica (não-sticker) — abre ImageViewer ao tocar
                    else if (!comment.isSticker && comment.mediaUrl != null && comment.mediaUrl!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: r.s(6)),
                        child: TappableImage(
                          url: comment.mediaUrl!,
                          width: r.s(200),
                          height: r.s(200),
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(r.s(10)),
                          heroTag: 'comment_img_${comment.id}',
                        ),
                      ),
                    SizedBox(height: r.s(8)),
                    Row(
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(r.s(20)),
                            onTap: _toggleCommentLike,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: r.s(4),
                                vertical: r.s(2),
                              ),
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
                          ),
                        ),
                        SizedBox(width: r.s(12)),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(r.s(20)),
                            onTap: () => widget.onReply?.call(comment),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: r.s(4),
                                vertical: r.s(2),
                              ),
                              child: Text(
                                s.reply,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: r.fs(12),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
          if (comment.replies.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: r.s(4)),
              child: Column(
                children: comment.replies
                    .map(
                      (reply) => _CommentTile(
                        comment: reply,
                        communityId: widget.communityId,
                        depth: widget.depth + 1,
                        onReply: widget.onReply,
                        onDelete: widget.onDelete,
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _RepostConfirmSheetDetail extends ConsumerWidget {
  final dynamic post;
  const _RepostConfirmSheetDetail({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s.repost, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.confirm),
          ),
        ],
      ),
    );
  }
}
