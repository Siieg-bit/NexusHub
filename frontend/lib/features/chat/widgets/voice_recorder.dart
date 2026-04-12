import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../config/app_theme.dart';
import '../../../core/utils/responsive.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Widget de gravação de Voice Notes — réplica pixel-perfect do Amino.
///
/// No Amino original, o botão de mic na barra de input permite:
/// 1. Tap: abre o modo de gravação
/// 2. Gravação com visualização de waveform em tempo real
/// 3. Botão de parar + enviar ou cancelar
/// 4. Timer mostrando duração da gravação
/// 5. Animação de pulso no ícone do mic durante gravação
///
/// Este widget gerencia todo o ciclo de gravação e retorna
/// o path do arquivo de áudio gravado via callback.
class VoiceRecorder extends StatefulWidget {
  /// Callback chamado quando a gravação é concluída com sucesso.
  /// Recebe o path do arquivo de áudio e a duração em segundos.
  final void Function(String filePath, int durationSeconds) onRecordingComplete;

  /// Callback chamado quando a gravação é cancelada.
  final VoidCallback onCancel;

  const VoiceRecorder({
    super.key,
    required this.onRecordingComplete,
    required this.onCancel,
  });

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder>
    with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  // ignore: unused_field
  bool _isRecording = false;
  int _seconds = 0;
  Timer? _timer;
  String? _filePath;

  // Waveform data (amplitudes simuladas durante gravação)
  final List<double> _amplitudes = [];
  Timer? _amplitudeTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amplitudeTimer?.cancel();
    _pulseController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: path,
        );

        if (!mounted) return;
        setState(() {
          _isRecording = true;
          _filePath = path;
          _seconds = 0;
          _amplitudes.clear();
        });

        HapticFeedback.mediumImpact();

        // Timer de duração
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          if (mounted) setState(() => _seconds++);
        });

        // Timer de amplitude para waveform
        _amplitudeTimer =
            Timer.periodic(const Duration(milliseconds: 100), (_) async {
          try {
            final amp = await _recorder.getAmplitude();
            if (mounted) {
              setState(() {
                // Normalizar amplitude (-160 a 0 dB) para 0.0 a 1.0
                final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
                _amplitudes.add(normalized);
                // Manter apenas os últimos 50 valores
                if (_amplitudes.length > 50) {
                  _amplitudes.removeAt(0);
                }
              });
            }
          } catch (_) {
            // Fallback: amplitude aleatória
            if (mounted) {
              setState(() {
                _amplitudes.add(0.2 + Random().nextDouble() * 0.5);
                if (_amplitudes.length > 50) _amplitudes.removeAt(0);
              });
            }
          }
        });
      } else {
        // Sem permissão
        if (mounted) widget.onCancel();
      }
    } catch (e) {
      if (mounted) widget.onCancel();
    }
  }

  Future<void> _stopAndSend() async {
    _timer?.cancel();
    _amplitudeTimer?.cancel();

    try {
      final path = await _recorder.stop();
      if (!mounted) return;
      if (path != null && _seconds > 0) {
        HapticFeedback.lightImpact();
        widget.onRecordingComplete(path, _seconds);
      } else {
        widget.onCancel();
      }
    } catch (_) {
      if (!mounted) return;
      widget.onCancel();
    }
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    _amplitudeTimer?.cancel();

    try {
      await _recorder.stop();
      // Deletar arquivo
      if (_filePath != null) {
        final file = File(_filePath!);
        if (await file.exists()) await file.delete();
      }
    } catch (e) {
      debugPrint('[voice_recorder] Erro: $e');
    }

    if (!mounted) return;
    widget.onCancel();
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
      decoration: BoxDecoration(
        color: context.nexusTheme.surfacePrimary,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          // ── Botão Cancelar ──
          GestureDetector(
            onTap: _cancelRecording,
            child: Container(
              width: r.s(40),
              height: r.s(40),
              decoration: BoxDecoration(
                color: context.nexusTheme.error.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_rounded,
                  color: context.nexusTheme.error, size: r.s(20)),
            ),
          ),
          SizedBox(width: r.s(12)),

          // ── Waveform + Timer ──
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Timer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (_, __) => Container(
                        width: r.s(8),
                        height: r.s(8),
                        decoration: BoxDecoration(
                          color: context.nexusTheme.error,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: context.nexusTheme.error.withValues(
                                  alpha: 0.5 * _pulseAnimation.value),
                              blurRadius: 4 * _pulseAnimation.value,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: r.s(8)),
                    Text(
                      _formatDuration(_seconds),
                      style: TextStyle(
                        color: context.nexusTheme.textPrimary,
                        fontSize: r.fs(16),
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.s(6)),

                // Waveform
                SizedBox(
                  height: r.s(32),
                  child: CustomPaint(
                    size: const Size(double.infinity, 32),
                    painter: _WaveformPainter(
                      amplitudes: _amplitudes,
                      color: context.nexusTheme.accentSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: r.s(12)),

          // ── Botão Enviar ──
          GestureDetector(
            onTap: _stopAndSend,
            child: Container(
              width: r.s(48),
              height: r.s(48),
              decoration: BoxDecoration(
                color: context.nexusTheme.accentPrimary,
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.send_rounded, color: Colors.white, size: r.s(22)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter para a waveform de áudio em tempo real.
class _WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color;

  _WaveformPainter({required this.amplitudes, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final barWidth = 3.0;
    final gap = 2.0;
    final totalBarWidth = barWidth + gap;
    final maxBars = (size.width / totalBarWidth).floor();
    final bars = amplitudes.length > maxBars
        ? amplitudes.sublist(amplitudes.length - maxBars)
        : amplitudes;

    final startX = size.width - bars.length * totalBarWidth;

    for (int i = 0; i < bars.length; i++) {
      final x = startX + i * totalBarWidth + barWidth / 2;
      final barHeight = max(4.0, bars[i] * size.height * 0.9);
      final y1 = (size.height - barHeight) / 2;
      final y2 = y1 + barHeight;

      final opacity = 0.4 + 0.6 * (i / bars.length);
      paint.color = color.withValues(alpha: opacity);

      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) => true;
}

/// Widget para reproduzir voice notes recebidas — estilo Amino.
class VoiceNotePlayer extends StatefulWidget {
  /// URL do arquivo de áudio.
  final String audioUrl;

  /// Duração em segundos (usada como fallback se o player não retornar duração).
  final int durationSeconds;

  /// Se a mensagem é do próprio usuário.
  final bool isMine;

  const VoiceNotePlayer({
    super.key,
    required this.audioUrl,
    required this.durationSeconds,
    this.isMine = false,
  });

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  double _progress = 0.0;
  Duration _position = Duration.zero;
  // Bug fix: _duration começa com o valor do widget mas é atualizado pelo
  // evento onDurationChanged do player. Isso garante sincronização real
  // mesmo quando widget.durationSeconds é 0 ou impreciso.
  late Duration _duration;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    // Inicializa com o valor fornecido como fallback
    _duration = Duration(seconds: widget.durationSeconds);

    // Bug fix: assinar onDurationChanged para obter a duração real do arquivo.
    // Sem isso, _duration ficava fixo no valor do widget (que pode ser 0 ou
    // impreciso), fazendo o progresso não avançar corretamente.
    _durationSub = _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      if (d > Duration.zero) {
        setState(() => _duration = d);
      }
    });

    _positionSub = _player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      final total = _duration.inMilliseconds;
      setState(() {
        _position = pos;
        _progress =
            total > 0 ? (pos.inMilliseconds / total).clamp(0.0, 1.0) : 0.0;
      });
    });

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      if (state == PlayerState.completed) {
        setState(() {
          _isPlaying = false;
          _progress = 0.0;
          _position = Duration.zero;
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _togglePlay() async {
    try {
      if (_isPlaying) {
        await _player.pause();
        setState(() => _isPlaying = false);
      } else {
        final url = widget.audioUrl;
        if (_position > Duration.zero && _position < _duration) {
          await _player.resume();
        } else {
          await _player.play(UrlSource(url));
        }
        setState(() => _isPlaying = true);
      }
    } catch (e) {
      debugPrint('[VoiceNotePlayer] Erro ao reproduzir: $e');
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final bgColor = widget.isMine
        ? Colors.white.withValues(alpha: 0.15)
        : context.nexusTheme.accentSecondary.withValues(alpha: 0.1);
    final fgColor = widget.isMine ? Colors.white : context.nexusTheme.accentSecondary;

    // Largura da waveform proporcional à duração do áudio:
    // mínimo 160px, máximo 220px, crescendo 3px por segundo.
    // Bug fix #060: mínimo aumentado de 80px para 160px para evitar
    // bubble de voz muito estreito visualmente.
    final durationSecs = _duration.inSeconds > 0
        ? _duration.inSeconds
        : widget.durationSeconds;
    final waveformWidth = (160.0 + durationSecs * 3.0).clamp(160.0, 220.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play/Pause button
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: r.s(32),
            height: r.s(32),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: fgColor,
              size: r.s(20),
            ),
          ),
        ),
        SizedBox(width: r.s(8)),

        // Waveform + duração com largura proporcional à duração do áudio
        SizedBox(
          width: r.s(waveformWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Waveform
              SizedBox(
                height: r.s(18),
                child: CustomPaint(
                  size: Size(waveformWidth, 18),
                  painter: _StaticWaveformPainter(
                    progress: _progress,
                    activeColor: fgColor,
                    inactiveColor: fgColor.withValues(alpha: 0.3),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              // Duração: posição atual durante reprodução, total em pausa
              Text(
                _isPlaying
                    ? _formatDuration(_position)
                    : _formatDuration(_duration),
                style: TextStyle(
                  color: fgColor.withValues(alpha: 0.7),
                  fontSize: r.fs(9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Waveform estático para reprodução de voice notes.
class _StaticWaveformPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  _StaticWaveformPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = 2.5;
    final gap = 2.0;
    final totalBarWidth = barWidth + gap;
    final barCount = (size.width / totalBarWidth).floor();

    // Gerar padrão de waveform pseudo-aleatório mas consistente
    final rng = Random(42); // Seed fixa para consistência
    final heights =
        List.generate(barCount, (_) => 0.2 + rng.nextDouble() * 0.8);

    final activePaint = Paint()
      ..color = activeColor
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;

    final progressIndex = (progress * barCount).floor();

    for (int i = 0; i < barCount; i++) {
      final x = i * totalBarWidth + barWidth / 2;
      final barHeight = max(4.0, heights[i] * size.height * 0.9);
      final y1 = (size.height - barHeight) / 2;
      final y2 = y1 + barHeight;

      canvas.drawLine(
        Offset(x, y1),
        Offset(x, y2),
        i <= progressIndex ? activePaint : inactivePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StaticWaveformPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
