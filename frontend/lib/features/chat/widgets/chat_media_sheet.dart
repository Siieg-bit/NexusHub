import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'message_bubble.dart' show MediaOptionItem;
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Bottom sheet com as opções de mídia do chat — Estilo Amino.
///
/// Chamadas de voz/vídeo foram removidas conforme solicitado.
/// O sistema de Sala de Projeção é acessado via botão na AppBar
/// e também aparece aqui como opção de mídia.
///
/// Extraído de chat_room_screen.dart para isolar a UI do painel de mídia.
class ChatMediaSheet extends ConsumerWidget {
  final VoidCallback onImage;
  final VoidCallback onGif;
  final VoidCallback onSticker;
  final VoidCallback onAudio;
  final VoidCallback onPoll;
  final VoidCallback onTip;
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
    required this.onScreening,
    required this.onLink,
    required this.onVideoFile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    return Padding(
      padding: EdgeInsets.fromLTRB(r.s(20), r.s(20), r.s(20), r.s(20) + MediaQuery.of(context).viewPadding.bottom),
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
                color: context.nexusTheme.accentPrimary,
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
                color: context.nexusTheme.warning,
                onTap: () {
                  Navigator.pop(context);
                  onTip();
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
    required VoidCallback onScreening,
    required VoidCallback onLink,
    required VoidCallback onVideoFile,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: context.surfaceColor.withValues(alpha: 0.7),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
            child: ChatMediaSheet(
              onImage: onImage,
              onGif: onGif,
              onSticker: onSticker,
              onAudio: onAudio,
              onPoll: onPoll,
              onTip: onTip,
              onScreening: onScreening,
              onLink: onLink,
              onVideoFile: onVideoFile,
            ),
          ),
        ),
      ),
    );
  }
}
