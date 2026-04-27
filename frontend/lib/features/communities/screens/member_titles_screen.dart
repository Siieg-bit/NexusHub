import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/nexus_loading_button.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// ── Providers ─────────────────────────────────────────────────────────────────
final communityTitlesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, communityId) async {
  final result = await SupabaseService.client
      .from('community_member_titles')
      .select('id, name, emoji, color, auto_assign_after_days')
      .eq('community_id', communityId)
      .order('created_at');
  return (result as List).map((e) => e as Map<String, dynamic>).toList();
});

// ── Screen ────────────────────────────────────────────────────────────────────
class MemberTitlesScreen extends ConsumerStatefulWidget {
  final String communityId;
  const MemberTitlesScreen({super.key, required this.communityId});

  @override
  ConsumerState<MemberTitlesScreen> createState() => _MemberTitlesScreenState();
}

class _MemberTitlesScreenState extends ConsumerState<MemberTitlesScreen> {
  static const _colors = [
    '#6366F1', '#EC4899', '#F59E0B', '#10B981',
    '#3B82F6', '#EF4444', '#8B5CF6', '#14B8A6',
  ];

  Future<void> _showCreateTitleDialog({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['name'] as String?);
    final emojiCtrl = TextEditingController(text: existing?['emoji'] as String?);
    String selectedColor = existing?['color'] as String? ?? _colors.first;
    int? autoDays = existing?['auto_assign_after_days'] as int?;
    bool allowSelfSelect = existing?['allow_self_select'] as bool? ?? true;
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final r = ctx.r;
          return AlertDialog(
            backgroundColor: ctx.nexusTheme.backgroundSecondary,
            title: Text(
              existing != null ? 'Editar Título' : 'Novo Título',
              style: TextStyle(
                color: ctx.nexusTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: ctx.nexusTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Nome do título',
                      labelStyle: TextStyle(color: ctx.nexusTheme.textSecondary),
                    ),
                  ),
                  SizedBox(height: r.s(12)),
                  TextField(
                    controller: emojiCtrl,
                    style: TextStyle(color: ctx.nexusTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Emoji (opcional)',
                      labelStyle: TextStyle(color: ctx.nexusTheme.textSecondary),
                    ),
                  ),
                  SizedBox(height: r.s(16)),
                  Text('Cor',
                      style: TextStyle(
                          color: ctx.nexusTheme.textSecondary,
                          fontSize: r.fs(13))),
                  SizedBox(height: r.s(8)),
                  Wrap(
                    spacing: r.s(8),
                    children: _colors.map((c) {
                      final color = _hexToColor(c);
                      final isSelected = c == selectedColor;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = c),
                        child: Container(
                          width: r.s(32),
                          height: r.s(32),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: Colors.white, width: 2.5)
                                : null,
                          ),
                          child: isSelected
                              ? Icon(Icons.check_rounded,
                                  color: Colors.white, size: r.s(16))
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: r.s(16)),
                  TextField(
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: ctx.nexusTheme.textPrimary),
                    onChanged: (v) =>
                        autoDays = int.tryParse(v),
                    decoration: InputDecoration(
                      labelText: 'Auto-atribuir após X dias (opcional)',
                      labelStyle: TextStyle(color: ctx.nexusTheme.textSecondary),
                      hintText: 'Ex: 30',
                      hintStyle: TextStyle(
                          color: ctx.nexusTheme.textSecondary
                              .withValues(alpha: 0.5)),
                    ),
                  ),
                  SizedBox(height: r.s(8)),
                  // Toggle: membros podem escolher este título por conta própria
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Membros podem escolher este título',
                          style: TextStyle(
                            color: ctx.nexusTheme.textPrimary,
                            fontSize: r.fs(13),
                          ),
                        ),
                      ),
                      Switch(
                        value: allowSelfSelect,
                        onChanged: (v) =>
                            setDialogState(() => allowSelfSelect = v),
                        activeColor: ctx.nexusTheme.accentPrimary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Cancelar',
                    style: TextStyle(color: ctx.nexusTheme.textSecondary)),
              ),
              NexusLoadingButton(
                label: existing != null ? 'Salvar' : 'Criar',
                isLoading: isLoading,
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  setDialogState(() => isLoading = true);
                  try {
                    if (existing != null) {
                      await SupabaseService.client
                          .from('community_member_titles')
                          .update({
                            'name': name,
                            'emoji': emojiCtrl.text.trim().isEmpty
                                ? null
                                : emojiCtrl.text.trim(),
                            'color': selectedColor,
                            'auto_assign_after_days': autoDays,
                            'allow_self_select': allowSelfSelect,
                          })
                          .eq('id', existing['id'] as String);
                    } else {
                      await SupabaseService.client
                          .from('community_member_titles')
                          .insert({
                            'community_id': widget.communityId,
                            'name': name,
                            'emoji': emojiCtrl.text.trim().isEmpty
                                ? null
                                : emojiCtrl.text.trim(),
                            'color': selectedColor,
                            'auto_assign_after_days': autoDays,
                            'allow_self_select': allowSelfSelect,
                            'created_by': SupabaseService.currentUserId,
                          });
                    }
                    ref.invalidate(communityTitlesProvider(widget.communityId));
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  } catch (e) {
                    setDialogState(() => isLoading = false);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Erro: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteTitle(String titleId) async {
    await SupabaseService.client
        .from('community_member_titles')
        .delete()
        .eq('id', titleId);
    ref.invalidate(communityTitlesProvider(widget.communityId));
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final titlesAsync = ref.watch(communityTitlesProvider(widget.communityId));

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Títulos de Membros',
          style: TextStyle(
            color: context.nexusTheme.textPrimary,
            fontSize: r.fs(17),
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Novo título',
            icon: Icon(Icons.add_rounded,
                color: context.nexusTheme.accentPrimary),
            onPressed: _showCreateTitleDialog,
          ),
        ],
      ),
      body: titlesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Erro: $e',
              style: TextStyle(color: context.nexusTheme.textSecondary)),
        ),
        data: (titles) {
          if (titles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.workspace_premium_rounded,
                      color: context.nexusTheme.textSecondary, size: r.s(48)),
                  SizedBox(height: r.s(12)),
                  Text(
                    'Nenhum título criado ainda',
                    style: TextStyle(
                      color: context.nexusTheme.textSecondary,
                      fontSize: r.fs(15),
                    ),
                  ),
                  SizedBox(height: r.s(8)),
                  TextButton.icon(
                    onPressed: _showCreateTitleDialog,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Criar primeiro título'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: EdgeInsets.all(r.s(16)),
            itemCount: titles.length,
            itemBuilder: (context, index) {
              final t = titles[index];
              final name = t['name'] as String? ?? '';
              final emoji = t['emoji'] as String?;
              final colorHex = t['color'] as String? ?? '#6366F1';
              final color = _hexToColor(colorHex);
              final autoDays = t['auto_assign_after_days'] as int?;

              return Container(
                margin: EdgeInsets.only(bottom: r.s(10)),
                padding: EdgeInsets.all(r.s(14)),
                decoration: BoxDecoration(
                  color: context.nexusTheme.backgroundSecondary,
                  borderRadius: BorderRadius.circular(r.s(12)),
                  border: Border.all(
                      color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: r.s(40),
                      height: r.s(40),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          emoji ?? '🏅',
                          style: TextStyle(fontSize: r.fs(20)),
                        ),
                      ),
                    ),
                    SizedBox(width: r.s(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              color: color,
                              fontSize: r.fs(15),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (autoDays != null)
                            Text(
                              'Auto: após $autoDays dias',
                              style: TextStyle(
                                color: context.nexusTheme.textSecondary,
                                fontSize: r.fs(11),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Editar',
                      icon: Icon(Icons.edit_rounded,
                          color: context.nexusTheme.textSecondary,
                          size: r.s(18)),
                      onPressed: () =>
                          _showCreateTitleDialog(existing: t),
                    ),
                    IconButton(
                      tooltip: 'Excluir',
                      icon: Icon(Icons.delete_rounded,
                          color: context.nexusTheme.error, size: r.s(18)),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor:
                                ctx.nexusTheme.backgroundSecondary,
                            title: Text('Excluir título?',
                                style: TextStyle(
                                    color: ctx.nexusTheme.textPrimary)),
                            content: Text(
                              'O título "$name" será removido de todos os membros.',
                              style: TextStyle(
                                  color: ctx.nexusTheme.textSecondary),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(ctx).pop(false),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(ctx).pop(true),
                                child: Text('Excluir',
                                    style: TextStyle(
                                        color: ctx.nexusTheme.error)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await _deleteTitle(t['id'] as String);
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  static Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    try {
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return const Color(0xFF6366F1);
    }
  }
}
