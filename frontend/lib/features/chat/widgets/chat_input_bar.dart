import 'package:flutter/material.dart';

import '../../../config/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Barra de input de mensagem do chat — estilo Amino.
///
/// Contém o botão de mídia (+), o campo de texto, o botão de emoji,
/// o botão de microfone (atalho rápido) e o botão de enviar.
///
/// Callbacks:
/// - [onMediaTap]: abre o painel de opções de mídia
/// - [onSend]: envia a mensagem de texto
/// - [onEmojiToggle]: alterna o emoji picker
/// - [onAudioTap]: inicia a gravação de áudio (atalho rápido ao lado do emoji)
/// - [onTextChanged]: notifica mudanças no texto (para link detection etc.)
class ChatInputBar extends ConsumerWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onMediaTap;
  final VoidCallback onSend;
  final VoidCallback onEmojiToggle;
  final VoidCallback onAudioTap;
  final ValueChanged<String>? onTextChanged;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.isSending,
    required this.onMediaTap,
    required this.onSend,
    required this.onEmojiToggle,
    required this.onAudioTap,
    this.onTextChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    return Container(
      padding: EdgeInsets.fromLTRB(r.s(8), r.s(8), r.s(8), r.s(8)),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Botão de mídia (+)
            GestureDetector(
              onTap: onMediaTap,
              child: Container(
                width: r.s(36),
                height: r.s(36),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_rounded,
                    color: AppTheme.primaryColor, size: r.s(20)),
              ),
            ),
            SizedBox(width: r.s(8)),
            // Input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(r.s(24)),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        style: TextStyle(
                            color: context.textPrimary, fontSize: r.fs(14)),
                        decoration: InputDecoration(
                          hintText: s.messagePlaceholder,
                          hintStyle: TextStyle(
                              color: Colors.grey[600], fontSize: r.fs(14)),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: r.s(16), vertical: r.s(10)),
                        ),
                        maxLines: 4,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSend(),
                        onChanged: onTextChanged,
                      ),
                    ),
                    // ── Ícone de emoji ──
                    GestureDetector(
                      onTap: onEmojiToggle,
                      child: Padding(
                        padding: EdgeInsets.only(right: r.s(4)),
                        child: Icon(Icons.emoji_emotions_outlined,
                            color: Colors.grey[600], size: r.s(20)),
                      ),
                    ),
                    // ── Ícone de microfone (atalho rápido de áudio) ──
                    GestureDetector(
                      onTap: onAudioTap,
                      child: Padding(
                        padding: EdgeInsets.only(right: r.s(8)),
                        child: Icon(Icons.mic_none_rounded,
                            color: Colors.grey[600], size: r.s(20)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: r.s(8)),
            // Botão enviar
            GestureDetector(
              onTap: isSending ? null : onSend,
              child: Container(
                width: r.s(40),
                height: r.s(40),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: isSending
                    ? Padding(
                        padding: EdgeInsets.all(r.s(10)),
                        child: const CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(Icons.send_rounded,
                        color: Colors.white, size: r.s(18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
