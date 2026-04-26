import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/member_title_badge.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final selectableTitlesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, communityId) async {
  final result = await SupabaseService.rpc('get_selectable_titles', params: {
    'p_community_id': communityId,
  });
  if (result == null) return [];
  return (result as List).map((e) => e as Map<String, dynamic>).toList();
});

// ── Screen ────────────────────────────────────────────────────────────────────

/// Tela para membros escolherem seu próprio título dentro de uma comunidade.
/// Acessível via /community/:id/my-title
class MemberTitlePickerScreen extends ConsumerStatefulWidget {
  final String communityId;
  const MemberTitlePickerScreen({super.key, required this.communityId});

  @override
  ConsumerState<MemberTitlePickerScreen> createState() =>
      _MemberTitlePickerScreenState();
}

class _MemberTitlePickerScreenState
    extends ConsumerState<MemberTitlePickerScreen> {
  String? _currentTitleId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentTitle();
  }

  Future<void> _loadCurrentTitle() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;
    try {
      // Busca direta na tabela para obter o title_id atual do membro
      final result = await SupabaseService.table('member_title_assignments')
          .select('title_id')
          .eq('user_id', userId)
          .eq('community_id', widget.communityId)
          .maybeSingle();
      if (result != null && mounted) {
        setState(() => _currentTitleId = result['title_id'] as String?);
      }
    } catch (_) {}
  }

  Future<void> _selectTitle(String titleId) async {
    if (_isLoading) return;
    HapticService.buttonPress();
    setState(() => _isLoading = true);
    try {
      await SupabaseService.rpc('self_select_member_title', params: {
        'p_title_id': titleId,
        'p_community_id': widget.communityId,
      });
      if (mounted) {
        setState(() {
          _currentTitleId = titleId;
          _isLoading = false;
        });
        HapticService.success();
        // Invalidar o provider do badge para atualizar em tempo real
        ref.invalidate(memberTitleProvider((
          userId: SupabaseService.currentUserId ?? '',
          communityId: widget.communityId,
        )));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Título selecionado com sucesso!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: context.nexusTheme.accentPrimary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final msg = e.toString().contains('self_select_not_allowed')
            ? 'Este título não pode ser escolhido por membros.'
            : 'Erro ao selecionar título. Tente novamente.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
            backgroundColor: context.nexusTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _removeTitle() async {
    if (_isLoading) return;
    HapticService.buttonPress();
    setState(() => _isLoading = true);
    try {
      await SupabaseService.rpc('remove_own_member_title', params: {
        'p_community_id': widget.communityId,
      });
      if (mounted) {
        setState(() {
          _currentTitleId = null;
          _isLoading = false;
        });
        ref.invalidate(memberTitleProvider((
          userId: SupabaseService.currentUserId ?? '',
          communityId: widget.communityId,
        )));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Título removido.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final titlesAsync = ref.watch(selectableTitlesProvider(widget.communityId));

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
          'Meu Título',
          style: TextStyle(
            color: context.nexusTheme.textPrimary,
            fontSize: r.fs(17),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: titlesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Erro ao carregar títulos.',
              style: TextStyle(color: context.nexusTheme.textSecondary)),
        ),
        data: (titles) {
          if (titles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.workspace_premium_outlined,
                      size: r.s(48), color: context.nexusTheme.textSecondary),
                  SizedBox(height: r.s(12)),
                  Text(
                    'Nenhum título disponível\nnesta comunidade.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.nexusTheme.textSecondary,
                      fontSize: r.fs(14),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: EdgeInsets.all(r.s(16)),
            children: [
              // Cabeçalho informativo
              Container(
                margin: EdgeInsets.only(bottom: r.s(16)),
                padding: EdgeInsets.all(r.s(14)),
                decoration: BoxDecoration(
                  color: context.nexusTheme.accentPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(r.s(12)),
                  border: Border.all(
                    color: context.nexusTheme.accentPrimary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: context.nexusTheme.accentPrimary, size: r.s(18)),
                    SizedBox(width: r.s(10)),
                    Expanded(
                      child: Text(
                        'Escolha um título para exibir abaixo do seu nome nos posts e mensagens desta comunidade.',
                        style: TextStyle(
                          color: context.nexusTheme.textSecondary,
                          fontSize: r.fs(12),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Opção "Sem título"
              if (_currentTitleId != null)
                _TitleOption(
                  name: 'Sem título',
                  emoji: '✕',
                  colorHex: '#9CA3AF',
                  isSelected: false,
                  isLoading: _isLoading,
                  onTap: _removeTitle,
                ),

              // Lista de títulos disponíveis
              ...titles.map((t) {
                final id = t['id'] as String;
                final isSelected = _currentTitleId == id;
                return _TitleOption(
                  name: t['name'] as String? ?? '',
                  emoji: t['emoji'] as String?,
                  colorHex: t['color'] as String? ?? '#6366F1',
                  isSelected: isSelected,
                  isLoading: _isLoading,
                  onTap: isSelected ? null : () => _selectTitle(id),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

// ── Widget auxiliar ────────────────────────────────────────────────────────────

class _TitleOption extends StatelessWidget {
  final String name;
  final String? emoji;
  final String colorHex;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback? onTap;

  const _TitleOption({
    required this.name,
    required this.emoji,
    required this.colorHex,
    required this.isSelected,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final color = _hexToColor(colorHex);

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: r.s(10)),
        padding: EdgeInsets.all(r.s(14)),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : context.nexusTheme.backgroundSecondary,
          borderRadius: BorderRadius.circular(r.s(12)),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1.0,
          ),
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
              child: Text(
                name,
                style: TextStyle(
                  color: isSelected ? color : context.nexusTheme.textPrimary,
                  fontSize: r.fs(15),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: r.s(22))
            else
              Icon(Icons.radio_button_unchecked_rounded,
                  color: context.nexusTheme.textSecondary, size: r.s(22)),
          ],
        ),
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
