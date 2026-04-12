import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Tela de gerenciamento de Links Gerais da comunidade.
/// Permite que líderes/agentes adicionem, editem, reordenem e removam
/// links customizáveis exibidos na seção "General" do drawer.
class CommunityGeneralLinksScreen extends ConsumerStatefulWidget {
  final String communityId;
  const CommunityGeneralLinksScreen({
    super.key,
    required this.communityId,
  });

  @override
  ConsumerState<CommunityGeneralLinksScreen> createState() =>
      _CommunityGeneralLinksScreenState();
}

class _CommunityGeneralLinksScreenState
    extends ConsumerState<CommunityGeneralLinksScreen> {
  List<Map<String, dynamic>> _links = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    setState(() => _isLoading = true);
    try {
      final res = await SupabaseService.table('community_general_links')
          .select()
          .eq('community_id', widget.communityId)
          .order('sort_order', ascending: true);
      if (mounted) {
        setState(() {
          _links = List<Map<String, dynamic>>.from(res as List? ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Erro ao carregar links. Tente novamente.');
      }
    }
  }

  Future<void> _addOrEditLink({Map<String, dynamic>? existing}) async {
    final s = getStrings();
    final titleCtrl =
        TextEditingController(text: existing?['title'] as String? ?? '');
    final urlCtrl =
        TextEditingController(text: existing?['url'] as String? ?? '');
    final isActive =
        ValueNotifier<bool>(existing?['is_active'] as bool? ?? true);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.nexusTheme.surfacePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          existing == null ? 'Adicionar Link' : 'Editar Link',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Título
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: s.title,
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.title_rounded,
                      color: context.nexusTheme.accentSecondary),
                ),
              ),
              const SizedBox(height: 12),
              // URL
              TextField(
                controller: urlCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'URL (https://...)',
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.link_rounded,
                      color: context.nexusTheme.accentSecondary),
                ),
              ),
              const SizedBox(height: 12),
              // Toggle ativo
              ValueListenableBuilder<bool>(
                valueListenable: isActive,
                builder: (_, active, __) => SwitchListTile(
                  value: active,
                  onChanged: (v) => isActive.value = v,
                  title: Text(s.active,
                      style: TextStyle(color: Colors.white70)),
                  activeColor: context.nexusTheme.accentSecondary,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel, style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty ||
                  urlCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                   SnackBar(
                    content: Text(s.fillTitleAndUrl),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.nexusTheme.accentSecondary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(s.save),
          ),
        ],
      ),
    );
    if (!mounted) return;

    if (result != true) return;

    setState(() => _isSaving = true);
    try {
      final data = {
        'community_id': widget.communityId,
        'title': titleCtrl.text.trim(),
        'url': urlCtrl.text.trim(),
        'is_active': isActive.value,
        'sort_order': existing?['sort_order'] as int? ?? _links.length,
      };

      if (existing == null) {
        await SupabaseService.table('community_general_links').insert(data);
      } else {
        await SupabaseService.table('community_general_links')
            .update(data)
            .eq('id', existing['id'] as String? ?? '');
      }
      await _loadLinks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(existing == null
                ? 'Link adicionado com sucesso!'
                : 'Link atualizado com sucesso!'),
            backgroundColor: context.nexusTheme.accentSecondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _showError('Erro ao salvar link. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteLink(Map<String, dynamic> link) async {
    final s = getStrings();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.nexusTheme.surfacePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Remover Link',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'Deseja remover o link "${link['title']}"?',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel, style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(s.remove),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    setState(() => _isSaving = true);
    try {
      await SupabaseService.table('community_general_links')
          .delete()
          .eq('id', link['id'] as String? ?? '');
      await _loadLinks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: Text(s.linkRemoved2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _showError('Erro ao remover link. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _reorderLinks(int oldIndex, int newIndex) async {
    HapticFeedback.mediumImpact();
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _links.removeAt(oldIndex);
      _links.insert(newIndex, item);
    });

    // Atualizar sort_order no banco
    try {
      for (int i = 0; i < _links.length; i++) {
        await SupabaseService.table('community_general_links').update(
            {'sort_order': i}).eq('id', _links[i]['id'] as String? ?? '');
      }
    } catch (e) {
      _showError('Erro ao reordenar. Tente novamente.');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.nexusTheme.surfacePrimary,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Links Gerais',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (_isSaving)
            Padding(
              padding: EdgeInsets.only(right: r.s(16)),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: context.nexusTheme.accentSecondary,
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: context.nexusTheme.accentSecondary))
          : Column(
              children: [
                // Cabeçalho informativo
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.all(r.s(16)),
                  padding: EdgeInsets.all(r.s(14)),
                  decoration: BoxDecoration(
                    color: context.nexusTheme.accentSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(r.s(12)),
                    border: Border.all(
                      color: context.nexusTheme.accentSecondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: context.nexusTheme.accentSecondary, size: r.s(18)),
                      SizedBox(width: r.s(10)),
                      Expanded(
                        child: Text(
                          s.linksInGeneralSection,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: r.fs(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Lista reordenável
                Expanded(
                  child: _links.isEmpty
                      ? _buildEmptyState(r)
                      : ReorderableListView.builder(
                          padding: EdgeInsets.only(
                            left: r.s(16),
                            right: r.s(16),
                            bottom: r.s(100),
                          ),
                          itemCount: _links.length,
                          onReorder: _reorderLinks,
                          itemBuilder: (context, index) {
                            final link = _links[index];
                            final isActive = link['is_active'] as bool? ?? true;
                            return _LinkTile(
                              key: ValueKey(link['id']),
                              link: link,
                              isActive: isActive,
                              onEdit: () => _addOrEditLink(existing: link),
                              onDelete: () => _deleteLink(link),
                              onToggle: () async {
                                setState(() {
                                  _links[index]['is_active'] = !isActive;
                                });
                                try {
                                  await SupabaseService.table(
                                          'community_general_links')
                                      .update({'is_active': !isActive}).eq(
                                          'id', link['id'] as String? ?? '');
                                } catch (e) {
                                  if (!mounted) return;
                                  setState(() {
                                    _links[index]['is_active'] = isActive;
                                  });
                                  _showError(
                                      'Erro ao atualizar. Tente novamente.');
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : () => _addOrEditLink(),
        backgroundColor: context.nexusTheme.accentSecondary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_link_rounded),
        label: const Text(
          'Adicionar Link',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Responsive r) {
    final s = getStrings();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.link_off_rounded, color: Colors.grey[700], size: r.s(64)),
          SizedBox(height: r.s(16)),
          Text(
            'Nenhum link adicionado',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: r.fs(16),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: r.s(8)),
          Text(
            s.addUsefulLinks,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: r.fs(13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Tile de link com drag handle, toggle, editar e deletar
// ─────────────────────────────────────────────────────────────────────────────

class _LinkTile extends ConsumerWidget {
  final Map<String, dynamic> link;
  final bool isActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _LinkTile({
    super.key,
    required this.link,
    required this.isActive,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    return Container(
      margin: EdgeInsets.only(bottom: r.s(8)),
      decoration: BoxDecoration(
        color: context.nexusTheme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(12)),
        border: Border.all(
          color: isActive
              ? context.nexusTheme.accentSecondary.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: ListTile(
        contentPadding:
            EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(4)),
        leading: ReorderableDragStartListener(
          index: 0,
          child: Icon(Icons.drag_handle_rounded,
              color: Colors.grey[600], size: r.s(22)),
        ),
        title: Text(
          link['title'] as String? ?? '',
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.w600,
            fontSize: r.fs(14),
          ),
        ),
        subtitle: Text(
          link['url'] as String? ?? '',
          style: TextStyle(
            color: isActive
                ? context.nexusTheme.accentSecondary.withValues(alpha: 0.8)
                : Colors.grey[700],
            fontSize: r.fs(11),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Toggle ativo/inativo
            GestureDetector(
              onTap: onToggle,
              child: Icon(
                isActive
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: isActive ? context.nexusTheme.accentSecondary : Colors.grey[700],
                size: r.s(20),
              ),
            ),
            SizedBox(width: r.s(8)),
            // Editar
            GestureDetector(
              onTap: onEdit,
              child: Icon(Icons.edit_rounded,
                  color: Colors.grey[400], size: r.s(20)),
            ),
            SizedBox(width: r.s(8)),
            // Deletar
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.delete_outline_rounded,
                  color: Colors.red[400], size: r.s(20)),
            ),
          ],
        ),
      ),
    );
  }
}
