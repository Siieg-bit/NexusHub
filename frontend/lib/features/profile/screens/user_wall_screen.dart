import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../chat/widgets/sticker_picker.dart';
import '../providers/profile_providers.dart';

/// Mural do Usuário (The Wall) — Mensagens públicas no perfil, estilo Amino.
/// Suporta texto, stickers, imagens, likes, replies e exclusão.
class UserWallScreen extends ConsumerStatefulWidget {
  final String userId;
  const UserWallScreen({super.key, required this.userId});

  @override
  ConsumerState<UserWallScreen> createState() => _UserWallScreenState();
}

class _UserWallScreenState extends ConsumerState<UserWallScreen> {
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  final _messageController = TextEditingController();
  bool _isSending = false;
  String? _pendingMediaUrl;
  String? _pendingStickerUrl;
  String? _replyingToId;
  String? _replyingToNickname;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final res = await SupabaseService.table('comments')
          .select('*, profiles!comments_author_id_fkey(id, nickname, icon_url)')
          .eq('profile_wall_id', widget.userId)
          .eq('status', 'ok')
          .isFilter('parent_id', null) // Apenas top-level
          .order('created_at', ascending: false)
          .limit(50);
      if (!mounted) return;

      // Carregar replies para cada mensagem
      final messages = List<Map<String, dynamic>>.from(res as List? ?? []);
      for (final msg in messages) {
        final msgId = msg['id'] as String?;
        if (msgId == null) continue;
        try {
          final replies = await SupabaseService.table('comments')
              .select(
                  '*, profiles!comments_author_id_fkey(id, nickname, icon_url)')
              .eq('parent_id', msgId)
              .eq('status', 'ok')
              .order('created_at', ascending: true)
              .limit(20);
          msg['_replies'] = List<Map<String, dynamic>>.from(replies as List? ?? []);
        } catch (_) {
          msg['_replies'] = <Map<String, dynamic>>[];
        }
      }

      if (!mounted) return;
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[user_wall_screen] Erro: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage({String? stickerUrl}) async {
    final s = getStrings();
    final text = _messageController.text.trim();
    final mediaUrl = stickerUrl ?? _pendingStickerUrl ?? _pendingMediaUrl;

    if (text.isEmpty && mediaUrl == null) return;

    setState(() => _isSending = true);
    try {
      await SupabaseService.table('comments').insert({
        'profile_wall_id': widget.userId,
        'author_id': SupabaseService.currentUserId,
        'content': text.isNotEmpty
            ? text
            : (stickerUrl != null ? '[sticker]' : '[image]'),
        'media_url': mediaUrl,
        'parent_id': _replyingToId,
      });
      _messageController.clear();
      _clearReply();
      setState(() {
        _pendingMediaUrl = null;
        _pendingStickerUrl = null;
      });
      await _loadMessages();
      // Invalidar provider do mural para sincronizar com profile_wall_tab
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
    final s = getStrings();
    try {
      await SupabaseService.table('comments').delete().eq('id', messageId);
      await _loadMessages();
      ref.invalidate(userWallProvider(widget.userId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.anErrorOccurredTryAgain)),
        );
      }
    }
  }

  Future<void> _toggleLike(String commentId) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      // Verificar se já curtiu
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
      await _loadMessages();
    } catch (e) {
      debugPrint('[user_wall_screen] Like error: $e');
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
      await _sendMessage(stickerUrl: result['sticker_url']!);
    }
  }

  void _setReply(String commentId, String nickname) {
    setState(() {
      _replyingToId = commentId;
      _replyingToNickname = nickname;
    });
    _messageController.text = '@$nickname ';
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
  }

  void _clearReply() {
    setState(() {
      _replyingToId = null;
      _replyingToNickname = null;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final isOwnWall = widget.userId == SupabaseService.currentUserId;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
        title: Text(isOwnWall ? 'Meu Mural' : s.wall,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            )),
      ),
      body: Column(
        children: [
          // Lista de mensagens
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.dashboard_rounded,
                                size: r.s(64), color: Colors.grey[600]),
                            SizedBox(height: r.s(16)),
                            Text(s.noWallMessages,
                                style: TextStyle(color: Colors.grey[500])),
                            SizedBox(height: r.s(8)),
                            Text(
                              'Deixe uma mensagem no mural!',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: r.fs(12)),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppTheme.primaryColor,
                        backgroundColor: context.surfaceColor,
                        onRefresh: _loadMessages,
                        child: ListView.builder(
                          padding: EdgeInsets.all(r.s(16)),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) => _WallMessageCard(
                            msg: _messages[index],
                            isOwnWall: isOwnWall,
                            r: r,
                            onDelete: _deleteMessage,
                            onLike: _toggleLike,
                            onReply: _setReply,
                          ),
                        ),
                      ),
          ),

          // Composer fixo
          _buildComposer(r, s),
        ],
      ),
    );
  }

  Widget _buildComposer(Responsive r, dynamic s) {
    return Container(
      padding: EdgeInsets.only(
        left: r.s(12),
        right: r.s(12),
        top: r.s(8),
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(
          top: BorderSide(
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
              margin: EdgeInsets.only(bottom: r.s(8)),
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(6)),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(r.s(10)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Respondendo a @${_replyingToNickname ?? ''}',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: r.fs(12),
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: _clearReply,
                    child: Icon(Icons.close_rounded,
                        color: Colors.grey[600], size: r.s(18)),
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
                      width: r.s(50),
                      height: r.s(50),
                      fit: BoxFit.cover,
                    ),
                  ),
                  SizedBox(width: r.s(8)),
                  Expanded(
                    child: Text(
                      _pendingStickerUrl != null
                          ? 'Sticker'
                          : 'Imagem anexada',
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: r.fs(12)),
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
          // Input row
          Row(
            children: [
              // Sticker button
              GestureDetector(
                onTap: _openStickerPicker,
                child: Padding(
                  padding: EdgeInsets.only(right: r.s(6)),
                  child: Icon(Icons.emoji_emotions_rounded,
                      color: Colors.grey[500], size: r.s(22)),
                ),
              ),
              // Image button
              GestureDetector(
                onTap: _pickImage,
                child: Padding(
                  padding: EdgeInsets.only(right: r.s(8)),
                  child: Icon(Icons.image_rounded,
                      color: Colors.grey[500], size: r.s(22)),
                ),
              ),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: r.s(14)),
                  decoration: BoxDecoration(
                    color: context.scaffoldBg,
                    borderRadius: BorderRadius.circular(r.s(24)),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(
                        color: context.textPrimary, fontSize: r.fs(14)),
                    decoration: InputDecoration(
                      hintText: s.writeOnTheWall,
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: r.fs(14),
                      ),
                    ),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
              ),
              SizedBox(width: r.s(10)),
              GestureDetector(
                onTap: _isSending ? null : _sendMessage,
                child: Container(
                  width: r.s(44),
                  height: r.s(44),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.accentColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _isSending
                      ? Padding(
                          padding: EdgeInsets.all(r.s(12)),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(Icons.send_rounded,
                          color: Colors.white, size: r.s(20)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// WALL MESSAGE CARD — Card individual de mensagem do mural com interações
// =============================================================================

class _WallMessageCard extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isOwnWall;
  final Responsive r;
  final Future<void> Function(String) onDelete;
  final Future<void> Function(String) onLike;
  final void Function(String, String) onReply;

  const _WallMessageCard({
    required this.msg,
    required this.isOwnWall,
    required this.r,
    required this.onDelete,
    required this.onLike,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final author =
        (msg['profiles'] ?? msg['author']) as Map<String, dynamic>? ?? {};
    final authorId = msg['author_id'] as String? ?? '';
    final content = msg['content'] as String? ?? '';
    final mediaUrl = msg['media_url'] as String?;
    final likesCount = msg['likes_count'] as int? ?? 0;
    final createdAt =
        DateTime.tryParse(msg['created_at'] as String? ?? '') ?? DateTime.now();
    final canDelete =
        isOwnWall || authorId == SupabaseService.currentUserId;
    final nickname = author['nickname'] as String? ?? 'Usuário';
    final replies =
        msg['_replies'] as List<Map<String, dynamic>>? ?? [];

    return Container(
      margin: EdgeInsets.only(bottom: r.s(12)),
      padding: EdgeInsets.all(r.s(14)),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(16)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — avatar, nome, tempo, delete
          Row(
            children: [
              GestureDetector(
                onTap: () => context.push('/user/$authorId'),
                child: CosmeticAvatar(
                  userId: authorId,
                  avatarUrl: author['icon_url'] as String?,
                  size: r.s(36),
                ),
              ),
              SizedBox(width: r.s(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nickname,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                          fontSize: r.fs(14)),
                    ),
                    Text(
                      timeago.format(createdAt, locale: 'pt_BR'),
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: r.fs(11)),
                    ),
                  ],
                ),
              ),
              if (canDelete)
                GestureDetector(
                  onTap: () => onDelete(msg['id'] as String? ?? ''),
                  child: Icon(Icons.close_rounded,
                      color: Colors.grey[600], size: r.s(18)),
                ),
            ],
          ),
          SizedBox(height: r.s(10)),

          // Conteúdo — texto (ocultar se marcador)
          if (content != '[sticker]' && content != '[image]' && content.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: r.s(8)),
              child: Text(
                content,
                style: TextStyle(
                  fontSize: r.fs(14),
                  color: context.textPrimary,
                  height: 1.4,
                ),
              ),
            ),

          // Mídia (sticker ou imagem)
          if (mediaUrl != null && mediaUrl.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: r.s(8)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(r.s(12)),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: r.s(220),
                    maxHeight: r.s(220),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: mediaUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => SizedBox(
                      width: r.s(80),
                      height: r.s(80),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryColor),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Icon(
                      Icons.broken_image_rounded,
                      color: Colors.grey[500],
                      size: r.s(40),
                    ),
                  ),
                ),
              ),
            ),

          // Barra de interações — like, reply
          Row(
            children: [
              // Like
              GestureDetector(
                onTap: () => onLike(msg['id'] as String? ?? ''),
                child: Row(
                  children: [
                    Icon(Icons.favorite_border_rounded,
                        size: r.s(18), color: Colors.grey[500]),
                    if (likesCount > 0) ...[
                      SizedBox(width: r.s(4)),
                      Text(
                        '$likesCount',
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: r.fs(12)),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: r.s(16)),
              // Reply
              GestureDetector(
                onTap: () => onReply(msg['id'] as String? ?? '', nickname),
                child: Row(
                  children: [
                    Icon(Icons.reply_rounded,
                        size: r.s(18), color: Colors.grey[500]),
                    SizedBox(width: r.s(4)),
                    Text(
                      'Responder',
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: r.fs(12)),
                    ),
                  ],
                ),
              ),
              if (replies.isNotEmpty) ...[
                SizedBox(width: r.s(16)),
                Text(
                  '${replies.length} ${replies.length == 1 ? 'resposta' : 'respostas'}',
                  style: TextStyle(
                      color: AppTheme.primaryColor, fontSize: r.fs(12)),
                ),
              ],
            ],
          ),

          // Replies inline
          if (replies.isNotEmpty) ...[
            SizedBox(height: r.s(10)),
            Container(
              margin: EdgeInsets.only(left: r.s(16)),
              padding: EdgeInsets.only(left: r.s(12)),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
              ),
              child: Column(
                children: replies.map((reply) {
                  final replyAuthor = (reply['profiles'] ?? reply['author'])
                      as Map<String, dynamic>? ?? {};
                  final replyContent = reply['content'] as String? ?? '';
                  final replyMedia = reply['media_url'] as String?;
                  final replyTime = DateTime.tryParse(
                          reply['created_at'] as String? ?? '') ??
                      DateTime.now();
                  final replyAuthorId = reply['author_id'] as String? ?? '';
                  final canDeleteReply = isOwnWall ||
                      replyAuthorId == SupabaseService.currentUserId;

                  return Padding(
                    padding: EdgeInsets.only(bottom: r.s(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () =>
                                  context.push('/user/$replyAuthorId'),
                              child: CosmeticAvatar(
                                userId: replyAuthorId,
                                avatarUrl:
                                    replyAuthor['icon_url'] as String?,
                                size: r.s(24),
                              ),
                            ),
                            SizedBox(width: r.s(6)),
                            Text(
                              replyAuthor['nickname'] as String? ??
                                  'Usuário',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary,
                                fontSize: r.fs(12),
                              ),
                            ),
                            SizedBox(width: r.s(6)),
                            Text(
                              timeago.format(replyTime, locale: 'pt_BR'),
                              style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: r.fs(10)),
                            ),
                            const Spacer(),
                            if (canDeleteReply)
                              GestureDetector(
                                onTap: () =>
                                    onDelete(reply['id'] as String? ?? ''),
                                child: Icon(Icons.close_rounded,
                                    color: Colors.grey[600], size: r.s(14)),
                              ),
                          ],
                        ),
                        SizedBox(height: r.s(4)),
                        if (replyContent != '[sticker]' &&
                            replyContent != '[image]' &&
                            replyContent.isNotEmpty)
                          Text(
                            replyContent,
                            style: TextStyle(
                              fontSize: r.fs(13),
                              color: context.textPrimary,
                              height: 1.3,
                            ),
                          ),
                        if (replyMedia != null && replyMedia.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: r.s(4)),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(r.s(8)),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: r.s(140),
                                  maxHeight: r.s(140),
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: replyMedia,
                                  fit: BoxFit.contain,
                                  errorWidget: (_, __, ___) => Icon(
                                    Icons.broken_image_rounded,
                                    color: Colors.grey[500],
                                    size: r.s(24),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
