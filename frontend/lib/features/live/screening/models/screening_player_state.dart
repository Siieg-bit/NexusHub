// =============================================================================
// ScreeningPlayerState — Estado do player de vídeo da Sala de Projeção
// =============================================================================

enum ScreeningPlayerType {
  webView,  // YouTube, Twitch, Kick, Vimeo, etc.
  none,     // Sem vídeo carregado
}

class ScreeningPlayerState {
  final ScreeningPlayerType playerType;

  /// TRUE se o vídeo está em reprodução.
  final bool isPlaying;

  /// TRUE se o player está carregando/buffering.
  final bool isBuffering;

  /// Posição atual de reprodução.
  final Duration position;

  /// Duração total do vídeo (0 para streams ao vivo).
  final Duration duration;

  /// Velocidade de reprodução atual (1.0 = normal, 1.05 = microsync acelerado).
  final double playbackRate;

  /// TRUE se o player está pronto para receber comandos.
  final bool isReady;

  /// TRUE se o vídeo chegou ao fim.
  final bool hasEnded;

  const ScreeningPlayerState({
    this.playerType = ScreeningPlayerType.none,
    this.isPlaying = false,
    this.isBuffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playbackRate = 1.0,
    this.isReady = false,
    this.hasEnded = false,
  });

  bool get isLiveStream => duration == Duration.zero;

  ScreeningPlayerState copyWith({
    ScreeningPlayerType? playerType,
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
    double? playbackRate,
    bool? isReady,
    bool? hasEnded,
  }) {
    return ScreeningPlayerState(
      playerType: playerType ?? this.playerType,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      playbackRate: playbackRate ?? this.playbackRate,
      isReady: isReady ?? this.isReady,
      hasEnded: hasEnded ?? this.hasEnded,
    );
  }
}
