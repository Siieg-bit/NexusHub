import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';

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
      _entries = List<Map<String, dynamic>>.from(res as List);

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
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        elevation: 0,
        title: const Text('Catálogo',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                fontSize: 20)),
        actions: [
          GestureDetector(
            onTap: () =>
                context.push('/community/${widget.communityId}/wiki/create'),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: AppTheme.textPrimary),
            ),
          ),
        ],
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Buscar no catálogo...',
                      hintStyle: TextStyle(color: AppTheme.textSecondary),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                if (_categories.isNotEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _CategoryChip(
                          label: 'Todos',
                          isSelected: _selectedCategory == null,
                          onTap: () => setState(() => _selectedCategory = null),
                        ),
                        ..._categories.map((cat) => _CategoryChip(
                              label: cat,
                              isSelected: _selectedCategory == cat,
                              onTap: () =>
                                  setState(() => _selectedCategory = cat),
                            )),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: _filteredEntries.isEmpty
                      ? Center(
                          child: Text('Nenhuma entrada encontrada',
                              style: TextStyle(color: AppTheme.textSecondary)),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
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
                              onTap: () => context.push('/wiki/${entry['id']}'),
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

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.15)
              : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(24),
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
            color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
            fontSize: 13,
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
    final title = entry['title'] as String? ?? 'Sem título';
    final imageUrl = entry['cover_image_url'] as String?;
    final category = entry['category'] as String?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
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
                    : const Center(
                        child: Icon(Icons.auto_stories_rounded,
                            color: Colors.grey, size: 36)),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (category != null)
                      Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.textPrimary),
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
        } catch (_) {}
      }

      // Load "What I Like" comments
      try {
        final likesRes = await SupabaseService.table('wiki_what_i_like')
            .select('*, profiles(nickname, icon_url)')
            .eq('wiki_entry_id', widget.wikiId)
            .order('created_at', ascending: false)
            .limit(20);
        _whatILikeList = List<Map<String, dynamic>>.from(likesRes as List);
      } catch (_) {}

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
      setState(() => _userRating = rating);
      // Reload to get updated average
      _loadEntry();
    } catch (_) {}
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
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        body: Center(
            child: CircularProgressIndicator(
          color: AppTheme.primaryColor,
        )),
      );
    }

    if (_entry == null) {
      return Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        appBar: AppBar(
          backgroundColor: AppTheme.scaffoldBg,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        ),
        body: Center(
            child: Text('Entrada não encontrada',
                style: TextStyle(color: AppTheme.textSecondary))),
      );
    }

    final title = _entry!['title'] as String? ?? 'Sem título';
    final content = _entry!['content'] as String? ?? '';
    final coverUrl = _entry!['cover_image_url'] as String?;
    final category = _entry!['category'] as String?;
    final author = _entry!['profiles'] as Map<String, dynamic>?;
    final infoboxData = _entry!['infobox'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppTheme.scaffoldBg,
            expandedHeight: coverUrl != null ? 200 : 0,
            pinned: true,
            elevation: 0,
            iconTheme: const IconThemeData(color: AppTheme.textPrimary),
            flexibleSpace: coverUrl != null
                ? FlexibleSpaceBar(
                    background: CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                    ),
                  )
                : null,
            title: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (infoboxData != null && infoboxData.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color:
                                Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Informações',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: AppTheme.textPrimary)),
                          const SizedBox(height: 8),
                          ...infoboxData.entries.map((e) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 110,
                                      child: Text(
                                        e.key,
                                        style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 14),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        e.value.toString(),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: AppTheme.textPrimary),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    content,
                    style: const TextStyle(
                        fontSize: 16,
                        height: 1.7,
                        color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 24),
                  if (author != null)
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: author['icon_url'] != null
                              ? CachedNetworkImageProvider(
                                  author['icon_url'] as String)
                              : null,
                          backgroundColor: AppTheme.surfaceColor,
                          child: author['icon_url'] == null
                              ? const Icon(Icons.person_rounded,
                                  size: 18, color: AppTheme.textSecondary)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Por ${author['nickname'] ?? 'Anônimo'}',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),

                  // ── My Rating ──
                  const SizedBox(height: 24),
                  Divider(color: Colors.white.withValues(alpha: 0.05)),
                  const SizedBox(height: 12),
                  Text('Minha Avaliação',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
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
                          size: 34,
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
                  const SizedBox(height: 6),
                  Text(
                    'Média: ${_avgRating.toStringAsFixed(1)} ($_totalRatings avaliações)',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),

                  // ── What I Like ──
                  const SizedBox(height: 24),
                  Divider(color: Colors.white.withValues(alpha: 0.05)),
                  const SizedBox(height: 12),
                  Text('O que eu gosto',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _whatILikeController,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Escreva o que você gosta...',
                            hintStyle: TextStyle(color: AppTheme.textSecondary),
                            filled: true,
                            fillColor: AppTheme.surfaceColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _submitWhatILike,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primaryColor, AppTheme.accentColor],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.send_rounded,
                              color: AppTheme.textPrimary, size: 24),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._whatILikeList.map((item) {
                    final profile = item['profiles'] as Map<String, dynamic>?;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
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
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppTheme.scaffoldBg,
                            backgroundImage: profile?['icon_url'] != null
                                ? CachedNetworkImageProvider(
                                    profile!['icon_url'] as String)
                                : null,
                            child: profile?['icon_url'] == null
                                ? const Icon(Icons.person,
                                    size: 16, color: AppTheme.textSecondary)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile?['nickname'] ?? 'Anônimo',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppTheme.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['content'] as String? ?? '',
                                  style: const TextStyle(
                                      fontSize: 14, color: AppTheme.textPrimary),
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
      });

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entrada criada com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
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
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        title: const Text('Nova Entrada Wiki',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                fontSize: 20)),
        actions: [
          GestureDetector(
            onTap: _isSubmitting ? null : _submit,
            child: Container(
              margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
                borderRadius: BorderRadius.circular(24),
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
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.textPrimary),
                    )
                  : const Text('Publicar',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _coverUrlController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'URL da imagem de capa',
                hintStyle: TextStyle(color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.image_rounded,
                    size: 20, color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _categoryController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Categoria (ex: Personagens, Itens...)',
                hintStyle: TextStyle(color: AppTheme.textSecondary),
                prefixIcon: const Icon(Icons.category_rounded,
                    size: 20, color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Título da entrada...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            TextField(
              controller: _contentController,
              style: const TextStyle(
                  fontSize: 16, height: 1.6, color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Conteúdo detalhado...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: AppTheme.textSecondary),
              ),
              maxLines: null,
              minLines: 8,
            ),
            Divider(
              height: 32,
              color: Colors.white.withValues(alpha: 0.05),
              thickness: 1,
            ),
            Row(
              children: [
                Text('Infobox',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppTheme.textPrimary)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() => _infoboxFields.add(_InfoboxField()));
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(24),
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
                      children: const [
                        Icon(Icons.add_rounded,
                            size: 18, color: AppTheme.primaryColor),
                        SizedBox(width: 6),
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
            const SizedBox(height: 12),
            ...List.generate(_infoboxFields.length, (i) {
              final f = _infoboxFields[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: f.keyController,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Campo',
                          hintStyle: TextStyle(color: AppTheme.textSecondary),
                          filled: true,
                          fillColor: AppTheme.surfaceColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: f.valueController,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Valor',
                          hintStyle: TextStyle(color: AppTheme.textSecondary),
                          filled: true,
                          fillColor: AppTheme.surfaceColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
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
                        margin: const EdgeInsets.only(left: 12),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.remove_circle_rounded,
                            color: AppTheme.errorColor, size: 24),
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
