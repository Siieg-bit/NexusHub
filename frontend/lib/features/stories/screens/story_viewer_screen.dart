import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

/// Story Viewer — Visualizador fullscreen de stories estilo Instagram/Amino.
///
/// Features:
///   - Progresso linear no topo (barra por story)
///   - Toque esquerdo/direito para navegar
///   - Swipe para fechar
///   - Auto-advance após duração
///   - Registro de visualização
///   - Reações rápidas
class StoryViewerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final Map<String, dynamic> authorProfile;

  const StoryViewerScreen({
    super.key,
    required this.stories,
    required this.authorProfile,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _progressController;
  Timer? _autoAdvanceTimer;
  VideoPlayerController? _videoController;

  static const _reactions = ['❤️', '🔥', '😂', '😮', '😢', '👏'];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );
    _progressController = AnimationController(vsync: this);
    _startStory();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _autoAdvanceTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initVideo(String url) async {
    _videoController?.dispose();
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
    await _videoController!.initialize();
    if (mounted) {
      setState(() {});
      _videoController!.play();
      _videoController!.setLooping(false);
      // Avança para o próximo story quando o vídeo terminar
      _videoController!.addListener(() {
        if (_videoController!.value.position >= _videoController!.value.duration &&
            _videoController!.value.duration > Duration.zero) {
          _advance();
        }
      });
    }
  }

  void _startStory() {
    final story = widget.stories[_currentIndex];
    final type = story['type'] as String? ?? 'image';
    final duration = (story['duration'] as int?) ?? (type == 'video' ? 15 : 5);

    // Parar vídeo anterior se houver
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;

    _progressController.removeStatusListener(_onProgressComplete);
    _progressController.duration = Duration(seconds: duration);

    if (type == 'video') {
      final mediaUrl = story['media_url'] as String?;
      if (mediaUrl != null) {
        // Inicializa o vídeo; o progresso será controlado pelo vídeo
        _initVideo(mediaUrl);
      }
    } else {
      _progressController.forward(from: 0);
      _progressController.addStatusListener(_onProgressComplete);
    }

    // Registrar visualização
    _registerView(story['id'] as String);
  }

  void _onProgressComplete(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _nextStory();
    }
  }

  void _advance() {
    if (!mounted) return;
    _nextStory();
  }

  Future<void> _registerView(String storyId) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      await SupabaseService.table('story_views').upsert({
        'story_id': storyId,
        'viewer_id': userId,
      });

      // Incrementar views_count
      await SupabaseService.client.rpc('increment_story_views',
          params: {'p_story_id': storyId}).catchError((_) => null);
    } catch (e) {
      debugPrint('[story_viewer_screen] Erro: $e');
    }
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() => _currentIndex++);
      _progressController.reset();
      _startStory();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _progressController.reset();
      _startStory();
    }
  }

  void _pauseStory() {
    _progressController.stop();
  }

  void _resumeStory() {
    _progressController.forward();
  }

  Future<void> _sendReaction(String reaction) async {
    try {
      final story = widget.stories[_currentIndex];
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      await SupabaseService.table('story_reactions').upsert({
        'story_id': story['id'],
        'user_id': userId,
        'reaction': reaction,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$reaction enviado!'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            backgroundColor: context.surfaceColor,
          ),
        );
      }
    } catch (e) {
      debugPrint('[story_viewer_screen] Erro: $e');
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'agora';
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final story = widget.stories[_currentIndex];
    final type = story['type'] as String? ?? 'image';
    final mediaUrl = story['media_url'] as String?;
    final textContent = story['text_content'] as String?;
    final bgColor = story['background_color'] as String? ?? '#000000';
    final username =
        widget.authorProfile['username'] as String? ?? 'Anônimo';
    final avatarUrl = widget.authorProfile['avatar_url'] as String?;
    final createdAt = story['created_at'] as String?;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 3) {
            _prevStory();
          } else if (details.globalPosition.dx > width * 2 / 3) {
            _nextStory();
          }
        },
        onLongPressStart: (_) => _pauseStory(),
        onLongPressEnd: (_) => _resumeStory(),
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            Navigator.of(context).pop();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background / Media ──
            if (type == 'video' && mediaUrl != null)
              _videoController != null && _videoController!.value.isInitialized
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoController!.value.size.width,
                        height: _videoController!.value.size.height,
                        child: VideoPlayer(_videoController!),
                      ),
                    )
                  : Container(
                      color: Colors.black,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    )
            else if (type == 'image' && mediaUrl != null)
              Image.network(
                mediaUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: Colors.black),
              )
            else if (type == 'text')
              Container(
                color: _parseColor(bgColor),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(r.s(32)),
                    child: Text(
                      textContent ?? '',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: r.fs(24),
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              Container(color: Colors.black),

            // ── Gradient overlays ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: r.s(120),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: r.s(160),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── Progress bars ──
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 8,
              child: Row(
                children: List.generate(widget.stories.length, (i) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: SizedBox(
                          height: r.s(3),
                          child: i < _currentIndex
                              ? const LinearProgressIndicator(
                                  value: 1,
                                  backgroundColor: Colors.white24,
                                  valueColor: AlwaysStoppedAnimation(
                                      Colors.white),
                                )
                              : i == _currentIndex
                                  ? AnimatedBuilder(
                                      animation: _progressController,
                                      builder: (_, __) =>
                                          LinearProgressIndicator(
                                        value: _progressController.value,
                                        backgroundColor: Colors.white24,
                                        valueColor:
                                            const AlwaysStoppedAnimation(
                                                Colors.white),
                                      ),
                                    )
                                  : const LinearProgressIndicator(
                                      value: 0,
                                      backgroundColor: Colors.white24,
                                      valueColor: AlwaysStoppedAnimation(
                                          Colors.white24),
                                    ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // ── Header: avatar + username + time + close ──
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: context.cardBg,
                    backgroundImage:
                        avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? Text(username[0].toUpperCase(),
                            style: TextStyle(
                                color: Colors.white, fontSize: r.fs(12)))
                        : null,
                  ),
                  SizedBox(width: r.s(8)),
                  Text(
                    username,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: r.fs(14),
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                  SizedBox(width: r.s(8)),
                  Text(
                    _timeAgo(createdAt),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: r.fs(12),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.close_rounded,
                        color: Colors.white, size: r.s(24)),
                  ),
                ],
              ),
            ),

            // ── Text overlay para stories de imagem ──
            if (type == 'image' && textContent != null && textContent.isNotEmpty)
              Positioned(
                bottom: 100,
                left: 16,
                right: 16,
                child: Container(
                  padding: EdgeInsets.all(r.s(12)),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(r.s(12)),
                  ),
                  child: Text(
                    textContent,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.fs(16),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // ── Reactions bar ──
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(r.s(30)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _reactions.map((emoji) {
                      return GestureDetector(
                        onTap: () => _sendReaction(emoji),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: r.s(8)),
                          child: Text(emoji, style: TextStyle(fontSize: r.fs(24))),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            // ── Views count (para stories do próprio usuário) ──
            if (story['author_id'] == SupabaseService.currentUserId)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 60,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(12), vertical: r.s(4)),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(r.s(12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility_rounded,
                            color: Colors.white70, size: r.s(14)),
                        SizedBox(width: r.s(4)),
                        Text(
                          '${story['views_count'] ?? 0}',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: r.fs(12),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      final h = hex.replaceFirst('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return Colors.black;
    }
  }
}
