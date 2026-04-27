import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// ============================================================================
// EditInterestsScreen — Editar interesses do perfil
// Reutiliza a mesma lista de categorias do InterestWizardScreen.
// ============================================================================

class _InterestItem {
  final String name;
  final IconData icon;
  final Color color;
  const _InterestItem(this.name, this.icon, this.color);
}

class EditInterestsScreen extends ConsumerStatefulWidget {
  const EditInterestsScreen({super.key});

  @override
  ConsumerState<EditInterestsScreen> createState() =>
      _EditInterestsScreenState();
}

class _EditInterestsScreenState extends ConsumerState<EditInterestsScreen> {
  final Set<String> _selected = {};
  bool _isSaving = false;

  static List<_InterestItem> _categories(BuildContext context) {
    final s = getStrings();
    return [
      _InterestItem(s.animeManga, Icons.movie_filter_rounded, const Color(0xFFE91E63)),
      _InterestItem(s.interestKpop, Icons.music_note_rounded, const Color(0xFF9C27B0)),
      _InterestItem(s.games, Icons.sports_esports_rounded, const Color(0xFF4CAF50)),
      _InterestItem(s.artDesign, Icons.palette_rounded, const Color(0xFFFF9800)),
      _InterestItem(s.interestFashion, Icons.checkroom_rounded, const Color(0xFFE040FB)),
      _InterestItem(s.booksWriting, Icons.menu_book_rounded, const Color(0xFF795548)),
      _InterestItem(s.moviesSeries, Icons.theaters_rounded, const Color(0xFFF44336)),
      _InterestItem(s.music, Icons.headphones_rounded, const Color(0xFF2196F3)),
      _InterestItem(s.interestPhotography, Icons.camera_alt_rounded, const Color(0xFF607D8B)),
      _InterestItem(s.interestScience, Icons.science_rounded, const Color(0xFF00BCD4)),
      _InterestItem(s.interestSports, Icons.fitness_center_rounded, const Color(0xFFFF5722)),
      _InterestItem(s.interestTechnology, Icons.computer_rounded, const Color(0xFF3F51B5)),
      _InterestItem(s.interestCosplay, Icons.face_retouching_natural_rounded, const Color(0xFFFF4081)),
      _InterestItem(s.interestSpirituality, Icons.self_improvement_rounded, const Color(0xFF8BC34A)),
      _InterestItem(s.interestCooking, Icons.restaurant_rounded, const Color(0xFFFFEB3B)),
      _InterestItem(s.petsAnimals, Icons.pets_rounded, const Color(0xFF009688)),
      _InterestItem(s.interestTravel, Icons.flight_rounded, const Color(0xFF03A9F4)),
      _InterestItem(s.interestHorror, Icons.dark_mode_rounded, const Color(0xFF424242)),
      _InterestItem(s.memesHumor, Icons.sentiment_very_satisfied_rounded, const Color(0xFFFFC107)),
      _InterestItem(s.interestLanguages, Icons.translate_rounded, const Color(0xFF673AB7)),
      _InterestItem(s.diy, Icons.handyman_rounded, const Color(0xFFCDDC39)),
      _InterestItem(s.interestComics, Icons.auto_stories_rounded, const Color(0xFFFF6F00)),
      _InterestItem(s.interestDance, Icons.nightlife_rounded, const Color(0xFFD500F9)),
      _InterestItem(s.interestNature, Icons.park_rounded, const Color(0xFF4CAF50)),
    ];
  }

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _selected.addAll(user?.selectedInterests ?? []);
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final interests = _selected.toList();
      await SupabaseService.rpc('set_user_interests', params: {
        'p_interests': interests,
      });
      // Atualizar o provider local
      final user = ref.read(currentUserProvider);
      if (user != null) {
        ref.read(authProvider.notifier).updateUserProfile(
          user.copyWith(selectedInterests: interests),
        );
      }
      if (mounted) {
        HapticService.success();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Interesses salvos!'),
            backgroundColor: context.nexusTheme.accentPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('[EditInterests] save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.nexusTheme;
    final r = context.r;
    final categories = _categories(context);

    return Scaffold(
      backgroundColor: theme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: theme.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Meus Interesses',
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: r.fs(17),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (_isSaving)
            Padding(
              padding: EdgeInsets.only(right: r.s(16)),
              child: SizedBox(
                width: r.s(20),
                height: r.s(20),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.accentPrimary,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _selected.isNotEmpty ? _save : null,
              child: Text(
                'Salvar',
                style: TextStyle(
                  color: _selected.isNotEmpty
                      ? theme.accentPrimary
                      : theme.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: r.fs(15),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Cabeçalho informativo
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: r.s(16), vertical: r.s(12)),
            child: Container(
              padding: EdgeInsets.all(r.s(12)),
              decoration: BoxDecoration(
                color: theme.accentPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(r.s(12)),
                border: Border.all(
                    color: theme.accentPrimary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: theme.accentPrimary, size: r.s(18)),
                  SizedBox(width: r.s(8)),
                  Expanded(
                    child: Text(
                      'Seus interesses são usados para encontrar pessoas com gostos similares. Selecione pelo menos 1.',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: r.fs(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Contador de selecionados
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.s(16)),
            child: Row(
              children: [
                Text(
                  '${_selected.length} selecionado${_selected.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: r.fs(12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_selected.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      HapticService.action();
                      setState(() => _selected.clear());
                    },
                    child: Text(
                      'Limpar tudo',
                      style: TextStyle(
                        color: theme.error,
                        fontSize: r.fs(12),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: r.s(8)),
          // Grid de interesses
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.symmetric(
                  horizontal: r.s(16), vertical: r.s(8)),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: r.s(8),
                mainAxisSpacing: r.s(8),
                childAspectRatio: 1.0,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final item = categories[index];
                final isSelected = _selected.contains(item.name);
                return GestureDetector(
                  onTap: () {
                    HapticService.action();
                    setState(() {
                      if (isSelected) {
                        _selected.remove(item.name);
                      } else {
                        _selected.add(item.name);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? item.color.withValues(alpha: 0.2)
                          : theme.backgroundSecondary,
                      borderRadius: BorderRadius.circular(r.s(12)),
                      border: Border.all(
                        color: isSelected
                            ? item.color
                            : theme.divider,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Ícone com checkmark se selecionado
                        Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Container(
                              padding: EdgeInsets.all(r.s(10)),
                              decoration: BoxDecoration(
                                color: item.color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                item.icon,
                                color: item.color,
                                size: r.s(24),
                              ),
                            ),
                            if (isSelected)
                              Container(
                                width: r.s(16),
                                height: r.s(16),
                                decoration: BoxDecoration(
                                  color: item.color,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: r.s(10),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: r.s(6)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: r.s(4)),
                          child: Text(
                            item.name,
                            style: TextStyle(
                              color: isSelected
                                  ? item.color
                                  : theme.textPrimary,
                              fontSize: r.fs(11),
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
}
