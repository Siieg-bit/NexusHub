import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/models/user_model.dart';
// helpers and amino_animations available if needed

/// Drawer estilo Amino Apps — web-preview fiel.
/// Estrutura: sidebar de comunidades (60px) + painel principal (280px).
class CommunityDrawer extends StatelessWidget {
  final CommunityModel community;
  final UserModel? currentUser;
  final String? userRole;

  const CommunityDrawer({
    super.key,
    required this.community,
    this.currentUser,
    this.userRole,
  });

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  bool get _isStaff =>
      userRole == 'agent' ||
      userRole == 'leader' ||
      userRole == 'curator' ||
      userRole == 'moderator' ||
      userRole == 'admin';

  bool get _isLeader => userRole == 'agent' || userRole == 'leader';

  // ignore: unused_element
  String _roleLabel(String role) {
    switch (role) {
      case 'agent':
        return 'Agent';
      case 'leader':
        return 'Leader';
      case 'curator':
        return 'Curator';
      case 'moderator':
        return 'Moderator';
      case 'admin':
        return 'Admin';
      default:
        return 'Member';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = _parseColor(community.themeColor);

    return Drawer(
      backgroundColor: AppTheme.scaffoldBg,
      width: 340,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Row(
          children: [
            // ==============================================================
            // SIDEBAR ESQUERDA — Lista de comunidades (60px)
            // Estilo web-preview: bg-[#070710], ícones de comunidades
            // ==============================================================
            Container(
              width: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF070710),
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
                      context.pop();
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
                              child: community.iconUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: community.iconUrl!,
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
                              context.push('/explore');
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
                        if (community.bannerUrl != null)
                          CachedNetworkImage(
                            imageUrl: community.bannerUrl!,
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
                                community.name.toUpperCase(),
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
                              Stack(
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
                                          currentUser?.iconUrl != null
                                              ? CachedNetworkImageProvider(
                                                  currentUser!.iconUrl!)
                                              : null,
                                      child: currentUser?.iconUrl == null
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
                              const SizedBox(height: 6),
                              // User name
                              Text(
                                currentUser?.nickname ?? 'Meu Perfil',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Check In button
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                  context.push('/check-in');
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
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
                                  child: const Text(
                                    'Check In',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
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
                            context.push('/chats');
                          },
                        ),
                        _AminoDrawerItem(
                          icon: Icons.auto_stories_rounded,
                          label: 'Catálogo',
                          color: const Color(0xFFFF9800),
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/community/${community.id}/wiki');
                          },
                        ),
                        _AminoDrawerItem(
                          icon: Icons.forum_rounded,
                          label: 'Chats Públicos',
                          color: AppTheme.primaryColor,
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/chats');
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
                            // TODO: Resource Links
                          },
                        ),

                        // "See More..."
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              // TODO: See more
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
                              context
                                  .push('/community/${community.id}/acm');
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
                              context.push(
                                  '/community/${community.id}/flags');
                            },
                          ),
                          _AminoDrawerItem(
                            icon: Icons.analytics_rounded,
                            label: 'Estatísticas',
                            color: const Color(0xFF2196F3),
                            onTap: () {
                              Navigator.pop(context);
                              context
                                  .push('/community/${community.id}/acm');
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
