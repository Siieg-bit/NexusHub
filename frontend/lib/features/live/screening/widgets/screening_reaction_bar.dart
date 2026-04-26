import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/widgets/emoji_rain_overlay.dart';

// =============================================================================
// ScreeningReactionBar — Barra de reações rápidas (Fase 2)
//
// Exibe 6 botões de reação rápida que:
// 1. Disparam o EmojiRain localmente (feedback imediato)
// 2. Transmitem a reação via Supabase Realtime Broadcast para todos os
//    participantes da sala (todos veem a chuva de emojis)
//
// Posicionada logo acima do chat overlay, visível apenas quando os controles
// estão visíveis (auto-hide junto com os controles).
//
// Cada reação tem um cooldown de 3s para evitar spam.
// =============================================================================

// ── Definição das reações ─────────────────────────────────────────────────────

class _Reaction {
  final String emoji;
  final EmojiRainType type;
  const _Reaction(this.emoji, this.type);
}

const _kReactions = [
  _Reaction('🔥', EmojiRainType.fire),
  _Reaction('❤️', EmojiRainType.love),
  _Reaction('😂', EmojiRainType.laugh),
  _Reaction('👏', EmojiRainType.clap),
  _Reaction('🎉', EmojiRainType.celebrate),
  _Reaction('⭐', EmojiRainType.star),
];

const _kCooldownSeconds = 3;

// ── Provider de cooldown ──────────────────────────────────────────────────────

final _reactionCooldownProvider =
    StateProvider.family<DateTime?, String>((ref, key) => null);

// ── Widget ────────────────────────────────────────────────────────────────────

class ScreeningReactionBar extends ConsumerWidget {
  final String sessionId;

  const ScreeningReactionBar({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: _kReactions.map((reaction) {
          return _ReactionButton(
            reaction: reaction,
            sessionId: sessionId,
          );
        }).toList(),
      ),
    );
  }
}

// ── Botão de reação individual ────────────────────────────────────────────────

class _ReactionButton extends ConsumerStatefulWidget {
  final _Reaction reaction;
  final String sessionId;

  const _ReactionButton({
    required this.reaction,
    required this.sessionId,
  });

  @override
  ConsumerState<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends ConsumerState<_ReactionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.75).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  bool get _isOnCooldown {
    final cooldownKey = '${widget.sessionId}_${widget.reaction.emoji}';
    final lastUsed = ref.read(_reactionCooldownProvider(cooldownKey));
    if (lastUsed == null) return false;
    return DateTime.now().difference(lastUsed).inSeconds < _kCooldownSeconds;
  }

  Future<void> _onTap() async {
    if (_isOnCooldown) return;

    // Feedback háptico
    HapticFeedback.lightImpact();

    // Animação de escala
    await _scaleController.forward();
    await _scaleController.reverse();

    // Disparar EmojiRain localmente
    if (mounted) {
      EmojiRainOverlay.trigger(context, type: widget.reaction.type);
    }

    // Marcar cooldown
    final cooldownKey = '${widget.sessionId}_${widget.reaction.emoji}';
    ref.read(_reactionCooldownProvider(cooldownKey).notifier).state =
        DateTime.now();

    // Transmitir para todos os participantes via Broadcast
    await _broadcastReaction();
  }

  Future<void> _broadcastReaction() async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id ?? '';
      await SupabaseService.client
          .channel('screening_sync_${widget.sessionId}')
          .sendBroadcastMessage(
            event: 'reaction',
            payload: {
              'emoji': widget.reaction.emoji,
              'reaction_type': widget.reaction.type.name,
              'user_id': userId,
              'ts': DateTime.now().millisecondsSinceEpoch,
            },
          );
    } catch (e) {
      debugPrint('[ScreeningReaction] broadcast error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cooldownKey = '${widget.sessionId}_${widget.reaction.emoji}';
    final lastUsed = ref.watch(_reactionCooldownProvider(cooldownKey));
    final onCooldown = lastUsed != null &&
        DateTime.now().difference(lastUsed).inSeconds < _kCooldownSeconds;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTap: _onTap,
          child: AnimatedOpacity(
            opacity: onCooldown ? 0.4 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  widget.reaction.emoji,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
