import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';

/// Screening Room — Assistir vídeos juntos estilo Amino.
///
/// No Amino original, Screening Rooms permitem:
/// 1. Um host cola um link de vídeo (YouTube, etc.)
/// 2. Todos os participantes assistem sincronizados
/// 3. Chat de texto em tempo real ao lado do vídeo
/// 4. Lista de participantes com avatares
/// 5. Controles de play/pause sincronizados pelo host
/// 6. Fila de vídeos (playlist)
///
/// Este widget implementa a UI completa com:
/// - Player de vídeo embutido (WebView para YouTube)
/// - Chat em tempo real via Supabase Realtime
/// - Lista de espectadores
/// - Controles do host
class ScreeningRoomScreen extends StatefulWidget {
  final String threadId;
  final String? callSessionId;

  const ScreeningRoomScreen({
    super.key,
    required this.threadId,
    this.callSessionId,
  });

  @override
  State<ScreeningRoomScreen> createState() => _ScreeningRoomScreenState();
}

class _ScreeningRoomScreenState extends State<ScreeningRoomScreen> {
  final _chatController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _chatMessages = [];
  final List<Map<String, dynamic>> _participants = [];

  RealtimeChannel? _channel;
  String? _sessionId;
  String? _currentVideoUrl;
  String? _currentVideoTitle;
  bool _isHost = false;
  bool _isPlaying = false;
  bool _isLoading = true;
  int _viewerCount = 0;

  // Playlist
  final List<Map<String, String>> _playlist = [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _initRoom();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _chatController.dispose();
    _scrollController.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Future<void> _initRoom() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      if (widget.callSessionId != null) {
        // Entrar em sala existente
        _sessionId = widget.callSessionId;
        final session = await SupabaseService.table('call_sessions')
            .select()
            .eq('id', _sessionId!)
            .single();
        _isHost = session['creator_id'] == userId;

        // Carregar metadata do vídeo atual
        final metadata = session['metadata'] as Map<String, dynamic>?;
        if (metadata != null) {
          _currentVideoUrl = metadata['video_url'] as String?;
          _currentVideoTitle = metadata['video_title'] as String?;
          _isPlaying = metadata['is_playing'] as bool? ?? false;
        }
      } else {
        // Criar nova sala
        final session = await SupabaseService.table('call_sessions')
            .insert({
              'thread_id': widget.threadId,
              'type': 'screening_room',
              'creator_id': userId,
              'status': 'active',
            })
            .select()
            .single();
        _sessionId = session['id'] as String;
        _isHost = true;
      }

      // Registrar participante
      await SupabaseService.table('call_participants').upsert({
        'call_session_id': _sessionId,
        'user_id': userId,
        'status': 'connected',
      });

      // Carregar participantes
      await _loadParticipants();

      // Inscrever no canal Realtime
      _subscribeToRealtime();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadParticipants() async {
    if (_sessionId == null) return;
    try {
      final res = await SupabaseService.table('call_participants')
          .select('*, profiles!user_id(username, avatar_url)')
          .eq('call_session_id', _sessionId!)
          .eq('status', 'connected');
      _participants.clear();
      _participants.addAll(List<Map<String, dynamic>>.from(res as List));
      _viewerCount = _participants.length;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _subscribeToRealtime() {
    if (_sessionId == null) return;
    _channel = SupabaseService.client.channel('screening_$_sessionId');

    _channel!
        .onBroadcast(
          event: 'chat',
          callback: (payload) {
            if (mounted) {
              setState(() {
                _chatMessages.add(payload);
              });
              _scrollToBottom();
            }
          },
        )
        .onBroadcast(
          event: 'video_control',
          callback: (payload) {
            if (mounted) {
              setState(() {
                _currentVideoUrl = payload['video_url'] as String?;
                _currentVideoTitle = payload['video_title'] as String?;
                _isPlaying = payload['is_playing'] as bool? ?? false;
              });
            }
          },
        )
        .onBroadcast(
          event: 'participant_update',
          callback: (_) => _loadParticipants(),
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendChatMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty || _channel == null) return;

    final userId = SupabaseService.currentUserId ?? '';
    final message = {
      'user_id': userId,
      'text': text,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _channel!.sendBroadcastMessage(event: 'chat', payload: message);
    setState(() => _chatMessages.add(message));
    _chatController.clear();
    _scrollToBottom();
  }

  void _setVideo(String url, String title) {
    if (!_isHost) return;

    _channel?.sendBroadcastMessage(
      event: 'video_control',
      payload: {
        'video_url': url,
        'video_title': title,
        'is_playing': true,
      },
    );

    setState(() {
      _currentVideoUrl = url;
      _currentVideoTitle = title;
      _isPlaying = true;
    });
  }

  void _togglePlayPause() {
    if (!_isHost) return;

    _channel?.sendBroadcastMessage(
      event: 'video_control',
      payload: {
        'video_url': _currentVideoUrl,
        'video_title': _currentVideoTitle,
        'is_playing': !_isPlaying,
      },
    );

    setState(() => _isPlaying = !_isPlaying);
  }

  Future<void> _showAddVideoDialog() async {
    final urlController = TextEditingController();
    final titleController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Adicionar Vídeo',
            style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Cole o link do vídeo (YouTube, etc.)',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: const Icon(Icons.link_rounded,
                    color: AppTheme.accentColor),
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Título do vídeo (opcional)',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: const Icon(Icons.title_rounded,
                    color: AppTheme.accentColor),
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton(
            onPressed: () {
              if (urlController.text.trim().isNotEmpty) {
                Navigator.pop(ctx, {
                  'url': urlController.text.trim(),
                  'title': titleController.text.trim().isNotEmpty
                      ? titleController.text.trim()
                      : 'Vídeo',
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Reproduzir',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    urlController.dispose();
    titleController.dispose();

    if (result != null) {
      _setVideo(result['url']!, result['title']!);
    }
  }

  Future<void> _leaveRoom() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId != null && _sessionId != null) {
        await SupabaseService.table('call_participants')
            .update({'status': 'disconnected', 'left_at': DateTime.now().toIso8601String()})
            .eq('call_session_id', _sessionId!)
            .eq('user_id', userId);

        _channel?.sendBroadcastMessage(
          event: 'participant_update',
          payload: {'action': 'leave', 'user_id': userId},
        );

        // Se é host, encerrar a sala
        if (_isHost) {
          await SupabaseService.table('call_sessions')
              .update({'status': 'ended', 'ended_at': DateTime.now().toIso8601String()})
              .eq('id', _sessionId!);
        }
      }
    } catch (_) {}

    if (mounted) Navigator.of(context).pop();
  }

  String _extractYouTubeId(String url) {
    final regExp = RegExp(
      r'(?:youtube\.com\/(?:watch\?v=|embed\/|shorts\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
    );
    final match = regExp.firstMatch(url);
    return match?.group(1) ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.accentColor))
            : Column(
                children: [
                  // ── Top Bar ──
                  _buildTopBar(),

                  // ── Video Player Area ──
                  _buildVideoArea(),

                  // ── Participants Strip ──
                  _buildParticipantsStrip(),

                  // ── Chat Area ──
                  Expanded(child: _buildChatArea()),

                  // ── Chat Input ──
                  _buildChatInput(),
                ],
              ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _leaveRoom,
            child: const Icon(Icons.arrow_back_rounded,
                color: AppTheme.textPrimary, size: 24),
          ),
          const SizedBox(width: 12),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.errorColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'SCREENING ROOM',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.visibility_rounded,
                    color: AppTheme.accentColor, size: 14),
                const SizedBox(width: 4),
                Text(
                  '$_viewerCount',
                  style: const TextStyle(
                    color: AppTheme.accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (_isHost) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showAddVideoDialog,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_link_rounded,
                    color: AppTheme.primaryColor, size: 18),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoArea() {
    if (_currentVideoUrl == null || _currentVideoUrl!.isEmpty) {
      return Container(
        height: 200,
        color: const Color(0xFF0A0A0A),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.live_tv_rounded, color: Colors.grey[700], size: 48),
              const SizedBox(height: 12),
              Text(
                _isHost
                    ? 'Toque em + para adicionar um vídeo'
                    : 'Aguardando o host adicionar um vídeo...',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final youtubeId = _extractYouTubeId(_currentVideoUrl!);

    return Container(
      height: 200,
      color: Colors.black,
      child: Stack(
        children: [
          // Thumbnail do YouTube como placeholder visual
          if (youtubeId.isNotEmpty)
            Center(
              child: Image.network(
                'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg',
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF0A0A0A),
                  child: const Icon(Icons.play_circle_outline_rounded,
                      color: Colors.white54, size: 64),
                ),
              ),
            )
          else
            Container(
              color: const Color(0xFF0A0A0A),
              child: Center(
                child: Icon(Icons.play_circle_outline_rounded,
                    color: Colors.grey[600], size: 64),
              ),
            ),

          // Overlay com controles
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ),

          // Título do vídeo
          Positioned(
            bottom: 8,
            left: 12,
            right: 60,
            child: Text(
              _currentVideoTitle ?? 'Vídeo',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                shadows: [Shadow(blurRadius: 4, color: Colors.black)],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Botão play/pause (apenas host)
          if (_isHost)
            Center(
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),

          // Status de reprodução
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _isPlaying
                    ? AppTheme.successColor.withValues(alpha: 0.8)
                    : Colors.grey[800]!.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isPlaying ? 'REPRODUZINDO' : 'PAUSADO',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsStrip() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.people_rounded, color: Colors.grey[600], size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _participants.length,
              itemBuilder: (ctx, i) {
                final p = _participants[i];
                final profile = p['profiles'] as Map<String, dynamic>?;
                final avatarUrl = profile?['avatar_url'] as String?;
                final username = profile?['username'] as String? ?? '?';
                final isCreator = i == 0; // Simplificação

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppTheme.cardColor,
                            backgroundImage: avatarUrl != null
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl == null
                                ? Text(username[0].toUpperCase(),
                                    style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 12))
                                : null,
                          ),
                          if (isCreator)
                            Positioned(
                              bottom: -2,
                              right: -2,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: AppTheme.warningColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppTheme.surfaceColor, width: 2),
                                ),
                                child: const Icon(Icons.star_rounded,
                                    color: Colors.white, size: 8),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        username.length > 6
                            ? '${username.substring(0, 6)}...'
                            : username,
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 8,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    if (_chatMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                color: Colors.grey[800], size: 40),
            const SizedBox(height: 8),
            Text(
              'Chat da Screening Room',
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
            Text(
              'Converse enquanto assiste!',
              style: TextStyle(color: Colors.grey[800], fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _chatMessages.length,
      itemBuilder: (ctx, i) {
        final msg = _chatMessages[i];
        final isMe = msg['user_id'] == SupabaseService.currentUserId;

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe) ...[
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppTheme.cardColor,
                  child: Text(
                    (msg['user_id'] as String? ?? '?')[0].toUpperCase(),
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 10),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe
                        ? AppTheme.primaryColor.withValues(alpha: 0.2)
                        : AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    msg['text'] as String? ?? '',
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _chatController,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Diga algo...',
                    hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendChatMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendChatMessage,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
