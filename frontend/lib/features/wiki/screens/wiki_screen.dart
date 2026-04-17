import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/models/comment_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/deep_link_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../communities/providers/community_detail_providers.dart'
    as community_providers;
import '../../moderation/widgets/report_dialog.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// ============================================================================
// PROVIDER: comentários de wiki
// ============================================================================

final wikiCommentsProvider =
    FutureProvider.family<List<CommentModel>, (String, String)>(
        (ref, args) async {
  final (wikiId, communityId) = args;

  final response = await SupabaseService.table('comments')
      .select(
        '*, profiles!comments_author_id_fkey(id, nickname, icon_url, amino_id)',
      )
      .eq('wiki_id', wikiId)
      .eq('status', 'ok')
      .order('created_at', ascending: true);

  final maps = List<Map<String, dynamic>>.from(
    (response as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
  );

  // Enriquecer com dados do perfil local de comunidade quando disponível.
  if (communityId.isNotEmpty && maps.isNotEmpty) {
    try {
      final authorIds = maps
          .map((m) => m['author_id'] as String?)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (authorIds.isNotEmpty) {
        final memberships = await SupabaseService.table('community_members')
            .select('user_id, local_nickname, local_icon_url')
            .eq('community_id', communityId)
            .inFilter('user_id', authorIds);

        final memberMap = <String, Map<String, dynamic>>{
          for (final row in (memberships as List? ?? []))
            (row['user_id'] as String): Map<String, dynamic>.from(row as Map),
        };

        for (final map in maps) {
          final authorId = map['author_id'] as String?;
          if (authorId == null) continue;
          final membership = memberMap[authorId];
          if (membership == null) continue;
          final localNickname =
              (membership['local_nickname'] as String?)?.trim();
          final localIconUrl =
              (membership['local_icon_url'] as String?)?.trim();
          if (localNickname != null && localNickname.isNotEmpty) {
            map['local_nickname'] = localNickname;
          }
          if (localIconUrl != null && localIconUrl.isNotEmpty) {
            map['local_icon_url'] = localIconUrl;
          }
        }
      }
    } catch (e) {
      debugPrint('[wikiCommentsProvider] enrich error: $e');
    }
  }

  return maps.map((e) => CommentModel.fromJson(e)).toList();
});

// ============================================================================
// WIKI LIST SCREEN
// ============================================================================

/// Catálogo / Wiki — lista de entradas da wiki de uma comunidade.
class WikiListScreen extends ConsumerStatefulWidget {
  final String communityId;
  const WikiListScreen({super.key, required this.communityId});

  @override
  ConsumerState<WikiListScreen> createState() => _WikiListScreenState();
}

class _WikiListScreenState extends ConsumerState<WikiListScreen> {
  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _categoryList = []; // {id, name}
  String? _selectedCategoryId;
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    try {
      // Carregar categorias do banco
      final catRes = await SupabaseService.table('wiki_categories')
          .select('id, name')
          .eq('community_id', widget.communityId)
          .order('sort_order', ascending: true);
      _categoryList = List<Map<String, dynamic>>.from(catRes as List? ?? []);

      // Carregar entries com join na categoria
      final res = await SupabaseService.table('wiki_entries')
          .select('*, profiles!wiki_entries_author_id_fkey(*), wiki_categories(id, name)')
          .eq('community_id', widget.communityId)
          .eq('status', 'ok')
          .order('created_at', ascending: false);
      if (!mounted) return;
      _entries = List<Map<String, dynamic>>.from(res as List? ?? []);

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredEntries {
    var list = _entries;
    if (_selectedCategoryId != null) {
      list =
          list.where((e) => e['category_id'] == _selectedCategoryId).toList();
    }
    final search = _searchController.text.trim().toLowerCase();
    if (search.isNotEmpty) {
      list = list.where((e) {
        final title = (e['title'] as String? ?? '').toLowerCase();
        return title.contains(search);
      }).toList();
    }
    return list;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        elevation: 0,
        iconTheme: IconThemeData(color: context.nexusTheme.textPrimary),
        title: Text(s.wiki,
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: context.nexusTheme.textPrimary)),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: context.nexusTheme.textPrimary),
            onPressed: () =>
                context.push('/community/${widget.communityId}/wiki/create'),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                  color: context.nexusTheme.accentPrimary))
          : Column(
              children: [
                // ── Barra de busca ──
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(16), vertical: r.s(8)),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(color: context.nexusTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: s.searchWikiArticlesHint,
                      hintStyle:
                          TextStyle(color: context.nexusTheme.textSecondary),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: context.nexusTheme.textSecondary),
                      filled: true,
                      fillColor: context.surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(r.s(16)),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: r.s(16), vertical: r.s(12)),
                    ),
                  ),
                ),
                // ── Filtro de categorias ──
                if (_categoryList.isNotEmpty)
                  SizedBox(
                    height: r.s(44),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding:
                          EdgeInsets.symmetric(horizontal: r.s(12)),
                      children: [
                        _CategoryChip(
                          label: s.seeAll,
                          isSelected: _selectedCategoryId == null,
                          onTap: () =>
                              setState(() => _selectedCategoryId = null),
                        ),
                        ..._categoryList.map((cat) => _CategoryChip(
                              label: cat['name'] as String,
                              isSelected:
                                  _selectedCategoryId == cat['id'],
                              onTap: () => setState(
                                  () => _selectedCategoryId = cat['id']),
                            )),
                      ],
                    ),
                  ),
                // ── Grid de entradas ──
                Expanded(
                  child: _filteredEntries.isEmpty
                      ? Center(
                          child: Text(s.noWikiEntries,
                              style: TextStyle(
                                  color: context.nexusTheme.textSecondary)))
                      : GridView.builder(
                          padding: EdgeInsets.all(r.s(16)),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: r.s(12),
                            mainAxisSpacing: r.s(12),
                            childAspectRatio: 0.75,
                          ),
                          itemCount: _filteredEntries.length,
                          itemBuilder: (context, index) {
                            final entry = _filteredEntries[index];
                            return _WikiEntryCard(
                              entry: entry,
                              onTap: () => context.push(
                                '/community/${widget.communityId}/wiki/${entry['id']}',
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip(
      {required this.label,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(right: r.s(8)),
        padding:
            EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
        decoration: BoxDecoration(
          color: isSelected
              ? context.nexusTheme.accentPrimary
              : context.surfaceColor,
          borderRadius: BorderRadius.circular(r.s(20)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : context.nexusTheme.textSecondary,
            fontSize: r.fs(13),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _WikiEntryCard extends ConsumerWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onTap;

  const _WikiEntryCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final title = entry['title'] as String? ?? s.untitled;
    final imageUrl = entry['cover_image_url'] as String?;
    // Categoria vem do join wiki_categories(id, name)
    final catData = entry['wiki_categories'] as Map<String, dynamic>?;
    final category = catData?['name'] as String?;
    final isCanonical = entry['is_canonical'] == true;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(r.s(16)),
          border: isCanonical
              ? Border.all(
                  color: const Color(0xFFFFD700), // dourado
                  width: 2.5,
                )
              : Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [
            if (isCanonical)
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 3),
              )
            else
              BoxShadow(
                color: context.nexusTheme.accentPrimary.withValues(alpha: 0.1),
                blurRadius: 6,
                spreadRadius: 1,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      color: context.nexusTheme.accentPrimary
                          .withValues(alpha: 0.1),
                    ),
                    child: imageUrl != null
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16)),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          )
                        : Center(
                            child: Icon(Icons.auto_stories_rounded,
                                color: Colors.grey, size: r.s(36))),
                  ),
                  // Badge canônica
                  if (isCanonical)
                    Positioned(
                      top: r.s(6),
                      right: r.s(6),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.s(8), vertical: r.s(3)),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700),
                          borderRadius: BorderRadius.circular(r.s(10)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded,
                                color: Colors.black, size: r.s(11)),
                            SizedBox(width: r.s(3)),
                            Text(
                              s.wikiCanonicalBadge,
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: r.fs(9),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(r.s(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (category != null)
                      Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          color: isCanonical
                              ? const Color(0xFFFFD700)
                              : context.nexusTheme.accentPrimary,
                          fontSize: r.fs(10),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    SizedBox(height: r.s(4)),
                    Text(
                      title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: r.fs(14),
                          color: context.nexusTheme.textPrimary),
                      maxLines: 2,
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
  }
}

// ============================================================================
// WIKI DETAIL SCREEN
// ============================================================================

class WikiDetailScreen extends ConsumerStatefulWidget {
  final String wikiId;
  const WikiDetailScreen({super.key, required this.wikiId});

  @override
  ConsumerState<WikiDetailScreen> createState() => _WikiDetailScreenState();
}

class _WikiDetailScreenState extends ConsumerState<WikiDetailScreen> {
  Map<String, dynamic>? _entry;
  bool _isLoading = true;
  int _userRating = 0;
  double _avgRating = 0;
  int _totalRatings = 0;
  bool _isPinnedToProfile = false;
  final _whatILikeController = TextEditingController();
  List<Map<String, dynamic>> _whatILikeList = [];

  // Comentários
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  bool _isSendingComment = false;
  CommentModel? _replyingToComment;
  _CommentSortOrder _commentSortOrder = _CommentSortOrder.oldest;

  String get _communityId =>
      (_entry?['community_id'] as String?) ?? '';

  bool _isCommunityStaff({
    required bool isTeamMember,
    required String? userRole,
  }) {
    if (isTeamMember) return true;
    switch ((userRole ?? '').toLowerCase()) {
      case 'agent':
      case 'leader':
      case 'curator':
      case 'moderator':
      case 'admin':
        return true;
      default:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadEntry();
  }

  @override
  void dispose() {
    _whatILikeController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadEntry() async {
    try {
      final res = await SupabaseService.table('wiki_entries')
          .select('*, profiles!wiki_entries_author_id_fkey(*), wiki_categories(id, name)')
          .eq('id', widget.wikiId)
          .maybeSingle();
      if (res == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      // Enriquecer o author com dados do perfil local de comunidade
      final entry = Map<String, dynamic>.from(res as Map);
      final communityId = entry['community_id'] as String?;
      final authorId = entry['author_id'] as String?;
      if (communityId != null &&
          communityId.isNotEmpty &&
          authorId != null &&
          authorId.isNotEmpty) {
        try {
          final membership =
              await SupabaseService.table('community_members')
                  .select('local_nickname, local_icon_url')
                  .eq('community_id', communityId)
                  .eq('user_id', authorId)
                  .maybeSingle();
          if (membership != null) {
            final localNickname =
                (membership['local_nickname'] as String?)?.trim();
            final localIconUrl =
                (membership['local_icon_url'] as String?)?.trim();
            final profiles = entry['profiles'] as Map<String, dynamic>?;
            if (profiles != null) {
              final updated = Map<String, dynamic>.from(profiles);
              if (localNickname != null && localNickname.isNotEmpty) {
                updated['nickname'] = localNickname;
              }
              if (localIconUrl != null && localIconUrl.isNotEmpty) {
                updated['icon_url'] = localIconUrl;
              }
              entry['profiles'] = updated;
            }
          }
        } catch (_) {}
      }
      _entry = entry;
      _avgRating = (res['average_rating'] as num?)?.toDouble() ?? 0;
      _totalRatings = res['total_ratings'] as int? ?? 0;

      // Load user's own rating
      final userId = SupabaseService.currentUserId;
      if (userId != null) {
        try {
          final ratingRes = await SupabaseService.table('wiki_ratings')
              .select('rating')
              .eq('wiki_entry_id', widget.wikiId)
              .eq('user_id', userId)
              .maybeSingle();
          if (ratingRes != null) {
            _userRating = ratingRes['rating'] as int? ?? 0;
          }
        } catch (e) {
          debugPrint('[wiki_screen] Erro: $e');
        }
      }

      // Check if pinned/bookmarked to profile
      if (userId != null) {
        try {
          final pinRes = await SupabaseService.table('bookmarks')
              .select('id')
              .eq('user_id', userId)
              .eq('wiki_id', widget.wikiId)
              .maybeSingle();
          _isPinnedToProfile = pinRes != null;
        } catch (e) {
          debugPrint('[wiki_screen] Erro: $e');
        }
      }

      // Load "What I Like" comments
      try {
        final likesRes = await SupabaseService.table('wiki_what_i_like')
            .select('*')
            .eq('wiki_entry_id', widget.wikiId)
            .order('created_at', ascending: false)
            .limit(20);
        if (!mounted) return;
        final likesList =
            List<Map<String, dynamic>>.from(likesRes as List? ?? []);
        // Buscar perfis separadamente
        if (likesList.isNotEmpty) {
          final userIds =
              likesList.map((e) => e['user_id'] as String).toList();
          try {
            final profilesRes = await SupabaseService.table('profiles')
                .select('id, nickname, icon_url')
                .inFilter('id', userIds);
            final profilesMap = <String, Map<String, dynamic>>{
              for (final p in (profilesRes as List)
                  .map((e) => Map<String, dynamic>.from(e as Map)))
                p['id'] as String: p,
            };
            for (final like in likesList) {
              final uid = like['user_id'] as String?;
              if (uid != null && profilesMap.containsKey(uid)) {
                like['profiles'] = profilesMap[uid];
              }
            }
          } catch (_) {}
        }
        _whatILikeList = likesList;
      } catch (e) {
        debugPrint('[wiki_screen] Erro: $e');
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePinToProfile() async {
    final s = getStrings();
    final r = context.r;
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      final result = await SupabaseService.rpc('toggle_bookmark', params: {
        'p_user_id': userId,
        'p_wiki_id': widget.wikiId,
      });
      final isNowBookmarked =
          result is Map ? (result['bookmarked'] == true) : !_isPinnedToProfile;
      if (mounted) {
        setState(() => _isPinnedToProfile = isNowBookmarked);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNowBookmarked ? s.wikiPinned : s.wikiRemoved),
            backgroundColor: isNowBookmarked
                ? context.nexusTheme.accentPrimary
                : context.surfaceColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.s(12))),
          ),
        );
      }
    } catch (e) {
      debugPrint('[wiki_screen] Erro: $e');
    }
  }

  Future<void> _submitRating(int rating) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      await SupabaseService.table('wiki_ratings').upsert({
        'wiki_entry_id': widget.wikiId,
        'user_id': userId,
        'rating': rating,
      });
      if (!mounted) return;
      setState(() => _userRating = rating);
      _loadEntry();
    } catch (e) {
      debugPrint('[wiki_screen] Erro: $e');
    }
  }

  Future<void> _submitWhatILike() async {
    final text = _whatILikeController.text.trim();
    if (text.isEmpty) return;
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      await SupabaseService.table('wiki_what_i_like').insert({
        'wiki_entry_id': widget.wikiId,
        'user_id': userId,
        'content': text,
      });
      _whatILikeController.clear();
      _loadEntry();
    } catch (e) {
      debugPrint('[wiki_screen] Erro: $e');
    }
  }

  // ── Comentários ──────────────────────────────────────────────────────────

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    setState(() => _isSendingComment = true);
    try {
      await SupabaseService.rpc('create_comment_with_reputation', params: {
        'p_community_id': _communityId,
        'p_author_id': userId,
        'p_content': text,
        'p_wiki_id': widget.wikiId,
        'p_parent_id': _replyingToComment?.id,
      });
      _commentController.clear();
      if (mounted) {
        setState(() {
          _replyingToComment = null;
          _isSendingComment = false;
        });
        ref.invalidate(wikiCommentsProvider((widget.wikiId, _communityId)));
      }
    } catch (e) {
      debugPrint('[wiki_screen] Erro ao enviar comentário: $e');
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  Future<void> _deleteComment(CommentModel comment) async {
    final s = getStrings();
    final r = context.r;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.s(16))),
        title: Text(s.confirmDelete,
            style: TextStyle(color: context.nexusTheme.textPrimary)),
        content: Text(s.confirmDeleteMessage,
            style: TextStyle(color: context.nexusTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel,
                style:
                    TextStyle(color: context.nexusTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.delete,
                style: const TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SupabaseService.table('comments')
          .delete()
          .eq('id', comment.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.wikiCommentDeleted),
          behavior: SnackBarBehavior.floating,
        ));
        ref.invalidate(wikiCommentsProvider((widget.wikiId, _communityId)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.wikiCommentDeleteError),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── Moderação: ocultar/desocultar wiki ──────────────────────────────────

  Future<void> _toggleHideWiki({required bool currentlyHidden}) async {
    final s = getStrings();
    final r = context.r;
    final newStatus = currentlyHidden ? 'ok' : 'disabled';
    try {
      await SupabaseService.rpc('log_moderation_action', params: {
        'p_community_id': _communityId,
        'p_action': currentlyHidden ? 'unhide_wiki' : 'hide_wiki',
        'p_target_wiki_id': widget.wikiId,
        'p_reason': currentlyHidden ? 'Moderação: desocultar wiki' : 'Moderação: ocultar wiki',
      });
      await SupabaseService.table('wiki_entries')
          .update({'status': newStatus}).eq('id', widget.wikiId);
      if (mounted) {
        setState(() {
          _entry?['status'] = newStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(currentlyHidden ? s.wikiUnhidden : s.wikiHidden),
          backgroundColor: context.nexusTheme.accentPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(r.s(12))),
        ));
      }
    } catch (e) {
      debugPrint('[wiki_screen] Erro ao ocultar/desocultar wiki: $e');
    }
  }

  // ── Moderação: canonizar/descanonizar wiki ───────────────────────────────

  Future<void> _toggleCanonical({required bool currentlyCanonical}) async {
    final s = getStrings();
    final r = context.r;
    try {
      await SupabaseService.rpc('log_moderation_action', params: {
        'p_community_id': _communityId,
        'p_action': currentlyCanonical ? 'decanonize_wiki' : 'canonize_wiki',
        'p_target_wiki_id': widget.wikiId,
        'p_reason': currentlyCanonical
            ? 'Moderação: remover canonização'
            : 'Moderação: canonizar wiki',
      });
      await SupabaseService.table('wiki_entries')
          .update({'is_canonical': !currentlyCanonical}).eq('id', widget.wikiId);
      if (mounted) {
        setState(() {
          _entry?['is_canonical'] = !currentlyCanonical;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              currentlyCanonical ? s.wikiDecanonized : s.wikiCanonized),
          backgroundColor: currentlyCanonical
              ? context.surfaceColor
              : const Color(0xFFFFD700),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(r.s(12))),
        ));
      }
    } catch (e) {
      debugPrint('[wiki_screen] Erro ao canonizar/descanonizar wiki: $e');
    }
  }

  // ── Construção de árvore de comentários ─────────────────────────────────

  List<CommentModel> _buildCommentTree(List<CommentModel> comments) {
    final topLevel = <CommentModel>[];
    final byId = <String, CommentModel>{};
    for (final c in comments) {
      byId[c.id] = c;
    }
    for (final c in comments) {
      if (c.parentId == null) {
        topLevel.add(c);
      } else {
        final parent = byId[c.parentId!];
        if (parent != null) {
          parent.replies.add(c);
        } else {
          topLevel.add(c);
        }
      }
    }
    return topLevel;
  }

  List<CommentModel> _sortedComments(List<CommentModel> comments) {
    final sorted = List<CommentModel>.from(comments);
    switch (_commentSortOrder) {
      case _CommentSortOrder.mostRecent:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case _CommentSortOrder.oldest:
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case _CommentSortOrder.mostPopular:
        sorted.sort((a, b) => b.likesCount.compareTo(a.likesCount));
        break;
    }
    return sorted;
  }

  Widget _buildCommentsSheetBody({
    required BuildContext context,
    required AsyncValue<List<CommentModel>> commentsAsync,
    required bool canModerate,
    required UserModel? currentUser,
    required String? currentUserAvatar,
    required StateSetter setModalState,
  }) {
    final s = getStrings();
    final r = context.r;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(r.s(16), r.s(16), r.s(16), r.s(8)),
          child: Row(
            children: [
              Container(
                width: r.s(40),
                height: r.s(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(r.s(999)),
                ),
              ),
              const Spacer(),
              Text(
                s.comments,
                style: TextStyle(
                  fontSize: r.fs(16),
                  fontWeight: FontWeight.w800,
                  color: context.nexusTheme.textPrimary,
                ),
              ),
              const Spacer(),
              PopupMenuButton<_CommentSortOrder>(
                tooltip: s.sortBy,
                initialValue: _commentSortOrder,
                onSelected: (value) {
                  setState(() => _commentSortOrder = value);
                  setModalState(() {});
                },
                color: context.surfaceColor,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.s(14)),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _CommentSortOrder.mostRecent,
                    child: Text(s.mostRecent,
                        style: TextStyle(
                            color: context.nexusTheme.textPrimary)),
                  ),
                  PopupMenuItem(
                    value: _CommentSortOrder.oldest,
                    child: Text(s.oldest,
                        style: TextStyle(
                            color: context.nexusTheme.textPrimary)),
                  ),
                  PopupMenuItem(
                    value: _CommentSortOrder.mostPopular,
                    child: Text(s.mostPopular,
                        style: TextStyle(
                            color: context.nexusTheme.textPrimary)),
                  ),
                ],
              ),
            ],
          ),
        ),
        Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
        Expanded(
          child: commentsAsync.when(
            loading: () => Center(
              child: CircularProgressIndicator(
                color: context.nexusTheme.accentPrimary,
              ),
            ),
            error: (e, _) => Center(
              child: Text(
                s.anErrorOccurredTryAgain,
                style: TextStyle(color: context.nexusTheme.textSecondary),
              ),
            ),
            data: (comments) {
              final sorted = _sortedComments(comments);
              final tree = _buildCommentTree(sorted);
              if (tree.isEmpty) {
                return Center(
                  child: Text(
                    s.noComments,
                    style: TextStyle(
                      color: context.nexusTheme.textSecondary,
                    ),
                  ),
                );
              }
              return ListView(
                padding: EdgeInsets.fromLTRB(r.s(16), r.s(12), r.s(16), r.s(16)),
                children: tree
                    .map((c) => _WikiCommentTile(
                          comment: c,
                          communityId: _communityId,
                          canModerate: canModerate,
                          onReply: (comment) {
                            setState(() => _replyingToComment = comment);
                            setModalState(() {});
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _commentFocusNode.requestFocus();
                            });
                          },
                          onDelete: _deleteComment,
                        ))
                    .toList(),
              );
            },
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: context.nexusTheme.backgroundPrimary,
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
          padding: EdgeInsets.only(
            left: r.s(12),
            right: r.s(12),
            top: r.s(8),
            bottom: r.s(8) + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_replyingToComment != null)
                Container(
                  margin: EdgeInsets.only(bottom: r.s(6)),
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(12), vertical: r.s(6)),
                  decoration: BoxDecoration(
                    color: context.nexusTheme.accentPrimary
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(r.s(8)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.reply_rounded,
                          color: context.nexusTheme.accentPrimary,
                          size: r.s(16)),
                      SizedBox(width: r.s(6)),
                      Expanded(
                        child: Text(
                          '${s.reply}: ${_replyingToComment!.effectiveNickname(s.user)}',
                          style: TextStyle(
                            color: context.nexusTheme.accentPrimary,
                            fontSize: r.fs(12),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() => _replyingToComment = null);
                          setModalState(() {});
                        },
                        child: Icon(Icons.close_rounded,
                            color: Colors.grey[600], size: r.s(18)),
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CosmeticAvatar(
                    userId: currentUser?.id ?? SupabaseService.currentUserId ?? '',
                    avatarUrl: currentUserAvatar ?? currentUser?.iconUrl,
                    size: r.s(32),
                  ),
                  SizedBox(width: r.s(8)),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      style: TextStyle(
                          color: context.nexusTheme.textPrimary,
                          fontSize: r.fs(14)),
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: SupabaseService.currentUserId != null
                            ? s.saySomethingHint
                            : s.needLoginToComment,
                        hintStyle: TextStyle(
                            color: context.nexusTheme.textSecondary,
                            fontSize: r.fs(14)),
                        filled: true,
                        fillColor: context.surfaceColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(r.s(20)),
                          borderSide: BorderSide.none,
                        ),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: r.s(16), vertical: r.s(10)),
                      ),
                      enabled: SupabaseService.currentUserId != null,
                    ),
                  ),
                  SizedBox(width: r.s(8)),
                  GestureDetector(
                    onTap: _isSendingComment
                        ? null
                        : () async {
                            await _sendComment();
                            setModalState(() {});
                          },
                    child: Container(
                      padding: EdgeInsets.all(r.s(10)),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.nexusTheme.accentPrimary,
                            context.nexusTheme.accentSecondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: context.nexusTheme.accentPrimary
                                .withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _isSendingComment
                          ? SizedBox(
                              width: r.s(18),
                              height: r.s(18),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(Icons.send_rounded,
                              color: Colors.white, size: r.s(18)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openCommentsSheet({
    required bool canModerate,
    required UserModel? currentUser,
    required String? currentUserAvatar,
  }) async {
    final r = context.r;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.nexusTheme.backgroundPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(24))),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setModalState) => Consumer(
          builder: (sheetContext, ref, _) {
            final commentsAsync =
                ref.watch(wikiCommentsProvider((widget.wikiId, _communityId)));
            return SafeArea(
              top: false,
              child: SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.82,
                child: _buildCommentsSheetBody(
                  context: sheetContext,
                  commentsAsync: commentsAsync,
                  canModerate: canModerate,
                  currentUser: currentUser,
                  currentUserAvatar: currentUserAvatar,
                  setModalState: setModalState,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        body: Center(
            child: CircularProgressIndicator(
          color: context.nexusTheme.accentPrimary,
        )),
      );
    }

    if (_entry == null) {
      return Scaffold(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: context.nexusTheme.backgroundPrimary,
          elevation: 0,
          iconTheme: IconThemeData(color: context.nexusTheme.textPrimary),
        ),
        body: Center(
            child: Text(s.entryNotFound,
                style: TextStyle(color: context.nexusTheme.textSecondary))),
      );
    }

    final title = _entry?['title'] as String? ?? s.untitled;
    final content = _entry?['content'] as String? ?? '';
    final coverUrl = _entry?['cover_image_url'] as String?;
    final catData = _entry?['wiki_categories'] as Map<String, dynamic>?;
    final category = catData?['name'] as String?;
    final author = _entry?['profiles'] as Map<String, dynamic>?;
    final infoboxData = _entry?['infobox'] as Map<String, dynamic>?;
    final isCanonical = _entry?['is_canonical'] == true;
    final isHidden = (_entry?['status'] as String?) == 'disabled';

    // Verificar se o usuário é moderador
    final currentUser = ref.watch(currentUserProvider);
    final communityMembership = _communityId.isNotEmpty
        ? ref
            .watch(community_providers
                .communityMembershipProvider(_communityId))
            .valueOrNull
        : null;
    final currentUserRole = communityMembership?['role'] as String?;
    final canModerate = _isCommunityStaff(
      isTeamMember: currentUser?.isTeamMember ?? false,
      userRole: currentUserRole,
    );

    // Avatar do usuário logado
    final currentUserAvatar = _communityId.isNotEmpty
        ? ref
                .watch(communityLocalAvatarProvider(_communityId))
                .valueOrNull ??
            ref.watch(currentUserAvatarProvider)
        : ref.watch(currentUserAvatarProvider);

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: context.nexusTheme.backgroundPrimary,
                  expandedHeight: coverUrl != null ? 200 : 0,
                  pinned: true,
                  elevation: 0,
                  iconTheme:
                      IconThemeData(color: context.nexusTheme.textPrimary),
                  flexibleSpace: coverUrl != null
                      ? FlexibleSpaceBar(
                          background: CachedNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                          ),
                        )
                      : null,
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: context.nexusTheme.textPrimary)),
                      ),
                      // Badge canônica na AppBar
                      if (isCanonical)
                        Container(
                          margin: EdgeInsets.only(right: r.s(4)),
                          padding: EdgeInsets.symmetric(
                              horizontal: r.s(8), vertical: r.s(3)),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            borderRadius: BorderRadius.circular(r.s(10)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded,
                                  color: Colors.black, size: r.s(11)),
                              SizedBox(width: r.s(3)),
                              Text(
                                s.wikiCanonicalBadge,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: r.fs(9),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  actions: [
                    // Denunciar
                    if (SupabaseService.currentUserId != null)
                      GestureDetector(
                        onTap: () => ReportDialog.show(
                          context,
                          communityId: _communityId,
                          targetWikiId: widget.wikiId,
                        ),
                        child: Container(
                          margin: EdgeInsets.only(right: r.s(4)),
                          padding: EdgeInsets.all(r.s(8)),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.flag_outlined,
                              color: context.nexusTheme.textPrimary,
                              size: r.s(20)),
                        ),
                      ),
                    // Share
                    GestureDetector(
                      onTap: () => DeepLinkService.shareUrl(
                        type: 'wiki',
                        targetId: widget.wikiId,
                        title: title,
                        text: title,
                      ),
                      child: Container(
                        margin: EdgeInsets.only(right: r.s(4)),
                        padding: EdgeInsets.all(r.s(8)),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.share_outlined,
                            color: context.nexusTheme.textPrimary,
                            size: r.s(20)),
                      ),
                    ),
                    // Pin to profile button
                    GestureDetector(
                      onTap: _togglePinToProfile,
                      child: Container(
                        margin: EdgeInsets.only(right: r.s(4)),
                        padding: EdgeInsets.all(r.s(8)),
                        decoration: BoxDecoration(
                          color: _isPinnedToProfile
                              ? context.nexusTheme.accentPrimary
                                  .withValues(alpha: 0.2)
                              : Colors.black.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isPinnedToProfile
                              ? Icons.push_pin_rounded
                              : Icons.push_pin_outlined,
                          color: _isPinnedToProfile
                              ? context.nexusTheme.accentPrimary
                              : context.nexusTheme.textPrimary,
                          size: r.s(20),
                        ),
                      ),
                    ),
                    // Menu de moderação
                    if (canModerate)
                      PopupMenuButton<String>(
                        icon: Container(
                          margin: EdgeInsets.only(right: r.s(8)),
                          padding: EdgeInsets.all(r.s(8)),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.shield_outlined,
                              color: context.nexusTheme.textPrimary,
                              size: r.s(20)),
                        ),
                        color: context.surfaceColor,
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.s(14)),
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        onSelected: (value) {
                          if (value == 'hide') {
                            _toggleHideWiki(currentlyHidden: isHidden);
                          } else if (value == 'canonical') {
                            _toggleCanonical(
                                currentlyCanonical: isCanonical);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem<String>(
                            value: 'hide',
                            child: Row(
                              children: [
                                Icon(
                                  isHidden
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                  color: isHidden
                                      ? context.nexusTheme.accentPrimary
                                      : Colors.grey[500],
                                  size: r.s(18),
                                ),
                                SizedBox(width: r.s(10)),
                                Text(
                                  isHidden ? s.wikiUnhide : s.wikiHide,
                                  style: TextStyle(
                                      color: context.nexusTheme.textPrimary),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'canonical',
                            child: Row(
                              children: [
                                Icon(
                                  isCanonical
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: isCanonical
                                      ? const Color(0xFFFFD700)
                                      : Colors.grey[500],
                                  size: r.s(18),
                                ),
                                SizedBox(width: r.s(10)),
                                Text(
                                  isCanonical
                                      ? s.wikiDecanonize
                                      : s.wikiCanonize,
                                  style: TextStyle(
                                      color: context.nexusTheme.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(r.s(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Banner "Wiki oculta" para moderadores
                        if (isHidden)
                          Container(
                            width: double.infinity,
                            margin: EdgeInsets.only(bottom: r.s(12)),
                            padding: EdgeInsets.all(r.s(12)),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(r.s(12)),
                              border: Border.all(
                                  color: Colors.orange
                                      .withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.visibility_off_rounded,
                                    color: Colors.orange, size: r.s(18)),
                                SizedBox(width: r.s(8)),
                                Expanded(
                                  child: Text(
                                    s.wikiHidden,
                                    style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: r.fs(13),
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (category != null)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: r.s(14), vertical: r.s(6)),
                            decoration: BoxDecoration(
                              color: isCanonical
                                  ? const Color(0xFFFFD700)
                                      .withValues(alpha: 0.15)
                                  : context.nexusTheme.accentPrimary
                                      .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(r.s(16)),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                color: isCanonical
                                    ? const Color(0xFFFFD700)
                                    : context.nexusTheme.accentPrimary,
                                fontSize: r.fs(13),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        SizedBox(height: r.s(16)),
                        if (infoboxData != null &&
                            infoboxData.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(r.s(16)),
                            decoration: BoxDecoration(
                              color: context.surfaceColor,
                              borderRadius: BorderRadius.circular(r.s(16)),
                              border: Border.all(
                                  color: isCanonical
                                      ? const Color(0xFFFFD700)
                                          .withValues(alpha: 0.3)
                                      : Colors.white.withValues(alpha: 0.05)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.information,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: r.fs(16),
                                        color:
                                            context.nexusTheme.textPrimary)),
                                SizedBox(height: r.s(8)),
                                ...infoboxData.entries.map((e) => Padding(
                                      padding: EdgeInsets.symmetric(
                                          vertical: r.s(6)),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: r.s(110),
                                            child: Text(
                                              e.key,
                                              style: TextStyle(
                                                  color: context.nexusTheme
                                                      .textSecondary,
                                                  fontSize: r.fs(14)),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              e.value.toString(),
                                              style: TextStyle(
                                                  fontSize: r.fs(14),
                                                  color: context
                                                      .nexusTheme.textPrimary),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                              ],
                            ),
                          ),
                          SizedBox(height: r.s(16)),
                        ],
                        Text(
                          content,
                          style: TextStyle(
                              fontSize: r.fs(16),
                              height: 1.7,
                              color: context.nexusTheme.textPrimary),
                        ),
                        SizedBox(height: r.s(24)),
                        if (author != null)
                          Row(
                            children: [
                              CosmeticAvatar(
                                userId: author['id'] as String?,
                                avatarUrl: author['icon_url'] as String?,
                                size: r.s(36),
                              ),
                              SizedBox(width: r.s(10)),
                              Text(
                                '${s.byAuthor}${author['nickname'] ?? s.anonymous}',
                                style: TextStyle(
                                    color: context.nexusTheme.textSecondary,
                                    fontSize: r.fs(14)),
                              ),
                            ],
                          ),

                        // ── My Rating ──
                        SizedBox(height: r.s(24)),
                        Divider(
                            color: Colors.white.withValues(alpha: 0.05)),
                        SizedBox(height: r.s(12)),
                        Text(s.myRating,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: r.fs(18),
                                color: context.nexusTheme.textPrimary)),
                        SizedBox(height: r.s(8)),
                        Row(
                          children: List.generate(5, (i) {
                            final star = i + 1;
                            return GestureDetector(
                              onTap: () => _submitRating(star),
                              child: Icon(
                                star <= _userRating
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: star <= _userRating
                                    ? Colors.amber
                                    : Colors.grey.withValues(alpha: 0.3),
                                size: r.s(34),
                              ),
                            );
                          }),
                        ),
                        SizedBox(height: r.s(6)),
                        Text(
                          _totalRatings > 0
                              ? '${_avgRating.toStringAsFixed(1)} ★  ($_totalRatings ${_totalRatings == 1 ? 'avaliação' : 'avaliações'})'
                              : s.averageRating,
                          style: TextStyle(
                              color: _totalRatings > 0
                                  ? Colors.amber
                                  : context.nexusTheme.textSecondary,
                              fontSize: r.fs(13),
                              fontWeight: _totalRatings > 0
                                  ? FontWeight.w600
                                  : FontWeight.normal),
                        ),

                        // ── What I Like ──
                        SizedBox(height: r.s(24)),
                        Divider(
                            color: Colors.white.withValues(alpha: 0.05)),
                        SizedBox(height: r.s(12)),
                        Text(s.whatILike,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: r.fs(18),
                                color: context.nexusTheme.textPrimary)),
                        SizedBox(height: r.s(8)),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _whatILikeController,
                                style: TextStyle(
                                    color: context.nexusTheme.textPrimary),
                                decoration: InputDecoration(
                                  hintText: s.writeWhatYouLike,
                                  hintStyle: TextStyle(
                                      color:
                                          context.nexusTheme.textSecondary),
                                  filled: true,
                                  fillColor: context.surfaceColor,
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(r.s(16)),
                                    borderSide: BorderSide.none,
                                  ),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: r.s(16),
                                      vertical: r.s(12)),
                                ),
                              ),
                            ),
                            SizedBox(width: r.s(12)),
                            GestureDetector(
                              onTap: _submitWhatILike,
                              child: Container(
                                padding: EdgeInsets.all(r.s(12)),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      context.nexusTheme.accentPrimary,
                                      context.nexusTheme.accentSecondary
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(r.s(24)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.nexusTheme.accentPrimary
                                          .withValues(alpha: 0.5),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(Icons.send_rounded,
                                    color: context.nexusTheme.textPrimary,
                                    size: r.s(24)),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: r.s(16)),
                        ..._whatILikeList.map((item) {
                          final profile =
                              item['profiles'] as Map<String, dynamic>?;
                          return Container(
                            margin: EdgeInsets.only(bottom: r.s(12)),
                            padding: EdgeInsets.all(r.s(14)),
                            decoration: BoxDecoration(
                              color: context.surfaceColor,
                              borderRadius: BorderRadius.circular(r.s(16)),
                              border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.05)),
                              boxShadow: [
                                BoxShadow(
                                  color: context.nexusTheme.accentPrimary
                                      .withValues(alpha: 0.05),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CosmeticAvatar(
                                  userId: profile?['id'] as String?,
                                  avatarUrl:
                                      profile?['icon_url'] as String?,
                                  size: r.s(32),
                                ),
                                SizedBox(width: r.s(12)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        profile?['nickname'] ?? s.anonymous,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: r.fs(14),
                                            color: context
                                                .nexusTheme.textPrimary),
                                      ),
                                      SizedBox(height: r.s(4)),
                                      Text(
                                        item['content'] as String? ?? '',
                                        style: TextStyle(
                                            fontSize: r.fs(14),
                                            color: context
                                                .nexusTheme.textPrimary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        // ══════════════════════════════════════════════════
                        // COMENTÁRIOS EM MODAL (mesmo padrão de interação do blog)
                        // ══════════════════════════════════════════════════
                        SizedBox(height: r.s(24)),
                        Divider(
                            color: Colors.white.withValues(alpha: 0.05)),
                        SizedBox(height: r.s(12)),
                        GestureDetector(
                          onTap: () => _openCommentsSheet(
                            canModerate: canModerate,
                            currentUser: currentUser,
                            currentUserAvatar: currentUserAvatar,
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(r.s(16)),
                            decoration: BoxDecoration(
                              color: context.surfaceColor,
                              borderRadius: BorderRadius.circular(r.s(18)),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: r.s(44),
                                  height: r.s(44),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        context.nexusTheme.accentPrimary,
                                        context.nexusTheme.accentSecondary,
                                      ],
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(r.s(14)),
                                  ),
                                  child: Icon(Icons.forum_rounded,
                                      color: Colors.white, size: r.s(22)),
                                ),
                                SizedBox(width: r.s(12)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.comments,
                                        style: TextStyle(
                                          fontSize: r.fs(15),
                                          fontWeight: FontWeight.w800,
                                          color: context
                                              .nexusTheme.textPrimary,
                                        ),
                                      ),
                                      SizedBox(height: r.s(4)),
                                      Text(
                                        s.tapToView,
                                        style: TextStyle(
                                          fontSize: r.fs(13),
                                          color: context
                                              .nexusTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded,
                                    color: context.nexusTheme.textSecondary,
                                    size: r.s(24)),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: r.s(24)),
                      ],
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

// ============================================================================
// ENUM: ordenação de comentários
// ============================================================================

enum _CommentSortOrder { mostRecent, oldest, mostPopular }

// ============================================================================
// TILE DE COMENTÁRIO DA WIKI
// ============================================================================

class _WikiCommentTile extends ConsumerStatefulWidget {
  final CommentModel comment;
  final String communityId;
  final bool canModerate;
  final int depth;
  final ValueChanged<CommentModel>? onReply;
  final Future<void> Function(CommentModel comment)? onDelete;

  const _WikiCommentTile({
    required this.comment,
    required this.communityId,
    required this.canModerate,
    this.depth = 0,
    this.onReply,
    this.onDelete,
  });

  @override
  ConsumerState<_WikiCommentTile> createState() => _WikiCommentTileState();
}

class _WikiCommentTileState extends ConsumerState<_WikiCommentTile> {
  late bool _isLiked;
  late int _likesCount;

  @override
  void initState() {
    super.initState();
    _isLiked = false;
    _likesCount = widget.comment.likesCount;
    _checkIfLiked();
  }

  Future<void> _checkIfLiked() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      final res = await SupabaseService.table('likes')
          .select('id')
          .eq('user_id', userId)
          .eq('comment_id', widget.comment.id)
          .maybeSingle();
      if (mounted && res != null) {
        setState(() => _isLiked = true);
      }
    } catch (_) {}
  }

  Future<void> _toggleCommentLike() async {
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });
    try {
      await SupabaseService.rpc('toggle_like_with_reputation', params: {
        'p_community_id': widget.communityId,
        'p_user_id': SupabaseService.currentUserId,
        'p_comment_id': widget.comment.id,
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likesCount += _isLiked ? 1 : -1;
        });
      }
    }
  }

  Future<void> _handleMenuSelection(String value) async {
    final s = ref.read(stringsProvider);
    switch (value) {
      case 'reply':
        widget.onReply?.call(widget.comment);
        break;
      case 'copy':
        await Clipboard.setData(
            ClipboardData(text: widget.comment.content));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.wikiCommentCopied),
          behavior: SnackBarBehavior.floating,
        ));
        break;
      case 'delete':
        await widget.onDelete?.call(widget.comment);
        break;
      case 'report':
        if (!mounted) return;
        await ReportDialog.show(
          context,
          communityId: widget.communityId,
          targetCommentId: widget.comment.id,
        );
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final comment = widget.comment;
    final isOwner = SupabaseService.currentUserId == comment.authorId;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        r.s(16 + (widget.depth * 20)),
        r.s(8),
        r.s(16),
        r.s(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CosmeticAvatar(
                userId: comment.authorId,
                avatarUrl: comment.effectiveIconUrl,
                size: r.s(widget.depth > 0 ? 30 : 36),
                onTap: () => context.push(
                  widget.communityId.isNotEmpty
                      ? '/community/${widget.communityId}/profile/${comment.authorId}'
                      : '/user/${comment.authorId}',
                ),
              ),
              SizedBox(width: r.s(10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: r.s(8),
                            runSpacing: r.s(2),
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                comment.effectiveNickname(s.user),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: r.fs(14),
                                  color: context.nexusTheme.textPrimary,
                                ),
                              ),
                              Text(
                                timeago.format(comment.createdAt,
                                    locale: 'pt_BR'),
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: r.fs(11),
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          iconSize: r.s(18),
                          color: context.surfaceColor,
                          onSelected: _handleMenuSelection,
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              value: 'reply',
                              child: Text(s.reply,
                                  style: TextStyle(
                                      color:
                                          context.nexusTheme.textPrimary)),
                            ),
                            PopupMenuItem<String>(
                              value: 'copy',
                              child: Text(s.copy,
                                  style: TextStyle(
                                      color:
                                          context.nexusTheme.textPrimary)),
                            ),
                            if (isOwner || widget.canModerate)
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Text(s.delete,
                                    style: const TextStyle(
                                        color: Color(0xFFEF4444))),
                              ),
                            if (!isOwner)
                              PopupMenuItem<String>(
                                value: 'report',
                                child: Text(s.report,
                                    style: TextStyle(
                                        color: context
                                            .nexusTheme.textPrimary)),
                              ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: r.s(4)),
                    Text(
                      comment.content,
                      style: TextStyle(
                        fontSize: r.fs(14),
                        height: 1.4,
                        color: context.nexusTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: r.s(8)),
                    Row(
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(r.s(20)),
                            onTap: _toggleCommentLike,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: r.s(4),
                                vertical: r.s(2),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isLiked
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    size: r.s(15),
                                    color: _isLiked
                                        ? const Color(0xFFEF4444)
                                        : Colors.grey[500],
                                  ),
                                  SizedBox(width: r.s(4)),
                                  Text(
                                    '$_likesCount',
                                    style: TextStyle(
                                      color: _isLiked
                                          ? const Color(0xFFEF4444)
                                          : Colors.grey[500],
                                      fontSize: r.fs(12),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: r.s(12)),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(r.s(20)),
                            onTap: () =>
                                widget.onReply?.call(comment),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: r.s(4),
                                vertical: r.s(2),
                              ),
                              child: Text(
                                s.reply,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: r.fs(12),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comment.replies.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: r.s(4)),
              child: Column(
                children: comment.replies
                    .map(
                      (reply) => _WikiCommentTile(
                        comment: reply,
                        communityId: widget.communityId,
                        canModerate: widget.canModerate,
                        depth: widget.depth + 1,
                        onReply: widget.onReply,
                        onDelete: widget.onDelete,
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
