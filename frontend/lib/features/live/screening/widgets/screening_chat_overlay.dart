import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/screening_chat_provider.dart';
import '../providers/screening_voice_provider.dart';
import '../providers/screening_room_provider.dart';
import '../models/screening_participant.dart';
import '../models/screening_chat_message.dart';

// =============================================================================
// ScreeningChatOverlay — Chat transparente (Camada 3 do Stack imersivo)
//
// Exibe as mensagens do chat como overlay sobre o vídeo.
// O fundo é semi-transparente com blur (glassmorphism).
// O input usa BackdropFilter para o efeito de vidro fosco.
// =============================================================================

class ScreeningChatOverlay extends ConsumerStatefulWidget {
  final String sessionId;
  final String threadId;

  const ScreeningChatOverlay({
    super.key,
    required this.sessionId,
    required this.threadId,
  });

  @override
  ConsumerState<ScreeningChatOverlay> createState() =>
      _ScreeningChatOverlayState();
}

class _ScreeningChatOverlayState extends ConsumerState<ScreeningChatOverlay> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _inputFocused = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(screeningChatProvider(widget.sessionId));
    final roomState = ref.watch(screeningRoomProvider(widget.threadId));
    final voiceState = ref.watch(screeningVoiceProvider(widget.sessionId));

    // Auto-scroll quando novas mensagens chegam
    ref.listen(screeningChatProvider(widget.sessionId), (prev, next) {
      if (next.length > (prev?.length ?? 0)) {
        _scrollToBottom();
      }
    });

    return Column(
      children: [
        // ── Lista de mensagens ──────────────────────────────────────────────
        Expanded(
          child: messages.isEmpty
              ? const SizedBox.shrink()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _ChatBubble(message: messages[index]);
                  },
                ),
        ),

        // ── Barra de participantes com indicadores de voz ──────────────────
        _VoiceParticipantsBar(
          participants: roomState.participants,
          speakingUids: voiceState.speakingAgoraUids,
        ),

        const SizedBox(height: 8),

        // ── Input de chat ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: _ChatInput(
            controller: _textController,
            onSend: () {
              final text = _textController.text.trim();
              if (text.isNotEmpty) {
                ref
                    .read(screeningChatProvider(widget.sessionId).notifier)
                    .sendMessage(text);
                _textController.clear();
              }
            },
          ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
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
          ),
          const SizedBox(width: 8),

          // Texto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username
                Text(
                  message.isMe ? 'Você' : message.username,
                  style: TextStyle(
                    color: message.isMe
                        ? Colors.lightBlueAccent
                        : Colors.white.withOpacity(0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 3),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                // Mensagem
                Text(
                  message.text,
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
        ],
      ),
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
      height: 44,
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

class _ParticipantAvatar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Tooltip(
      message: username + (isHost ? ' (Host)' : ''),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(isSpeaking ? 2.5 : 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: isSpeaking
              ? Border.all(color: Colors.greenAccent, width: 2)
              : isHost
                  ? Border.all(
                      color: Colors.amberAccent.withOpacity(0.8),
                      width: 1.5,
                    )
                  : null,
          boxShadow: isSpeaking
              ? [
                  BoxShadow(
                    color: Colors.greenAccent.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.white24,
          backgroundImage:
              avatarUrl != null ? NetworkImage(avatarUrl!) : null,
          child: avatarUrl == null
              ? Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

// ── ChatInput ─────────────────────────────────────────────────────────────────

class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _ChatInput({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Diga algo...',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onSubmitted: (_) => onSend(),
                  textInputAction: TextInputAction.send,
                ),
              ),
              GestureDetector(
                onTap: onSend,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 18,
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
