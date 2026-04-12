import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import 'nine_slice_bubble.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../config/nexus_theme_extension.dart';
export '../../../core/widgets/avatar_with_frame.dart';

/// Custom Chat Bubble com suporte a frames equipáveis — estilo Amino Apps.
///
/// O Amino permite que usuários comprem e equipem "bubble frames" que
/// alteram a aparência visual dos balões de chat. Este widget implementa:
/// - Bubble padrão (sem frame) via [CustomPaint]
/// - Bubble com frame de imagem (9-patch style) via [CachedNetworkImage]
/// - Cores customizáveis por role (Leader, Curator, Agent)
/// - Tail (seta) apontando para o remetente
class ChatBubble extends ConsumerWidget {
  final Widget child;
  final bool isMine;
  final String? bubbleFrameUrl;
  final Color? bubbleColor;
  final String? userRole;
  final bool showTail;
  final double maxWidth;

  /// Parâmetros nine-slice vindos do asset_config do store_item.
  /// Quando não fornecidos, usam os valores padrão do [NineSliceBubble].
  final EdgeInsets? sliceInsets;
  final Size? imageSize;
  final EdgeInsets? contentPadding;

  const ChatBubble({
    super.key,
    required this.child,
    required this.isMine,
    this.bubbleFrameUrl,
    this.bubbleColor,
    this.userRole,
    this.showTail = true,
    this.maxWidth = 280,
    this.sliceInsets,
    this.imageSize,
    this.contentPadding,
  });

  /// Cor do bubble baseada no role do usuário — estilo Amino
  Color _roleColor(BuildContext context) {
    if (bubbleColor != null) return bubbleColor!;
    switch (userRole) {
      case 'agent':
        return const Color(0xFF6C5CE7); // Roxo para Agent
      case 'leader':
        return context.nexusTheme.accentPrimary; // Verde Amino para Leader
      case 'curator':
        return const Color(0xFFE040FB); // Rosa/Magenta para Curator
      default:
        return isMine
            ? context.nexusTheme.accentPrimary
            : context.surfaceColor; // Surface escuro para outros
    }
  }

  /// Cor do texto baseada no tipo de bubble
  Color _textColor(BuildContext context) {
    if (isMine ||
        userRole == 'agent' ||
        userRole == 'leader' ||
        userRole == 'curator') {
      return Colors.white;
    }
    return context.nexusTheme.textPrimary;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Se tem frame de imagem, usar o frame
    if (bubbleFrameUrl != null && bubbleFrameUrl!.isNotEmpty) {
      return _buildFramedBubble(context);
    }

    // Bubble padrão com CustomPaint
    return _buildDefaultBubble(context);
  }

  Widget _buildDefaultBubble(BuildContext context) {
    final r = context.r;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left: isMine ? 48 : 8,
          right: isMine ? 8 : 48,
          top: 2,
          bottom: 2,
        ),
        child: CustomPaint(
          painter: _BubblePainter(
            color: _roleColor(context),
            isMine: isMine,
            showTail: showTail,
          ),
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: EdgeInsets.only(
              left: isMine ? 12 : (showTail ? 16 : 12),
              right: isMine ? (showTail ? 16 : 12) : 12,
              top: 8,
              bottom: 8,
            ),
            child: DefaultTextStyle(
              style: TextStyle(color: _textColor(context), fontSize: r.fs(14)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  /// Bubble com frame decorativo — réplica Amino com motor 9-slice real.
  ///
  /// Usa [NineSliceBubble] para imagens PNG da loja (9-slice scaling real
  /// via centerSlice do Flutter) ou [ProceduralBubbleFrame] para frames
  /// procedurais com decorações desenhadas via CustomPainter.
  Widget _buildFramedBubble(BuildContext context) {
    // Se a URL começa com 'procedural:' é um frame procedural
    if (bubbleFrameUrl!.startsWith('procedural:')) {
      final parts = bubbleFrameUrl!.split(':');
      final style = parts.length > 1 ? parts[1] : 'gradient';
      return ProceduralBubbleFrame(
        isMine: isMine,
        style: style,
        primaryColor: _roleColor(context),
        secondaryColor: _roleColor(context).withValues(alpha: 0.7),
        maxWidth: maxWidth,
        child: child,
      );
    }

    // Frame de imagem real — 9-slice scaling com parâmetros do asset_config
    return NineSliceBubble(
      imageUrl: bubbleFrameUrl!,
      isMine: isMine,
      maxWidth: maxWidth,
      sliceInsets: sliceInsets ?? const EdgeInsets.all(38),
      imageSize: imageSize ?? const Size(128, 128),
      contentPadding: contentPadding ??
          const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: child,
    );
  }
}

/// Painter customizado para o balão de chat com tail (seta).
class _BubblePainter extends CustomPainter {
  final Color color;
  final bool isMine;
  final bool showTail;

  _BubblePainter({
    required this.color,
    required this.isMine,
    required this.showTail,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    const radius = 16.0;
    const tailWidth = 8.0;
    const tailHeight = 10.0;

    final path = Path();

    if (isMine) {
      // Bubble com tail à direita
      path.moveTo(radius, 0);
      path.lineTo(size.width - radius - (showTail ? tailWidth : 0), 0);
      path.quadraticBezierTo(size.width - (showTail ? tailWidth : 0), 0,
          size.width - (showTail ? tailWidth : 0), radius);

      if (showTail) {
        path.lineTo(size.width - tailWidth, size.height - tailHeight - radius);
        path.lineTo(size.width, size.height - tailHeight + 2);
        path.lineTo(size.width - tailWidth - 4, size.height - 4);
      }

      path.lineTo(
          size.width - (showTail ? tailWidth : 0), size.height - radius);
      path.quadraticBezierTo(
          size.width - (showTail ? tailWidth : 0),
          size.height,
          size.width - radius - (showTail ? tailWidth : 0),
          size.height);
      path.lineTo(radius, size.height);
      path.quadraticBezierTo(0, size.height, 0, size.height - radius);
      path.lineTo(0, radius);
      path.quadraticBezierTo(0, 0, radius, 0);
    } else {
      // Bubble com tail à esquerda
      path.moveTo(radius + (showTail ? tailWidth : 0), 0);
      path.lineTo(size.width - radius, 0);
      path.quadraticBezierTo(size.width, 0, size.width, radius);
      path.lineTo(size.width, size.height - radius);
      path.quadraticBezierTo(
          size.width, size.height, size.width - radius, size.height);
      path.lineTo(radius + (showTail ? tailWidth : 0), size.height);
      path.quadraticBezierTo(showTail ? tailWidth : 0, size.height,
          showTail ? tailWidth : 0, size.height - radius);

      if (showTail) {
        path.lineTo(tailWidth, tailHeight + radius);
        path.lineTo(0, tailHeight - 2);
        path.lineTo(tailWidth + 4, 4);
      }

      path.lineTo(showTail ? tailWidth : 0, radius);
      path.quadraticBezierTo(
          showTail ? tailWidth : 0, 0, radius + (showTail ? tailWidth : 0), 0);
    }

    path.close();

    // Sombra sutil
    canvas.drawPath(path.shift(const Offset(0, 1)), shadowPaint);
    // Bubble
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) =>
      color != oldDelegate.color ||
      isMine != oldDelegate.isMine ||
      showTail != oldDelegate.showTail;
}

/// Widget para exibir o avatar com frame equipado — estilo Amino.
// AvatarWithFrame foi movido para core/widgets/avatar_with_frame.dart
// Re-exportado no topo do arquivo para manter compatibilidade.

/// Badge de Amino+ para exibir ao lado do nome.
class AminoPlusBadge extends ConsumerWidget {
  final double height;

  const AminoPlusBadge({super.key, this.height = 18});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: r.s(6)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
        ),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_rounded, size: height * 0.65, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            s.aminoPlus,
            style: TextStyle(
              color: Colors.white,
              fontSize: height * 0.55,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Streak Bar visual para o perfil da comunidade — estilo Amino.
class StreakBar extends ConsumerWidget {
  final int currentStreak;
  final int maxStreak;
  final int checkInDays;

  const StreakBar({
    super.key,
    required this.currentStreak,
    this.maxStreak = 0,
    this.checkInDays = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return Container(
      padding: EdgeInsets.all(r.s(12)),
      decoration: BoxDecoration(
        color: context.nexusTheme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(12)),
        border: Border.all(
          color: currentStreak > 0
              ? context.nexusTheme.warning.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                currentStreak > 0
                    ? Icons.local_fire_department_rounded
                    : Icons.local_fire_department_outlined,
                color: currentStreak > 0
                    ? context.nexusTheme.warning
                    : Colors.grey[600],
                size: r.s(20),
              ),
              SizedBox(width: r.s(6)),
              Text(
                s.checkInSequence,
                style: TextStyle(
                  color: currentStreak > 0
                      ? context.nexusTheme.textPrimary
                      : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                  fontSize: r.fs(13),
                ),
              ),
              const Spacer(),
              if (maxStreak > 0)
                Text(
                  s.maxStreakRecord,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: r.fs(11),
                  ),
                ),
            ],
          ),
          SizedBox(height: r.s(8)),
          // Streak dots (últimos 7 dias)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final isActive = i < currentStreak.clamp(0, 7);
              return Column(
                children: [
                  Container(
                    width: r.s(32),
                    height: r.s(32),
                    decoration: BoxDecoration(
                      color: isActive
                          ? context.nexusTheme.warning.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.03),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive
                            ? context.nexusTheme.warning
                            : Colors.white.withValues(alpha: 0.1),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: isActive
                          ? Icon(Icons.check_rounded,
                              size: r.s(16), color: context.nexusTheme.warning)
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: r.fs(11),
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: r.s(4)),
                  Text(
                    _dayLabel(i, s),
                    style: TextStyle(
                      color:
                          isActive ? context.nexusTheme.warning : Colors.grey[600],
                      fontSize: r.fs(9),
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              );
            }),
          ),
          if (currentStreak > 0) ...[
            SizedBox(height: r.s(8)),
            Row(
              children: [
                Icon(Icons.local_fire_department_rounded,
                    size: r.s(14), color: context.nexusTheme.warning),
                SizedBox(width: r.s(4)),
                Text(
                  '$currentStreak dia${currentStreak > 1 ? 's' : ''} seguido${currentStreak > 1 ? 's' : ''}',
                  style: TextStyle(
                    color: context.nexusTheme.warning,
                    fontWeight: FontWeight.bold,
                    fontSize: r.fs(12),
                  ),
                ),
                const Spacer(),
                Text(
                  s.totalCheckIns,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: r.fs(11),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _dayLabel(int index, AppStrings s) {
    final s = getStrings();
    final days = [s.monday, s.tuesday, s.wednesday, s.thursday, s.friday, s.saturday, s.sunday];
    final today = DateTime.now().weekday - 1; // 0 = Monday
    final dayIndex = (today - (6 - index)) % 7;
    return days[dayIndex < 0 ? dayIndex + 7 : dayIndex];
  }
}
