import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/responsive.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../models/system_announcement.dart';
import '../providers/announcements_provider.dart';

/// Banner de anúncios globais exibido no topo do GlobalFeedScreen.
///
/// Os conteúdos são carregados remotamente por RPC, com fallback local vazio,
/// feature flag de rollback e persistência local de anúncios dispensados.
class AnnouncementBanner extends ConsumerStatefulWidget {
  const AnnouncementBanner({super.key});

  @override
  ConsumerState<AnnouncementBanner> createState() =>
      _AnnouncementBannerState();
}

class _AnnouncementBannerState extends ConsumerState<AnnouncementBanner> {
  static const String _dismissedKey = 'dismissed_announcements';

  Set<String> _dismissed = {};
  bool _loaded = false;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadDismissed();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_dismissedKey) ?? const [];
    if (mounted) {
      setState(() {
        _dismissed = list.toSet();
        _loaded = true;
      });
    }
  }

  Future<void> _dismiss(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final next = {..._dismissed, id};
    await prefs.setStringList(_dismissedKey, next.toList());
    if (mounted) setState(() => _dismissed = next);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    final announcementsAsync = ref.watch(activeAnnouncementsProvider);
    return announcementsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (all) {
        final items = all.where((a) => !_dismissed.contains(a.id)).toList();
        if (items.isEmpty) return const SizedBox.shrink();
        return _buildBanner(context, items);
      },
    );
  }

  Widget _buildBanner(BuildContext context, List<SystemAnnouncement> items) {
    final r = context.r;
    final hasAnyImage = items.any((a) => a.imageUrl?.isNotEmpty == true);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: r.s(hasAnyImage ? 160 : 108),
          child: PageView.builder(
            controller: _pageController,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              final announcement = items[index];
              return _AnnouncementCard(
                announcement: announcement,
                isNew: _isNew(announcement),
                onDismiss: announcement.dismissible
                    ? () => _dismiss(announcement.id)
                    : null,
              );
            },
          ),
        ),
        if (items.length > 1)
          Padding(
            padding: EdgeInsets.only(top: r.s(6), bottom: r.s(2)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                items.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: EdgeInsets.symmetric(horizontal: r.s(3)),
                  width: _currentPage == i ? r.s(16) : r.s(6),
                  height: r.s(6),
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? context.nexusTheme.accentPrimary
                        : Colors.grey[600],
                    borderRadius: BorderRadius.circular(r.s(3)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  bool _isNew(SystemAnnouncement announcement) {
    final publishAt = announcement.publishAt;
    if (publishAt == null) return false;
    return DateTime.now().difference(publishAt).inHours < 24;
  }
}

class _AnnouncementCard extends ConsumerWidget {
  const _AnnouncementCard({
    required this.announcement,
    required this.isNew,
    required this.onDismiss,
  });

  final SystemAnnouncement announcement;
  final bool isNew;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final severityStyle = _severityStyle(context, announcement.severity);
    final imageUrl = announcement.imageUrl;
    final hasImage = imageUrl?.isNotEmpty == true;

    return GestureDetector(
      onTap: announcement.ctaUrl != null
          ? () async {
              final uri = Uri.tryParse(announcement.ctaUrl!);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          : null,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(6)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: severityStyle.gradientColors,
          ),
          borderRadius: BorderRadius.circular(r.s(16)),
          boxShadow: [
            BoxShadow(
              color: severityStyle.shadowColor,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r.s(16)),
          child: Stack(
            children: [
              if (hasImage && imageUrl != null)
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    color: Colors.black.withValues(alpha: 0.45),
                    colorBlendMode: BlendMode.darken,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(r.s(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(
                          severityStyle.icon,
                          color: Colors.white,
                          size: r.s(16),
                        ),
                        SizedBox(width: r.s(6)),
                        if (isNew)
                          Container(
                            margin: EdgeInsets.only(right: r.s(6)),
                            padding: EdgeInsets.symmetric(
                              horizontal: r.s(6),
                              vertical: r.s(2),
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(r.s(6)),
                            ),
                            child: Text(
                              'NOVO',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: r.fs(9),
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            announcement.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: r.fs(15),
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: r.s(4)),
                    Text(
                      announcement.body,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: r.fs(12),
                      ),
                      maxLines: announcement.hasCta ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (announcement.hasCta) ...[
                      SizedBox(height: r.s(8)),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: r.s(12),
                          vertical: r.s(5),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(r.s(8)),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          announcement.ctaText!,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: r.fs(12),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onDismiss != null)
                Positioned(
                  top: r.s(6),
                  right: r.s(6),
                  child: GestureDetector(
                    onTap: onDismiss,
                    child: Container(
                      padding: EdgeInsets.all(r.s(4)),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: r.s(14),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  _AnnouncementSeverityStyle _severityStyle(
    BuildContext context,
    String severity,
  ) {
    switch (severity.toLowerCase().trim()) {
      case 'critical':
        return _AnnouncementSeverityStyle(
          icon: Icons.error_rounded,
          gradientColors: [
            Colors.red.shade800.withValues(alpha: 0.9),
            Colors.deepOrange.shade700.withValues(alpha: 0.82),
          ],
          shadowColor: Colors.red.shade700.withValues(alpha: 0.3),
        );
      case 'warning':
        return _AnnouncementSeverityStyle(
          icon: Icons.warning_amber_rounded,
          gradientColors: [
            Colors.orange.shade700.withValues(alpha: 0.9),
            Colors.amber.shade700.withValues(alpha: 0.78),
          ],
          shadowColor: Colors.orange.shade700.withValues(alpha: 0.28),
        );
      case 'info':
      default:
        return _AnnouncementSeverityStyle(
          icon: Icons.info_outline_rounded,
          gradientColors: [
            context.nexusTheme.accentPrimary.withValues(alpha: 0.85),
            context.nexusTheme.accentSecondary.withValues(alpha: 0.75),
          ],
          shadowColor: context.nexusTheme.accentPrimary.withValues(alpha: 0.25),
        );
    }
  }
}

class _AnnouncementSeverityStyle {
  const _AnnouncementSeverityStyle({
    required this.icon,
    required this.gradientColors,
    required this.shadowColor,
  });

  final IconData icon;
  final List<Color> gradientColors;
  final Color shadowColor;
}
