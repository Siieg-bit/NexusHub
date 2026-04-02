import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/helpers.dart';
import '../providers/community_shared_providers.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/amino_drawer.dart';

/// Drawer estilo Amino — fiel ao app original.
///
/// Estrutura:
///   [Sidebar esquerda 56px] | [Painel principal flex-1 (resto da tela)]
///
/// Painel principal:
///   1. Header: banner retangular da comunidade no topo + fundo = imagem da comunidade
///      + avatar do usuário centralizado + nome + badge de nível + barra de reputação + streak
///   2. Menu principal: lista com fundo semi-transparente, ícones coloridos
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

    return Container(
      color: context.scaffoldBg,
      child: SafeArea(
        child: Row(
          children: [
            // ============================================================
            // SIDEBAR ESQUERDA — Lista de comunidades do usuário (56px)
            // ============================================================
            _buildLeftSidebar(r, userCommunitiesAsync),

            // ============================================================
            // PAINEL PRINCIPAL — ocupa todo o espaço restante
            // ============================================================
            Expanded(
              child: Column(
                children: [
                  // 1. Header: banner + avatar + nome + nível + streak
                  _buildHeader(r, themeColor, hasCheckedIn, streak),
                  // 2. Menu principal (scrollável)
                  Expanded(
                    child: Container(
                      color: context.scaffoldBg.withValues(alpha: 0.92),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: r.s(4)),
                            _buildMainMenu(r),
                            _buildSeeMore(r),
                            if (_isStaff) _buildStaffSection(r),
                            SizedBox(height: r.s(40)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                              width: r.s(40),
                              height: r.s(40),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(r.s(10)),
                                color: Colors.grey[800],
                                image: community.iconUrl != null
                                    ? DecorationImage(
                                        image: CachedNetworkImageProvider(
                                            community.iconUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
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
  // HEADER — banner da comunidade + avatar + nome + nível + streak
  // Fiel ao Amino: imagem de fundo, avatar centralizado, nome, badge, streak
  // ---------------------------------------------------------------------------
  Widget _buildHeader(
      Responsive r, Color themeColor, bool hasCheckedIn, int streak) {
    final user = widget.currentUser;
    final screenHeight = MediaQuery.of(context).size.height;
    // Header ocupa ~38% da tela (como no Amino original)
    final headerHeight = (screenHeight * 0.38).clamp(260.0, 380.0);

    return SizedBox(
      height: headerHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Fundo: imagem da comunidade (bannerUrl) cobrindo toda a área ──
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
          // ── Gradiente escuro para legibilidade ──────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.5, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.75),
                ],
              ),
            ),
          ),
          // ── Ícone de busca no topo direito (como no Amino) ─────────────
          Positioned(
            top: r.s(8),
            right: r.s(12),
            child: GestureDetector(
              onTap: () => _closeAndNavigate(() {
                context.push('/community/${widget.community.id}/search');
              }),
              child: Container(
                width: r.s(36),
                height: r.s(36),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.search_rounded,
                    color: Colors.white, size: r.s(20)),
              ),
            ),
          ),
          // ── Conteúdo do header ──────────────────────────────────────────
          Column(
            children: [
              // Banner retangular pequeno da comunidade no topo
              if (widget.community.iconUrl != null)
                Container(
                  height: r.s(60),
                  margin: EdgeInsets.fromLTRB(r.s(16), r.s(10), r.s(16), 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(r.s(8)),
                    color: Colors.white.withValues(alpha: 0.1),
                    image: widget.community.iconUrl != null
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(
                                widget.community.iconUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                ),
              SizedBox(height: r.s(12)),
              // Avatar do usuário centralizado (grande, como no Amino)
              Container(
                width: r.s(80),
                height: r.s(80),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4), width: 3),
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
                  fontSize: r.fs(17),
                  fontWeight: FontWeight.w800,
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: r.s(6)),
              // Badge de nível + barra de reputação
              if (user != null) _buildLevelBadge(r, user),
              SizedBox(height: r.s(10)),
              // Dots de streak (7 dias como no Amino)
              _buildStreakDots(r, streak, hasCheckedIn),
              if (!hasCheckedIn) ...[
                SizedBox(height: r.s(6)),
                GestureDetector(
                  onTap: _isCheckingIn ? null : _doCheckIn,
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: r.s(16)),
                    padding: EdgeInsets.symmetric(vertical: r.s(6)),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(r.s(20)),
                    ),
                    child: Center(
                      child: Text(
                        _isCheckingIn
                            ? 'Fazendo check-in...'
                            : '⚠️ Check-in perdido. Toque para recuperar!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: r.fs(10),
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BADGE DE NÍVEL + BARRA DE REPUTAÇÃO (estilo Amino)
  // ---------------------------------------------------------------------------
  Widget _buildLevelBadge(Responsive r, UserModel user) {
    final level = user.level;
    final reputation = user.reputation;
    final levelColor = AppTheme.getLevelColor(level);
    final levelName = levelTitle(level);
    // Reputação necessária para o próximo nível (exemplo: 100 * level)
    final repForNextLevel = 100 * (level + 1);
    final repProgress = (reputation % repForNextLevel) / repForNextLevel;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.s(24)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Badge circular com nível
          Container(
            width: r.s(30),
            height: r.s(30),
            decoration: BoxDecoration(
              color: levelColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$level',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.fs(12),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          SizedBox(width: r.s(8)),
          // Pill com nome do nível + barra de progresso
          Expanded(
            child: Container(
              height: r.s(26),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(r.s(13)),
              ),
              padding: EdgeInsets.symmetric(horizontal: r.s(10)),
              child: Row(
                children: [
                  Text(
                    levelName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.fs(10),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: r.s(6)),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: repProgress.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: levelColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DOTS DE STREAK (7 dias) — idêntico ao Amino original
  // ---------------------------------------------------------------------------
  Widget _buildStreakDots(Responsive r, int streak, bool hasCheckedIn) {
    const totalDots = 7;
    final doneDots = streak.clamp(0, totalDots);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.s(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalDots, (i) {
          final done = i < doneDots;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: r.s(3)),
            child: Container(
              width: r.s(18),
              height: r.s(18),
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
                      color: Colors.white, size: r.s(11))
                  : null,
            ),
          );
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MENU PRINCIPAL — Fiel ao Amino original (Home, My Chats, Public Chatrooms,
  // Leaderboards, Wiki, Shared Folder, Stories)
  // ---------------------------------------------------------------------------
  Widget _buildMainMenu(Responsive r) {
    return Column(
      children: [
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
          iconColor: const Color(0xFF66BB6A), // verde (como no Amino)
          label: 'Salas de Chat Públicas',
          onTap: () => _closeAndNavigate(() {
            context.push('/create-public-chat', extra: {
              'communityId': widget.community.id,
              'communityName': widget.community.name,
            });
          }),
        ),
        _DrawerTile(
          icon: Icons.leaderboard_rounded,
          iconColor: const Color(0xFFAB47BC), // roxo
          label: 'Ranking',
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/leaderboard');
          }),
        ),
        _DrawerTile(
          icon: Icons.auto_stories_rounded,
          iconColor: const Color(0xFFAB47BC), // roxo
          label: 'Wiki',
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/wiki');
          }),
        ),
        _DrawerTile(
          icon: Icons.folder_shared_rounded,
          iconColor: const Color(0xFF42A5F5), // azul
          label: 'Pasta Compartilhada',
          onTap: () => _closeAndNavigate(() {
            context
                .push('/community/${widget.community.id}/shared-folder');
          }),
        ),
        _DrawerTile(
          icon: Icons.amp_stories_rounded,
          iconColor: const Color(0xFFAB47BC), // roxo
          label: 'Stories',
          onTap: () => _closeAndNavigate(() {
            // Stories — navega para o perfil onde stories ficam
            context.push('/profile/${SupabaseService.currentUserId}');
          }),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SEE MORE + OPÇÕES EXTRAS
  // ---------------------------------------------------------------------------
  Widget _buildSeeMore(Responsive r) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/info');
          }),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: r.s(16),
              vertical: r.s(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Ver Mais...',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: r.fs(14),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: Colors.grey[600], size: r.s(20)),
              ],
            ),
          ),
        ),
        // Divider sutil
        Container(
          margin: EdgeInsets.symmetric(horizontal: r.s(16)),
          height: 1,
          color: Colors.white.withValues(alpha: 0.05),
        ),
        SizedBox(height: r.s(4)),
        // Membros
        _DrawerTile(
          icon: Icons.group_rounded,
          iconColor: const Color(0xFF26C6DA), // ciano
          label: 'Ver Membros',
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/members');
          }),
        ),
        // Posts Salvos
        _DrawerTile(
          icon: Icons.bookmark_rounded,
          iconColor: const Color(0xFFEF5350), // vermelho
          label: 'Posts Salvos',
          onTap: () => _closeAndNavigate(() {
            context.push('/profile/${SupabaseService.currentUserId}');
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
        // Divider
        Container(
          margin: EdgeInsets.symmetric(horizontal: r.s(16)),
          height: 1,
          color: Colors.white.withValues(alpha: 0.05),
        ),
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
}

// =============================================================================
// DRAWER TILE — Item de menu estilo Amino com ícone circular colorido
// Tamanhos maiores para combinar com o painel mais largo
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
            // Ícone dentro de círculo colorido (estilo Amino — tamanho grande)
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
