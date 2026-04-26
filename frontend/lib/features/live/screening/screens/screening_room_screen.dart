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
import '../widgets/screening_player_widget.dart';
import '../widgets/screening_controls_overlay.dart';
import '../widgets/screening_chat_overlay.dart';
import '../widgets/screening_reaction_bar.dart';
import '../../../../core/widgets/emoji_rain_overlay.dart';

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

  const ScreeningRoomScreen({
    super.key,
    required this.threadId,
    this.callSessionId,
  });

  @override
  ConsumerState<ScreeningRoomScreen> createState() =>
      _ScreeningRoomScreenState();
}

class _ScreeningRoomScreenState extends ConsumerState<ScreeningRoomScreen>
    with WidgetsBindingObserver {
  // ── Controles de UI ─────────────────────────────────────────────────────────
  bool _showControls = true;
  Timer? _controlsHideTimer;

  // ── Emoji rain ──────────────────────────────────────────────────────────────
  // EmojiRainOverlay usa um GlobalKey interno estático — disparado via
  // EmojiRainOverlay.trigger(context, type: type)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Forçar modo landscape-friendly (sem barras de status)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Entrar na sala após o primeiro frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinRoom();
    });

    // Mostrar controles inicialmente e esconder após 4s
    _scheduleControlsHide(delay: 4);
  }

  @override
  void dispose() {
    _controlsHideTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);

    // Restaurar UI do sistema
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

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
        );

    final roomState = ref.read(screeningRoomProvider(widget.threadId));
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

  void _scheduleControlsHide({int delay = 3}) {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(Duration(seconds: delay), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  // ── Minimizar (PiP) ─────────────────────────────────────────────────────────

  void _minimize() {
    final roomState = ref.read(screeningRoomProvider(widget.threadId));
    if (roomState.sessionId == null) {
      Navigator.of(context).pop();
      return;
    }

    ref.read(miniRoomProvider.notifier).show(
      roomId: roomState.sessionId!,
      title: roomState.currentVideoTitle ?? 'Sala de Projeção',
      type: MiniRoomType.screening,
      onReturn: () {
        ref.read(miniRoomProvider.notifier).hide();
        // Navegar de volta para a sala
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ScreeningRoomScreen(
            threadId: widget.threadId,
            callSessionId: roomState.sessionId,
          ),
        ));
      },
      onEnd: () {
        ref.read(miniRoomProvider.notifier).hide();
        ref
            .read(screeningRoomProvider(widget.threadId).notifier)
            .leaveRoom();
      },
      onToggleMute: () {
        if (roomState.sessionId != null) {
          ref
              .read(screeningVoiceProvider(roomState.sessionId!).notifier)
              .toggleMute();
        }
      },
    );

    Navigator.of(context).pop();
  }

  // ── Sair da sala ────────────────────────────────────────────────────────────

  Future<void> _leaveRoom() async {
    final roomState = ref.read(screeningRoomProvider(widget.threadId));

    if (roomState.isHost) {
      final confirmed = await _showLeaveConfirmDialog();
      if (!confirmed) return;
    }

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
    ref.listen(screeningRoomProvider(widget.threadId), (prev, next) {
      if (next.status == ScreeningRoomStatus.closed && mounted) {
        _showRoomClosedDialog();
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _leaveRoom();
      },
      child: EmojiRainOverlay.withKey(
        child: Scaffold(
          backgroundColor: Colors.black,
          body: _buildBody(context, roomState),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ScreeningRoomState roomState) {
    // ── Estado de carregamento ──────────────────────────────────────────────
    if (roomState.status == ScreeningRoomStatus.loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white54),
            SizedBox(height: 16),
            Text(
              'Entrando na sala...',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

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

    // ── Stack imersivo ──────────────────────────────────────────────────────
    return GestureDetector(
      onTap: _onTapScreen,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camada 0: Player ──────────────────────────────────────────────
          ScreeningPlayerWidget(
            sessionId: sessionId,
            threadId: widget.threadId,
          ),
          // ── Camada 1: SyncStatusBadge (indicador de sincronização) ─────────────
          // Exibe badge de "Sincronizando..." / "Ajustando..." quando o
          // SyncStatus não está em stable/idle. IgnorePointer para não
          // bloquear gestos na tela.
          if (sessionId.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 56,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: _SyncStatusBadge(sessionId: sessionId),
              ),
            ),

          // ── Camada 2: Gradientes de contraste ─────────────────────────────
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.65),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.80),
                    ],
                    stops: const [0.0, 0.18, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // ── Camada 3: Chat overlay (metade inferior) ──────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.of(context).size.height * 0.48,
            child: SafeArea(
              top: false,
              child: ScreeningChatOverlay(
                sessionId: sessionId,
                threadId: widget.threadId,
              ),
            ),
             // ── Camada 4a: Barra de reações (acima do chat) ───────────────────────────
          if (sessionId.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).size.height * 0.48 + 8,
              child: SafeArea(
                top: false,
                child: ScreeningReactionBar(sessionId: sessionId),
              ),
            ),
          // ── Camada 4b: Controles flutuantes ────────────────────────────────────────────────
          Positioned.fill(
            child: ScreeningControlsOverlay(
              sessionId: sessionId,
              threadId: widget.threadId,
              visible: _showControls,
              onMinimize: _minimize,
            ),
          ),
        ],
      ),
    );
  }

  // ── Diálogo de sala encerrada ───────────────────────────────────────────────

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
            color: Colors.black.withOpacity(0.72),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.6), width: 1),
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
