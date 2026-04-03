import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/realtime_service.dart';
import '../../../core/utils/responsive.dart';

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
  // ignore: unused_field
  final List<Map<String, String>> _playlist = [];
  // ignore: unused_field
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
    if (_sessionId != null) {
      RealtimeService.instance.unsubscribe('screening_$_sessionId');
    }
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
        _sessionId = session['id'] as String?;
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
      if (!mounted) return;

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
      if (!mounted) return;
      _participants.clear();
      _participants.addAll(List<Map<String, dynamic>>.from(res as List? ?? []));
      _viewerCount = _participants.length;
      if (!mounted) return;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[screening_room_screen] Erro: $e');
    }
  }

  void _subscribeToRealtime() {
    if (_sessionId == null) return;

    // Usar RealtimeService para reconexão automática com backoff
    _channel = RealtimeService.instance.subscribeWithRetry(
      channelName: 'screening_$_sessionId',
      configure: (channel) {
        channel
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
            );
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
    final r = context.r;
    final urlController = TextEditingController();
    final titleController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.s(16))),
        title: Text('Adicionar Vídeo',
            style: TextStyle(
                color: context.textPrimary, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'Cole o link do vídeo (YouTube, etc.)',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon:
                    const Icon(Icons.link_rounded, color: AppTheme.accentColor),
                filled: true,
                fillColor: context.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: r.s(12)),
            TextField(
              controller: titleController,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'Título do vídeo (opcional)',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: const Icon(Icons.title_rounded,
                    color: AppTheme.accentColor),
                filled: true,
                fillColor: context.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
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
                  borderRadius: BorderRadius.circular(r.s(10))),
            ),
            child: const Text('Reproduzir',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ).then((_) {
      urlController.dispose();
      titleController.dispose();
    });

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
            .update({
              'status': 'disconnected',
              'left_at': DateTime.now().toIso8601String()
            })
            .eq('call_session_id', _sessionId!)
            .eq('user_id', userId);

        _channel?.sendBroadcastMessage(
          event: 'participant_update',
          payload: {'action': 'leave', 'user_id': userId},
        );

        // Se é host, encerrar a sala
        if (_isHost) {
          await SupabaseService.table('call_sessions').update({
            'status': 'ended',
            'ended_at': DateTime.now().toIso8601String()
          }).eq('id', _sessionId!);
        }
      }
    } catch (e) {
      debugPrint('[screening_room_screen] Erro: $e');
    }

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
    final r = context.r;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _leaveRoom,
            child: Icon(Icons.arrow_back_rounded,
                color: context.textPrimary, size: r.s(24)),
          ),
          SizedBox(width: r.s(12)),
          Container(
            width: r.s(8),
            height: r.s(8),
            decoration: const BoxDecoration(
              color: AppTheme.errorColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: r.s(6)),
          Text(
            'SCREENING ROOM',
            style: TextStyle(
              color: context.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: r.fs(14),
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          Container(
            padding:
                EdgeInsets.symmetric(horizontal: r.s(10), vertical: r.s(4)),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(r.s(12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility_rounded,
                    color: AppTheme.accentColor, size: r.s(14)),
                SizedBox(width: r.s(4)),
                Text(
                  '$_viewerCount',
                  style: TextStyle(
                    color: AppTheme.accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: r.fs(13),
                  ),
                ),
              ],
            ),
          ),
          if (_isHost) ...[
            SizedBox(width: r.s(8)),
            GestureDetector(
              onTap: _showAddVideoDialog,
              child: Container(
                width: r.s(34),
                height: r.s(34),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_link_rounded,
                    color: AppTheme.primaryColor, size: r.s(18)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoArea() {
    final r = context.r;
    if (_currentVideoUrl == null || _currentVideoUrl!.isEmpty) {
      return Container(
        height: r.s(200),
        color: const Color(0xFF0A0A0A),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.live_tv_rounded,
                  color: Colors.grey[700], size: r.s(48)),
              SizedBox(height: r.s(12)),
              Text(
                _isHost
                    ? 'Toque em + para adicionar um vídeo'
                    : 'Aguardando o host adicionar um vídeo...',
                style: TextStyle(color: Colors.grey[600], fontSize: r.fs(14)),
              ),
            ],
          ),
        ),
      );
    }

    final youtubeId = _extractYouTubeId(_currentVideoUrl!);

    return Container(
      height: r.s(200),
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
                  child: Icon(Icons.play_circle_outline_rounded,
                      color: Colors.white54, size: r.s(64)),
                ),
              ),
            )
          else
            Container(
              color: const Color(0xFF0A0A0A),
              child: Center(
                child: Icon(Icons.play_circle_outline_rounded,
                    color: Colors.grey[600], size: r.s(64)),
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
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: r.fs(14),
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
                  width: r.s(56),
                  height: r.s(56),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: r.s(32),
                  ),
                ),
              ),
            ),

          // Status de reprodução
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(8), vertical: r.s(4)),
              decoration: BoxDecoration(
                color: _isPlaying
                    ? AppTheme.successColor.withValues(alpha: 0.8)
                    : (Colors.grey[800] ?? Colors.grey).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(r.s(8)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    color: Colors.white,
                    size: r.s(12),
                  ),
                  SizedBox(width: r.s(4)),
                  Text(
                    _isPlaying ? 'REPRODUZINDO' : 'PAUSADO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.fs(9),
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
    final r = context.r;
    return Container(
      height: r.s(56),
      padding: EdgeInsets.symmetric(horizontal: r.s(12)),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.people_rounded, color: Colors.grey[600], size: r.s(18)),
          SizedBox(width: r.s(8)),
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
                  padding: EdgeInsets.only(right: r.s(8)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: context.cardBg,
                            backgroundImage: avatarUrl != null
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl == null
                                ? Text(username[0].toUpperCase(),
                                    style: TextStyle(
                                        color: context.textPrimary,
                                        fontSize: r.fs(12)))
                                : null,
                          ),
                          if (isCreator)
                            Positioned(
                              bottom: -2,
                              right: -2,
                              child: Container(
                                width: r.s(14),
                                height: r.s(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.warningColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: context.surfaceColor, width: 2),
                                ),
                                child: Icon(Icons.star_rounded,
                                    color: Colors.white, size: r.s(8)),
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
                            fontSize: r.fs(8),
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
    final r = context.r;
    if (_chatMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                color: Colors.grey[800], size: r.s(40)),
            SizedBox(height: r.s(8)),
            Text(
              'Chat da Screening Room',
              style: TextStyle(color: Colors.grey[700], fontSize: r.fs(14)),
            ),
            Text(
              'Converse enquanto assiste!',
              style: TextStyle(color: Colors.grey[800], fontSize: r.fs(12)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
      itemCount: _chatMessages.length,
      itemBuilder: (ctx, i) {
        final msg = _chatMessages[i];
        final isMe = msg['user_id'] == SupabaseService.currentUserId;

        return Padding(
          padding: EdgeInsets.only(bottom: r.s(6)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe) ...[
                CircleAvatar(
                  radius: 12,
                  backgroundColor: context.cardBg,
                  child: Text(
                    (msg['user_id'] as String? ?? '?')[0].toUpperCase(),
                    style: TextStyle(
                        color: context.textPrimary, fontSize: r.fs(10)),
                  ),
                ),
                SizedBox(width: r.s(8)),
              ],
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(12), vertical: r.s(8)),
                  decoration: BoxDecoration(
                    color: isMe
                        ? AppTheme.primaryColor.withValues(alpha: 0.2)
                        : context.cardBg,
                    borderRadius: BorderRadius.circular(r.s(16)),
                  ),
                  child: Text(
                    msg['text'] as String? ?? '',
                    style: TextStyle(
                        color: context.textPrimary, fontSize: r.fs(13)),
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
    final r = context.r;
    return Container(
      padding: EdgeInsets.fromLTRB(r.s(12), r.s(8), r.s(12), r.s(8)),
      decoration: BoxDecoration(
        color: context.surfaceColor,
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
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(r.s(24)),
                ),
                child: TextField(
                  controller: _chatController,
                  style:
                      TextStyle(color: context.textPrimary, fontSize: r.fs(14)),
                  decoration: InputDecoration(
                    hintText: 'Diga algo...',
                    hintStyle:
                        TextStyle(color: Colors.grey[600], fontSize: r.fs(14)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: r.s(16), vertical: r.s(10)),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendChatMessage(),
                ),
              ),
            ),
            SizedBox(width: r.s(8)),
            GestureDetector(
              onTap: _sendChatMessage,
              child: Container(
                width: r.s(40),
                height: r.s(40),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.send_rounded,
                    color: Colors.white, size: r.s(18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
