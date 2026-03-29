import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../config/app_theme.dart';
import '../../../core/models/chat_room_model.dart';
import '../../../core/models/community_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/amino_top_bar.dart';
import '../../../core/widgets/amino_particles_bg.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../../core/providers/notification_provider.dart';

/// Provider para lista de chats do usuário.
final chatListProvider = FutureProvider<List<ChatRoomModel>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];

  final response = await SupabaseService.table('chat_members')
      .select('thread_id, chat_threads(*)')
      .eq('user_id', userId)
      .order('joined_at', ascending: false);

  return (response as List)
      .where((e) => e['chat_threads'] != null)
      .map((e) =>
          ChatRoomModel.fromJson(e['chat_threads'] as Map<String, dynamic>))
      .toList()
    ..sort((a, b) => (b.lastMessageAt ?? b.createdAt)
        .compareTo(a.lastMessageAt ?? a.createdAt));
});

/// Provider para comunidades do usuário (sidebar).
final chatCommunitiesProvider =
    FutureProvider<List<CommunityModel>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];
  final response = await SupabaseService.table('community_members')
      .select('community_id, communities(*)')
      .eq('user_id', userId)
      .order('joined_at', ascending: false)
      .limit(10);
  return (response as List)
      .where((e) => e['communities'] != null)
      .map((e) => CommunityModel.fromJson(e['communities']))
      .toList();
});

/// Tela de Chats — réplica fiel do Amino Apps.
/// Layout: AminoTopBar + Row[ Sidebar esquerda | Área principal de chats ]
/// Sidebar: Recente, Global, ícones de comunidades, botão +
/// Área principal: lista de chats ou "Recomendados" com cards grandes
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  int _selectedSidebarIndex = 0; // 0 = Recente, 1 = Global, 2+ = comunidades
  String? _avatarUrl;
  int _coins = 0;

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
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(chatListProvider);
    final communitiesAsync = ref.watch(chatCommunitiesProvider);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: AminoParticlesBg(
        child: Column(
          children: [
            // ── Top Bar Amino ──
            AminoTopBar(
              avatarUrl: _avatarUrl,
              coins: _coins,
              notificationCount: ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0,
              onSearchTap: () => context.push('/search'),
              onAddTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: AppTheme.surfaceColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (ctx) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Novo Chat',
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 20),
                        ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.person_add_rounded,
                                color: AppTheme.primaryColor),
                          ),
                          title: const Text('Chat Privado',
                              style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text('Iniciar conversa com um usu\u00e1rio',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          onTap: () {
                            Navigator.pop(ctx);
                            context.push('/search');
                          },
                        ),
                        ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.group_add_rounded,
                                color: AppTheme.accentColor),
                          ),
                          title: const Text('Chat em Grupo',
                              style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text('Criar um grupo com v\u00e1rios membros',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          onTap: () {
                            Navigator.pop(ctx);
                            // Navegar para criar grupo
                            context.push('/create-group-chat');
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // ── Conteúdo: Sidebar + Área principal ──
            Expanded(
              child: Row(
                children: [
                  // ════════════════════════════════════════════════
                  // SIDEBAR ESQUERDA — Estilo Amino
                  // ════════════════════════════════════════════════
                  Container(
                    width: 64,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor.withValues(alpha: 0.5),
                      border: Border(
                        right: BorderSide(
                          color: AppTheme.dividerColor.withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),

                        // Recente (ícone relógio)
                        _SidebarIcon(
                          icon: Icons.access_time_rounded,
                          isSelected: _selectedSidebarIndex == 0,
                          onTap: () => setState(() => _selectedSidebarIndex = 0),
                          tooltip: 'Recente',
                        ),

                        const SizedBox(height: 8),

                        // Global (ícone globo com badge)
                        _SidebarIcon(
                          icon: Icons.public_rounded,
                          isSelected: _selectedSidebarIndex == 1,
                          onTap: () => setState(() => _selectedSidebarIndex = 1),
                          tooltip: 'Global',
                          badgeCount: 0,
                        ),

                        const SizedBox(height: 4),

                        // Divider
                        Container(
                          width: 28,
                          height: 1,
                          color: AppTheme.dividerColor.withValues(alpha: 0.4),
                        ),

                        const SizedBox(height: 4),

                        // Comunidades do usuário
                        Expanded(
                          child: communitiesAsync.when(
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (communities) => ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemCount: communities.length,
                              itemBuilder: (context, index) {
                                final community = communities[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _SidebarCommunityIcon(
                                    community: community,
                                    isSelected: _selectedSidebarIndex == index + 2,
                                    onTap: () => setState(
                                        () => _selectedSidebarIndex = index + 2),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        // Botão + (criar/entrar)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: GestureDetector(
                            onTap: () => context.go('/explore'),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.cardColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.dividerColor.withValues(alpha: 0.4),
                                ),
                              ),
                              child: const Icon(Icons.add,
                                  color: AppTheme.textSecondary, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ════════════════════════════════════════════════
                  // ÁREA PRINCIPAL — Lista de chats ou Recomendados
                  // ════════════════════════════════════════════════
                  Expanded(
                    child: chatsAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.accentColor,
                          strokeWidth: 2.5,
                        ),
                      ),
                      error: (error, _) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline_rounded,
                                size: 48, color: AppTheme.textHint),
                            const SizedBox(height: 12),
                            Text('Erro ao carregar chats',
                                style: TextStyle(
                                    color: AppTheme.textSecondary, fontSize: 14)),
                          ],
                        ),
                      ),
                      data: (chatRooms) {
                        if (_selectedSidebarIndex == 1) {
                          // Global — mostrar recomendados
                          return _buildRecommendedChats();
                        }
                        if (chatRooms.isEmpty) {
                          return _buildEmptyChats();
                        }
                        return _buildChatList(chatRooms);
                      },
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

  // ==========================================================================
  // LISTA DE CHATS — Estilo Amino
  // ==========================================================================
  Widget _buildChatList(List<ChatRoomModel> chatRooms) {
    return ListView.builder(
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 80,
      ),
      itemCount: chatRooms.length,
      itemBuilder: (context, index) => _AminoChatTile(chatRoom: chatRooms[index]),
    );
  }

  // ==========================================================================
  // RECOMENDADOS — Estilo Amino (cards grandes com imagem de fundo)
  // ==========================================================================
  Widget _buildRecommendedChats() {
    return ListView(
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 80,
      ),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            'Recomendados',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        // Placeholder cards para chats recomendados
        ...List.generate(5, (index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppTheme.cardColor,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Fundo com gradiente
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        [AppTheme.aminoPurple, AppTheme.aminoBlue],
                        [AppTheme.aminoMagenta, AppTheme.aminoPurple],
                        [AppTheme.aminoBlue, AppTheme.accentColor],
                        [AppTheme.aminoOrange, AppTheme.aminoRed],
                        [AppTheme.primaryColor, AppTheme.accentColor],
                      ][index % 5],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                // Gradiente escuro
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                ),
                // Conteúdo
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Badge da comunidade
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          ['Anime', 'K-Pop', 'Gaming', 'Art', 'Music'][index % 5],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        [
                          'Chat Geral da Comunidade',
                          'Bate-papo Livre',
                          'Discussões e Debates',
                          'Compartilhe sua Arte',
                          'Recomendações Musicais',
                        ][index % 5],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.people_rounded,
                              color: Colors.white70, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${(index + 1) * 73}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ==========================================================================
  // ESTADO VAZIO — Estilo Amino
  // ==========================================================================
  Widget _buildEmptyChats() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chat_bubble_outline_rounded,
                  size: 36, color: AppTheme.textHint),
            ),
            const SizedBox(height: 16),
            const Text('Nenhum chat ainda',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Entre em uma comunidade e comece a conversar!',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => context.go('/explore'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Explorar Mais Chats',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
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

// ============================================================================
// SIDEBAR ICON — Ícone na sidebar esquerda
// ============================================================================
class _SidebarIcon extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final String tooltip;
  final int badgeCount;

  const _SidebarIcon({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.tooltip,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.accentColor.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? AppTheme.accentColor : AppTheme.textHint,
                    size: 22,
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: AppTheme.aminoRed,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            badgeCount > 9 ? '9+' : badgeCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tooltip,
              style: TextStyle(
                color: isSelected ? AppTheme.accentColor : AppTheme.textHint,
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SIDEBAR COMMUNITY ICON — Ícone de comunidade na sidebar
// ============================================================================
class _SidebarCommunityIcon extends StatelessWidget {
  final CommunityModel community;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarCommunityIcon({
    required this.community,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: AppTheme.accentColor, width: 2)
                : Border.all(
                    color: AppTheme.dividerColor.withValues(alpha: 0.3),
                    width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: community.iconUrl != null
              ? CachedNetworkImage(
                  imageUrl: community.iconUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: AppTheme.cardColor,
                    child: Icon(Icons.groups_rounded,
                        color: AppTheme.textHint, size: 16),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppTheme.cardColor,
                    child: Icon(Icons.groups_rounded,
                        color: AppTheme.textHint, size: 16),
                  ),
                )
              : Container(
                  color: AppTheme.cardColor,
                  child: Icon(Icons.groups_rounded,
                      color: AppTheme.textHint, size: 16),
                ),
        ),
      ),
    );
  }
}

// ============================================================================
// CHAT TILE — Estilo Amino (avatar, nome, preview, timestamp, unread badge)
// ============================================================================
class _AminoChatTile extends StatelessWidget {
  final ChatRoomModel chatRoom;

  const _AminoChatTile({required this.chatRoom});

  @override
  Widget build(BuildContext context) {
    final hasUnread = chatRoom.unreadCount > 0;

    return GestureDetector(
      onTap: () => context.push('/chat/${chatRoom.id}'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // ── Avatar com frame cosmético ──
            CosmeticAvatar(
              userId: chatRoom.type == 'direct' ? chatRoom.hostId : null,
              avatarUrl: chatRoom.iconUrl,
              size: 48,
              showOnline: chatRoom.type == 'direct',
            ),
            const SizedBox(width: 12),

            // ── Info ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chatRoom.title,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    chatRoom.lastMessagePreview ?? 'Sem mensagens',
                    style: TextStyle(
                      color: hasUnread
                          ? AppTheme.textSecondary
                          : AppTheme.textHint,
                      fontSize: 12,
                      fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // ── Timestamp + Badge ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  chatRoom.lastMessageAt != null
                      ? timeago.format(chatRoom.lastMessageAt!, locale: 'pt_BR')
                      : '',
                  style: TextStyle(
                    color: hasUnread ? AppTheme.accentColor : AppTheme.textHint,
                    fontSize: 10,
                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (hasUnread) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      chatRoom.unreadCount > 99
                          ? '99+'
                          : chatRoom.unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
