import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../config/nexus_theme_extension.dart';
import '../../../core/models/community_model.dart';
import '../../../core/services/deep_link_service.dart';
import '../../../core/services/social_share_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

class _ShareCardVariant {
  static const String standard = 'standard';
  static const String story = 'story';
}

class CommunityShareCardSheet extends StatefulWidget {
  final CommunityModel community;

  const CommunityShareCardSheet({
    super.key,
    required this.community,
  });

  static Future<void> show(
    BuildContext context, {
    required CommunityModel community,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommunityShareCardSheet(community: community),
    );
  }

  @override
  State<CommunityShareCardSheet> createState() => _CommunityShareCardSheetState();
}

class _CommunityShareCardSheetState extends State<CommunityShareCardSheet> {
  final GlobalKey _cardKey = GlobalKey();
  late Future<String> _shareUrlFuture;
  late Future<Set<String>> _availableTargetsFuture;
  String _previewVariant = _ShareCardVariant.standard;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _shareUrlFuture = DeepLinkService.generateShareUrl(
      type: 'community',
      targetId: widget.community.id,
    );
    _availableTargetsFuture = SocialShareService.availableTargets();
  }

  String get _safeFileSlug {
    final raw = widget.community.endpoint ?? widget.community.name;
    final slug = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return slug.isEmpty ? widget.community.id : slug;
  }

  String _shareText(String shareUrl) {
    return 'Confira a comunidade ${widget.community.name} no NexusHub!\n$shareUrl';
  }


  Future<File> _captureCardAsPng({required String variant}) async {
    if (_previewVariant != variant && mounted) {
      setState(() => _previewVariant = variant);
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final boundary =
        _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('Preview de compartilhamento indisponível.');
    }

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Não foi possível gerar a imagem de preview.');
    }

    final bytes = byteData.buffer.asUint8List();
    return _writeTempShareImage(bytes);
  }

  Future<File> _writeTempShareImage(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/nexushub-community-$_safeFileSlug-${DateTime.now().millisecondsSinceEpoch}.png',
    );
    return file.writeAsBytes(bytes, flush: true);
  }

  Future<void> _share(
    String shareUrl, {
    required String target,
    required String channel,
  }) async {
    if (_isSharing) return;
    HapticFeedback.selectionClick();
    setState(() => _isSharing = true);
    try {
      final variant = target == SocialShareTarget.instagramStories
          ? _ShareCardVariant.story
          : _ShareCardVariant.standard;
      final imageFile = await _captureCardAsPng(variant: variant);
      final shareResult = await SocialShareService.shareCommunityCard(
        target: target,
        imageFile: imageFile,
        text: _shareText(shareUrl),
        url: shareUrl,
        subject: widget.community.name,
      );
      _trackShareEvent(
        target: target,
        usedNativeTarget: shareResult.usedNativeTarget,
        nativePackage: shareResult.nativePackage,
      );
      if (!mounted || shareResult.usedNativeTarget) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$channel não estava disponível. Abri o compartilhamento geral.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao compartilhar no $channel: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  void _trackShareEvent({
    required String target,
    required bool usedNativeTarget,
    String? nativePackage,
  }) {
    SupabaseService.rpc('track_share_event', params: {
      'p_content_type': 'community',
      'p_content_id': widget.community.id,
      'p_target': target,
      'p_native': usedNativeTarget,
      'p_package': nativePackage,
    }).catchError((e) {
      debugPrint('[CommunityShareCardSheet] share analytics skipped: $e');
    });
  }

  Future<void> _copyLink(String shareUrl) async {
    await Clipboard.setData(ClipboardData(text: shareUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copiado!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  Widget _buildSocialAction({
    required double width,
    required IconData icon,
    required String label,
    required Color color,
    required String target,
    required String channel,
    required String shareUrl,
    required bool nativeReady,
    required bool loadingAvailability,
  }) {
    return SizedBox(
      width: width,
      child: _ShareActionButton(
        icon: icon,
        label: label,
        color: color,
        enabled: !_isSharing,
        nativeReady: nativeReady,
        loadingAvailability: loadingAvailability,
        onTap: () => _share(
          shareUrl,
          target: target,
          channel: channel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return FutureBuilder<String>(
      future: _shareUrlFuture,
      builder: (context, snapshot) {
        final fallbackUrl = widget.community.link ??
            DeepLinkService.generateLink(
              type: 'community',
              id: widget.community.id,
            );
        final shareUrl = snapshot.data ?? fallbackUrl;
        final actionWidth =
            (MediaQuery.of(context).size.width - r.s(56)) / 2;

        return Container(
          decoration: BoxDecoration(
            color: theme.surfacePrimary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 32,
                offset: const Offset(0, -12),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            r.s(18),
            r.s(10),
            r.s(18),
            bottomPadding + r.s(18),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: r.s(42),
                    height: r.s(4),
                    margin: EdgeInsets.only(bottom: r.s(14)),
                    decoration: BoxDecoration(
                      color: theme.textHint.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Compartilhar comunidade',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: r.fs(19),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: theme.textSecondary),
                    ),
                  ],
                ),
                SizedBox(height: r.s(12)),
                Center(
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: _CommunitySharePreviewCard(
                      community: widget.community,
                      shareUrl: shareUrl,
                      variant: _previewVariant,
                    ),
                  ),
                ),
                SizedBox(height: r.s(16)),
                Text(
                  'Enviar com imagem e link',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: r.fs(12),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: r.s(10)),
                FutureBuilder<Set<String>>(
                  future: _availableTargetsFuture,
                  builder: (context, targetSnapshot) {
                    final availableTargets = targetSnapshot.data ?? const <String>{};
                    final isLoadingTargets =
                        targetSnapshot.connectionState == ConnectionState.waiting;
                    bool isNativeReady(String target) => availableTargets.contains(target);
                    return Wrap(
                      spacing: r.s(10),
                      runSpacing: r.s(10),
                      children: [
                        _buildSocialAction(
                          width: actionWidth,
                          icon: Icons.play_circle_fill_rounded,
                          label: 'Stories',
                          color: const Color(0xFFE1306C),
                          target: SocialShareTarget.instagramStories,
                          channel: 'Instagram Stories',
                          shareUrl: shareUrl,
                          nativeReady: isNativeReady(SocialShareTarget.instagramStories),
                          loadingAvailability: isLoadingTargets,
                        ),
                        _buildSocialAction(
                          width: actionWidth,
                          icon: Icons.camera_alt_rounded,
                          label: 'Instagram',
                          color: const Color(0xFFE1306C),
                          target: SocialShareTarget.instagramFeed,
                          channel: 'Instagram',
                          shareUrl: shareUrl,
                          nativeReady: isNativeReady(SocialShareTarget.instagramFeed),
                          loadingAvailability: isLoadingTargets,
                        ),
                        _buildSocialAction(
                          width: actionWidth,
                          icon: Icons.chat_rounded,
                          label: 'WhatsApp',
                          color: const Color(0xFF25D366),
                          target: SocialShareTarget.whatsapp,
                          channel: 'WhatsApp',
                          shareUrl: shareUrl,
                          nativeReady: isNativeReady(SocialShareTarget.whatsapp),
                          loadingAvailability: isLoadingTargets,
                        ),
                        _buildSocialAction(
                          width: actionWidth,
                          icon: Icons.send_rounded,
                          label: 'Telegram',
                          color: const Color(0xFF229ED9),
                          target: SocialShareTarget.telegram,
                          channel: 'Telegram',
                          shareUrl: shareUrl,
                          nativeReady: isNativeReady(SocialShareTarget.telegram),
                          loadingAvailability: isLoadingTargets,
                        ),
                        _buildSocialAction(
                          width: actionWidth,
                          icon: Icons.facebook_rounded,
                          label: 'Facebook',
                          color: const Color(0xFF1877F2),
                          target: SocialShareTarget.facebook,
                          channel: 'Facebook',
                          shareUrl: shareUrl,
                          nativeReady: isNativeReady(SocialShareTarget.facebook),
                          loadingAvailability: isLoadingTargets,
                        ),
                        _buildSocialAction(
                          width: actionWidth,
                          icon: Icons.forum_rounded,
                          label: 'Messenger',
                          color: const Color(0xFF0084FF),
                          target: SocialShareTarget.messenger,
                          channel: 'Messenger',
                          shareUrl: shareUrl,
                          nativeReady: isNativeReady(SocialShareTarget.messenger),
                          loadingAvailability: isLoadingTargets,
                        ),
                        _buildSocialAction(
                          width: actionWidth,
                          icon: Icons.alternate_email_rounded,
                          label: 'X / Twitter',
                          color: const Color(0xFF111111),
                          target: SocialShareTarget.twitter,
                          channel: 'X/Twitter',
                          shareUrl: shareUrl,
                          nativeReady: isNativeReady(SocialShareTarget.twitter),
                          loadingAvailability: isLoadingTargets,
                        ),
                        _buildSocialAction(
                          width: actionWidth,
                          icon: Icons.ios_share_rounded,
                          label: 'Mais apps',
                          color: theme.accentPrimary,
                          target: SocialShareTarget.more,
                          channel: 'outros apps',
                          shareUrl: shareUrl,
                          nativeReady: true,
                          loadingAvailability: false,
                        ),
                        SizedBox(
                          width: actionWidth,
                          child: _ShareActionButton(
                            icon: Icons.link_rounded,
                            label: 'Copiar link',
                            color: theme.textSecondary,
                            enabled: !_isSharing,
                            nativeReady: true,
                            loadingAvailability: false,
                            onTap: () => _copyLink(shareUrl),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                if (_isSharing) ...[
                  SizedBox(height: r.s(14)),
                  LinearProgressIndicator(
                    minHeight: r.s(3),
                    backgroundColor: theme.textHint.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(theme.accentPrimary),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CommunitySharePreviewCard extends StatelessWidget {
  final CommunityModel community;
  final String shareUrl;
  final String variant;

  const _CommunitySharePreviewCard({
    required this.community,
    required this.shareUrl,
    required this.variant,
  });

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF6C5CE7);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final accent = _parseColor(community.themeColor);
    final bannerUrl = community.bannerForContext('card') ?? community.bannerForContext('info');
    final tagline = community.tagline.trim().isNotEmpty
        ? community.tagline.trim()
        : community.description.trim();

    final isStory = variant == _ShareCardVariant.story;
    final cardWidth = isStory ? r.s(300) : r.s(330);
    final cardHeight = isStory ? r.s(533) : r.s(430);
    final heroGap = isStory ? r.s(96) : r.s(58);

    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r.s(28)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.98),
            const Color(0xFF111226),
            const Color(0xFF050509),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.25),
            blurRadius: r.s(28),
            offset: Offset(0, r.s(12)),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (bannerUrl != null && bannerUrl.isNotEmpty)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: bannerUrl,
                fit: BoxFit.cover,
                color: Colors.black.withValues(alpha: 0.50),
                colorBlendMode: BlendMode.darken,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.50),
                    Colors.black.withValues(alpha: 0.90),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(r.s(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CommunityAvatar(community: community, accent: accent),
                    SizedBox(width: r.s(14)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            community.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: r.fs(23),
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                          ),
                          SizedBox(height: r.s(6)),
                          Text(
                            '@${community.endpoint ?? (community.id.length <= 8 ? community.id : community.id.substring(0, 8))}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: r.fs(12),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: heroGap),
                Text(
                  tagline.isNotEmpty
                      ? tagline
                      : 'Entre nessa comunidade no NexusHub.',
                  maxLines: isStory ? 5 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: r.fs(15),
                    height: 1.28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: r.s(20)),
                Wrap(
                  spacing: r.s(8),
                  runSpacing: r.s(8),
                  children: [
                    _ShareMetricChip(
                      icon: Icons.people_alt_rounded,
                      label: '${community.membersCount} membros',
                    ),
                    if (!isStory)
                      _ShareMetricChip(
                        icon: Icons.article_rounded,
                        label: '${community.postsCount} posts',
                      ),
                    if (community.category.isNotEmpty)
                      _ShareMetricChip(
                        icon: Icons.auto_awesome_rounded,
                        label: community.category,
                      ),
                  ],
                ),
                SizedBox(height: r.s(24)),
                Container(
                  padding: EdgeInsets.all(r.s(12)),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(r.s(18)),
                  ),
                  child: Row(
                    children: [
                      QrImageView(
                        data: shareUrl,
                        version: QrVersions.auto,
                        size: r.s(72),
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.circle,
                          color: Color(0xFF101018),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.circle,
                          color: Color(0xFF101018),
                        ),
                      ),
                      SizedBox(width: r.s(12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Escaneie para entrar',
                              style: TextStyle(
                                color: const Color(0xFF101018),
                                fontSize: r.fs(13),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: r.s(4)),
                            Text(
                              shareUrl,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: const Color(0xFF101018).withValues(alpha: 0.62),
                                fontSize: r.fs(10),
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: r.s(16)),
                Center(
                  child: Text(
                    'NexusHub',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: r.fs(13),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityAvatar extends StatelessWidget {
  final CommunityModel community;
  final Color accent;

  const _CommunityAvatar({required this.community, required this.accent});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      width: r.s(72),
      height: r.s(72),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.82), width: r.s(3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: community.iconUrl != null && community.iconUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: community.iconUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _AvatarFallback(name: community.name),
            )
          : _AvatarFallback(name: community.name),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String name;

  const _AvatarFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final letter = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'N';
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: r.fs(28),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ShareMetricChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ShareMetricChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.s(10), vertical: r.s(7)),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: r.s(14), color: Colors.white.withValues(alpha: 0.86)),
          SizedBox(width: r.s(5)),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: r.fs(11),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final bool nativeReady;
  final bool loadingAvailability;
  final VoidCallback onTap;

  const _ShareActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.nativeReady,
    required this.loadingAvailability,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(r.s(16)),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: enabled ? 1.0 : 0.55,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: r.s(13), horizontal: r.s(12)),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(r.s(16)),
            border: Border.all(color: color.withValues(alpha: 0.32)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: r.s(18)),
              SizedBox(width: r.s(7)),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: r.fs(12),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: r.s(2)),
                    Text(
                      loadingAvailability
                          ? 'verificando'
                          : nativeReady
                              ? 'direto'
                              : 'fallback',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color.withValues(alpha: 0.68),
                        fontSize: r.fs(8.5),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
