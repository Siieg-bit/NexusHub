import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/screening_room_provider.dart';

// =============================================================================
// ScreeningAddVideoSheet — Bottom sheet para adicionar/trocar vídeo (estilo Rave)
// Grid de plataformas + campo de busca/URL. Disponível apenas para o host.
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
  final _searchController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedPlatform;

  static const _platforms = [
    _PlatformTile('YouTube', 'youtube.com'),
    _PlatformTile('Twitch', 'twitch.tv'),
    _PlatformTile('Vimeo', 'vimeo.com'),
    _PlatformTile('Kick', 'kick.com'),
    _PlatformTile('Dailymotion', 'dailymotion.com'),
    _PlatformTile('Drive', 'drive.google.com'),
    _PlatformTile('WEB', null),
    _PlatformTile('YouTube\nLIVE', 'youtube.com/live'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final input = _searchController.text.trim();
    if (input.isEmpty) {
      setState(() => _errorMessage = 'Cole a URL ou título do vídeo.');
      return;
    }

    String url = input;
    if (!input.startsWith('http')) {
      url =
          'https://www.youtube.com/results?search_query=${Uri.encodeComponent(input)}';
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final title = _inferTitle(url);

    await ref
        .read(screeningRoomProvider(widget.threadId).notifier)
        .updateVideo(videoUrl: url, videoTitle: title);

    if (mounted) {
      HapticFeedback.lightImpact();
      Navigator.of(context).pop();
    }
  }

  String _inferTitle(String url) {
    final u = url.toLowerCase();
    if (u.contains('youtube')) return 'YouTube';
    if (u.contains('twitch')) return 'Twitch';
    if (u.contains('vimeo')) return 'Vimeo';
    if (u.contains('kick')) return 'Kick';
    if (u.contains('dailymotion')) return 'Dailymotion';
    if (u.contains('drive.google')) return 'Google Drive';
    return 'Vídeo';
  }

  void _onPlatformTap(_PlatformTile platform) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedPlatform = platform.name;
      if (platform.domain != null) {
        _searchController.text = 'https://${platform.domain}/';
        _searchController.selection = TextSelection.fromPosition(
          TextPosition(offset: _searchController.text.length),
        );
      } else {
        _searchController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPad = mq.viewInsets.bottom + mq.padding.bottom + 16;

    return Container(
      height: mq.size.height * 0.85,
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
          const SizedBox(height: 16),

          // ── Campo de busca / URL ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  Icon(
                    Icons.search_rounded,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _submit(),
                      onChanged: (_) =>
                          setState(() => _errorMessage = null),
                      decoration: InputDecoration(
                        hintText: 'procurar um vídeo, série ou filme...',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() {
                        _searchController.clear();
                        _selectedPlatform = null;
                        _errorMessage = null;
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Erro ──────────────────────────────────────────────────────────
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
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
                final isSelected = _selectedPlatform == platform.name;
                return _PlatformCard(
                  platform: platform,
                  isSelected: isSelected,
                  onTap: () => _onPlatformTap(platform),
                );
              },
            ),
          ),

          // ── Botão Reproduzir ───────────────────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _searchController.text.isNotEmpty
                ? Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _submit,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.play_arrow_rounded, size: 22),
                        label: const Text(
                          'Reproduzir',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── _PlatformTile (modelo) ────────────────────────────────────────────────────
class _PlatformTile {
  final String name;
  final String? domain;
  const _PlatformTile(this.name, this.domain);
}

// ── _PlatformCard ─────────────────────────────────────────────────────────────
class _PlatformCard extends StatelessWidget {
  final _PlatformTile platform;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlatformCard({
    required this.platform,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.10),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Center(
          child: Text(
            platform.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.85),
              fontSize: platform.name.length > 8 ? 18 : 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
