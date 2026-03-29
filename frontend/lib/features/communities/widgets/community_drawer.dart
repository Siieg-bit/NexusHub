import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/supabase_service.dart';
import '../screens/community_list_screen.dart'; // para checkInStatusProvider

/// Drawer estilo Amino Apps — réplica pixel-perfect.
/// Estrutura: sidebar de comunidades (56px) + painel principal (flex).
/// No Amino original, o drawer empurra a tela principal para a direita
/// com animação de scale (push/scale). Isso é controlado pelo Scaffold.
/// Os módulos do menu são dinâmicos e refletem a configuração do ACM.
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

  bool get _isStaff =>
      widget.userRole == 'agent' ||
      widget.userRole == 'leader' ||
      widget.userRole == 'curator' ||
      widget.userRole == 'moderator' ||
      widget.userRole == 'admin';

  bool get _isLeader => widget.userRole == 'agent' || widget.userRole == 'leader';

  Future<void> _doCheckIn() async {
    if (_isCheckingIn) return;
    setState(() => _isCheckingIn = true);

    try {
      final result = await SupabaseService.rpc('daily_checkin', params: {
        'p_community_id': widget.community.id,
      });

      ref.invalidate(checkInStatusProvider);

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
            content: Text('Erro no check-in: $e'),
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
    final themeColor = _parseColor(widget.community.themeColor);
    final checkInStatus = ref.watch(checkInStatusProvider);
    final statusMap = checkInStatus.valueOrNull ?? {};
    final myStatus = statusMap[widget.community.id];
    final hasCheckedIn = myStatus?['has_checkin_today'] as bool? ?? false;
    final streak = myStatus?['consecutive_checkin_days'] as int? ?? 0;

    return Drawer(
      backgroundColor: AppTheme.scaffoldBg,
      width: MediaQuery.of(context).size.width * 0.85,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Row(
          children: [
            // ==============================================================
            // SIDEBAR ESQUERDA — Lista de comunidades (60px)
            // Estilo web-preview: bg-[#070710], ícones de comunidades
            // ==============================================================
            Container(
              width: 56,
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
                  const SizedBox(height: 10),
                  // Exit button
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (context.mounted) context.pop();
                      });
                    },
                    child: Column(
                      children: [
                        Icon(Icons.logout_rounded,
                            color: Colors.grey[600], size: 18),
                        const SizedBox(height: 2),
                        Text('Sair',
                            style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 8,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 32,
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  const SizedBox(height: 8),

                  // Comunidade atual (highlighted)
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Comunidade atual
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white, width: 2),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: widget.community.iconUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: widget.community.iconUrl!,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 40,
                                      height: 40,
                                      color: themeColor,
                                      child: const Icon(Icons.groups_rounded,
                                          color: Colors.white70, size: 20),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Botão adicionar comunidade
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (context.mounted) context.push('/explore');
                              });
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Icon(Icons.add_rounded,
                                  color: Colors.grey[600], size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ==============================================================
            // PAINEL PRINCIPAL (280px)
            // ==============================================================
            Expanded(
              child: Column(
                children: [
                  // ========================================================
                  // COVER + PROFILE HEADER (220px)
                  // Estilo web-preview: cover image + gradient + avatar + check-in
                  // ========================================================
                  SizedBox(
                    height: 220,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Cover image
                        if (widget.community.bannerUrl != null)
                          CachedNetworkImage(
                            imageUrl: widget.community.bannerUrl!,
                            fit: BoxFit.cover,
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  themeColor,
                                  themeColor.withValues(alpha: 0.4),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),

                        // Gradient overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppTheme.scaffoldBg.withValues(alpha: 0.0),
                                AppTheme.scaffoldBg.withValues(alpha: 0.4),
                                AppTheme.scaffoldBg,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),

                        // "Welcome to" + Community name (top)
                        Positioned(
                          top: 12,
                          left: 0,
                          right: 0,
                          child: Column(
                            children: [
                              Text(
                                'Bem-vindo(a) a',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 10,
                                  letterSpacing: 3,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.community.name.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Avatar + Name + Check-in (bottom)
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Column(
                            children: [
                              // Avatar simples sem anel (estilo Amino original)
                              GestureDetector(
                                onTap: widget.currentUser != null
                                    ? () {
                                        Navigator.pop(context);
                                        context.push(
                                          '/community/${widget.community.id}/profile/${widget.currentUser!.id}',
                                        );
                                      }
                                    : null,
                                child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 68,
                                    height: 68,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 32,
                                      backgroundColor: AppTheme.surfaceColor,
                                      backgroundImage:
                                          widget.currentUser?.iconUrl != null
                                              ? CachedNetworkImageProvider(
                                                  widget.currentUser!.iconUrl!)
                                              : null,
                                      child: widget.currentUser?.iconUrl == null
                                          ? const Icon(Icons.person_rounded,
                                              color: Colors.white70, size: 28)
                                          : null,
                                    ),
                                  ),
                                  // Plus badge (top-right)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: AppTheme.scaffoldBg,
                                            width: 2),
                                      ),
                                      child: const Icon(Icons.add_rounded,
                                          color: Colors.white, size: 12),
                                    ),
                                  ),
                                ],
                              ),
                              ),
                              const SizedBox(height: 6),
                              // User name
                              Text(
                                widget.currentUser?.nickname ?? 'Meu Perfil',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Check In button ou Streak badge
                              if (!hasCheckedIn)
                                GestureDetector(
                                  onTap: _isCheckingIn ? null : _doCheckIn,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: _isCheckingIn
                                          ? AppTheme.primaryColor.withValues(alpha: 0.5)
                                          : AppTheme.primaryColor,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: _isCheckingIn
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Check In',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                )
                              else
                                // Streak badge — já fez check-in hoje
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppTheme.warningColor.withValues(alpha: 0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.local_fire_department_rounded,
                                        color: AppTheme.warningColor,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$streak dia${streak > 1 ? 's' : ''}',
                                        style: const TextStyle(
                                          color: AppTheme.warningColor,
                                          fontSize: 13,
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
                  ),

                  // ========================================================
                  // MENU ITEMS — Estilo Amino (ícones em círculos coloridos)
                  // ========================================================
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      children: [
                        _AminoDrawerItem(
                          icon: Icons.star_rounded,
                          label: 'Início',
                          color: AppTheme.primaryColor,
                          onTap: () => Navigator.pop(context),
                        ),
                        _AminoDrawerItem(
                          icon: Icons.chat_rounded,
                          label: 'Meus Chats',
                          color: AppTheme.primaryColor,
                          badge: 0,
                          onTap: () {
                            Navigator.pop(context);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (context.mounted) context.go('/chats');
                            });
                          },
                        ),
                        _AminoDrawerItem(
                          icon: Icons.people_rounded,
                          label: 'Membros',
                          color: const Color(0xFF9C27B0),
                          onTap: () {
                            Navigator.pop(context);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (context.mounted) context.push('/community/${widget.community.id}/members');
                            });
                          },
                        ),
                        _AminoDrawerItem(
                          icon: Icons.auto_stories_rounded,
                          label: 'Wiki',
                          color: const Color(0xFFFF9800),
                          onTap: () {
                            Navigator.pop(context);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (context.mounted) context.push('/community/${widget.community.id}/wiki');
                            });
                          },
                        ),
                        _AminoDrawerItem(
                          icon: Icons.leaderboard_rounded,
                          label: 'Ranking',
                          color: const Color(0xFFFFD700),
                          onTap: () {
                            Navigator.pop(context);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (context.mounted) context.push('/community/${widget.community.id}/leaderboard');
                            });
                          },
                        ),
                        _AminoDrawerItem(
                          icon: Icons.access_time_rounded,
                          label: 'Feed Recente',
                          color: const Color(0xFF2196F3),
                          onTap: () {
                            Navigator.pop(context);
                            // Volta para a tela da comunidade, tab Latest
                          },
                        ),
                        _AminoDrawerItem(
                          icon: Icons.public_rounded,
                          label: 'Regras',
                          color: const Color(0xFFFF9800),
                          onTap: () {
                            Navigator.pop(context);
                            // Volta para a tela da comunidade, tab Guidelines
                          },
                        ),
                        _AminoDrawerItem(
                          icon: Icons.link_rounded,
                          label: 'Links Úteis',
                          color: const Color(0xFFFF9800),
                          onTap: () {
                            Navigator.pop(context);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (context.mounted) {
                                context.push('/community/${widget.community.id}/wiki');
                              }
                            });
                          },
                        ),

                        // "See More..."
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (context.mounted) {
                                  context.push('/community/${widget.community.id}/wiki');
                                }
                              });
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Ver Mais...',
                                    style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 13)),
                                Icon(Icons.chevron_right_rounded,
                                    color: Colors.grey[600], size: 16),
                              ],
                            ),
                          ),
                        ),

                        // Leader-only: Edit Community
                        if (_isLeader) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (context.mounted) {
                                  context.push('/community/${widget.community.id}/acm');
                                }
                              });
                            },
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.settings_rounded,
                                        color: Colors.white, size: 16),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Editar Comunidade',
                                          style: TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          'Nome, descrição, tags, capa, ícone',
                                          style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 9),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        // Staff management section
                        if (_isStaff) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            child: Text(
                              'GERENCIAMENTO',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          _AminoDrawerItem(
                            icon: Icons.flag_rounded,
                            label: 'Central de Denúncias',
                            color: AppTheme.errorColor,
                            onTap: () {
                              Navigator.pop(context);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (context.mounted) {
                                  context.push('/community/${widget.community.id}/flags');
                                }
                              });
                            },
                          ),
                          _AminoDrawerItem(
                            icon: Icons.analytics_rounded,
                            label: 'Estatísticas',
                            color: const Color(0xFF2196F3),
                            onTap: () {
                              Navigator.pop(context);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (context.mounted) {
                                  context.push('/community/${widget.community.id}/acm');
                                }
                              });
                            },
                          ),
                        ],
                      ],
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
}

// =============================================================================
// DRAWER ITEM — Estilo Amino (ícone em círculo colorido + label)
// =============================================================================
class _AminoDrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int? badge;

  const _AminoDrawerItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // Ícone em círculo colorido
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            // Label
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Badge (opcional)
            if (badge != null && badge! > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 20),
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
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
}
