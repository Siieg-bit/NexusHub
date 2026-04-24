import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'nine_slice_bubble.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/app_strings.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import 'dynamic_nineslice_layout.dart';
export '../../../core/widgets/avatar_with_frame.dart';

/// Custom Chat Bubble com suporte a frames equipáveis — estilo Amino Apps.
///
/// O Amino permite que usuários comprem e equipem "bubble frames" que
/// alteram a aparência visual dos balões de chat. Este widget implementa:
/// - Bubble padrão (sem frame) via [CustomPaint]
/// - Bubble com frame de imagem estático (9-slice) via [NineSliceBubble]
/// - Bubble com frame animado (GIF/WebP) via [Image.network] + [gaplessPlayback]
/// - Cores customizáveis por role (Leader, Curator, Agent)
/// - Tail (seta) apontando para o remetente
///
/// ## Modo Animado
///
/// Quando [isBubbleAnimated] é `true`, o widget usa [_buildAnimatedBubble]
/// em vez do [NineSliceBubble]. Isso é necessário porque [Canvas.drawImageNine]
/// (usado pelo [NineSliceBubble]) opera sobre [ui.Image] estático e não
/// suporta animações GIF/WebP. O modo animado usa [Image.network] com
/// [gaplessPlayback: true] como fundo do balão, preservando o loop completo.
///
/// O 9-slice scaling não é aplicado no modo animado (GIFs não suportam isso
/// tecnicamente). O fundo é exibido com [BoxFit.fill] e [BorderRadius],
/// que é o comportamento padrão de apps como Amino e Discord para bubbles animados.
class ChatBubble extends ConsumerWidget {
  final Widget child;
  final bool isMine;
  final String? bubbleFrameUrl;
  final Color? bubbleColor;
  final String? userRole;
  final bool showTail;
  final double maxWidth;

  /// Parâmetros nine-slice vindos do asset_config do store_item.
  /// Usados apenas quando [isBubbleAnimated] é false.
  /// Quando não fornecidos, usam os valores padrão do [NineSliceBubble].
  final EdgeInsets? sliceInsets;
  final Size? imageSize;
  final EdgeInsets? contentPadding;

  /// Indica se o bubble frame é animado (GIF / WebP animado).
  ///
  /// Quando `true`, usa [Image.network] com [gaplessPlayback] para preservar
  /// o loop da animação. Quando `false` (padrão), usa [NineSliceBubble] com
  /// [Canvas.drawImageNine] para renderização estática com 9-slice scaling.
  ///
  /// Deve ser lido de [UserCosmetics.isChatBubbleAnimated], que por sua
  /// vez lê [asset_config.is_animated] do banco de dados.
  final bool isBubbleAnimated;

  /// Cor customizada do texto dentro do balão.
  ///
  /// Quando fornecida, sobrescreve a cor padrão calculada por [_textColor].
  /// Lida de [asset_config.text_color] no banco de dados via
  /// [UserCosmetics.chatBubbleTextColor].
  /// Suporta formato hex com ou sem `#` (ex: `#FFFFFF` ou `FFFFFF`).
  final Color? bubbleTextColor;
  /// Polígono opcional de fill (8 pontos normalizados 0–1).
  ///
  /// Passado diretamente ao [NineSliceBubble] para aplicar [ClipPath].
  /// Quando nulo, usa o [contentPadding] normal.
  final List<Offset>? polyPoints;

  // ── Campos do modo dynamic_nineslice ──────────────────────────────────────
  /// Modo do balão. "dynamic_nineslice" ativa o layout pré-calculado.
  /// Quando nulo ou diferente, usa o comportamento clássico.
  final String? bubbleMode;

  /// Largura máxima no modo dinâmico (pixels lógicos).
  final double dynMaxWidth;

  /// Largura mínima no modo dinâmico (pixels lógicos).
  final double dynMinWidth;

  /// Padding horizontal interno no modo dinâmico (pixels lógicos).
  final double dynPaddingX;

  /// Padding vertical interno no modo dinâmico (pixels lógicos).
  final double dynPaddingY;

  /// Quando true, expande horizontalmente antes de quebrar linha.
  final bool dynHorizontalPriority;

  /// Zona de transição para suavização das bordas (0.0–1.0).
  final double dynTransitionZone;

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
    this.isBubbleAnimated = false,
    this.bubbleTextColor,
    this.polyPoints,
    // Campos dinâmicos — padrões compatíveis com o modo clássico
    this.bubbleMode,
    this.dynMaxWidth = 260.0,
    this.dynMinWidth = 60.0,
    this.dynPaddingX = 16.0,
    this.dynPaddingY = 12.0,
    this.dynHorizontalPriority = true,
    this.dynTransitionZone = 0.15,
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

  /// Cor do texto baseada no tipo de bubble.
  ///
  /// Prioridade:
  /// 1. [bubbleTextColor] — cor customizada definida no asset_config do bubble
  /// 2. Cor padrão baseada em role/isMine
  Color _textColor(BuildContext context) {
    if (bubbleTextColor != null) return bubbleTextColor!;
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
      // Bubble animado: usa Image.network com gaplessPlayback
      if (isBubbleAnimated && !bubbleFrameUrl!.startsWith('procedural:')) {
        return _buildAnimatedBubble(context);
      }
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

  /// Bubble com frame animado (GIF / WebP animado).
  ///
  /// Usa [Image.network] com [gaplessPlayback: true] como fundo do balão,
  /// preservando o loop completo da animação. O 9-slice scaling não é
  /// aplicado pois [Canvas.drawImageNine] não suporta frames animados.
  ///
  /// O layout replica o [NineSliceBubble]: alinhamento, padding lateral,
  /// [maxWidth] e padding do conteúdo são preservados.
  Widget _buildAnimatedBubble(BuildContext context) {
    final r = context.r;
    // Fallback: sliceInset(38) - kNineSliceOffset(12) + padBruto(20/14) = 46/40
    // Mantém consistência visual com o NineSliceBubble estático.
    final effectivePadding = contentPadding ??
        const EdgeInsets.symmetric(horizontal: 46, vertical: 40);
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left: isMine ? 48 : 4,
          right: isMine ? 4 : 48,
          top: r.s(3),
          bottom: r.s(3),
        ),
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth, minHeight: 48),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            // Fallback de cor enquanto o GIF carrega
            color: context.nexusTheme.accentPrimary.withValues(alpha: 0.15),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Fundo animado: GIF/WebP em loop contínuo
              Positioned.fill(
                child: Image.network(
                  bubbleFrameUrl!,
                  fit: BoxFit.fill,
                  // gaplessPlayback evita piscar entre loops da animação
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => Container(
                    color: context.nexusTheme.accentPrimary.withValues(alpha: 0.2),
                  ),
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    // Enquanto carrega, mostra fundo semitransparente
                    return Container(
                      color: context.nexusTheme.accentPrimary.withValues(alpha: 0.15),
                    );
                  },
                ),
              ),
              // Conteúdo da mensagem sobre o GIF
              Padding(
                padding: effectivePadding,
                child: DefaultTextStyle(
                  style: TextStyle(
                    // bubbleTextColor tem prioridade; fallback: branco com sombra
                    color: bubbleTextColor ?? Colors.white,
                    fontSize: r.fs(14),
                    height: 1.4,
                    shadows: bubbleTextColor == null
                        ? const [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bubble com frame decorativo estático — réplica Amino com motor 9-slice real.
  ///
  /// Usa [NineSliceBubble] para imagens PNG da loja (9-slice scaling real
  /// via [Canvas.drawImageNine]) ou [ProceduralBubbleFrame] para frames
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

    // ── Modo dynamic_nineslice ────────────────────────────────────────────────
    // Quando o asset_config define mode = "dynamic_nineslice", pré-calcula
    // as dimensões com TextPainter antes de construir o NineSliceBubble.
    // O widget filho recebe o tamanho exato e apenas desenha — não decide mais.
    //
    // Compatibilidade: quando bubbleMode != "dynamic_nineslice" (ou null),
    // o DynamicNineSliceWrapper passa null ao builder e o NineSliceBubble
    // usa o comportamento clássico sem qualquer alteração.
    if (bubbleMode == 'dynamic_nineslice') {
      final baseStyle = DefaultTextStyle.of(context).style;
      final textStyle = baseStyle.copyWith(
        fontSize: baseStyle.fontSize ?? 14.0,
        height: baseStyle.height ?? 1.45,
      );
      final effectiveSlice = sliceInsets ?? const EdgeInsets.all(38);
      return DynamicNineSliceWrapper(
        text: _extractText(child),
        textStyle: textStyle,
        sliceInsets: effectiveSlice,
        content: DynamicContentConfig(
          paddingX: dynPaddingX,
          paddingY: dynPaddingY,
          maxWidth: dynMaxWidth,
          minWidth: dynMinWidth,
        ),
        behavior: DynamicBehaviorConfig(
          horizontalPriority: dynHorizontalPriority,
          transitionZone: dynTransitionZone,
        ),
        mode: bubbleMode,
        builder: (context, result) {
          return NineSliceBubble(
            imageUrl: bubbleFrameUrl!,
            isMine: isMine,
            maxWidth: result != null ? result.width : maxWidth,
            sliceInsets: effectiveSlice,
            imageSize: imageSize ?? const Size(128, 128),
            contentPadding: result?.contentPadding ??
                contentPadding ??
                const EdgeInsets.symmetric(horizontal: 46, vertical: 40),
            textColor: bubbleTextColor,
            polyPoints: polyPoints,
            child: child,
          );
        },
      );
    }

    // ── Modo clássico (nine_slice) ────────────────────────────────────────────
    // Comportamento original preservado integralmente.
    return NineSliceBubble(
      imageUrl: bubbleFrameUrl!,
      isMine: isMine,
      maxWidth: maxWidth,
      sliceInsets: sliceInsets ?? const EdgeInsets.all(38),
      imageSize: imageSize ?? const Size(128, 128),
      // Padrão já inclui o offset de 12 px do Positioned do NineSliceBubble.
      // Fallback: sliceInset(38) - kNineSliceOffset(12) + padBruto(20/14) = 46/40
      contentPadding: contentPadding ??
          const EdgeInsets.symmetric(horizontal: 46, vertical: 40),
      // Passa a cor do texto para o NineSliceBubble aplicar no DefaultTextStyle
      textColor: bubbleTextColor,
      // Polígono opcional de fill — passado direto do UserCosmetics
      polyPoints: polyPoints,
      child: child,
    );
  }

  /// Extrai o texto de um widget filho para medição com TextPainter.
  ///
  /// Suporta [Text], [RichText] e widgets com texto aninhado.
  /// Retorna string vazia se o texto não puder ser extraído — o layout
  /// dinâmico degrada graciosamente para o tamanho mínimo.
  static String _extractText(Widget child) {
    if (child is Text) return child.data ?? child.textSpan?.toPlainText() ?? '';
    if (child is RichText) return child.text.toPlainText();
    if (child is Column) {
      for (final c in child.children) {
        final t = _extractText(c);
        if (t.isNotEmpty) return t;
      }
    }
    if (child is Row) {
      for (final c in child.children) {
        final t = _extractText(c);
        if (t.isNotEmpty) return t;
      }
    }
    if (child is Padding) return _extractText(child.child ?? const SizedBox());
    if (child is DefaultTextStyle) return _extractText(child.child);
    return '';
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
