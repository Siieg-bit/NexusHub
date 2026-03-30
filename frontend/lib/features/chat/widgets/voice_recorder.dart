import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../config/app_theme.dart';
import '../../../core/utils/responsive.dart';

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
                final normalized =
                    ((amp.current + 60) / 60).clamp(0.0, 1.0);
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
        widget.onCancel();
      }
    } catch (e) {
      widget.onCancel();
    }
  }

  Future<void> _stopAndSend() async {
    _timer?.cancel();
    _amplitudeTimer?.cancel();

    try {
      final path = await _recorder.stop();
      if (path != null && _seconds > 0) {
        HapticFeedback.lightImpact();
        widget.onRecordingComplete(path, _seconds);
      } else {
        widget.onCancel();
      }
    } catch (_) {
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
        color: context.cardBg,
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
                color: AppTheme.errorColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_rounded,
                  color: AppTheme.errorColor, size: r.s(20)),
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
                          color: AppTheme.errorColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.errorColor
                                  .withValues(alpha: 0.5 * _pulseAnimation.value),
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
                        color: context.textPrimary,
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
                      color: AppTheme.accentColor,
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
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.send_rounded,
                  color: Colors.white, size: r.s(22)),
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

      // Gradiente de opacidade: barras mais recentes são mais brilhantes
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

  /// Duração em segundos.
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
  bool _isPlaying = false;
  double _progress = 0.0;
  Timer? _progressTimer;

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _togglePlay() {
    setState(() => _isPlaying = !_isPlaying);

    if (_isPlaying) {
      // Simular progresso (será substituído por player real)
      _progressTimer = Timer.periodic(
        Duration(
            milliseconds:
                (widget.durationSeconds * 1000 / 100).round().clamp(50, 500)),
        (_) {
          if (mounted) {
            setState(() {
              _progress += 0.01;
              if (_progress >= 1.0) {
                _progress = 0.0;
                _isPlaying = false;
                _progressTimer?.cancel();
              }
            });
          }
        },
      );
    } else {
      _progressTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final bgColor = widget.isMine
        ? Colors.white.withValues(alpha: 0.15)
        : AppTheme.accentColor.withValues(alpha: 0.1);
    final fgColor =
        widget.isMine ? Colors.white : AppTheme.accentColor;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
      constraints: const BoxConstraints(minWidth: 180),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: r.s(36),
              height: r.s(36),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: fgColor,
                size: r.s(22),
              ),
            ),
          ),
          SizedBox(width: r.s(10)),

          // Waveform estático + progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform bars estáticas
                SizedBox(
                  height: r.s(24),
                  child: CustomPaint(
                    size: const Size(double.infinity, 24),
                    painter: _StaticWaveformPainter(
                      progress: _progress,
                      activeColor: fgColor,
                      inactiveColor: fgColor.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                // Duration
                Text(
                  _formatDuration(widget.durationSeconds),
                  style: TextStyle(
                    color: fgColor.withValues(alpha: 0.7),
                    fontSize: r.fs(10),
                    fontWeight: FontWeight.w500,
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
    final heights = List.generate(
        barCount, (_) => 0.2 + rng.nextDouble() * 0.8);

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
