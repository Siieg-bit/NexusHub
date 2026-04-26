import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/screening_room_provider.dart';

// =============================================================================
// ScreeningAddVideoSheet — Bottom sheet para adicionar/trocar vídeo
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
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  // Plataformas suportadas para exibição visual
  static const _platforms = [
    _PlatformInfo('YouTube', Icons.play_circle_outline, 'youtube.com'),
    _PlatformInfo('Twitch', Icons.live_tv_rounded, 'twitch.tv'),
    _PlatformInfo('Vimeo', Icons.videocam_outlined, 'vimeo.com'),
    _PlatformInfo('Kick', Icons.sports_esports_outlined, 'kick.com'),
    _PlatformInfo('Dailymotion', Icons.movie_outlined, 'dailymotion.com'),
  ];

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _errorMessage = 'Cole a URL do vídeo.');
      return;
    }
    if (!url.startsWith('http')) {
      setState(() => _errorMessage = 'URL inválida. Use http:// ou https://');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final title = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : _inferTitle(url);

    await ref
        .read(screeningRoomProvider(widget.threadId).notifier)
        .updateVideo(videoUrl: url, videoTitle: title);

    if (mounted) Navigator.of(context).pop();
  }

  String _inferTitle(String url) {
    final u = url.toLowerCase();
    if (u.contains('youtube')) return 'YouTube';
    if (u.contains('twitch')) return 'Twitch';
    if (u.contains('vimeo')) return 'Vimeo';
    if (u.contains('kick')) return 'Kick';
    return 'Vídeo';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
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

              // Título
              const Text(
                'Adicionar vídeo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Cole a URL de qualquer plataforma suportada',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),

              // Chips de plataformas suportadas
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _platforms
                    .map((p) => _PlatformChip(platform: p))
                    .toList(),
              ),
              const SizedBox(height: 20),

              // Campo de URL
              _DarkTextField(
                controller: _urlController,
                hint: 'https://youtube.com/watch?v=...',
                label: 'URL do vídeo',
                keyboardType: TextInputType.url,
                onChanged: (_) =>
                    setState(() => _errorMessage = null),
              ),
              const SizedBox(height: 12),

              // Campo de título (opcional)
              _DarkTextField(
                controller: _titleController,
                hint: 'Deixe em branco para detectar automaticamente',
                label: 'Título (opcional)',
              ),

              // Erro
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Botão confirmar
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Reproduzir',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _PlatformInfo {
  final String name;
  final IconData icon;
  final String domain;

  const _PlatformInfo(this.name, this.icon, this.domain);
}

class _PlatformChip extends StatelessWidget {
  final _PlatformInfo platform;

  const _PlatformChip({required this.platform});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(platform.icon, color: Colors.white70, size: 13),
          const SizedBox(width: 5),
          Text(
            platform.name,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String label;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _DarkTextField({
    required this.controller,
    required this.hint,
    required this.label,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            keyboardType: keyboardType,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 13,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
