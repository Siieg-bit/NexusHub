import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/utils/helpers.dart';

/// Sidebar arrastável (Drawer) dentro da comunidade — cópia 1:1 do Amino.
/// Exibe foto de perfil no topo, atalhos de navegação e informações da comunidade.
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

  @override
  Widget build(BuildContext context) {
    final themeColor = _parseColor(community.themeColor);

    return Drawer(
      backgroundColor: AppTheme.scaffoldBg,
      child: SafeArea(
        child: Column(
          children: [
            // ============================================================
            // HEADER: Perfil do usuário + info da comunidade
            // ============================================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [themeColor, themeColor.withValues(alpha: 0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar do usuário
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/profile');
                    },
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white24,
                      backgroundImage: currentUser?.iconUrl != null
                          ? CachedNetworkImageProvider(currentUser!.iconUrl!)
                          : null,
                      child: currentUser?.iconUrl == null
                          ? const Icon(Icons.person_rounded,
                              color: Colors.white, size: 32)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    currentUser?.nickname ?? 'Usuário',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (userRole != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _roleLabel(userRole!),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Info da comunidade
                  Text(
                    community.name,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatCount(community.membersCount)} membros',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),

            // ============================================================
            // MENU DE NAVEGAÇÃO
            // ============================================================
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DrawerItem(
                    icon: Icons.home_rounded,
                    label: 'Feed',
                    color: themeColor,
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.featured_play_list_rounded,
                    label: 'Featured',
                    color: themeColor,
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Featured screen
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.auto_stories_rounded,
                    label: 'Catálogo (Wiki)',
                    color: themeColor,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/community/${community.id}/wiki');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.chat_rounded,
                    label: 'Chats da Comunidade',
                    color: themeColor,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/chats');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.people_rounded,
                    label: 'Membros',
                    color: themeColor,
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Members list
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.leaderboard_rounded,
                    label: 'Leaderboard',
                    color: themeColor,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/community/${community.id}/leaderboard');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.folder_shared_rounded,
                    label: 'Shared Folder',
                    color: themeColor,
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Shared folder
                    },
                  ),
                  const Divider(height: 24),
                  _DrawerItem(
                    icon: Icons.check_circle_rounded,
                    label: 'Check-in Diário',
                    color: const Color(0xFF00BCD4),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/check-in');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.notifications_rounded,
                    label: 'Notificações',
                    color: themeColor,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/notifications');
                    },
                  ),

                  // Seção de staff
                  if (_isStaff) ...[
                    const Divider(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Text(
                        'GERENCIAMENTO',
                        style: TextStyle(
                          color: themeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    _DrawerItem(
                      icon: Icons.flag_rounded,
                      label: 'Flag Center',
                      color: AppTheme.errorColor,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/community/${community.id}/flags');
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.settings_rounded,
                      label: 'ACM (Configurações)',
                      color: themeColor,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/community/${community.id}/acm');
                      },
                    ),
                    _DrawerItem(
                      icon: Icons.analytics_rounded,
                      label: 'Estatísticas',
                      color: themeColor,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/community/${community.id}/acm');
                      },
                    ),
                  ],
                ],
              ),
            ),

            // ============================================================
            // FOOTER
            // ============================================================
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppTheme.textHint, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Criada em ${_formatDate(community.createdAt)}',
                      style: const TextStyle(
                          color: AppTheme.textHint, fontSize: 11),
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
        return 'Membro';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      horizontalTitleGap: 8,
    );
  }
}
