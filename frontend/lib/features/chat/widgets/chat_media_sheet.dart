import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../../../config/app_theme.dart';
import '../../../core/utils/responsive.dart';
import 'message_bubble.dart';
import '../../../core/l10n/locale_provider.dart';

/// Bottom sheet com as opções de mídia do chat (19+ tipos) — Estilo Amino.
///
/// Cada opção retorna um identificador de ação via Navigator.pop para que
/// o caller (chat_room_screen) execute a lógica correspondente.
///
/// Extraído de chat_room_screen.dart para isolar a UI do painel de mídia.
class ChatMediaSheet extends ConsumerWidget {
  final VoidCallback onImage;
  final VoidCallback onGif;
  final VoidCallback onSticker;
  final VoidCallback onAudio;
  final VoidCallback onPoll;
  final VoidCallback onTip;
  final VoidCallback onVoiceCall;
  final VoidCallback onVideoCall;
  final VoidCallback onScreening;
  final VoidCallback onLink;
  final VoidCallback onVideoFile;

  const ChatMediaSheet({
    super.key,
    required this.onImage,
    required this.onGif,
    required this.onSticker,
    required this.onAudio,
    required this.onPoll,
    required this.onTip,
    required this.onVoiceCall,
    required this.onVideoCall,
    required this.onScreening,
    required this.onLink,
    required this.onVideoFile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return Padding(
      padding: EdgeInsets.all(r.s(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: r.s(36),
            height: r.s(4),
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: r.s(20)),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              MediaOptionItem(
                icon: Icons.image_rounded,
                label: s.image2,
                color: AppTheme.primaryColor,
                onTap: () {
                  Navigator.pop(context);
                  onImage();
                },
              ),
              MediaOptionItem(
                icon: Icons.gif_rounded,
                label: s.gif,
                color: const Color(0xFF9C27B0),
                onTap: () {
                  Navigator.pop(context);
                  onGif();
                },
              ),
              MediaOptionItem(
                icon: Icons.emoji_emotions_rounded,
                label: s.sticker,
                color: const Color(0xFFFF9800),
                onTap: () {
                  Navigator.pop(context);
                  onSticker();
                },
              ),
              MediaOptionItem(
                icon: Icons.mic_rounded,
                label: s.audio2,
                color: const Color(0xFFE91E63),
                onTap: () {
                  Navigator.pop(context);
                  onAudio();
                },
              ),
              MediaOptionItem(
                icon: Icons.poll_rounded,
                label: s.poll2,
                color: const Color(0xFF00BCD4),
                onTap: () {
                  Navigator.pop(context);
                  onPoll();
                },
              ),
              MediaOptionItem(
                icon: Icons.monetization_on_rounded,
                label: s.tip,
                color: AppTheme.warningColor,
                onTap: () {
                  Navigator.pop(context);
                  onTip();
                },
              ),
              MediaOptionItem(
                icon: Icons.headset_mic_rounded,
                label: s.voice,
                color: const Color(0xFF4CAF50),
                onTap: () {
                  Navigator.pop(context);
                  onVoiceCall();
                },
              ),
              MediaOptionItem(
                icon: Icons.video_call_rounded,
                label: s.video,
                color: const Color(0xFF2196F3),
                onTap: () {
                  Navigator.pop(context);
                  onVideoCall();
                },
              ),
              MediaOptionItem(
                icon: Icons.live_tv_rounded,
                label: s.screening,
                color: const Color(0xFFFF5722),
                onTap: () {
                  Navigator.pop(context);
                  onScreening();
                },
              ),
              MediaOptionItem(
                icon: Icons.link_rounded,
                label: s.link,
                color: const Color(0xFF3F51B5),
                onTap: () {
                  Navigator.pop(context);
                  onLink();
                },
              ),
              MediaOptionItem(
                icon: Icons.video_file_rounded,
                label: s.videoLabel,
                color: const Color(0xFFFF5722),
                onTap: () {
                  Navigator.pop(context);
                  onVideoFile();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Mostra o bottom sheet de opções de mídia.
  static void show(
    BuildContext context, {
    required VoidCallback onImage,
    required VoidCallback onGif,
    required VoidCallback onSticker,
    required VoidCallback onAudio,
    required VoidCallback onPoll,
    required VoidCallback onTip,
    required VoidCallback onVoiceCall,
    required VoidCallback onVideoCall,
    required VoidCallback onScreening,
    required VoidCallback onLink,
    required VoidCallback onVideoFile,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ChatMediaSheet(
        onImage: onImage,
        onGif: onGif,
        onSticker: onSticker,
        onAudio: onAudio,
        onPoll: onPoll,
        onTip: onTip,
        onVoiceCall: onVoiceCall,
        onVideoCall: onVideoCall,
        onScreening: onScreening,
        onLink: onLink,
        onVideoFile: onVideoFile,
      ),
    );
  }
}
