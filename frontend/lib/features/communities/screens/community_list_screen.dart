import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/amino_top_bar.dart';
import '../../../core/widgets/amino_particles_bg.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/utils/responsive.dart';

/// Provider para comunidades do usuário.
final userCommunitiesProvider =
    FutureProvider<List<CommunityModel>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];

  final response = await SupabaseService.table('community_members')
      .select('community_id, communities(*)')
      .eq('user_id', userId)
      .eq('is_banned', false)
      .order('joined_at', ascending: false);

  return (response as List?)
      .where((e) => e['communities'] != null)
      .map((e) =>
          CommunityModel.fromJson(e['communities'] as Map<String, dynamic>))
      .toList();
});

/// Provider para status de check-in de todas as comunidades do usuário.
/// Retorna Map<communityId, {has_checkin_today, consecutive_checkin_days}>.
final checkInStatusProvider =
    FutureProvider<Map<String, Map<String, dynamic>>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return {};

  final response = await SupabaseService.table('community_members')
      .select('community_id, has_checkin_today, consecutive_checkin_days, last_checkin_at')
      .eq('user_id', userId)
      .eq('is_banned', false);

  final Map<String, Map<String, dynamic>> result = {};
  for (final row in (response as List?)) {
    final communityId = row['community_id'] as String?;
    final lastCheckin = row['last_checkin_at'] as String?;
    // Derivar has_checkin_today comparando last_checkin_at com data UTC atual.
    // O campo has_checkin_today pode estar stale se não há cron de reset,
    // então usamos last_checkin_at como fonte de verdade.
    bool checkedInToday = false;
    if (lastCheckin != null) {
      final lastDate = DateTime.parse(lastCheckin).toUtc();
      final nowUtc = DateTime.now().toUtc();
      checkedInToday = lastDate.year == nowUtc.year &&
          lastDate.month == nowUtc.month &&
          lastDate.day == nowUtc.day;
    }
    result[communityId] = {
      'has_checkin_today': checkedInToday,
      'consecutive_checkin_days': row['consecutive_checkin_days'] as int? ?? 0,
    };
  }
  return result;
});

/// Provider para comunidades sugeridas.
final suggestedCommunitiesProvider =
    FutureProvider<List<CommunityModel>>((ref) async {
  final response = await SupabaseService.table('communities')
      .select()
      .eq('is_active', true)
      .eq('is_searchable', true)
      .order('members_count', ascending: false)
      .limit(50);

  return (response as List?)
      .map((e) => CommunityModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class CommunityListScreen extends ConsumerStatefulWidget {
  final bool isExplore;

  const CommunityListScreen({super.key, this.isExplore = false});

  @override
  ConsumerState<CommunityListScreen> createState() =>
      _CommunityListScreenState();
}

class _CommunityListScreenState extends ConsumerState<CommunityListScreen> {
  String? _avatarUrl;
  int _coins = 0;
  List<CommunityModel>? _reorderedCommunities;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final profile = await SupabaseService.table('profiles')
          .select('avatar_url, coins_count')
          .eq('id', userId)
          .single();
      if (mounted) {
        setState(() {
          _avatarUrl = profile['avatar_url'] as String?;
          _coins = profile['coins_count'] as int? ?? 0;
        });
      }
    } catch (e) {
      debugPrint('[community_list_screen] Erro: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final communitiesAsync = ref.watch(userCommunitiesProvider);
    // Observar status de check-in para rebuild automático
    ref.watch(checkInStatusProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: AminoParticlesBg(
        child: Column(
          children: [
            AminoTopBar(
              avatarUrl: _avatarUrl,
              coins: _coins,
              notificationCount: ref.watch(unreadNotificationCountProvider),
              onSearchTap: () => context.push('/search'),
              onAddTap: () => context.push('/community/create'),
            ),
            Expanded(
              child: communitiesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.accentColor,
                    strokeWidth: 2.5,
                  ),
                ),
                error: (error, stack) => _buildErrorState(),
                data: (communities) {
                  if (communities.isEmpty) {
                    return _buildEmptyState();
                  }
                  return _buildCommunityList(communities);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityList(List<CommunityModel> communities) {
      final r = context.r;
    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async {
        setState(() => _reorderedCommunities = null);
        ref.invalidate(userCommunitiesProvider);
        ref.invalidate(checkInStatusProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 80,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Título "Minhas Comunidades" ──
            Padding(
              padding: EdgeInsets.fromLTRB(r.s(16), r.s(8), r.s(16), r.s(8)),
              child: Text(
                'Minhas Comunidades',
                style: TextStyle(
                  fontSize: r.fs(20),
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
            ),

            // ── Grade horizontal de cards com drag & drop ──
            SizedBox(
              height: r.s(195),
              child: Row(
                children: [
                  Expanded(
                    child: ReorderableListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.only(left: r.s(14), right: r.s(8), top: r.s(18)),
                      itemCount: (_reorderedCommunities ?? communities).length,
                      onReorder: (oldIndex, newIndex) {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final list = List<CommunityModel>.from(
                              _reorderedCommunities ?? communities);
                          final item = list.removeAt(oldIndex);
                          list.insert(newIndex, item);
                          _reorderedCommunities = list;
                        });
                      },
                      proxyDecorator: (child, index, animation) {
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (context, child) => Transform.scale(
                            scale: 1.05,
                            child: Material(
                              color: Colors.transparent,
                              child: child,
                            ),
                          ),
                          child: child,
                        );
                      },
                      itemBuilder: (context, index) {
                        final community = (_reorderedCommunities ?? communities)[index];
                        return Padding(
                          key: ValueKey(community.id),
                          padding: EdgeInsets.only(right: r.s(8)),
                          child: _AminoCommunityCard(
                            community: community,
                            ref: ref,
                            onTap: () => context.push('/community/${community.id}'),
                            onLongPress: () {
                              HapticFeedback.mediumImpact();
                              _showCommunityPreview(context, community);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  // Card fixo para entrar em nova comunidade
                  Padding(
                    padding: EdgeInsets.only(right: r.s(8)),
                    child: _JoinCommunityCard(
                      onTap: () => context.push('/community/search'),
                    ),
                  ),
                ],
              ),
            ),

            // ── Texto instrucional ──
            Padding(
              padding: EdgeInsets.only(top: r.s(16), bottom: r.s(16)),
              child: Center(
                child: Text(
                  'Segure e arraste os cards para reordenar',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: r.fs(12),
                  ),
                ),
              ),
            ),

            // ── Botão outline "CRIE SUA COMUNIDADE" ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.s(24)),
              child: GestureDetector(
                onTap: () => context.push('/community/create'),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: r.s(16)),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(r.s(8)),
                    border: Border.all(
                      color: AppTheme.accentColor,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'CRIE SUA COMUNIDADE',
                      style: TextStyle(
                        color: AppTheme.accentColor,
                        fontSize: r.fs(15),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCommunityPreview(BuildContext context, CommunityModel community) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CommunityPreviewSheet(
        community: community,
        ref: ref,
      ),
    );
  }

  Widget _buildEmptyState() {
      final r = context.r;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(r.s(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_rounded,
                color: context.textHint, size: r.s(48)),
            SizedBox(height: r.s(12)),
            Text(
              'Nenhuma comunidade',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: r.fs(16),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: r.s(6)),
            Text(
              'Explore e entre em comunidades para começar!',
              style: TextStyle(
                color: context.textSecondary,
                fontSize: r.fs(13),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: r.s(18)),
            GestureDetector(
              onTap: () => context.go('/explore'),
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: r.s(24), vertical: r.s(10)),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(r.s(20)),
                ),
                child: Text(
                  'Explorar Comunidades',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: r.fs(14),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
      final r = context.r;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              color: AppTheme.errorColor, size: r.s(40)),
          SizedBox(height: r.s(10)),
          Text(
            'Erro ao carregar comunidades',
            style: TextStyle(color: context.textPrimary, fontSize: r.fs(14)),
          ),
          SizedBox(height: r.s(12)),
          GestureDetector(
            onTap: () => ref.invalidate(userCommunitiesProvider),
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(20), vertical: r.s(10)),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(r.s(16)),
              ),
              child: Text(
                'Tentar novamente',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.fs(13),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CARD DE COMUNIDADE — Clone pixel-perfect do Amino original
//
// Referência visual (print do Amino):
// - Card retangular vertical com bordas arredondadas (~10px)
// - Banner (imagem de capa) preenchendo o card
// - Gradiente escuro na base para legibilidade do nome
// - Nome da comunidade na parte inferior da imagem, branco bold
// - Botão CHECK IN: retângulo arredondado ciano SEPARADO na base do card
//   com padding lateral (NÃO full-width colado na borda)
//   → DESAPARECE após check-in feito (mostra streak badge no lugar)
// - Ícone flutuante no canto superior esquerdo, parcialmente fora do card
//   com borda colorida (themeColor)
// ============================================================================
class _AminoCommunityCard extends StatefulWidget {
  final CommunityModel community;
  final WidgetRef ref;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  static const double _cardWidth = 120;
  static const double _iconSize = 34;
  static const double _iconOverflow = 16;

  const _AminoCommunityCard({
    required this.community,
    required this.ref,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_AminoCommunityCard> createState() => _AminoCommunityCardState();
}

class _AminoCommunityCardState extends State<_AminoCommunityCard> {
  bool _isCheckingIn = false;

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.aminoPurple;
    }
  }

  Future<void> _doCheckIn() async {
    if (_isCheckingIn) return;
    setState(() => _isCheckingIn = true);

    try {
      final result = await SupabaseService.rpc('daily_checkin', params: {
        'p_community_id': widget.community.id,
      });

      // Invalidar o provider para atualizar o status em todos os cards
      widget.ref.invalidate(checkInStatusProvider);

      if (mounted) {
        final data = result as Map<String, dynamic>?;
        if (data != null && data['success'] == true) {
          final streak = data['streak'] as int? ?? 1;
          final coins = data['coins_earned'] as int? ?? 0;
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Check-in feito! Sequência: $streak dia${streak > 1 ? 's' : ''} (+$coins moedas)',
              ),
              backgroundColor: AppTheme.accentColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (data != null && data['error'] == 'already_checked_in') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Você já fez check-in hoje nesta comunidade!'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro no check-in. Tente novamente.'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final color = _parseColor(widget.community.themeColor);
    final checkInStatus = widget.ref.watch(checkInStatusProvider);
    final statusMap = checkInStatus.valueOrNull ?? {};
    final myStatus = statusMap[widget.community.id];
    final hasCheckedIn = myStatus?['has_checkin_today'] as bool? ?? false;
    final streak = myStatus?['consecutive_checkin_days'] as int? ?? 0;

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: SizedBox(
        width: _AminoCommunityCard._cardWidth,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Card principal (com margem top para o ícone flutuante) ──
            Positioned.fill(
              top: _AminoCommunityCard._iconOverflow,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(r.s(10)),
                  color: const Color(0xFF1E1E3A),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Banner (imagem de capa) — preenche o espaço disponível
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Imagem
                          widget.community.bannerUrl != null && widget.community.bannerUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: widget.community.bannerUrl ?? '',
                                  fit: BoxFit.cover,
                                  memCacheWidth: 360,
                                  memCacheHeight: 480,
                                  placeholder: (_, __) => Container(
                                    color: color.withValues(alpha: 0.3),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: color.withValues(alpha: 0.3),
                                    child: Center(
                                      child: Icon(Icons.groups_rounded,
                                          color: Colors.white
                                              .withValues(alpha: 0.2),
                                          size: r.s(28)),
                                    ),
                                  ),
                                )
                              : Container(
                                  color: color.withValues(alpha: 0.3),
                                  child: Center(
                                    child: Icon(Icons.groups_rounded,
                                        color: Colors.white
                                            .withValues(alpha: 0.2),
                                        size: r.s(28)),
                                  ),
                                ),

                          // Gradiente inferior para legibilidade do nome
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: r.s(50),
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Color(0xCC000000),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Nome da comunidade
                          Positioned(
                            bottom: 4,
                            left: 6,
                            right: 6,
                            child: Text(
                              widget.community.name,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: r.fs(11),
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                shadows: [
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 6,
                                  ),
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Botão CHECK IN ou Streak Badge ──
                    if (!hasCheckedIn)
                      // Botão CHECK IN — visível apenas se não fez check-in hoje
                      GestureDetector(
                        onTap: _isCheckingIn ? null : _doCheckIn,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(r.s(6), r.s(4), r.s(6), r.s(5)),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: r.s(4)),
                            decoration: BoxDecoration(
                              color: _isCheckingIn
                                  ? AppTheme.accentColor.withValues(alpha: 0.5)
                                  : AppTheme.accentColor,
                              borderRadius: BorderRadius.circular(r.s(6)),
                            ),
                            child: _isCheckingIn
                                ? SizedBox(
                                    height: r.s(14),
                                    child: Center(
                                      child: SizedBox(
                                        width: r.s(12),
                                        height: r.s(12),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  )
                                : Text(
                                    'CHECK IN',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: r.fs(10),
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                          ),
                        ),
                      )
                    else
                      // Streak badge — mostra quando já fez check-in hoje
                      Padding(
                        padding: EdgeInsets.fromLTRB(r.s(6), r.s(4), r.s(6), r.s(5)),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: r.s(3)),
                          decoration: BoxDecoration(
                            color: context.cardBgAlt,
                            borderRadius: BorderRadius.circular(r.s(6)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_fire_department_rounded,
                                color: AppTheme.warningColor,
                                size: r.s(12),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$streak dia${streak > 1 ? 's' : ''}',
                                style: TextStyle(
                                  color: AppTheme.warningColor,
                                  fontSize: r.fs(9),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Ícone flutuante (acima e à esquerda do card, parcialmente fora) ──
            Positioned(
              top: 0,
              left: 4,
              child: Container(
                width: _AminoCommunityCard._iconSize,
                height: _AminoCommunityCard._iconSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(r.s(8)),
                  color: context.scaffoldBg,
                  border: Border.all(color: color, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: widget.community.iconUrl != null && widget.community.iconUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: widget.community.iconUrl ?? '',
                        fit: BoxFit.cover,
                        memCacheWidth: 96,
                        memCacheHeight: 96,
                      )
                    : Icon(Icons.person,
                        color: Colors.white54, size: r.s(18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CARD "ENTRAR EM UMA COMUNIDADE" — translúcido cinza-azulado
// Ícone "+" no topo, texto "Entrar em uma comunidade" centralizado.
// Mesma altura que os cards de comunidade.
// ============================================================================
class _JoinCommunityCard extends StatelessWidget {
  final VoidCallback onTap;
  const _JoinCommunityCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: r.s(120),
        margin: EdgeInsets.only(top: r.s(18)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r.s(10)),
          color: context.cardBgAlt.withValues(alpha: 0.5),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícone "+"
            Icon(
              Icons.add,
              color: Colors.white.withValues(alpha: 0.55),
              size: r.s(28),
            ),
            SizedBox(height: r.s(10)),
            // Texto
            Text(
              'Entrar em uma\ncomunidade',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: r.fs(12),
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PREVIEW DA COMUNIDADE — Bottom sheet (long press)
// ============================================================================
class _CommunityPreviewSheet extends StatefulWidget {
  final CommunityModel community;
  final WidgetRef ref;

  const _CommunityPreviewSheet({
    required this.community,
    required this.ref,
  });

  @override
  State<_CommunityPreviewSheet> createState() => _CommunityPreviewSheetState();
}

class _CommunityPreviewSheetState extends State<_CommunityPreviewSheet> {
  bool _isCheckingIn = false;

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.aminoPurple;
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  Future<void> _doCheckIn() async {
    if (_isCheckingIn) return;
    setState(() => _isCheckingIn = true);

    try {
      final result = await SupabaseService.rpc('daily_checkin', params: {
        'p_community_id': widget.community.id,
      });

      widget.ref.invalidate(checkInStatusProvider);

      if (mounted) {
        final data = result as Map<String, dynamic>?;
        if (data != null && data['success'] == true) {
          final streak = data['streak'] as int? ?? 1;
          final coins = data['coins_earned'] as int? ?? 0;
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Check-in feito! Sequência: $streak dia${streak > 1 ? 's' : ''} (+$coins moedas)',
              ),
              backgroundColor: AppTheme.accentColor,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (data != null && data['error'] == 'already_checked_in') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Você já fez check-in hoje nesta comunidade!'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro no check-in. Tente novamente.'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final color = _parseColor(widget.community.themeColor);
    final checkInStatus = widget.ref.watch(checkInStatusProvider);
    final statusMap = checkInStatus.valueOrNull ?? {};
    final myStatus = statusMap[widget.community.id];
    final hasCheckedIn = myStatus?['has_checkin_today'] as bool? ?? false;
    final streak = myStatus?['consecutive_checkin_days'] as int? ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: r.s(32),
            height: r.s(3),
            margin: EdgeInsets.only(top: r.s(10)),
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Banner
          Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: r.s(140),
                  width: double.infinity,
                  child: widget.community.bannerUrl != null && widget.community.bannerUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.community.bannerUrl ?? '',
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [color, color.withValues(alpha: 0.5)],
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [color, color.withValues(alpha: 0.5)],
                              ),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color, color.withValues(alpha: 0.5)],
                            ),
                          ),
                        ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: r.s(60),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        context.surfaceColor.withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Ícone + Nome + Tagline
          Padding(
            padding: EdgeInsets.fromLTRB(r.s(16), 0, r.s(16), 0),
            child: Row(
              children: [
                Container(
                  width: r.s(48),
                  height: r.s(48),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(r.s(12)),
                    color: context.cardBg,
                    border: Border.all(color: color, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: widget.community.iconUrl != null && widget.community.iconUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.community.iconUrl ?? '',
                          fit: BoxFit.cover,
                        )
                      : Icon(Icons.groups_rounded,
                          color: context.textHint, size: r.s(24)),
                ),
                SizedBox(width: r.s(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.community.name,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: r.fs(16),
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.community.tagline.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.community.tagline,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: r.fs(11),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: r.s(10)),

          // Estatísticas
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.s(16)),
            child: Row(
              children: [
                _StatChip(
                  icon: Icons.people_rounded,
                  label: '${_formatCount(widget.community.membersCount)} membros',
                  color: AppTheme.accentColor,
                ),
                SizedBox(width: r.s(8)),
                _StatChip(
                  icon: Icons.article_rounded,
                  label: '${_formatCount(widget.community.postsCount)} posts',
                  color: AppTheme.aminoPurple,
                ),
                if (hasCheckedIn && streak > 0) ...[
                  SizedBox(width: r.s(8)),
                  _StatChip(
                    icon: Icons.local_fire_department_rounded,
                    label: '$streak dia${streak > 1 ? 's' : ''}',
                    color: AppTheme.warningColor,
                  ),
                ],
              ],
            ),
          ),

          // Descrição
          if (widget.community.description.isNotEmpty) ...[
            SizedBox(height: r.s(10)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: r.s(16)),
              child: Text(
                widget.community.description,
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: r.fs(12),
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          SizedBox(height: r.s(16)),

          // Botões
          Padding(
            padding: EdgeInsets.only(
              left: r.s(16),
              right: r.s(16),
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/community/${widget.community.id}');
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: r.s(11)),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(r.s(8)),
                      ),
                      child: Text(
                        'Abrir',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: r.fs(14),
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: r.s(8)),
                // Botão Check In ou badge de streak
                if (!hasCheckedIn)
                  GestureDetector(
                    onTap: _isCheckingIn ? null : _doCheckIn,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(16), vertical: r.s(11)),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor,
                        borderRadius: BorderRadius.circular(r.s(8)),
                      ),
                      child: _isCheckingIn
                          ? SizedBox(
                              width: r.s(16),
                              height: r.s(16),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Check In',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: r.fs(13),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  )
                else
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(12), vertical: r.s(11)),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(r.s(8)),
                      border: Border.all(
                          color: AppTheme.warningColor.withValues(alpha: 0.4),
                          width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department_rounded,
                            color: AppTheme.warningColor, size: r.s(16)),
                        SizedBox(width: r.s(4)),
                        Text(
                          '$streak dia${streak > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: AppTheme.warningColor,
                            fontSize: r.fs(13),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.s(8), vertical: r.s(4)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(r.s(16)),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: r.s(12)),
          SizedBox(width: r.s(4)),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: r.fs(10),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
