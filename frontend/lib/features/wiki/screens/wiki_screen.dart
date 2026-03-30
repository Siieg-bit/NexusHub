import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../../core/utils/responsive.dart';

// ============================================================================
// WIKI LIST SCREEN
// ============================================================================

/// Catálogo / Wiki — lista de entradas da wiki de uma comunidade.
class WikiListScreen extends StatefulWidget {
  final String communityId;
  const WikiListScreen({super.key, required this.communityId});

  @override
  State<WikiListScreen> createState() => _WikiListScreenState();
}

class _WikiListScreenState extends State<WikiListScreen> {
  List<Map<String, dynamic>> _entries = [];
  List<String> _categories = [];
  String? _selectedCategory;
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    try {
      final res = await SupabaseService.table('wiki_entries')
          .select('*, profiles(*)')
          .eq('community_id', widget.communityId)
          .eq('status', 'approved')
          .order('created_at', ascending: false);
      _entries = List<Map<String, dynamic>>.from(res as List?);

      final cats = <String>{};
      for (final e in _entries) {
        final cat = e['category'] as String?;
        if (cat != null && cat.isNotEmpty) cats.add(cat);
      }
      _categories = cats.toList()..sort();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredEntries {
    var list = _entries;
    if (_selectedCategory != null) {
      list = list.where((e) => e['category'] == _selectedCategory).toList();
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
    final r = context.r;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        elevation: 0,
        title: Text('Catálogo',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
                fontSize: r.fs(20))),
        actions: [
          // Botão de revisão para curadores/leaders
          GestureDetector(
            onTap: () =>
                context.push('/community/${widget.communityId}/wiki/review'),
            child: Container(
              margin: EdgeInsets.symmetric(vertical: r.s(8)),
              padding: EdgeInsets.symmetric(horizontal: r.s(10), vertical: r.s(8)),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(r.s(20)),
              ),
              child: Icon(Icons.pending_actions_rounded,
                  color: AppTheme.warningColor, size: r.s(20)),
            ),
          ),
          SizedBox(width: r.s(4)),
          GestureDetector(
            onTap: () =>
                context.push('/community/${widget.communityId}/wiki/create'),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
              padding: EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(8)),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(r.s(20)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.add_rounded, color: context.textPrimary),
            ),
          ),
        ],
        iconTheme: IconThemeData(color: context.textPrimary),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            )
          : RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: () async {
                await _loadEntries();
              },
              child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(r.s(16)),
                  child: TextField(
                    controller: _searchController,
                    if (!mounted) return;
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(color: context.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Buscar no catálogo...',
                      hintStyle: TextStyle(color: context.textSecondary),
                      prefixIcon: Icon(Icons.search_rounded, size: r.s(20), color: context.textSecondary),
                      filled: true,
                      fillColor: context.surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(r.s(16)),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: r.s(16), vertical: r.s(10)),
                    ),
                  ),
                ),
                if (_categories.isNotEmpty)
                  SizedBox(
                    height: r.s(40),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: r.s(16)),
                      children: [
                        _CategoryChip(
                          label: 'Todos',
                          isSelected: _selectedCategory == null,
                          if (!mounted) return;
                          onTap: () => setState(() => _selectedCategory = null),
                        ),
                        ..._categories.map((cat) => _CategoryChip(
                              label: cat,
                              isSelected: _selectedCategory == cat,
                              onTap: () =>
                                  if (!mounted) return;
                                  setState(() => _selectedCategory = cat),
                            )),
                      ],
                    ),
                  ),
                SizedBox(height: r.s(8)),
                Expanded(
                  child: _filteredEntries.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: r.s(100)),
                            Center(
                              child: Text('Nenhuma entrada encontrada',
                                  style: TextStyle(color: context.textSecondary)),
                            ),
                          ],
                        )
                      : GridView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.all(r.s(16)),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: _filteredEntries.length,
                          itemBuilder: (context, index) {
                            final entry = _filteredEntries[index];
                            return _WikiEntryCard(
                              entry: entry,
                              if (!mounted) return;
                              onTap: () => context.push('/wiki/${entry['id']}'),
                            );
                          },
                        ),
                ),
              ],
            ),
            ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(right: r.s(8)),
        padding: EdgeInsets.symmetric(horizontal: r.s(18), vertical: r.s(8)),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.15)
              : context.surfaceColor,
          borderRadius: BorderRadius.circular(r.s(24)),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : Colors.white.withValues(alpha: 0.05),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.primaryColor : context.textSecondary,
            fontSize: r.fs(13),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _WikiEntryCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onTap;

  const _WikiEntryCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final title = entry['title'] as String? ?? 'Sem título';
    final imageUrl = entry['cover_image_url'] as String?;
    final category = entry['category'] as String?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(r.s(16)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
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
              child: Container(
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
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
                          color: AppTheme.primaryColor,
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
                          color: context.textPrimary),
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

class WikiDetailScreen extends StatefulWidget {
  final String wikiId;
  const WikiDetailScreen({super.key, required this.wikiId});

  @override
  State<WikiDetailScreen> createState() => _WikiDetailScreenState();
}

class _WikiDetailScreenState extends State<WikiDetailScreen> {
  Map<String, dynamic>? _entry;
  bool _isLoading = true;
  int _userRating = 0;
  double _avgRating = 0;
  int _totalRatings = 0;
  bool _isPinnedToProfile = false;
  final _whatILikeController = TextEditingController();
  List<Map<String, dynamic>> _whatILikeList = [];

  @override
  void initState() {
    super.initState();
    _loadEntry();
  }

  Future<void> _loadEntry() async {
    try {
      final res = await SupabaseService.table('wiki_entries')
          .select('*, profiles(*)')
          .eq('id', widget.wikiId)
          .single();
      _entry = res;
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
            .select('*, profiles(nickname, icon_url)')
            .eq('wiki_entry_id', widget.wikiId)
            .order('created_at', ascending: false)
            .limit(20);
        _whatILikeList = List<Map<String, dynamic>>.from(likesRes as List?);
      } catch (e) {
        debugPrint('[wiki_screen] Erro: $e');
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePinToProfile() async {

      final r = context.r;
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      if (_isPinnedToProfile) {
        await SupabaseService.table('bookmarks')
            .delete()
            .eq('user_id', userId)
            .eq('wiki_id', widget.wikiId);
        if (mounted) {
          setState(() => _isPinnedToProfile = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Wiki removida do perfil'),
              backgroundColor: context.surfaceColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.s(12))),
            ),
          );
        }
      } else {
        await SupabaseService.table('bookmarks').insert({
          'user_id': userId,
          'wiki_id': widget.wikiId,
        });
        if (mounted) {
          setState(() => _isPinnedToProfile = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Wiki fixada no seu perfil!'),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.s(12))),
            ),
          );
        }
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
      // Reload to get updated average
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

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.scaffoldBg,
        body: Center(
            child: CircularProgressIndicator(
          color: AppTheme.primaryColor,
        )),
      );
    }

    if (_entry == null) {
      return Scaffold(
        backgroundColor: context.scaffoldBg,
        appBar: AppBar(
          backgroundColor: context.scaffoldBg,
          elevation: 0,
          iconTheme: IconThemeData(color: context.textPrimary),
        ),
        body: Center(
            child: Text('Entrada não encontrada',
                style: TextStyle(color: context.textSecondary))),
      );
    }

    final title = _entry!['title'] as String? ?? 'Sem título';
    final content = _entry!['content'] as String? ?? '';
    final coverUrl = _entry!['cover_image_url'] as String?;
    final category = _entry!['category'] as String?;
    final author = _entry!['profiles'] as Map<String, dynamic>?;
    final infoboxData = _entry!['infobox'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: context.scaffoldBg,
            expandedHeight: coverUrl != null ? 200 : 0,
            pinned: true,
            elevation: 0,
            iconTheme: IconThemeData(color: context.textPrimary),
            flexibleSpace: coverUrl != null
                ? FlexibleSpaceBar(
                    background: CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                    ),
                  )
                : null,
            title: Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: context.textPrimary)),
            actions: [
              // Pin to profile button
              GestureDetector(
                onTap: _togglePinToProfile,
                child: Container(
                  margin: EdgeInsets.only(right: r.s(12)),
                  padding: EdgeInsets.all(r.s(8)),
                  decoration: BoxDecoration(
                    color: _isPinnedToProfile
                        ? AppTheme.primaryColor.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPinnedToProfile
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    color: _isPinnedToProfile
                        ? AppTheme.primaryColor
                        : context.textPrimary,
                    size: r.s(20),
                  ),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(r.s(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (category != null)
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(14), vertical: r.s(6)),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(r.s(16)),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: r.fs(13),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  SizedBox(height: r.s(16)),
                  if (infoboxData != null && infoboxData.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(r.s(16)),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(r.s(16)),
                        border: Border.all(
                            color:
                                Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Informações',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: r.fs(16),
                                  color: context.textPrimary)),
                          SizedBox(height: r.s(8)),
                          ...infoboxData.entries.map((e) => Padding(
                                padding:
                                    EdgeInsets.symmetric(vertical: r.s(6)),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: r.s(110),
                                      child: Text(
                                        e.key,
                                        style: TextStyle(
                                            color: context.textSecondary,
                                            fontSize: r.fs(14)),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        e.value.toString(),
                                        style: TextStyle(
                                            fontSize: r.fs(14),
                                            color: context.textPrimary),
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
                        color: context.textPrimary),
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
                          'Por ${author['nickname'] ?? 'Anônimo'}',
                          style: TextStyle(
                              color: context.textSecondary, fontSize: r.fs(14)),
                        ),
                      ],
                    ),

                  // ── My Rating ──
                  SizedBox(height: r.s(24)),
                  Divider(color: Colors.white.withValues(alpha: 0.05)),
                  SizedBox(height: r.s(12)),
                  Text('Minha Avaliação',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: r.fs(18),
                          color: context.textPrimary)),
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
                              ? AppTheme.warningColor
                              : Colors.grey.withValues(alpha: 0.3),
                          size: r.s(34),
                          shadows: star <= _userRating
                              ? [
                                  BoxShadow(
                                    color: AppTheme.warningColor.withValues(alpha: 0.6),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: r.s(6)),
                  Text(
                    'Média: ${_avgRating.toStringAsFixed(1)} ($_totalRatings avaliações)',
                    style: TextStyle(
                        color: context.textSecondary, fontSize: r.fs(13)),
                  ),

                  // ── What I Like ──
                  SizedBox(height: r.s(24)),
                  Divider(color: Colors.white.withValues(alpha: 0.05)),
                  SizedBox(height: r.s(12)),
                  Text('O que eu gosto',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: r.fs(18),
                          color: context.textPrimary)),
                  SizedBox(height: r.s(8)),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _whatILikeController,
                          style: TextStyle(color: context.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Escreva o que você gosta...',
                            hintStyle: TextStyle(color: context.textSecondary),
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
                      SizedBox(width: r.s(12)),
                      GestureDetector(
                        onTap: _submitWhatILike,
                        child: Container(
                          padding: EdgeInsets.all(r.s(12)),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primaryColor, AppTheme.accentColor],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(r.s(24)),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(Icons.send_rounded,
                              color: context.textPrimary, size: r.s(24)),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: r.s(16)),
                  ..._whatILikeList.map((item) {
                    final profile = item['profiles'] as Map<String, dynamic>?;
                    return Container(
                      margin: EdgeInsets.only(bottom: r.s(12)),
                      padding: EdgeInsets.all(r.s(14)),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(r.s(16)),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.05),
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
                            avatarUrl: profile?['icon_url'] as String?,
                            size: r.s(32),
                          ),
                          SizedBox(width: r.s(12)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile?['nickname'] ?? 'Anônimo',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: r.fs(14),
                                      color: context.textPrimary),
                                ),
                                SizedBox(height: r.s(4)),
                                Text(
                                  item['content'] as String? ?? '',
                                  style: TextStyle(
                                      fontSize: r.fs(14), color: context.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CREATE WIKI SCREEN
// ============================================================================

class CreateWikiScreen extends StatefulWidget {
  final String communityId;
  const CreateWikiScreen({super.key, required this.communityId});

  @override
  State<CreateWikiScreen> createState() => _CreateWikiScreenState();
}

class _CreateWikiScreenState extends State<CreateWikiScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _categoryController = TextEditingController();
  final _coverUrlController = TextEditingController();
  final List<_InfoboxField> _infoboxFields = [];
  bool _isSubmitting = false;

  Future<void> _submit() async {

      final r = context.r;
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Título é obrigatório')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception('Não autenticado');

      final infobox = <String, dynamic>{};
      for (final f in _infoboxFields) {
        if (f.keyController.text.trim().isNotEmpty) {
          infobox[f.keyController.text.trim()] = f.valueController.text.trim();
        }
      }

      await SupabaseService.table('wiki_entries').insert({
        'community_id': widget.communityId,
        'author_id': userId,
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'category': _categoryController.text.trim().isNotEmpty
            ? _categoryController.text.trim()
            : null,
        'cover_image_url': _coverUrlController.text.trim().isNotEmpty
            ? _coverUrlController.text.trim()
            : null,
        'infobox': infobox.isNotEmpty ? infobox : null,
        'status': 'pending',
      });

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Entrada enviada para revisão dos curadores!'),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.s(12))),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ocorreu um erro. Tente novamente.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _categoryController.dispose();
    _coverUrlController.dispose();
    for (final f in _infoboxFields) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
        title: Text('Nova Entrada Wiki',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
                fontSize: r.fs(20))),
        actions: [
          GestureDetector(
            onTap: _isSubmitting ? null : _submit,
            child: Container(
              margin: EdgeInsets.only(right: r.s(12), top: r.s(8), bottom: r.s(8)),
              padding: EdgeInsets.symmetric(horizontal: r.s(18), vertical: r.s(10)),
              decoration: BoxDecoration(
                gradient: _isSubmitting
                    ? LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withValues(alpha: 0.5),
                          AppTheme.accentColor.withValues(alpha: 0.5)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [AppTheme.primaryColor, AppTheme.accentColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(r.s(24)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _isSubmitting
                  ? SizedBox(
                      width: r.s(18),
                      height: r.s(18),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: context.textPrimary),
                    )
                  : Text('Publicar',
                      style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: r.fs(16))),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(r.s(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _coverUrlController,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'URL da imagem de capa',
                hintStyle: TextStyle(color: context.textSecondary),
                prefixIcon: Icon(Icons.image_rounded,
                    size: r.s(20), color: context.textSecondary),
                filled: true,
                fillColor: context.surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(16)),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(12)),
              ),
            ),
            SizedBox(height: r.s(16)),
            TextField(
              controller: _categoryController,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'Categoria (ex: Personagens, Itens...)',
                hintStyle: TextStyle(color: context.textSecondary),
                prefixIcon: Icon(Icons.category_rounded,
                    size: r.s(20), color: context.textSecondary),
                filled: true,
                fillColor: context.surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(16)),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(12)),
              ),
            ),
            SizedBox(height: r.s(16)),
            TextField(
              controller: _titleController,
              style: TextStyle(
                  fontSize: r.fs(22),
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'Título da entrada...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: context.textSecondary),
              ),
            ),
            TextField(
              controller: _contentController,
              style: TextStyle(
                  fontSize: r.fs(16), height: 1.6, color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'Conteúdo detalhado...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: context.textSecondary),
              ),
              maxLines: null,
              minLines: 8,
            ),
            Divider(
              height: r.s(32),
              color: Colors.white.withValues(alpha: 0.05),
              thickness: 1,
            ),
            Row(
              children: [
                Text('Infobox',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: r.fs(18),
                        color: context.textPrimary)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() => _infoboxFields.add(_InfoboxField()));
                  },
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(8)),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(r.s(24)),
                      border: Border.all(color: AppTheme.primaryColor),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.add_rounded,
                            size: r.s(18), color: AppTheme.primaryColor),
                        SizedBox(width: r.s(6)),
                        Text('Campo',
                            style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: r.s(12)),
            ...List.generate(_infoboxFields.length, (i) {
              final f = _infoboxFields[i];
              return Padding(
                padding: EdgeInsets.only(bottom: r.s(12)),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: f.keyController,
                        style: TextStyle(color: context.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Campo',
                          hintStyle: TextStyle(color: context.textSecondary),
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
                    SizedBox(width: r.s(12)),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: f.valueController,
                        style: TextStyle(color: context.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Valor',
                          hintStyle: TextStyle(color: context.textSecondary),
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
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _infoboxFields[i].dispose();
                          _infoboxFields.removeAt(i);
                        });
                      },
                      child: Container(
                        margin: EdgeInsets.only(left: r.s(12)),
                        padding: EdgeInsets.all(r.s(6)),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.remove_circle_rounded,
                            color: AppTheme.errorColor, size: r.s(24)),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _InfoboxField {
  final TextEditingController keyController = TextEditingController();
  final TextEditingController valueController = TextEditingController();

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}
