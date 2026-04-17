import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../stickers/stickers.dart';
import '../../../core/widgets/image_viewer.dart';
import '../../../core/widgets/comment_media_menu_button.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// =============================================================================
// PROVIDER — carregamento de comentários do mural via RPC
// =============================================================================

/// Chave composta para o mural: (wallUserId, communityId)
/// communityId vazio ('') = mural global
typedef WallKey = ({String userId, String communityId});

final wallCommentsProvider =
    FutureProvider.family<List<WallComment>, WallKey>((ref, key) async {
  try {
    final params = <String, dynamic>{
      'p_wall_user_id': key.userId,
      'p_limit': 60,
      'p_offset': 0,
    };
    // Passa community_id apenas quando for um mural de comunidade
    if (key.communityId.isNotEmpty) {
      params['p_community_id'] = key.communityId;
    }
    final res = await SupabaseService.rpc('get_wall_comments', params: params);
    final list = List<Map<String, dynamic>>.from(res as List? ?? []);
    return list.map(WallComment.fromJson).toList();
  } catch (e) {
    debugPrint('[wallCommentsProvider] $e');
    return [];
  }
});

// =============================================================================
// MODELO — WallComment
// =============================================================================

class WallComment {
  final String id;
  final String authorId;
  final String content;
  final String? mediaUrl;
  final String? mediaType; // 'image' | 'video' | 'sticker' | 'gif'
  final String? stickerId;
  final String? stickerUrl;
  final String? stickerName;
  final String? packId;
  final String? emojiReaction;
  final int likesCount;
  final bool isLiked;
  final DateTime createdAt;
  final Map<String, dynamic> author;
  final List<WallComment> replies;

  const WallComment({
    required this.id,
    required this.authorId,
    required this.content,
    this.mediaUrl,
    this.mediaType,
    this.stickerId,
    this.stickerUrl,
    this.stickerName,
    this.packId,
    this.emojiReaction,
    this.likesCount = 0,
    this.isLiked = false,
    required this.createdAt,
    required this.author,
    this.replies = const [],
  });

  factory WallComment.fromJson(Map<String, dynamic> json) {
    return WallComment(
      id: json['id'] as String? ?? '',
      authorId: json['author_id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      mediaUrl: json['media_url'] as String?,
      mediaType: json['media_type'] as String?,
      stickerId: json['sticker_id'] as String?,
      stickerUrl: json['sticker_url'] as String?,
      stickerName: json['sticker_name'] as String?,
      packId: json['pack_id'] as String?,
      emojiReaction: json['emoji_reaction'] as String?,
      likesCount: json['likes_count'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      author: Map<String, dynamic>.from(json['author'] as Map? ?? {}),
      replies: (json['replies'] as List<dynamic>? ?? [])
          .map((r) => WallComment.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isSticker => stickerUrl != null || stickerId != null;
  bool get isMedia => mediaUrl != null && !isSticker;
  bool get isVideo => mediaType == 'video' || (mediaUrl?.contains('.mp4') == true);
}

// =============================================================================
// WIDGET PRINCIPAL — WallCommentSheet (bottom sheet ou inline)
// =============================================================================

class WallCommentSheet extends ConsumerStatefulWidget {
  final String wallUserId;
  final bool isOwnWall;
  final bool asBottomSheet;
  /// communityId vazio ('') = mural global; preenchido = mural da comunidade
  final String communityId;

  const WallCommentSheet({
    super.key,
    required this.wallUserId,
    required this.isOwnWall,
    this.asBottomSheet = false,
    this.communityId = '',
  });

  /// Abre como bottom sheet modal.
  static Future<void> show(
    BuildContext context, {
    required String wallUserId,
    required bool isOwnWall,
    String communityId = '',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WallCommentSheet(
        wallUserId: wallUserId,
        isOwnWall: isOwnWall,
        asBottomSheet: true,
        communityId: communityId,
      ),
    );
  }

  @override
  ConsumerState<WallCommentSheet> createState() => _WallCommentSheetState();
}

class _WallCommentSheetState extends ConsumerState<WallCommentSheet> {
  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();

  bool _isSending = false;
  bool _showEmojiPicker = false;

  // Mídia pendente
  String? _pendingMediaUrl;
  String? _pendingMediaType;
  Uint8List? _pendingMediaBytes;
  bool _isUploadingMedia = false;

  // Sticker pendente
  String? _pendingStickerUrl;
  String? _pendingStickerId;
  String? _pendingStickerName;
  String? _pendingPackId;

  // Reply
  WallComment? _replyingTo;

  @override
  void initState() {
    super.initState();
    // Atualiza a borda do campo ao ganhar/perder foco
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // ENVIO
  // ---------------------------------------------------------------------------

  Future<void> _send() async {
    if (_isSending) return;
    final text = _textCtrl.text.trim();
    final hasMedia = _pendingMediaUrl != null;
    final hasSticker = _pendingStickerUrl != null;
    if (text.isEmpty && !hasMedia && !hasSticker) return;

    setState(() => _isSending = true);
    try {
      await SupabaseService.rpc('post_wall_message', params: {
        'p_wall_user_id': widget.wallUserId,
        'p_content': text,
        'p_media_url': _pendingMediaUrl,
        'p_media_type': _pendingMediaType ?? 'image',
        'p_sticker_id': _pendingStickerId,
        'p_sticker_url': _pendingStickerUrl,
        'p_sticker_name': _pendingStickerName,
        'p_pack_id': _pendingPackId,
        'p_parent_id': _replyingTo?.id,
        if (widget.communityId.isNotEmpty) 'p_community_id': widget.communityId,
      });

      _textCtrl.clear();
      setState(() {
        _pendingMediaUrl = null;
        _pendingMediaType = null;
        _pendingMediaBytes = null;
        _pendingStickerUrl = null;
        _pendingStickerId = null;
        _pendingStickerName = null;
        _pendingPackId = null;
        _replyingTo = null;
        _showEmojiPicker = false;
      });
      _focusNode.unfocus();
      ref.invalidate(wallCommentsProvider((userId: widget.wallUserId, communityId: widget.communityId)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao comentar: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: context.nexusTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendSticker(StickerModel sticker) async {
    setState(() {
      _pendingStickerUrl = sticker.imageUrl;
      _pendingStickerId = sticker.id;
      _pendingStickerName = sticker.name;
      _pendingPackId = sticker.packId.isNotEmpty ? sticker.packId : null;
    });
    await _send();
  }

  // Mídia unificada: abre dialog para escolher imagem ou vídeo
  Future<void> _pickMedia() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.image_outlined, color: context.nexusTheme.accentPrimary),
              title: const Text('Imagem', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              leading: Icon(Icons.videocam_outlined, color: context.nexusTheme.accentPrimary),
              title: const Text('Vídeo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'video'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'image') {
      await _doPickImage();
    } else {
      await _doPickVideo();
    }
  }

  Future<void> _doPickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() => _isUploadingMedia = true);
    try {
      final rawBytes = await file.readAsBytes();
      final bytes = await MediaUtils.compressImage(rawBytes);
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final path = 'wall/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await SupabaseService.storage.from('post_media').uploadBinary(path, bytes);
      final url = SupabaseService.storage.from('post_media').getPublicUrl(path);
      if (mounted) {
        setState(() {
          _pendingMediaUrl = url;
          _pendingMediaType = 'image';
          _pendingMediaBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar imagem'), backgroundColor: context.nexusTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  Future<void> _doPickVideo() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60),
    );
    if (file == null) return;
    setState(() => _isUploadingMedia = true);
    try {
      final bytes = await file.readAsBytes();
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final path = 'wall/$userId/${DateTime.now().millisecondsSinceEpoch}.mp4';
      await SupabaseService.storage.from('post_media').uploadBinary(
        path, bytes,
        fileOptions: const FileOptions(contentType: 'video/mp4'),
      );
      final url = SupabaseService.storage.from('post_media').getPublicUrl(path);
      if (mounted) {
        setState(() {
          _pendingMediaUrl = url;
          _pendingMediaType = 'video';
          _pendingMediaBytes = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar vídeo'), backgroundColor: context.nexusTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  Future<void> _toggleLike(WallComment comment) async {
    try {
      await SupabaseService.rpc('toggle_wall_comment_like', params: {
        'p_comment_id': comment.id,
      });
      ref.invalidate(wallCommentsProvider((userId: widget.wallUserId, communityId: widget.communityId)));
    } catch (e) {
      debugPrint('[WallCommentSheet] toggleLike: $e');
    }
  }

  Future<void> _deleteComment(WallComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text('Excluir comentário', style: TextStyle(color: context.nexusTheme.textPrimary)),
        content: Text('Tem certeza que deseja excluir este comentário?',
            style: TextStyle(color: Colors.grey[400])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[500])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseService.rpc('delete_wall_comment', params: {
        'p_comment_id': comment.id,
        'p_wall_user_id': widget.wallUserId,
      });
      ref.invalidate(wallCommentsProvider((userId: widget.wallUserId, communityId: widget.communityId)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir'), backgroundColor: context.nexusTheme.error),
        );
      }
    }
  }

  void _setReply(WallComment comment) {
    setState(() => _replyingTo = comment);
    _textCtrl.text = '@${comment.author['nickname'] ?? 'usuário'} ';
    _textCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _textCtrl.text.length),
    );
    _focusNode.requestFocus();
  }

  void _clearReply() {
    setState(() => _replyingTo = null);
    if (_textCtrl.text.startsWith('@')) _textCtrl.clear();
  }

  void _clearMedia() {
    setState(() {
      _pendingMediaUrl = null;
      _pendingMediaType = null;
      _pendingMediaBytes = null;
      _pendingStickerUrl = null;
      _pendingStickerId = null;
      _pendingStickerName = null;
      _pendingPackId = null;
    });
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final commentsAsync = ref.watch(wallCommentsProvider((userId: widget.wallUserId, communityId: widget.communityId)));
    // Captura o viewInsets aqui no build (onde o NestedScrollView ainda propaga)
    // e injeta manualmente no MediaQuery dos filhos.
    final mq = MediaQuery.of(context);
    final keyboardHeight = mq.viewInsets.bottom;

    // Layout sempre inline fixo: composer no topo, lista de comentários abaixo.
    // O campo de texto fica sempre visível — ao tocar, o teclado abre direto.
    return Column(
      children: [
        // Composer fixo no topo
        _buildComposer(r, keyboardHeight),
        // Lista de comentários ocupa o restante
        Expanded(child: _buildCommentList(r, null, commentsAsync)),
      ],
    );
  }

  Widget _buildCommentList(
    Responsive r,
    ScrollController? scrollCtrl,
    AsyncValue<List<WallComment>> commentsAsync,
  ) {
    return commentsAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: context.nexusTheme.accentPrimary),
      ),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.grey[600], size: 48),
            const SizedBox(height: 12),
            Text(
              'Erro ao carregar comentários',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(wallCommentsProvider((userId: widget.wallUserId, communityId: widget.communityId))),
              child: Text('Tentar novamente', style: TextStyle(color: context.nexusTheme.accentPrimary)),
            ),
          ],
        ),
      ),
      data: (comments) {
        if (comments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline_rounded, color: Colors.grey[700], size: r.s(48)),
                SizedBox(height: r.s(12)),
                Text(
                  'Nenhum comentário ainda',
                  style: TextStyle(color: Colors.grey[500], fontSize: r.fs(14)),
                ),
                SizedBox(height: r.s(4)),
                Text(
                  'Seja o primeiro a comentar!',
                  style: TextStyle(color: Colors.grey[600], fontSize: r.fs(12)),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: context.nexusTheme.accentPrimary,
          backgroundColor: context.surfaceColor,
          onRefresh: () async => ref.invalidate(wallCommentsProvider((userId: widget.wallUserId, communityId: widget.communityId))),
          child: ListView.builder(
            controller: scrollCtrl,
            padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
            itemCount: comments.length,
            itemBuilder: (_, i) => _WallCommentCard(
              comment: comments[i],
              wallUserId: widget.wallUserId,
              isOwnWall: widget.isOwnWall,
              onReply: _setReply,
              onLike: _toggleLike,
              onDelete: _deleteComment,
            ),
          ),
        );
      },
    );
  }

  Widget _buildComposer(Responsive r, double keyboardHeight) {
    final hasContent = _pendingMediaUrl != null || _pendingStickerUrl != null;
    // Padding inferior: quando teclado aberto, adiciona a altura do teclado
    // para empurrar o composer acima dele.
    final bottomPad = keyboardHeight > 0
        ? keyboardHeight + MediaQuery.of(context).padding.bottom
        : MediaQuery.of(context).padding.bottom + r.s(4);

    return Container(
      color: context.nexusTheme.backgroundPrimary,
      padding: EdgeInsets.fromLTRB(r.s(16), r.s(12), r.s(16), bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Banner de reply
          if (_replyingTo != null)
            Container(
              margin: EdgeInsets.only(bottom: r.s(8)),
              padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(6)),
              decoration: BoxDecoration(
                color: context.nexusTheme.accentPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(r.s(8)),
              ),
              child: Row(
                children: [
                  Icon(Icons.reply_rounded, color: context.nexusTheme.accentPrimary, size: r.s(14)),
                  SizedBox(width: r.s(6)),
                  Expanded(
                    child: Text(
                      'Respondendo @${_replyingTo!.author['nickname'] ?? 'usuário'}',
                      style: TextStyle(
                        color: context.nexusTheme.accentPrimary,
                        fontSize: r.fs(12),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _clearReply,
                    child: Icon(Icons.close_rounded, color: Colors.grey[500], size: r.s(16)),
                  ),
                ],
              ),
            ),

          // Preview de mídia / sticker pendente
          if (hasContent)
            Container(
              margin: EdgeInsets.only(bottom: r.s(8)),
              child: Row(
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(r.s(8)),
                        child: _pendingStickerUrl != null
                            ? CachedNetworkImage(
                                imageUrl: _pendingStickerUrl!,
                                width: r.s(52),
                                height: r.s(52),
                                fit: BoxFit.contain,
                              )
                            : _pendingMediaBytes != null
                                ? Image.memory(
                                    _pendingMediaBytes!,
                                    width: r.s(52),
                                    height: r.s(52),
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: r.s(52),
                                    height: r.s(52),
                                    decoration: BoxDecoration(
                                      color: context.nexusTheme.surfacePrimary,
                                      borderRadius: BorderRadius.circular(r.s(8)),
                                    ),
                                    child: Icon(
                                      _pendingMediaType == 'video'
                                          ? Icons.videocam_rounded
                                          : Icons.image_rounded,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _clearMedia,
                          child: Container(
                            width: r.s(18),
                            height: r.s(18),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded, color: Colors.white, size: r.s(11)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: r.s(10)),
                  Text(
                    _pendingStickerUrl != null
                        ? 'Figurinha selecionada'
                        : _pendingMediaType == 'video'
                            ? 'Vídeo selecionado'
                            : 'Imagem selecionada',
                    style: TextStyle(color: Colors.grey[400], fontSize: r.fs(12)),
                  ),
                ],
              ),
            ),

          // Linha principal: campo de texto + botão enviar
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Campo de texto com borda
              Expanded(
                child: Container(
                  constraints: BoxConstraints(maxHeight: r.s(120)),
                  decoration: BoxDecoration(
                    color: context.nexusTheme.surfacePrimary,
                    borderRadius: BorderRadius.circular(r.s(24)),
                    border: Border.all(
                      color: _focusNode.hasFocus
                          ? context.nexusTheme.accentPrimary
                          : Colors.white.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Input
                      Expanded(
                        child: TextField(
                          controller: _textCtrl,
                          focusNode: _focusNode,
                          maxLines: null,
                          style: TextStyle(color: context.nexusTheme.textPrimary, fontSize: r.fs(14)),
                          decoration: InputDecoration(
                            hintText: _replyingTo != null
                                ? 'Respondendo...'
                                : 'Escreva no mural...',
                            hintStyle: TextStyle(color: Colors.grey[600], fontSize: r.fs(14)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: r.s(14),
                              vertical: r.s(10),
                            ),
                          ),
                          onTap: () {
                            if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
                          },
                        ),
                      ),
                      // Botão unificado: emoji + figurinha + mídia
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: r.s(4)),
                        child: CommentMediaMenuButton(
                          isUploadingMedia: _isUploadingMedia,
                          showEmojiPicker: _showEmojiPicker,
                          onToggleEmoji: () {
                            _focusNode.unfocus();
                            setState(() => _showEmojiPicker = !_showEmojiPicker);
                          },
                          onOpenSticker: () async {
                            _focusNode.unfocus();
                            await StickerPickerV2.show(
                              context,
                              onStickerSelected: _sendSticker,
                            );
                          },
                          onPickMedia: _isUploadingMedia ? null : _pickMedia,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(width: r.s(8)),

              // Botão enviar
              GestureDetector(
                onTap: _isSending ? null : _send,
                child: Container(
                  width: r.s(42),
                  height: r.s(42),
                  decoration: BoxDecoration(
                    color: context.nexusTheme.accentPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: _isSending
                      ? Padding(
                          padding: EdgeInsets.all(r.s(10)),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Icons.send_rounded, color: Colors.white, size: r.s(20)),
                ),
              ),
            ],
          ),

          // Emoji Picker (abre abaixo do campo)
          if (_showEmojiPicker)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: (_, emoji) {
                  final pos = _textCtrl.selection.baseOffset;
                  final text = _textCtrl.text;
                  final newText = pos < 0
                      ? text + emoji.emoji
                      : text.substring(0, pos) + emoji.emoji + text.substring(pos);
                  _textCtrl.value = TextEditingValue(
                    text: newText,
                    selection: TextSelection.collapsed(
                      offset: (pos < 0 ? newText.length : pos + emoji.emoji.length),
                    ),
                  );
                },
                config: Config(
                  columns: 8,
                  emojiSizeMax: 28,
                  bgColor: context.nexusTheme.backgroundPrimary,
                  indicatorColor: context.nexusTheme.accentPrimary,
                  iconColorSelected: context.nexusTheme.accentPrimary,
                  iconColor: Colors.grey[600] ?? Colors.grey,
                  checkPlatformCompatibility: true,
                  recentTabBehavior: RecentTabBehavior.RECENT,
                  recentsLimit: 20,
                  noRecents: Text(
                    'Sem emojis recentes',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// CARD DE COMENTÁRIO
// =============================================================================

class _WallCommentCard extends StatelessWidget {
  final WallComment comment;
  final String wallUserId;
  final bool isOwnWall;
  final void Function(WallComment) onReply;
  final void Function(WallComment) onLike;
  final void Function(WallComment) onDelete;

  const _WallCommentCard({
    required this.comment,
    required this.wallUserId,
    required this.isOwnWall,
    required this.onReply,
    required this.onLike,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final currentUserId = SupabaseService.currentUserId;
    final canDelete = isOwnWall || comment.authorId == currentUserId;

    return Padding(
      padding: EdgeInsets.only(bottom: r.s(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comentário principal
          _CommentRow(
            comment: comment,
            canDelete: canDelete,
            onReply: () => onReply(comment),
            onLike: () => onLike(comment),
            onDelete: () => onDelete(comment),
          ),

          // Replies
          if (comment.replies.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: r.s(40), top: r.s(8)),
              child: Column(
                children: comment.replies.map((reply) {
                  final canDeleteReply = isOwnWall || reply.authorId == currentUserId;
                  return Padding(
                    padding: EdgeInsets.only(bottom: r.s(10)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Linha vertical de reply
                        Container(
                          width: 2,
                          height: r.s(40),
                          margin: EdgeInsets.only(right: r.s(10)),
                          color: context.nexusTheme.accentPrimary.withValues(alpha: 0.25),
                        ),
                        Expanded(
                          child: _CommentRow(
                            comment: reply,
                            canDelete: canDeleteReply,
                            isReply: true,
                            onReply: () => onReply(comment), // reply ao pai
                            onLike: () => onLike(reply),
                            onDelete: () => onDelete(reply),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// ROW DE UM COMENTÁRIO (reutilizado para comentário e reply)
// =============================================================================

class _CommentRow extends StatelessWidget {
  final WallComment comment;
  final bool canDelete;
  final bool isReply;
  final VoidCallback onReply;
  final VoidCallback onLike;
  final VoidCallback onDelete;

  const _CommentRow({
    required this.comment,
    required this.canDelete,
    this.isReply = false,
    required this.onReply,
    required this.onLike,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final authorId = comment.authorId;
    final nickname = comment.author['nickname'] as String? ?? 'Usuário';
    final iconUrl = comment.author['icon_url'] as String?;
    final timeStr = timeago.format(comment.createdAt, locale: 'pt_BR');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        GestureDetector(
          onTap: () => context.push('/user/$authorId'),
          child: CosmeticAvatar(
            userId: authorId,
            avatarUrl: iconUrl,
            size: isReply ? r.s(28) : r.s(36),
          ),
        ),
        SizedBox(width: r.s(8)),

        // Conteúdo
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: nome + tempo + delete
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.push('/user/$authorId'),
                    child: Text(
                      nickname,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: context.nexusTheme.textPrimary,
                        fontSize: isReply ? r.fs(12) : r.fs(13),
                      ),
                    ),
                  ),
                  SizedBox(width: r.s(6)),
                  Text(
                    timeStr,
                    style: TextStyle(color: Colors.grey[600], fontSize: r.fs(11)),
                  ),
                  const Spacer(),
                  if (canDelete)
                    GestureDetector(
                      onTap: onDelete,
                      child: Icon(Icons.close_rounded, color: Colors.grey[600], size: r.s(14)),
                    ),
                ],
              ),

              SizedBox(height: r.s(4)),

              // Conteúdo: texto, sticker, imagem ou vídeo
              if (comment.isSticker)
                _StickerDisplay(
                  stickerUrl: comment.stickerUrl!,
                  stickerName: comment.stickerName,
                  packId: comment.packId,
                )
              else if (comment.isVideo)
                _VideoDisplay(url: comment.mediaUrl!)
              else if (comment.isMedia)
                _ImageDisplay(url: comment.mediaUrl!)
              else if (comment.content.isNotEmpty &&
                  comment.content != '[sticker]' &&
                  comment.content != '[image]' &&
                  comment.content != '[video]')
                Text(
                  comment.content,
                  style: TextStyle(
                    color: context.nexusTheme.textPrimary,
                    fontSize: r.fs(13),
                    height: 1.4,
                  ),
                ),

              // Se há texto E mídia
              if ((comment.isMedia || comment.isSticker) &&
                  comment.content.isNotEmpty &&
                  comment.content != '[sticker]' &&
                  comment.content != '[image]' &&
                  comment.content != '[video]') ...[
                SizedBox(height: r.s(4)),
                Text(
                  comment.content,
                  style: TextStyle(
                    color: context.nexusTheme.textPrimary,
                    fontSize: r.fs(13),
                    height: 1.4,
                  ),
                ),
              ],

              SizedBox(height: r.s(6)),

              // Ações: curtir + responder
              Row(
                children: [
                  GestureDetector(
                    onTap: onLike,
                    child: Row(
                      children: [
                        Icon(
                          comment.isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: comment.isLiked ? Colors.red : Colors.grey[600],
                          size: r.s(14),
                        ),
                        if (comment.likesCount > 0) ...[
                          SizedBox(width: r.s(3)),
                          Text(
                            '${comment.likesCount}',
                            style: TextStyle(
                              color: comment.isLiked ? Colors.red : Colors.grey[600],
                              fontSize: r.fs(11),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: r.s(14)),
                  GestureDetector(
                    onTap: onReply,
                    child: Row(
                      children: [
                        Icon(Icons.reply_rounded, color: Colors.grey[600], size: r.s(14)),
                        SizedBox(width: r.s(3)),
                        Text(
                          'Responder',
                          style: TextStyle(color: Colors.grey[600], fontSize: r.fs(11)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// DISPLAYS DE MÍDIA
// =============================================================================

class _StickerDisplay extends ConsumerWidget {
  final String stickerUrl;
  final String? stickerName;
  final String? packId;

  const _StickerDisplay({
    required this.stickerUrl,
    this.stickerName,
    this.packId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    return GestureDetector(
      onLongPress: () {
        // Mostrar opções de salvar/favoritar
        showModalBottomSheet(
          context: context,
          backgroundColor: context.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(16))),
          ),
          builder: (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.favorite_border_rounded, color: context.nexusTheme.accentPrimary),
                  title: Text('Favoritar figurinha',
                      style: TextStyle(color: context.nexusTheme.textPrimary)),
                  onTap: () async {
                    Navigator.pop(context);
                    final sticker = StickerModel(
                      id: stickerUrl,
                      packId: packId ?? '',
                      name: stickerName ?? '',
                      imageUrl: stickerUrl,
                    );
                    await StickerRepository.instance.toggleFavorite(
                      stickerId: sticker.id,
                      stickerUrl: sticker.imageUrl,
                      packId: packId,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Figurinha favoritada!'),
                          backgroundColor: context.nexusTheme.accentPrimary,
                        ),
                      );
                    }
                  },
                ),
                if (packId != null)
                  ListTile(
                    leading: Icon(Icons.bookmark_border_rounded, color: context.nexusTheme.accentSecondary),
                    title: Text('Salvar pack', style: TextStyle(color: context.nexusTheme.textPrimary)),
                    onTap: () async {
                      Navigator.pop(context);
                      await StickerRepository.instance.savePack(packId!);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Pack salvo!'),
                            backgroundColor: context.nexusTheme.accentSecondary,
                          ),
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
      child: CachedNetworkImage(
        imageUrl: stickerUrl,
        width: 120,
        height: 120,
        fit: BoxFit.contain,
        placeholder: (_, __) => Container(
          width: 120,
          height: 120,
          color: Colors.transparent,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.nexusTheme.accentPrimary,
            ),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.sticky_note_2_outlined, color: Colors.grey[500], size: 32),
        ),
      ),
    );
  }
}

class _ImageDisplay extends StatelessWidget {
  final String url;
  const _ImageDisplay({required this.url});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    // Usa TappableImage para abrir o ImageViewer com suporte a salvar
    return TappableImage(
      url: url,
      width: r.s(220),
      height: r.s(220),
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(r.s(10)),
      heroTag: 'wall_comment_img_$url',
    );
  }
}

class _VideoDisplay extends StatefulWidget {
  final String url;
  const _VideoDisplay({required this.url});

  @override
  State<_VideoDisplay> createState() => _VideoDisplayState();
}

class _VideoDisplayState extends State<_VideoDisplay> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return ClipRRect(
      borderRadius: BorderRadius.circular(r.s(10)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: r.s(220), maxHeight: r.s(180)),
        child: _initialized
            ? GestureDetector(
                onTap: () {
                  setState(() {
                    _playing = !_playing;
                    _playing ? _ctrl.play() : _ctrl.pause();
                  });
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _ctrl.value.aspectRatio,
                      child: VideoPlayer(_ctrl),
                    ),
                    if (!_playing)
                      Container(
                        width: r.s(44),
                        height: r.s(44),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: r.s(28)),
                      ),
                  ],
                ),
              )
            : Container(
                width: r.s(160),
                height: r.s(120),
                color: Colors.grey[800],
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.nexusTheme.accentPrimary,
                  ),
                ),
              ),
      ),
    );
  }
}



// _MediaMenuButton e _ActionButton removidas (unused_element)
/*
class _MediaMenuButton extends StatelessWidget {
  final dynamic r;
  final bool isUploadingMedia;
  final bool showEmojiPicker;
  final VoidCallback onToggleEmoji;
  final Future<void> Function() onOpenSticker;
  final VoidCallback? onPickMedia;

  const _MediaMenuButton({
    required this.r,
    required this.isUploadingMedia,
    required this.showEmojiPicker,
    required this.onToggleEmoji,
    required this.onOpenSticker,
    required this.onPickMedia,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showMenu(context),
      child: SizedBox(
        width: r.s(30),
        height: r.s(30),
        child: Icon(
          showEmojiPicker
              ? Icons.add_reaction
              : Icons.add_reaction_outlined,
          size: r.s(22),
          color: showEmojiPicker
              ? context.nexusTheme.accentPrimary
              : Colors.grey[500],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      elevation: 8,
      color: const Color(0xFF1A2332),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      items: [
        PopupMenuItem<String>(
          value: 'emoji',
          padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(4)),
          child: Row(
            children: [
              Icon(Icons.emoji_emotions_outlined,
                  color: Colors.amber[400], size: r.s(20)),
              SizedBox(width: r.s(10)),
              Text(
                'Emoji',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.s(14),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'sticker',
          padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(4)),
          child: Row(
            children: [
              Icon(Icons.sticky_note_2_outlined,
                  color: Colors.purple[300], size: r.s(20)),
              SizedBox(width: r.s(10)),
              Text(
                'Figurinha',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.s(14),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'media',
          enabled: !isUploadingMedia,
          padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(4)),
          child: Row(
            children: [
              isUploadingMedia
                  ? SizedBox(
                      width: r.s(20),
                      height: r.s(20),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.nexusTheme.accentPrimary,
                      ),
                    )
                  : Icon(Icons.perm_media_outlined,
                      color: Colors.blue[300], size: r.s(20)),
              SizedBox(width: r.s(10)),
              Text(
                'Mídia',
                style: TextStyle(
                  color: isUploadingMedia ? Colors.grey[600] : Colors.white,
                  fontSize: r.s(14),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'emoji') {
        onToggleEmoji();
      } else if (value == 'sticker') {
        onOpenSticker();
      } else if (value == 'media' && onPickMedia != null) {
        onPickMedia!();
      }
    });
  }
}
*/
