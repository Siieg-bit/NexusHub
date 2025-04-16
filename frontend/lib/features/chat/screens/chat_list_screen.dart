import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/models/chat_room_model.dart';
import '../../../core/models/community_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/amino_top_bar.dart';
import '../../../core/widgets/amino_particles_bg.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../../core/providers/notification_provider.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/providers/dm_invite_provider.dart';
import '../../../core/providers/chat_provider.dart'
    show unreadCountProvider, unreadCountByCommunityProvider;
import '../widgets/dm_invite_card.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../stories/screens/story_viewer_screen.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Provider para "Meus chats" — lista pessoal do usuário.
/// Retorna apenas threads com membership ativo (status != 'left').
/// NÃO mistura com "Chats públicos disponíveis" (descoberta/exploração).
/// Ordena fixados no topo (is_pinned_by_user=true), depois por última mensagem.
final chatListProvider = FutureProvider<List<ChatRoomModel>>((ref) async {
  Map<String, dynamic>? extractProfile(dynamic rawProfile) {
    if (rawProfile is Map<String, dynamic>) return rawProfile;
    if (rawProfile is Map) return Map<String, dynamic>.from(rawProfile);
    if (rawProfile is List && rawProfile.isNotEmpty) {
      final first = rawProfile.first;
      if (first is Map<String, dynamic>) return first;
      if (first is Map) return Map<String, dynamic>.from(first);
    }
    return null;
  }

  String? normalizedString(dynamic value) {
    final text = value as String?;
    if (text == null) return null;
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];

  final response = await SupabaseService.table('chat_members')
      .select(
          'thread_id, status, is_pinned_by_user, pinned_at, chat_threads(*)')
      .eq('user_id', userId)
      .neq('status', 'left') // "Meus chats" = apenas membership ativo
      .order('joined_at', ascending: false);

  final rawChats = (response as List? ?? [])
      .where((e) => e['chat_threads'] != null)
      .toList();

  bool isDirectLikeThread(Map<String, dynamic>? thread) {
    if (thread == null) return false;
    final type = thread['type'] as String? ?? '';
    if (type == 'dm') return true;
    if (type == 'public') return false;

    final communityId = thread['community_id'] as String?;
    final membersCount = thread['members_count'] as int? ?? 0;
    final hasGenericTitle =
        ((thread['title'] as String?) ?? '').trim().toLowerCase() == 'chat';

    return communityId == null && (membersCount <= 2 || hasGenericTitle);
  }

  final dmThreadsById = <String, Map<String, dynamic>>{};
  for (final row in rawChats) {
    final thread = row['chat_threads'] as Map<String, dynamic>?;
    final threadId = row['thread_id'] as String?;
    if (threadId == null || !isDirectLikeThread(thread)) continue;
    dmThreadsById[threadId] = Map<String, dynamic>.from(thread!);
  }

  final dmThreadIds = dmThreadsById.keys.toList();
  final Map<String, Map<String, dynamic>> dmCounterparts = {};
  if (dmThreadIds.isNotEmpty) {
    try {
      final dmMembers = await SupabaseService.table('chat_members')
          .select(
              'thread_id, user_id, profiles!chat_members_user_id_fkey(id, nickname, icon_url, banner_url, online_status, is_ghost_mode, last_seen_at)')
          .inFilter('thread_id', dmThreadIds)
          .neq('user_id', userId);

      final counterpartRows = (dmMembers as List? ?? [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

      final counterpartUserIds = counterpartRows
          .map((row) => row['user_id'] as String?)
          .whereType<String>()
          .toSet();
      final communityIds = dmThreadsById.values
          .map((thread) => normalizedString(thread['community_id']))
          .whereType<String>()
          .toSet();

      final Map<String, Map<String, dynamic>> localMemberships = {};
      if (counterpartUserIds.isNotEmpty && communityIds.isNotEmpty) {
        final membershipRes = await SupabaseService.table('community_members')
            .select(
                'community_id, user_id, local_nickname, local_icon_url, local_banner_url')
            .inFilter('community_id', communityIds.toList())
            .inFilter('user_id', counterpartUserIds.toList());

        for (final row in (membershipRes as List? ?? [])) {
          final membership = Map<String, dynamic>.from(row as Map);
          final communityId = normalizedString(membership['community_id']);
          final memberUserId = normalizedString(membership['user_id']);
          if (communityId == null || memberUserId == null) continue;
          localMemberships['$communityId:$memberUserId'] = membership;
        }
      }

      for (final row in counterpartRows) {
        final threadId = row['thread_id'] as String?;
        final counterpartUserId = normalizedString(row['user_id']);
        final profile = extractProfile(row['profiles']);
        if (threadId == null || counterpartUserId == null || profile == null) {
          continue;
        }

        final mergedProfile = Map<String, dynamic>.from(profile)
          ..['user_id'] = counterpartUserId;
        final communityId =
            normalizedString(dmThreadsById[threadId]?['community_id']);
        final membership = communityId == null
            ? null
            : localMemberships['$communityId:$counterpartUserId'];

        if (membership != null) {
          // Usa sempre o valor local da comunidade (pode ser null se não definido).
          mergedProfile['nickname'] = normalizedString(membership['local_nickname']);
          mergedProfile['icon_url'] = normalizedString(membership['local_icon_url']);
          mergedProfile['banner_url'] = normalizedString(membership['local_banner_url']);
        }

        dmCounterparts[threadId] = mergedProfile;
      }
    } catch (e) {
      debugPrint('[ChatList] Erro ao enriquecer DMs: $e');
    }
  }

  final chats = rawChats.map((e) {
    final threadMap =
        Map<String, dynamic>.from(e['chat_threads'] as Map<String, dynamic>);
    // Injetar campos de membership no modelo do thread:
    // - isPinnedByUser: preferência pessoal, nunca global
    // - membershipStatus: fonte de verdade para regras de acesso por tipo
    threadMap['is_pinned_by_user'] = e['is_pinned_by_user'] as bool? ?? false;
    threadMap['pinned_at'] = e['pinned_at'];
    threadMap['membership_status'] = e['status'] as String? ?? 'active';

    if (isDirectLikeThread(threadMap)) {
      final dmThreadId =
          e['thread_id'] as String? ?? threadMap['id'] as String? ?? '';
      final counterpart = dmCounterparts[dmThreadId];
      if (counterpart != null) {
        threadMap['title'] = counterpart['nickname'] ?? threadMap['title'];
        threadMap['icon_url'] = counterpart['icon_url'];
        threadMap['host_id'] =
            counterpart['id'] ?? counterpart['user_id'] ?? threadMap['host_id'];
        threadMap['counterpart_online_status'] = counterpart['online_status'] ??
            threadMap['counterpart_online_status'];
        threadMap['counterpart_is_ghost_mode'] = counterpart['is_ghost_mode'] ??
            threadMap['counterpart_is_ghost_mode'];
        threadMap['counterpart_last_seen_at'] = counterpart['last_seen_at'] ??
            threadMap['counterpart_last_seen_at'];
      }
    }

    return ChatRoomModel.fromJson(threadMap);
  }).toList();

  // Ordenar: fixados no topo (por pinned_at desc), depois por última mensagem
  chats.sort((a, b) {
    if (a.isPinnedByUser && !b.isPinnedByUser) return -1;
    if (!a.isPinnedByUser && b.isPinnedByUser) return 1;
    return (b.lastMessageAt ?? b.createdAt)
        .compareTo(a.lastMessageAt ?? a.createdAt);
  });
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

/// Provider para stories dos usuários que o usuário atual segue.
/// Agrupa por autor, filtra apenas stories ativos não expirados.
final followingStoriesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];
  try {
    // Buscar quem o usuário segue
    final follows = await SupabaseService.table('follows')
        .select('following_id')
        .eq('follower_id', userId)
        .limit(50);
    final followingIds = (follows as List? ?? [])
        .map((r) => r['following_id'] as String?)
        .whereType<String>()
        .toList();
    if (followingIds.isEmpty) return [];

    // Buscar stories ativos dos seguidos
    final now = DateTime.now().toUtc().toIso8601String();
    final stories = await SupabaseService.table('stories')
        .select('*, profiles!author_id(id, nickname, icon_url)')
        .inFilter('author_id', followingIds)
        .eq('is_active', true)
        .gte('expires_at', now)
        .order('created_at', ascending: false)
        .limit(100);

    // Agrupar por autor
    final grouped = <String, Map<String, dynamic>>{};
    for (final story in (stories as List? ?? [])) {
      final authorId = story['author_id'] as String? ?? '';
      if (authorId.isEmpty) continue;
      if (!grouped.containsKey(authorId)) {
        grouped[authorId] = {
          'author_id': authorId,
          'profile': story['profiles'],
          'stories': <Map<String, dynamic>>[],
          'has_unviewed': false,
        };
      }
      (grouped[authorId]!['stories'] as List).add(Map<String, dynamic>.from(story as Map));
    }

    // Verificar stories não vistos
    if (grouped.isNotEmpty) {
      final allStoryIds = (stories as List<dynamic>)
          .map((s) => (s as Map<String, dynamic>)['id'] as String?)
          .whereType<String>()
          .toList();
      try {
        final viewed = await SupabaseService.table('story_views')
            .select('story_id')
            .eq('viewer_id', userId)
            .inFilter('story_id', allStoryIds);
        // viewer_id é o campo correto (confirmado no story_carousel)
        final viewedIds = (viewed as List)
            .map((v) => v['story_id'] as String?)
            .whereType<String>()
            .toSet();
        for (final group in grouped.values) {
          final groupStories = group['stories'] as List;
          group['has_unviewed'] =
              groupStories.any((s) => !viewedIds.contains(s['id']));
        }
      } catch (_) {}
    }

    // Ordenar: não vistos primeiro
    final result = grouped.values.toList()
      ..sort((a, b) {
        final aUnviewed = a['has_unviewed'] as bool? ?? false;
        final bUnviewed = b['has_unviewed'] as bool? ?? false;
        if (aUnviewed && !bUnviewed) return -1;
        if (!aUnviewed && bUnviewed) return 1;
        return 0;
      });
    return result;
  } catch (e) {
    debugPrint('[followingStoriesProvider] error: \$e');
    return [];
  }
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
  // _avatarUrl removido: agora usa currentUserAvatarProvider (atualização em tempo real)
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
      // Carregar apenas coins (avatar vem do currentUserAvatarProvider em tempo real)
      final profile = await SupabaseService.table('profiles')
          .select('coins')
          .eq('id', userId)
          .single();
      if (mounted) {
        setState(() {
          _coins = profile['coins'] as int? ?? 0;
        });
      }
    } catch (e) {
      debugPrint('[chat_list_screen] Erro: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final chatsAsync = ref.watch(chatListProvider);
    final communitiesAsync = ref.watch(chatCommunitiesProvider);
    // Determinar communityId selecionado para exibir avatar local
    String? _selectedCommunityId;
    if (_selectedSidebarIndex >= 2) {
      final communities = communitiesAsync.valueOrNull;
      if (communities != null) {
        final idx = _selectedSidebarIndex - 2;
        if (idx < communities.length) {
          _selectedCommunityId = communities[idx].id;
        }
      }
    }
    final _topBarAvatar = _selectedCommunityId != null
        ? ref.watch(communityLocalAvatarProvider(_selectedCommunityId)).valueOrNull
            ?? ref.watch(currentUserAvatarProvider)
        : ref.watch(currentUserAvatarProvider);

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      body: AminoParticlesBg(
        child: Column(
          children: [
            // ── Top Bar Amino ──
            AminoTopBar(
              avatarUrl: _topBarAvatar,
              coins: _coins,
              notificationCount: ref.watch(unreadNotificationCountProvider),
              onSearchTap: () => context.push('/search'),
              onAddTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: context.surfaceColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (ctx) => Padding(
                    padding: EdgeInsets.all(r.s(24)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(s.newChatTitle,
                            style: TextStyle(
                                color: context.nexusTheme.textPrimary,
                                fontSize: r.fs(18),
                                fontWeight: FontWeight.w800)),
                        SizedBox(height: r.s(20)),
                        ListTile(
                          leading: Container(
                            width: r.s(44),
                            height: r.s(44),
                            decoration: BoxDecoration(
                              color: context.nexusTheme.accentPrimary
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(r.s(12)),
                            ),
                            child: Icon(Icons.person_add_rounded,
                                color: context.nexusTheme.accentPrimary),
                          ),
                          title: Text(s.privateChatLabel,
                              style: TextStyle(
                                  color: context.nexusTheme.textPrimary,
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(s.startConversationUser,
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: r.fs(12))),
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
                              color: context.nexusTheme.accentSecondary
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(r.s(12)),
                            ),
                            child: Icon(Icons.group_add_rounded,
                                color: context.nexusTheme.accentSecondary),
                          ),
                          title: Text(s.groupChatLabel,
                              style: TextStyle(
                                  color: context.nexusTheme.textPrimary,
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              'Criar um grupo com v\u00e1rios membros',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: r.fs(12))),
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
                          onTap: () =>
                              setState(() => _selectedSidebarIndex = 0),
                          tooltip: s.recent,
                        ),

                        SizedBox(height: r.s(8)),

                        // Global (ícone globo com badge)
                        _SidebarIcon(
                          icon: Icons.public_rounded,
                          isSelected: _selectedSidebarIndex == 1,
                          onTap: () =>
                              setState(() => _selectedSidebarIndex = 1),
                          tooltip: s.global,
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
                                    isSelected:
                                        _selectedSidebarIndex == index + 2,
                                    onTap: () => setState(() =>
                                        _selectedSidebarIndex = index + 2),
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
                                color: context.nexusTheme.surfacePrimary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      context.dividerClr.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Icon(Icons.add,
                                  color: context.nexusTheme.textSecondary,
                                  size: r.s(20)),
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
                      loading: () => Center(
                        child: CircularProgressIndicator(
                          color: context.nexusTheme.accentSecondary,
                          strokeWidth: 2.5,
                        ),
                      ),
                      error: (error, _) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline_rounded,
                                size: r.s(48),
                                color: context.nexusTheme.textHint),
                            SizedBox(height: r.s(12)),
                            Text(s.errorLoadingChats,
                                style: TextStyle(
                                    color: context.nexusTheme.textSecondary,
                                    fontSize: r.fs(14))),
                          ],
                        ),
                      ),
                      data: (chatRooms) {
                        if (_selectedSidebarIndex == 1) {
                          // Global — mostrar recomendados
                          return _buildRecommendedChats();
                        }

                        // Filtrar por comunidade selecionada na sidebar
                        // Índice 0 (Recente) = apenas chats sem comunidade (DMs globais)
                        // Índice 2+ = chats da comunidade selecionada
                        final filtered = _selectedSidebarIndex >= 2
                            ? communitiesAsync.whenOrNull(
                                  data: (communities) {
                                    final idx = _selectedSidebarIndex - 2;
                                    if (idx >= communities.length)
                                      return chatRooms;
                                    final cid = communities[idx].id;
                                    return chatRooms
                                        .where((c) => c.communityId == cid)
                                        .toList();
                                  },
                                ) ??
                                chatRooms
                            : _selectedSidebarIndex == 0
                                ? chatRooms
                                    .where((c) => c.communityId == null)
                                    .toList()
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
    final s = getStrings();
    final r = context.r;
    final pendingInvites = ref.watch(pendingDmInvitesProvider);
    return RefreshIndicator(
      color: context.nexusTheme.accentPrimary,
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
                  padding:
                      EdgeInsets.fromLTRB(r.s(16), r.s(4), r.s(16), r.s(8)),
                  child: Row(
                    children: [
                      Icon(Icons.mail_rounded,
                          color: context.nexusTheme.accentSecondary,
                          size: r.s(16)),
                      SizedBox(width: r.s(6)),
                      Text(
                        s.pendingInvites,
                        style: TextStyle(
                          color: context.nexusTheme.accentSecondary,
                          fontSize: r.fs(13),
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
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
          // ── Stories dos seguidos (tipo Instagram) ──
          _buildFollowingStoriesBar(r),

          // ── Lista de chats ──
          ...chatRooms.map((chatRoom) => _AminoChatTile(chatRoom: chatRoom)),
        ],
      ),
    );
  }

  // ==========================================================================
  // STORIES DOS SEGUIDOS — Barra horizontal estilo Instagram
  // ==========================================================================
  Widget _buildFollowingStoriesBar(Responsive r) {
    final storiesAsync = ref.watch(followingStoriesProvider);
    return storiesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (groups) {
        if (groups.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(r.s(16), r.s(8), r.s(16), r.s(4)),
              child: Row(
                children: [
                  Icon(Icons.auto_stories_rounded,
                      color: context.nexusTheme.accentPrimary, size: r.s(14)),
                  SizedBox(width: r.s(6)),
                  Text(
                    'Status',
                    style: TextStyle(
                      color: context.nexusTheme.textSecondary,
                      fontSize: r.fs(12),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: r.s(90),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: r.s(12)),
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  final profile = group['profile'] as Map<String, dynamic>?;
                  final username = (profile?['nickname'] as String?) ?? '?';
                  final avatarUrl = profile?['icon_url'] as String?;
                  final hasUnviewed = group['has_unviewed'] as bool? ?? false;
                  final stories = (group['stories'] as List)
                      .map((s) => Map<String, dynamic>.from(s as Map))
                      .toList();
                  return Padding(
                    padding: EdgeInsets.only(right: r.s(12)),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => _FollowingStoryViewer(
                            stories: stories,
                            authorProfile: profile ?? {},
                          ),
                        ));
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: r.s(56),
                            height: r.s(56),
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: hasUnviewed
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFE91E63),
                                        Color(0xFFFF5722),
                                        Color(0xFFFF9800),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              border: hasUnviewed
                                  ? null
                                  : Border.all(
                                      color: Colors.grey[700] ?? Colors.grey,
                                      width: 2),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: context.nexusTheme.backgroundPrimary,
                                    width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 22,
                                backgroundColor:
                                    context.nexusTheme.surfacePrimary,
                                backgroundImage: avatarUrl != null
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: avatarUrl == null
                                    ? Text(
                                        username[0].toUpperCase(),
                                        style: TextStyle(
                                          color: context.nexusTheme.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          SizedBox(height: r.s(4)),
                          SizedBox(
                            width: r.s(56),
                            child: Text(
                              username,
                              style: TextStyle(
                                color: hasUnviewed
                                    ? context.nexusTheme.textPrimary
                                    : Colors.grey[600],
                                fontSize: r.fs(10),
                                fontWeight: hasUnviewed
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Divider(
              color: context.dividerClr.withValues(alpha: 0.3),
              height: r.s(8),
              indent: r.s(16),
              endIndent: r.s(16),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================================
  // RECOMENDADOS — Estilo Amino (cards grandes com imagem de fundo)
  // ==========================================================================
  Widget _buildRecommendedChats() {
    final s = getStrings();
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
            s.recommended,
            style: TextStyle(
              fontSize: r.fs(18),
              fontWeight: FontWeight.w700,
              color: context.nexusTheme.textPrimary,
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
              color: context.nexusTheme.surfacePrimary,
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
                        [
                          context.nexusTheme.accentPrimary,
                          context.nexusTheme.accentPrimary
                        ],
                        [
                          context.nexusTheme.accentSecondary,
                          context.nexusTheme.accentPrimary
                        ],
                        [
                          context.nexusTheme.accentPrimary,
                          context.nexusTheme.accentSecondary
                        ],
                        [context.nexusTheme.warning, context.nexusTheme.error],
                        [
                          context.nexusTheme.accentPrimary,
                          context.nexusTheme.accentSecondary
                        ],
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
                          [
                            s.interestAnime,
                            s.interestKpop,
                            'Gaming',
                            'Art',
                            'Music'
                          ][index % 5],
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
                          s.discussionsAndDebates,
                          'Compartilhe sua Arte',
                          s.musicRecommendations,
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
    final s = getStrings();
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
                  size: r.s(36), color: context.nexusTheme.textHint),
            ),
            SizedBox(height: r.s(16)),
            Text(s.noChatsYet,
                style: TextStyle(
                    color: context.nexusTheme.textPrimary,
                    fontSize: r.fs(16),
                    fontWeight: FontWeight.w600)),
            SizedBox(height: r.s(8)),
            Text(s.joinCommunityStartChat,
                style: TextStyle(
                    color: context.nexusTheme.textSecondary,
                    fontSize: r.fs(13)),
                textAlign: TextAlign.center),
            SizedBox(height: r.s(24)),
            GestureDetector(
              onTap: () => context.go('/explore'),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: r.s(20), vertical: r.s(10)),
                decoration: BoxDecoration(
                  color: context.nexusTheme.accentSecondary,
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
class _SidebarIcon extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
                    ? context.nexusTheme.accentSecondary.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(r.s(12)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    icon,
                    color: isSelected
                        ? context.nexusTheme.accentSecondary
                        : context.nexusTheme.textHint,
                    size: r.s(22),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: r.s(14),
                        height: r.s(14),
                        decoration: BoxDecoration(
                          color: context.nexusTheme.error,
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
                color: isSelected
                    ? context.nexusTheme.accentSecondary
                    : context.nexusTheme.textHint,
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
class _SidebarCommunityIcon extends ConsumerWidget {
  final CommunityModel community;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarCommunityIcon({
    required this.community,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                ? Border.all(
                    color: context.nexusTheme.accentSecondary, width: 2)
                : Border.all(
                    color: context.dividerClr.withValues(alpha: 0.3), width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: community.iconUrl != null && community.iconUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: community.iconUrl ?? '',
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: context.nexusTheme.surfacePrimary,
                    child: Icon(Icons.groups_rounded,
                        color: context.nexusTheme.textHint, size: r.s(16)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: context.nexusTheme.surfacePrimary,
                    child: Icon(Icons.groups_rounded,
                        color: context.nexusTheme.textHint, size: r.s(16)),
                  ),
                )
              : Container(
                  color: context.nexusTheme.surfacePrimary,
                  child: Icon(Icons.groups_rounded,
                      color: context.nexusTheme.textHint, size: r.s(16)),
                ),
        ),
      ),
    );
  }
}

// ============================================================================
// CHAT TILE — Estilo Amino (avatar, nome, preview, timestamp, unread badge)
// ============================================================================
class _AminoChatTile extends ConsumerWidget {
  final ChatRoomModel chatRoom;

  const _AminoChatTile({required this.chatRoom});

  /// Exibe o menu contextual de long press.
  Future<void> _showContextMenu(BuildContext context, WidgetRef ref) async {
    final s = getStrings();
    final r = context.r;
    final isPinned = chatRoom.isPinnedByUser;
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.nexusTheme.surfacePrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: EdgeInsets.only(top: r.s(10), bottom: r.s(4)),
              width: r.s(36),
              height: r.s(4),
              decoration: BoxDecoration(
                color: context.dividerClr,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Título do chat
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
              child: Text(
                chatRoom.title,
                style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontSize: r.fs(15),
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Divider(
                color: context.dividerClr.withValues(alpha: 0.3), height: 1),
            // Opção: Fixar / Desafixar
            ListTile(
              leading: Icon(
                isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                color: isPinned
                    ? context.nexusTheme.accentSecondary
                    : context.nexusTheme.textSecondary,
                size: r.s(22),
              ),
              title: Text(
                isPinned ? s.unpinFromTop : s.pinToTop,
                style: TextStyle(
                    color: context.nexusTheme.textPrimary, fontSize: r.fs(14)),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                try {
                  if (isPinned) {
                    await SupabaseService.rpc('unpin_chat_for_user', params: {
                      'p_thread_id': chatRoom.id,
                    });
                  } else {
                    await SupabaseService.rpc('pin_chat_for_user', params: {
                      'p_thread_id': chatRoom.id,
                    });
                  }
                  ref.invalidate(chatListProvider);
                } catch (e) {
                  debugPrint('[ChatList] Pin/unpin error: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Erro ao ${isPinned ? 'desafixar' : 'fixar'} chat.'),
                        backgroundColor: context.nexusTheme.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
            ),
            // Opção: Sair/Ocultar/Apagar — semântica diferenciada por tipo.
            // public: "Sair do chat" — usuário pode re-entrar depois.
            // group:  "Sair do grupo" — re-entrada por convite (Etapa 2+).
            // dm:     "Apagar conversa" — oculta da lista pessoal, não apaga o thread global.
            // Em todos os casos: marca status='left' via RPC leave_public_chat.
            // NÃO deleta a linha de chat_members — isso quebraria a semântica de saída.
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: context.nexusTheme.error,
                size: r.s(22),
              ),
              title: Text(
                chatRoom.type == 'dm'
                    ? s.deleteConversation
                    : chatRoom.type == 'group'
                        ? s.leaveGroup
                        : s.leaveChat,
                style: TextStyle(
                    color: context.nexusTheme.error, fontSize: r.fs(14)),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                if (!context.mounted) return;
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    backgroundColor: context.nexusTheme.surfacePrimary,
                    title: Text(
                      chatRoom.type == 'dm'
                          ? 'Apagar conversa?'
                          : chatRoom.type == 'group'
                              ? 'Sair do grupo?'
                              : 'Sair do chat?',
                      style: TextStyle(
                          color: context.nexusTheme.textPrimary,
                          fontSize: r.fs(16),
                          fontWeight: FontWeight.w700),
                    ),
                    content: Text(
                      chatRoom.type == 'dm'
                          ? s.conversationRemovedFromList
                          : chatRoom.type == 'group'
                              ? s.needNewInvite
                              : 'Você poderá entrar novamente depois.',
                      style: TextStyle(
                          color: context.nexusTheme.textSecondary,
                          fontSize: r.fs(13)),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dCtx).pop(false),
                        child: Text(s.cancel,
                            style: TextStyle(
                                color: context.nexusTheme.textSecondary,
                                fontSize: r.fs(13))),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dCtx).pop(true),
                        child: Text(
                          chatRoom.type == 'dm' ? s.deleteAction : s.logout,
                          style: TextStyle(
                              color: context.nexusTheme.error,
                              fontWeight: FontWeight.w700,
                              fontSize: r.fs(13)),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;
                // Fonte de verdade: leave_public_chat marca status='left'.
                // NÃO deleta a linha — preserva semântica de saída intencional.
                try {
                  await SupabaseService.rpc('leave_public_chat', params: {
                    'p_thread_id': chatRoom.id,
                  });
                  ref.invalidate(chatListProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(chatRoom.type == 'dm'
                            ? 'Conversa apagada.'
                            : chatRoom.type == 'group'
                                ? s.leftGroup
                                : s.leftChat),
                        backgroundColor: context.nexusTheme.accentPrimary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('[ChatList] Leave from context menu error: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(chatRoom.type == 'dm'
                            ? 'Erro ao apagar conversa.'
                            : 'Erro ao sair do chat.'),
                        backgroundColor: context.nexusTheme.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
            ),
            SizedBox(height: r.s(8)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final hasUnread = chatRoom.unreadCount > 0;
    final isPinned = chatRoom.isPinnedByUser;
    final isDirectLikeChat = chatRoom.type == 'dm' ||
        (chatRoom.type != 'public' &&
            chatRoom.communityId == null &&
            (chatRoom.membersCount <= 2 ||
                chatRoom.title.trim().toLowerCase() == 'chat'));
    final counterpartUserId = chatRoom.hostId;
    final showOnlineIndicator = isDirectLikeChat &&
        counterpartUserId != null &&
        counterpartUserId.isNotEmpty &&
        chatRoom.isCounterpartOnline;

    // GestureDetector com HitTestBehavior.translucent:
    // - translucent permite que o ListView receba o scroll normalmente
    // - onLongPress é processado pelo GestureDetector antes do scroll iniciar
    // - Container com BoxDecoration não intercepta o gesto (translucent passa por ele)
    // Nota: InkWell com Container(decoration) quebrava o long press porque
    // o RenderDecoratedBox criado pelo BoxDecoration interceptava o hit test.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => context.push('/chat/${chatRoom.id}').then((_) {
        // Ao voltar do chat, invalidar todos os providers de unread para refletir
        // o unread_count zerado pelo mark_chat_read chamado no chat_room_screen
        ref.invalidate(chatListProvider);
        ref.invalidate(chatCommunitiesProvider);
        ref.invalidate(unreadCountProvider);
        ref.invalidate(unreadCountByCommunityProvider);
      }),
      onLongPress: () => _showContextMenu(context, ref),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(10)),
        decoration: isPinned
            ? BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: context.nexusTheme.accentSecondary
                        .withValues(alpha: 0.6),
                    width: 3,
                  ),
                ),
              )
            : null,
        child: Row(
          children: [
            isDirectLikeChat
                ? CosmeticAvatar(
                    userId: chatRoom.hostId,
                    avatarUrl: chatRoom.iconUrl,
                    size: r.s(48),
                    showOnline: showOnlineIndicator,
                  )
                : Container(
                    width: r.s(56),
                    height: r.s(48),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(r.s(10)),
                      color: context.nexusTheme.surfacePrimary,
                      border: Border.all(
                        color: context.dividerClr.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (chatRoom.coverImageUrl ?? chatRoom.iconUrl) !=
                                null &&
                            (chatRoom.coverImageUrl ?? chatRoom.iconUrl)!
                                .isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl:
                                (chatRoom.coverImageUrl ?? chatRoom.iconUrl)!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: context.nexusTheme.surfacePrimary,
                              child: Icon(
                                Icons.forum_rounded,
                                color: context.nexusTheme.textSecondary,
                                size: r.s(22),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: context.nexusTheme.surfacePrimary,
                              child: Icon(
                                Icons.forum_rounded,
                                color: context.nexusTheme.textSecondary,
                                size: r.s(22),
                              ),
                            ),
                          )
                        : Container(
                            color: context.nexusTheme.surfacePrimary,
                            child: Icon(
                              Icons.forum_rounded,
                              color: context.nexusTheme.textSecondary,
                              size: r.s(22),
                            ),
                          ),
                  ),
            SizedBox(width: r.s(12)),

            // ── Info ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isPinned) ...[
                        Icon(
                          Icons.push_pin_rounded,
                          size: r.s(12),
                          color: context.nexusTheme.accentSecondary,
                        ),
                        SizedBox(width: r.s(4)),
                      ],
                      Expanded(
                        child: Text(
                          chatRoom.title,
                          style: TextStyle(
                            color: context.nexusTheme.textPrimary,
                            fontSize: r.fs(14),
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: r.s(3)),
                  Text(
                    chatRoom.lastMessagePreview ?? s.noMessages,
                    style: TextStyle(
                      color: hasUnread
                          ? context.nexusTheme.textSecondary
                          : context.nexusTheme.textHint,
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
                      ? timeago.format(
                          chatRoom.lastMessageAt!.toLocal(),
                          locale: 'pt_BR',
                        )
                      : '',
                  style: TextStyle(
                    color: hasUnread
                        ? context.nexusTheme.accentSecondary
                        : context.nexusTheme.textHint,
                    fontSize: r.fs(10),
                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (hasUnread) ...[
                  SizedBox(height: r.s(4)),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: r.s(6), vertical: 2),
                    decoration: BoxDecoration(
                      color: context.nexusTheme.accentSecondary,
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
    ); // GestureDetector
  }
}

// =============================================================================
// VIEWER DE STORIES DOS SEGUIDOS — Wrapper para StoryViewerScreen
// =============================================================================
class _FollowingStoryViewer extends StatelessWidget {
  final List<Map<String, dynamic>> stories;
  final Map<String, dynamic> authorProfile;

  const _FollowingStoryViewer({
    required this.stories,
    required this.authorProfile,
  });

  @override
  Widget build(BuildContext context) {
    return StoryViewerScreen(
      stories: stories,
      authorProfile: authorProfile,
    );
  }
}
