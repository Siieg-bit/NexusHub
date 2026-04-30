import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../l10n/locale_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Widget de Avatar com Frame decorativo — réplica pixel-perfect do Amino.
///
/// O frame é uma imagem PNG/GIF/WebP com transparência que envolve o avatar
/// circular. O frame é renderizado 40% maior que o avatar e centralizado
/// sobre ele usando [Align] dentro de um [Stack] com [Clip.none].
///
/// ## Molduras Animadas
///
/// Quando [isFrameAnimated] é `true` (lido de `asset_config.is_animated`),
/// o widget usa [Image.network] em vez de [CachedNetworkImage] para renderizar
/// o frame. Isso é necessário porque [CachedNetworkImage] pode armazenar
/// apenas o primeiro frame de um GIF em cache, quebrando a animação.
/// [Image.network] preserva a animação completa do GIF/WebP animado.
///
/// O Flutter renderiza GIF e WebP animado nativamente desde a versão 1.x —
/// nenhuma dependência adicional é necessária.
///
/// ## Indicadores de Estado
///
/// O widget suporta três estados visuais mutuamente exclusivos por prioridade:
///
/// 1. **Call/Projeção ativa** ([hasActiveCall] = true): Borda glow verde pulsante.
///    Indica que o usuário está em uma call ou projeção pública em andamento.
///    Tem prioridade máxima — sobrepõe o anel de story.
///
/// 2. **Story não visto** ([hasActiveStory] = true): Anel gradiente laranja/rosa.
///    Indica que o usuário tem stories ativos não visualizados pelo viewer atual.
///    Exibido apenas quando não há call ativa.
///
/// 3. **Nenhum indicador**: Borda sutil branca com 10% de opacidade.
///
/// Essa hierarquia garante que não haja conflito visual entre os dois anéis.
class AvatarWithFrame extends ConsumerStatefulWidget {
  /// URL da imagem do avatar do usuário.
  final String? avatarUrl;

  /// URL da imagem do frame decorativo (PNG/GIF/WebP com transparência).
  final String? frameUrl;

  /// Tamanho do avatar em pixels (diâmetro do círculo interno).
  final double size;

  /// Se deve mostrar o badge de Amino+ no canto inferior direito.
  final bool showAminoPlus;

  /// Se deve mostrar o indicador de online (ponto verde).
  final bool showOnline;

  /// Callback ao tocar no avatar.
  final VoidCallback? onTap;

  /// Indica se a moldura é animada (GIF ou WebP animado).
  ///
  /// Quando `true`, usa [Image.network] para preservar a animação.
  /// Quando `false` (padrão), usa [CachedNetworkImage] para melhor
  /// performance e cache.
  ///
  /// Deve ser lido de [UserCosmetics.isAvatarFrameAnimated], que por sua
  /// vez lê `asset_config.is_animated` do banco de dados.
  final bool isFrameAnimated;

  /// Indica se o usuário tem um story ativo não visto. Quando `true`, exibe um
  /// anel gradiente ao redor do avatar (estilo Instagram/Amino).
  ///
  /// Ignorado quando [hasActiveCall] é `true` — a call tem prioridade visual.
  final bool hasActiveStory;

  /// Indica se o usuário está em uma call ou projeção pública ativa.
  ///
  /// Quando `true`, exibe uma borda glow verde pulsante com prioridade máxima.
  /// Sobrepõe o anel de story para evitar conflito visual.
  final bool hasActiveCall;

  /// Indica se a call ativa é uma sala de projeção (screening room).
  ///
  /// Quando `true` e [hasActiveCall] também é `true`, usa um ícone de
  /// projeção em vez do ícone de microfone no badge de call.
  final bool isScreeningRoom;

  const AvatarWithFrame({
    super.key,
    this.avatarUrl,
    this.frameUrl,
    this.size = 48,
    this.showAminoPlus = false,
    this.showOnline = false,
    this.onTap,
    this.isFrameAnimated = false,
    this.hasActiveStory = false,
    this.hasActiveCall = false,
    this.isScreeningRoom = false,
  });

  @override
  ConsumerState<AvatarWithFrame> createState() => _AvatarWithFrameState();
}

class _AvatarWithFrameState extends ConsumerState<AvatarWithFrame>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    if (widget.hasActiveCall) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AvatarWithFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasActiveCall && !_glowController.isAnimating) {
      _glowController.repeat(reverse: true);
    } else if (!widget.hasActiveCall && _glowController.isAnimating) {
      _glowController.stop();
      _glowController.reset();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final hasFrame = (widget.frameUrl ?? '').isNotEmpty;
    // Frame é 40% maior que o avatar para acomodar decorações externas
    final frameSize = widget.size * 1.4;
    // O SizedBox total tem o tamanho do frame para não cortar as bordas
    final totalSize = hasFrame ? frameSize : widget.size;
    // Anel de story: 4px de padding ao redor do avatar
    final storyRingSize = widget.size + 8.0;
    // Anel de call: 6px de padding ao redor do avatar (ligeiramente maior para destaque)
    final callRingSize = widget.size + 10.0;

    // Prioridade de indicadores:
    // 1. Call ativa (glow verde pulsante) — máxima prioridade
    // 2. Story não visto (anel gradiente) — só quando não há call
    // 3. Nenhum (borda sutil)
    //
    // Quando há moldura (hasFrame=true), o anel fica entre o avatar e a moldura,
    // pois o anel (size+8~10px) é menor que o frame (size×1.4). A moldura
    // continua visível por cima — comportamento elegante sem conflito.
    final showCallRing = widget.hasActiveCall;
    final showStoryRing = widget.hasActiveStory && !widget.hasActiveCall;

    final innerWidget = GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: totalSize,
        height: totalSize,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // ── Anel de call ativa (glow verde pulsante, camada inferior) ──
            if (showCallRing)
              AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) => Center(
                  child: Container(
                    width: callRingSize,
                    height: callRingSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // Gradiente verde para call/projeção ativa
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF00E676), // verde vibrante
                          Color(0xFF1DE9B6), // teal/verde-água
                          Color(0xFF00BFA5), // verde escuro
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E676)
                              .withValues(alpha: _glowAnimation.value * 0.7),
                          blurRadius: 8 + (_glowAnimation.value * 6),
                          spreadRadius: _glowAnimation.value * 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Anel de story (camada inferior, quando ativo e sem call) ──
            if (showStoryRing)
              Center(
                child: Container(
                  width: storyRingSize,
                  height: storyRingSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFE91E63),
                        Color(0xFFFF5722),
                        Color(0xFFFF9800),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),

            // ── Avatar circular (camada base, centralizado) ──
            Center(
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.surfaceColor,
                  // Borda separadora entre o avatar e o anel de status:
                  // - Sem anel e sem frame: borda sutil branca (10% opacidade)
                  // - Com anel (story ou call): borda backgroundPrimary para
                  //   criar separação visual entre o avatar e o anel colorido
                  // - Com frame e sem anel: sem borda (a moldura já separa)
                  border: (!showStoryRing && !showCallRing && !hasFrame)
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                          width: 1.5,
                        )
                      : (showStoryRing || showCallRing)
                          ? Border.all(
                              color: context.nexusTheme.backgroundPrimary,
                              width: 2.5,
                            )
                          : null,
                ),
                child: ClipOval(
                  child: (widget.avatarUrl ?? '').isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.avatarUrl ?? '',
                          fit: BoxFit.cover,
                          width: widget.size,
                          height: widget.size,
                          memCacheWidth: (widget.size * 2).toInt(),
                          memCacheHeight: (widget.size * 2).toInt(),
                          placeholder: (ctx, __) => _avatarPlaceholder(ctx),
                          errorWidget: (ctx, __, ___) => _avatarPlaceholder(ctx),
                        )
                      : _avatarPlaceholder(context),
                ),
              ),
            ),

            // ── Frame decorativo (camada overlay, centralizado sobre o avatar) ──
            //
            // Para molduras animadas (GIF / WebP animado), usamos Image.network
            // diretamente porque o CachedNetworkImage pode armazenar apenas o
            // primeiro frame em cache, quebrando a animação. O Flutter renderiza
            // GIF e WebP animado nativamente sem dependências adicionais.
            //
            // Para molduras estáticas (PNG), usamos CachedNetworkImage para
            // melhor performance com cache em disco e memória.
            if (hasFrame)
              Center(
                child: IgnorePointer(
                  child: SizedBox(
                    width: frameSize,
                    height: frameSize,
                    child: widget.isFrameAnimated
                        ? Image.network(
                            widget.frameUrl ?? '',
                            fit: BoxFit.contain,
                            width: frameSize,
                            height: frameSize,
                            // gaplessPlayback evita piscar entre loops da animação
                            gaplessPlayback: true,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return const SizedBox.shrink();
                            },
                          )
                        : CachedNetworkImage(
                            imageUrl: widget.frameUrl ?? '',
                            fit: BoxFit.contain,
                            memCacheWidth: (frameSize * 2).toInt(),
                            memCacheHeight: (frameSize * 2).toInt(),
                            errorWidget: (_, __, ___) =>
                                const SizedBox.shrink(),
                            placeholder: (_, __) => const SizedBox.shrink(),
                          ),
                  ),
                ),
              ),

            // ── Badge de call ativa (ícone no canto inferior esquerdo) ──
            // Exibido quando o usuário está em call, independentemente de ter frame.
            // Posicionado no canto oposto ao badge Amino+ para não conflitar.
            if (widget.hasActiveCall)
              Positioned(
                bottom: hasFrame ? (frameSize - widget.size) / 2 - 2 : -2,
                left: hasFrame ? (frameSize - widget.size) / 2 - 2 : -2,
                child: AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) => Container(
                    width: widget.size * 0.32,
                    height: widget.size * 0.32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00E676), Color(0xFF1DE9B6)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: context.nexusTheme.backgroundPrimary, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E676)
                              .withValues(alpha: _glowAnimation.value * 0.6),
                          blurRadius: 4 + (_glowAnimation.value * 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.isScreeningRoom
                          ? Icons.cast_rounded
                          : Icons.mic_rounded,
                      size: widget.size * 0.18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            // ── Badge Amino+ (canto inferior direito do avatar) ──
            if (widget.showAminoPlus)
              Positioned(
                bottom: hasFrame ? (frameSize - widget.size) / 2 - 2 : -2,
                right: hasFrame ? (frameSize - widget.size) / 2 - 2 : -2,
                child: Container(
                  width: widget.size * 0.32,
                  height: widget.size * 0.32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: context.nexusTheme.backgroundPrimary, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: widget.size * 0.18,
                    color: Colors.white,
                  ),
                ),
              ),

            // ── Indicador Online (ponto verde, canto inferior direito) ──
            if (widget.showOnline && !widget.showAminoPlus)
              Positioned(
                bottom: hasFrame ? (frameSize - widget.size) / 2 : 0,
                right: hasFrame ? (frameSize - widget.size) / 2 : 0,
                child: Container(
                  width: widget.size * 0.25,
                  height: widget.size * 0.25,
                  decoration: BoxDecoration(
                    color: context.nexusTheme.onlineIndicator,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.nexusTheme.backgroundPrimary, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (widget.onTap != null) {
      return Semantics(
        label: s.profilePicture,
        button: true,
        child: innerWidget,
      );
    }
    return innerWidget;
  }

  Widget _avatarPlaceholder(BuildContext context) {
    return Container(
      color: context.surfaceColor,
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: widget.size * 0.45,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}
