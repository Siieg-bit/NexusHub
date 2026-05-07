import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';

// =============================================================================
// InterestCategory — Modelo de categoria de interesse carregada do banco
//
// Substitui a classe privada _InterestItem que estava duplicada em:
//   - interest_wizard_screen.dart
//   - edit_interests_screen.dart
//
// Os dados vêm da tabela `interests` (migration 235), que inclui:
//   name, display_name, category, background_color, icon_name, sort_order
// =============================================================================

/// Modelo de categoria de interesse carregada remotamente do Supabase.
class InterestCategory {
  final String name;
  final String displayName;
  final String category;
  final Color color;
  final IconData icon;
  final int sortOrder;

  const InterestCategory({
    required this.name,
    required this.displayName,
    required this.category,
    required this.color,
    required this.icon,
    required this.sortOrder,
  });

  /// Converte uma linha da tabela `interests` em [InterestCategory].
  factory InterestCategory.fromRow(Map<String, dynamic> row) {
    return InterestCategory(
      name:        row['name']         as String? ?? '',
      displayName: row['display_name'] as String? ?? row['name'] as String? ?? '',
      category:    row['category']     as String? ?? '',
      color:       _parseColor(row['background_color'] as String? ?? '#607D8B'),
      icon:        _parseIcon(row['icon_name'] as String? ?? 'star_rounded'),
      sortOrder:   row['sort_order']   as int? ?? 0,
    );
  }

  /// Converte string hex (#RRGGBB ou #AARRGGBB) em [Color].
  static Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      final value = int.parse(clean.length == 6 ? 'FF$clean' : clean, radix: 16);
      return Color(value);
    } catch (_) {
      return const Color(0xFF607D8B);
    }
  }

  /// Converte nome de ícone Material em [IconData].
  /// Mapa cobre todos os ícones usados nas 24 categorias de interesse.
  /// Ícones desconhecidos fazem fallback para [Icons.star_rounded].
  static IconData _parseIcon(String name) {
    const map = <String, IconData>{
      'movie_filter_rounded':              Icons.movie_filter_rounded,
      'music_note_rounded':                Icons.music_note_rounded,
      'sports_esports_rounded':            Icons.sports_esports_rounded,
      'palette_rounded':                   Icons.palette_rounded,
      'checkroom_rounded':                 Icons.checkroom_rounded,
      'menu_book_rounded':                 Icons.menu_book_rounded,
      'theaters_rounded':                  Icons.theaters_rounded,
      'headphones_rounded':                Icons.headphones_rounded,
      'camera_alt_rounded':                Icons.camera_alt_rounded,
      'science_rounded':                   Icons.science_rounded,
      'fitness_center_rounded':            Icons.fitness_center_rounded,
      'computer_rounded':                  Icons.computer_rounded,
      'face_retouching_natural_rounded':   Icons.face_retouching_natural_rounded,
      'self_improvement_rounded':          Icons.self_improvement_rounded,
      'restaurant_rounded':                Icons.restaurant_rounded,
      'pets_rounded':                      Icons.pets_rounded,
      'flight_rounded':                    Icons.flight_rounded,
      'dark_mode_rounded':                 Icons.dark_mode_rounded,
      'sentiment_very_satisfied_rounded':  Icons.sentiment_very_satisfied_rounded,
      'translate_rounded':                 Icons.translate_rounded,
      'handyman_rounded':                  Icons.handyman_rounded,
      'auto_stories_rounded':              Icons.auto_stories_rounded,
      'nightlife_rounded':                 Icons.nightlife_rounded,
      'park_rounded':                      Icons.park_rounded,
      // Ícones extras para extensibilidade futura
      'star_rounded':                      Icons.star_rounded,
      'favorite_rounded':                  Icons.favorite_rounded,
      'emoji_events_rounded':              Icons.emoji_events_rounded,
      'sports_rounded':                    Icons.sports_rounded,
      'local_movies_rounded':              Icons.local_movies_rounded,
      'brush_rounded':                     Icons.brush_rounded,
      'code_rounded':                      Icons.code_rounded,
      'school_rounded':                    Icons.school_rounded,
      'travel_explore_rounded':            Icons.travel_explore_rounded,
      'psychology_rounded':                Icons.psychology_rounded,
      'nature_rounded':                    Icons.nature_rounded,
      'emoji_nature_rounded':              Icons.emoji_nature_rounded,
      'celebration_rounded':               Icons.celebration_rounded,
    };
    return map[name] ?? Icons.star_rounded;
  }
}

// =============================================================================
// interestCategoriesProvider — FutureProvider que busca interesses do Supabase
//
// Cache automático pelo Riverpod. Invalide com:
//   ref.invalidate(interestCategoriesProvider)
// =============================================================================

/// FutureProvider que carrega as categorias de interesse da tabela `interests`.
/// Ordenado por `sort_order ASC`.
/// Em caso de erro de rede, lança exceção para o caller tratar com estado de erro.
final interestCategoriesProvider = FutureProvider<List<InterestCategory>>((ref) async {
  final rows = await SupabaseService.table('interests')
      .select('name, display_name, category, background_color, icon_name, sort_order')
      .order('sort_order', ascending: true);

  return (rows as List)
      .map((row) => InterestCategory.fromRow(row as Map<String, dynamic>))
      .where((c) => c.name.isNotEmpty)
      .toList();
});
