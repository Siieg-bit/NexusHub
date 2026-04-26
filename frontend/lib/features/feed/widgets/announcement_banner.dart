import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// ── Provider ──────────────────────────────────────────────────────────────────
final systemAnnouncementsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final result =
      await SupabaseService.rpc('get_active_system_announcements', params: {});
  if (result == null) return [];
  return (result as List).map((e) => e as Map<String, dynamic>).toList();
});

// ── Widget ────────────────────────────────────────────────────────────────────

/// Banner de anúncios globais exibido no topo do GlobalFeedScreen.
/// Suporta múltiplos anúncios com PageView e indicadores de página.
/// O usuário pode dispensar cada anúncio (salvo em SharedPreferences).
class AnnouncementBanner extends ConsumerStatefulWidget {
  const AnnouncementBanner({super.key});

  @override
  ConsumerState<AnnouncementBanner> createState() =>
      _AnnouncementBannerState();
}

class _AnnouncementBannerState extends ConsumerState<AnnouncementBanner> {
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
    final list = prefs.getStringList('dismissed_announcements') ?? [];
    if (mounted) {
      setState(() {
        _dismissed = list.toSet();
        _loaded = true;
      });
    }
  }

  Future<void> _dismiss(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('dismissed_announcements') ?? [];
    list.add(id);
    await prefs.setStringList('dismissed_announcements', list);
    if (mounted) setState(() => _dismissed.add(id));
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final announcementsAsync = ref.watch(systemAnnouncementsProvider);
    return announcementsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (all) {
        final items =
            all.where((a) => !_dismissed.contains(a['id'])).toList();
        if (items.isEmpty) return const SizedBox.shrink();
        return _buildBanner(context, items);
      },
    );
  }

  Widget _buildBanner(
      BuildContext context, List<Map<String, dynamic>> items) {
    final r = context.r;
    final isNew = (Map<String, dynamic> a) {
      final publishAt = DateTime.tryParse(a['publish_at'] as String? ?? '');
      if (publishAt == null) return false;
      return DateTime.now().difference(publishAt).inHours < 24;
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: r.s(items.first['image_url'] != null ? 160 : 100),
          child: PageView.builder(
            controller: _pageController,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              final a = items[index];
              final hasImage = (a['image_url'] as String?)?.isNotEmpty == true;
              return _AnnouncementCard(
                announcement: a,
                isNew: isNew(a),
                hasImage: hasImage,
                onDismiss: () => _dismiss(a['id'] as String),
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
}

class _AnnouncementCard extends ConsumerWidget {
  final Map<String, dynamic> announcement;
  final bool isNew;
  final bool hasImage;
  final VoidCallback onDismiss;

  const _AnnouncementCard({
    required this.announcement,
    required this.isNew,
    required this.hasImage,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final title = announcement['title'] as String? ?? '';
    final body = announcement['body'] as String? ?? '';
    final imageUrl = announcement['image_url'] as String?;
    final ctaText = announcement['cta_text'] as String?;
    final ctaUrl = announcement['cta_url'] as String?;

    return GestureDetector(
      onTap: ctaUrl != null && ctaUrl.isNotEmpty
          ? () async {
              final uri = Uri.tryParse(ctaUrl);
              if (uri != null) await launchUrl(uri);
            }
          : null,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(6)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.nexusTheme.accentPrimary.withValues(alpha: 0.85),
              context.nexusTheme.accentSecondary.withValues(alpha: 0.75),
            ],
          ),
          borderRadius: BorderRadius.circular(r.s(16)),
          boxShadow: [
            BoxShadow(
              color: context.nexusTheme.accentPrimary.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r.s(16)),
          child: Stack(
            children: [
              // Imagem de fundo (se houver)
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
              // Conteúdo
              Padding(
                padding: EdgeInsets.all(r.s(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        if (isNew)
                          Container(
                            margin: EdgeInsets.only(right: r.s(6)),
                            padding: EdgeInsets.symmetric(
                                horizontal: r.s(6), vertical: r.s(2)),
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
                            title,
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
                      body,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: r.fs(12),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (ctaText != null && ctaText.isNotEmpty) ...[
                      SizedBox(height: r.s(8)),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.s(12), vertical: r.s(5)),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(r.s(8)),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          ctaText,
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
              // Botão X para dispensar
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
                    child: Icon(Icons.close_rounded,
                        color: Colors.white, size: r.s(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
