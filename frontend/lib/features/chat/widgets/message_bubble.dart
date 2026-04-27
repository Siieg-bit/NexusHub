import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/message_model.dart';
import '../../../core/providers/cosmetics_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/call_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../screens/call_screen.dart';
import '../../stickers/widgets/sticker_message_bubble.dart';
import 'chat_bubble.dart' show ChatBubble;
import 'voice_recorder.dart' show VoiceNotePlayer;
import '../../../core/widgets/image_viewer.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widgets/linkified_text.dart';
import 'form_message_bubble.dart';
import '../../../core/widgets/simple_link_preview.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../../core/widgets/member_title_badge.dart';
import '../../../core/widgets/nexus_image.dart';

/// ============================================================================
/// MESSAGE BUBBLE (suporta todos os 19+ tipos) — Estilo Amino
///
/// Extraído de chat_room_screen.dart para reduzir o tamanho do arquivo
/// principal e isolar a lógica de renderização de mensagens.
/// ============================================================================

/// Tipos de mensagem que NÃO devem ter a borda/bubble ao redor.
/// Imagem, GIF, vídeo e sticker são renderizados sem container de fundo.
bool _isMediaOnlyType(MessageModel message) {
  final type = message.type;
  if (type == 'image' && message.mediaUrl != null) return true;
  if (type == 'gif' && message.mediaUrl != null) return true;
  if (type == 'video') return true;
  // Mensagens otimistas (upload em andamento ou com erro) são sem bubble
  if (message.uploadState != null) return true;
  // Stickers: sem borda/bubble
  if (type == 'sticker') return true;
  if (message.stickerUrl != null) return true;
  // Retrocompatibilidade: tipo 'text' com media_type de mídia
  if (message.mediaUrl != null && message.mediaType == 'image') return true;
  if (message.mediaUrl != null && message.mediaType == 'gif') return true;
  if (message.mediaUrl != null && message.mediaType == 'video') return true;
  return false;
}

class MessageBubble extends ConsumerStatefulWidget {
  final MessageModel message;
  final bool isMe;
  final bool showAvatar;
  final void Function(String emoji)? onReactionTap;
  final bool showAuthorName;
  /// ID da comunidade à qual este chat pertence.
  /// Quando fornecido, ao clicar no avatar/nome do autor navega para
  /// o perfil do usuário dentro da comunidade em vez do perfil global.
  final String? communityId;
  final MessageModel? repliedMessage;
  final VoidCallback? onReplyTap;
  /// ID do host do chat — usado para exibir badge de cargo no nome do autor.
  final String? hostId;
  /// IDs dos co-hosts do chat — usado para exibir badge de cargo no nome do autor.
  final List<String> coHostIds;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.showAvatar,
    this.onReactionTap,
    this.showAuthorName = true,
    this.communityId,
    this.repliedMessage,
    this.onReplyTap,
    this.hostId,
    this.coHostIds = const [],
  });

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble> {
  bool _showTime = false;

  // Atalhos para acessar os campos do widget sem repetir widget. em todo lugar
  MessageModel get message => widget.message;
  bool get isMe => widget.isMe;
  bool get showAvatar => widget.showAvatar;
  void Function(String emoji)? get onReactionTap => widget.onReactionTap;
  bool get showAuthorName => widget.showAuthorName;
  String? get communityId => widget.communityId;
  MessageModel? get repliedMessage => widget.repliedMessage;
  VoidCallback? get onReplyTap => widget.onReplyTap;
  String? get hostId => widget.hostId;
  List<String> get coHostIds => widget.coHostIds;

  /// Retorna o badge de cargo do autor da mensagem, se houver.
  Widget? _buildRoleBadge(BuildContext context, Responsive r) {
    final authorId = message.authorId;
    if (authorId.isEmpty) return null;
    if (authorId == hostId) {
      return Container(
        margin: EdgeInsets.only(left: r.s(4)),
        padding: EdgeInsets.symmetric(horizontal: r.s(5), vertical: r.s(1)),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(r.s(4)),
          border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5), width: 0.8),
        ),
        child: Text(
          'Host',
          style: TextStyle(
            color: const Color(0xFFFFD700),
            fontSize: r.fs(9),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    if (coHostIds.contains(authorId)) {
      return Container(
        margin: EdgeInsets.only(left: r.s(4)),
        padding: EdgeInsets.symmetric(horizontal: r.s(5), vertical: r.s(1)),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(r.s(4)),
          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5), width: 0.8),
        ),
        child: Text(
          'Co-host',
          style: TextStyle(
            color: Colors.blueAccent,
            fontSize: r.fs(9),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return null;
  }

  String _truncatePreview(String value) {
    final sanitized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (sanitized.length <= 90) return sanitized;
    return '${sanitized.substring(0, 87)}...';
  }

  String _replyAuthorLabel(MessageModel? repliedMessage, String fallbackUserLabel) {
    if (repliedMessage == null) return 'Mensagem original';
    final nickname = repliedMessage.author?.nickname;
    if (nickname != null && nickname.trim().isNotEmpty) {
      return nickname.trim();
    }
    return fallbackUserLabel;
  }

  String _replyPreviewText(MessageModel? repliedMessage, String fallbackFileLabel) {
    if (repliedMessage == null) {
      return 'Mensagem original indisponível.';
    }

    final content = repliedMessage.content?.trim();
    final type = repliedMessage.type;
    final mediaType = repliedMessage.mediaType;

    if (content != null && content.isNotEmpty) {
      return _truncatePreview(content);
    }
    if (repliedMessage.stickerUrl != null || type == 'sticker') return 'Sticker';
    if (type == 'image' || mediaType == 'image') return 'Imagem';
    if (type == 'gif' || mediaType == 'gif') return 'GIF';
    if (type == 'video' || mediaType == 'video') return 'Vídeo';
    if (type == 'voice') return 'Áudio';
    if (type == 'poll') return 'Enquete';
    if (type == 'file') return fallbackFileLabel;
    return 'Mensagem';
  }

  Widget _buildReplyReference(
    BuildContext context,
    Responsive r,
    Color textColor, {
    required String fallbackUserLabel,
    required String fallbackFileLabel,
  }) {
    final accentColor = isMe
        ? Colors.white.withValues(alpha: 0.82)
        : context.nexusTheme.accentPrimary;
    final subtitleColor = isMe
        ? Colors.white.withValues(alpha: 0.72)
        : Colors.grey[400]!;
    final previewAuthor = _replyAuthorLabel(repliedMessage, fallbackUserLabel);
    final previewText = _replyPreviewText(repliedMessage, fallbackFileLabel);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onReplyTap,
        borderRadius: BorderRadius.circular(r.s(12)),
        child: Ink(
          padding: EdgeInsets.all(r.s(10)),
          decoration: BoxDecoration(
            // Usa cor fixa semitransparente para evitar fundo branco/inválido
            // quando textColor é claro (ex: textPrimary no bubble de outro usuário).
            color: isMe
                ? Colors.white.withValues(alpha: 0.12)
                : context.nexusTheme.surfacePrimary.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(r.s(12)),
            border: Border(
              left: BorderSide(color: accentColor, width: r.s(3)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      previewAuthor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: r.fs(11),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: r.s(4)),
                    Text(
                      previewText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: r.fs(12),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (onReplyTap != null) ...[
                SizedBox(width: r.s(8)),
                Icon(
                  Icons.reply_rounded,
                  size: r.s(16),
                  color: accentColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final _specialType = message.type;

    // ── Tipos system especiais com UI própria (devem vir ANTES do isSystemMessage genérico) ──
    if (_specialType == 'system_screen_end') {
      final endLabel = message.content?.isNotEmpty == true
          ? message.content!
          : 'Sala de Projeção encerrada';
      return Padding(
        padding: EdgeInsets.symmetric(vertical: r.s(8)),
        child: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(r.s(12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tv_off_rounded, color: Colors.grey[600], size: r.s(16)),
                SizedBox(width: r.s(8)),
                Text(
                  endLabel,
                  style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12)),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_specialType == 'system_voice_end') {
      final endLabel = message.content?.isNotEmpty == true
          ? message.content!
          : 'Voice Chat encerrado';
      return Padding(
        padding: EdgeInsets.symmetric(vertical: r.s(8)),
        child: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(r.s(12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mic_off_rounded, color: Colors.grey[600], size: r.s(16)),
                SizedBox(width: r.s(8)),
                Text(
                  endLabel,
                  style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_specialType == 'system_voice_start' || _specialType == 'system_screen_start') {
      final isVoice = _specialType == 'system_voice_start';
      final icon = isVoice ? Icons.headset_mic_rounded : Icons.live_tv_rounded;
      final label = isVoice ? 'Voice Chat' : 'Sala de Projeção';
      final accentColor = isVoice ? const Color(0xFF4CAF50) : const Color(0xFFFF5722);
      final threadId = message.threadId;
      // Exibe o nome do iniciador a partir do conteúdo da mensagem
      final initiatorText = message.content?.isNotEmpty == true ? message.content! : null;
      final container = Container(
        padding: EdgeInsets.all(r.s(12)),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(r.s(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: accentColor),
                SizedBox(width: r.s(8)),
                Text(label,
                    style: TextStyle(fontWeight: FontWeight.w600, color: accentColor)),
                if (!isVoice) ...[SizedBox(width: r.s(8)), Icon(Icons.arrow_forward_ios_rounded, color: accentColor, size: r.s(12))],
              ],
            ),
            if (initiatorText != null) ...[  
              SizedBox(height: r.s(4)),
              Text(
                initiatorText,
                style: TextStyle(color: accentColor.withValues(alpha: 0.75), fontSize: r.fs(11)),
              ),
            ],
          ],
        ),
      );
      return Padding(
        padding: EdgeInsets.symmetric(vertical: r.s(8)),
        child: Center(
          child: GestureDetector(
            onTap: () async {
              if (threadId.isEmpty) return;

              if (!isVoice) {
                context.push('/screening-room/$threadId');
                return;
              }

              var loadingVisible = false;
              try {
                loadingVisible = true;
                showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext) {
                    return PopScope(
                      canPop: false,
                      child: AlertDialog(
                        content: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.2),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text('Abrindo voice chat...'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ).then((_) => loadingVisible = false);

                // Usar joinExistingCall: entra apenas em uma call já ativa.
                // O usuário clicou explicitamente em "Entrar" — esta é a única
                // forma de participar de uma call iniciada por outro usuário.
                final session = await CallService.joinExistingCall(
                  threadId: threadId,
                  type: CallType.voice,
                );

                if (loadingVisible && context.mounted) {
                  Navigator.of(context, rootNavigator: true).pop();
                }

                if (session == null) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Esta chamada já foi encerrada.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                if (!context.mounted) return;
                await CallScreen.show(context, session);
              } catch (e, st) {
                if (loadingVisible && context.mounted) {
                  Navigator.of(context, rootNavigator: true).pop();
                }

                final report = [
                  '===== MESSAGE BUBBLE VOICE CALL UNCAUGHT EXCEPTION =====',
                  'threadId: $threadId',
                  'messageId: ${message.id}',
                  'error: $e',
                  'stackTrace:',
                  st.toString(),
                  '===== END MESSAGE BUBBLE VOICE CALL UNCAUGHT EXCEPTION =====',
                ].join('\n');
                debugPrint(report);

                if (!context.mounted) return;
                await showDialog<void>(
                  context: context,
                  builder: (dialogContext) {
                    return AlertDialog(
                      title: const Text('Exceção ao abrir chamada'),
                      content: SizedBox(
                        width: 560,
                        child: SingleChildScrollView(
                          child: SelectableText(report),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Fechar'),
                        ),
                      ],
                    );
                  },
                );
              }
            },
            child: container,
          ),
        ),
      );
    }

    // System messages com nome do autor em azul clicável (system_join, system_leave, system_deleted, system_removed, system_admin_delete)
    if (message.isSystemMessage &&
        (_specialType == 'system_join' ||
            _specialType == 'system_leave' ||
            _specialType == 'system_deleted' ||
            _specialType == 'system_removed' ||
            _specialType == 'system_admin_delete')) {
      final s = getStrings();
      final authorName = message.author?.nickname ?? '';
      final authorId = message.authorId;
      String actionText;
      if (_specialType == 'system_join') {
        // Extrai só a parte do texto sem o nome do usuário
        final fullJoinMsg = s.userJoinedTheChat(authorName.isNotEmpty ? authorName : '\u200B');
        actionText = fullJoinMsg.replaceFirst(authorName.isNotEmpty ? authorName : '\u200B', '').trim();
        if (actionText.isEmpty) actionText = 'entrou no chat.';
      } else if (_specialType == 'system_leave') {
        final fullLeaveMsg = s.userLeftTheChat(authorName.isNotEmpty ? authorName : '\u200B');
        actionText = fullLeaveMsg.replaceFirst(authorName.isNotEmpty ? authorName : '\u200B', '').trim();
        if (actionText.isEmpty) actionText = 'saiu do chat.';
      } else {
        // system_deleted, system_removed, system_admin_delete
        // Extrai só a parte do texto sem o nome do usuário
        final fullDeletedMsg = s.userDeletedMessage(authorName.isNotEmpty ? authorName : '\u200B');
        actionText = fullDeletedMsg.replaceFirst(authorName.isNotEmpty ? authorName : '\u200B', '').trim();
        if (actionText.isEmpty) actionText = 'excluiu uma mensagem.';
      }
      return Padding(
        padding: EdgeInsets.symmetric(vertical: r.s(6)),
        child: Center(
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                if (authorName.isNotEmpty) ...
                  [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: GestureDetector(
                        onTap: () {
                          if (authorId.isEmpty) return;
                          if (communityId != null && communityId!.isNotEmpty) {
                            context.push('/community/$communityId/profile/$authorId');
                          } else {
                            context.push('/user/$authorId');
                          }
                        },
                        child: Text(
                          authorName,
                          style: TextStyle(
                            color: context.nexusTheme.accentPrimary,
                            fontSize: r.fs(13),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    TextSpan(
                      text: ' $actionText',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: r.fs(13),
                      ),
                    ),
                  ]
                else
                  TextSpan(
                    text: message.content ?? actionText,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: r.fs(13),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // System messages genéricos (system_pin, system_unpin, system_tip, etc.)
    if (message.isSystemMessage) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: r.s(8)),
        child: Center(
          child: Container(
            padding:
                EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(6)),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(r.s(12)),
            ),
            child: Text(
              message.content ?? '',
              style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12)),
            ),
          ),
        ),
      );
    }

    final isMediaOnly = _isMediaOnlyType(message);
    final isAudioType = message.type == 'audio' || message.type == 'voice_note';
    final selfLabel = Localizations.localeOf(context).languageCode == 'pt'
        ? 'Eu'
        : 'Me';
    final realAuthorName = message.author?.nickname ?? 'User';
    final authorName = isMe ? selfLabel : realAuthorName;
    final shouldShowAuthorName = showAuthorName && authorName.trim().isNotEmpty;
    final avatarFallbackLabel =
        realAuthorName.isNotEmpty ? realAuthorName : authorName;
    final authorIcon = message.author?.iconUrl;

    // ── Cosméticos do remetente (frame + bubble) ──
    // Usa o tipo explícito AsyncValue<UserCosmetics> para evitar inferência como Object
    final authorId = message.authorId;
    UserCosmetics? senderCosmetics;
    if (authorId.isNotEmpty) {
      final AsyncValue<UserCosmetics> senderAsync =
          ref.watch(userCosmeticsProvider(authorId));
      senderCosmetics = senderAsync.valueOrNull;
    }

    // Bubble: só aplica cosméticos nas mensagens do remetente (não nas minhas)
    // Para as minhas mensagens, aplica os cosméticos do usuário atual
    final myId = SupabaseService.currentUserId ?? '';
    UserCosmetics? myCosmetics;
    if (isMe && myId.isNotEmpty) {
      final AsyncValue<UserCosmetics> myAsync =
          ref.watch(userCosmeticsProvider(myId));
      myCosmetics = myAsync.valueOrNull;
    }

    final activeBubbleStyle = isMe
        ? myCosmetics?.chatBubbleStyle
        : senderCosmetics?.chatBubbleStyle;
    final activeBubbleColor = isMe
        ? myCosmetics?.chatBubbleColor
        : senderCosmetics?.chatBubbleColor;
    final activeBubbleImageUrl = isMe
        ? myCosmetics?.chatBubbleImageUrl
        : senderCosmetics?.chatBubbleImageUrl;

    // Parâmetros nine-slice vindos do asset_config (via UserCosmetics)
    final activeCosmetics = isMe ? myCosmetics : senderCosmetics;
    final bubbleSliceInsets = activeCosmetics?.chatBubbleSliceInsets;
    final bubbleImageSize = activeCosmetics?.chatBubbleImageSize;
    final bubbleContentPadding = activeCosmetics?.chatBubbleContentPadding;
    // Parâmetros do modo dynamic_nineslice (retrocompatíveis — null = modo clássico)
    final bubbleMode = activeCosmetics?.chatBubbleMode;
    final bubbleDynMaxWidth = activeCosmetics?.chatBubbleDynMaxWidth ?? 260.0;
    final bubbleDynMinWidth = activeCosmetics?.chatBubbleDynMinWidth ?? 60.0;
    final bubbleDynPaddingX = activeCosmetics?.chatBubbleDynPaddingX ?? 16.0;
    final bubbleDynPaddingY = activeCosmetics?.chatBubbleDynPaddingY ?? 12.0;
    final bubbleDynHorizontalPriority = activeCosmetics?.chatBubbleDynHorizontalPriority ?? true;
    final bubbleDynTransitionZone = activeCosmetics?.chatBubbleDynTransitionZone ?? 0.15;
    // Parâmetros do modo horizontal_stretch
    final bubbleHsMaxWidth = activeCosmetics?.chatBubbleHsMaxWidth ?? 280.0;
    final bubbleHsMinWidth = activeCosmetics?.chatBubbleHsMinWidth ?? 60.0;
    final bubbleHsPaddingX = activeCosmetics?.chatBubbleHsPaddingX ?? 4.0;
    final bubbleHsPaddingY = activeCosmetics?.chatBubbleHsPaddingY ?? 4.0;
    // Indica se o bubble equipado é animado (GIF/WebP).
    // Quando true, ChatBubble usa Image.network com gaplessPlayback
    // em vez de NineSliceBubble (que só suporta frames estáticos).
    final isBubbleAnimated = activeCosmetics?.isChatBubbleAnimated ?? false;

    // Determina o bubbleFrameUrl para o ChatBubble.
    // Prioridade: image_url > procedural:style > null (bubble padrão)
    String? bubbleFrameUrl;
    Color? bubbleColor;
    if (activeBubbleImageUrl != null && activeBubbleImageUrl.isNotEmpty) {
      // Tem imagem (nine-slice ou qualquer frame) — usa diretamente
      bubbleFrameUrl = activeBubbleImageUrl;
    } else if (activeBubbleStyle != null && activeBubbleStyle.isNotEmpty) {
      // Sem imagem mas com estilo procedural
      bubbleFrameUrl = 'procedural:$activeBubbleStyle';
    }
    if (activeBubbleColor != null && activeBubbleColor.isNotEmpty) {
      try {
        final hex = activeBubbleColor.replaceAll('#', '');
        bubbleColor = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    Widget buildAuthorAvatar() {
      return CosmeticAvatar(
        userId: message.authorId.isNotEmpty ? message.authorId : null,
        avatarUrl: authorIcon,
        size: r.s(36),
        onTap: () {
          if (communityId != null && communityId!.isNotEmpty) {
            context.push('/community/$communityId/profile/${message.authorId}');
          } else {
            context.push('/user/${message.authorId}');
          }
        },
      );
    }

    // Widget do horário exibido abaixo do bubble ao clicar
    Widget timeWidget = AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      child: _showTime
          ? Padding(
              padding: EdgeInsets.only(
                top: r.s(2),
                left: isMe ? 0 : r.s(40),
              ),
              child: Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: r.fs(10),
                      ),
                    ),
                    if (message.isEdited) ...[  
                      SizedBox(width: r.s(4)),
                      Text(
                        'editado',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: r.fs(9),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );

    return GestureDetector(
      onTap: () => setState(() => _showTime = !_showTime),
      behavior: HitTestBehavior.translucent,
      child: Padding(
      padding: EdgeInsets.only(
        bottom: showAvatar ? 8 : 2,
        left: isMe ? 60 : 0,
        right: isMe ? 0 : 60,
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe) ...[
                buildAuthorAvatar(),
                SizedBox(width: r.s(8)),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Nome do autor ACIMA do balão ──────────────────────────
                    if (shouldShowAuthorName) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              authorName,
                              style: TextStyle(
                                color: context.nexusTheme.accentPrimary,
                                fontSize: r.fs(12.5),
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_buildRoleBadge(context, r) != null)
                            _buildRoleBadge(context, r)!,
                        ],
                      ),
                      // Título de membro (apenas em chats de comunidade)
                      if (!isMe &&
                          communityId != null &&
                          communityId!.isNotEmpty &&
                          message.authorId.isNotEmpty)
                        MemberTitleBadge(
                          userId: message.authorId,
                          communityId: communityId!,
                          fontSize: 9,
                        ),
                      SizedBox(height: r.s(2)),
                    ],
                    // ── Conteúdo (mídia ou bubble) ────────────────────────────
                    isMediaOnly
                        // Mídia sem bubble
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(r.s(12)),
                            child: _buildContent(context),
                          )
                        // ── Mensagem com bubble cosmético (texto, áudio, etc.) ──
                        : bubbleFrameUrl != null || bubbleColor != null
                            // Bubble cosmético da loja
                            ? ChatBubble(
                                isMine: isMe,
                                bubbleFrameUrl: bubbleFrameUrl,
                                bubbleColor: bubbleColor,
                                showTail: showAvatar,
                                isBubbleAnimated: isBubbleAnimated,
                                sliceInsets: bubbleSliceInsets,
                                imageSize: bubbleImageSize,
                                contentPadding: bubbleContentPadding,
                                bubbleTextColor: activeCosmetics?.chatBubbleTextColor,
                                polyPoints: activeCosmetics?.chatBubblePolyPoints,
                                bubbleMode: bubbleMode,
                                dynMaxWidth: bubbleDynMaxWidth,
                                dynMinWidth: bubbleDynMinWidth,
                                dynPaddingX: bubbleDynPaddingX,
                                dynPaddingY: bubbleDynPaddingY,
                                dynHorizontalPriority: bubbleDynHorizontalPriority,
                                dynTransitionZone: bubbleDynTransitionZone,
                                hsMaxWidth: bubbleHsMaxWidth,
                                hsMinWidth: bubbleHsMinWidth,
                                hsPaddingX: bubbleHsPaddingX,
                                hsPaddingY: bubbleHsPaddingY,
                                child: _buildContent(
                                  context,
                                  bubbleTextColor: activeCosmetics?.chatBubbleTextColor,
                                ),
                              )
                            // Bubble padrão (sem cosmético)
                            : Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: r.s(isAudioType ? 8 : 14),
                                    vertical: r.s(isAudioType ? 4 : 10)),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? context.nexusTheme.accentPrimary
                                      : context.surfaceColor,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(
                                        isMe ? 16 : (showAvatar ? 4 : 16)),
                                    bottomRight: Radius.circular(
                                        isMe ? (showAvatar ? 4 : 16) : 16),
                                  ),
                                ),
                                child: _buildContent(context),
                              ),
                  ],
                ),
              ),
              if (isMe) ...[
                SizedBox(width: r.s(8)),
                buildAuthorAvatar(),
              ],
            ],
          ),
          // ── Horário abaixo do bubble (visível ao clicar) ──
          timeWidget,
          // ── Reações abaixo do bubble ──
          if (message.reactions.isNotEmpty) _buildReactionsRow(context),
        ],
      ),
    ), // Padding
    ); // GestureDetector
  }

  Widget _buildReactionsRow(BuildContext context) {
    final r = context.r;
    // reactions é Map<emoji, List<userId>> ou Map<emoji, dynamic>
    final reactionMap = <String, List<String>>{};
    message.reactions.forEach((key, value) {
      if (value is List) {
        reactionMap[key] = List<String>.from(value);
      }
    });
    if (reactionMap.isEmpty) return const SizedBox.shrink();

    final currentUserId = SupabaseService.currentUserId;

    return Padding(
      padding: EdgeInsets.only(
        top: r.s(2),
        left: isMe ? 0 : r.s(40),
        right: isMe ? 0 : 0,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Wrap(
          spacing: r.s(4),
          runSpacing: r.s(2),
          children: reactionMap.entries.map((entry) {
            final emoji = entry.key;
            final users = entry.value;
            final iReacted = users.contains(currentUserId);
            return GestureDetector(
              onTap: () => onReactionTap?.call(emoji),
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: r.s(6), vertical: r.s(2)),
                decoration: BoxDecoration(
                  color: iReacted
                      ? context.nexusTheme.accentPrimary.withValues(alpha: 0.25)
                      : context.surfaceColor,
                  borderRadius: BorderRadius.circular(r.s(10)),
                  border: Border.all(
                    color: iReacted
                        ? context.nexusTheme.accentPrimary.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: TextStyle(fontSize: r.fs(14))),
                    SizedBox(width: r.s(2)),
                    Text(
                      '${users.length}',
                      style: TextStyle(
                        fontSize: r.fs(10),
                        color:
                            iReacted ? context.nexusTheme.accentPrimary : Colors.grey[500],
                        fontWeight:
                            iReacted ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, {Color? bubbleTextColor}) {
    final s = getStrings();
    final r = context.r;
    final type = message.type;
    // Se o bubble tem cor customizada (asset_config.text_color), usa ela.
    // Caso contrário, usa a cor padrão baseada em isMe.
    final textColor = bubbleTextColor ??
        (isMe ? Colors.white : context.nexusTheme.textPrimary);

    // ── Upload otimista: exibe thumbnail local + spinner ou retry ─────────────────
    if (message.uploadState != null && message.localPath != null) {
      final isVideo = message.mediaType == 'video' || message.type == 'video';
      final hasError = message.uploadState == 'error';
      return Stack(
        alignment: Alignment.center,
        children: [
          // Thumbnail local
          ClipRRect(
            borderRadius: BorderRadius.circular(r.s(12)),
            child: isVideo
                ? Container(
                    width: r.s(220),
                    height: r.s(160),
                    color: Colors.black87,
                    child: Center(
                      child: Icon(Icons.videocam_rounded,
                          color: Colors.white38, size: r.s(40)),
                    ),
                  )
                : message.localBytes != null
                    ? Image.memory(
                        message.localBytes!,
                        width: r.s(220),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: r.s(220),
                          height: r.s(160),
                          color: Colors.grey[800],
                          child: Icon(Icons.broken_image_rounded,
                              color: Colors.white38, size: r.s(40)),
                        ),
                      )
                    : Image.file(
                        File(message.localPath!),
                        width: r.s(220),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: r.s(220),
                          height: r.s(160),
                          color: Colors.grey[800],
                          child: Icon(Icons.broken_image_rounded,
                              color: Colors.white38, size: r.s(40)),
                        ),
                      ),
          ),
          // Overlay escuro
          ClipRRect(
            borderRadius: BorderRadius.circular(r.s(12)),
            child: Container(
              width: r.s(220),
              height: isVideo ? r.s(160) : null,
              color: Colors.black.withValues(alpha: hasError ? 0.6 : 0.4),
            ),
          ),
          // Spinner ou ícone de erro + retry
          if (!hasError)
            SizedBox(
              width: r.s(36),
              height: r.s(36),
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            )
          else
            GestureDetector(
              onTap: message.onRetry,
              child: Container(
                padding: EdgeInsets.all(r.s(10)),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.refresh_rounded,
                    color: Colors.white, size: r.s(22)),
              ),
            ),
          // Botão X de cancelamento (apenas durante upload, não em erro)
          if (!hasError && message.onCancel != null)
            Positioned(
              top: r.s(6),
              right: r.s(6),
              child: GestureDetector(
                onTap: message.onCancel,
                child: Container(
                  width: r.s(26),
                  height: r.s(26),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: r.s(16),
                  ),
                ),
              ),
            ),
          // Label de status
          Positioned(
            bottom: r.s(8),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: r.s(8), vertical: r.s(3)),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(r.s(8)),
              ),
              child: Text(
                hasError ? 'Toque para reenviar' : 'Enviando...',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: r.fs(11),
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      );
    }

    // Imagem: tipo 'image' (nativo) OU tipo 'text' com media_type == 'image' (legado)
    if ((type == 'image' && message.mediaUrl != null) ||
        (message.mediaUrl != null && message.mediaType == 'image')) {
      final imgUrl = message.mediaUrl!;
      return GestureDetector(
        onTap: () => showSingleImageViewer(
          context,
          imageUrl: imgUrl,
          heroTag: 'chat_img_${message.id}',
        ),
        onLongPress: () => showSingleImageViewer(
          context,
          imageUrl: imgUrl,
          heroTag: 'chat_img_${message.id}',
        ),
        child: Hero(
          tag: 'chat_img_${message.id}',
          child: NexusImage(
            imageUrl: imgUrl,
            blurhash: message.mediaBlurhash,
            width: r.s(220),
            fit: BoxFit.cover,
            borderRadius: BorderRadius.circular(r.s(12)),
            errorWidget: Container(
              width: r.s(220),
              height: r.s(160),
              color: Colors.grey[800],
              child: Icon(Icons.broken_image_rounded,
                  color: Colors.grey[600], size: r.s(32)),
            ),
          ),
        ),
      );
    }

    // GIF: tipo 'gif' (nativo) OU tipo 'text' com media_type == 'gif' (legado)
    if ((type == 'gif' && message.mediaUrl != null) ||
        (message.mediaUrl != null && message.mediaType == 'gif')) {
      final gifUrl = message.mediaUrl!;
      return GestureDetector(
        onTap: () => showSingleImageViewer(
          context,
          imageUrl: gifUrl,
          heroTag: 'chat_gif_${message.id}',
        ),
        onLongPress: () => showSingleImageViewer(
          context,
          imageUrl: gifUrl,
          heroTag: 'chat_gif_${message.id}',
        ),
        child: Hero(
          tag: 'chat_gif_${message.id}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(r.s(12)),
            child: CachedNetworkImage(
              imageUrl: gifUrl,
              width: r.s(200),
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                width: r.s(200),
                height: r.s(150),
                color: Colors.grey[800],
                child: Icon(Icons.gif_rounded, color: Colors.grey[600], size: r.s(32)),
              ),
            ),
          ),
        ),
      );
    }

    // Sticker — usa StickerMessageBubble com suporte a favoritar/salvar pack
    if (type == 'sticker' || message.stickerUrl != null) {
      final rawUrl = message.stickerUrl ?? message.mediaUrl;
      final url = (rawUrl != null && rawUrl.isNotEmpty) ? rawUrl : null;
      if (url != null) {
        return StickerMessageBubble(
          stickerId: message.stickerId ?? url,
          stickerUrl: url,
          stickerName: message.content ?? '',
          packId: message.packId,
          isSentByMe: isMe,
          size: r.s(120),
        );
      }
      // Sticker emoji padrão: renderizar o conteúdo textual da mensagem
      final emoji = (message.content != null && message.content!.isNotEmpty)
          ? message.content!
          : '\uD83C\uDFAD';
      return Text(emoji, style: TextStyle(fontSize: r.fs(48)));
    }

    // Áudio: tipo 'audio' (nativo, gravado pelo VoiceRecorder) ou 'voice_note' (legado)
    if (type == 'audio' || type == 'voice_note') {
      final audioUrl = message.mediaUrl;
      final duration = message.mediaDuration ?? 0;
      if (audioUrl != null && audioUrl.isNotEmpty) {
        return VoiceNotePlayer(
          audioUrl: audioUrl,
          durationSeconds: duration,
          isMine: isMe,
        );
      }
      // Fallback sem URL (mensagem legada sem media_url)
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_circle_rounded, color: textColor, size: r.s(32)),
          SizedBox(width: r.s(8)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.audio2,
                  style: TextStyle(color: textColor, fontSize: r.fs(13))),
              if (duration > 0)
                Text('${duration}s',
                    style: TextStyle(
                        color: textColor.withValues(alpha: 0.6),
                        fontSize: r.fs(11))),
              Container(
                width: r.s(120),
                height: r.s(4),
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Video — sem bubble, renderizado diretamente (ClipRRect aplicado no build)
    if (type == 'video') {
      final videoUrl = message.mediaUrl ?? '';
      return GestureDetector(
        onTap: videoUrl.isNotEmpty
            ? () => context.push(
                  Uri(
                    path: '/video-player',
                    queryParameters: {'url': videoUrl},
                  ).toString(),
                )
            : null,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: r.s(220),
              height: r.s(160),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(r.s(4)),
              ),
              child: videoUrl.isEmpty
                  ? Center(
                      child: Icon(Icons.videocam_off_rounded,
                          color: Colors.white38, size: r.s(36)),
                    )
                  : null,
            ),
            Container(
              width: r.s(56),
              height: r.s(56),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: r.s(32)),
            ),
            if (videoUrl.isNotEmpty)
              Positioned(
                bottom: r.s(8),
                right: r.s(8),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(6), vertical: r.s(2)),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(r.s(4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam_rounded,
                          color: Colors.white70, size: r.s(12)),
                      SizedBox(width: r.s(3)),
                      Text('Vídeo',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: r.fs(10))),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // System messages (tip, voice start, etc.)
    if (type == 'system_tip') {
      final amount = message.tipAmount ?? 0;
      return Container(
        padding: EdgeInsets.all(r.s(12)),
        decoration: BoxDecoration(
          color: context.nexusTheme.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(r.s(12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monetization_on_rounded,
                color: context.nexusTheme.warning),
            SizedBox(width: r.s(8)),
            Text(s.amountCoins(amount),
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: context.nexusTheme.warning)),
          ],
        ),
      );
    }

    // Sala de Projeção encerrada
    if (type == 'system_screen_end') {
      final endLabel = message.content?.isNotEmpty == true
          ? message.content!
          : 'Sala de Projeção encerrada';
      return Container(
        padding: EdgeInsets.all(r.s(12)),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(r.s(12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tv_off_rounded, color: Colors.grey[600], size: r.s(20)),
            SizedBox(width: r.s(8)),
            Text(
              endLabel,
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }
    // Voice Chat encerrado
    if (type == 'system_voice_end') {
      final endLabel = message.content?.isNotEmpty == true
          ? message.content!
          : 'Voice Chat encerrado';
      return Container(
        padding: EdgeInsets.all(r.s(12)),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(r.s(12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic_off_rounded, color: Colors.grey[600], size: r.s(20)),
            SizedBox(width: r.s(8)),
            Text(
              endLabel,
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    if (type == 'system_voice_start' || type == 'system_screen_start') {
      final isVoice = type == 'system_voice_start';
      final icon = isVoice ? Icons.headset_mic_rounded : Icons.live_tv_rounded;
      final label = isVoice ? 'Voice Chat' : 'Sala de Projeção';
      final accentColor =
          isVoice ? const Color(0xFF4CAF50) : const Color(0xFFFF5722);
      final threadId = message.threadId;
      // Exibe o nome do iniciador a partir do conteúdo da mensagem
      final initiatorText = message.content?.isNotEmpty == true ? message.content! : null;
      final container = Container(
        padding: EdgeInsets.all(r.s(12)),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(r.s(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: accentColor),
                SizedBox(width: r.s(8)),
                Text(label,
                    style:
                        TextStyle(fontWeight: FontWeight.w600, color: accentColor)),
                if (!isVoice) ...[
                  SizedBox(width: r.s(8)),
                  Icon(Icons.arrow_forward_ios_rounded,
                      color: accentColor, size: r.s(12)),
                ],
              ],
            ),
            if (initiatorText != null) ...[  
              SizedBox(height: r.s(4)),
              Text(
                initiatorText,
                style: TextStyle(color: accentColor.withValues(alpha: 0.75), fontSize: r.fs(11)),
              ),
            ],
          ],
        ),
      );
      // Sala de Projeção é clicável para entrar na sala
      if (!isVoice && threadId.isNotEmpty) {
        return GestureDetector(
          onTap: () async {
            // Verificar se ainda existe uma sessão ativa para este thread
            // antes de navegar, para evitar entrar em sessão já encerrada.
            try {
              final result = await SupabaseService.client.rpc(
                'get_active_screening_session',
                params: {'p_thread_id': threadId},
              );
              if (!context.mounted) return;
              if (result == null || (result as List).isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Esta projeção já foi encerrada.'),
                    duration: Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              final sessionId = (result as List).first['id'] as String?;
              context.push(
                '/screening-room/$threadId${sessionId != null ? '?sessionId=\$sessionId' : ''}',
              );
            } catch (_) {
              if (context.mounted) context.push('/screening-room/$threadId');
            }
          },
          child: container,
        );
      }
      return container;
    }

    // Link (share_url) — clicável com preview
    if (type == 'share_url' || message.sharedUrl != null) {
      final url = message.sharedUrl ?? message.content ?? '';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () async {
              final uri = Uri.tryParse(url);
              if (uri != null) {
                // Verificar se é link interno do app
                final host = uri.host;
                if (host.isEmpty || host.contains('aminexus') || host.contains('nexushub')) {
                  final path = uri.path;
                  if (path.isNotEmpty && context.mounted) {
                    context.push(path);
                    return;
                  }
                }
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
            child: SimpleLinkPreview(url: url),
          ),
          if (message.content != null &&
              message.content != url &&
              message.content!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: r.s(4)),
              child: LinkifiedText(
                text: message.content!,
                style: TextStyle(color: textColor, fontSize: r.fs(14)),
                linkStyle: TextStyle(
                  color: context.nexusTheme.accentSecondary,
                  fontSize: r.fs(14),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ],
      );
    }

    // Form (tipo 'form' com extra_data contendo form_id)
    if (type == 'form' && message.extraData != null) {
      final formId = message.extraData?['form_id'] as String?;
      final formTitle = message.extraData?['form_title'] as String? ?? 'Formulário';
      final formDesc = message.extraData?['form_description'] as String?;
      final fieldsRaw = message.extraData?['fields'];
      final allowMultiple = message.extraData?['allow_multiple'] as bool? ?? false;

      List<Map<String, dynamic>> fields = [];
      if (fieldsRaw is List) {
        fields = fieldsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }

      if (formId != null && fields.isNotEmpty) {
        return FormMessageBubble(
          formId: formId,
          formTitle: formTitle,
          formDescription: formDesc,
          fields: fields,
          isMe: isMe,
          allowMultipleResponses: allowMultiple,
        );
      }
    }

    // Poll do chat (armazenado como JSON em content e votado por message_id)
    if (type == 'poll' || message.isPoll) {
      return _ChatPollBubble(
        message: message,
        isMe: isMe,
      );
    }

    // Reply (tipo text com reply_to_id)
    if (message.replyToId != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReplyReference(
            context,
            r,
            textColor,
            fallbackUserLabel: s.user,
            fallbackFileLabel: s.file,
          ),
          SizedBox(height: r.s(6)),
          Text(
            message.content ?? '',
            style: TextStyle(color: textColor, fontSize: r.fs(14)),
          ),
        ],
      );
    }

    // File attachment
    if (type == 'file') {
      final fileName = message.content ?? s.file;
      return Container(
        padding: EdgeInsets.all(r.s(10)),
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(r.s(8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.attach_file_rounded, color: textColor, size: r.s(20)),
            SizedBox(width: r.s(8)),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fileName,
                      style: TextStyle(
                          color: textColor,
                          fontSize: r.fs(13),
                          fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (message.mediaUrl != null)
                    Text(s.tapToDownload,
                        style: TextStyle(
                            color: textColor.withValues(alpha: 0.6),
                            fontSize: r.fs(11))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Forward (mensagem encaminhada)
    if (type == 'forward') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.forward_rounded,
                  color: textColor.withValues(alpha: 0.5), size: r.s(14)),
              SizedBox(width: r.s(4)),
              Text(s.forwarded,
                  style: TextStyle(
                      color: textColor.withValues(alpha: 0.5),
                      fontSize: r.fs(11),
                      fontStyle: FontStyle.italic)),
            ],
          ),
          SizedBox(height: r.s(4)),
          if (message.mediaUrl != null && message.mediaType == 'image')
            NexusImage(
              imageUrl: message.mediaUrl!,
              blurhash: message.mediaBlurhash,
              width: r.s(200),
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(r.s(8)),
            )
          else
            Text(message.content ?? '',
                style: TextStyle(color: textColor, fontSize: r.fs(14))),
        ],
      );
    }

    // Shared user
    if (type == 'share_user') {
      return Container(
        padding: EdgeInsets.all(r.s(10)),
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(r.s(8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_rounded, color: textColor, size: r.s(16)),
            SizedBox(width: r.s(8)),
            Text(s.sharedProfile,
                style: TextStyle(
                    color: textColor,
                    fontSize: r.fs(13),
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    // Default: texto simples com links clicáveis
    return LinkifiedText(
      text: message.content ?? '',
      style: TextStyle(color: textColor, fontSize: r.fs(14)),
      linkStyle: TextStyle(
        color: context.nexusTheme.accentSecondary,
        fontSize: r.fs(14),
        decoration: TextDecoration.underline,
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final localDateTime = dateTime.toLocal();
    return '${localDateTime.hour.toString().padLeft(2, '0')}:${localDateTime.minute.toString().padLeft(2, '0')}';
  }
}

// ============================================================================
// MEDIA OPTION ITEM — Estilo Amino
// ============================================================================

class MediaOptionItem extends ConsumerWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const MediaOptionItem({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: r.s(52),
            height: r.s(52),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(r.s(16)),
            ),
            child: Icon(icon, color: color, size: r.s(24)),
          ),
          SizedBox(height: r.s(6)),
          Text(label,
              style: TextStyle(fontSize: r.fs(11), color: Colors.grey[500])),
        ],
      ),
    );
  }
}

class _ChatPollPayload {
  final String question;
  final List<String> options;

  const _ChatPollPayload({
    required this.question,
    required this.options,
  });

  static _ChatPollPayload? tryParse(String? rawContent) {
    if (rawContent == null || rawContent.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(rawContent);
      if (decoded is! Map) return null;

      final question = decoded['question']?.toString().trim();
      final rawOptions = decoded['options'];
      if (question == null || question.isEmpty || rawOptions is! List) {
        return null;
      }

      final options = rawOptions
          .map((option) => option.toString().trim())
          .where((option) => option.isNotEmpty)
          .toList();
      if (options.length < 2) return null;

      return _ChatPollPayload(question: question, options: options);
    } catch (_) {
      return null;
    }
  }
}

class _ChatPollBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;

  const _ChatPollBubble({
    required this.message,
    required this.isMe,
  });

  @override
  State<_ChatPollBubble> createState() => _ChatPollBubbleState();
}

class _ChatPollBubbleState extends State<_ChatPollBubble> {
  bool _isSubmitting = false;

  Future<void> _vote(int optionIndex) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      await SupabaseService.client.from('chat_poll_votes').insert({
        'message_id': widget.message.id,
        'user_id': userId,
        'option_index': optionIndex,
      });
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text('Não foi possível registrar seu voto: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final s = getStrings();
    final textColor = widget.isMe ? Colors.white : context.nexusTheme.textPrimary;
    final accentColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.92)
        : context.nexusTheme.accentPrimary;
    final payload = _ChatPollPayload.tryParse(widget.message.content);

    if (payload == null) {
      return LinkifiedText(
        text: widget.message.content ?? '',
        style: TextStyle(color: textColor, fontSize: r.fs(14)),
        linkStyle: TextStyle(
          color: context.nexusTheme.accentSecondary,
          fontSize: r.fs(14),
          decoration: TextDecoration.underline,
        ),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.client
          .from('chat_poll_votes')
          .stream(primaryKey: ['id'])
          .eq('message_id', widget.message.id),
      builder: (context, snapshot) {
        final votes = snapshot.data ?? const <Map<String, dynamic>>[];
        final counts = List<int>.filled(payload.options.length, 0);
        final currentUserId = SupabaseService.currentUserId;
        int? myVoteIndex;

        for (final vote in votes) {
          final rawIndex = vote['option_index'];
          final optionIndex = rawIndex is int
              ? rawIndex
              : int.tryParse(rawIndex?.toString() ?? '');
          if (optionIndex == null || optionIndex < 0 || optionIndex >= counts.length) {
            continue;
          }
          counts[optionIndex] += 1;
          if (currentUserId != null && vote['user_id']?.toString() == currentUserId) {
            myVoteIndex = optionIndex;
          }
        }

        final totalVotes = counts.fold<int>(0, (sum, value) => sum + value);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.poll_rounded, color: accentColor, size: r.s(18)),
                SizedBox(width: r.s(6)),
                Expanded(
                  child: Text(
                    payload.question,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: r.fs(14),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: r.s(8)),
            ...List.generate(payload.options.length, (index) {
              final option = payload.options[index];
              final votesForOption = counts[index];
              final percentage = totalVotes == 0 ? 0.0 : votesForOption / totalVotes;
              final isSelected = myVoteIndex == index;
              final canVote = myVoteIndex == null && !_isSubmitting;

              return Padding(
                padding: EdgeInsets.only(bottom: r.s(6)),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: canVote ? () => _vote(index) : null,
                    borderRadius: BorderRadius.circular(r.s(10)),
                    child: Ink(
                      decoration: BoxDecoration(
                        color: textColor.withValues(alpha: widget.isMe ? 0.10 : 0.08),
                        borderRadius: BorderRadius.circular(r.s(10)),
                        border: Border.all(
                          color: isSelected
                              ? accentColor.withValues(alpha: 0.70)
                              : textColor.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Stack(
                        children: [
                          if (totalVotes > 0)
                            FractionallySizedBox(
                              widthFactor: percentage.clamp(0.0, 1.0),
                              child: Container(
                                height: r.s(44),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: widget.isMe ? 0.16 : 0.12),
                                  borderRadius: BorderRadius.circular(r.s(10)),
                                ),
                              ),
                            ),
                          Container(
                            constraints: BoxConstraints(minHeight: r.s(44)),
                            padding: EdgeInsets.symmetric(
                              horizontal: r.s(12),
                              vertical: r.s(10),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    option,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: r.fs(13),
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                SizedBox(width: r.s(10)),
                                Text(
                                  totalVotes == 0
                                      ? s.vote
                                      : '${(percentage * 100).round()}% • $votesForOption',
                                  style: TextStyle(
                                    color: textColor.withValues(alpha: 0.78),
                                    fontSize: r.fs(11),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (isSelected) ...[
                                  SizedBox(width: r.s(6)),
                                  Icon(Icons.check_circle_rounded,
                                      color: accentColor, size: r.s(16)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            SizedBox(height: r.s(2)),
            Text(
              totalVotes == 0
                  ? 'Toque em uma opção para votar'
                  : '$totalVotes voto${totalVotes == 1 ? '' : 's'}',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.72),
                fontSize: r.fs(11),
              ),
            ),
          ],
        );
      },
    );
  }
}
