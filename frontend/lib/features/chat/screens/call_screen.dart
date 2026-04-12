import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/call_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../../config/nexus_theme_extension.dart';
import '../../../../config/nexus_theme_extension.dart';

/// ============================================================================
/// CallScreen — UI de chamada com Agora.io RTC real.
///
/// Features:
/// - Vídeo real (câmera local + remota) via AgoraVideoView
/// - Indicadores de volume de áudio (quem está falando)
/// - Controles: mute, speaker, câmera, trocar câmera, encerrar
/// - Grid adaptativo de participantes
/// - Timer de duração da chamada
/// - Suporte a Voice Chat, Video Chat e Sala de Projeção
/// ============================================================================

class CallScreen extends ConsumerStatefulWidget {
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
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  List<Map<String, dynamic>> _participants = [];
  Set<int> _remoteUsers = {};
  Map<int, double> _audioLevels = {};
  StreamSubscription? _participantsSub;
  StreamSubscription? _remoteUsersSub;
  StreamSubscription? _audioLevelsSub;

  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isCameraOn = false;
  bool _controlsVisible = true;

  late DateTime _startTime;
  Timer? _timer;
  String _elapsed = '00:00';

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _isCameraOn = widget.session.type == CallType.video;
    _isMuted = CallService.isMuted;
    _isSpeakerOn = CallService.isSpeakerOn;

    _loadParticipants();

    // Ouvir atualizações de participantes do Supabase
    _participantsSub = CallService.participantsStream.listen((p) {
      if (mounted) setState(() => _participants = p);
    });

    // Ouvir usuários remotos do Agora
    _remoteUsersSub = CallService.remoteUsersStream.listen((users) {
      if (mounted) setState(() => _remoteUsers = users);
    });

    // Ouvir níveis de áudio do Agora
    _audioLevelsSub = CallService.audioLevelsStream.listen((levels) {
      if (mounted) setState(() => _audioLevels = levels);
    });

    // Timer de duração
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        final diff = DateTime.now().difference(_startTime);
        setState(() {
          _elapsed =
              '${diff.inMinutes.toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}';
        });
      }
    });
  }

  Future<void> _loadParticipants() async {
    final p = await CallService.getParticipants();
    if (!mounted) return;
    if (mounted) setState(() => _participants = p);
  }

  @override
  void dispose() {
    _participantsSub?.cancel();
    _remoteUsersSub?.cancel();
    _audioLevelsSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _toggleMute() async {
    await CallService.toggleMute();
    if (!mounted) return;
    setState(() => _isMuted = CallService.isMuted);
  }

  Future<void> _toggleSpeaker() async {
    await CallService.toggleSpeaker();
    if (!mounted) return;
    setState(() => _isSpeakerOn = CallService.isSpeakerOn);
  }

  Future<void> _toggleCamera() async {
    await CallService.toggleCamera();
    if (!mounted) return;
    setState(() => _isCameraOn = CallService.isCameraOn);
  }

  Future<void> _switchCamera() async {
    await CallService.switchCamera();
  }

  Future<void> _endCall() async {
    await CallService.leaveCall();
    if (!mounted) return;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final isVideo = widget.session.type == CallType.video;
    final isScreening = widget.session.type == CallType.screeningRoom;
    final title = isScreening
        ? 'Sala de Projeção'
        : isVideo
            ? 'Video Chat'
            : 'Voice Chat';
    final bgColor = context.nexusTheme.backgroundPrimary;

    return Scaffold(
      backgroundColor: bgColor,
      body: GestureDetector(
        onTap: () => setState(() => _controlsVisible = !_controlsVisible),
        child: SafeArea(
          child: Stack(
            children: [
              // ── Main Content ──
              Column(
                children: [
                  // ── Header ──
                  AnimatedOpacity(
                    opacity: _controlsVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: _buildHeader(title),
                  ),

                  // ── Video/Audio Grid ──
                  Expanded(
                    child: isVideo ? _buildVideoGrid() : _buildAudioGrid(),
                  ),

                  // ── Sala de Projeção: área de vídeo ──
                  if (isScreening) _buildScreeningArea(),

                  // ── Controls ──
                  AnimatedOpacity(
                    opacity: _controlsVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: _buildControls(isVideo),
                  ),
                ],
              ),

              // ── Local video preview (PiP) ──
              if (isVideo && _isCameraOn && _remoteUsers.isNotEmpty)
                Positioned(
                  top: 80,
                  right: 16,
                  child: GestureDetector(
                    onTap: _switchCamera,
                    child: Container(
                      width: r.s(120),
                      height: r.s(160),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(r.s(12)),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                            width: 1),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: CallService.engine != null
                          ? AgoraVideoView(
                              controller: VideoViewController(
                                rtcEngine: CallService.engine!,
                                canvas: const VideoCanvas(uid: 0),
                              ),
                            )
                          : const SizedBox(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.all(r.s(16)),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: context.nexusTheme.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          Column(
            children: [
              Text(title,
                  style: TextStyle(
                      color: context.nexusTheme.textPrimary,
                      fontSize: r.fs(18),
                      fontWeight: FontWeight.w800)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: r.s(8),
                    height: r.s(8),
                    decoration: const BoxDecoration(
                      color: context.nexusTheme.accentPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: r.s(6)),
                  Text(_elapsed,
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: r.fs(14))),
                ],
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding:
                EdgeInsets.symmetric(horizontal: r.s(10), vertical: r.s(4)),
            decoration: BoxDecoration(
              color: context.nexusTheme.accentPrimary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(r.s(20)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_rounded,
                    color: context.nexusTheme.accentPrimary, size: r.s(16)),
                SizedBox(width: r.s(4)),
                Text('${_participants.length + _remoteUsers.length}',
                    style: const TextStyle(
                        color: context.nexusTheme.accentPrimary,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Grid de vídeo real via Agora
  Widget _buildVideoGrid() {
    final s = getStrings();
    final r = context.r;
    if (CallService.engine == null) {
      return const Center(
        child: CircularProgressIndicator(color: context.nexusTheme.accentPrimary),
      );
    }

    final List<Widget> videoViews = [];

    // Se não há usuários remotos, mostrar vídeo local em tela cheia
    if (_remoteUsers.isEmpty) {
      videoViews.add(
        _isCameraOn
            ? AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: CallService.engine!,
                  canvas: const VideoCanvas(uid: 0),
                ),
              )
            : _buildAvatarPlaceholder(s.you),
      );
    } else {
      // Mostrar vídeos remotos
      for (final uid in _remoteUsers) {
        videoViews.add(
          ClipRRect(
            borderRadius: BorderRadius.circular(r.s(12)),
            child: AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: CallService.engine!,
                canvas: VideoCanvas(uid: uid),
                connection: RtcConnection(
                  channelId:
                      'nexushub_${widget.session.id.replaceAll('-', '').substring(0, 16)}',
                ),
              ),
            ),
          ),
        );
      }
    }

    return GridView.builder(
      padding: EdgeInsets.all(r.s(16)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: videoViews.length <= 1 ? 1 : 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: videoViews.length <= 1 ? 0.75 : 0.65,
      ),
      itemCount: videoViews.length,
      itemBuilder: (_, i) => videoViews[i],
    );
  }

  /// Grid de áudio com indicadores de volume
  Widget _buildAudioGrid() {
    final r = context.r;
    if (_participants.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: context.nexusTheme.accentPrimary),
            SizedBox(height: r.s(16)),
            Text('Aguardando participantes...',
                style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(r.s(16)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _participants.length <= 2 ? 1 : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: _participants.length <= 2 ? 1.5 : 1.0,
      ),
      itemCount: _participants.length,
      itemBuilder: (_, i) => _buildParticipantTile(_participants[i]),
    );
  }

  Widget _buildParticipantTile(Map<String, dynamic> participant) {
    final s = getStrings();
    final r = context.r;
    final profile = participant['profiles'] as Map<String, dynamic>?;
    final nickname = profile?['nickname'] as String? ?? s.user;
    final iconUrl = profile?['icon_url'] as String?;

    // Detectar se está falando via audio levels do Agora
    // uid 0 = local user
    final isSpeaking = _audioLevels.values.any((v) => v > 30);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(16)),
        border: isSpeaking
            ? Border.all(color: context.nexusTheme.accentPrimary, width: 2.5)
            : Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
        boxShadow: isSpeaking
            ? [
                BoxShadow(
                  color: context.nexusTheme.accentPrimary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar com indicador de áudio
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: context.nexusTheme.accentPrimary.withValues(alpha: 0.3),
                backgroundImage: iconUrl != null
                    ? CachedNetworkImageProvider(iconUrl)
                    : null,
                child: iconUrl == null
                    ? Text(nickname[0].toUpperCase(),
                        style: TextStyle(
                            color: context.nexusTheme.textPrimary,
                            fontSize: r.fs(28),
                            fontWeight: FontWeight.w800))
                    : null,
              ),
              if (isSpeaking)
                Container(
                  width: r.s(20),
                  height: r.s(20),
                  decoration: BoxDecoration(
                    color: context.nexusTheme.accentPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.surfaceColor, width: 2),
                  ),
                  child: Icon(Icons.mic_rounded,
                      color: Colors.white, size: r.s(12)),
                ),
            ],
          ),
          SizedBox(height: r.s(12)),
          Text(nickname,
              style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontSize: r.fs(14),
                  fontWeight: FontWeight.w700)),
          SizedBox(height: r.s(4)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: r.s(8),
                height: r.s(8),
                decoration: const BoxDecoration(
                  color: context.nexusTheme.accentPrimary,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: r.s(4)),
              Text(s.connected,
                  style:
                      TextStyle(color: Colors.grey[500], fontSize: r.fs(11))),
            ],
          ),
          // Audio level bar
          if (isSpeaking)
            Padding(
              padding: EdgeInsets.only(top: r.s(8)),
              child: _AudioLevelBar(
                  level: _audioLevels.values.isNotEmpty
                      ? _audioLevels.values.first / 255
                      : 0),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String name) {
    final r = context.r;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: context.nexusTheme.accentPrimary.withValues(alpha: 0.3),
            child: Text(name[0].toUpperCase(),
                style: TextStyle(
                    color: context.nexusTheme.textPrimary,
                    fontSize: r.fs(36),
                    fontWeight: FontWeight.w800)),
          ),
          SizedBox(height: r.s(16)),
          Text(name,
              style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontSize: r.fs(18),
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildScreeningArea() {
    final s = getStrings();
    final r = context.r;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.s(16)),
      height: r.s(200),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(16)),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
      ),
      child: _remoteUsers.isNotEmpty && CallService.engine != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(r.s(16)),
              child: AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: CallService.engine!,
                  canvas: VideoCanvas(uid: _remoteUsers.first),
                  connection: RtcConnection(
                    channelId:
                        'nexushub_${widget.session.id.replaceAll('-', '').substring(0, 16)}',
                  ),
                ),
              ),
            )
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.live_tv_rounded,
                      color: Colors.white.withValues(alpha: 0.24),
                      size: r.s(48)),
                  SizedBox(height: r.s(8)),
                  Text(s.sharedScreenWillAppearHere,
                      style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            ),
    );
  }

  Widget _buildControls(bool isVideo) {
    final s = getStrings();
    final r = context.r;
    return Padding(
      padding: EdgeInsets.all(r.s(24)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: _isMuted ? s.muted : s.mic,
            isActive: !_isMuted,
            onTap: _toggleMute,
          ),
          _ControlButton(
            icon: _isSpeakerOn
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            label: s.speaker,
            isActive: _isSpeakerOn,
            onTap: _toggleSpeaker,
          ),
          if (isVideo) ...[
            _ControlButton(
              icon: _isCameraOn
                  ? Icons.videocam_rounded
                  : Icons.videocam_off_rounded,
              label: s.camera,
              isActive: _isCameraOn,
              onTap: _toggleCamera,
            ),
            _ControlButton(
              icon: Icons.cameraswitch_rounded,
              label: s.switchCamera,
              isActive: true,
              onTap: _switchCamera,
            ),
          ],
          _ControlButton(
            icon: Icons.call_end_rounded,
            label: s.end,
            isActive: false,
            isEnd: true,
            onTap: _endCall,
          ),
        ],
      ),
    );
  }
}

/// Barra animada de nível de áudio
class _AudioLevelBar extends ConsumerWidget {
  final double level; // 0.0 a 1.0

  const _AudioLevelBar({required this.level});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final threshold = (i + 1) / 5;
        final isActive = level >= threshold;
        return Container(
          width: r.s(4),
          height: 8 + (i * 3).toDouble(),
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: isActive
                ? context.nexusTheme.accentPrimary
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

class _ControlButton extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: r.s(56),
            height: r.s(56),
            decoration: BoxDecoration(
              color: isEnd
                  ? context.nexusTheme.error
                  : isActive
                      ? context.nexusTheme.accentPrimary.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
              border: Border.all(
                color: isEnd
                    ? Colors.transparent
                    : isActive
                        ? context.nexusTheme.accentPrimary.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
            child: Icon(icon,
                color: isEnd
                    ? Colors.white
                    : isActive
                        ? context.nexusTheme.accentPrimary
                        : Colors.grey[500],
                size: r.s(24)),
          ),
          SizedBox(height: r.s(6)),
          Text(label,
              style: TextStyle(
                  color: isEnd ? context.nexusTheme.error : Colors.grey[500],
                  fontSize: r.fs(11),
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
