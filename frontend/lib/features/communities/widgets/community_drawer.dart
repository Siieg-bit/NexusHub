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
import '../../../core/utils/responsive.dart'; // para checkInStatusProvider
import '../../../core/widgets/amino_drawer.dart';

/// Drawer estilo Amino Apps — réplica pixel-perfect.
/// Estrutura: sidebar de comunidades (56px) + painel principal (flex).
class CommunityDrawer extends ConsumerStatefulWidget {
  final CommunityModel community;
  final UserModel? currentUser;
  final String? userRole;
  final VoidCallback? onChatsTap;
  final VoidCallback? onGuidelinesTap;
  final VoidCallback? onRecentFeedTap;

  const CommunityDrawer({
    super.key,
    required this.community,
    this.currentUser,
    this.userRole,
    this.onChatsTap,
    this.onGuidelinesTap,
    this.onRecentFeedTap,
  });

  @override
  ConsumerState<CommunityDrawer> createState() => _CommunityDrawerState();
}

class _CommunityDrawerState extends ConsumerState<CommunityDrawer> {
  bool _isCheckingIn = false;
  bool _showMore = false;
  List<Map<String, dynamic>> _generalLinks = [];

  @override
  void initState() {
    super.initState();
    _loadGeneralLinks();
  }

  Future<void> _loadGeneralLinks() async {
    try {
      final res = await SupabaseService.table('community_general_links')
          .select()
          .eq('community_id', widget.community.id)
          .order('sort_order', ascending: true)
          .limit(10);
      if (mounted) {
        setState(() {
          _generalLinks = List<Map<String, dynamic>>.from(res as List? ?? []);
        });
      }
    } catch (_) {
      // Tabela pode não existir ainda — ignorar silenciosamente
    }
  }

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
      if (!mounted) return;

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
    final themeColor = _parseColor(widget.community.themeColor);
    final checkInStatus = ref.watch(checkInStatusProvider);
    final statusMap = checkInStatus.valueOrNull ?? {};
    final myStatus = statusMap[widget.community.id];
    final hasCheckedIn = myStatus?['has_checkin_today'] as bool? ?? false;
    final streak = myStatus?['consecutive_checkin_days'] as int? ?? 0;

    // Carregar comunidades do usuário para a sidebar esquerda
    final userCommunitiesAsync = ref.watch(userCommunitiesProvider);

    // Bug #7 fix: O Drawer não deve definir width próprio — o AminoDrawerController
    // já posiciona este widget em um slot de maxSlide (280px). Definir 85% da tela
    // causava overflow quando 85% > 280px.
    return Container(
      color: context.scaffoldBg,
      child: SafeArea(
        child: Row(
          children: [
            // ==============================================================
            // SIDEBAR ESQUERDA — Lista de comunidades do usuário (56px)
            // ==============================================================
            Container(
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
                  // Exit button — volta para a lista de comunidades
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

                  // Lista de comunidades do usuário
                  Expanded(
                    child: userCommunitiesAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (communities) {
                        return SingleChildScrollView(
                          child: Column(
                            children: [
                              // Comunidades do usuário
                              ...communities.map((community) {
                                final isCurrentCommunity =
                                    community.id == widget.community.id;
                                return GestureDetector(
                                  onTap: () {
                                    if (!isCurrentCommunity) {
                                      // Fechar o drawer primeiro
                                      final drawerController =
                                          AminoDrawerController.of(context);
                                      if (drawerController != null &&
                                          drawerController.isOpen) {
                                        drawerController.close();
                                      }
                                      // Usar pushReplacement em vez de go
                                      // para evitar tear-down completo da
                                      // route stack que causa Duplicate
                                      // GlobalKey<NavigatorState>.
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        if (context.mounted) {
                                          context.pushReplacement(
                                              '/community/${community.id}');
                                        }
                                      });
                                    }
                                  },
                                  child: Container(
                                    margin:
                                        EdgeInsets.only(bottom: r.s(6)),
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(r.s(12)),
                                      border: isCurrentCommunity
                                          ? Border.all(
                                              color: Colors.white,
                                              width: 2)
                                          : null,
                                    ),
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(r.s(10)),
                                      child: (community.iconUrl ?? '').isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl:
                                                  community.iconUrl ?? '',
                                              width: r.s(40),
                                              height: r.s(40),
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              width: r.s(40),
                                              height: r.s(40),
                                              color: _parseColor(
                                                  community.themeColor),
                                              child: Icon(
                                                  Icons.groups_rounded,
                                                  color: Colors.white70,
                                                  size: r.s(20)),
                                            ),
                                    ),
                                  ),
                                );
                              }),

                              SizedBox(height: r.s(6)),

                              // Botão adicionar/explorar comunidade
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (context.mounted) {
                                      context.push('/explore');
                                    }
                                  });
                                },
                                child: Container(
                                  width: r.s(40),
                                  height: r.s(40),
                                  decoration: BoxDecoration(
                                    color: context.surfaceColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white
                                          .withValues(alpha: 0.1),
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: Icon(Icons.add_rounded,
                                      color: Colors.grey[600],
                                      size: r.s(16)),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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
                  // ========================================================
                  SizedBox(
                    height: r.s(220),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Cover image
                        if ((widget.community.bannerUrl ?? '').isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: widget.community.bannerUrl ?? '',
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
                                context.scaffoldBg.withValues(alpha: 0.0),
                                context.scaffoldBg.withValues(alpha: 0.4),
                                context.scaffoldBg,
                              ],
                              stops: const [0.0, 0.6, 1.0],
                            ),
                          ),
                        ),

                        // Content overlay
                        Positioned(
                          bottom: r.s(12),
                          left: r.s(16),
                          right: r.s(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar + Name
                              Row(
                                children: [
                                  // User avatar
                                  Builder(builder: (_) {
                                    final userIcon = widget.currentUser?.iconUrl;
                                    return CircleAvatar(
                                      radius: r.s(24),
                                      backgroundColor: themeColor,
                                      backgroundImage: userIcon != null && userIcon.isNotEmpty
                                          ? CachedNetworkImageProvider(userIcon)
                                          : null,
                                      child: userIcon == null || userIcon.isEmpty
                                          ? Icon(Icons.person_rounded,
                                              color: Colors.white70,
                                              size: r.s(24))
                                          : null,
                                    );
                                  }),
                                  SizedBox(width: r.s(12)),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.currentUser?.nickname ??
                                              'Usuário',
                                          style: TextStyle(
                                            color: context.textPrimary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: r.fs(16),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          widget.userRole?.toUpperCase() ??
                                              'MEMBRO',
                                          style: TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.w700,
                                            fontSize: r.fs(10),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: r.s(12)),
                              // Check-in button
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: hasCheckedIn ? null : _doCheckIn,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            vertical: r.s(8)),
                                        decoration: BoxDecoration(
                                          color: hasCheckedIn
                                              ? Colors.grey[800]
                                              : AppTheme.accentColor,
                                          borderRadius:
                                              BorderRadius.circular(r.s(8)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            if (_isCheckingIn)
                                              SizedBox(
                                                width: r.s(14),
                                                height: r.s(14),
                                                child:
                                                    const CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            else ...[
                                              Icon(
                                                hasCheckedIn
                                                    ? Icons.check_circle_rounded
                                                    : Icons
                                                        .local_fire_department_rounded,
                                                color: Colors.white,
                                                size: r.s(16),
                                              ),
                                              SizedBox(width: r.s(6)),
                                              Text(
                                                hasCheckedIn
                                                    ? 'Check-in feito!'
                                                    : 'Check-in diário',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: r.fs(12),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (streak > 0) ...[
                                    SizedBox(width: r.s(8)),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: r.s(10),
                                          vertical: r.s(8)),
                                      decoration: BoxDecoration(
                                        color: AppTheme.warningColor
                                            .withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(r.s(8)),
                                        border: Border.all(
                                            color: AppTheme.warningColor
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                              Icons
                                                  .local_fire_department_rounded,
                                              color: AppTheme.warningColor,
                                              size: r.s(14)),
                                          SizedBox(width: r.s(4)),
                                          Text(
                                            '$streak',
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
                                ],
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
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(8), vertical: r.s(8)),
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
                            if (widget.onChatsTap != null) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                widget.onChatsTap!();
                              });
                            }
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
                          icon: Icons.folder_shared_rounded,
                          label: 'Shared Folder',
                          color: const Color(0xFF00BCD4),
                          onTap: () {
                            Navigator.pop(context);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (context.mounted) context.push('/community/${widget.community.id}/shared-folder');
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
                            if (widget.onRecentFeedTap != null) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                widget.onRecentFeedTap!();
                              });
                            }
                          },
                        ),
                        _AminoDrawerItem(
                          icon: Icons.public_rounded,
                          label: 'Regras',
                          color: const Color(0xFFFF9800),
                          onTap: () {
                            Navigator.pop(context);
                            if (widget.onGuidelinesTap != null) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                widget.onGuidelinesTap!();
                              });
                            }
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

                        // "See More..." expansível
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: r.s(12), vertical: r.s(8)),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _showMore = !_showMore);
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_showMore ? 'Ver Menos' : 'Ver Mais...',
                                    style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: r.fs(13))),
                                AnimatedRotation(
                                  turns: _showMore ? 0.25 : 0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(Icons.chevron_right_rounded,
                                      color: Colors.grey[600], size: r.s(16)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Seção expandida
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Seção General — links customizáveis
                              if (_generalLinks.isNotEmpty) ...[
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: r.s(12), vertical: r.s(4)),
                                  child: Text('General',
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: r.fs(11),
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5)),
                                ),
                                for (final link in _generalLinks)
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: r.s(12), vertical: r.s(4)),
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.pop(context);
                                        // Abrir URL do link
                                        final url = link['url'] as String? ?? '';
                                        if (url.isNotEmpty) {
                                          WidgetsBinding.instance.addPostFrameCallback((_) {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Abrindo: ${link['title']}'),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          });
                                        }
                                      },
                                      child: Row(
                                        children: [
                                          Container(
                                            width: r.s(28),
                                            height: r.s(28),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(r.s(6)),
                                            ),
                                            child: Icon(Icons.link_rounded,
                                                color: AppTheme.primaryColor,
                                                size: r.s(14)),
                                          ),
                                          SizedBox(width: r.s(10)),
                                          Expanded(
                                            child: Text(
                                              link['title'] as String? ?? '',
                                              style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: r.fs(13)),
                                            ),
                                          ),
                                          Icon(Icons.open_in_new_rounded,
                                              color: Colors.grey[600],
                                              size: r.s(14)),
                                        ],
                                      ),
                                    ),
                                  ),
                              ] else ...[
                                // Mostrar leaderboard e busca como opções extras
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: r.s(12), vertical: r.s(4)),
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.pop(context);
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        if (context.mounted) {
                                          context.push('/community/${widget.community.id}/leaderboard');
                                        }
                                      });
                                    },
                                    child: Row(
                                      children: [
                                        Container(
                                          width: r.s(28),
                                          height: r.s(28),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(r.s(6)),
                                          ),
                                          child: Icon(Icons.leaderboard_rounded,
                                              color: Colors.amber, size: r.s(14)),
                                        ),
                                        SizedBox(width: r.s(10)),
                                        Text('Ranking',
                                            style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: r.fs(13))),
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: r.s(12), vertical: r.s(4)),
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.pop(context);
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        if (context.mounted) {
                                          context.push(
                                            '/community/${widget.community.id}/search',
                                            extra: {'communityName': widget.community.name},
                                          );
                                        }
                                      });
                                    },
                                    child: Row(
                                      children: [
                                        Container(
                                          width: r.s(28),
                                          height: r.s(28),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(r.s(6)),
                                          ),
                                          child: Icon(Icons.search_rounded,
                                              color: Colors.blue, size: r.s(14)),
                                        ),
                                        SizedBox(width: r.s(10)),
                                        Text('Buscar na Comunidade',
                                            style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: r.fs(13))),
                                      ],
                                    ),
                                  ),
                                ),
                                // Gerenciar Links — apenas para líderes
                                if (_isLeader)
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: r.s(12), vertical: r.s(4)),
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.pop(context);
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          if (context.mounted) {
                                            context.push(
                                              '/community/${widget.community.id}/general-links',
                                            );
                                          }
                                        });
                                      },
                                      child: Row(
                                        children: [
                                          Container(
                                            width: r.s(28),
                                            height: r.s(28),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(r.s(6)),
                                            ),
                                            child: Icon(Icons.add_link_rounded,
                                                color: Colors.green, size: r.s(14)),
                                          ),
                                          SizedBox(width: r.s(10)),
                                          Text('Gerenciar Links',
                                              style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: r.fs(13))),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                              SizedBox(height: r.s(8)),
                            ],
                          ),
                          crossFadeState: _showMore
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 250),
                        ),

                        // Leader-only: Edit Community
                        if (_isLeader) ...[
                          SizedBox(height: r.s(8)),
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
                                  EdgeInsets.symmetric(horizontal: r.s(4)),
                              padding: EdgeInsets.symmetric(
                                  horizontal: r.s(12), vertical: r.s(10)),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(r.s(10)),
                                border: Border.all(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: r.s(32),
                                    height: r.s(32),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.settings_rounded,
                                        color: Colors.white, size: r.s(16)),
                                  ),
                                  SizedBox(width: r.s(12)),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Editar Comunidade',
                                          style: TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontSize: r.fs(13),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          'Nome, descrição, tags, capa, ícone',
                                          style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: r.fs(9)),
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
                          SizedBox(height: r.s(12)),
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: r.s(12), vertical: r.s(4)),
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
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(10)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r.s(10)),
        ),
        child: Row(
          children: [
            // Ícone em círculo colorido
            Container(
              width: r.s(32),
              height: r.s(32),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: r.s(16)),
            ),
            SizedBox(width: r.s(12)),
            // Label
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: r.fs(14),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Badge (opcional)
            if (badge != null && (badge ?? 0) > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 20),
                height: r.s(20),
                padding: EdgeInsets.symmetric(horizontal: r.s(4)),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor,
                  borderRadius: BorderRadius.circular(r.s(10)),
                ),
                child: Center(
                  child: Text(
                    '$badge',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.fs(10),
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
