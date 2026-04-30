import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ============================================================================
// EmojiRainOverlay — Chuva de emojis semântica inspirada no OluOlu
//
// O OluOlu usa um analisador de texto local que dispara animações ao detectar
// palavras-chave como "Parabéns" ou "Te amo". Implementamos o mesmo conceito
// usando flutter_animate (já disponível no NexusHub) sem dependência de Lottie.
//
// Uso:
//   // Envolver a tela com EmojiRainOverlay e uma key local
//   final _emojiRainKey = GlobalKey<EmojiRainOverlayState>();
//   EmojiRainOverlay(key: _emojiRainKey, child: MinhaTela())
//
//   // Disparar a chuva de emojis via key local
//   _emojiRainKey.currentState?.trigger(EmojiRainType.love);
//   _emojiRainKey.currentState?.triggerFromText(text);
//
// Integração no chat:
//   Ao enviar uma mensagem, chamar EmojiRainAnalyzer.analyze(text)
//   e se retornar um EmojiRainType, chamar trigger() via key local.
//
// BUGFIX (GlobalKey conflict):
//   Anteriormente havia uma GlobalKey estática (_emojiRainKey) usada por
//   todas as telas via EmojiRainOverlay.withKey(). Quando ChatRoomScreen e
//   ScreeningRoomScreen estavam ambos na pilha de navegação, a mesma key
//   era aplicada a dois widgets simultaneamente, causando:
//   "Multiple widgets used the same GlobalKey".
//   A solução é cada tela criar sua própria GlobalKey<EmojiRainOverlayState>
//   e passá-la diretamente ao construtor do EmojiRainOverlay.
// ============================================================================

// ─── Tipos de chuva ──────────────────────────────────────────────────────────
enum EmojiRainType {
  love,        // ❤️ te amo, amor, love, coração
  celebrate,   // 🎉 parabéns, feliz, aniversário, congrats
  fire,        // 🔥 incrível, demais, top, fire
  sad,         // 😢 triste, choro, saudade
  laugh,       // 😂 haha, kkk, lol, rsrs
  clap,        // 👏 parabéns, muito bem, bravo
  star,        // ⭐ estrela, top, incrível
}

// ─── Analisador de texto ─────────────────────────────────────────────────────
class EmojiRainAnalyzer {
  static const _patterns = <EmojiRainType, List<String>>{
    EmojiRainType.love: [
      'te amo', 'te adoro', 'amor', 'love', 'coração', '❤', '🥰', '😍',
      'apaixonado', 'apaixonada', 'beijo', 'saudade',
    ],
    EmojiRainType.celebrate: [
      'parabéns', 'feliz aniversário', 'feliz ano', 'congrats', 'congratulations',
      'feliz', 'comemorando', 'celebrando', '🎉', '🎊', '🥳', 'aniversário',
    ],
    EmojiRainType.fire: [
      'incrível', 'demais', 'top demais', 'fire', '🔥', 'sensacional',
      'impressionante', 'uau', 'wow', 'que lindo', 'perfeito',
    ],
    EmojiRainType.sad: [
      'triste', 'chorando', 'choro', 'saudade', '😢', '😭', 'coração partido',
      'que pena', 'lamentável', 'descanse em paz',
    ],
    EmojiRainType.laugh: [
      'hahaha', 'kkkkk', 'rsrsrs', 'lol', '😂', '🤣', 'morrendo de rir',
      'que engraçado', 'hilário',
    ],
    EmojiRainType.clap: [
      'muito bem', 'bravo', 'excelente', 'ótimo trabalho', 'mandou bem',
      'arrasou', '👏', 'aplausos',
    ],
    EmojiRainType.star: [
      'estrela', '⭐', '🌟', 'brilhante', 'genial', 'talentoso', 'talentosa',
    ],
  };

  /// Analisa o texto e retorna o tipo de chuva de emojis, se houver.
  static EmojiRainType? analyze(String text) {
    final lower = text.toLowerCase();
    for (final entry in _patterns.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  /// Retorna os emojis para o tipo de chuva.
  static List<String> emojisFor(EmojiRainType type) {
    switch (type) {
      case EmojiRainType.love:
        return ['❤️', '🥰', '💕', '💖', '😍', '💗', '💝'];
      case EmojiRainType.celebrate:
        return ['🎉', '🎊', '🥳', '🎈', '✨', '🎆', '🎇'];
      case EmojiRainType.fire:
        return ['🔥', '⚡', '💥', '✨', '🌟', '💫', '🚀'];
      case EmojiRainType.sad:
        return ['😢', '😭', '💔', '🥺', '😔', '😞', '🌧️'];
      case EmojiRainType.laugh:
        return ['😂', '🤣', '😆', '😹', '💀', '🤭', '😄'];
      case EmojiRainType.clap:
        return ['👏', '🙌', '🎊', '✨', '🌟', '💪', '🏆'];
      case EmojiRainType.star:
        return ['⭐', '🌟', '✨', '💫', '🌠', '🎇', '💥'];
    }
  }
}

// ─── Partícula de emoji ───────────────────────────────────────────────────────
class _EmojiParticle {
  final String emoji;
  final double startX;   // 0.0 a 1.0 (fração da largura)
  final double startY;   // 0.0 a 1.0 (fração da altura)
  final double size;
  final Duration delay;
  final Duration duration;
  final double driftX;   // deriva horizontal

  const _EmojiParticle({
    required this.emoji,
    required this.startX,
    required this.startY,
    required this.size,
    required this.delay,
    required this.duration,
    required this.driftX,
  });
}

// ─── Widget principal ─────────────────────────────────────────────────────────
class EmojiRainOverlay extends StatefulWidget {
  final Widget child;

  const EmojiRainOverlay({
    Key? key,
    required this.child,
  }) : super(key: key);

  /// [DEPRECATED] Use EmojiRainOverlay(key: _localKey, child: ...) diretamente.
  ///
  /// Este factory existia com uma GlobalKey estática compartilhada entre todas
  /// as telas, causando conflito de GlobalKey quando múltiplas telas com
  /// EmojiRainOverlay estavam na pilha de navegação simultaneamente.
  ///
  /// Migração:
  ///   Antes: EmojiRainOverlay.withKey(child: minhaTela)
  ///   Depois: EmojiRainOverlay(key: _emojiRainKey, child: minhaTela)
  ///   onde _emojiRainKey = GlobalKey<EmojiRainOverlayState>() no State.
  @Deprecated('Use EmojiRainOverlay(key: localKey, child: ...) diretamente.')
  factory EmojiRainOverlay.withKey({Key? key, required Widget child}) {
    return EmojiRainOverlay(key: key, child: child);
  }

  /// Dispara a chuva de emojis usando o contexto para encontrar o
  /// EmojiRainOverlayState ancestral na árvore de widgets.
  /// Seguro para uso dentro de widgets que estão dentro do EmojiRainOverlay.
  static void trigger(BuildContext context, {required EmojiRainType type}) {
    context
        .findAncestorStateOfType<EmojiRainOverlayState>()
        ?.trigger(type);
  }

  /// Analisa o texto e dispara automaticamente se houver correspondência,
  /// usando a key local passada.
  static void analyzeAndTrigger(
    BuildContext context,
    String text, {
    GlobalKey<EmojiRainOverlayState>? key,
  }) {
    final type = EmojiRainAnalyzer.analyze(text);
    if (type != null) {
      key?.currentState?.trigger(type);
    }
  }

  @override
  State<EmojiRainOverlay> createState() => EmojiRainOverlayState();
}

// Estado público para permitir acesso via GlobalKey<EmojiRainOverlayState>
class EmojiRainOverlayState extends State<EmojiRainOverlay> {
  final List<_EmojiParticle> _particles = [];
  final _random = Random();
  bool _isActive = false;
  int _generation = 0;

  void clear() {
    _generation++;
    if (!mounted) return;
    setState(() {
      _particles.clear();
      _isActive = false;
    });
  }

  /// Dispara a chuva de emojis para o tipo especificado.
  void trigger(EmojiRainType type) {
    if (!mounted || _isActive) return; // Evitar sobreposição
    final generation = ++_generation;
    final emojis = EmojiRainAnalyzer.emojisFor(type);
    final particles = <_EmojiParticle>[];

    // Gerar 20 partículas com posições e delays aleatórios
    for (int i = 0; i < 20; i++) {
      particles.add(_EmojiParticle(
        emoji: emojis[_random.nextInt(emojis.length)],
        startX: _random.nextDouble(),
        startY: -0.1, // começa acima da tela
        size: 20 + _random.nextDouble() * 20,
        delay: Duration(milliseconds: _random.nextInt(1500)),
        duration: Duration(milliseconds: 1500 + _random.nextInt(1000)),
        driftX: (_random.nextDouble() - 0.5) * 100,
      ));
    }

    setState(() {
      _particles.clear();
      _particles.addAll(particles);
      _isActive = true;
    });

    // Limpar após a animação
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted && generation == _generation) {
        setState(() {
          _particles.clear();
          _isActive = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _generation++;
    _particles.clear();
    _isActive = false;
    super.dispose();
  }

  /// Analisa o texto e dispara automaticamente se houver correspondência.
  void triggerFromText(String text) {
    final type = EmojiRainAnalyzer.analyze(text);
    if (type != null) {
      trigger(type);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_particles.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRect(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      clipBehavior: Clip.hardEdge,
                      children: _particles.map((p) {
                        final particleWidth = p.size + 12;
                        final maxLeft = (constraints.maxWidth - particleWidth)
                            .clamp(0.0, constraints.maxWidth);
                        final startLeft = (p.startX * maxLeft).clamp(0.0, maxLeft);
                        return Positioned(
                          left: startLeft,
                          top: 0,
                          child: SizedBox(
                            width: particleWidth,
                            child: _AnimatedEmojiParticle(
                              particle: p,
                              screenHeight: constraints.maxHeight,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Partícula animada ────────────────────────────────────────────────────────
class _AnimatedEmojiParticle extends StatelessWidget {
  final _EmojiParticle particle;
  final double screenHeight;

  const _AnimatedEmojiParticle({
    required this.particle,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      particle.emoji,
      style: TextStyle(fontSize: particle.size),
    )
        .animate(delay: particle.delay)
        .moveY(
          begin: -50,
          end: screenHeight + 50,
          duration: particle.duration,
          curve: Curves.easeIn,
        )
        .moveX(
          begin: 0,
          end: particle.driftX,
          duration: particle.duration,
          curve: Curves.easeInOut,
        )
        .fadeIn(duration: const Duration(milliseconds: 200))
        .fadeOut(
          delay: Duration(
              milliseconds: particle.duration.inMilliseconds - 400),
          duration: const Duration(milliseconds: 400),
        );
  }
}

// ─── Mixin para integração fácil no chat ─────────────────────────────────────
/// Mixin para adicionar análise de emoji rain em widgets de chat.
/// Basta chamar `checkEmojiRain(key, text)` ao enviar uma mensagem.
mixin EmojiRainMixin {
  void checkEmojiRain(
    BuildContext context,
    String text, {
    GlobalKey<EmojiRainOverlayState>? emojiRainKey,
  }) {
    emojiRainKey?.currentState?.triggerFromText(text);
  }
}
