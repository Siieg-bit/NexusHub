import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';

/// Tela para criação de novo post em uma comunidade.
class CreatePostScreen extends ConsumerStatefulWidget {
  final String communityId;

  const CreatePostScreen({super.key, required this.communityId});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagController = TextEditingController();
  String _postType = 'blog';
  final List<String> _tags = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _createPost() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escreva algo para publicar')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = SupabaseService.currentUserId!;
      await SupabaseService.table('posts').insert({
        'community_id': widget.communityId,
        'author_id': userId,
        'title': _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'type': _postType,
        'tags': _tags,
        'status': 'published',
      });

      // XP por criar post
      await SupabaseService.table('profiles')
          .update({'xp': SupabaseService.client.rpc('increment_xp', params: {'amount': 10})})
          .eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post publicado com sucesso!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao publicar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag) && _tags.length < 10) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Post'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createPost,
            child: _isLoading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Publicar',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tipo de post
            Row(
              children: [
                _PostTypeChip(
                  label: 'Blog',
                  icon: Icons.article_rounded,
                  isSelected: _postType == 'blog',
                  onTap: () => setState(() => _postType = 'blog'),
                ),
                const SizedBox(width: 8),
                _PostTypeChip(
                  label: 'Imagem',
                  icon: Icons.image_rounded,
                  isSelected: _postType == 'image',
                  onTap: () => setState(() => _postType = 'image'),
                ),
                const SizedBox(width: 8),
                _PostTypeChip(
                  label: 'Enquete',
                  icon: Icons.poll_rounded,
                  isSelected: _postType == 'poll',
                  onTap: () => setState(() => _postType = 'poll'),
                ),
                const SizedBox(width: 8),
                _PostTypeChip(
                  label: 'Quiz',
                  icon: Icons.quiz_rounded,
                  isSelected: _postType == 'quiz',
                  onTap: () => setState(() => _postType = 'quiz'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Título
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Título (opcional)',
                border: InputBorder.none,
                hintStyle: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textHint,
                ),
              ),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
            ),

            const Divider(color: AppTheme.dividerColor),

            // Conteúdo
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                hintText: 'Escreva seu post aqui...\n\nCompartilhe suas ideias, histórias, teorias ou qualquer coisa com a comunidade!',
                border: InputBorder.none,
                hintStyle: TextStyle(color: AppTheme.textHint, height: 1.5),
              ),
              style: const TextStyle(fontSize: 16, height: 1.6),
              maxLines: null,
              minLines: 10,
            ),

            const SizedBox(height: 16),

            // Tags
            Text('Tags', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      hintText: 'Adicionar tag...',
                      prefixIcon: Icon(Icons.tag_rounded, size: 18),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addTag,
                  icon: const Icon(Icons.add_circle_rounded, color: AppTheme.primaryColor),
                ),
              ],
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _tags.map((tag) => Chip(
                  label: Text('#$tag', style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => setState(() => _tags.remove(tag)),
                )).toList(),
              ),
            ],

            const SizedBox(height: 24),

            // Toolbar de mídia
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cardColorLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MediaButton(
                    icon: Icons.image_rounded,
                    label: 'Imagem',
                    onTap: () {/* TODO: Image picker */},
                  ),
                  _MediaButton(
                    icon: Icons.gif_box_rounded,
                    label: 'GIF',
                    onTap: () {/* TODO: GIF picker */},
                  ),
                  _MediaButton(
                    icon: Icons.videocam_rounded,
                    label: 'Vídeo',
                    onTap: () {/* TODO: Video picker */},
                  ),
                  _MediaButton(
                    icon: Icons.link_rounded,
                    label: 'Link',
                    onTap: () {/* TODO: Link embed */},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PostTypeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.2) : AppTheme.cardColorLight,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: AppTheme.primaryColor) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }
}

class _MediaButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MediaButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryLight, size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }
}
