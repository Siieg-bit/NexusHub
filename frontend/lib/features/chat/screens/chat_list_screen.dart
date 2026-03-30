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
import '../../../core/utils/responsive.dart';
import '../../../core/providers/dm_invite_provider.dart';
import '../widgets/dm_invite_card.dart';

/// Provider para lista de chats do usuário.
final chatListProvider = FutureProvider<List<ChatRoomModel>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];

  final response = await SupabaseService.table('chat_members')
      .select('thread_id, chat_threads(*)')
      .eq('user_id', userId)
      .order('joined_at', ascending: false);

  final chats = (response as List? ?? [])
      .where((e) => e['chat_threads'] != null)
      .map((e) =>
          ChatRoomModel.fromJson(e['chat_threads'] as Map<String, dynamic>))
      .toList();
  chats.sort((a, b) => (b.lastMessageAt ?? b.createdAt)
        .compareTo(a.lastMessageAt ?? a.createdAt));
  return chats;
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
  return (response as List? ?? [])
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
    } catch (e) {
      debugPrint('[chat_list_screen] Erro: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final chatsAsync = ref.watch(chatListProvider);
    final communitiesAsync = ref.watch(chatCommunitiesProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: AminoParticlesBg(
        child: Column(
          children: [
            // ── Top Bar Amino ──
            AminoTopBar(
              avatarUrl: _avatarUrl,
              coins: _coins,
              notificationCount: ref.watch(unreadNotificationCountProvider),
              onSearchTap: () => context.push('/search'),
              onAddTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: context.surfaceColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (ctx) => Padding(
                    padding: EdgeInsets.all(r.s(24)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Novo Chat',
                            style: TextStyle(
                                color: context.textPrimary,
                                fontSize: r.fs(18),
                                fontWeight: FontWeight.w800)),
                        SizedBox(height: r.s(20)),
                        ListTile(
                          leading: Container(
                            width: r.s(44),
                            height: r.s(44),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(r.s(12)),
                            ),
                            child: const Icon(Icons.person_add_rounded,
                                color: AppTheme.primaryColor),
                          ),
                          title: Text('Chat Privado',
                              style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text('Iniciar conversa com um usu\u00e1rio',
                              style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12))),
                          onTap: () {
                            Navigator.pop(ctx);
                            context.push('/search');
                          },
                        ),
                        ListTile(
                          leading: Container(
                            width: r.s(44),
                            height: r.s(44),
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(r.s(12)),
                            ),
                            child: const Icon(Icons.group_add_rounded,
                                color: AppTheme.accentColor),
                          ),
                          title: Text('Chat em Grupo',
                              style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text('Criar um grupo com v\u00e1rios membros',
                              style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12))),
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
                    width: r.s(64),
                    decoration: BoxDecoration(
                      color: context.surfaceColor.withValues(alpha: 0.5),
                      border: Border(
                        right: BorderSide(
                          color: context.dividerClr.withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        SizedBox(height: r.s(12)),

                        // Recente (ícone relógio)
                        _SidebarIcon(
                          icon: Icons.access_time_rounded,
                          isSelected: _selectedSidebarIndex == 0,
                          onTap: () => setState(() => _selectedSidebarIndex = 0),
                          tooltip: 'Recente',
                        ),

                        SizedBox(height: r.s(8)),

                        // Global (ícone globo com badge)
                        _SidebarIcon(
                          icon: Icons.public_rounded,
                          isSelected: _selectedSidebarIndex == 1,
                          onTap: () => setState(() => _selectedSidebarIndex = 1),
                          tooltip: 'Global',
                          badgeCount: 0,
                        ),

                        SizedBox(height: r.s(4)),

                        // Divider
                        Container(
                          width: r.s(28),
                          height: 1,
                          color: context.dividerClr.withValues(alpha: 0.4),
                        ),

                        SizedBox(height: r.s(4)),

                        // Comunidades do usuário
                        Expanded(
                          child: communitiesAsync.when(
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (communities) => ListView.builder(
                              padding: EdgeInsets.symmetric(vertical: r.s(4)),
                              itemCount: communities.length,
                              itemBuilder: (context, index) {
                                final community = communities[index];
                                return Padding(
                                  padding: EdgeInsets.only(bottom: r.s(8)),
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
                          padding: EdgeInsets.only(bottom: r.s(16)),
                          child: GestureDetector(
                            onTap: () => context.go('/explore'),
                            child: Container(
                              width: r.s(36),
                              height: r.s(36),
                              decoration: BoxDecoration(
                                color: context.cardBg,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.dividerClr.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Icon(Icons.add,
                                  color: context.textSecondary, size: r.s(20)),
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
                                size: r.s(48), color: context.textHint),
                            SizedBox(height: r.s(12)),
                            Text('Erro ao carregar chats',
                                style: TextStyle(
                                    color: context.textSecondary, fontSize: r.fs(14))),
                          ],
                        ),
                      ),
                      data: (chatRooms) {
                        if (_selectedSidebarIndex == 1) {
                          // Global — mostrar recomendados
                          return _buildRecommendedChats();
                        }

                        // Filtrar por comunidade selecionada na sidebar
                        final filtered = _selectedSidebarIndex >= 2
                            ? communitiesAsync.whenOrNull(
                                data: (communities) {
                                  final idx = _selectedSidebarIndex - 2;
                                  if (idx >= communities.length) return chatRooms;
                                  final cid = communities[idx].id;
                                  return chatRooms
                                      .where((c) => c.communityId == cid)
                                      .toList();
                                },
                              ) ?? chatRooms
                            : chatRooms;

                        if (filtered.isEmpty) {
                          return _buildEmptyChats();
                        }
                        return _buildChatList(filtered);
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
      final r = context.r;
      final pendingInvites = ref.watch(pendingDmInvitesProvider);
    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async {
        ref.invalidate(chatListProvider);
        ref.invalidate(chatCommunitiesProvider);
        ref.invalidate(pendingDmInvitesProvider);
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: r.s(8),
          bottom: MediaQuery.of(context).padding.bottom + 80,
        ),
        children: [
          // ── Convites de DM pendentes ──
          ...pendingInvites.when(
            loading: () => <Widget>[],
            error: (_, __) => <Widget>[],
            data: (invites) {
              if (invites.isEmpty) return <Widget>[];
              return <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(r.s(16), r.s(4), r.s(16), r.s(8)),
                  child: Row(
                    children: [
                      Icon(Icons.mail_rounded, color: AppTheme.accentColor, size: r.s(16)),
                      SizedBox(width: r.s(6)),
                      Text(
                        'Convites pendentes',
                        style: TextStyle(
                          color: AppTheme.accentColor,
                          fontSize: r.fs(13),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                ...invites.map((invite) => DmInviteCard(invite: invite)),
                Divider(
                  color: context.dividerClr.withValues(alpha: 0.3),
                  height: r.s(16),
                  indent: r.s(16),
                  endIndent: r.s(16),
                ),
              ];
            },
          ),
          // ── Lista de chats ──
          ...chatRooms.map((chatRoom) => _AminoChatTile(chatRoom: chatRoom)),
        ],
      ),
    );
  }

  // ==========================================================================
  // RECOMENDADOS — Estilo Amino (cards grandes com imagem de fundo)
  // ==========================================================================
  Widget _buildRecommendedChats() {
      final r = context.r;
    return ListView(
      padding: EdgeInsets.only(
        top: r.s(8),
        bottom: MediaQuery.of(context).padding.bottom + 80,
      ),
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(r.s(16), r.s(8), r.s(16), r.s(12)),
          child: Text(
            'Recomendados',
            style: TextStyle(
              fontSize: r.fs(18),
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
          ),
        ),
        // Placeholder cards para chats recomendados
        ...List.generate(5, (index) {
          return Container(
            margin: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(6)),
            height: r.s(120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(r.s(12)),
              color: context.cardBg,
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
                  padding: EdgeInsets.all(r.s(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Badge da comunidade
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.s(8), vertical: r.s(3)),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(r.s(8)),
                        ),
                        child: Text(
                          ['Anime', 'K-Pop', 'Gaming', 'Art', 'Music'][index % 5],
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: r.fs(10),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(height: r.s(6)),
                      Text(
                        [
                          'Chat Geral da Comunidade',
                          'Bate-papo Livre',
                          'Discussões e Debates',
                          'Compartilhe sua Arte',
                          'Recomendações Musicais',
                        ][index % 5],
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: r.fs(15),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: r.s(4)),
                      Row(
                        children: [
                          Icon(Icons.people_rounded,
                              color: Colors.white70, size: r.s(14)),
                          SizedBox(width: r.s(4)),
                          Text(
                            '${(index + 1) * 73}',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: r.fs(12),
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
      final r = context.r;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(r.s(32)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: r.s(80),
              height: r.s(80),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chat_bubble_outline_rounded,
                  size: r.s(36), color: context.textHint),
            ),
            SizedBox(height: r.s(16)),
            Text('Nenhum chat ainda',
                style: TextStyle(
                    color: context.textPrimary,
                    fontSize: r.fs(16),
                    fontWeight: FontWeight.w600)),
            SizedBox(height: r.s(8)),
            Text('Entre em uma comunidade e comece a conversar!',
                style: TextStyle(color: context.textSecondary, fontSize: r.fs(13)),
                textAlign: TextAlign.center),
            SizedBox(height: r.s(24)),
            GestureDetector(
              onTap: () => context.go('/explore'),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: r.s(20), vertical: r.s(10)),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor,
                  borderRadius: BorderRadius.circular(r.s(20)),
                ),
                child: Text(
                  'Explorar Mais Chats',
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
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: r.s(40),
              height: r.s(40),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.accentColor.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(r.s(12)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? AppTheme.accentColor : context.textHint,
                    size: r.s(22),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: r.s(14),
                        height: r.s(14),
                        decoration: const BoxDecoration(
                          color: AppTheme.aminoRed,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            badgeCount > 9 ? '9+' : badgeCount.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: r.fs(8),
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
                color: isSelected ? AppTheme.accentColor : context.textHint,
                fontSize: r.fs(9),
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
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Container(
          width: r.s(36),
          height: r.s(36),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r.s(10)),
            border: isSelected
                ? Border.all(color: AppTheme.accentColor, width: 2)
                : Border.all(
                    color: context.dividerClr.withValues(alpha: 0.3),
                    width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: community.iconUrl != null && community.iconUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: community.iconUrl ?? '',
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: context.cardBg,
                    child: Icon(Icons.groups_rounded,
                        color: context.textHint, size: r.s(16)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: context.cardBg,
                    child: Icon(Icons.groups_rounded,
                        color: context.textHint, size: r.s(16)),
                  ),
                )
              : Container(
                  color: context.cardBg,
                  child: Icon(Icons.groups_rounded,
                      color: context.textHint, size: r.s(16)),
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
    final r = context.r;
    final hasUnread = chatRoom.unreadCount > 0;

    return GestureDetector(
      onTap: () => context.push('/chat/${chatRoom.id}'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(10)),
        child: Row(
          children: [
            // ── Avatar com frame cosmético ──
            CosmeticAvatar(
              userId: chatRoom.type == 'direct' ? chatRoom.hostId : null,
              avatarUrl: chatRoom.iconUrl,
              size: r.s(48),
              showOnline: chatRoom.type == 'direct',
            ),
            SizedBox(width: r.s(12)),

            // ── Info ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chatRoom.title,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: r.fs(14),
                      fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: r.s(3)),
                  Text(
                    chatRoom.lastMessagePreview ?? 'Sem mensagens',
                    style: TextStyle(
                      color: hasUnread
                          ? context.textSecondary
                          : context.textHint,
                      fontSize: r.fs(12),
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
                    color: hasUnread ? AppTheme.accentColor : context.textHint,
                    fontSize: r.fs(10),
                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (hasUnread) ...[
                  SizedBox(height: r.s(4)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: r.s(6), vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor,
                      borderRadius: BorderRadius.circular(r.s(10)),
                    ),
                    child: Text(
                      chatRoom.unreadCount > 99
                          ? '99+'
                          : chatRoom.unreadCount.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: r.fs(10),
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
