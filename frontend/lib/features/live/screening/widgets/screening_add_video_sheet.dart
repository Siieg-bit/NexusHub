import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/screening_room_provider.dart';
import 'screening_browser_sheet.dart';
import 'screening_local_video_sheet.dart';

// =============================================================================
// ScreeningAddVideoSheet — Bottom sheet para adicionar/trocar vídeo (estilo Rave)
// Grid de plataformas. Ao clicar, abre ScreeningBrowserSheet para navegar.
// "Galeria" abre o ScreeningLocalVideoSheet para upload de vídeo local.
// Disponível apenas para o host.
// =============================================================================
class ScreeningAddVideoSheet extends ConsumerStatefulWidget {
  final String sessionId;
  final String threadId;

  const ScreeningAddVideoSheet({
    super.key,
    required this.sessionId,
    required this.threadId,
  });

  @override
  ConsumerState<ScreeningAddVideoSheet> createState() =>
      _ScreeningAddVideoSheetState();
}

class _ScreeningAddVideoSheetState
    extends ConsumerState<ScreeningAddVideoSheet> {
  // ── Plataformas do grid ───────────────────────────────────────────────────
  static const _platforms = [
    // ── Galeria local ─────────────────────────────────────────────────────
    _PlatformTile(
      id: 'local',
      name: 'Galeria',
      icon: Icons.video_library_rounded,
      color: Color(0xFF6C5CE7),
    ),
    // ── Plataformas online ─────────────────────────────────────────────────
    _PlatformTile(
      id: 'youtube',
      name: 'YouTube',
      icon: Icons.play_circle_outline_rounded,
      color: Color(0xFFFF0000),
    ),
    _PlatformTile(
      id: 'twitch',
      name: 'Twitch',
      icon: Icons.live_tv_rounded,
      color: Color(0xFF9146FF),
    ),
    _PlatformTile(
      id: 'kick',
      name: 'Kick',
      icon: Icons.sports_esports_rounded,
      color: Color(0xFF53FC18),
    ),
    _PlatformTile(
      id: 'vimeo',
      name: 'Vimeo',
      icon: Icons.videocam_rounded,
      color: Color(0xFF1AB7EA),
    ),
    _PlatformTile(
      id: 'dailymotion',
      name: 'Dailymotion',
      icon: Icons.movie_rounded,
      color: Color(0xFF0066DC),
    ),
    _PlatformTile(
      id: 'drive',
      name: 'Drive',
      icon: Icons.folder_rounded,
      color: Color(0xFF4285F4),
    ),
    _PlatformTile(
      id: 'web',
      name: 'WEB',
      icon: Icons.language_rounded,
      color: Color(0xFF888888),
    ),
    _PlatformTile(
      id: 'youtube_live',
      name: 'YouTube\nLIVE',
      icon: Icons.stream_rounded,
      color: Color(0xFFFF0000),
    ),
    // ── AVOD gratuito ──────────────────────────────────────────────────────
    _PlatformTile(
      id: 'tubi',
      name: 'Tubi',
      icon: Icons.tv_rounded,
      color: Color(0xFFFA4B00),
    ),
    _PlatformTile(
      id: 'pluto',
      name: 'Pluto TV',
      icon: Icons.satellite_alt_rounded,
      color: Color(0xFF00A0E3),
    ),
    // ── Assinatura (login) ─────────────────────────────────────────────────
    _PlatformTile(
      id: 'netflix',
      name: 'Netflix',
      icon: Icons.movie_filter_rounded,
      color: Color(0xFFE50914),
    ),
    _PlatformTile(
      id: 'disney',
      name: 'Disney+',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFF0063E5),
    ),
    _PlatformTile(
      id: 'amazon',
      name: 'Prime\nVideo',
      icon: Icons.local_play_rounded,
      color: Color(0xFF00A8E1),
    ),
    _PlatformTile(
      id: 'hbo',
      name: 'Max',
      icon: Icons.hd_rounded,
      color: Color(0xFF002BE7),
    ),
    _PlatformTile(
      id: 'crunchyroll',
      name: 'Crunchyroll',
      icon: Icons.animation_rounded,
      color: Color(0xFFF47521),
    ),
  ];

  // ── Abrir galeria local ───────────────────────────────────────────────────

  Future<void> _openLocalGallery() async {
    HapticFeedback.selectionClick();
    if (!mounted) return;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => ScreeningLocalVideoSheet(
        sessionId: widget.sessionId,
        threadId: widget.threadId,
      ),
    );

    // Se o upload foi bem-sucedido, fechar o ScreeningAddVideoSheet também
    if (result != null && mounted) {
      Navigator.of(context).pop();
    }
  }

  // ── Abrir o browser sheet para a plataforma selecionada ───────────────────

  Future<void> _openBrowser(_PlatformTile platform) async {
    HapticFeedback.selectionClick();

    if (!mounted) return;

    // Capturar URL atual antes de abrir o browser (para detectar mudança)
    final urlBefore = ref
        .read(screeningRoomProvider(widget.threadId))
        .currentVideoUrl;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => ScreeningBrowserSheet(
        platformId: platform.id,
        sessionId: widget.sessionId,
        threadId: widget.threadId,
      ),
    );

    // Após o browser sheet fechar, verificar se um NOVO vídeo foi selecionado
    // (URL mudou em relação ao que era antes de abrir o browser)
    if (mounted) {
      final urlAfter = ref
          .read(screeningRoomProvider(widget.threadId))
          .currentVideoUrl;
      if (urlAfter != null &&
          urlAfter.isNotEmpty &&
          urlAfter != urlBefore) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPad = mq.viewInsets.bottom + mq.padding.bottom + 16;

    return Container(
      height: mq.size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Handle ────────────────────────────────────────────────────────
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Título ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Escolha uma plataforma',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Navegue e selecione o vídeo diretamente no site',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Grid de plataformas ───────────────────────────────────────────
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _platforms.length,
              itemBuilder: (context, index) {
                final platform = _platforms[index];
                return _PlatformCard(
                  platform: platform,
                  onTap: platform.id == 'local'
                      ? _openLocalGallery
                      : () => _openBrowser(platform),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── _PlatformTile (modelo) ────────────────────────────────────────────────────
class _PlatformTile {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const _PlatformTile({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

// ── _PlatformCard ─────────────────────────────────────────────────────────────
class _PlatformCard extends StatelessWidget {
  final _PlatformTile platform;
  final VoidCallback onTap;

  const _PlatformCard({
    required this.platform,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              platform.icon,
              color: platform.color.withValues(alpha: 0.85),
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              platform.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: platform.name.length > 8 ? 16 : 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
