import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/responsive.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../services/supabase_service.dart';
import '../services/haptic_service.dart';

// ─── Widget de exibição ───────────────────────────────────────────────────────

/// Badge compacto que exibe o emoji + texto de status do usuário.
///
/// Uso:
/// ```dart
/// UserStatusBadge(emoji: '🎮', text: 'Jogando agora')
/// ```
class UserStatusBadge extends StatelessWidget {
  final String? emoji;
  final String? text;
  final bool compact; // true = só emoji, false = emoji + texto

  const UserStatusBadge({
    super.key,
    this.emoji,
    this.text,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasEmoji = emoji != null && emoji!.isNotEmpty;
    final hasText = text != null && text!.isNotEmpty;
    if (!hasEmoji && !hasText) return const SizedBox.shrink();

    final r = context.r;
    final theme = context.nexusTheme;

    if (compact) {
      // Modo compacto: só emoji em um círculo pequeno
      if (!hasEmoji) return const SizedBox.shrink();
      return Container(
        width: r.s(20),
        height: r.s(20),
        decoration: BoxDecoration(
          color: theme.backgroundPrimary,
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.backgroundSecondary,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            emoji!,
            style: TextStyle(fontSize: r.fs(11)),
          ),
        ),
      );
    }

    // Modo completo: emoji + texto
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.s(8),
        vertical: r.s(3),
      ),
      decoration: BoxDecoration(
        color: theme.backgroundSecondary.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(r.s(12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasEmoji) ...[
            Text(emoji!, style: TextStyle(fontSize: r.fs(13))),
            if (hasText) SizedBox(width: r.s(4)),
          ],
          if (hasText)
            Flexible(
              child: Text(
                text!,
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: r.fs(12),
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Bottom Sheet de edição ───────────────────────────────────────────────────

/// Bottom sheet para o usuário definir seu mood/status.
///
/// Uso:
/// ```dart
/// EditStatusSheet.show(context, currentEmoji: '🎮', currentText: 'Jogando');
/// ```
class EditStatusSheet extends ConsumerStatefulWidget {
  final String? currentEmoji;
  final String? currentText;
  final void Function(String? emoji, String? text)? onSaved;

  const EditStatusSheet({
    super.key,
    this.currentEmoji,
    this.currentText,
    this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    String? currentEmoji,
    String? currentText,
    void Function(String? emoji, String? text)? onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditStatusSheet(
        currentEmoji: currentEmoji,
        currentText: currentText,
        onSaved: onSaved,
      ),
    );
  }

  @override
  ConsumerState<EditStatusSheet> createState() => _EditStatusSheetState();
}

class _EditStatusSheetState extends ConsumerState<EditStatusSheet> {
  late final TextEditingController _emojiController;
  late final TextEditingController _textController;
  bool _isSaving = false;

  // Sugestões rápidas de emoji
  static const _quickEmojis = [
    '😊', '😎', '🎮', '🎵', '📚', '💪', '😴', '🍕',
    '🌙', '☕', '🎨', '🏃', '✈️', '🎉', '🤔', '❤️',
  ];

  @override
  void initState() {
    super.initState();
    _emojiController = TextEditingController(text: widget.currentEmoji ?? '');
    _textController = TextEditingController(text: widget.currentText ?? '');
  }

  @override
  void dispose() {
    _emojiController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    HapticService.action();

    final emoji = _emojiController.text.trim().isEmpty
        ? null
        : _emojiController.text.trim();
    final text = _textController.text.trim().isEmpty
        ? null
        : _textController.text.trim();

    try {
      await SupabaseService.client.rpc(
        'set_user_status',
        params: {
          'p_emoji': emoji,
          'p_text': text,
        },
      );
      widget.onSaved?.call(emoji, text);
      if (mounted) Navigator.of(context).pop();
    } catch (e, stack) {
      debugPrint('[EditStatusSheet] save error: $e');
      debugPrint('[EditStatusSheet] stack: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível salvar o status. Tente novamente.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _clear() async {
    HapticService.tap();
    try {
      await SupabaseService.client.rpc('clear_user_status');
      widget.onSaved?.call(null, null);
      if (mounted) Navigator.of(context).pop();
    } catch (e, stack) {
      debugPrint('[EditStatusSheet] clear error: $e');
      debugPrint('[EditStatusSheet] stack: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível limpar o status. Tente novamente.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        r.s(20),
        r.s(20),
        r.s(20),
        r.s(20) + bottomPadding,
      ),
      decoration: BoxDecoration(
        color: theme.backgroundSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: r.s(40),
              height: r.s(4),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: r.s(16)),

          // Título
          Text(
            'Definir status',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: r.fs(18),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: r.s(16)),

          // Campo de emoji
          Row(
            children: [
              // Preview do emoji
              Container(
                width: r.s(52),
                height: r.s(52),
                decoration: BoxDecoration(
                  color: theme.backgroundPrimary,
                  borderRadius: BorderRadius.circular(r.s(12)),
                  border: Border.all(
                    color: theme.accentPrimary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: ValueListenableBuilder(
                    valueListenable: _emojiController,
                    builder: (_, value, __) => Text(
                      value.text.isEmpty ? '😊' : value.text,
                      style: TextStyle(fontSize: r.fs(26)),
                    ),
                  ),
                ),
              ),
              SizedBox(width: r.s(12)),
              // Campo de texto do emoji
              Expanded(
                child: TextField(
                  controller: _emojiController,
                  maxLength: 2,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: r.fs(22),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Emoji',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    counterText: '',
                    filled: true,
                    fillColor: theme.backgroundPrimary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(r.s(10)),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: r.s(12),
                      vertical: r.s(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: r.s(12)),

          // Emojis rápidos
          Wrap(
            spacing: r.s(8),
            runSpacing: r.s(8),
            children: _quickEmojis.map((e) {
              return GestureDetector(
                onTap: () {
                  HapticService.tap();
                  _emojiController.text = e;
                },
                child: Container(
                  width: r.s(36),
                  height: r.s(36),
                  decoration: BoxDecoration(
                    color: theme.backgroundPrimary,
                    borderRadius: BorderRadius.circular(r.s(8)),
                  ),
                  child: Center(
                    child: Text(e, style: TextStyle(fontSize: r.fs(20))),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: r.s(16)),

          // Campo de texto do status
          TextField(
            controller: _textController,
            maxLength: 60,
            style: TextStyle(color: theme.textPrimary, fontSize: r.fs(14)),
            decoration: InputDecoration(
              hintText: 'O que você está fazendo?',
              hintStyle: TextStyle(color: Colors.grey[600]),
              filled: true,
              fillColor: theme.backgroundPrimary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(10)),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: r.s(12),
                vertical: r.s(12),
              ),
              counterStyle: TextStyle(color: Colors.grey[600], fontSize: r.fs(11)),
            ),
          ),
          SizedBox(height: r.s(16)),

          // Botões
          Row(
            children: [
              // Limpar status
              TextButton.icon(
                onPressed: _clear,
                icon: Icon(Icons.clear_rounded,
                    size: r.s(16), color: Colors.grey[500]),
                label: Text(
                  'Limpar',
                  style: TextStyle(color: Colors.grey[500], fontSize: r.fs(13)),
                ),
              ),
              const Spacer(),
              // Salvar
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accentPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.s(10)),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: r.s(24),
                    vertical: r.s(12),
                  ),
                ),
                child: _isSaving
                    ? SizedBox(
                        width: r.s(16),
                        height: r.s(16),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Salvar',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: r.fs(14),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
