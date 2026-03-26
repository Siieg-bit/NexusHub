import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';

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
      appBar: AppBar(
        title: const Text('Catálogo',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () =>
                context.push('/community/${widget.communityId}/wiki/create'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Buscar no catálogo...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      filled: true,
                      fillColor: AppTheme.cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                if (_categories.isNotEmpty)
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _CategoryChip(
                          label: 'Todos',
                          isSelected: _selectedCategory == null,
                          onTap: () =>
                              setState(() => _selectedCategory = null),
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
                      ? const Center(
                          child: Text('Nenhuma entrada encontrada',
                              style:
                                  TextStyle(color: AppTheme.textSecondary)),
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
                              onTap: () =>
                                  context.push('/wiki/${entry['id']}'),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.15)
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.dividerColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  color: AppTheme.primaryColor.withOpacity(0.1),
                ),
                child: imageUrl != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12)),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.auto_stories_rounded,
                            color: AppTheme.textHint, size: 36)),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (category != null)
                      Text(
                        category.toUpperCase(),
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
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
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_entry == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Entrada não encontrada')),
      );
    }

    final title = _entry!['title'] as String? ?? 'Sem título';
    final content = _entry!['content'] as String? ?? '';
    final coverUrl = _entry!['cover_image_url'] as String?;
    final category = _entry!['category'] as String?;
    final author = _entry!['profiles'] as Map<String, dynamic>?;
    final infoboxData = _entry!['infobox'] as Map<String, dynamic>?;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: coverUrl != null ? 200 : 0,
            pinned: true,
            flexibleSpace: coverUrl != null
                ? FlexibleSpaceBar(
                    background: CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                    ),
                  )
                : null,
            title: Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
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
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (infoboxData != null && infoboxData.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.dividerColor.withOpacity(0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Informações',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 8),
                          ...infoboxData.entries.map((e) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        e.key,
                                        style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 13),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        e.value.toString(),
                                        style: const TextStyle(fontSize: 13),
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
                        fontSize: 15, height: 1.7, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 24),
                  if (author != null)
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: author['avatar_url'] != null
                              ? CachedNetworkImageProvider(
                                  author['avatar_url'] as String)
                              : null,
                          child: author['avatar_url'] == null
                              ? const Icon(Icons.person_rounded, size: 16)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Por ${author['nickname'] ?? 'Anônimo'}',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
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
      appBar: AppBar(
        title: const Text('Nova Entrada Wiki',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Publicar'),
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
              decoration: const InputDecoration(
                hintText: 'URL da imagem de capa',
                prefixIcon: Icon(Icons.image_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                hintText: 'Categoria (ex: Personagens, Itens...)',
                prefixIcon: Icon(Icons.category_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Título da entrada...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: AppTheme.textHint),
              ),
            ),
            TextField(
              controller: _contentController,
              style: const TextStyle(fontSize: 15, height: 1.6),
              decoration: const InputDecoration(
                hintText: 'Conteúdo detalhado...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: AppTheme.textHint),
              ),
              maxLines: null,
              minLines: 8,
            ),
            const Divider(height: 32),
            Row(
              children: [
                Text('Infobox',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _infoboxFields.add(_InfoboxField()));
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Campo'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(_infoboxFields.length, (i) {
              final f = _infoboxFields[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: f.keyController,
                        decoration: const InputDecoration(
                          hintText: 'Campo',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: f.valueController,
                        decoration: const InputDecoration(
                          hintText: 'Valor',
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_rounded,
                          color: AppTheme.errorColor, size: 20),
                      onPressed: () {
                        setState(() {
                          _infoboxFields[i].dispose();
                          _infoboxFields.removeAt(i);
                        });
                      },
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
