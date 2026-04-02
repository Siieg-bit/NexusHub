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

/// Drawer estilo Amino — layout fiel aos prints de referência.
///
/// Estrutura:
///   [Sidebar esquerda 56px] | [Painel principal]
///
/// Painel principal:
///   1. Header: banner da comunidade + avatar do usuário + nome + Check In
///   2. Menu principal: Home, My Chats, Let's Chat!, Shared Folder
///   3. Seção de membros: lista com avatar, nome e subtítulo
///   4. Seção Options: My Saved Posts
///   5. Bottom bar fixa: All Members | Alerts | Compose
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
    Navigator.pop(context);
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
                    child: Column(
                      children: [
                        // Conteúdo scrollável
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // 1. Header: banner + avatar + nome + check-in
                                _buildHeader(r, themeColor, hasCheckedIn,
                                    streak),
                                // 2. Menu principal
                                _buildMainMenu(r, themeColor),
                                // 3. Botão de membros
                                _buildMembersSection(r, const AsyncData([])),
                                // 4. Options
                                _buildOptionsSection(r),
                                // Staff
                                if (_isStaff) _buildStaffSection(r),
                                SizedBox(height: r.s(80)),
                              ],
                            ),
                          ),
                        ),

                      ],
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
              Navigator.pop(context);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) context.go('/communities');
              });
            },
            child: Column(
              children: [
                Icon(Icons.logout_rounded,
                    color: Colors.grey[600], size: r.s(18)),
                const SizedBox(height: 2),
                Text('Sair',
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: r.fs(8),
                        fontWeight: FontWeight.w500)),
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
                            // Indicador de comunidade atual
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
                                shape: BoxShape.circle,
                                border: isCurrent
                                    ? Border.all(
                                        color: AppTheme.primaryColor, width: 2)
                                    : null,
                                image: community.iconUrl != null
                                    ? DecorationImage(
                                        image: CachedNetworkImageProvider(
                                            community.iconUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                color: community.iconUrl == null
                                    ? AppTheme.primaryColor.withValues(alpha: 0.3)
                                    : null,
                              ),
                              child: community.iconUrl == null
                                  ? Icon(Icons.people_rounded,
                                      color: Colors.white, size: r.s(16))
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
  // HEADER: banner + avatar + nome + check-in
  // ---------------------------------------------------------------------------
  Widget _buildHeader(
      Responsive r, Color themeColor, bool hasCheckedIn, int streak) {
    final user = widget.currentUser;
    return Stack(
      children: [
        // Banner da comunidade (fundo personalizável pelos líderes)
        Container(
          height: r.s(220),
          decoration: BoxDecoration(
            color: themeColor.withValues(alpha: 0.9),
            image: widget.community.bannerUrl != null
                ? DecorationImage(
                    image: CachedNetworkImageProvider(
                        widget.community.bannerUrl!),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.35), BlendMode.darken),
                  )
                : null,
          ),
        ),
        // Gradiente inferior suave
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: r.s(100),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.75),
                ],
              ),
            ),
          ),
        ),
        // Avatar + nome + streak + check-in
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: r.s(20)),
            child: Column(
              children: [
                // Avatar circular do usuário
                Container(
                  width: r.s(80),
                  height: r.s(80),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3), width: 3),
                    color: themeColor.withValues(alpha: 0.5),
                    image: user?.iconUrl != null
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(user!.iconUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: user?.iconUrl == null
                      ? Icon(Icons.person_rounded,
                          color: Colors.white, size: r.s(40))
                      : null,
                ),
                SizedBox(height: r.s(8)),
                // Nome do usuário
                Text(
                  user?.nickname ?? 'Visitante',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: r.fs(16),
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 4)
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: r.s(12)),
                // Botão Check In OU barra de streak
                if (!hasCheckedIn)
                  GestureDetector(
                    onTap: _isCheckingIn ? null : _doCheckIn,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: r.s(12)),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(r.s(10)),
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
                                  fontSize: r.fs(15),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  )
                else
                  _buildStreakBar(r, streak),
                SizedBox(height: r.s(16)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // MENU PRINCIPAL
  // ---------------------------------------------------------------------------
  Widget _buildMainMenu(Responsive r, Color themeColor) {
    return Column(
      children: [
        _DrawerTile(
          icon: Icons.home_rounded,
          label: 'Início',
          onTap: () => _closeAndNavigate(() {}),
        ),
        _DrawerTile(
          icon: Icons.chat_bubble_rounded,
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
          label: 'Pasta Compartilhada',
          onTap: () => _closeAndNavigate(() {
            context.push(
                '/community/${widget.community.id}/shared-folder');
          }),
        ),
        Divider(
          color: context.dividerClr,
          height: r.s(1),
          indent: r.s(16),
          endIndent: r.s(16),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BOTÃO DE MEMBROS
  // ---------------------------------------------------------------------------
  Widget _buildMembersSection(
      Responsive r, AsyncValue<List<Map<String, dynamic>>> membersAsync) {
    return Column(
      children: [
        _DrawerTile(
          icon: Icons.group_rounded,
          label: 'Ver Membros',
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/members');
          }),
        ),
        Divider(
          color: context.dividerClr,
          height: r.s(1),
          indent: r.s(16),
          endIndent: r.s(16),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // OPTIONS
  // ---------------------------------------------------------------------------
  Widget _buildOptionsSection(Responsive r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(r.s(16), r.s(12), r.s(16), r.s(4)),
          child: Text(
            'OPÇÕES',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: r.fs(12),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        _DrawerTile(
          icon: Icons.bookmark_rounded,
          label: 'Posts Salvos',
          onTap: () => _closeAndNavigate(() {
            context.push('/profile/${SupabaseService.currentUserId}');
          }),
        ),
        _DrawerTile(
          icon: Icons.auto_stories_rounded,
          label: 'Wiki',
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/wiki');
          }),
        ),
        _DrawerTile(
          icon: Icons.leaderboard_rounded,
          label: 'Ranking',
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/leaderboard');
          }),
        ),
        Divider(
          color: context.dividerClr,
          height: r.s(1),
          indent: r.s(16),
          endIndent: r.s(16),
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
          padding: EdgeInsets.fromLTRB(r.s(16), r.s(12), r.s(16), r.s(4)),
          child: Text(
            'GERENCIAMENTO',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: r.fs(10),
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        if (_isLeader)
          _DrawerTile(
            icon: Icons.settings_rounded,
            label: 'Editar Comunidade',
            onTap: () => _closeAndNavigate(() {
              context.push('/community/${widget.community.id}/acm');
            }),
          ),
        _DrawerTile(
          icon: Icons.flag_rounded,
          label: 'Central de Denúncias',
          isDestructive: true,
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/flags');
          }),
        ),
        _DrawerTile(
          icon: Icons.analytics_rounded,
          label: 'Estatísticas',
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/acm');
          }),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BARRA DE STREAK — exibida após o check-in no lugar do botão
  // ---------------------------------------------------------------------------
  Widget _buildStreakBar(Responsive r, int streak) {
    const totalDots = 7;
    final doneDots = streak.clamp(0, totalDots);
    return Column(
      children: [
        // LayoutBuilder garante que as bolinhas nunca excedam a largura disponível
        LayoutBuilder(
          builder: (context, constraints) {
            // Calcula o tamanho máximo de cada bolinha para caber todas na largura
            final maxDotSize = ((constraints.maxWidth - r.s(6) * totalDots * 2) / totalDots)
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
        SizedBox(height: r.s(5)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_fire_department_rounded,
                color: AppTheme.warningColor, size: r.s(13)),
            SizedBox(width: r.s(3)),
            Flexible(
              child: Text(
                '$streak dia${streak != 1 ? 's' : ''} de sequência',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: r.fs(11),
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
// DRAWER TILE — Item de menu com ícone circular estilo Amino
// =============================================================================
class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final color = isDestructive ? AppTheme.errorColor : context.textPrimary;
    final iconBg = isDestructive
        ? AppTheme.errorColor.withValues(alpha: 0.15)
        : Colors.white.withValues(alpha: 0.08);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: r.s(16), vertical: r.s(13)),
        child: Row(
          children: [
            // Ícone dentro de círculo escuro
            Container(
              width: r.s(42),
              height: r.s(42),
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: r.s(20)),
            ),
            SizedBox(width: r.s(14)),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: r.fs(16),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

