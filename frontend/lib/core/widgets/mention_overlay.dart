import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/supabase_service.dart';
import '../utils/responsive.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Modelo leve para sugestões de menção.
class MentionCandidate {
  final String id;
  final String nickname;
  final String aminoId;
  final String? iconUrl;

  const MentionCandidate({
    required this.id,
    required this.nickname,
    required this.aminoId,
    this.iconUrl,
  });

  factory MentionCandidate.fromJson(Map<String, dynamic> json) =>
      MentionCandidate(
        id: json['id'] as String? ?? '',
        nickname: json['nickname'] as String? ?? '',
        aminoId: json['amino_id'] as String? ?? '',
        iconUrl: json['icon_url'] as String?,
      );

  /// O handle que será inserido no texto: @aminoId (ou @nickname se aminoId vazio)
  String get handle => aminoId.isNotEmpty ? aminoId : nickname;
}

/// Controlador de menção — envolve um [TextEditingController] e emite
/// sugestões sempre que o usuário digita `@query`.
///
/// Uso:
/// ```dart
/// final _mentionCtrl = MentionController(baseController: _textController);
/// // No build:
/// MentionOverlay(controller: _mentionCtrl, communityId: widget.communityId)
/// // No TextField:
/// controller: _mentionCtrl.textController
/// ```
class MentionController extends ChangeNotifier {
  final TextEditingController textController;

  /// ID da comunidade para filtrar sugestões por membros (opcional).
  final String? communityId;

  List<MentionCandidate> _suggestions = [];
  List<MentionCandidate> get suggestions => _suggestions;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Posição do cursor quando o `@` foi detectado.
  int _mentionStart = -1;

  /// Query atual após o `@`.
  String _query = '';
  String get query => _query;

  bool get isActive => _mentionStart >= 0;

  Timer? _debounce;

  MentionController({
    required this.textController,
    this.communityId,
  }) {
    textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final text = textController.text;
    final cursor = textController.selection.baseOffset;
    if (cursor < 0) return;

    // Procurar o @ mais próximo antes do cursor
    final before = text.substring(0, cursor);
    final atIndex = before.lastIndexOf('@');

    if (atIndex < 0) {
      _dismiss();
      return;
    }

    // Verificar se há espaço entre o @ e o cursor (menção encerrada)
    final afterAt = before.substring(atIndex + 1);
    if (afterAt.contains(' ') || afterAt.contains('\n')) {
      _dismiss();
      return;
    }

    // Verificar se o @ está no início ou precedido por espaço/newline
    if (atIndex > 0) {
      final charBefore = text[atIndex - 1];
      if (charBefore != ' ' && charBefore != '\n') {
        _dismiss();
        return;
      }
    }

    final newQuery = afterAt;
    if (newQuery == _query && _mentionStart == atIndex) return;

    _mentionStart = atIndex;
    _query = newQuery;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(newQuery));
  }

  Future<void> _search(String query) async {
    _isLoading = true;
    notifyListeners();

    try {
      var q = SupabaseService.table('profiles')
          .select('id, nickname, amino_id, icon_url');

      if (query.isNotEmpty) {
        q = q.ilike('nickname', '%$query%');
      }

      // Se tem comunidade, priorizar membros da comunidade
      // (busca simples por nickname — pode ser expandida com join em community_members)
      final results = await q.limit(8);
      _suggestions = (results as List)
          .map((e) => MentionCandidate.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _suggestions = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Insere a menção no texto substituindo `@query` por `@handle `.
  void insertMention(MentionCandidate candidate) {
    final text = textController.text;
    final cursor = textController.selection.baseOffset;
    if (_mentionStart < 0 || cursor < 0) return;

    final before = text.substring(0, _mentionStart);
    final after = text.substring(cursor);
    final inserted = '@${candidate.handle} ';

    textController.value = TextEditingValue(
      text: '$before$inserted$after',
      selection: TextSelection.collapsed(
        offset: before.length + inserted.length,
      ),
    );

    _dismiss();
  }

  void _dismiss() {
    if (_mentionStart < 0 && _suggestions.isEmpty) return;
    _mentionStart = -1;
    _query = '';
    _suggestions = [];
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    textController.removeListener(_onTextChanged);
    super.dispose();
  }
}

/// Widget que exibe o overlay de sugestões de menção acima do teclado.
///
/// Deve ser colocado em um [Stack] ou como filho direto de um [Column]
/// abaixo do [TextField] associado.
class MentionOverlay extends ConsumerWidget {
  final MentionController controller;

  const MentionOverlay({super.key, required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.isActive) return const SizedBox.shrink();

        final r = context.r;
        final theme = context.nexusTheme;
        final suggestions = controller.suggestions;
        final isLoading = controller.isLoading;

        if (!isLoading && suggestions.isEmpty) return const SizedBox.shrink();

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          constraints: BoxConstraints(maxHeight: r.s(220)),
          decoration: BoxDecoration(
            color: theme.backgroundSecondary,
            border: Border(
              top: BorderSide(color: theme.divider, width: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: isLoading
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(r.s(12)),
                    child: SizedBox(
                      width: r.s(20),
                      height: r.s(20),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.accentPrimary,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.symmetric(vertical: r.s(4)),
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final candidate = suggestions[index];
                    return _MentionItem(
                      candidate: candidate,
                      query: controller.query,
                      onTap: () => controller.insertMention(candidate),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _MentionItem extends StatelessWidget {
  final MentionCandidate candidate;
  final String query;
  final VoidCallback onTap;

  const _MentionItem({
    required this.candidate,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: r.s(16),
          vertical: r.s(8),
        ),
        child: Row(
          children: [
            // Avatar
            ClipOval(
              child: candidate.iconUrl != null && candidate.iconUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: candidate.iconUrl!,
                      width: r.s(36),
                      height: r.s(36),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _defaultAvatar(r, theme, candidate),
                    )
                  : _defaultAvatar(r, theme, candidate),
            ),
            SizedBox(width: r.s(12)),
            // Nome e handle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HighlightText(
                    text: candidate.nickname,
                    highlight: query,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: r.fs(14),
                      fontWeight: FontWeight.w600,
                    ),
                    highlightStyle: TextStyle(
                      color: theme.accentPrimary,
                      fontSize: r.fs(14),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (candidate.aminoId.isNotEmpty)
                    Text(
                      '@${candidate.aminoId}',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: r.fs(12),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar(Responsive r, NexusThemeExtension theme, MentionCandidate c) {
    return Container(
      width: r.s(36),
      height: r.s(36),
      color: theme.accentPrimary.withValues(alpha: 0.2),
      child: Center(
        child: Text(
          (c.nickname.isNotEmpty ? c.nickname[0] : '?').toUpperCase(),
          style: TextStyle(
            color: theme.accentPrimary,
            fontWeight: FontWeight.bold,
            fontSize: r.fs(16),
          ),
        ),
      ),
    );
  }
}

/// Widget de texto com highlight da query de busca.
class _HighlightText extends StatelessWidget {
  final String text;
  final String highlight;
  final TextStyle style;
  final TextStyle highlightStyle;

  const _HighlightText({
    required this.text,
    required this.highlight,
    required this.style,
    required this.highlightStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (highlight.isEmpty) {
      return Text(text, style: style);
    }

    final lower = text.toLowerCase();
    final lowerHighlight = highlight.toLowerCase();
    final start = lower.indexOf(lowerHighlight);

    if (start < 0) return Text(text, style: style);

    final end = start + highlight.length;
    return Text.rich(
      TextSpan(
        children: [
          if (start > 0) TextSpan(text: text.substring(0, start), style: style),
          TextSpan(text: text.substring(start, end), style: highlightStyle),
          if (end < text.length) TextSpan(text: text.substring(end), style: style),
        ],
      ),
    );
  }
}
