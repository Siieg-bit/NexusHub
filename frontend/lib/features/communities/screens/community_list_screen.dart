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
import '../providers/community_shared_providers.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/widgets/level_up_dialog.dart';
import '../../../../config/nexus_theme_extension.dart';
import '../../../../config/nexus_theme_extension.dart';

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
          .select('icon_url, coins')
          .eq('id', userId)
          .single();
      if (mounted) {
        setState(() {
          _avatarUrl = profile['icon_url'] as String?;
          _coins = profile['coins'] as int? ?? 0;
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
      backgroundColor: context.nexusTheme.backgroundPrimary,
      body: AminoParticlesBg(
        child: Column(
          children: [
            AminoTopBar(
              avatarUrl: _avatarUrl,
              coins: _coins,
              notificationCount: ref.watch(unreadNotificationCountProvider),
              onSearchTap: () => context.push('/search'),
              onAddTap: () => context.push('/coin-shop'),
            ),
            Expanded(
              child: RefreshIndicator(
                color: context.nexusTheme.accentPrimary,
                onRefresh: () async {
                  setState(() => _reorderedCommunities = null);
                  ref.invalidate(userCommunitiesProvider);
                  ref.invalidate(checkInStatusProvider);
                },
                child: communitiesAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: context.nexusTheme.accentSecondary,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunityList(List<CommunityModel> communities) {
    final s = getStrings();
    final r = context.r;
    return RefreshIndicator(
      color: context.nexusTheme.accentPrimary,
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
                s.myCommunitiesTitle,
                style: TextStyle(
                  fontSize: r.fs(20),
                  fontWeight: FontWeight.w800,
                  color: context.nexusTheme.textPrimary,
                ),
              ),
            ),

            // ── Grade horizontal de cards com drag & drop ──
            // Objetivo: exatamente 3 itens visiveis na tela (2 cards + JoinCard).
            // Todos com a mesma largura. O 3o card (JoinCard) fica fixo no Row,
            // os demais ficam no ReorderableListView com scroll horizontal.
            // Formula: cardW = (screenWidth - leftPad - 2*gap - rightPad) / 3
            LayoutBuilder(builder: (context, constraints) {
              final screenW = r.screenWidth;
              const double leftPad = 14.0; // padding.left da lista
              const double gap     = 8.0;  // espaco entre cada item
              const double rightPad = 8.0; // padding.right do JoinCard
              // 3 itens: cada um tem gap a direita, exceto o ultimo que tem rightPad
              // total ocupado pelos gaps: gap*2 (entre item1-2 e item2-3) + rightPad
              final double cardW    = (screenW - leftPad - gap * 2 - rightPad) / 3;
              final double overflow  = r.s(_AminoCommunityCard._iconOverflow);
              // cardH proporcional à cardW (mesma razão usada dentro do card)
              final double cardH    = cardW * (175.0 / 120.0);

              return SizedBox(
                height: overflow + cardH,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.only(
                            left: leftPad, right: gap, top: overflow),
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
                          final community =
                              (_reorderedCommunities ?? communities)[index];
                          return Padding(
                            key: ValueKey(community.id),
                            padding: EdgeInsets.only(right: gap),
                            child: _AminoCommunityCard(
                              community: community,
                              reorderIndex: index,
                              cardWidth: cardW,
                              onTap: () =>
                                  context.push('/community/${community.id}'),
                              onLongPress: () {
                                HapticFeedback.mediumImpact();
                                _showCommunityPreview(context, community);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    // JoinCard fixo com mesma largura dos cards de comunidade
                    Padding(
                      padding: EdgeInsets.only(right: rightPad),
                      child: _JoinCommunityCard(
                        cardWidth: cardW,
                        onTap: () => _showJoinCommunitySheet(communities),
                      ),
                    ),
                  ],
                ),
              );
            }),
            // ── Texto instrucional ───
            Padding(
              padding: EdgeInsets.only(top: r.s(16), bottom: r.s(16)),
              child: Center(
                child: Text(
                  'Use o ícone de arraste no card para reordenar suas comunidades.',
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
                      color: context.nexusTheme.accentSecondary,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      s.createCommunityTitle.toUpperCase(),
                      style: TextStyle(
                        color: context.nexusTheme.accentSecondary,
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
    final s = getStrings();
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final r = ctx.r;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: r.s(8)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: r.s(32),
                  height: r.s(3),
                  margin: EdgeInsets.only(bottom: r.s(8)),
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header com nome da comunidade
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(16), vertical: r.s(8)),
                  child: Row(
                    children: [
                      Container(
                        width: r.s(40),
                        height: r.s(40),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(r.s(10)),
                          color: ctx.cardBg,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: community.iconUrl != null &&
                                community.iconUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: community.iconUrl!,
                                fit: BoxFit.cover,
                              )
                            : Icon(Icons.groups_rounded,
                                color: ctx.textHint, size: r.s(20)),
                      ),
                      SizedBox(width: r.s(12)),
                      Expanded(
                        child: Text(
                          community.name,
                          style: TextStyle(
                            color: ctx.textPrimary,
                            fontSize: r.fs(16),
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: Colors.grey[800], height: 1),
                // 1. Ver detalhes da comunidade
                ListTile(
                  leading: Icon(Icons.info_outline_rounded,
                      color: context.nexusTheme.accentSecondary, size: r.s(22)),
                  title: Text(
                    'Ver detalhes da comunidade',
                    style: TextStyle(
                        color: ctx.textPrimary,
                        fontSize: r.fs(14),
                        fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/community/${community.id}/info');
                  },
                ),
                // 2. Reordenar comunidades
                ListTile(
                  leading: Icon(Icons.swap_vert_rounded,
                      color: context.nexusTheme.accentPrimary, size: r.s(22)),
                  title: Text(
                    'Reordenar comunidades',
                    style: TextStyle(
                        color: ctx.textPrimary,
                        fontSize: r.fs(14),
                        fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showReorderMode();
                  },
                ),
                // 3. Sair da comunidade
                ListTile(
                  leading: Icon(Icons.exit_to_app_rounded,
                      color: context.nexusTheme.error, size: r.s(22)),
                  title: Text(
                    s.leaveCommunity,
                    style: TextStyle(
                        color: context.nexusTheme.error,
                        fontSize: r.fs(14),
                        fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmLeaveCommunity(context, community);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReorderMode() {
    final s = ref.read(stringsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            s.holdAndDragToReorder),
        backgroundColor: context.nexusTheme.accentSecondary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _confirmLeaveCommunity(
      BuildContext context, CommunityModel community) async {
    final s = getStrings();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final r = ctx.r;
        return AlertDialog(
          backgroundColor: ctx.surfaceColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(r.s(16))),
          title: Text(
            s.leaveCommunity,
            style:
                TextStyle(color: ctx.textPrimary, fontWeight: FontWeight.w800),
          ),
          content: Text(
            s.leaveCommunityConfirmMsg(community.name),
            style: TextStyle(color: ctx.textSecondary, fontSize: r.fs(14)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  Text(s.cancel, style: TextStyle(color: ctx.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.logout,
                  style: TextStyle(
                      color: context.nexusTheme.error, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        final userId = SupabaseService.currentUserId;
        if (userId == null) return;

        await SupabaseService.table('community_members')
            .delete()
            .eq('community_id', community.id)
            .eq('user_id', userId);

        if (mounted) {
          ref.invalidate(userCommunitiesProvider);
          setState(() => _reorderedCommunities = null);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(s.leftCommunityMsg(community.name)),
              backgroundColor: context.nexusTheme.accentSecondary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  const Text('Erro ao sair da comunidade. Tente novamente.'),
              backgroundColor: context.nexusTheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showJoinCommunitySheet(List<CommunityModel> joinedCommunities) {
    final joinedIds = joinedCommunities.map((community) => community.id).toSet();
    final r = context.r;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final suggestionsAsync = ref.watch(suggestedCommunitiesProvider);

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.82,
              ),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(r.s(24)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(r.s(20), r.s(12), r.s(20), r.s(20)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: r.s(44),
                          height: r.s(5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(r.s(999)),
                          ),
                        ),
                      ),
                      SizedBox(height: r.s(16)),
                      Text(
                        'Entrar em uma comunidade',
                        style: TextStyle(
                          color: context.nexusTheme.textPrimary,
                          fontSize: r.fs(18),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: r.s(6)),
                      Text(
                        'Abra rapidamente comunidades sugeridas para descobrir algo novo sem sair do seu hub atual.',
                        style: TextStyle(
                          color: context.nexusTheme.textSecondary,
                          fontSize: r.fs(13),
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: r.s(18)),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          context.push('/explore');
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: r.s(16),
                            vertical: r.s(14),
                          ),
                          decoration: BoxDecoration(
                            color: context.nexusTheme.accentPrimary,
                            borderRadius: BorderRadius.circular(r.s(14)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.travel_explore_rounded,
                                  color: Colors.white, size: r.s(18)),
                              SizedBox(width: r.s(10)),
                              Text(
                                'Explorar todas as comunidades',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: r.fs(14),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: r.s(18)),
                      Text(
                        'Sugestões para entrar agora',
                        style: TextStyle(
                          color: context.nexusTheme.textPrimary,
                          fontSize: r.fs(14),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: r.s(10)),
                      Flexible(
                        child: suggestionsAsync.when(
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(
                                color: context.nexusTheme.accentSecondary,
                                strokeWidth: 2.4,
                              ),
                            ),
                          ),
                          error: (_, __) => Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: r.s(24)),
                              child: Text(
                                'Não foi possível carregar sugestões agora.',
                                style: TextStyle(color: context.nexusTheme.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          data: (suggestions) {
                            final filtered = suggestions
                                .where((community) => !joinedIds.contains(community.id))
                                .take(6)
                                .toList(growable: false);

                            if (filtered.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: r.s(24)),
                                  child: Text(
                                    'Você já entrou nas principais sugestões. Toque acima para explorar outras comunidades.',
                                    style: TextStyle(color: context.nexusTheme.textSecondary),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => SizedBox(height: r.s(10)),
                              itemBuilder: (context, index) {
                                final community = filtered[index];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.of(sheetContext).pop();
                                    context.push('/community/${community.id}');
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(r.s(12)),
                                    decoration: BoxDecoration(
                                      color: context.nexusTheme.surfaceSecondary.withValues(alpha: 0.42),
                                      borderRadius: BorderRadius.circular(r.s(14)),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.05),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(r.s(12)),
                                          child: SizedBox(
                                            width: r.s(48),
                                            height: r.s(48),
                                            child: community.iconUrl != null &&
                                                    community.iconUrl!.isNotEmpty
                                                ? CachedNetworkImage(
                                                    imageUrl: community.iconUrl!,
                                                    fit: BoxFit.cover,
                                                    errorWidget: (_, __, ___) =>
                                                        _suggestionIconFallback(r),
                                                  )
                                                : _suggestionIconFallback(r),
                                          ),
                                        ),
                                        SizedBox(width: r.s(12)),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                community.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: context.nexusTheme.textPrimary,
                                                  fontSize: r.fs(14),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              if (community.tagline.isNotEmpty) ...[
                                                SizedBox(height: r.s(4)),
                                                Text(
                                                  community.tagline,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: context.nexusTheme.textSecondary,
                                                    fontSize: r.fs(12),
                                                    height: 1.3,
                                                  ),
                                                ),
                                              ],
                                              SizedBox(height: r.s(6)),
                                              Text(
                                                '${community.membersCount} membros',
                                                style: TextStyle(
                                                  color: Colors.grey[400],
                                                  fontSize: r.fs(11),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: r.s(12)),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: r.s(10),
                                            vertical: r.s(8),
                                          ),
                                          decoration: BoxDecoration(
                                            color: context.nexusTheme.accentPrimary.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(r.s(999)),
                                          ),
                                          child: Text(
                                            'Abrir',
                                            style: TextStyle(
                                              color: context.nexusTheme.accentPrimary,
                                              fontSize: r.fs(11),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _suggestionIconFallback(Responsive r) {
    return Container(
      color: const Color(0xFF2D3142),
      child: Icon(
        Icons.groups_rounded,
        color: Colors.white,
        size: r.s(22),
      ),
    );
  }

  Widget _buildEmptyState() {
    final s = getStrings();
    final r = context.r;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(r.s(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_rounded, color: context.nexusTheme.textHint, size: r.s(48)),
            SizedBox(height: r.s(12)),
            Text(
              'Nenhuma comunidade',
              style: TextStyle(
                color: context.nexusTheme.textPrimary,
                fontSize: r.fs(16),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: r.s(6)),
            Text(
              s.exploreCommunities,
              style: TextStyle(
                color: context.nexusTheme.textSecondary,
                fontSize: r.fs(13),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: r.s(18)),
            GestureDetector(
              onTap: () => context.go('/explore'),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: r.s(24), vertical: r.s(10)),
                decoration: BoxDecoration(
                  color: context.nexusTheme.accentPrimary,
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
    final s = getStrings();
    final r = context.r;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              color: context.nexusTheme.error, size: r.s(40)),
          SizedBox(height: r.s(10)),
          Text(
            'Erro ao carregar comunidades',
            style: TextStyle(color: context.nexusTheme.textPrimary, fontSize: r.fs(14)),
          ),
          SizedBox(height: r.s(12)),
          GestureDetector(
            onTap: () => ref.invalidate(userCommunitiesProvider),
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(20), vertical: r.s(10)),
              decoration: BoxDecoration(
                color: context.nexusTheme.accentPrimary,
                borderRadius: BorderRadius.circular(r.s(16)),
              ),
              child: Text(
                s.retry,
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
class _AminoCommunityCard extends ConsumerStatefulWidget {
  final CommunityModel community;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final int reorderIndex;
  /// Largura do card em dp (calculada dinamicamente pelo pai).
  final double cardWidth;

  static const double _iconSize      = 36;
  static const double _iconOverflow  = 18;

  const _AminoCommunityCard({
    required this.community,
    required this.reorderIndex,
    required this.cardWidth,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  ConsumerState<_AminoCommunityCard> createState() =>
      _AminoCommunityCardState();
}

class _AminoCommunityCardState extends ConsumerState<_AminoCommunityCard> {
  bool _isCheckingIn = false;

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return context.nexusTheme.accentPrimary;
    }
  }

  Future<void> _doCheckIn() async {
    if (_isCheckingIn) return;
    final s = ref.read(stringsProvider);
    setState(() => _isCheckingIn = true);

    try {
      final result = await SupabaseService.rpc('daily_checkin', params: {
        'p_community_id': widget.community.id,
      });
      if (!mounted) return;

      // Invalidar o provider para atualizar o status em todos os cards
      ref.invalidate(checkInStatusProvider);

      if (mounted) {
        final data = result as Map<String, dynamic>?;
        if (data != null && data['success'] == true) {
          final streak = data['streak'] as int? ?? 1;
          final coins = data['coins_earned'] as int? ?? 0;
          final levelUp = data['level_up'] as bool? ?? false;
          final newLevel = data['new_level'] as int? ?? 0;
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                s.checkInStreakMsg(streak, coins),
              ),
              backgroundColor: context.nexusTheme.accentSecondary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
          if (levelUp && newLevel > 0 && mounted) {
            LevelUpDialog.show(context, newLevel: newLevel);
          }
        } else if (data != null && data['error'] == 'already_checked_in') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(s.alreadyCheckedInCommunity),
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
            content: Text(s.errorCheckIn),
            backgroundColor: context.nexusTheme.error,
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
    final checkInStatus = ref.watch(checkInStatusProvider);
    final statusMap = checkInStatus.valueOrNull ?? {};
    final myStatus = statusMap[widget.community.id];
    final hasCheckedIn = myStatus?['has_checkin_today'] as bool? ?? false;
    final streak = myStatus?['consecutive_checkin_days'] as int? ?? 0;

    // Dimensões do card
    // cardWidth vem do pai (calculado dinamicamente por LayoutBuilder).
    // cardHeight e bannerHeight são proporcionais à cardWidth para manter
    // a proporção original do design (120 x 175, banner 130).
    final double scaledWidth   = widget.cardWidth;
    // Razão de aspecto original: height/width = 175/120 ≈ 1.458
    final double scaledCardH   = scaledWidth * (175.0 / 120.0);
    // Razão do banner: bannerHeight/cardHeight = 130/175 ≈ 0.743
    final double scaledBannerH = scaledCardH * (130.0 / 175.0);
    final double scaledIconSz  = r.s(_AminoCommunityCard._iconSize);     // 36 (fixo)
    final String? cardBannerUrl = widget.community.bannerForContext('card');

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: SizedBox(
        width: scaledWidth,
        height: scaledCardH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Card principal ocupa toda a altura do SizedBox ──
            Positioned.fill(
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Banner (imagem de capa) — altura fixa escalada para não distorcer
                    SizedBox(
                      height: scaledBannerH,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Imagem com BoxFit.cover garantido
                          cardBannerUrl != null && cardBannerUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: cardBannerUrl,
                                  width: double.infinity,
                                  height: double.infinity,
                                  memCacheWidth: 240,
                                  memCacheHeight: 260,
                                  imageBuilder: (context, imageProvider) => Container(
                                    decoration: BoxDecoration(
                                      image: DecorationImage(
                                        image: imageProvider,
                                        fit: BoxFit.cover,
                                        alignment: Alignment.center,
                                      ),
                                    ),
                                  ),
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
                            height: r.s(52),
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Color(0xDD000000),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          Positioned(
                            top: r.s(6),
                            right: r.s(6),
                            child: ReorderableDelayedDragStartListener(
                              index: widget.reorderIndex,
                              child: Container(
                                padding: EdgeInsets.all(r.s(4)),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.42),
                                  borderRadius: BorderRadius.circular(r.s(999)),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Icon(
                                  Icons.drag_indicator_rounded,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  size: r.s(16),
                                ),
                              ),
                            ),
                          ),

                          // Nome da comunidade
                          Positioned(
                            bottom: 5,
                            left: 6,
                            right: 6,
                            child: Text(
                              widget.community.name,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: r.fs(11),
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                shadows: const [
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
                    Expanded(
                      child: Align(
                        alignment: Alignment.center,
                        child: !hasCheckedIn
                            // Botão CHECK IN
                            ? GestureDetector(
                                onTap: _isCheckingIn ? null : _doCheckIn,
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                      r.s(6), r.s(4), r.s(6), r.s(5)),
                                  child: Container(
                                    width: double.infinity,
                                    padding:
                                        EdgeInsets.symmetric(vertical: r.s(4)),
                                    decoration: BoxDecoration(
                                      color: _isCheckingIn
                                          ? context.nexusTheme.accentSecondary
                                              .withValues(alpha: 0.5)
                                          : context.nexusTheme.accentSecondary,
                                      borderRadius:
                                          BorderRadius.circular(r.s(6)),
                                    ),
                                    child: _isCheckingIn
                                        ? SizedBox(
                                            height: r.s(14),
                                            child: Center(
                                              child: SizedBox(
                                                width: r.s(12),
                                                height: r.s(12),
                                                child:
                                                    CircularProgressIndicator(
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
                            // Streak badge
                            : Padding(
                                padding: EdgeInsets.fromLTRB(
                                    r.s(6), r.s(4), r.s(6), r.s(5)),
                                child: Container(
                                  width: double.infinity,
                                  padding:
                                      EdgeInsets.symmetric(vertical: r.s(3)),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(r.s(6)),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.local_fire_department_rounded,
                                        color: context.nexusTheme.warning,
                                        size: r.s(12),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '$streak dia${streak > 1 ? 's' : ''}',
                                        style: TextStyle(
                                          color: context.nexusTheme.warning,
                                          fontSize: r.fs(9),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Ícone flutuante — sai para cima do card usando top negativo ──
            // O Stack tem clipBehavior: Clip.none, então o ícone pode ultrapassar
            // o limite superior do SizedBox e entrar no espaço do padding.top
            // do ReorderableListView (18px), ficando visualmente "flutuando" acima.
            Positioned(
              top: -r.s(_AminoCommunityCard._iconOverflow),
              left: 4,
              child: Container(
                width: scaledIconSz,
                height: scaledIconSz,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(r.s(8)),
                  // Sem cor de fundo — a imagem preenche 100%
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 6,
                      spreadRadius: 0,
                      offset: const Offset(0, 2),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(r.s(8)),
                  child: widget.community.iconUrl != null &&
                          widget.community.iconUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.community.iconUrl!,
                          fit: BoxFit.cover,
                          width: scaledIconSz,
                          height: scaledIconSz,
                          memCacheWidth: 72,
                          memCacheHeight: 72,
                          placeholder: (_, __) => Container(
                            color: color.withValues(alpha: 0.4),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: color.withValues(alpha: 0.4),
                            child: Icon(Icons.groups_rounded,
                                color: Colors.white, size: r.s(18)),
                          ),
                        )
                      : Container(
                          color: color.withValues(alpha: 0.4),
                          child: Icon(Icons.groups_rounded,
                              color: Colors.white, size: r.s(18)),
                        ),
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
// CARD "ENTRAR EM UMA COMUNIDADE" — translúcido cinza-azulado
// Ícone "+" no topo, texto "Entrar em uma comunidade" centralizado.
// Mesma altura que os cards de comunidade.
// ============================================================================
class _JoinCommunityCard extends ConsumerWidget {
  final VoidCallback onTap;
  /// Largura do card em dp (passada pelo pai).
  final double cardWidth;
  const _JoinCommunityCard({required this.onTap, required this.cardWidth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final double overflow = r.s(_AminoCommunityCard._iconOverflow); // 18 (fixo)
    // cardH proporcional à cardWidth (mesma razão do _AminoCommunityCard)
    final double cardH    = cardWidth * (175.0 / 120.0);

    // O JoinCard fica fora do ReorderableListView (sem padding.top).
    // Para alinhar com os cards de comunidade, usamos Padding.top = overflow.
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: cardWidth,
        height: overflow + cardH,
        child: Padding(
          padding: EdgeInsets.only(top: overflow),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(r.s(10)),
              color: context.nexusTheme.surfaceSecondary.withValues(alpha: 0.5),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
                width: 0.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add,
                  color: Colors.white.withValues(alpha: 0.55),
                  size: r.s(28),
                ),
                SizedBox(height: r.s(10)),
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
        ),
      ),
    );
  }
}

// ============================================================================
// PREVIEW DA COMUNIDADE — Bottom sheet (long press)
// ============================================================================
class _CommunityPreviewSheet extends ConsumerStatefulWidget {
  final CommunityModel community;

  const _CommunityPreviewSheet({
    required this.community,
  });

  @override
  ConsumerState<_CommunityPreviewSheet> createState() =>
      _CommunityPreviewSheetState();
}

class _CommunityPreviewSheetState
    extends ConsumerState<_CommunityPreviewSheet> {
  bool _isCheckingIn = false;

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return context.nexusTheme.accentPrimary;
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  Future<void> _doCheckIn() async {
    if (_isCheckingIn) return;
    final s = ref.read(stringsProvider);
    setState(() => _isCheckingIn = true);

    try {
      final result = await SupabaseService.rpc('daily_checkin', params: {
        'p_community_id': widget.community.id,
      });
      if (!mounted) return;

      ref.invalidate(checkInStatusProvider);

      if (mounted) {
        final data = result as Map<String, dynamic>?;
        if (data != null && data['success'] == true) {
          final streak = data['streak'] as int? ?? 1;
          final coins = data['coins_earned'] as int? ?? 0;
          final levelUp = data['level_up'] as bool? ?? false;
          final newLevel = data['new_level'] as int? ?? 0;
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                s.checkInStreakMsg(streak, coins),
              ),
              backgroundColor: context.nexusTheme.accentSecondary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
          if (levelUp && newLevel > 0 && mounted) {
            LevelUpDialog.show(context, newLevel: newLevel);
          }
        } else if (data != null && data['error'] == 'already_checked_in') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(s.alreadyCheckedInCommunity),
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
            content: Text(s.errorCheckIn),
            backgroundColor: context.nexusTheme.error,
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
      final s = ref.watch(stringsProvider);
    final r = context.r;
    final color = _parseColor(widget.community.themeColor);
    final checkInStatus = ref.watch(checkInStatusProvider);
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
                  child: widget.community.bannerUrl != null &&
                          widget.community.bannerUrl!.isNotEmpty
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
                    color: context.nexusTheme.surfacePrimary,
                    border: Border.all(color: color, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: widget.community.iconUrl != null &&
                          widget.community.iconUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.community.iconUrl ?? '',
                          fit: BoxFit.cover,
                        )
                      : Icon(Icons.groups_rounded,
                          color: context.nexusTheme.textHint, size: r.s(24)),
                ),
                SizedBox(width: r.s(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.community.name,
                        style: TextStyle(
                          color: context.nexusTheme.textPrimary,
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
                            color: context.nexusTheme.textSecondary,
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
                  label:
                      '${_formatCount(widget.community.membersCount)} membros',
                  color: context.nexusTheme.accentSecondary,
                ),
                SizedBox(width: r.s(8)),
                _StatChip(
                  icon: Icons.article_rounded,
                  label: '${_formatCount(widget.community.postsCount)} posts',
                  color: context.nexusTheme.accentPrimary,
                ),
                if (hasCheckedIn && streak > 0) ...[
                  SizedBox(width: r.s(8)),
                  _StatChip(
                    icon: Icons.local_fire_department_rounded,
                    label: '$streak dia${streak > 1 ? 's' : ''}',
                    color: context.nexusTheme.warning,
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
                  color: context.nexusTheme.textSecondary,
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
                        color: context.nexusTheme.accentPrimary,
                        borderRadius: BorderRadius.circular(r.s(8)),
                      ),
                      child: Text(
                        s.openAction,
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
                        color: context.nexusTheme.accentSecondary,
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
                      color: context.nexusTheme.surfacePrimary,
                      borderRadius: BorderRadius.circular(r.s(8)),
                      border: Border.all(
                          color: context.nexusTheme.warning.withValues(alpha: 0.4),
                          width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department_rounded,
                            color: context.nexusTheme.warning, size: r.s(16)),
                        SizedBox(width: r.s(4)),
                        Text(
                          '$streak dia${streak > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: context.nexusTheme.warning,
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

class _StatChip extends ConsumerWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
