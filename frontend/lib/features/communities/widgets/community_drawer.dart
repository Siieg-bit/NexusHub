import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/supabase_service.dart';
import '../providers/community_shared_providers.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/amino_drawer.dart';

/// Drawer estilo Amino — layout fiel ao app de referência.
///
/// Estrutura:
///   [Sidebar esquerda 56px] | [Painel principal]
///
/// Painel principal:
///   1. Header: banner (~45% da tela) + avatar + nome + Check In / streak
///   2. Menu principal: lista limpa sem separadores, ícones coloridos
///   3. Seções secundárias: Membros, Opções, Staff
class CommunityDrawer extends ConsumerStatefulWidget {
  final CommunityModel community;
  final UserModel? currentUser;
  final String? userRole;

  const CommunityDrawer({
    super.key,
    required this.community,
    this.currentUser,
    this.userRole,
  });

  @override
  ConsumerState<CommunityDrawer> createState() => _CommunityDrawerState();
}

class _CommunityDrawerState extends ConsumerState<CommunityDrawer> {
  bool _isCheckingIn = false;

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  bool get _isTeamMember => widget.currentUser?.isTeamMember ?? false;

  bool get _isStaff =>
      _isTeamMember ||
      widget.userRole == 'agent' ||
      widget.userRole == 'leader' ||
      widget.userRole == 'curator' ||
      widget.userRole == 'moderator' ||
      widget.userRole == 'admin';

  bool get _isLeader =>
      _isTeamMember ||
      widget.userRole == 'agent' ||
      widget.userRole == 'leader';

  Future<void> _doCheckIn() async {
    if (_isCheckingIn) return;
    setState(() => _isCheckingIn = true);
    try {
      final result = await SupabaseService.rpc('daily_checkin', params: {
        'p_community_id': widget.community.id,
      });
      if (!mounted) return;
      ref.invalidate(checkInStatusProvider);
      final data = result as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        final streak = data['streak'] as int? ?? 1;
        final coins = data['coins_earned'] as int? ?? 0;
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Check-in feito! Sequência: $streak dia${streak > 1 ? 's' : ''} (+$coins moedas)'),
          backgroundColor: AppTheme.accentColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      } else if (data != null && data['error'] == 'already_checked_in') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Você já fez check-in hoje nesta comunidade!'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Erro no check-in. Tente novamente.'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isCheckingIn = false);
    }
  }

  void _closeAndNavigate(VoidCallback action) {
    final ctrl = AminoDrawerController.of(context);
    if (ctrl != null && ctrl.isOpen) {
      ctrl.close();
    } else {
      Navigator.maybePop(context);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) action();
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final themeColor = _parseColor(widget.community.themeColor);
    final checkInStatus = ref.watch(checkInStatusProvider);
    final statusMap = checkInStatus.valueOrNull ?? {};
    final myStatus = statusMap[widget.community.id];
    final hasCheckedIn = myStatus?['has_checkin_today'] as bool? ?? false;
    final streak = myStatus?['consecutive_checkin_days'] as int? ?? 0;
    final userCommunitiesAsync = ref.watch(userCommunitiesProvider);

    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final availableWidth = outerConstraints.maxWidth.isFinite
            ? outerConstraints.maxWidth
            : MediaQuery.of(context).size.width * 0.85;
        return ConstrainedBox(
          constraints: BoxConstraints.tightFor(width: availableWidth),
          child: Container(
            color: context.scaffoldBg,
            child: SafeArea(
              child: Row(
                children: [
                  // ============================================================
                  // SIDEBAR ESQUERDA — Lista de comunidades do usuário (56px)
                  // ============================================================
                  _buildLeftSidebar(r, userCommunitiesAsync),

                  // ============================================================
                  // PAINEL PRINCIPAL
                  // ============================================================
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Header: banner + avatar + nome + check-in
                          _buildHeader(r, themeColor, hasCheckedIn, streak),
                          // 2. Menu principal (sem separadores)
                          _buildMainMenu(r),
                          // 3. Membros
                          _buildMembersSection(r),
                          // 4. Opções
                          _buildOptionsSection(r),
                          // 5. Staff (apenas para moderadores/líderes)
                          if (_isStaff) _buildStaffSection(r),
                          SizedBox(height: r.s(40)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SIDEBAR ESQUERDA
  // ---------------------------------------------------------------------------
  Widget _buildLeftSidebar(
      Responsive r, AsyncValue<List<CommunityModel>> userCommunitiesAsync) {
    return Container(
      width: r.s(56),
      decoration: BoxDecoration(
        color: const Color(0xFF060D18),
        border: Border(
          right: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          SizedBox(height: r.s(10)),
          // Botão sair
          GestureDetector(
            onTap: () {
              final ctrl = AminoDrawerController.of(context);
              if (ctrl != null && ctrl.isOpen) ctrl.close();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) context.go('/communities');
              });
            },
            child: Column(
              children: [
                Icon(Icons.logout_rounded,
                    color: Colors.grey[600], size: r.s(18)),
                const SizedBox(height: 2),
                Text(
                  'Sair',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: r.fs(8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r.s(8)),
          Container(
            width: r.s(32),
            height: 1,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          SizedBox(height: r.s(8)),
          Expanded(
            child: userCommunitiesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (communities) => SingleChildScrollView(
                child: Column(
                  children: communities.map((community) {
                    final isCurrent = community.id == widget.community.id;
                    return GestureDetector(
                      onTap: () {
                        if (!isCurrent) {
                          final ctrl = AminoDrawerController.of(context);
                          if (ctrl != null && ctrl.isOpen) ctrl.close();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (context.mounted) {
                              context
                                  .pushReplacement('/community/${community.id}');
                            }
                          });
                        }
                      },
                      child: Container(
                        margin: EdgeInsets.only(bottom: r.s(6)),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (isCurrent)
                              Positioned(
                                left: 0,
                                child: Container(
                                  width: 3,
                                  height: r.s(36),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            Container(
                              width: r.s(36),
                              height: r.s(36),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                    isCurrent ? r.s(10) : r.s(18)),
                                color: Colors.grey[800],
                                image: community.iconUrl != null
                                    ? DecorationImage(
                                        image: CachedNetworkImageProvider(
                                            community.iconUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: community.iconUrl == null
                                  ? Icon(Icons.people_rounded,
                                      color: Colors.grey[400], size: r.s(18))
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER — ocupa ~45% da altura da tela (igual ao Amino)
  // ---------------------------------------------------------------------------
  Widget _buildHeader(
      Responsive r, Color themeColor, bool hasCheckedIn, int streak) {
    final user = widget.currentUser;
    final screenHeight = MediaQuery.of(context).size.height;
    // Header ocupa ~45% da tela, mínimo 260px, máximo 380px
    final headerHeight = (screenHeight * 0.45).clamp(260.0, 380.0);

    return SizedBox(
      height: headerHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Banner da comunidade (fundo personalizável) ──────────────────
          Container(
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.9),
              image: widget.community.bannerUrl != null
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(
                          widget.community.bannerUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
          ),
          // ── Gradiente escuro de baixo para cima ──────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.45, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.88),
                ],
              ),
            ),
          ),
          // ── Avatar + nome + check-in (ancorado na parte inferior) ────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(r.s(20), 0, r.s(20), r.s(20)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar circular grande
                  Container(
                    width: r.s(88),
                    height: r.s(88),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 3),
                      color: themeColor.withValues(alpha: 0.5),
                      image: user?.iconUrl != null
                          ? DecorationImage(
                              image:
                                  CachedNetworkImageProvider(user!.iconUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: user?.iconUrl == null
                        ? Icon(Icons.person_rounded,
                            color: Colors.white, size: r.s(44))
                        : null,
                  ),
                  SizedBox(height: r.s(10)),
                  // Nome do usuário
                  Text(
                    user?.nickname ?? 'Visitante',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.fs(18),
                      fontWeight: FontWeight.w800,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 6)
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: r.s(14)),
                  // Botão Check In OU barra de streak
                  if (!hasCheckedIn)
                    GestureDetector(
                      onTap: _isCheckingIn ? null : _doCheckIn,
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: r.s(14)),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(r.s(30)),
                        ),
                        child: Center(
                          child: _isCheckingIn
                              ? SizedBox(
                                  width: r.s(18),
                                  height: r.s(18),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Check In',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: r.fs(16),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    )
                  else
                    _buildStreakBar(r, streak),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MENU PRINCIPAL — lista limpa sem separadores, ícones coloridos
  // ---------------------------------------------------------------------------
  Widget _buildMainMenu(Responsive r) {
    return Column(
      children: [
        SizedBox(height: r.s(8)),
        _DrawerTile(
          icon: Icons.home_rounded,
          iconColor: const Color(0xFF42A5F5), // azul
          label: 'Início',
          onTap: () => _closeAndNavigate(() {}),
        ),
        _DrawerTile(
          icon: Icons.chat_bubble_rounded,
          iconColor: const Color(0xFF66BB6A), // verde
          label: 'Meus Chats',
          onTap: () => _closeAndNavigate(() {
            context.push(
              '/community/${widget.community.id}/my-chats',
              extra: {'communityName': widget.community.name},
            );
          }),
        ),
        _DrawerTile(
          icon: Icons.forum_rounded,
          iconColor: const Color(0xFFAB47BC), // roxo
          label: 'Vamos Conversar!',
          onTap: () => _closeAndNavigate(() {
            context.push('/create-public-chat', extra: {
              'communityId': widget.community.id,
              'communityName': widget.community.name,
            });
          }),
        ),
        _DrawerTile(
          icon: Icons.folder_shared_rounded,
          iconColor: const Color(0xFFFFA726), // laranja
          label: 'Pasta Compartilhada',
          onTap: () => _closeAndNavigate(() {
            context
                .push('/community/${widget.community.id}/shared-folder');
          }),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // MEMBROS
  // ---------------------------------------------------------------------------
  Widget _buildMembersSection(Responsive r) {
    return Column(
      children: [
        _DrawerTile(
          icon: Icons.group_rounded,
          iconColor: const Color(0xFF26C6DA), // ciano
          label: 'Ver Membros',
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/members');
          }),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // OPÇÕES
  // ---------------------------------------------------------------------------
  Widget _buildOptionsSection(Responsive r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(r.s(20), r.s(16), r.s(20), r.s(4)),
          child: Text(
            'OPÇÕES',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: r.fs(11),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        _DrawerTile(
          icon: Icons.bookmark_rounded,
          iconColor: const Color(0xFFEF5350), // vermelho
          label: 'Posts Salvos',
          onTap: () => _closeAndNavigate(() {
            context.push('/profile/${SupabaseService.currentUserId}');
          }),
        ),
        _DrawerTile(
          icon: Icons.auto_stories_rounded,
          iconColor: const Color(0xFF8D6E63), // marrom
          label: 'Wiki',
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/wiki');
          }),
        ),
        _DrawerTile(
          icon: Icons.leaderboard_rounded,
          iconColor: const Color(0xFFFFCA28), // amarelo
          label: 'Ranking',
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/leaderboard');
          }),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STAFF
  // ---------------------------------------------------------------------------
  Widget _buildStaffSection(Responsive r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(r.s(20), r.s(16), r.s(20), r.s(4)),
          child: Text(
            'GERENCIAMENTO',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: r.fs(11),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        if (_isLeader)
          _DrawerTile(
            icon: Icons.settings_rounded,
            iconColor: const Color(0xFF78909C), // cinza azulado
            label: 'Editar Comunidade',
            onTap: () => _closeAndNavigate(() {
              context.push('/community/${widget.community.id}/acm');
            }),
          ),
        _DrawerTile(
          icon: Icons.flag_rounded,
          iconColor: AppTheme.errorColor,
          label: 'Central de Denúncias',
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/flags');
          }),
        ),
        _DrawerTile(
          icon: Icons.analytics_rounded,
          iconColor: const Color(0xFF26A69A), // teal
          label: 'Estatísticas',
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/acm');
          }),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BARRA DE STREAK
  // ---------------------------------------------------------------------------
  Widget _buildStreakBar(Responsive r, int streak) {
    const totalDots = 7;
    final doneDots = streak.clamp(0, totalDots);
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final maxDotSize =
                ((constraints.maxWidth - r.s(6) * totalDots * 2) / totalDots)
                    .clamp(r.s(18), r.s(28));
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalDots, (i) {
                final done = i < doneDots;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: r.s(3)),
                  child: Container(
                    width: maxDotSize,
                    height: maxDotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? const Color(0xFF4CAF50)
                          : Colors.white.withValues(alpha: 0.15),
                      border: Border.all(
                        color: done
                            ? const Color(0xFF4CAF50)
                            : Colors.white.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: done
                        ? Icon(Icons.check_rounded,
                            color: Colors.white, size: maxDotSize * 0.55)
                        : null,
                  ),
                );
              }),
            );
          },
        ),
        SizedBox(height: r.s(6)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_fire_department_rounded,
                color: AppTheme.warningColor, size: r.s(14)),
            SizedBox(width: r.s(4)),
            Flexible(
              child: Text(
                '$streak dia${streak != 1 ? 's' : ''} de sequência',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: r.fs(12),
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// DRAWER TILE — Item de menu estilo Amino com ícone circular colorido
// =============================================================================
class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: r.s(16),
          vertical: r.s(10),
        ),
        child: Row(
          children: [
            // Ícone dentro de círculo colorido (estilo Amino)
            Container(
              width: r.s(46),
              height: r.s(46),
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: r.s(22)),
            ),
            SizedBox(width: r.s(16)),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.fs(17),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
