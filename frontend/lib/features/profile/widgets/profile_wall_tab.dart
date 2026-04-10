import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/widgets/sticker_picker.dart';
import '../providers/profile_providers.dart';
import '../../../core/l10n/locale_provider.dart';

// =============================================================================
// WALL TAB — Mural de mensagens com stickers, imagens, likes e replies
// =============================================================================

class ProfileWallTab extends ConsumerStatefulWidget {
  final String userId;
  final TextEditingController wallController;

  const ProfileWallTab({
    super.key,
    required this.userId,
    required this.wallController,
  });

  @override
  ConsumerState<ProfileWallTab> createState() => _ProfileWallTabState();
}

class _ProfileWallTabState extends ConsumerState<ProfileWallTab> {
  String? _pendingMediaUrl;
  String? _pendingStickerUrl;
  String? _replyingToId;
  String? _replyingToNickname;
  bool _isSending = false;

  void _setReply(String commentId, String nickname) {
    setState(() {
      _replyingToId = commentId;
      _replyingToNickname = nickname;
    });
    widget.wallController.text = '@$nickname ';
    widget.wallController.selection = TextSelection.fromPosition(
      TextPosition(offset: widget.wallController.text.length),
    );
  }

  void _clearReply() {
    setState(() {
      _replyingToId = null;
      _replyingToNickname = null;
    });
  }

  Future<void> _postMessage() async {
    final s = ref.read(stringsProvider);
    final text = widget.wallController.text.trim();
    final mediaUrl = _pendingStickerUrl ?? _pendingMediaUrl;

    if (text.isEmpty && mediaUrl == null) return;

    setState(() => _isSending = true);
    try {
      await SupabaseService.table('comments').insert({
        'profile_wall_id': widget.userId,
        'author_id': SupabaseService.currentUserId,
        'content': text.isNotEmpty
            ? text
            : (_pendingStickerUrl != null ? '[sticker]' : '[image]'),
        'media_url': mediaUrl,
        'parent_id': _replyingToId,
      });
      widget.wallController.clear();
      _clearReply();
      setState(() {
        _pendingMediaUrl = null;
        _pendingStickerUrl = null;
      });
      ref.invalidate(userWallProvider(widget.userId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.anErrorOccurredTryAgain)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await SupabaseService.table('comments').delete().eq('id', messageId);
      ref.invalidate(userWallProvider(widget.userId));
    } catch (e) {
      debugPrint('[profile_wall_tab] Erro: $e');
    }
  }

  Future<void> _toggleLike(String commentId) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      final existing = await SupabaseService.table('comment_likes')
          .select('id')
          .eq('comment_id', commentId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        await SupabaseService.table('comment_likes')
            .delete()
            .eq('comment_id', commentId)
            .eq('user_id', userId);
      } else {
        await SupabaseService.table('comment_likes').insert({
          'comment_id': commentId,
          'user_id': userId,
        });
      }
      ref.invalidate(userWallProvider(widget.userId));
    } catch (e) {
      debugPrint('[profile_wall_tab] Like error: $e');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final path =
          'wall/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
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
            content: Text('Erro ao enviar imagem'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _openStickerPicker() async {
    final result = await StickerPicker.show(context);
    if (result != null && result['sticker_url'] != null && mounted) {
      // Enviar sticker diretamente
      setState(() => _pendingStickerUrl = result['sticker_url']);
      await _postMessage();
    }
  }

  String _timeAgo(DateTime dt) {
    final s = getStrings();
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 365) return '${diff.inDays ~/ 365}a';
    if (diff.inDays > 30) return '${diff.inDays ~/ 30}m';
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}min';
    return s.now;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final wallAsync = ref.watch(userWallProvider(widget.userId));
    final isOwnWall = widget.userId == SupabaseService.currentUserId;

    return Column(
      children: [
        // Composer com stickers e imagem
        Container(
          padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reply indicator
              if (_replyingToId != null)
                Container(
                  margin: EdgeInsets.only(bottom: r.s(6)),
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(10), vertical: r.s(5)),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(r.s(8)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Respondendo a @${_replyingToNickname ?? ''}',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: r.fs(11),
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: _clearReply,
                        child: Icon(Icons.close_rounded,
                            color: Colors.grey[600], size: r.s(16)),
                      ),
                    ],
                  ),
                ),
              // Preview de mídia pendente
              if (_pendingMediaUrl != null)
                Container(
                  margin: EdgeInsets.only(bottom: r.s(6)),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(r.s(6)),
                        child: Image.network(
                          _pendingMediaUrl!,
                          width: r.s(40),
                          height: r.s(40),
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(width: r.s(6)),
                      Expanded(
                        child: Text('Imagem anexada',
                            style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: r.fs(11))),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _pendingMediaUrl = null),
                        child: Icon(Icons.close_rounded,
                            color: Colors.grey[600], size: r.s(16)),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  // Sticker button
                  GestureDetector(
                    onTap: _openStickerPicker,
                    child: Padding(
                      padding: EdgeInsets.only(right: r.s(4)),
                      child: Icon(Icons.emoji_emotions_rounded,
                          color: Colors.grey[500], size: r.s(20)),
                    ),
                  ),
                  // Image button
                  GestureDetector(
                    onTap: _pickImage,
                    child: Padding(
                      padding: EdgeInsets.only(right: r.s(6)),
                      child: Icon(Icons.image_rounded,
                          color: Colors.grey[500], size: r.s(20)),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: widget.wallController,
                      style: TextStyle(
                          color: context.textPrimary, fontSize: r.fs(14)),
                      decoration: InputDecoration(
                        hintText: s.writeOnTheWall,
                        hintStyle: TextStyle(
                            color: Colors.grey[600], fontSize: r.fs(14)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: r.s(10), vertical: r.s(8)),
                      ),
                    ),
                  ),
                  SizedBox(width: r.s(6)),
                  GestureDetector(
                    onTap: _isSending ? null : _postMessage,
                    child: Container(
                      padding: EdgeInsets.all(r.s(8)),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(r.s(8)),
                      ),
                      child: _isSending
                          ? SizedBox(
                              width: r.s(16),
                              height: r.s(16),
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
            ],
          ),
        ),
        // Lista de mensagens
        Expanded(
          child: wallAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                  color: AppTheme.accentColor, strokeWidth: 2),
            ),
            error: (_, __) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(s.failedToLoadData,
                      style: TextStyle(color: Colors.grey[500])),
                  SizedBox(height: r.s(12)),
                  GestureDetector(
                    onTap: () =>
                        ref.invalidate(userWallProvider(widget.userId)),
                    child: Icon(Icons.refresh_rounded,
                        color: Colors.grey[500], size: r.s(32)),
                  ),
                ],
              ),
            ),
            data: (messages) {
              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.dashboard_rounded,
                          size: r.s(48), color: Colors.grey[600]),
                      SizedBox(height: r.s(8)),
                      Text(s.noWallComments,
                          style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                color: AppTheme.primaryColor,
                onRefresh: () async {
                  ref.invalidate(userWallProvider(widget.userId));
                  ref.invalidate(userProfileProvider);
                  ref.invalidate(equippedItemsProvider);
                  ref.invalidate(currentUserProvider);
                  ref.invalidate(userLinkedCommunitiesProvider);
                  ref.invalidate(userPostsProvider);
                  await Future.delayed(const Duration(milliseconds: 300));
                },
                child: ListView.builder(
                  padding: EdgeInsets.all(r.s(12)),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final profile = (msg['author'] ?? msg['profiles'])
                            as Map<String, dynamic>? ??
                        {};
                    final authorId = msg['author_id'] as String? ?? '';
                    final content = msg['content'] as String? ?? '';
                    final mediaUrl = msg['media_url'] as String?;
                    final likesCount = msg['likes_count'] as int? ?? 0;
                    final createdAt = DateTime.tryParse(
                            msg['created_at'] as String? ?? '') ??
                        DateTime.now();
                    final canDelete = isOwnWall ||
                        authorId == SupabaseService.currentUserId;
                    final nickname =
                        profile['nickname'] as String? ?? s.user;

                    return Container(
                      margin: EdgeInsets.only(bottom: r.s(10)),
                      padding: EdgeInsets.all(r.s(12)),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(r.s(12)),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    context.push('/user/$authorId'),
                                child: CosmeticAvatar(
                                  userId: authorId,
                                  avatarUrl:
                                      profile['icon_url'] as String?,
                                  size: r.s(32),
                                ),
                              ),
                              SizedBox(width: r.s(8)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nickname,
                                      style: TextStyle(
                                        color: context.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: r.fs(13),
                                      ),
                                    ),
                                    Text(
                                      _timeAgo(createdAt),
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: r.fs(11)),
                                    ),
                                  ],
                                ),
                              ),
                              if (canDelete)
                                GestureDetector(
                                  onTap: () => _deleteMessage(
                                      msg['id'] as String? ?? ''),
                                  child: Icon(Icons.close_rounded,
                                      color: Colors.grey[600],
                                      size: r.s(16)),
                                ),
                            ],
                          ),
                          SizedBox(height: r.s(8)),
                          // Conteúdo
                          if (content != '[sticker]' &&
                              content != '[image]' &&
                              content.isNotEmpty)
                            Text(
                              content,
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: r.fs(13),
                                height: 1.4,
                              ),
                            ),
                          // Mídia
                          if (mediaUrl != null && mediaUrl.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: r.s(6)),
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(r.s(10)),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: r.s(180),
                                    maxHeight: r.s(180),
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: mediaUrl,
                                    fit: BoxFit.contain,
                                    errorWidget: (_, __, ___) => Icon(
                                      Icons.broken_image_rounded,
                                      color: Colors.grey[500],
                                      size: r.s(32),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          SizedBox(height: r.s(8)),
                          // Barra de interações
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => _toggleLike(
                                    msg['id'] as String? ?? ''),
                                child: Row(
                                  children: [
                                    Icon(
                                        Icons
                                            .favorite_border_rounded,
                                        size: r.s(16),
                                        color: Colors.grey[500]),
                                    if (likesCount > 0) ...[
                                      SizedBox(width: r.s(3)),
                                      Text('$likesCount',
                                          style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: r.fs(11))),
                                    ],
                                  ],
                                ),
                              ),
                              SizedBox(width: r.s(14)),
                              GestureDetector(
                                onTap: () => _setReply(
                                    msg['id'] as String? ?? '',
                                    nickname),
                                child: Icon(Icons.reply_rounded,
                                    size: r.s(16),
                                    color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
