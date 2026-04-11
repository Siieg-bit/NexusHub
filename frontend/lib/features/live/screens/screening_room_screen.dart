import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/realtime_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';

/// Screening Room — sala de exibição coletiva de vídeos/streams.
///
/// Funcionalidades:
/// - Quem abre a sala é o HOST da rodada.
/// - O host pode adicionar qualquer URL de streaming (YouTube, Twitch, Vimeo,
///   Kick, Dailymotion, Streamable, etc.) com embed automático via WebView.
/// - Quando o host sai, a sala é encerrada para TODOS os participantes.
/// - Os participantes recebem o evento "room_closed" via Realtime e são
///   redirecionados automaticamente com um dialog informativo.
/// - Chat interno em tempo real durante a exibição.
/// - Badge colorido identifica a plataforma do stream.

/// Plataformas suportadas com embed automático.
enum StreamPlatform {
  youtube,
  youtubeShorts,
  twitch,
  twitchClip,
  vimeo,
  kick,
  dailymotion,
  streamable,
  generic,
}

class ScreeningRoomScreen extends ConsumerStatefulWidget {
  final String threadId;
  final String? callSessionId;

  const ScreeningRoomScreen({
    super.key,
    required this.threadId,
    this.callSessionId,
  });

  @override
  ConsumerState<ScreeningRoomScreen> createState() =>
      _ScreeningRoomScreenState();
}

class _ScreeningRoomScreenState extends ConsumerState<ScreeningRoomScreen> {
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
  bool _roomClosed = false;
  int _viewerCount = 0;

  InAppWebViewController? _webViewController;

  // Supabase Realtime para escutar mudanças na call_sessions (encerramento)
  StreamSubscription<List<Map<String, dynamic>>>? _sessionSub;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initRoom();
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    if (_sessionId != null) {
      RealtimeService.instance.unsubscribe('screening_$_sessionId');
    }
    _chatController.dispose();
    _scrollController.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // ── Inicialização ──────────────────────────────────────────────────────────

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

        // Verificar se a sala já foi encerrada
        if ((session['status'] as String?) == 'ended') {
          if (mounted) {
            setState(() {
              _roomClosed = true;
              _isLoading = false;
            });
          }
          return;
        }

        _isHost = session['creator_id'] == userId;

        // Carregar metadata do vídeo atual
        final metadata = session['metadata'] as Map<String, dynamic>?;
        if (metadata != null) {
          _currentVideoUrl = metadata['video_url'] as String?;
          _currentVideoTitle = metadata['video_title'] as String?;
          _isPlaying = metadata['is_playing'] as bool? ?? false;
        }
      } else {
        // Criar nova sala — quem cria É o host
        final session = await SupabaseService.table('call_sessions')
            .insert({
              'thread_id': widget.threadId,
              'type': 'screening_room',
              'creator_id': userId,
              'status': 'active',
              'metadata': <String, dynamic>{},
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

      await _loadParticipants();
      if (!mounted) return;

      _subscribeToRealtime();
      _listenForSessionEnd();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('[screening_room] _initRoom error: $e');
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
      _participants
        ..clear()
        ..addAll(List<Map<String, dynamic>>.from(res as List? ?? []));
      _viewerCount = _participants.length;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[screening_room] _loadParticipants error: $e');
    }
  }

  // ── Realtime ───────────────────────────────────────────────────────────────

  void _subscribeToRealtime() {
    if (_sessionId == null) return;
    _channel = RealtimeService.instance.subscribeWithRetry(
      channelName: 'screening_$_sessionId',
      configure: (channel) {
        channel
            .onBroadcast(
              event: 'chat',
              callback: (payload) {
                if (mounted) {
                  setState(() => _chatMessages.add(payload));
                  _scrollToBottom();
                }
              },
            )
            .onBroadcast(
              event: 'video_control',
              callback: (payload) {
                if (!mounted) return;
                final newUrl = payload['video_url'] as String?;
                final newTitle = payload['video_title'] as String?;
                final playing = payload['is_playing'] as bool? ?? false;
                setState(() {
                  _currentVideoUrl = newUrl;
                  _currentVideoTitle = newTitle;
                  _isPlaying = playing;
                });
                if (newUrl != null && newUrl.isNotEmpty) {
                  _loadUrlInWebView(newUrl);
                }
              },
            )
            .onBroadcast(
              event: 'participant_update',
              callback: (_) => _loadParticipants(),
            )
            .onBroadcast(
              event: 'room_closed',
              callback: (_) {
                if (mounted && !_isHost) {
                  _showRoomClosedDialog();
                }
              },
            );
      },
    );
  }

  /// Escuta mudanças no status da sessão via Postgres Changes (fallback).
  void _listenForSessionEnd() {
    if (_sessionId == null) return;
    final stream = Supabase.instance.client
        .from('call_sessions')
        .stream(primaryKey: ['id'])
        .eq('id', _sessionId!);

    _sessionSub = stream.listen((rows) {
      if (!mounted) return;
      if (rows.isEmpty) return;
      final status = rows.first['status'] as String?;
      if (status == 'ended' && !_isHost && !_roomClosed) {
        _showRoomClosedDialog();
      }
    });
  }

  void _showRoomClosedDialog() {
    if (_roomClosed) return;
    setState(() => _roomClosed = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.r.s(16))),
        title: Text(
          'Sessão encerrada',
          style: TextStyle(
              color: context.textPrimary, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'O host encerrou a Screening Room.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(context.r.s(10))),
            ),
            child: const Text('OK',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Controle de vídeo (apenas host) ───────────────────────────────────────

  void _setVideo(String url, String title) {
    if (!_isHost) return;
    final payload = <String, dynamic>{
      'video_url': url,
      'video_title': title,
      'is_playing': true,
    };
    _channel?.sendBroadcastMessage(event: 'video_control', payload: payload);
    // Persistir no banco para novos participantes
    if (_sessionId != null) {
      SupabaseService.client.rpc('update_screening_metadata', params: {
        'p_session_id': _sessionId,
        'p_metadata': payload,
      }).catchError((e) => debugPrint('[screening_room] metadata update: $e'));
    }
    setState(() {
      _currentVideoUrl = url;
      _currentVideoTitle = title;
      _isPlaying = true;
    });
    _loadUrlInWebView(url);
  }

  void _togglePlayPause() {
    if (!_isHost) return;
    final newPlaying = !_isPlaying;
    final payload = <String, dynamic>{
      'video_url': _currentVideoUrl,
      'video_title': _currentVideoTitle,
      'is_playing': newPlaying,
    };
    _channel?.sendBroadcastMessage(event: 'video_control', payload: payload);
    setState(() => _isPlaying = newPlaying);
    // Tentar controlar o player via JS
    if (newPlaying) {
      _webViewController?.evaluateJavascript(
          source:
              "try { document.querySelector('video').play(); } catch(e) {}");
    } else {
      _webViewController?.evaluateJavascript(
          source:
              "try { document.querySelector('video').pause(); } catch(e) {}");
    }
  }

  // ── WebView ────────────────────────────────────────────────────────────────

  /// Detecta a plataforma e retorna o enum adequado.
  static StreamPlatform detectPlatform(String url) {
    final u = url.toLowerCase();
    if (u.contains('youtube.com/shorts/') || u.contains('youtu.be/shorts/')) {
      return StreamPlatform.youtubeShorts;
    }
    if (u.contains('youtube.com') || u.contains('youtu.be')) {
      return StreamPlatform.youtube;
    }
    if (u.contains('twitch.tv/clip') || u.contains('clips.twitch.tv')) {
      return StreamPlatform.twitchClip;
    }
    if (u.contains('twitch.tv')) return StreamPlatform.twitch;
    if (u.contains('vimeo.com')) return StreamPlatform.vimeo;
    if (u.contains('kick.com')) return StreamPlatform.kick;
    if (u.contains('dailymotion.com')) return StreamPlatform.dailymotion;
    if (u.contains('streamable.com')) return StreamPlatform.streamable;
    return StreamPlatform.generic;
  }

  /// Converte qualquer URL de streaming em URL de embed.
  static String toEmbedUrl(String url) {
    final platform = detectPlatform(url);
    switch (platform) {
      case StreamPlatform.youtube:
      case StreamPlatform.youtubeShorts:
        final id = _extractYouTubeId(url);
        if (id.isNotEmpty) {
          return 'https://www.youtube.com/embed/$id?autoplay=1&rel=0&modestbranding=1';
        }
        return url;

      case StreamPlatform.twitch:
        final match = RegExp(r'twitch\.tv/([a-zA-Z0-9_]+)').firstMatch(url);
        final channel = match?.group(1) ?? '';
        if (channel.isNotEmpty) {
          return 'https://player.twitch.tv/?channel=$channel&parent=localhost&autoplay=true&muted=false';
        }
        return url;

      case StreamPlatform.twitchClip:
        final match = RegExp(
                r'(?:clips\.twitch\.tv/|twitch\.tv/\w+/clip/)([a-zA-Z0-9_-]+)')
            .firstMatch(url);
        final clip = match?.group(1) ?? '';
        if (clip.isNotEmpty) {
          return 'https://clips.twitch.tv/embed?clip=$clip&parent=localhost&autoplay=true';
        }
        return url;

      case StreamPlatform.vimeo:
        final match = RegExp(r'vimeo\.com/(\d+)').firstMatch(url);
        final id = match?.group(1) ?? '';
        if (id.isNotEmpty) {
          return 'https://player.vimeo.com/video/$id?autoplay=1&title=0&byline=0&portrait=0';
        }
        return url;

      case StreamPlatform.kick:
        final match = RegExp(r'kick\.com/([a-zA-Z0-9_]+)').firstMatch(url);
        final channel = match?.group(1) ?? '';
        if (channel.isNotEmpty) {
          return 'https://player.kick.com/$channel?autoplay=true';
        }
        return url;

      case StreamPlatform.dailymotion:
        final match =
            RegExp(r'dailymotion\.com/video/([a-zA-Z0-9]+)').firstMatch(url);
        final id = match?.group(1) ?? '';
        if (id.isNotEmpty) {
          return 'https://www.dailymotion.com/embed/video/$id?autoplay=1';
        }
        return url;

      case StreamPlatform.streamable:
        final match =
            RegExp(r'streamable\.com/([a-zA-Z0-9]+)').firstMatch(url);
        final id = match?.group(1) ?? '';
        if (id.isNotEmpty) {
          return 'https://streamable.com/e/$id?autoplay=1';
        }
        return url;

      case StreamPlatform.generic:
        return url;
    }
  }

  static String _extractYouTubeId(String url) {
    final regExp = RegExp(
      r'(?:youtube\.com/(?:watch\?v=|embed/|shorts/|live/)|youtu\.be/)([a-zA-Z0-9_-]{11})',
    );
    return regExp.firstMatch(url)?.group(1) ?? '';
  }

  void _loadUrlInWebView(String url) {
    if (_webViewController == null) return;
    final embedUrl = toEmbedUrl(url);
    _webViewController!.loadUrl(
      urlRequest: URLRequest(url: WebUri(embedUrl)),
    );
  }

  // ── Sair da sala ──────────────────────────────────────────────────────────

  Future<void> _leaveRoom() async {
    if (_isHost) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.surfaceColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.r.s(16))),
          title: Text(
            'Encerrar Screening Room?',
            style: TextStyle(
                color: context.textPrimary, fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Como host, ao sair você encerrará a sala para todos os participantes.',
            style: TextStyle(color: Colors.grey[400]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  Text('Cancelar', style: TextStyle(color: Colors.grey[500])),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.r.s(10))),
              ),
              child: const Text('Encerrar',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    try {
      final userId = SupabaseService.currentUserId;
      if (userId != null && _sessionId != null) {
        await SupabaseService.table('call_participants')
            .update({
              'status': 'disconnected',
              'left_at': DateTime.now().toIso8601String(),
            })
            .eq('call_session_id', _sessionId!)
            .eq('user_id', userId);

        if (_isHost) {
          // Notificar todos via Broadcast ANTES de encerrar no banco
          _channel?.sendBroadcastMessage(
            event: 'room_closed',
            payload: {'host_id': userId},
          );
          await Future.delayed(const Duration(milliseconds: 200));

          // Encerrar via RPC (atualiza status + desconecta todos)
          await SupabaseService.client.rpc('end_screening_session',
              params: {'p_session_id': _sessionId});

          // Enviar mensagem de sistema no chat
          await SupabaseService.client.rpc(
            'send_chat_message_with_reputation',
            params: {
              'p_thread_id': widget.threadId,
              'p_content': 'Screening Room encerrada',
              'p_type': 'system_screen_end',
              'p_media_url': null,
              'p_media_type': null,
              'p_media_duration': null,
              'p_reply_to': null,
              'p_sticker_id': null,
              'p_sticker_url': null,
              'p_sticker_name': null,
              'p_pack_id': null,
            },
          );
        } else {
          _channel?.sendBroadcastMessage(
            event: 'participant_update',
            payload: {'action': 'leave', 'user_id': userId},
          );
        }
      }
    } catch (e) {
      debugPrint('[screening_room] _leaveRoom error: $e');
    }

    if (mounted) Navigator.of(context).pop();
  }

  // ── Chat ──────────────────────────────────────────────────────────────────

  Future<void> _sendChatMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty || _sessionId == null) return;
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    _chatController.clear();
    final msg = <String, dynamic>{
      'user_id': userId,
      'text': text,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };
    _channel?.sendBroadcastMessage(event: 'chat', payload: msg);
    if (mounted) {
      setState(() => _chatMessages.add(msg));
      _scrollToBottom();
    }
  }

  // ── Dialog de adicionar vídeo ─────────────────────────────────────────────

  Future<void> _showAddVideoDialog() async {
    final r = context.r;
    final urlController = TextEditingController();
    final titleController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.s(16))),
        title: Text(
          'Adicionar vídeo / stream',
          style: TextStyle(
              color: ctx.textPrimary, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _platformChip(ctx, 'YouTube'),
                _platformChip(ctx, 'Twitch'),
                _platformChip(ctx, 'Vimeo'),
                _platformChip(ctx, 'Kick'),
                _platformChip(ctx, 'Dailymotion'),
                _platformChip(ctx, 'Streamable'),
              ],
            ),
            SizedBox(height: r.s(12)),
            TextField(
              controller: urlController,
              autofocus: true,
              style: TextStyle(color: ctx.textPrimary),
              decoration: InputDecoration(
                hintText: 'Cole o link do vídeo ou stream',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: const Icon(Icons.link_rounded,
                    color: AppTheme.accentColor),
                filled: true,
                fillColor: ctx.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: r.s(12)),
            TextField(
              controller: titleController,
              style: TextStyle(color: ctx.textPrimary),
              decoration: InputDecoration(
                hintText: 'Título (opcional)',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: const Icon(Icons.title_rounded,
                    color: AppTheme.accentColor),
                filled: true,
                fillColor: ctx.cardBg,
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
            child:
                Text('Cancelar', style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton(
            onPressed: () {
              if (urlController.text.trim().isNotEmpty) {
                Navigator.pop(ctx, {
                  'url': urlController.text.trim(),
                  'title': titleController.text.trim().isNotEmpty
                      ? titleController.text.trim()
                      : _autoTitle(urlController.text.trim()),
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
    ).then((v) {
      urlController.dispose();
      titleController.dispose();
      return v;
    });

    if (result != null) {
      _setVideo(result['url']!, result['title']!);
    }
  }

  Widget _platformChip(BuildContext ctx, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(label,
          style: TextStyle(
              color: AppTheme.primaryColor,
              fontSize: ctx.r.fs(10),
              fontWeight: FontWeight.w600)),
    );
  }

  String _autoTitle(String url) {
    switch (detectPlatform(url)) {
      case StreamPlatform.youtube:
      case StreamPlatform.youtubeShorts:
        return 'YouTube';
      case StreamPlatform.twitch:
      case StreamPlatform.twitchClip:
        return 'Twitch';
      case StreamPlatform.vimeo:
        return 'Vimeo';
      case StreamPlatform.kick:
        return 'Kick';
      case StreamPlatform.dailymotion:
        return 'Dailymotion';
      case StreamPlatform.streamable:
        return 'Streamable';
      case StreamPlatform.generic:
        return 'Vídeo';
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.accentColor))
            : _roomClosed
                ? _buildRoomClosedState()
                : Column(
                    children: [
                      _buildTopBar(),
                      _buildVideoArea(),
                      _buildParticipantsStrip(),
                      Expanded(child: _buildChatArea()),
                      _buildChatInput(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildRoomClosedState() {
    final r = context.r;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.tv_off_rounded, color: Colors.grey[700], size: r.s(64)),
          SizedBox(height: r.s(16)),
          Text(
            'Screening Room encerrada',
            style: TextStyle(
                color: Colors.grey[400],
                fontSize: r.fs(18),
                fontWeight: FontWeight.w700),
          ),
          SizedBox(height: r.s(8)),
          Text(
            'O host encerrou esta sessão.',
            style: TextStyle(color: Colors.grey[600], fontSize: r.fs(14)),
          ),
          SizedBox(height: r.s(24)),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.s(12))),
              padding: EdgeInsets.symmetric(
                  horizontal: r.s(32), vertical: r.s(12)),
            ),
            child: const Text('Voltar ao chat',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
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
            bottom:
                BorderSide(color: Colors.white.withValues(alpha: 0.05))),
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
          if (_isHost) ...[
            SizedBox(width: r.s(8)),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: r.s(6), vertical: r.s(2)),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(r.s(6)),
                border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.5)),
              ),
              child: Text(
                'HOST',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: r.fs(9),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
          const Spacer(),
          Row(
            children: [
              Icon(Icons.visibility_rounded,
                  color: Colors.grey[600], size: r.s(14)),
              SizedBox(width: r.s(4)),
              Text(
                '$_viewerCount',
                style:
                    TextStyle(color: Colors.grey[500], fontSize: r.fs(12)),
              ),
            ],
          ),
          if (_isHost) ...[
            SizedBox(width: r.s(12)),
            GestureDetector(
              onTap: _showAddVideoDialog,
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: r.s(10), vertical: r.s(6)),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(r.s(20)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded,
                        color: Colors.white, size: r.s(14)),
                    SizedBox(width: r.s(4)),
                    Text(
                      'Vídeo',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: r.fs(11),
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
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
        height: r.s(220),
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
                    ? 'Toque em "+ Vídeo" para começar'
                    : 'Aguardando o host iniciar...',
                style: TextStyle(
                    color: Colors.grey[600], fontSize: r.fs(14)),
              ),
              if (_isHost) ...[
                SizedBox(height: r.s(16)),
                GestureDetector(
                  onTap: _showAddVideoDialog,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(20), vertical: r.s(10)),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(r.s(24)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded,
                            color: Colors.white, size: r.s(16)),
                        SizedBox(width: r.s(6)),
                        Text('Adicionar vídeo / stream',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: r.fs(13),
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final embedUrl = toEmbedUrl(_currentVideoUrl!);
    final platform = detectPlatform(_currentVideoUrl!);

    return Container(
      height: r.s(220),
      color: Colors.black,
      child: Stack(
        children: [
          // ── WebView com o player embutido ──
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(embedUrl)),
            initialSettings: InAppWebViewSettings(
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              javaScriptEnabled: true,
              domStorageEnabled: true,
              useWideViewPort: true,
              loadWithOverviewMode: true,
              supportZoom: false,
              disableHorizontalScroll: true,
              disableVerticalScroll: true,
              userAgent:
                  'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            onLoadStop: (controller, url) {
              controller.evaluateJavascript(
                  source:
                      "try { document.querySelector('video').play(); } catch(e) {}");
            },
          ),
          // ── Badge da plataforma ──
          Positioned(
            top: 8,
            left: 8,
            child: _buildPlatformBadge(platform),
          ),
          // ── Título do vídeo ──
          Positioned(
            bottom: 8,
            left: 12,
            right: _isHost ? 60 : 12,
            child: Text(
              _currentVideoTitle ?? 'Vídeo',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: r.fs(13),
                shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // ── Botão play/pause (apenas host) ──
          if (_isHost)
            Positioned(
              bottom: 4,
              right: 8,
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: r.s(36),
                  height: r.s(36),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: r.s(20),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlatformBadge(StreamPlatform platform) {
    final r = context.r;
    String label;
    Color color;
    switch (platform) {
      case StreamPlatform.youtube:
      case StreamPlatform.youtubeShorts:
        label = 'YouTube';
        color = const Color(0xFFFF0000);
        break;
      case StreamPlatform.twitch:
      case StreamPlatform.twitchClip:
        label = 'Twitch';
        color = const Color(0xFF9146FF);
        break;
      case StreamPlatform.vimeo:
        label = 'Vimeo';
        color = const Color(0xFF1AB7EA);
        break;
      case StreamPlatform.kick:
        label = 'Kick';
        color = const Color(0xFF53FC18);
        break;
      case StreamPlatform.dailymotion:
        label = 'Dailymotion';
        color = const Color(0xFF0066DC);
        break;
      case StreamPlatform.streamable:
        label = 'Streamable';
        color = const Color(0xFF00B4D8);
        break;
      case StreamPlatform.generic:
        label = 'Web';
        color = Colors.grey;
        break;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.s(6), vertical: r.s(3)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(r.s(6)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: Colors.white,
            fontSize: r.fs(9),
            fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildParticipantsStrip() {
    final r = context.r;
    return Container(
      height: r.s(64),
      color: context.surfaceColor,
      padding:
          EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
      child: Row(
        children: [
          Icon(Icons.people_rounded,
              color: Colors.grey[600], size: r.s(16)),
          SizedBox(width: r.s(8)),
          Text(
            '$_viewerCount assistindo',
            style: TextStyle(color: Colors.grey[500], fontSize: r.fs(11)),
          ),
          SizedBox(width: r.s(12)),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _participants.length,
              itemBuilder: (ctx, i) {
                final p = _participants[i];
                final profile = p['profiles'] as Map<String, dynamic>?;
                final username = profile?['username'] as String? ?? '?';
                final avatarUrl = profile?['avatar_url'] as String?;
                return Padding(
                  padding: EdgeInsets.only(right: r.s(8)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: r.s(16),
                        backgroundColor: context.cardBg,
                        backgroundImage:
                            avatarUrl != null && avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                        child: avatarUrl == null || avatarUrl.isEmpty
                            ? Text(
                                username[0].toUpperCase(),
                                style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: r.fs(10)),
                              )
                            : null,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        username.length > 6
                            ? '${username.substring(0, 6)}…'
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
              style:
                  TextStyle(color: Colors.grey[700], fontSize: r.fs(14)),
            ),
            Text(
              'Converse enquanto assiste!',
              style:
                  TextStyle(color: Colors.grey[800], fontSize: r.fs(12)),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding:
          EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
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
            top:
                BorderSide(color: Colors.white.withValues(alpha: 0.05))),
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
                  style: TextStyle(
                      color: context.textPrimary, fontSize: r.fs(14)),
                  decoration: InputDecoration(
                    hintText: 'Diga algo...',
                    hintStyle: TextStyle(
                        color: Colors.grey[600], fontSize: r.fs(14)),
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
