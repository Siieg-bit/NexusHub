import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/haptic_service.dart';

// ============================================================================
// MiniRoomOverlay — Overlay flutuante PiP para salas ativas
//
// Suporta três tipos de sala:
//   freeTalk   → card compacto roxo com ícone de voz
//   voiceChat  → preview rico com avatar do speaker ativo + anel animado de áudio
//   screening  → preview 16:9 com thumbnail do vídeo
//
// O PiP é arrastável, aparece acima de toda a navegação (via Stack no main.dart)
// e persiste enquanto o usuário navega pelo app.
//
// NOTA: Tooltip NÃO é usado neste widget porque o MiniRoomOverlayWrapper fica
// acima do MaterialApp na árvore de widgets, fora do Overlay do Navigator.
// Usar Tooltip aqui causaria "No Overlay widget found" em runtime.
// ============================================================================

// ─── Tipo de sala ─────────────────────────────────────────────────────────────
enum MiniRoomType {
  freeTalk,   // Sala de voz estilo palco
  voiceChat,  // Voice chat inline do chat
  screening,  // Sala de projeção
}

// ─── Dados do speaker ativo ───────────────────────────────────────────────────
class ActiveSpeakerInfo {
  final String? avatarUrl;
  final String name;
  final double audioLevel; // 0.0 – 1.0

  const ActiveSpeakerInfo({
    required this.name,
    this.avatarUrl,
    this.audioLevel = 0.0,
  });
}

// ─── Estado do mini room ──────────────────────────────────────────────────────
class MiniRoomState {
  final String roomId;
  final String title;
  final MiniRoomType type;
  final bool isMuted;
  final int participantCount;
  final bool isVisible;
  final String? thumbnailUrl;
  final String? videoUrl;

  /// Stream de speaker ativo — usado pelo voiceChat PiP para animar o avatar.
  /// Emite null quando ninguém está falando.
  final Stream<ActiveSpeakerInfo?>? speakerStream;

  /// Callback legado (sem context). Mantido por compatibilidade.
  final VoidCallback? onReturn;

  /// Callback com context do PiP — preferir este para navegação segura.
  final void Function(BuildContext context)? onReturnWithContext;
  final VoidCallback? onEnd;
  final VoidCallback? onToggleMute;

  const MiniRoomState({
    required this.roomId,
    required this.title,
    required this.type,
    this.isMuted = false,
    this.participantCount = 0,
    this.isVisible = true,
    this.thumbnailUrl,
    this.videoUrl,
    this.speakerStream,
    this.onReturn,
    this.onReturnWithContext,
    this.onEnd,
    this.onToggleMute,
  });

  MiniRoomState copyWith({
    bool? isMuted,
    int? participantCount,
    bool? isVisible,
  }) {
    return MiniRoomState(
      roomId: roomId,
      title: title,
      type: type,
      isMuted: isMuted ?? this.isMuted,
      participantCount: participantCount ?? this.participantCount,
      isVisible: isVisible ?? this.isVisible,
      thumbnailUrl: thumbnailUrl,
      videoUrl: videoUrl,
      speakerStream: speakerStream,
      onReturn: onReturn,
      onReturnWithContext: onReturnWithContext,
      onEnd: onEnd,
      onToggleMute: onToggleMute,
    );
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────
class MiniRoomNotifier extends StateNotifier<MiniRoomState?> {
  MiniRoomNotifier() : super(null);

  void show({
    required String roomId,
    required String title,
    required MiniRoomType type,
    bool isMuted = false,
    int participantCount = 0,
    String? thumbnailUrl,
    String? videoUrl,
    Stream<ActiveSpeakerInfo?>? speakerStream,
    VoidCallback? onReturn,
    void Function(BuildContext context)? onReturnWithContext,
    VoidCallback? onEnd,
    VoidCallback? onToggleMute,
  }) {
    state = MiniRoomState(
      roomId: roomId,
      title: title,
      type: type,
      isMuted: isMuted,
      participantCount: participantCount,
      isVisible: true,
      thumbnailUrl: thumbnailUrl,
      videoUrl: videoUrl,
      speakerStream: speakerStream,
      onReturn: onReturn,
      onReturnWithContext: onReturnWithContext,
      onEnd: onEnd,
      onToggleMute: onToggleMute,
    );
  }

  void hide() => state = null;

  void updateMute(bool muted) {
    if (state == null) return;
    state = state!.copyWith(isMuted: muted);
  }

  void updateParticipantCount(int count) {
    if (state == null) return;
    state = state!.copyWith(participantCount: count);
  }
}

final miniRoomProvider =
    StateNotifierProvider<MiniRoomNotifier, MiniRoomState?>(
  (ref) => MiniRoomNotifier(),
);

// ─── Widget principal ─────────────────────────────────────────────────────────
/// Wrapper que envolve o MaterialApp para exibir o overlay acima da navegação.
class MiniRoomOverlayWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const MiniRoomOverlayWrapper({super.key, required this.child});

  @override
  ConsumerState<MiniRoomOverlayWrapper> createState() =>
      _MiniRoomOverlayWrapperState();
}

class _MiniRoomOverlayWrapperState
    extends ConsumerState<MiniRoomOverlayWrapper> {
  @override
  Widget build(BuildContext context) {
    final miniRoom = ref.watch(miniRoomProvider);

    return Stack(
      children: [
        widget.child,
        if (miniRoom != null && miniRoom.isVisible)
          Positioned(
            bottom: 90, // Acima da bottom nav bar
            right: 16,
            child: _MiniRoomPip(state: miniRoom),
          ),
      ],
    );
  }
}

// ─── PiP flutuante ────────────────────────────────────────────────────────────
class _MiniRoomPip extends ConsumerStatefulWidget {
  final MiniRoomState state;

  const _MiniRoomPip({required this.state});

  @override
  ConsumerState<_MiniRoomPip> createState() => _MiniRoomPipState();
}

class _MiniRoomPipState extends ConsumerState<_MiniRoomPip>
    with TickerProviderStateMixin {
  // Animação de pulso geral (sempre ativa)
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Animação do anel de áudio (responde ao nível de áudio do speaker)
  late AnimationController _ringCtrl;
  late Animation<double> _ringAnim;

  // Posição arrastável
  Offset _offset = Offset.zero;

  // Speaker ativo atual (recebido via stream)
  ActiveSpeakerInfo? _activeSpeaker;
  StreamSubscription<ActiveSpeakerInfo?>? _speakerSub;

  @override
  void initState() {
    super.initState();

    // Pulso suave de fundo (escala 0.97 → 1.03)
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Anel de áudio (escala 1.0 → 1.35, dispara quando há nível de áudio)
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _ringAnim = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOut),
    );

    _subscribeSpeakerStream();
  }

  void _subscribeSpeakerStream() {
    _speakerSub?.cancel();
    final stream = widget.state.speakerStream;
    if (stream == null) return;

    _speakerSub = stream.listen((info) {
      if (!mounted) return;
      setState(() => _activeSpeaker = info);

      // Animar o anel quando há nível de áudio significativo
      if (info != null && info.audioLevel > 0.05) {
        if (!_ringCtrl.isAnimating) {
          _ringCtrl.forward().then((_) {
            if (mounted) _ringCtrl.reverse();
          });
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant _MiniRoomPip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.speakerStream != widget.state.speakerStream) {
      _subscribeSpeakerStream();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _ringCtrl.dispose();
    _speakerSub?.cancel();
    super.dispose();
  }

  void _onTap() {
    HapticService.buttonPress();
    final s = widget.state;
    if (s.onReturnWithContext != null) {
      s.onReturnWithContext!(context);
    } else {
      s.onReturn?.call();
    }
  }

  void _onClose() {
    HapticService.action();
    final s = widget.state;
    s.onEnd?.call();
    ref.read(miniRoomProvider.notifier).hide();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;

    // Material + DefaultTextStyle garantem que o PiP não herde o
    // DefaultTextStyle do app (que pode ter decoration: underline / cor amarela)
    // pois o MiniRoomOverlayWrapper fica acima do MaterialApp na árvore.
    return Transform.translate(
      offset: _offset,
      child: Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle(
          style: const TextStyle(
            decoration: TextDecoration.none,
            decorationColor: Colors.transparent,
            fontFamily: 'sans-serif',
          ),
          child: GestureDetector(
            onPanUpdate: (details) => setState(() => _offset += details.delta),
            onTap: _onTap,
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, child) => Transform.scale(
                scale: _pulseAnim.value,
                child: child,
              ),
              child: _buildPipBody(s),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPipBody(MiniRoomState s) {
    return switch (s.type) {
      MiniRoomType.voiceChat => _buildVoiceChatPip(s),
      MiniRoomType.screening => _buildScreeningPip(s),
      MiniRoomType.freeTalk  => _buildFreeTalkPip(s),
    };
  }

  // ── Voice Chat PiP ─────────────────────────────────────────────────────────
  // Design minimalista: card pequeno com header (título + X) e avatar grande
  // centralizado com anel de áudio animado. Sem textos, sem barra de botões.
  Widget _buildVoiceChatPip(MiniRoomState s) {
    final speaker = _activeSpeaker;
    final hasSpeaker = speaker != null;
    const accentColor = Color(0xFF9C6FD6);

    return Container(
      width: 112,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1035), Color(0xFF130B28)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.30),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: accentColor.withValues(alpha: 0.18),
            blurRadius: 16,
            spreadRadius: -2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header: título + fechar ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 8, 5, 0),
            child: Row(
              children: [
                // Indicador ao vivo
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.6),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    s.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                      letterSpacing: 0.1,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Botão fechar
                GestureDetector(
                  onTap: _onClose,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 2, 2, 2),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.40),
                      size: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Avatar grande centralizado ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
            child: AnimatedBuilder(
              animation: _ringAnim,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Anel externo animado (pulsa com o áudio)
                    if (hasSpeaker)
                      Transform.scale(
                        scale: _ringAnim.value,
                        child: Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accentColor.withValues(
                                alpha: (0.50 * (speaker.audioLevel + 0.25))
                                    .clamp(0.0, 0.85),
                              ),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    // Anel interno estático (sempre visível)
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                    ),
                    // Avatar principal
                    _SpeakerAvatar(
                      avatarUrl: hasSpeaker ? speaker.avatarUrl : null,
                      name: hasSpeaker ? speaker.name : null,
                      size: 64,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── FreeTalk PiP ───────────────────────────────────────────────────────────
  Widget _buildFreeTalkPip(MiniRoomState s) {
    const color = Color(0xFF7C4DFF);
    return _buildCompactPip(
      s: s,
      accentColor: color,
      icon: Icons.record_voice_over_rounded,
    );
  }

  // ── Compact PiP (freeTalk) ─────────────────────────────────────────────────
  Widget _buildCompactPip({
    required MiniRoomState s,
    required Color accentColor,
    required IconData icon,
  }) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  s.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: _onClose,
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white70,
                  size: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  s.participantCount > 0
                      ? '${s.participantCount} participantes'
                      : 'Ao vivo',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ),
              if (s.onToggleMute != null)
                GestureDetector(
                  onTap: () {
                    HapticService.tap();
                    s.onToggleMute?.call();
                  },
                  child: Icon(
                    s.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    color: s.isMuted ? Colors.red[200] : Colors.white,
                    size: 16,
                  ),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _onClose,
                child: const Icon(
                  Icons.call_end_rounded,
                  color: Colors.red,
                  size: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Screening PiP ─────────────────────────────────────────────────────────
  Widget _buildScreeningPip(MiniRoomState s) {
    const color = Color(0xFFE91E63);
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.live_tv_rounded, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  s.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticService.buttonPress();
                  if (s.onEnd != null) {
                    s.onEnd?.call();
                  } else {
                    ref.read(miniRoomProvider.notifier).hide();
                  }
                },
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white70,
                  size: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildScreeningPreview(s),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  s.participantCount > 0
                      ? '${s.participantCount} participantes'
                      : 'Ao vivo',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
              if (s.onToggleMute != null)
                GestureDetector(
                  onTap: () {
                    HapticService.tap();
                    s.onToggleMute?.call();
                  },
                  child: Icon(
                    s.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    color: s.isMuted ? Colors.red[200] : Colors.white,
                    size: 16,
                  ),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  HapticService.action();
                  s.onEnd?.call();
                  ref.read(miniRoomProvider.notifier).hide();
                },
                child: const Icon(
                  Icons.call_end_rounded,
                  color: Colors.red,
                  size: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScreeningPreview(MiniRoomState s) {
    final thumbnailUrl = s.thumbnailUrl?.trim();
    final hasThumbnail = thumbnailUrl != null && thumbnailUrl.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasThumbnail)
              CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _buildScreeningFallback(),
              )
            else
              _buildScreeningFallback(),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.10),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreeningFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B1B2F), Color(0xFF0F3460)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.live_tv_rounded, color: Colors.white70, size: 30),
      ),
    );
  }
}

// ─── Avatar do speaker ────────────────────────────────────────────────────────
class _SpeakerAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? name;
  final double size;

  const _SpeakerAvatar({
    this.avatarUrl,
    this.name,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final initial = (name?.isNotEmpty == true) ? name![0].toUpperCase() : '?';
    final url = avatarUrl?.trim();
    final hasUrl = url != null && url.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF3D2060),
        border: Border.all(
          color: const Color(0xFF9C6FD6).withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: hasUrl
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _buildInitial(initial),
              )
            : _buildInitial(initial),
      ),
    );
  }

  Widget _buildInitial(String initial) {
    return Container(
      color: const Color(0xFF3D2060),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.38,
          ),
        ),
      ),
    );
  }
}

// ─── Botão de controle ────────────────────────────────────────────────────────
// NOTA: Tooltip NÃO é usado aqui porque este widget vive fora do Overlay do
// Navigator (MiniRoomOverlayWrapper fica acima do MaterialApp). Usar Tooltip
// causaria "No Overlay widget found" em runtime.
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Color? background;

  const _ControlButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: background ?? Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}
