import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../../../core/widgets/emoji_rain_overlay.dart';
import '../providers/screening_chat_provider.dart';
import '../providers/screening_voice_provider.dart';
import '../providers/screening_room_provider.dart';
import '../models/screening_participant.dart';
import '../models/screening_chat_message.dart';
import '../../../chat/widgets/sticker_picker.dart';
// emoji_picker_flutter removido — usar EmojiRainCascadePicker (efeito cascata)
import 'screening_add_video_sheet.dart';

// =============================================================================
// ScreeningChatOverlay — Chat transparente (Camada 3 do Stack imersivo) — Fase 2
//
// Melhorias sobre a Fase 1:
// ─────────────────────────────────────────────────────────────────────────────
// 1. RECEPÇÃO DE REAÇÕES: subscreve ao canal de sync para o evento 'reaction'
//    e dispara EmojiRainOverlay.trigger() localmente ao receber.
//
// 2. ANÁLISE DE MENSAGENS: ao enviar/receber mensagens, chama
//    EmojiRainOverlay.analyzeAndTrigger() para disparar chuva automática
//    quando o texto contém emojis especiais (🔥❤️😂👏🎉⭐).
//
// 3. MENSAGEM DE SISTEMA: exibe mensagens de sistema (host mudou, vídeo
//    trocado) em estilo diferenciado no chat.
//
// 4. FADE DE MENSAGENS ANTIGAS: mensagens mais antigas ficam mais transparentes
//    para dar destaque às recentes.
// =============================================================================

class ScreeningChatOverlay extends ConsumerStatefulWidget {
  final String sessionId;
  final String threadId;
  /// Em modo landscape, o chat ocupa um painel lateral sem gradiente de fundo.
  final bool isLandscape;
  /// Key local do EmojiRainOverlay da tela pai para disparar animações.
  final GlobalKey<EmojiRainOverlayState>? emojiRainKey;

  const ScreeningChatOverlay({
    super.key,
    required this.sessionId,
    required this.threadId,
    this.isLandscape = false,
    this.emojiRainKey,
  });

  @override
  ConsumerState<ScreeningChatOverlay> createState() =>
      _ScreeningChatOverlayState();
}

class _ScreeningChatOverlayState extends ConsumerState<ScreeningChatOverlay> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  RealtimeChannel? _reactionChannel;
  bool _showEmojiPicker = false;
  bool _showFab = false;
  Future<bool>? _canModerateFuture;

  @override
  void initState() {
    super.initState();
    _subscribeToReactions();
    _refreshModerationPermission();
  }

  @override
  void didUpdateWidget(covariant ScreeningChatOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.threadId != widget.threadId ||
        oldWidget.sessionId != widget.sessionId) {
      _refreshModerationPermission();
    }
  }

  void _refreshModerationPermission() {
    _canModerateFuture = ref
        .read(screeningRoomProvider(widget.threadId).notifier)
        .canModerate();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _reactionChannel?.unsubscribe();
    super.dispose();
  }

  // ── Subscrição a reações via Broadcast ────────────────────────────────────────

  void _subscribeToReactions() {
    _reactionChannel = SupabaseService.client
        .channel('screening_sync_${widget.sessionId}')
      ..onBroadcast(
        event: 'reaction',
        callback: (payload) {
          if (!mounted) return;
          final reactionTypeName = payload['reaction_type'] as String?;
          if (reactionTypeName == null) return;
          try {
            final type = EmojiRainType.values.firstWhere(
              (e) => e.name == reactionTypeName,
            );
            widget.emojiRainKey?.currentState?.trigger(type);
          } catch (_) {}
        },
      )
      ..subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    // Analisar e disparar EmojiRain se houver emoji especial
    widget.emojiRainKey?.currentState?.triggerFromText(text);
    ref
        .read(screeningChatProvider(widget.sessionId).notifier)
        .sendMessage(text);
    _textController.clear();
    // Fechar o emoji picker ao enviar mensagem
    if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
    _scrollToBottom();
  }

  Future<void> _pickAndSendImage() async {
    try {
      final file = await MediaUploadService.pickImage(context: context);
      if (file == null || !mounted) return;
      final url = await MediaUploadService.uploadChatMedia(file: file);
      if (url == null || !mounted) return;
      await ref.read(screeningChatProvider(widget.sessionId).notifier).sendImage(
            imageUrl: url,
            name: file.path.split(Platform.pathSeparator).last,
          );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar imagem: $e')),
      );
    }
  }

  Future<void> _pickAndSendSticker() async {
    final sticker = await StickerPicker.show(context);
    if (sticker == null || !mounted) return;
    final stickerUrl = sticker['sticker_url'] as String?;
    if (stickerUrl == null || stickerUrl.isEmpty) return;
    await ref.read(screeningChatProvider(widget.sessionId).notifier).sendSticker(
          stickerUrl: stickerUrl,
          stickerName: sticker['sticker_name'] as String?,
        );
    _scrollToBottom();
  }

  void _showModerationError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Não foi possível aplicar esta ação de moderação.'),
      ),
    );
  }

  Future<void> _openModerationSheet() async {
    final canModerate = await ref
        .read(screeningRoomProvider(widget.threadId).notifier)
        .canModerate();
    if (!mounted || !canModerate) {
      _showModerationError();
      return;
    }

    final roomState = ref.read(screeningRoomProvider(widget.threadId));
    final currentUserId = SupabaseService.currentUserId;
    final participants = roomState.participants
        .where((p) => p.userId != currentUserId && !p.isHost)
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        if (participants.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Nenhum participante moderável na sala.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Moderação da sala',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: participants.length,
                    separatorBuilder: (_, __) => Divider(
                      color: Colors.white.withValues(alpha: 0.08),
                      height: 1,
                    ),
                    itemBuilder: (_, index) {
                      final participant = participants[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.white24,
                          backgroundImage: participant.avatarUrl != null
                              ? NetworkImage(participant.avatarUrl!)
                              : null,
                          child: participant.avatarUrl == null
                              ? Text(participant.username.isNotEmpty
                                  ? participant.username[0].toUpperCase()
                                  : '?')
                              : null,
                        ),
                        title: Text(
                          participant.username,
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                final success = await ref
                                    .read(screeningRoomProvider(widget.threadId)
                                        .notifier)
                                    .muteParticipant(participant.userId);
                                if (ctx.mounted) Navigator.of(ctx).pop();
                                if (!success) _showModerationError();
                              },
                              icon: const Icon(Icons.mic_off_rounded, size: 16),
                              label: const Text('Mutar'),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final success = await ref
                                    .read(screeningRoomProvider(widget.threadId)
                                        .notifier)
                                    .kickParticipant(participant.userId);
                                if (ctx.mounted) Navigator.of(ctx).pop();
                                if (!success) _showModerationError();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                              ),
                              icon: const Icon(Icons.person_remove_alt_1_rounded,
                                  size: 16),
                              label: const Text('Remover'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(screeningChatProvider(widget.sessionId));
    final roomState = ref.watch(screeningRoomProvider(widget.threadId));
    final voiceState = ref.watch(screeningVoiceProvider(widget.sessionId));
    final mq = MediaQuery.of(context);
    final bottomPad = mq.padding.bottom > 0 ? mq.padding.bottom : 12.0;

    // Auto-scroll quando novas mensagens chegam
    ref.listen(screeningChatProvider(widget.sessionId), (prev, next) {
      if (next.length > (prev?.length ?? 0)) {
        _scrollToBottom();
        if (next.isNotEmpty && !next.last.isMe) {
          widget.emojiRainKey?.currentState?.triggerFromText(next.last.text);
        }
      }
    });

    return Column(
      children: [
        // ── Lista de mensagens ─────────────────────────────────────────────
        Expanded(
          child: messages.isEmpty
              ? const SizedBox.shrink()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final fromEnd = messages.length - 1 - index;
                    final opacity = fromEnd >= 8
                        ? 0.0
                        : fromEnd >= 5
                            ? 0.45
                            : 1.0;
                    if (opacity == 0.0) return const SizedBox.shrink();
                    return Opacity(
                      opacity: opacity,
                      child: _ChatBubble(message: messages[index]),
                    );
                  },
                ),
        ),
        // ── Indicadores de voz ─────────────────────────────────────────────
        _VoiceParticipantsBar(
          participants: roomState.participants,
          speakingUids: voiceState.speakingAgoraUids,
        ),
        // ── Seletor de reações (efeito cascata) ────────────────────────────────
        // Substitui o EmojiPicker padrão: ao tocar em uma reação, dispara
        // o EmojiRainOverlay (chuva de emojis) em vez de inserir no texto.
        if (_showEmojiPicker)
          _EmojiCascadePicker(
            emojiRainKey: widget.emojiRainKey,
            onClose: () => setState(() => _showEmojiPicker = false),
          ),
        // ── Barra inferior: microfone + input estilo Rave ──────────────────
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Menu do FAB — renderizado acima da barra, fora do Row
            if (_showFab)
              Positioned(
                bottom: 64 + bottomPad,
                right: 12,
                child: _FabMenu(
                  onClose: () => setState(() => _showFab = false),
                  onSticker: () {
                    setState(() => _showFab = false);
                    _pickAndSendSticker();
                  },
                  onModerate: _canModerateFuture != null
                      ? () async {
                          setState(() => _showFab = false);
                          final can = await _canModerateFuture;
                          if (can == true) _openModerationSheet();
                        }
                      : null,
                  isHost: roomState.isHost,
                  onAddVideo: roomState.isHost
                      ? () {
                          setState(() => _showFab = false);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => ScreeningAddVideoSheet(
                              sessionId: widget.sessionId,
                              threadId: widget.threadId,
                            ),
                          );
                        }
                      : null,
                ),
              ),
            Container(
              padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPad),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.06),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Botão de microfone grande e circular
                  _MicButton(sessionId: widget.sessionId),
                  const SizedBox(width: 10),
                  // Campo de chat estilo Rave
                  Expanded(
                    child: _ChatInput(
                      controller: _textController,
                      onSend: _sendMessage,
                    ),
                  ),
                  // Botão de reação (emoji) — toggle do seletor de cascata
                  const SizedBox(width: 8),
                  _ActionIconButton(
                    icon: _showEmojiPicker
                        ? Icons.close_rounded
                        : Icons.add_reaction_outlined,
                    onTap: () => setState(
                        () => _showEmojiPicker = !_showEmojiPicker),
                  ),
                  const SizedBox(width: 6),
                  // Galeria de imagens — sempre visível
                  _ActionIconButton(
                    icon: Icons.image_outlined,
                    onTap: _pickAndSendImage,
                  ),
                  const SizedBox(width: 6),
                  // FAB "+" — toggle do menu
                  _FabToggleButton(
                    isOpen: _showFab,
                    onToggle: () => setState(() => _showFab = !_showFab),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── ChatBubble ────────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final ScreeningChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    // Mensagem de sistema (ex: "Host mudou para Ana")
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      )
          .animate()
          .fadeIn(duration: 300.ms)
          .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), duration: 300.ms);
    }

    final isMe = message.isMe;
    final normalizedName = message.username.trim().toLowerCase();
    final showName = !isMe &&
        message.username.trim().isNotEmpty &&
        normalizedName != 'usuário' &&
        normalizedName != 'usuario' &&
        normalizedName != 'user';

    final avatar = CircleAvatar(
      radius: 14,
      backgroundColor: Colors.white24,
      backgroundImage: message.avatarUrl != null
          ? NetworkImage(message.avatarUrl!)
          : null,
      child: message.avatarUrl == null
          ? Text(
              message.username.isNotEmpty
                  ? message.username[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: message.isMedia ? 6 : 12,
          vertical: message.isMedia ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.lightBlueAccent.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMe ? 14 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 14),
          ),
          border: Border.all(
            color: isMe
                ? Colors.lightBlueAccent.withValues(alpha: 0.24)
                : Colors.white.withValues(alpha: 0.08),
            width: 0.6,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showName) ...[
              Text(
                message.username,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  shadows: const [
                    Shadow(color: Colors.black, blurRadius: 3),
                  ],
                ),
              ),
              const SizedBox(height: 3),
            ],
            if (message.kind == ScreeningChatMessageKind.image &&
                message.mediaUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  message.mediaUrl!,
                  width: 180,
                  height: 140,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Text(
                    message.displayText,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              )
            else if (message.kind == ScreeningChatMessageKind.sticker &&
                message.mediaUrl != null)
              Image.network(
                message.mediaUrl!,
                width: 96,
                height: 96,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text(
                  message.displayText,
                  style: const TextStyle(color: Colors.white),
                ),
              )
            else
              Text(
                message.displayText,
                textAlign: isMe ? TextAlign.right : TextAlign.left,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  shadows: [
                    Shadow(color: Colors.black, blurRadius: 4),
                    Shadow(color: Colors.black54, blurRadius: 8),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: isMe
            ? [bubble, const SizedBox(width: 8), avatar]
            : [avatar, const SizedBox(width: 8), bubble],
      ),
    )
        .animate()
        .fadeIn(duration: 250.ms)
        .slideX(
          begin: isMe ? 0.05 : -0.05,
          end: 0.0,
          duration: 250.ms,
          curve: Curves.easeOut,
        );
  }
}

// ── VoiceParticipantsBar ──────────────────────────────────────────────────────

class _VoiceParticipantsBar extends StatelessWidget {
  final List<ScreeningParticipant> participants;
  final Set<int> speakingUids;

  const _VoiceParticipantsBar({
    required this.participants,
    required this.speakingUids,
  });

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: participants.length,
        itemBuilder: (context, index) {
          final participant = participants[index];
          final isSpeaking = participant.agoraUid != null &&
              speakingUids.contains(participant.agoraUid);

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _ParticipantAvatar(
              username: participant.username,
              avatarUrl: participant.avatarUrl,
              isHost: participant.isHost,
              isSpeaking: isSpeaking,
            ),
          );
        },
      ),
    );
  }
}

class _ParticipantAvatar extends StatefulWidget {
  final String username;
  final String? avatarUrl;
  final bool isHost;
  final bool isSpeaking;

  const _ParticipantAvatar({
    required this.username,
    this.avatarUrl,
    this.isHost = false,
    this.isSpeaking = false,
  });

  @override
  State<_ParticipantAvatar> createState() => _ParticipantAvatarState();
}

class _ParticipantAvatarState extends State<_ParticipantAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_ParticipantAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpeaking && !oldWidget.isSpeaking) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isSpeaking && oldWidget.isSpeaking) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.username + (widget.isHost ? ' (Host)' : ''),
      child: ScaleTransition(
        scale: widget.isSpeaking ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(widget.isSpeaking ? 2.5 : 0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: widget.isSpeaking
                ? Border.all(color: Colors.greenAccent, width: 2)
                : widget.isHost
                    ? Border.all(
                        color: Colors.amberAccent.withValues(alpha: 0.8),
                        width: 1.5,
                      )
                    : null,
            boxShadow: widget.isSpeaking
                ? [
                    BoxShadow(
                      color: Colors.greenAccent.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white24,
            backgroundImage: widget.avatarUrl != null
                ? NetworkImage(widget.avatarUrl!)
                : null,
            child: widget.avatarUrl == null
                ? Text(
                    widget.username.isNotEmpty
                        ? widget.username[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

// ── MicButton ─────────────────────────────────────────────────────────────────
// Botão de microfone grande e circular, posicionado à esquerda do chat input.
// Replicando o layout do Rave: microfone proeminente na barra inferior.
class _MicButton extends ConsumerWidget {
  final String sessionId;
  const _MicButton({required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(screeningVoiceProvider(sessionId));
    final isMuted = voiceState.isMuted;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        ref.read(screeningVoiceProvider(sessionId).notifier).toggleMute();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isMuted
              ? Colors.redAccent.withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.18),
          border: Border.all(
            color: isMuted
                ? Colors.redAccent
                : Colors.white.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: isMuted
              ? [
                  BoxShadow(
                    color: Colors.redAccent.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Icon(
          isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

// ── ChatInput ─────────────────────────────────────────────────────────────────

class _ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _ChatInput({required this.controller, required this.onSend});

  @override
  State<_ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<_ChatInput> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _handleSend() {
    if (!_hasText) return;
    HapticFeedback.lightImpact();
    widget.onSend();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 46,
          decoration: BoxDecoration(
            color: _hasText
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _hasText
                  ? Colors.white.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Diga algo...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 14,
                    ),
                    // Remover bordas em TODOS os estados para evitar o bug
                    // visual de caixa quadrada dentro do container arredondado.
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    // Fundo transparente para não sobrepor o container pai
                    filled: false,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onSubmitted: (_) => _handleSend(),
                  textInputAction: TextInputAction.send,
                ),
              ),
              // Botão de envio com animação
              AnimatedOpacity(
                opacity: _hasText ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: GestureDetector(
                  onTap: _handleSend,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _hasText
                          ? Colors.white.withValues(alpha: 0.22)
                          : Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      color: _hasText ? Colors.white : Colors.white54,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _FabToggleButton ─────────────────────────────────────────────────────────
// Apenas o botão "+" que abre/fecha o menu FAB. O menu em si é renderizado
// no Stack pai (nível do Column) para não ser cortado pelo Row.
// =============================================================================
class _FabToggleButton extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onToggle;

  const _FabToggleButton({
    required this.isOpen,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isOpen
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.10),
          border: Border.all(
            color: Colors.white.withValues(alpha: isOpen ? 0.40 : 0.18),
          ),
        ),
        child: AnimatedRotation(
          turns: isOpen ? 0.125 : 0,
          duration: const Duration(milliseconds: 200),
          child: const Icon(Icons.add_rounded, color: Colors.white70, size: 20),
        ),
      ),
    );
  }
}

// ── _FabMenu ──────────────────────────────────────────────────────────────────
class _FabMenu extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onSticker;
  final Future<void> Function()? onModerate;
  final bool isHost;
  final VoidCallback? onAddVideo;

  const _FabMenu({
    required this.onClose,
    required this.onSticker,
    this.onModerate,
    required this.isHost,
    this.onAddVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FabMenuItem(
            icon: Icons.sticky_note_2_outlined,
            label: 'Sticker',
            onTap: () {
              onClose();
              onSticker();
            },
          ),
          if (onModerate != null) ...[
            const SizedBox(height: 4),
            _FabMenuItem(
              icon: Icons.shield_outlined,
              label: 'Moderar',
              onTap: () {
                onClose();
                onModerate!();
              },
            ),
          ],
          if (isHost && onAddVideo != null) ...[
            const SizedBox(height: 4),
            _FabMenuItem(
              icon: Icons.video_library_outlined,
              label: 'Vídeo',
              onTap: () {
                onClose();
                onAddVideo!();
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ── _FabMenuItem ──────────────────────────────────────────────────────────────
class _FabMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FabMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── ActionIconButton ──────────────────────────────────────────────────────────
class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ActionIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Icon(icon, color: Colors.white70, size: 18),
      ),
    );
  }
}

// ── EmojiCascadePicker ────────────────────────────────────────────────────────
// Seletor de reações que substitui o EmojiPicker padrão na Sala de Projeção.
// Ao tocar em uma reação, dispara o EmojiRainOverlay (chuva de emojis) em vez
// de inserir texto no campo de mensagem — comportamento imersivo e consistente
// com o restante da experiência da sala.
//
// Os 7 tipos de reação espelham o EmojiRainType definido em emoji_rain_overlay.dart.
// =============================================================================
class _EmojiCascadePicker extends StatelessWidget {
  final GlobalKey<EmojiRainOverlayState>? emojiRainKey;
  final VoidCallback onClose;

  const _EmojiCascadePicker({
    required this.emojiRainKey,
    required this.onClose,
  });

  static const _reactions = [
    (emoji: '🔥', type: EmojiRainType.fire,      label: 'Fogo'),
    (emoji: '❤️', type: EmojiRainType.love,      label: 'Amor'),
    (emoji: '😂', type: EmojiRainType.laugh,     label: 'Risada'),
    (emoji: '👏', type: EmojiRainType.clap,      label: 'Palmas'),
    (emoji: '🎉', type: EmojiRainType.celebrate, label: 'Festa'),
    (emoji: '⭐', type: EmojiRainType.star,      label: 'Estrela'),
    (emoji: '😢', type: EmojiRainType.sad,       label: 'Triste'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: const Color(0xFF12121E).withValues(alpha: 0.97),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _reactions.map((r) {
          return _CascadeReactionButton(
            emoji: r.emoji,
            label: r.label,
            type: r.type,
            emojiRainKey: emojiRainKey,
            onTap: onClose,
          );
        }).toList(),
      ),
    );
  }
}

class _CascadeReactionButton extends StatefulWidget {
  final String emoji;
  final String label;
  final EmojiRainType type;
  final GlobalKey<EmojiRainOverlayState>? emojiRainKey;
  final VoidCallback onTap;

  const _CascadeReactionButton({
    required this.emoji,
    required this.label,
    required this.type,
    required this.emojiRainKey,
    required this.onTap,
  });

  @override
  State<_CascadeReactionButton> createState() => _CascadeReactionButtonState();
}

class _CascadeReactionButtonState extends State<_CascadeReactionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.90), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.90, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    HapticFeedback.lightImpact();
    await _ctrl.forward(from: 0);
    widget.emojiRainKey?.currentState?.trigger(widget.type);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  widget.emoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
