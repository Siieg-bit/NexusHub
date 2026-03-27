import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';

/// Custom Chat Bubble com suporte a frames equipáveis.
///
/// O Amino permite que usuários comprem e equipem "bubble frames" que
/// alteram a aparência visual dos balões de chat. Este widget implementa:
/// - Bubble padrão (sem frame) via [CustomPaint]
/// - Bubble com frame de imagem (9-patch style) via [CachedNetworkImage]
/// - Cores customizáveis por role (Leader, Curator, Agent)
/// - Tail (seta) apontando para o remetente
class ChatBubble extends StatelessWidget {
  final Widget child;
  final bool isMine;
  final String? bubbleFrameUrl;
  final Color? bubbleColor;
  final String? userRole;
  final bool showTail;
  final double maxWidth;

  const ChatBubble({
    super.key,
    required this.child,
    required this.isMine,
    this.bubbleFrameUrl,
    this.bubbleColor,
    this.userRole,
    this.showTail = true,
    this.maxWidth = 280,
  });

  /// Cor do bubble baseada no role do usuário
  Color get _roleColor {
    if (bubbleColor != null) return bubbleColor!;
    switch (userRole) {
      case 'agent':
        return const Color(0xFF6C5CE7); // Roxo para Agent
      case 'leader':
        return const Color(0xFF00B894); // Verde para Leader
      case 'curator':
        return const Color(0xFF0984E3); // Azul para Curator
      default:
        return isMine
            ? AppTheme.primaryColor
            : const Color(0xFF2D2D3A); // Cinza escuro para outros
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se tem frame de imagem, usar o frame
    if (bubbleFrameUrl != null && bubbleFrameUrl!.isNotEmpty) {
      return _buildFramedBubble();
    }

    // Bubble padrão com CustomPaint
    return _buildDefaultBubble();
  }

  Widget _buildDefaultBubble() {
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
            color: _roleColor,
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
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildFramedBubble() {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left: isMine ? 48 : 8,
          right: isMine ? 8 : 48,
          top: 2,
          bottom: 2,
        ),
        child: Stack(
          children: [
            // Frame de imagem (9-patch style)
            CachedNetworkImage(
              imageUrl: bubbleFrameUrl!,
              fit: BoxFit.fill,
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
            // Conteúdo sobre o frame
            Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: child,
            ),
          ],
        ),
      ),
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
      ..color = Colors.black.withOpacity(0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    const radius = 16.0;
    const tailWidth = 8.0;
    const tailHeight = 10.0;

    final path = Path();

    if (isMine) {
      // Bubble com tail à direita
      path.moveTo(radius, 0);
      path.lineTo(size.width - radius - (showTail ? tailWidth : 0), 0);
      path.quadraticBezierTo(
          size.width - (showTail ? tailWidth : 0), 0,
          size.width - (showTail ? tailWidth : 0), radius);

      if (showTail) {
        path.lineTo(size.width - tailWidth, size.height - tailHeight - radius);
        // Tail
        path.lineTo(size.width, size.height - tailHeight + 2);
        path.lineTo(size.width - tailWidth - 4, size.height - 4);
      }

      path.lineTo(size.width - (showTail ? tailWidth : 0),
          size.height - radius);
      path.quadraticBezierTo(
          size.width - (showTail ? tailWidth : 0), size.height,
          size.width - radius - (showTail ? tailWidth : 0), size.height);
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
      path.quadraticBezierTo(
          showTail ? tailWidth : 0, size.height,
          showTail ? tailWidth : 0, size.height - radius);

      if (showTail) {
        path.lineTo(tailWidth, tailHeight + radius);
        // Tail
        path.lineTo(0, tailHeight - 2);
        path.lineTo(tailWidth + 4, 4);
      }

      path.lineTo(showTail ? tailWidth : 0, radius);
      path.quadraticBezierTo(
          showTail ? tailWidth : 0, 0,
          radius + (showTail ? tailWidth : 0), 0);
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

/// Widget para exibir o avatar com frame equipado.
class AvatarWithFrame extends StatelessWidget {
  final String? avatarUrl;
  final String? frameUrl;
  final double size;
  final bool showAminoPlus;

  const AvatarWithFrame({
    super.key,
    this.avatarUrl,
    this.frameUrl,
    this.size = 48,
    this.showAminoPlus = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 8,
      height: size + 8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Avatar
          CircleAvatar(
            radius: size / 2,
            backgroundColor: AppTheme.cardColor,
            backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                ? CachedNetworkImageProvider(avatarUrl!)
                : null,
            child: avatarUrl == null || avatarUrl!.isEmpty
                ? Icon(Icons.person_rounded,
                    size: size * 0.5, color: AppTheme.textHint)
                : null,
          ),

          // Frame overlay
          if (frameUrl != null && frameUrl!.isNotEmpty)
            SizedBox(
              width: size + 8,
              height: size + 8,
              child: CachedNetworkImage(
                imageUrl: frameUrl!,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),

          // Amino+ badge
          if (showAminoPlus)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: size * 0.35,
                height: size * 0.35,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.scaffoldBg, width: 2),
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: size * 0.2,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Badge de Amino+ para exibir ao lado do nome.
class AminoPlusBadge extends StatelessWidget {
  final double height;

  const AminoPlusBadge({super.key, this.height = 18});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 6),
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
            'Amino+',
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

/// Streak Bar visual para o perfil da comunidade.
class StreakBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: currentStreak > 0
              ? AppTheme.warningColor.withOpacity(0.3)
              : AppTheme.dividerColor,
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
                    ? AppTheme.warningColor
                    : AppTheme.textHint,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                'Ofensiva de Check-in',
                style: TextStyle(
                  color: currentStreak > 0
                      ? AppTheme.textPrimary
                      : AppTheme.textHint,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (maxStreak > 0)
                Text(
                  'Recorde: $maxStreak dias',
                  style: const TextStyle(
                    color: AppTheme.textHint,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Streak dots (últimos 7 dias)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final isActive = i < currentStreak.clamp(0, 7);
              return Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppTheme.warningColor.withOpacity(0.2)
                          : AppTheme.dividerColor.withOpacity(0.3),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive
                            ? AppTheme.warningColor
                            : AppTheme.dividerColor,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: isActive
                          ? const Icon(Icons.check_rounded,
                              size: 16, color: AppTheme.warningColor)
                          : Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: AppTheme.textHint,
                                fontSize: 11,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _dayLabel(i),
                    style: TextStyle(
                      color: isActive
                          ? AppTheme.warningColor
                          : AppTheme.textHint,
                      fontSize: 9,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              );
            }),
          ),
          if (currentStreak > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.local_fire_department_rounded,
                    size: 14, color: AppTheme.warningColor),
                const SizedBox(width: 4),
                Text(
                  '$currentStreak dia${currentStreak > 1 ? 's' : ''} seguido${currentStreak > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: AppTheme.warningColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  'Total: $checkInDays check-ins',
                  style: const TextStyle(
                    color: AppTheme.textHint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _dayLabel(int index) {
    const days = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    final today = DateTime.now().weekday - 1; // 0 = Monday
    final dayIndex = (today - (6 - index)) % 7;
    return days[dayIndex < 0 ? dayIndex + 7 : dayIndex];
  }
}
