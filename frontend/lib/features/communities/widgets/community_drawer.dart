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

// =============================================================================
// COMMUNITY DRAWER — Réplica fiel do painel lateral do Amino Apps
//
// Layout (análise forense do print original):
//
//   ┌──────┬────────────────────────────────────────────┐
//   │ Exit │  [Banner retangular da comunidade]    🔍  │
//   │      │                                           │
//   │  ●   │         ┌──────────┐                      │
//   │  ●   │         │  Avatar  │                      │
//   │  ●   │         └──────────┘                      │
//   │  ●   │           Cole19                          │
//   │  ●   │      Lv2  Anti Newbie ████░░░             │
//   │  ●   │      ● ○ ○ ○ ○ ○ ○  (streak dots)       │
//   │  ●   │  Check-in streak lost. Tap here to fix it!│
//   │      ├───────────────────────────────────────────│
//   │      │  🏠 Home                                  │
//   │      │  💬 My Chats                         6    │
//   │      │  🗣️ Public Chatrooms                      │
//   │      │  🏆 Leaderboards                          │
//   │      │  📖 Wiki                                  │
//   │      │  📁 Shared Folder                         │
//   │      │  📱 Stories                               │
//   │      │                                           │
//   │      │  See More...                          >   │
//   └──────┴───────────────────────────────────────────┘
//
// Sidebar esquerda: ~52-56px, fundo preto puro, ícones ~42px com badges
// Painel principal: flex-1, imagem de fundo da comunidade no header
// =============================================================================

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

  // ── Helpers ────────────────────────────────────────────────────────────────

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

  // ── Check-in ──────────────────────────────────────────────────────────────

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

  // ── Navegação ─────────────────────────────────────────────────────────────

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

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

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
      // Fundo escuro base (igual ao Amino: preto/quase preto)
      color: const Color(0xFF000000),
      child: SafeArea(
        child: Row(
          children: [
            // ══════════════════════════════════════════════════════════════
            // SIDEBAR ESQUERDA — Comunidades do usuário (~52px)
            // No Amino: fundo preto puro, ícones ~42px, badges vermelhos
            // ══════════════════════════════════════════════════════════════
            _buildLeftSidebar(r, userCommunitiesAsync),

            // ══════════════════════════════════════════════════════════════
            // PAINEL PRINCIPAL — Ocupa todo o espaço restante
            // No Amino: imagem de fundo da comunidade no header,
            // menu com fundo escuro semi-transparente
            // ══════════════════════════════════════════════════════════════
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  children: [
                    // Header: imagem de fundo + avatar + nome + nível + streak
                    _buildHeader(r, themeColor, hasCheckedIn, streak),
                    // Menu principal (sem scroll próprio)
                    _buildMenuArea(r),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SIDEBAR ESQUERDA
  //
  // Amino original:
  // - Fundo: preto puro (#000000)
  // - Topo: ícone de porta + "Exit" em cinza
  // - Ícones: ~42px, borderRadius ~12px
  // - Badges: círculos vermelhos (#FF0000) com número branco, ~16px
  // - Sem borda direita visível
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLeftSidebar(
      Responsive r, AsyncValue<List<CommunityModel>> userCommunitiesAsync) {
    return Container(
      width: r.s(52),
      color: const Color(0xFF000000),
      child: Column(
        children: [
          SizedBox(height: r.s(6)),
          // ── Botão Exit (estilo Amino: ícone + "Exit") ──────────────────
          GestureDetector(
            onTap: () {
              final ctrl = AminoDrawerController.of(context);
              if (ctrl != null && ctrl.isOpen) ctrl.close();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) context.go('/communities');
              });
            },
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: r.s(4)),
              child: Column(
                children: [
                  Icon(Icons.door_front_door_outlined,
                      color: Colors.grey[500], size: r.s(18)),
                  SizedBox(height: r.s(1)),
                  Text(
                    'Exit',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: r.fs(8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: r.s(6)),
          // ── Lista de comunidades ───────────────────────────────────────
          Expanded(
            child: userCommunitiesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (communities) => SingleChildScrollView(
                child: Column(
                  children: communities.map((community) {
                    final isCurrent = community.id == widget.community.id;
                    return _buildSidebarCommunityIcon(r, community, isCurrent);
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ícone individual de comunidade na sidebar com badge de notificação
  Widget _buildSidebarCommunityIcon(
      Responsive r, CommunityModel community, bool isCurrent) {
    // TODO: Integrar com provider de unread count por comunidade quando disponível
    // Por enquanto, não mostramos badge (como no Amino quando não há notificações)
    return GestureDetector(
      onTap: () {
        if (!isCurrent) {
          final ctrl = AminoDrawerController.of(context);
          if (ctrl != null && ctrl.isOpen) ctrl.close();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.pushReplacement('/community/${community.id}');
            }
          });
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: r.s(4)),
        padding: EdgeInsets.symmetric(horizontal: r.s(4)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Ícone da comunidade (42px, borderRadius 12px — como no Amino)
            Container(
              width: r.s(42),
              height: r.s(42),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r.s(12)),
                color: Colors.grey[850],
                image: community.iconUrl != null
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(community.iconUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                // No Amino, a comunidade ativa tem uma borda branca sutil
                border: isCurrent
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 2,
                      )
                    : null,
              ),
              child: community.iconUrl == null
                  ? Center(
                      child: Text(
                        community.name.isNotEmpty
                            ? community.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: r.fs(16),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADER — Fundo com imagem da comunidade
  //
  // Amino original:
  // - Imagem de fundo: bannerUrl/iconUrl da comunidade, cover, toda a área
  // - Gradiente: de transparente (topo) a preto (base)
  // - Banner retangular: capa da comunidade no topo (~55px altura)
  // - Ícone de busca: canto superior direito, círculo escuro semi-transparente
  // - Avatar: ~75px, borda branca fina (~2px), centralizado
  // - Nome: branco, bold, ~16px, sombra
  // - Badge de nível: círculo verde "Lv2" + pill escura "Anti Newbie" + barra
  // - Streak dots: 7 dots, ~14px, verde = feito, cinza = pendente
  // - Mensagem: TEXTO VERDE (não container vermelho!)
  //   "Check-in streak lost. Tap here to fix it!"
  // - Header ocupa ~42-45% da tela
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader(
      Responsive r, Color themeColor, bool hasCheckedIn, int streak) {
    final user = widget.currentUser;
    final screenHeight = MediaQuery.of(context).size.height;
    // Header ocupa ~43% da tela (fiel ao Amino)
    final headerHeight = (screenHeight * 0.43).clamp(280.0, 400.0);

    return SizedBox(
      height: headerHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Fundo: imagem da comunidade cobrindo toda a área ────────────
          Container(
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: 0.9),
              image: widget.community.bannerUrl != null
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(
                          widget.community.bannerUrl!),
                      fit: BoxFit.cover,
                    )
                  : widget.community.iconUrl != null
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(
                              widget.community.iconUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
            ),
          ),

          // ── Gradiente escuro (Amino: mais transparente no topo, preto na base)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.35, 0.7, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.10),
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.80),
                ],
              ),
            ),
          ),

          // ── Conteúdo do header ─────────────────────────────────────────
          // Layout:
          //   [topo]  ícone de busca (32px) + padding (6px) = 44px reservados
          //   [meio]  banner centralizado no espaço livre entre busca e avatar
          //   [base]  avatar + nome + nível + streak
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Espaço reservado para o ícone de busca (32px + 6px top + 6px bottom)
                SizedBox(height: r.s(44)),
                SizedBox(height: r.s(6)),
                // Banner retangular logo abaixo do botão de busca
                _buildCommunityBanner(r),
                // Espaço flexível entre banner e avatar
                const Spacer(flex: 1),
                // Avatar do usuário centralizado
                _buildUserAvatar(r, user, themeColor),
                SizedBox(height: r.s(6)),
                // Nome do usuário
                Text(
                  user?.nickname ?? 'Visitante',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: r.fs(20),
                    fontWeight: FontWeight.w800,
                    shadows: const [
                      Shadow(color: Colors.black87, blurRadius: 8),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: r.s(4)),
                // Badge de nível + barra de reputação
                if (user != null) _buildLevelBadge(r, user),
                SizedBox(height: r.s(8)),
                // Streak dots (7 dias)
                _buildStreakDots(r, streak, hasCheckedIn),
                SizedBox(height: r.s(4)),
                // Mensagem de check-in (TEXTO VERDE — como no Amino!)
                _buildCheckInMessage(r, hasCheckedIn),
                SizedBox(height: r.s(8)),
              ],
            ),
          ),

          // ── Ícone de busca no topo direito ───────────────────────────────
          // Posicionado APÓS o Positioned.fill para ficar sempre na frente
          Positioned(
            top: r.s(6),
            right: r.s(8),
            child: GestureDetector(
              onTap: () => _closeAndNavigate(() {
                context.push('/community/${widget.community.id}/search');
              }),
              child: Container(
                width: r.s(32),
                height: r.s(32),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.40),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.search_rounded,
                    color: Colors.white, size: r.s(18)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Banner retangular da comunidade no topo do header (como no Amino)
  Widget _buildCommunityBanner(Responsive r) {
    if (widget.community.iconUrl == null &&
        widget.community.bannerUrl == null) {
      return SizedBox(height: r.s(10));
    }
    return Container(
      height: r.s(55),
      margin: EdgeInsets.fromLTRB(r.s(12), r.s(6), r.s(12), 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r.s(8)),
        color: Colors.white.withValues(alpha: 0.08),
        image: (widget.community.bannerUrl ?? widget.community.iconUrl) != null
            ? DecorationImage(
                image: CachedNetworkImageProvider(
                    widget.community.bannerUrl ?? widget.community.iconUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
    );
  }

  /// Avatar do usuário (Amino: ~75px, borda branca fina 2px)
  /// Ao clicar, navega para o perfil do usuário na comunidade.
  Widget _buildUserAvatar(Responsive r, UserModel? user, Color themeColor) {
    final userId = user?.id ?? SupabaseService.currentUserId;
    return GestureDetector(
      onTap: userId != null
          ? () => _closeAndNavigate(() {
                context.push(
                  '/community/${widget.community.id}/profile/$userId',
                );
              })
          : null,
      child: Container(
        width: r.s(92),
        height: r.s(92),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 2,
          ),
          color: themeColor.withValues(alpha: 0.4),
          image: user?.iconUrl != null
              ? DecorationImage(
                  image: CachedNetworkImageProvider(user!.iconUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: user?.iconUrl == null
            ? Icon(Icons.person_rounded, color: Colors.white, size: r.s(44))
            : null,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BADGE DE NÍVEL + BARRA DE REPUTAÇÃO
  //
  // Amino original:
  // - Círculo verde com "Lv" + número (ex: "Lv2")
  //   Tamanho: ~26px, fonte ~9px
  // - Pill escura: nome do nível (ex: "Anti Newbie") + barra de progresso
  //   Altura: ~22px, borderRadius: pill
  //   Barra: azul/verde brilhante sobre fundo cinza escuro
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLevelBadge(Responsive r, UserModel user) {
    final level = user.level;
    final reputation = user.reputation;
    final levelColor = AppTheme.getLevelColor(level);
    final levelName = levelTitle(level);
    final repForNextLevel = 100 * (level + 1);
    final repProgress = (reputation % repForNextLevel) / repForNextLevel;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.s(30)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Círculo com "Lv" + número (estilo Amino)
          Container(
            width: r.s(36),
            height: r.s(36),
            decoration: BoxDecoration(
              color: levelColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Center(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Lv',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: r.fs(9),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: '$level',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: r.fs(13),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: r.s(4)),
          // Pill com nome do nível + barra de progresso
          Flexible(
            child: Container(
              height: r.s(28),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.50),
                borderRadius: BorderRadius.circular(r.s(14)),
              ),
              padding: EdgeInsets.symmetric(horizontal: r.s(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    flex: 0,
                    child: Text(
                      levelName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: r.fs(9),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  SizedBox(width: r.s(6)),
                  Expanded(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // STREAK DOTS (7 dias)
  //
  // Amino original:
  // - 7 dots em linha horizontal
  // - Tamanho: ~14px cada
  // - Feito: verde (#4CAF50) com check branco
  // - Pendente: cinza transparente com borda cinza
  // - O primeiro dot pode ter um badge vermelho "1"
  // - Espaçamento: ~4px entre dots
  // - Conectados por uma linha cinza horizontal fina
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStreakDots(Responsive r, int streak, bool hasCheckedIn) {
    const totalDots = 7;
    final doneDots = streak.clamp(0, totalDots);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.s(24)),
      child: SizedBox(
        height: r.s(18),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Linha horizontal conectando os dots (como no Amino)
            Positioned(
              left: r.s(8),
              right: r.s(8),
              child: Container(
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalDots, (i) {
                final done = i < doneDots;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: r.s(3)),
                  child: Container(
                    width: r.s(14),
                    height: r.s(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? const Color(0xFF4CAF50)
                          : Colors.grey.withValues(alpha: 0.25),
                      border: Border.all(
                        color: done
                            ? const Color(0xFF4CAF50)
                            : Colors.white.withValues(alpha: 0.20),
                        width: 1.5,
                      ),
                    ),
                    child: done
                        ? Icon(Icons.check_rounded,
                            color: Colors.white, size: r.s(9))
                        : null,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MENSAGEM DE CHECK-IN
  //
  // Amino original:
  // - TEXTO VERDE brilhante (NÃO container vermelho!)
  // - "Check-in streak lost. Tap here to fix it!"
  // - Fonte ~11px, verde (#4CAF50), sem fundo/container
  // - Clicável para fazer check-in
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCheckInMessage(Responsive r, bool hasCheckedIn) {
    if (hasCheckedIn) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _isCheckingIn ? null : _doCheckIn,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.s(16)),
        child: Text(
          _isCheckingIn
              ? 'Fazendo check-in...'
              : 'Check-in streak lost. Tap here to fix it!',
          style: TextStyle(
            color: const Color(0xFF4CAF50),
            fontSize: r.fs(11),
            fontWeight: FontWeight.w600,
            shadows: const [
              Shadow(color: Colors.black54, blurRadius: 4),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ÁREA DO MENU
  //
  // Amino original:
  // - Fundo: escuro semi-transparente (a imagem da comunidade NÃO continua
  //   aqui — é um fundo sólido escuro, mas levemente transparente)
  // - Sem separadores entre os itens do menu principal
  // - "See More..." com seta no final
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMenuArea(Responsive r) {
    return Container(
      // Fundo escuro do menu (Amino: quase opaco, mas com leve transparência)
      color: const Color(0xFF0A0A0A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: r.s(2)),
          _buildMainMenu(r),
          _buildSeeMore(r),
          if (_isStaff) _buildStaffSection(r),
          SizedBox(height: r.s(40)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MENU PRINCIPAL
  //
  // Amino original (ordem exata do print):
  //   1. Home — ícone azul (#42A5F5), casa preenchida
  //   2. My Chats — ícone verde (#66BB6A), balão de chat
  //   3. Public Chatrooms — ícone verde (#66BB6A), fórum
  //   4. Leaderboards — ícone roxo escuro (#7B1FA2), troféu/ranking
  //   5. Wiki — ícone roxo (#9C27B0), livro
  //   6. Shared Folder — ícone azul (#42A5F5), pasta
  //   7. Stories — ícone roxo escuro (#7B1FA2), stories
  //
  // Cada item: ícone circular ~42px, texto branco bold ~16px
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMainMenu(Responsive r) {
    return Column(
      children: [
        _AminoDrawerTile(
          icon: Icons.home_rounded,
          iconColor: const Color(0xFF42A5F5),
          label: 'Home',
          onTap: () => _closeAndNavigate(() {}),
        ),
        _AminoDrawerTile(
          icon: Icons.chat_bubble_rounded,
          iconColor: const Color(0xFF66BB6A),
          label: 'My Chats',
          onTap: () => _closeAndNavigate(() {
            context.push(
              '/community/${widget.community.id}/my-chats',
              extra: {'communityName': widget.community.name},
            );
          }),
        ),
        _AminoDrawerTile(
          icon: Icons.forum_rounded,
          iconColor: const Color(0xFF66BB6A),
          label: 'Public Chatrooms',
          onTap: () => _closeAndNavigate(() {
            context.push('/create-public-chat', extra: {
              'communityId': widget.community.id,
              'communityName': widget.community.name,
            });
          }),
        ),
        _AminoDrawerTile(
          icon: Icons.leaderboard_rounded,
          iconColor: const Color(0xFF7B1FA2),
          label: 'Leaderboards',
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/leaderboard');
          }),
        ),
        _AminoDrawerTile(
          icon: Icons.auto_stories_rounded,
          iconColor: const Color(0xFF9C27B0),
          label: 'Wiki',
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/wiki');
          }),
        ),
        _AminoDrawerTile(
          icon: Icons.folder_shared_rounded,
          iconColor: const Color(0xFF42A5F5),
          label: 'Shared Folder',
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/shared-folder');
          }),
        ),
        _AminoDrawerTile(
          icon: Icons.amp_stories_rounded,
          iconColor: const Color(0xFF7B1FA2),
          label: 'Stories',
          onTap: () => _closeAndNavigate(() {
            context.push('/profile/${SupabaseService.currentUserId}');
          }),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SEE MORE...
  //
  // Amino original:
  // - "See More..." em cinza claro (~14px) com seta ">" à direita
  // - Sem divider acima
  // - Abaixo: itens extras (membros, posts salvos, etc.)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSeeMore(Responsive r) {
    return Column(
      children: [
        // "See More..." com seta
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
                    'See More...',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: r.fs(14),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: Colors.grey[500], size: r.s(22)),
              ],
            ),
          ),
        ),
        // Divider sutil
        Container(
          margin: EdgeInsets.symmetric(horizontal: r.s(16)),
          height: 0.5,
          color: Colors.white.withValues(alpha: 0.06),
        ),
        SizedBox(height: r.s(4)),
        // Membros
        _AminoDrawerTile(
          icon: Icons.group_rounded,
          iconColor: const Color(0xFF26C6DA),
          label: 'Members',
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/members');
          }),
        ),
        // Posts Salvos
        _AminoDrawerTile(
          icon: Icons.bookmark_rounded,
          iconColor: const Color(0xFFEF5350),
          label: 'Saved Posts',
          onTap: () => _closeAndNavigate(() {
            context.push('/profile/${SupabaseService.currentUserId}');
          }),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STAFF / GERENCIAMENTO
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStaffSection(Responsive r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: r.s(16)),
          height: 0.5,
          color: Colors.white.withValues(alpha: 0.06),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(r.s(20), r.s(14), r.s(20), r.s(4)),
          child: Text(
            'MANAGEMENT',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: r.fs(10),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        if (_isLeader)
          _AminoDrawerTile(
            icon: Icons.settings_rounded,
            iconColor: const Color(0xFF78909C),
            label: 'Edit Community',
            onTap: () => _closeAndNavigate(() {
              context.push('/community/${widget.community.id}/acm');
            }),
          ),
        _AminoDrawerTile(
          icon: Icons.flag_rounded,
          iconColor: AppTheme.errorColor,
          label: 'Flag Center',
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/flags');
          }),
        ),
        _AminoDrawerTile(
          icon: Icons.analytics_rounded,
          iconColor: const Color(0xFF26A69A),
          label: 'Statistics',
          onTap: () => _closeAndNavigate(() {
            context.push('/community/${widget.community.id}/acm');
          }),
        ),
      ],
    );
  }
}

// =============================================================================
// _AminoDrawerTile — Item de menu estilo Amino
//
// Amino original:
// - Ícone circular colorido: ~42px diâmetro
// - Ícone branco dentro: ~20px
// - Texto: branco, semibold/bold, ~16px
// - Espaçamento ícone→texto: ~14px
// - Padding vertical: ~10px
// - Padding horizontal: ~14px
// =============================================================================

class _AminoDrawerTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final int? badgeCount;

  const _AminoDrawerTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: r.s(14),
          vertical: r.s(9),
        ),
        child: Row(
          children: [
            // Ícone circular colorido (42px — fiel ao Amino)
            Container(
              width: r.s(42),
              height: r.s(42),
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: r.s(20)),
            ),
            SizedBox(width: r.s(14)),
            // Label
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.fs(16),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Badge de notificação (se houver)
            if (badgeCount != null && badgeCount! > 0)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: r.s(6),
                  vertical: r.s(2),
                ),
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(r.s(10)),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: r.fs(11),
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
