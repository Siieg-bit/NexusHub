import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/call_service.dart';

/// ============================================================================
/// CallScreen — UI de chamada de voz/vídeo/screening room.
///
/// Mostra participantes em tempo real via Supabase Realtime,
/// timer da chamada, controles de mute/speaker/câmera, e botão de encerrar.
///
/// Para WebRTC real, integrar flutter_webrtc ou agora_rtc_engine aqui.
/// ============================================================================

class CallScreen extends StatefulWidget {
  final CallSession session;

  const CallScreen({super.key, required this.session});

  static Future<void> show(BuildContext context, CallSession session) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CallScreen(session: session),
      ),
    );
  }

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  List<Map<String, dynamic>> _participants = [];
  StreamSubscription? _sub;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isCameraOn = false;
  late DateTime _startTime;
  Timer? _timer;
  String _elapsed = '00:00';

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _loadParticipants();
    _sub = CallService.participantsStream.listen((p) {
      if (mounted) setState(() => _participants = p);
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        final diff = DateTime.now().difference(_startTime);
        setState(() {
          _elapsed =
              '${diff.inMinutes.toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}';
        });
      }
    });
    _isCameraOn = widget.session.type == CallType.video;
  }

  Future<void> _loadParticipants() async {
    final p = await CallService.getParticipants();
    if (mounted) setState(() => _participants = p);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _endCall() async {
    await CallService.leaveCall();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.session.type == CallType.video;
    final isScreening = widget.session.type == CallType.screeningRoom;
    final title = isScreening
        ? 'Screening Room'
        : isVideo
            ? 'Video Chat'
            : 'Voice Chat';
    final bgColor = isScreening
        ? const Color(0xFF1A1A2E)
        : isVideo
            ? const Color(0xFF0D1117)
            : const Color(0xFF16213E);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Column(
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      Text(_elapsed,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 14)),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_rounded,
                            color: AppTheme.successColor, size: 16),
                        const SizedBox(width: 4),
                        Text('${_participants.length}',
                            style: const TextStyle(
                                color: AppTheme.successColor,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Participants Grid ──
            Expanded(
              child: _participants.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white38),
                          SizedBox(height: 16),
                          Text('Aguardando participantes...',
                              style: TextStyle(color: Colors.white60)),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _participants.length <= 2 ? 1 : 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio:
                            _participants.length <= 2 ? 1.5 : 1.0,
                      ),
                      itemCount: _participants.length,
                      itemBuilder: (_, i) =>
                          _buildParticipantTile(_participants[i]),
                    ),
            ),

            // ── Screening Room: Video area ──
            if (isScreening)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.live_tv_rounded,
                          color: Colors.white24, size: 48),
                      SizedBox(height: 8),
                      Text('Tela compartilhada aparecerá aqui',
                          style: TextStyle(color: Colors.white38)),
                    ],
                  ),
                ),
              ),

            // ── Controls ──
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ControlButton(
                    icon: _isMuted
                        ? Icons.mic_off_rounded
                        : Icons.mic_rounded,
                    label: _isMuted ? 'Mudo' : 'Mic',
                    isActive: !_isMuted,
                    onTap: () => setState(() => _isMuted = !_isMuted),
                  ),
                  _ControlButton(
                    icon: _isSpeakerOn
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    label: 'Speaker',
                    isActive: _isSpeakerOn,
                    onTap: () =>
                        setState(() => _isSpeakerOn = !_isSpeakerOn),
                  ),
                  if (isVideo)
                    _ControlButton(
                      icon: _isCameraOn
                          ? Icons.videocam_rounded
                          : Icons.videocam_off_rounded,
                      label: 'Câmera',
                      isActive: _isCameraOn,
                      onTap: () =>
                          setState(() => _isCameraOn = !_isCameraOn),
                    ),
                  _ControlButton(
                    icon: Icons.call_end_rounded,
                    label: 'Encerrar',
                    isActive: false,
                    isEnd: true,
                    onTap: _endCall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantTile(Map<String, dynamic> participant) {
    final profile = participant['profiles'] as Map<String, dynamic>?;
    final nickname = profile?['nickname'] as String? ?? 'Usuário';
    final iconUrl = profile?['icon_url'] as String?;
    final isSpeaking = false; // TODO: Audio level detection

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: isSpeaking
            ? Border.all(color: AppTheme.successColor, width: 2)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.3),
            backgroundImage: iconUrl != null
                ? CachedNetworkImageProvider(iconUrl)
                : null,
            child: iconUrl == null
                ? Text(nickname[0].toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold))
                : null,
          ),
          const SizedBox(height: 12),
          Text(nickname,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.successColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              const Text('Conectado',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isEnd;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    this.isEnd = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isEnd
                  ? AppTheme.errorColor
                  : isActive
                      ? Colors.white.withOpacity(0.15)
                      : Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                color: isEnd
                    ? Colors.white
                    : isActive
                        ? Colors.white
                        : Colors.white38,
                size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: isEnd ? AppTheme.errorColor : Colors.white60,
                  fontSize: 11)),
        ],
      ),
    );
  }
}
