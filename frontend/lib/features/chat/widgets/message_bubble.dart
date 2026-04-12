import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/message_model.dart';
import '../../../core/providers/cosmetics_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../stickers/widgets/sticker_message_bubble.dart';
import 'chat_bubble.dart' show ChatBubble;
import 'voice_recorder.dart' show VoiceNotePlayer;

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
  // Stickers: sem borda/bubble
  if (type == 'sticker') return true;
  if (message.stickerUrl != null) return true;
  // Retrocompatibilidade: tipo 'text' com media_type de mídia
  if (message.mediaUrl != null && message.mediaType == 'image') return true;
  if (message.mediaUrl != null && message.mediaType == 'gif') return true;
  if (message.mediaUrl != null && message.mediaType == 'video') return true;
  return false;
}

class MessageBubble extends ConsumerWidget {
  final MessageModel message;
  final bool isMe;
  final bool showAvatar;
  final void Function(String emoji)? onReactionTap;
  /// ID da comunidade à qual este chat pertence.
  /// Quando fornecido, ao clicar no avatar/nome do autor navega para
  /// o perfil do usuário dentro da comunidade em vez do perfil global.
  final String? communityId;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.showAvatar,
    this.onReactionTap,
    this.communityId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final _specialType = message.type;

    // ── Tipos system especiais com UI própria (devem vir ANTES do isSystemMessage genérico) ──
    if (_specialType == 'system_screen_end') {
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
                  'Sala de Projeção encerrada',
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
      final container = Container(
        padding: EdgeInsets.all(r.s(12)),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(r.s(12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accentColor),
            SizedBox(width: r.s(8)),
            Text(label,
                style: TextStyle(fontWeight: FontWeight.w600, color: accentColor)),
            if (!isVoice) ...[SizedBox(width: r.s(8)), Icon(Icons.arrow_forward_ios_rounded, color: accentColor, size: r.s(12))],
          ],
        ),
      );
      return Padding(
        padding: EdgeInsets.symmetric(vertical: r.s(8)),
        child: Center(
          child: !isVoice && threadId.isNotEmpty
              ? GestureDetector(
                  onTap: () => context.push('/screening-room/$threadId'),
                  child: container,
                )
              : container,
        ),
      );
    }

    // System messages genéricos (system_join, system_leave, etc.)
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

    // Determina o bubbleFrameUrl para o ChatBubble
    // Se tem image_url no bubble, usa como frame; senão usa 'procedural:style'
    String? bubbleFrameUrl;
    Color? bubbleColor;
    if (activeBubbleStyle != null && activeBubbleStyle.isNotEmpty) {
      if (activeBubbleImageUrl != null && activeBubbleImageUrl.isNotEmpty) {
        bubbleFrameUrl = activeBubbleImageUrl;
      } else {
        bubbleFrameUrl = 'procedural:$activeBubbleStyle';
      }
    }
    if (activeBubbleColor != null && activeBubbleColor.isNotEmpty) {
      try {
        final hex = activeBubbleColor.replaceAll('#', '');
        bubbleColor = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    Widget buildAuthorAvatar() {
      return GestureDetector(
        onTap: () {
          if (communityId != null && communityId!.isNotEmpty) {
            context.push('/community/$communityId/profile/${message.authorId}');
          } else {
            context.push('/user/${message.authorId}');
          }
        },
        child: CircleAvatar(
          radius: 16,
          backgroundColor: context.surfaceColor,
          backgroundImage: authorIcon != null && authorIcon.isNotEmpty
              ? CachedNetworkImageProvider(authorIcon)
              : null,
          child: authorIcon == null || authorIcon.isEmpty
              ? Text(
                  avatarFallbackLabel.isNotEmpty
                      ? avatarFallbackLabel[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: r.fs(11),
                    color: Colors.grey[400],
                  ),
                )
              : null,
        ),
      );
    }

    return Padding(
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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                buildAuthorAvatar(),
                SizedBox(width: r.s(8)),
              ],
              Flexible(
                child: isMediaOnly
                    // ── Mídia sem bubble: apenas nome do autor + conteúdo + hora ──
                    ? Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(bottom: r.s(2)),
                            child: Text(
                              authorName,
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: r.fs(11),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          // Conteúdo de mídia (imagem/gif/vídeo)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(r.s(12)),
                            child: _buildContent(context),
                          ),
                          // Hora sobreposta abaixo da mídia
                          Padding(
                            padding: EdgeInsets.only(top: r.s(2)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatTime(message.createdAt),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: r.fs(10),
                                  ),
                                ),
                                if (message.isEdited) ...[
                                  SizedBox(width: r.s(4)),
                                  Text(
                                    'editado',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: r.fs(9),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      )
                    // ── Mensagem com bubble cosmético (texto, áudio, etc.) ──
                    : bubbleFrameUrl != null || bubbleColor != null
                        // Bubble cosmético da loja
                        ? ChatBubble(
                            isMine: isMe,
                            bubbleFrameUrl: bubbleFrameUrl,
                            bubbleColor: bubbleColor,
                            showTail: showAvatar,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(bottom: r.s(4)),
                                  child: Text(
                                    authorName,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: r.fs(11),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                _buildContent(context),
                                Padding(
                                  padding: EdgeInsets.only(top: r.s(isAudioType ? 2 : 4)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatTime(message.createdAt),
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.6),
                                          fontSize: r.fs(10),
                                        ),
                                      ),
                                      if (message.isEdited) ...[
                                        SizedBox(width: r.s(4)),
                                        Text(
                                          'editado',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.45),
                                            fontSize: r.fs(9),
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        // Bubble padrão (sem cosmético)
                        : Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: r.s(isAudioType ? 8 : 14),
                                vertical: r.s(isAudioType ? 4 : 10)),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? AppTheme.primaryColor
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(bottom: r.s(4)),
                                  child: Text(
                                    authorName,
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white.withValues(alpha: 0.9)
                                          : AppTheme.primaryColor,
                                      fontSize: r.fs(11),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                _buildContent(context),
                                Padding(
                                  padding: EdgeInsets.only(top: r.s(isAudioType ? 2 : 4)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatTime(message.createdAt),
                                        style: TextStyle(
                                          color: isMe
                                              ? Colors.white.withValues(alpha: 0.6)
                                              : Colors.grey[600],
                                          fontSize: r.fs(10),
                                        ),
                                      ),
                                      if (message.isEdited) ...[
                                        SizedBox(width: r.s(4)),
                                        Text(
                                          'editado',
                                          style: TextStyle(
                                            color: isMe
                                                ? Colors.white
                                                    .withValues(alpha: 0.45)
                                                : Colors.grey[600],
                                            fontSize: r.fs(9),
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
              if (isMe) ...[
                SizedBox(width: r.s(8)),
                buildAuthorAvatar(),
              ],
            ],
          ),
          // ── Reações abaixo do bubble ──
          if (message.reactions.isNotEmpty) _buildReactionsRow(context),
        ],
      ),
    );
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
                      ? AppTheme.primaryColor.withValues(alpha: 0.25)
                      : context.surfaceColor,
                  borderRadius: BorderRadius.circular(r.s(10)),
                  border: Border.all(
                    color: iReacted
                        ? AppTheme.primaryColor.withValues(alpha: 0.5)
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
                            iReacted ? AppTheme.primaryColor : Colors.grey[500],
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

  Widget _buildContent(BuildContext context) {
    final s = getStrings();
    final r = context.r;
    final type = message.type;
    final textColor = isMe ? Colors.white : context.textPrimary;

    // Imagem: tipo 'image' (nativo) OU tipo 'text' com media_type == 'image' (legado)
    if ((type == 'image' && message.mediaUrl != null) ||
        (message.mediaUrl != null && message.mediaType == 'image')) {
      return CachedNetworkImage(
        imageUrl: message.mediaUrl!,
        width: r.s(220),
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: r.s(220),
          height: r.s(160),
          color: Colors.grey[800],
          child:
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) => Container(
          width: r.s(220),
          height: r.s(160),
          color: Colors.grey[800],
          child: Icon(Icons.broken_image_rounded,
              color: Colors.grey[600], size: r.s(32)),
        ),
      );
    }

    // GIF: tipo 'gif' (nativo) OU tipo 'text' com media_type == 'gif' (legado)
    if ((type == 'gif' && message.mediaUrl != null) ||
        (message.mediaUrl != null && message.mediaType == 'gif')) {
      return CachedNetworkImage(
        imageUrl: message.mediaUrl!,
        width: r.s(200),
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => Container(
          width: r.s(200),
          height: r.s(150),
          color: Colors.grey[800],
          child: Icon(Icons.gif_rounded, color: Colors.grey[600], size: r.s(32)),
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
      return Container(
        width: r.s(220),
        height: r.s(160),
        color: Colors.black45,
        child: Center(
          child: Icon(Icons.play_circle_rounded,
              color: Colors.white, size: r.s(48)),
        ),
      );
    }

    // System messages (tip, voice start, etc.)
    if (type == 'system_tip') {
      final amount = message.tipAmount ?? 0;
      return Container(
        padding: EdgeInsets.all(r.s(12)),
        decoration: BoxDecoration(
          color: AppTheme.warningColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(r.s(12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monetization_on_rounded,
                color: AppTheme.warningColor),
            SizedBox(width: r.s(8)),
            Text(s.amountCoins(amount),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppTheme.warningColor)),
          ],
        ),
      );
    }

    // Sala de Projeção encerrada
    if (type == 'system_screen_end') {
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
              'Sala de Projeção encerrada',
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
      final container = Container(
        padding: EdgeInsets.all(r.s(12)),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(r.s(12)),
        ),
        child: Row(
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
      );
      // Sala de Projeção é clicável para entrar na sala
      if (!isVoice && threadId.isNotEmpty) {
        return GestureDetector(
          onTap: () => context.push('/screening-room/$threadId'),
          child: container,
        );
      }
      return container;
    }

    // Link (share_url)
    if (type == 'share_url' || message.sharedUrl != null) {
      final url = message.sharedUrl ?? message.content ?? '';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(r.s(10)),
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(r.s(8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.link_rounded, color: textColor, size: r.s(16)),
                SizedBox(width: r.s(8)),
                Flexible(
                  child: Text(
                    url,
                    style: TextStyle(
                      color: textColor,
                      fontSize: r.fs(13),
                      decoration: TextDecoration.underline,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (message.content != null &&
              message.content != url &&
              message.content!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: r.s(4)),
              child: Text(message.content!,
                  style: TextStyle(color: textColor, fontSize: r.fs(14))),
            ),
        ],
      );
    }

    // Poll (armazenado como text com JSON no content)
    if (message.content != null && message.content!.startsWith('{"question"')) {
      try {
        // Tentar parsear o JSON do poll
        final content = message.content!;
        final questionMatch =
            RegExp(r'"question":"([^"]*)"').firstMatch(content);
        final question = questionMatch?.group(1) ?? s.poll;
        final optionsMatch = RegExp(r'"options":\[(.*?)\]').firstMatch(content);
        final optionsStr = optionsMatch?.group(1) ?? '';
        final options = RegExp(r'"([^"]*)"')
            .allMatches(optionsStr)
            .map((m) => m.group(1) ?? '')
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('\uD83D\uDCCA $question',
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: r.fs(14))),
            SizedBox(height: r.s(8)),
            ...options.map((opt) => Container(
                  margin: EdgeInsets.only(bottom: r.s(4)),
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(12), vertical: r.s(8)),
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(r.s(8)),
                  ),
                  child: Text(opt,
                      style: TextStyle(color: textColor, fontSize: r.fs(13))),
                )),
          ],
        );
      } catch (_) {
        // Se falhar o parse, mostra como texto normal
      }
    }

    // Reply (tipo text com reply_to_id)
    if (message.replyToId != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(r.s(8)),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.5)
                        : AppTheme.primaryColor,
                    width: r.s(3)),
              ),
            ),
            child: Text(
              'Respondendo...',
              style: TextStyle(
                color: isMe
                    ? Colors.white.withValues(alpha: 0.6)
                    : Colors.grey[500],
                fontSize: r.fs(11),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          SizedBox(height: r.s(4)),
          Text(message.content ?? '',
              style: TextStyle(color: textColor, fontSize: r.fs(14))),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(r.s(8)),
              child: CachedNetworkImage(
                imageUrl: message.mediaUrl!,
                width: r.s(200),
                fit: BoxFit.cover,
              ),
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

    // Default: texto simples
    return Text(
      message.content ?? '',
      style: TextStyle(color: textColor, fontSize: r.fs(14)),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
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
