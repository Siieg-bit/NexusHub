import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/responsive.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Mapa de tipo de reaction → emoji e cor
const kReactionMeta = {
  'like':  {'emoji': '❤️', 'label': 'Curtir',   'color': Color(0xFFE91E63)},
  'love':  {'emoji': '😍', 'label': 'Amei',     'color': Color(0xFFE91E63)},
  'haha':  {'emoji': '😂', 'label': 'Haha',     'color': Color(0xFFFF9800)},
  'wow':   {'emoji': '😮', 'label': 'Uau',      'color': Color(0xFFFF9800)},
  'sad':   {'emoji': '😢', 'label': 'Triste',   'color': Color(0xFF2196F3)},
  'angry': {'emoji': '😡', 'label': 'Grr',      'color': Color(0xFFF44336)},
};

/// Retorna o emoji correspondente ao tipo de reaction.
String reactionEmoji(String? type) =>
    (kReactionMeta[type]?['emoji'] as String?) ?? '❤️';

/// Retorna a cor correspondente ao tipo de reaction.
Color reactionColor(String? type, Color fallback) =>
    (kReactionMeta[type]?['color'] as Color?) ?? fallback;

/// Widget que exibe o botão de reaction com suporte a long-press para picker.
///
/// - Tap simples: toggle 'like' (coração)
/// - Long press: abre o picker de reactions
class ReactionButton extends StatefulWidget {
  final String? currentReaction; // tipo atual ou null
  final int totalCount;
  final ValueChanged<String?> onReaction; // null = remover reaction

  const ReactionButton({
    super.key,
    required this.currentReaction,
    required this.totalCount,
    required this.onReaction,
  });

  @override
  State<ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<ReactionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.35)
        .chain(CurveTween(curve: Curves.elasticOut))
        .animate(_scaleCtrl);
  }

  @override
  void dispose() {
    _removeOverlay();
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showPicker() {
    HapticFeedback.mediumImpact();
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (ctx) => _ReactionPickerOverlay(
        anchorOffset: offset,
        anchorSize: renderBox.size,
        currentReaction: widget.currentReaction,
        onSelect: (type) {
          _removeOverlay();
          widget.onReaction(type);
        },
        onDismiss: _removeOverlay,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _onTap() {
    // Toggle like simples
    _scaleCtrl.forward().then((_) => _scaleCtrl.reverse());
    if (widget.currentReaction != null) {
      HapticFeedback.lightImpact();
      widget.onReaction(null); // remover
    } else {
      HapticFeedback.mediumImpact();
      widget.onReaction('like'); // adicionar like
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final hasReaction = widget.currentReaction != null;
    final reactionType = widget.currentReaction;
    final color = hasReaction
        ? reactionColor(reactionType, context.nexusTheme.accentPrimary)
        : Colors.grey[500]!;

    // 'like' usa ícone vetorial de coração; demais reactions usam emoji.
    final bool useVectorIcon = !hasReaction || reactionType == 'like';

    return GestureDetector(
      onTap: _onTap,
      onLongPress: _showPicker,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: r.s(22),
              height: r.s(22),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: child,
                ),
                child: useVectorIcon
                    ? Icon(
                        hasReaction
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        key: ValueKey('heart_$hasReaction'),
                        size: r.s(22),
                        color: color,
                      )
                    : Center(
                        child: Text(
                          reactionEmoji(reactionType),
                          key: ValueKey(reactionType),
                          style: TextStyle(
                            fontSize: r.fs(17),
                            height: 1.0,
                          ),
                        ),
                      ),
              ),
            ),
            if (widget.totalCount > 0) ...[
              SizedBox(width: r.s(4)),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: color,
                  fontSize: r.fs(13),
                  fontWeight: FontWeight.w600,
                ),
                child: Text(
                  widget.totalCount.toString(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Overlay flutuante com os 6 emojis de reaction.
class _ReactionPickerOverlay extends StatefulWidget {
  final Offset anchorOffset;
  final Size anchorSize;
  final String? currentReaction;
  final ValueChanged<String?> onSelect;
  final VoidCallback onDismiss;

  const _ReactionPickerOverlay({
    required this.anchorOffset,
    required this.anchorSize,
    required this.currentReaction,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<_ReactionPickerOverlay> createState() =>
      _ReactionPickerOverlayState();
}

class _ReactionPickerOverlayState extends State<_ReactionPickerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final reactions = kReactionMeta.entries.toList();
    // Posicionar acima do botão
    final top = widget.anchorOffset.dy - r.s(64);
    final left = (widget.anchorOffset.dx - r.s(20))
        .clamp(8.0, MediaQuery.of(context).size.width - r.s(280));

    return GestureDetector(
      onTap: widget.onDismiss,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          Positioned(
            top: top,
            left: left,
            child: ScaleTransition(
              scale: _scaleAnim,
              alignment: Alignment.bottomLeft,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(10), vertical: r.s(8)),
                  decoration: BoxDecoration(
                    color: context.nexusTheme.backgroundSecondary,
                    borderRadius: BorderRadius.circular(r.s(28)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(reactions.length, (i) {
                      final entry = reactions[i];
                      final type = entry.key;
                      final meta = entry.value;
                      final isSelected = widget.currentReaction == type;
                      final isHovered = _hoveredIndex == i;

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onSelect(isSelected ? null : type);
                        },
                        child: MouseRegion(
                          onEnter: (_) =>
                              setState(() => _hoveredIndex = i),
                          onExit: (_) =>
                              setState(() => _hoveredIndex = null),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin:
                                EdgeInsets.symmetric(horizontal: r.s(3)),
                            padding: EdgeInsets.all(r.s(4)),
                            transform: Matrix4.identity()
                              ..scale(isHovered || isSelected ? 1.3 : 1.0),
                            transformAlignment: Alignment.center,
                            decoration: isSelected
                                ? BoxDecoration(
                                    color: (meta['color'] as Color)
                                        .withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  )
                                : null,
                            child: Tooltip(
                              message: meta['label'] as String,
                              child: Text(
                                meta['emoji'] as String,
                                style: TextStyle(fontSize: r.fs(26)),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget compacto que exibe as contagens de reactions mais populares.
class ReactionCountsRow extends StatelessWidget {
  final int likeCount;
  final int loveCount;
  final int hahaCount;
  final int wowCount;
  final int sadCount;
  final int angryCount;

  const ReactionCountsRow({
    super.key,
    required this.likeCount,
    required this.loveCount,
    required this.hahaCount,
    required this.wowCount,
    required this.sadCount,
    required this.angryCount,
  });

  int get total =>
      likeCount + loveCount + hahaCount + wowCount + sadCount + angryCount;

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    final r = context.r;

    // Ordenar por contagem e mostrar os top 3
    final counts = {
      'like': likeCount,
      'love': loveCount,
      'haha': hahaCount,
      'wow': wowCount,
      'sad': sadCount,
      'angry': angryCount,
    };
    final top = counts.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topTypes = top.take(3).map((e) => e.key).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...topTypes.map((type) => Padding(
              padding: EdgeInsets.only(right: r.s(1)),
              child: Text(
                reactionEmoji(type),
                style: TextStyle(fontSize: r.fs(13)),
              ),
            )),
        SizedBox(width: r.s(4)),
        Text(
          total.toString(),
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: r.fs(12),
          ),
        ),
      ],
    );
  }
}
