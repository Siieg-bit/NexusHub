import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

// =============================================================================
// PINNED WIKIS SECTION — Wikis fixadas no perfil (via bookmarks.wiki_id)
// =============================================================================

class ProfilePinnedWikis extends StatefulWidget {
  final String userId;
  const ProfilePinnedWikis({super.key, required this.userId});

  @override
  State<ProfilePinnedWikis> createState() => _ProfilePinnedWikisState();
}

class _ProfilePinnedWikisState extends State<ProfilePinnedWikis> {
  List<Map<String, dynamic>> _pinnedWikis = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPinnedWikis();
  }

  Future<void> _loadPinnedWikis() async {
    try {
      final res = await SupabaseService.table('bookmarks')
          .select(
              'wiki_id, wiki_entries!bookmarks_wiki_id_fkey(id, title, cover_image_url, category)')
          .eq('user_id', widget.userId)
          .not('wiki_id', 'is', null)
          .order('created_at', ascending: false)
          .limit(10);
      if (!mounted) return;
      final list = (res as List? ?? [])
          .where((e) => e['wiki_entries'] != null)
          .toList();
      if (mounted) {
        setState(() {
          _pinnedWikis = List<Map<String, dynamic>>.from(list);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    if (_isLoading) return const SizedBox.shrink();
    if (_pinnedWikis.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(r.s(16), r.s(8), r.s(16), r.s(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.push_pin_rounded,
                  size: r.s(14), color: AppTheme.primaryColor),
              SizedBox(width: r.s(6)),
              Text(
                'Wikis Fixadas',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: r.fs(13),
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
          SizedBox(height: r.s(10)),
          SizedBox(
            height: r.s(100),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _pinnedWikis.length,
              separatorBuilder: (_, __) => SizedBox(width: r.s(12)),
              itemBuilder: (context, index) {
                final bookmark = _pinnedWikis[index];
                final wiki =
                    bookmark['wiki_entries'] as Map<String, dynamic>;
                final title = wiki['title'] as String? ?? 'Wiki';
                final coverUrl = wiki['cover_image_url'] as String?;
                final category = wiki['category'] as String?;
                final wikiId = wiki['id'] as String?;

                return GestureDetector(
                  onTap: () => context.push('/wiki/$wikiId'),
                  child: Container(
                    width: r.s(140),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(r.s(12)),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cover
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                          child: coverUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: coverUrl,
                                  height: r.s(50),
                                  width: r.s(140),
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => _coverPlaceholder(r),
                                )
                              : _coverPlaceholder(r),
                        ),
                        // Title + category
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: r.s(8), vertical: r.s(6)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: r.fs(11),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (category != null && category.isNotEmpty)
                                  Text(
                                    category,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: r.fs(9),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverPlaceholder(Responsive r) {
    return Container(
      height: r.s(50),
      width: r.s(140),
      color: AppTheme.primaryColor.withValues(alpha: 0.15),
      child: Center(
        child: Icon(Icons.auto_stories_rounded,
            color: AppTheme.primaryColor, size: r.s(20)),
      ),
    );
  }
}
