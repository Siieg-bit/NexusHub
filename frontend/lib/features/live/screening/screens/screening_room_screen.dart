import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/widgets/mini_room_overlay.dart';
import '../models/screening_room_state.dart';
import '../providers/screening_room_provider.dart';
import '../providers/screening_sync_provider.dart';
import '../providers/screening_voice_provider.dart';
import '../../../../core/widgets/emoji_rain_overlay.dart';
import '../../../../router/app_router.dart';
import '../widgets/screening_landscape_layout.dart';

// =============================================================================
// ScreeningRoomScreen — Sala de Projeção (Fase 2 — Sync + Reações + Robustez)
//
// Layout em Stack imersivo de 4 camadas:
//   Camada 0: Player WebView (ocupa toda a tela)
//   Camada 1: EmojiRain (reações flutuantes, IgnorePointer)
//   Camada 2: Gradientes de contraste (IgnorePointer)
//   Camada 3: Chat overlay transparente (metade inferior)
//   Camada 4: Controles flutuantes com auto-hide (AnimatedOpacity)
//
// Parâmetros:
//   [threadId] — ID do thread da comunidade (obrigatório)
//   [callSessionId] — ID de sessão existente para entrar como participante
//                     (null = criar nova sessão como host)
// =============================================================================

class ScreeningRoomScreen extends ConsumerStatefulWidget {
  final String threadId;
  final String? callSessionId;
  /// URL do vídeo inicial (passado ao criar a sala com URL já definida)
  final String? initialVideoUrl;
  /// Título do vídeo inicial (para exibir na animação de entrada)
  final String? initialVideoTitle;
  /// Thumbnail do vídeo inicial (para o gradiente ambiente antes do WebView carregar)
  final String? initialVideoThumbnail;

  const ScreeningRoomScreen({
    super.key,
    required this.threadId,
    this.callSessionId,
    this.initialVideoUrl,
    this.initialVideoTitle,
    this.initialVideoThumbnail,
  });

  @override
  ConsumerState<ScreeningRoomScreen> createState() =>
      _ScreeningRoomScreenState();
}

class _ScreeningRoomScreenState extends ConsumerState<ScreeningRoomScreen>
    with WidgetsBindingObserver {
  // ── Controles de UI ────────────────────────────────────────────────────────────────
  bool _showControls = true;
  Timer? _controlsHideTimer;

  // ── Modo imersivo (fullscreen apenas do player) ──────────────────────────────────
  bool _isImmersive = false;

  // ── Animação de entrada ──────────────────────────────────────────────────────────
  bool _entryAnimationDone = false;
  bool _entryAnimationExiting = false;

  // ── Emoji rain ────────────────────────────────────────────────────────────────
  // BUGFIX: usar GlobalKey local em vez da key estática global para evitar
  // conflito quando múltiplas telas com EmojiRainOverlay estão na pilha.
  final GlobalKey<EmojiRainOverlayState> _emojiRainKey = GlobalKey<EmojiRainOverlayState>();

  // ── Flag de saída ativa ─────────────────────────────────────────────────────
  // Impede que o _showRoomClosedDialog (destinado a participantes que recebem
  // o evento room_closed via Realtime) seja exibido quando o HOST está
  // encerrando a sala ativamente via _leaveRoom(). Sem esse flag, o dialog
  // aparece e bloqueia o Navigator.pop() do _leaveRoom(), fazendo a tela
  // ficar presa.
  bool _isLeavingRoom = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);


    // Entrar na sala após o primeiro frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinRoom();
    });

    // Timeout de segurança: se a animação de entrada não for descartada em 15s,
    // forçar a saída para evitar loop infinito de carregamento.
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && !_entryAnimationDone && !_entryAnimationExiting) {
        debugPrint('[ScreeningRoomScreen] Timeout da animação de entrada — forçando saída.');
        setState(() => _entryAnimationExiting = true);
      }
    });

    // Se vier com vídeo inicial, definir no player após o join

    // Mostrar controles inicialmente e esconder após 4s
    _scheduleControlsHide(delay: 4);
  }

  @override
  void dispose() {
    _controlsHideTimer?.cancel();
    _emojiRainKey.currentState?.clear();
    WidgetsBinding.instance.removeObserver(this);

    // Restaurar UI do sistema (mostrar status bar e nav bar novamente)
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Pausar o vídeo quando o app vai para background (apenas host)
      final roomState = ref.read(screeningRoomProvider(widget.threadId));
      if (roomState.isHost && roomState.sessionId != null) {
        // O provider de voice já trata o ciclo de vida
      }
    }
  }

  // ── Entrar na sala ──────────────────────────────────────────────────────────

  Future<void> _joinRoom() async {
    await ref.read(screeningRoomProvider(widget.threadId).notifier).joinRoom(
          existingSessionId: widget.callSessionId,
          initialVideoUrl: widget.initialVideoUrl,
          initialVideoTitle: widget.initialVideoTitle,
          initialVideoThumbnail: widget.initialVideoThumbnail,
        );

    final roomState = ref.read(screeningRoomProvider(widget.threadId));
    // Disparar o fade-out da animação de entrada assim que a sala estiver ativa
    if (mounted && !_entryAnimationExiting) {
      setState(() => _entryAnimationExiting = true);
    }
    if (roomState.status == ScreeningRoomStatus.active &&
        roomState.sessionId != null) {
      // Iniciar voice chat
      await ref
          .read(screeningVoiceProvider(roomState.sessionId!).notifier)
          .joinChannel();

      // Sincronização inicial (apenas participantes, não o host)
      if (!roomState.isHost) {
        await _syncOnJoin(roomState.sessionId!);
      }
    }
  }

  Future<void> _syncOnJoin(String sessionId) async {
    try {
      final result = await SupabaseService.client
          .rpc('get_screening_session_state', params: {
        'p_session_id': sessionId,
      }).select();

      if (result != null && (result as List).isNotEmpty) {
        final row = (result as List).first as Map<String, dynamic>;
        final posMs = (row['sync_position'] as num?)?.toInt() ?? 0;
        final isPlaying = row['sync_is_playing'] as bool? ?? false;
        final syncUpdatedAt = row['sync_updated_at'] != null
            ? DateTime.parse(row['sync_updated_at'] as String)
            : DateTime.now();

        await ref
            .read(screeningSyncProvider(sessionId).notifier)
            .syncOnJoin(
              positionMs: posMs,
              isPlaying: isPlaying,
              syncUpdatedAt: syncUpdatedAt,
            );
      }
    } catch (e) {
      debugPrint('[ScreeningRoomScreen] syncOnJoin error: $e');
    }
  }

  // ── Controles auto-hide ─────────────────────────────────────────────────────

  void _onTapScreen() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _scheduleControlsHide();
    } else {
      _controlsHideTimer?.cancel();
    }
  }

  // ── Fullscreen do player ───────────────────────────────────────────────────────

  void _toggleImmersive() {
    final entering = !_isImmersive;
    setState(() => _isImmersive = entering);
    if (entering) {
      // Entrar em fullscreen: landscape + ocultar system UI
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      // Sair do fullscreen: restaurar portrait + system UI
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
  }

  void _scheduleControlsHide({int delay = 3}) {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(Duration(seconds: delay), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  // ── Minimizar (PiP) ─────────────────────────────────────────────────────────

  /// Exibe um dialog perguntando se o usuário quer minimizar (PiP) ou encerrar
  /// a sala. Isso substitui o comportamento anterior de minimizar direto ao
  /// clicar no X, e também corrige o crash "Cannot use ref after widget was
  /// disposed" capturando todos os valores necessários antes do Navigator.pop.
  Future<void> _minimize() async {
    final roomState = ref.read(screeningRoomProvider(widget.threadId));
    if (roomState.sessionId == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // Mostrar dialog de escolha: Minimizar ou Encerrar
    final choice = await _showMinimizeOrEndDialog(roomState.isHost);
    if (choice == null || !mounted) return; // Cancelou

    if (choice == _MinimizeChoice.end) {
      // Encerrar sala — skipConfirm:true pois o usuário já confirmou
      // a intenção ao escolher 'Encerrar sala' no dialog anterior.
      await _leaveRoom(skipConfirm: true);
      return;
    }

    // ── Minimizar (PiP) ──────────────────────────────────────────────────────
    // Capturar todos os valores ANTES do Navigator.pop para evitar o erro
    // "Cannot use ref after widget was disposed" que ocorria quando o
    // MiniRoomPip chamava os callbacks depois que este widget já foi descartado.
    final sessionId = roomState.sessionId!;
    final videoTitle = roomState.currentVideoTitle ?? 'Sala de Projeção';
    final videoThumbnail = roomState.currentVideoThumbnail;
    final videoUrl = roomState.currentVideoUrl;
    final threadId = widget.threadId;
    final miniNotifier = ref.read(miniRoomProvider.notifier);
    final roomNotifier = ref.read(screeningRoomProvider(threadId).notifier);
    final voiceNotifier = ref.read(screeningVoiceProvider(sessionId).notifier);
    final router = ref.read(appRouterProvider);

    miniNotifier.show(
      roomId: sessionId,
      title: videoTitle,
      type: MiniRoomType.screening,
      thumbnailUrl: videoThumbnail,
      videoUrl: videoUrl,
      // O PiP fica acima do Router no builder do MaterialApp; por isso o context
      // dele não é descendente de Navigator. Usamos o GoRouter capturado antes
      // de descartar esta tela, mantendo a navegação declarativa e segura.
      onReturnWithContext: (_) {
        miniNotifier.hide();
        router.push(
          Uri(
            path: '/screening-room/$threadId',
            queryParameters: {'sessionId': sessionId},
          ).toString(),
        );
      },
      onEnd: () {
        miniNotifier.hide();
        voiceNotifier.leaveChannel();
        roomNotifier.leaveRoom();
      },
      onToggleMute: () {
        voiceNotifier.toggleMute();
      },
    );

    if (mounted) Navigator.of(context).pop();
  }

  Future<_MinimizeChoice?> _showMinimizeOrEndDialog(bool isHost) async {
    return showDialog<_MinimizeChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'O que deseja fazer?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          isHost
              ? 'Você pode minimizar a sala (continuar em segundo plano) ou encerrá-la para todos.'
              : 'Você pode minimizar a sala (continuar em segundo plano) ou sair dela.',
          style: const TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(_MinimizeChoice.minimize),
            child: const Text(
              'Minimizar',
              style: TextStyle(color: Colors.white),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(_MinimizeChoice.end),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              isHost ? 'Encerrar sala' : 'Sair',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sair da sala ────────────────────────────────────────────────────────────

  Future<void> _leaveRoom({bool skipConfirm = false}) async {
    final roomState = ref.read(screeningRoomProvider(widget.threadId));

    // Mostrar dialog de confirmação apenas quando chamado diretamente (ex: botão
    // de back do sistema). Quando chamado via _minimize() com choice == end,
    // o usuário já confirmou a intenção no dialog anterior — pular confirmação.
    if (roomState.isHost && !skipConfirm) {
      final confirmed = await _showLeaveConfirmDialog();
      if (!confirmed) return;
    }

    // Sinalizar que estamos encerrando ativamente para que o ref.listen
    // não exiba o _showRoomClosedDialog (destinado a participantes externos).
    _isLeavingRoom = true;

    if (roomState.sessionId != null) {
      await ref
          .read(screeningVoiceProvider(roomState.sessionId!).notifier)
          .leaveChannel();
    }

    await ref
        .read(screeningRoomProvider(widget.threadId).notifier)
        .leaveRoom();

    if (mounted) Navigator.of(context).pop();
  }

  Future<bool> _showLeaveConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Encerrar sala?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: const Text(
              'Como você é o host, encerrar a sala desconectará todos os participantes.',
              style: TextStyle(color: Colors.white60),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Encerrar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(screeningRoomProvider(widget.threadId));

    // Ouvir mudanças de status da sala
    // _isLeavingRoom evita que o dialog apareça quando o HOST encerra
    // ativamente (o _leaveRoom já chama Navigator.pop diretamente).
    // O dialog só é exibido para participantes que recebem room_closed via Realtime.
    ref.listen(screeningRoomProvider(widget.threadId), (prev, next) {
      if (next.status == ScreeningRoomStatus.closed && mounted && !_isLeavingRoom) {
        _showRoomClosedDialog();
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _leaveRoom();
      },
      child: EmojiRainOverlay(
        key: _emojiRainKey,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: _buildBody(context, roomState),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ScreeningRoomState roomState) {
    // ── Estado de carregamento ──────────────────────────────────────────────
    // Não retornamos um widget genérico durante o loading: o ScreeningAdaptiveLayout
    // já exibe o ScreeningEntryAnimation ("Preparando a experiência") como overlay
    // enquanto entryAnimationDone == false. Isso evita que o widget seja desmontado
    // e remontado entre os estados loading → active, o que impedia o didUpdateWidget
    // de disparar o fade-out corretamente.

    // ── Estado de erro ──────────────────────────────────────────────────────
    if (roomState.status == ScreeningRoomStatus.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              roomState.errorMessage ?? 'Erro ao entrar na sala.',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: const Text('Voltar'),
            ),
          ],
        ),
      );
    }

    final sessionId = roomState.sessionId ?? '';

    // ── Layout adaptativo (portrait/landscape) ────────────────────────────
    return ScreeningAdaptiveLayout(
      sessionId: sessionId,
      threadId: widget.threadId,
      showControls: _showControls,
      entryAnimationDone: _entryAnimationDone,
      onTap: _onTapScreen,
      onMinimize: _minimize,
      entryAnimationExiting: _entryAnimationExiting,
      onEntryAnimationComplete: () {
        if (mounted) setState(() => _entryAnimationDone = true);
      },
      emojiRainKey: _emojiRainKey,
      isImmersive: _isImmersive,
      onToggleFullscreen: _toggleImmersive,
    );
  }

  void _showRoomClosedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Sessão encerrada',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'O host encerrou a Sala de Projeção.',
          style: TextStyle(color: Colors.white60),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'OK',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _SyncStatusBadge — Indicador visual de sincronização (Fase 2)
//
// Exibe um badge discreto no topo da tela quando o SyncStatus não está em
// stable/idle. Desaparece automaticamente quando a sincronização é concluída.
// =============================================================================

class _SyncStatusBadge extends ConsumerWidget {
  final String sessionId;
  const _SyncStatusBadge({required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(screeningSyncProvider(sessionId));

    final (label, color) = switch (syncState.status) {
      SyncStatus.syncing      => ('Sincronizando...', const Color(0xFFFFB300)),
      SyncStatus.adjusting    => ('Ajustando...', const Color(0xFF4FC3F7)),
      SyncStatus.reconnecting => ('Reconectando...', const Color(0xFFEF5350)),
      _                       => ('', Colors.transparent),
    };

    if (label.isEmpty) return const SizedBox.shrink();

    return Center(
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Enum interno para o dialog de minimizar/encerrar ─────────────────────────
enum _MinimizeChoice { minimize, end }
