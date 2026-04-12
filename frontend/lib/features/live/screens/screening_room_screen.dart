import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/realtime_service.dart';
import '../../../core/utils/responsive.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Sala de Projeção — sala de exibição coletiva de vídeos/streams.
///
/// Técnicas anti-bloqueio implementadas:
/// - HTML wrapper local com <iframe> e todos os atributos de permissão
/// - User-agent de desktop Chrome para contornar bloqueios mobile
/// - Headers customizados (Referer, Origin) para Twitch/YouTube
/// - JS injection pós-carregamento para forçar autoplay e remover overlays
/// - Retry automático em caso de falha de carregamento
/// - Cache e cookies habilitados
/// - Twitch: parent domain dinâmico via múltiplas tentativas
/// - YouTube: nocookie domain + parâmetros anti-bloqueio

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
  bool _webViewLoading = false;
  int _viewerCount = 0;
  int _loadRetryCount = 0;

  InAppWebViewController? _webViewController;
  StreamSubscription<List<Map<String, dynamic>>>? _sessionSub;
  Timer? _heartbeatTimer;
  Timer? _cleanupTimer;

  // Perfil do usuário atual (para exibir no chat interno)
  String? _myUsername;
  String? _myAvatarUrl;

  // User-agent de desktop Chrome — contorna bloqueios de WebView mobile
  static const _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  // User-agent mobile como fallback
  static const _mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initRoom();
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _cleanupTimer?.cancel();
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
        _sessionId = widget.callSessionId;
        final session = await SupabaseService.table('call_sessions')
            .select()
            .eq('id', _sessionId!)
            .single();

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

        final metadata = session['metadata'] as Map<String, dynamic>?;
        if (metadata != null) {
          _currentVideoUrl = metadata['video_url'] as String?;
          _currentVideoTitle = metadata['video_title'] as String?;
          _isPlaying = metadata['is_playing'] as bool? ?? false;
        }
      } else {
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

      await SupabaseService.table('call_participants').upsert({
        'call_session_id': _sessionId,
        'user_id': userId,
        'status': 'connected',
        'last_heartbeat': DateTime.now().toIso8601String(),
      });

      // Carregar perfil do usuário atual para exibir no chat interno
      try {
        final profile = await SupabaseService.table('profiles')
            .select('username, avatar_url')
            .eq('id', userId)
            .single();
        _myUsername = profile['username'] as String?;
        _myAvatarUrl = profile['avatar_url'] as String?;
      } catch (_) {}

      await _loadParticipants();
      await _loadChatHistory();
      if (!mounted) return;

      _subscribeToRealtime();
      _listenForSessionEnd();
      _startHeartbeat();

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

  // ── Histórico do chat interno ──────────────────────────────────────────────

  Future<void> _loadChatHistory() async {
    if (_sessionId == null) return;
    try {
      final rows = await SupabaseService.client.rpc(
        'get_screening_chat_history',
        params: {'p_session_id': _sessionId, 'p_limit': 100},
      );
      if (!mounted) return;
      final msgs = (rows as List? ?? []).map((r) {
        final m = Map<String, dynamic>.from(r as Map);
        // Normalizar para o mesmo formato usado pelo Broadcast
        return <String, dynamic>{
          'user_id': m['user_id'],
          'username': m['username'],
          'avatar_url': m['avatar_url'],
          'text': m['text'],
          'ts': DateTime.parse(m['created_at'] as String)
              .millisecondsSinceEpoch,
          'persisted': true,
        };
      }).toList();
      setState(() {
        _chatMessages
          ..clear()
          ..addAll(msgs);
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('[screening_room] _loadChatHistory error: $e');
    }
  }

  // ── Heartbeat ─────────────────────────────────────────────────────────────

  void _startHeartbeat() {
    if (_sessionId == null) return;
    // Envia heartbeat a cada 30s para manter o participante como 'connected'
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      try {
        await SupabaseService.client.rpc(
          'send_screening_heartbeat',
          params: {'p_session_id': _sessionId},
        );
      } catch (e) {
        debugPrint('[screening_room] heartbeat error: $e');
      }
    });
    // Se for host, limpa participantes inativos a cada 90s
    if (_isHost) {
      _cleanupTimer = Timer.periodic(const Duration(seconds: 90), (_) async {
        try {
          await SupabaseService.client.rpc(
            'cleanup_inactive_screening_participants',
            params: {'p_session_id': _sessionId},
          );
          await _loadParticipants();
        } catch (e) {
          debugPrint('[screening_room] cleanup error: $e');
        }
      });
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
                  _loadRetryCount = 0;
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
              color: context.nexusTheme.textPrimary, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'O host encerrou a Sala de Projeção.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.nexusTheme.accentPrimary,
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
      _loadRetryCount = 0;
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
    _injectPlayPauseJs(newPlaying);
  }

  // ── Anti-bloqueio: JS injection ────────────────────────────────────────────

  /// Injeta JS para forçar autoplay e remover overlays/banners de bloqueio.
  void _injectAutoplayJs() {
    _webViewController?.evaluateJavascript(source: r"""
      (function() {
        // 1. Forçar play em todos os elementos <video>
        var videos = document.querySelectorAll('video');
        videos.forEach(function(v) {
          v.muted = false;
          v.autoplay = true;
          v.play().catch(function() {
            // Se falhar sem mute, tenta com mute (política de autoplay)
            v.muted = true;
            v.play().catch(function(){});
          });
        });

        // 2. Remover overlays de "clique para reproduzir" comuns
        var overlaySelectors = [
          '.ytp-cued-thumbnail-overlay',
          '.ytp-large-play-button',
          '[class*="play-overlay"]',
          '[class*="click-to-play"]',
          '[id*="play-overlay"]',
          '.vp-preview',
          '.player-overlay',
        ];
        overlaySelectors.forEach(function(sel) {
          var els = document.querySelectorAll(sel);
          els.forEach(function(el) { el.style.display = 'none'; });
        });

        // 3. Simular clique no botão de play se ainda não tocou
        var playBtns = document.querySelectorAll(
          '.ytp-large-play-button, [aria-label="Play"], [title="Play"], '
          + '.play-button, .vjs-play-control, .fp-play'
        );
        playBtns.forEach(function(btn) { btn.click(); });
      })();
    """);
  }

  void _injectPlayPauseJs(bool play) {
    _webViewController?.evaluateJavascript(source: """
      (function() {
        var videos = document.querySelectorAll('video');
        videos.forEach(function(v) {
          if ($play) { v.play().catch(function(){}); }
          else { v.pause(); }
        });
      })();
    """);
  }

  /// Injeta CSS para remover banners de "abrir no app" e popups de cookies.
  void _injectCleanupCss() {
    _webViewController?.evaluateJavascript(source: r"""
      (function() {
        var style = document.createElement('style');
        style.textContent = `
          /* Remover banner "Abrir no app" do YouTube */
          .ytp-mobile-app-promo, .ytp-app-promo-banner,
          ytm-app-promo-banner-renderer, ytm-companion-slot,
          /* Remover banner de cookies/GDPR */
          #consent-bump, .consent-bump-v2, [id*="cookie-banner"],
          [class*="cookie-consent"], [class*="gdpr"],
          /* Remover overlays de login */
          .sign-in-container, [class*="signin-prompt"],
          /* Remover popups genéricos */
          .modal-overlay, [class*="paywall"] { display: none !important; }
          /* Garantir que o vídeo ocupe todo o espaço */
          video { width: 100% !important; height: 100% !important; }
          body { margin: 0 !important; overflow: hidden !important; }
        `;
        document.head.appendChild(style);
      })();
    """);
  }

  // ── Anti-bloqueio: HTML Wrapper ────────────────────────────────────────────

  /// Gera um HTML local que embute o player via <iframe> com todos os
  /// atributos de permissão necessários. Isso contorna restrições de
  /// X-Frame-Options e permite autoplay sem interação do usuário.
  static String _buildHtmlWrapper(String embedUrl, StreamPlatform platform) {
    // Atributos allow para o iframe — cobrem todas as APIs necessárias
    const iframeAllow =
        'autoplay; fullscreen; picture-in-picture; encrypted-media; '
        'accelerometer; gyroscope; clipboard-write; web-share; '
        'cross-origin-isolated';

    // Parâmetros extras por plataforma
    String finalUrl = embedUrl;

    // Para YouTube: adicionar parâmetros anti-bloqueio extras
    if (platform == StreamPlatform.youtube ||
        platform == StreamPlatform.youtubeShorts) {
      final uri = Uri.tryParse(embedUrl);
      if (uri != null) {
        final params = Map<String, String>.from(uri.queryParameters);
        params['autoplay'] = '1';
        params['mute'] = '0';
        params['enablejsapi'] = '1';
        params['origin'] = 'https://www.youtube.com';
        params['widget_referrer'] = 'https://www.youtube.com';
        params['rel'] = '0';
        params['modestbranding'] = '1';
        params['playsinline'] = '1';
        finalUrl = uri.replace(queryParameters: params).toString();
      }
    }

    return '''<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
  iframe {
    width: 100%;
    height: 100%;
    border: none;
    display: block;
  }
</style>
</head>
<body>
<iframe
  src="$finalUrl"
  allow="$iframeAllow"
  allowfullscreen
  allowtransparency="true"
  frameborder="0"
  scrolling="no"
  referrerpolicy="origin"
></iframe>
<script>
  // Tentar desbloquear autoplay após carregamento
  window.addEventListener('load', function() {
    var iframe = document.querySelector('iframe');
    if (iframe) {
      // Simular interação do usuário para desbloquear autoplay
      iframe.contentWindow && iframe.contentWindow.postMessage(
        JSON.stringify({event: 'command', func: 'playVideo', args: []}),
        '*'
      );
    }
  });

  // Escutar mensagens do iframe (YouTube API)
  window.addEventListener('message', function(e) {
    try {
      var data = JSON.parse(e.data);
      if (data.event === 'onReady') {
        e.source.postMessage(
          JSON.stringify({event: 'command', func: 'playVideo', args: []}),
          '*'
        );
      }
    } catch(err) {}
  });
</script>
</body>
</html>''';
  }

  // ── WebView: carregamento ──────────────────────────────────────────────────

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

  /// Converte URL de streaming em URL de embed com parâmetros anti-bloqueio.
  static String toEmbedUrl(String url) {
    final platform = detectPlatform(url);
    switch (platform) {
      case StreamPlatform.youtube:
      case StreamPlatform.youtubeShorts:
        final id = _extractYouTubeId(url);
        if (id.isNotEmpty) {
          // Usar youtube-nocookie.com para evitar rastreamento e bloqueios
          return 'https://www.youtube-nocookie.com/embed/$id'
              '?autoplay=1&mute=0&rel=0&modestbranding=1'
              '&playsinline=1&enablejsapi=1&origin=https://www.youtube.com';
        }
        return url;

      case StreamPlatform.twitch:
        final match = RegExp(r'twitch\.tv/([a-zA-Z0-9_]+)').firstMatch(url);
        final channel = match?.group(1) ?? '';
        if (channel.isNotEmpty) {
          // Múltiplos parents para cobrir diferentes ambientes
          return 'https://player.twitch.tv/?channel=$channel'
              '&parent=localhost&parent=127.0.0.1&parent=nexushub.app'
              '&autoplay=true&muted=false';
        }
        return url;

      case StreamPlatform.twitchClip:
        final match = RegExp(
                r'(?:clips\.twitch\.tv/|twitch\.tv/\w+/clip/)([a-zA-Z0-9_-]+)')
            .firstMatch(url);
        final clip = match?.group(1) ?? '';
        if (clip.isNotEmpty) {
          return 'https://clips.twitch.tv/embed?clip=$clip'
              '&parent=localhost&parent=127.0.0.1&parent=nexushub.app'
              '&autoplay=true';
        }
        return url;

      case StreamPlatform.vimeo:
        final match = RegExp(r'vimeo\.com/(\d+)').firstMatch(url);
        final id = match?.group(1) ?? '';
        if (id.isNotEmpty) {
          return 'https://player.vimeo.com/video/$id'
              '?autoplay=1&title=0&byline=0&portrait=0&dnt=1';
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
          return 'https://www.dailymotion.com/embed/video/$id'
              '?autoplay=1&mute=0&ui-logo=false';
        }
        return url;

      case StreamPlatform.streamable:
        final match =
            RegExp(r'streamable\.com/([a-zA-Z0-9]+)').firstMatch(url);
        final id = match?.group(1) ?? '';
        if (id.isNotEmpty) {
          return 'https://streamable.com/e/$id?autoplay=1&nocontrols=0';
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
    final platform = detectPlatform(url);
    final embedUrl = toEmbedUrl(url);

    if (platform == StreamPlatform.generic) {
      // URLs genéricas: carregar diretamente
      _webViewController!.loadUrl(
        urlRequest: URLRequest(
          url: WebUri(embedUrl),
          headers: {
            'Referer': 'https://www.google.com',
            'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
          },
        ),
      );
    } else {
      // Plataformas conhecidas: usar HTML wrapper para máxima compatibilidade
      final html = _buildHtmlWrapper(embedUrl, platform);
      _webViewController!.loadData(
        data: html,
        mimeType: 'text/html',
        encoding: 'UTF-8',
        baseUrl: WebUri('https://nexushub.app'),
      );
    }
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
            'Encerrar Sala de Projeção?',
            style: TextStyle(
                color: context.nexusTheme.textPrimary, fontWeight: FontWeight.w800),
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
                backgroundColor: context.nexusTheme.error,
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
          _channel?.sendBroadcastMessage(
            event: 'room_closed',
            payload: {'host_id': userId},
          );
          await Future.delayed(const Duration(milliseconds: 200));

          await SupabaseService.client.rpc('end_screening_session',
              params: {'p_session_id': _sessionId});

          await SupabaseService.client.rpc(
            'send_chat_message_with_reputation',
            params: {
              'p_thread_id': widget.threadId,
              'p_content': 'Sala de Projeção encerrada',
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
      'username': _myUsername ?? 'Usuário',
      'avatar_url': _myAvatarUrl,
      'text': text,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };

    // Broadcast em tempo real para todos na sala
    _channel?.sendBroadcastMessage(event: 'chat', payload: msg);

    // Persistir no banco para histórico
    SupabaseService.table('screening_chat_messages').insert({
      'session_id': _sessionId,
      'user_id': userId,
      'text': text,
    }).catchError((e) => debugPrint('[screening_room] persist chat: $e'));

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
                prefixIcon: Icon(Icons.link_rounded,
                    color: context.nexusTheme.accentSecondary),
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
                prefixIcon: Icon(Icons.title_rounded,
                    color: context.nexusTheme.accentSecondary),
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
              backgroundColor: context.nexusTheme.accentPrimary,
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
        color: context.nexusTheme.accentPrimary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: context.nexusTheme.accentPrimary.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(label,
          style: TextStyle(
              color: context.nexusTheme.accentPrimary,
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
            ? Center(
                child: CircularProgressIndicator(color: context.nexusTheme.accentSecondary))
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
            'Sala de Projeção encerrada',
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
              backgroundColor: context.nexusTheme.accentPrimary,
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
                color: context.nexusTheme.textPrimary, size: r.s(24)),
          ),
          SizedBox(width: r.s(12)),
          Container(
            width: r.s(8),
            height: r.s(8),
            decoration: BoxDecoration(
              color: context.nexusTheme.error,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: r.s(6)),
          Text(
            'SALA DE PROJEÇÃO',
            style: TextStyle(
              color: context.nexusTheme.textPrimary,
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
                color: context.nexusTheme.accentPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(r.s(6)),
                border: Border.all(
                    color: context.nexusTheme.accentPrimary.withValues(alpha: 0.5)),
              ),
              child: Text(
                'HOST',
                style: TextStyle(
                  color: context.nexusTheme.accentPrimary,
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
                  color: context.nexusTheme.accentPrimary,
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
                      color: context.nexusTheme.accentPrimary,
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

    final platform = detectPlatform(_currentVideoUrl!);
    final embedUrl = toEmbedUrl(_currentVideoUrl!);

    return Container(
      height: r.s(220),
      color: Colors.black,
      child: Stack(
        children: [
          // ── WebView com anti-bloqueio ──
          InAppWebView(
            // Para plataformas conhecidas, usar HTML wrapper via loadData
            // Para genéricas, usar initialUrlRequest
            initialUrlRequest: platform == StreamPlatform.generic
                ? URLRequest(
                    url: WebUri(embedUrl),
                    headers: {
                      'Referer': 'https://www.google.com',
                      'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
                    },
                  )
                : null,
            initialData: platform != StreamPlatform.generic
                ? InAppWebViewInitialData(
                    data: _buildHtmlWrapper(embedUrl, platform),
                    mimeType: 'text/html',
                    encoding: 'UTF-8',
                    baseUrl: WebUri('https://nexushub.app'),
                  )
                : null,
            initialSettings: InAppWebViewSettings(
              // ── Autoplay e mídia ──
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              allowsPictureInPictureMediaPlayback: true,
              // ── JavaScript e DOM ──
              javaScriptEnabled: true,
              javaScriptCanOpenWindowsAutomatically: false,
              domStorageEnabled: true,
              databaseEnabled: true,
              // ── Cache e cookies (evita re-autenticação) ──
              cacheEnabled: true,
              cacheMode: CacheMode.LOAD_DEFAULT,
              // ── Layout ──
              useWideViewPort: true,
              loadWithOverviewMode: true,
              supportZoom: false,
              disableHorizontalScroll: true,
              disableVerticalScroll: true,
              // ── User-agent de desktop Chrome ──
              // Contorna bloqueios de WebView mobile em YouTube/Twitch
              userAgent: _desktopUserAgent,
              // ── Mixed content (HTTP dentro de HTTPS) ──
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              // ── Transparência ──
              transparentBackground: true,
              // ── Geolocalização desabilitada ──
              geolocationEnabled: false,
              // ── Permitir navegação por file:// e data:// ──
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
              // ── Desabilitar detecção de telefone/email (evita redirecionamentos) ──
              dataDetectorTypes: const [DataDetectorTypes.NONE],
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
            },
            onLoadStart: (controller, url) {
              if (mounted) setState(() => _webViewLoading = true);
            },
            onLoadStop: (controller, url) async {
              if (mounted) setState(() => _webViewLoading = false);
              // Injetar CSS de limpeza e JS de autoplay
              await Future.delayed(const Duration(milliseconds: 500));
              _injectCleanupCss();
              await Future.delayed(const Duration(milliseconds: 300));
              _injectAutoplayJs();
            },
            onReceivedError: (controller, request, error) {
              debugPrint('[screening_room] WebView error: ${error.description}');
              // Retry automático com user-agent mobile como fallback
              if (_loadRetryCount < 1 && _currentVideoUrl != null) {
                _loadRetryCount++;
                Future.delayed(const Duration(seconds: 2), () {
                  if (!mounted || _webViewController == null) return;
                  // Na segunda tentativa, usar user-agent mobile
                  _webViewController!.getSettings().then((settings) {
                    if (settings != null) {
                      settings.userAgent = _mobileUserAgent;
                      _webViewController!.setSettings(settings: settings);
                    }
                  });
                  _loadUrlInWebView(_currentVideoUrl!);
                });
              }
            },
            onConsoleMessage: (controller, msg) {
              debugPrint('[WebView console] ${msg.message}');
            },
            // Interceptar requisições para adicionar headers customizados
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url?.toString() ?? '';
              // Bloquear redirecionamentos para app stores (evita saída do WebView)
              if (url.contains('market://') ||
                  url.contains('itms-apps://') ||
                  url.contains('intent://')) {
                return NavigationActionPolicy.CANCEL;
              }
              return NavigationActionPolicy.ALLOW;
            },
          ),

          // ── Loading indicator ──
          if (_webViewLoading)
            Center(
              child: CircularProgressIndicator(
                  color: context.nexusTheme.accentSecondary, strokeWidth: 2),
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
                        backgroundColor: context.nexusTheme.surfacePrimary,
                        backgroundImage:
                            avatarUrl != null && avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                        child: avatarUrl == null || avatarUrl.isEmpty
                            ? Text(
                                username[0].toUpperCase(),
                                style: TextStyle(
                                    color: context.nexusTheme.textPrimary,
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
              'Chat da Sala de Projeção',
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
        final username = msg['username'] as String? ?? 'Usuário';
        final avatarUrl = msg['avatar_url'] as String?;
        return Padding(
          padding: EdgeInsets.only(bottom: r.s(6)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                CircleAvatar(
                  radius: 14,
                  backgroundColor: context.nexusTheme.surfacePrimary,
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(
                          username.isNotEmpty
                              ? username[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              color: context.nexusTheme.textPrimary,
                              fontSize: r.fs(10),
                              fontWeight: FontWeight.w700),
                        )
                      : null,
                ),
                SizedBox(width: r.s(6)),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: EdgeInsets.only(left: r.s(4), bottom: r.s(2)),
                        child: Text(
                          username,
                          style: TextStyle(
                              color: context.nexusTheme.accentSecondary,
                              fontSize: r.fs(10),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(12), vertical: r.s(8)),
                      decoration: BoxDecoration(
                        color: isMe
                            ? context.nexusTheme.accentPrimary.withValues(alpha: 0.25)
                            : context.nexusTheme.surfacePrimary,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(r.s(16)),
                          topRight: Radius.circular(r.s(16)),
                          bottomLeft: Radius.circular(isMe ? r.s(16) : r.s(4)),
                          bottomRight:
                              Radius.circular(isMe ? r.s(4) : r.s(16)),
                        ),
                      ),
                      child: Text(
                        msg['text'] as String? ?? '',
                        style: TextStyle(
                            color: context.nexusTheme.textPrimary, fontSize: r.fs(13)),
                      ),
                    ),
                  ],
                ),
              ),
              if (isMe) SizedBox(width: r.s(6)),
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
                  color: context.nexusTheme.surfacePrimary,
                  borderRadius: BorderRadius.circular(r.s(24)),
                ),
                child: TextField(
                  controller: _chatController,
                  style: TextStyle(
                      color: context.nexusTheme.textPrimary, fontSize: r.fs(14)),
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
                decoration: BoxDecoration(
                  color: context.nexusTheme.accentPrimary,
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
