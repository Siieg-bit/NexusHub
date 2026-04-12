import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/models/chat_room_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/amino_bottom_nav.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../chat/screens/chat_list_screen.dart' show chatListProvider, chatCommunitiesProvider;
import '../../../core/providers/chat_provider.dart' show unreadCountProvider, unreadCountByCommunityProvider;
import '../widgets/community_create_menu.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

Map<String, dynamic>? _extractProfile(dynamic rawProfile) {
  if (rawProfile is Map<String, dynamic>) return rawProfile;
  if (rawProfile is Map) return Map<String, dynamic>.from(rawProfile);
  if (rawProfile is List && rawProfile.isNotEmpty) {
    final first = rawProfile.first;
    if (first is Map<String, dynamic>) return first;
    if (first is Map) return Map<String, dynamic>.from(first);
  }
  return null;
}

String? _normalizedString(dynamic value) {
  final text = value as String?;
  if (text == null) return null;
  final trimmed = text.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool _isDirectLikeCommunityThread(
  Map<String, dynamic>? thread,
  String communityId,
) {
  if (thread == null) return false;

  final type = (thread['type'] as String? ?? '').trim().toLowerCase();
  if (type == 'dm' || type == 'direct' || type == 'private') return true;
  if (type == 'public' || type == 'group') return false;

  final threadCommunityId = thread['community_id'] as String?;
  final membersCount = thread['members_count'] as int? ?? 0;
  final title = ((thread['title'] as String?) ?? '').trim().toLowerCase();
  final hasGenericTitle = title.isEmpty || title == 'chat';

  final belongsToCurrentCommunity = threadCommunityId == communityId;
  final hasDmShape = membersCount > 0 && membersCount <= 2;

  if (belongsToCurrentCommunity && (hasDmShape || hasGenericTitle)) {
    return true;
  }

  return threadCommunityId == null && (hasDmShape || hasGenericTitle);
}

bool _isDirectLikeChatRoom(ChatRoomModel chatRoom, String communityId) {
  return _isDirectLikeCommunityThread(
    {
      'type': chatRoom.type,
      'community_id': chatRoom.communityId,
      'members_count': chatRoom.membersCount,
      'title': chatRoom.title,
    },
    communityId,
  );
}

String _dmFallbackInitial(String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed[0].toUpperCase();
}

String _typeLabelForChat(ChatRoomModel chatRoom, String communityId) {
  final s = getStrings();
  if (_isDirectLikeChatRoom(chatRoom, communityId)) {
    return 'Mensagem Direta';
  }
  switch (chatRoom.type) {
    case 'public':
      return s.publicChatLabel;
    case 'group':
      return s.groupChatLabel;
    default:
      return s.chat;
  }
}

bool _usesDmDeleteFlow(ChatRoomModel chatRoom, String communityId) {
  return _isDirectLikeChatRoom(chatRoom, communityId);
}

// =============================================================================
// Provider: chats do usuário filtrados por comunidade
// =============================================================================
final communityMyChatsProvider =
    FutureProvider.family<List<ChatRoomModel>, String>(
        (ref, communityId) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];

  final response = await SupabaseService.table('chat_members')
      .select(
          'thread_id, status, is_pinned_by_user, pinned_at, unread_count, chat_threads(*)')
      .eq('user_id', userId)
      .neq('status', 'left');

  final rawChats = (response as List? ?? [])
      .where((e) => e['chat_threads'] != null)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .where((e) {
        final thread = e['chat_threads'] as Map<String, dynamic>?;
        if (thread == null) return false;
        final threadCommunityId = thread['community_id'] as String?;
        return threadCommunityId == communityId ||
            _isDirectLikeCommunityThread(thread, communityId);
      })
      .toList();

  final dmThreadsById = <String, Map<String, dynamic>>{};
  for (final row in rawChats) {
    final thread = row['chat_threads'] as Map<String, dynamic>?;
    final threadId = row['thread_id'] as String?;
    if (threadId == null ||
        !_isDirectLikeCommunityThread(thread, communityId)) {
      continue;
    }
    dmThreadsById[threadId] = Map<String, dynamic>.from(thread!);
  }

  final dmThreadIds = dmThreadsById.keys.toList();
  final Map<String, Map<String, dynamic>> dmCounterparts = {};
  if (dmThreadIds.isNotEmpty) {
    try {
      final dmMembers = await SupabaseService.table('chat_members').select(
          'thread_id, user_id, profiles!chat_members_user_id_fkey(id, nickname, icon_url, banner_url)')
        .inFilter('thread_id', dmThreadIds)
        .neq('user_id', userId);

      final counterpartRows = (dmMembers as List? ?? [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

      final counterpartUserIds = counterpartRows
          .map((row) => row['user_id'] as String?)
          .whereType<String>()
          .toSet();

      final Map<String, Map<String, dynamic>> localMemberships = {};
      if (counterpartUserIds.isNotEmpty) {
        final membershipRes = await SupabaseService.table('community_members')
            .select(
                'community_id, user_id, local_nickname, local_icon_url, local_banner_url')
            .eq('community_id', communityId)
            .inFilter('user_id', counterpartUserIds.toList());

        for (final row in (membershipRes as List? ?? [])) {
          final membership = Map<String, dynamic>.from(row as Map);
          final memberUserId = _normalizedString(membership['user_id']);
          if (memberUserId == null) continue;
          localMemberships[memberUserId] = membership;
        }
      }

      for (final row in counterpartRows) {
        final threadId = row['thread_id'] as String?;
        final counterpartUserId = _normalizedString(row['user_id']);
        final profile = _extractProfile(row['profiles']);
        if (threadId == null || counterpartUserId == null || profile == null) {
          continue;
        }

        final mergedProfile = Map<String, dynamic>.from(profile)
          ..['user_id'] = counterpartUserId;
        final membership = localMemberships[counterpartUserId];
        final localNickname = _normalizedString(membership?['local_nickname']);
        final localIconUrl = _normalizedString(membership?['local_icon_url']);
        final localBannerUrl = _normalizedString(membership?['local_banner_url']);

        if (localNickname != null) mergedProfile['nickname'] = localNickname;
        if (localIconUrl != null) mergedProfile['icon_url'] = localIconUrl;
        if (localBannerUrl != null) mergedProfile['banner_url'] = localBannerUrl;

        dmCounterparts[threadId] = mergedProfile;
      }
    } catch (e) {
      debugPrint('[CommunityMyChats] Erro ao enriquecer DMs: $e');
    }
  }

  final all = rawChats.map((e) {
    final threadMap =
        Map<String, dynamic>.from(e['chat_threads'] as Map<String, dynamic>);
    threadMap['is_pinned_by_user'] = e['is_pinned_by_user'] as bool? ?? false;
    threadMap['pinned_at'] = e['pinned_at'];
    threadMap['membership_status'] = e['status'] as String? ?? 'active';
    threadMap['unread_count'] = e['unread_count'] as int? ?? 0;

    if (_isDirectLikeCommunityThread(threadMap, communityId)) {
      final dmThreadId =
          e['thread_id'] as String? ?? threadMap['id'] as String? ?? '';
      final counterpart = dmCounterparts[dmThreadId];
      if (counterpart != null) {
        threadMap['title'] = counterpart['nickname'] ?? threadMap['title'];
        threadMap['icon_url'] = counterpart['icon_url'];
        threadMap['host_id'] =
            counterpart['id'] ?? counterpart['user_id'] ?? threadMap['host_id'];
      }
    }

    return ChatRoomModel.fromJson(threadMap);
  }).toList();

  all.sort((a, b) {
    if (a.isPinnedByUser && !b.isPinnedByUser) return -1;
    if (!a.isPinnedByUser && b.isPinnedByUser) return 1;
    return (b.lastMessageAt ?? b.createdAt)
        .compareTo(a.lastMessageAt ?? a.createdAt);
  });
  return all;
});

// =============================================================================
// Provider: membros da comunidade (para "Todos os Membros" e "Favoritos")
// =============================================================================
final communityMemberAvatarsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, communityId) async {
  final response = await SupabaseService.table('community_members')
      .select('user_id, local_nickname, local_icon_url, profiles(id, nickname, icon_url)')
      .eq('community_id', communityId)
      .order('joined_at', ascending: false)
      .limit(20);

  final rows = List<Map<String, dynamic>>.from(response as List? ?? []);
  for (final row in rows) {
    final profile = _extractProfile(row['profiles']);
    if (profile == null) continue;
    final mergedProfile = Map<String, dynamic>.from(profile);
    final localNickname = _normalizedString(row['local_nickname']);
    final localIconUrl = _normalizedString(row['local_icon_url']);
    if (localNickname != null) mergedProfile['nickname'] = localNickname;
    if (localIconUrl != null) mergedProfile['icon_url'] = localIconUrl;
    row['profiles'] = mergedProfile;
  }
  return rows;
});

// =============================================================================
// Provider: membros favoritos (follows do usuário que também são membros)
// =============================================================================
final favoriteMembersProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, communityId) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];
  // Buscar quem o usuário segue
  final follows = await SupabaseService.table('follows')
      .select(
          'following_id, profiles!follows_following_id_fkey(id, nickname, icon_url)')
      .eq('follower_id', userId)
      .limit(30);
  return List<Map<String, dynamic>>.from(follows as List? ?? []);
});

// =============================================================================
// TELA: Meus Chats (dentro da comunidade)
// Layout 1:1 do print Amino:
//   AppBar: "← Meus Chats" + botão verde "Criar"
//   Barra de busca
//   Linha "Todos os Membros (X)" com avatares sobrepostos
//   Seção "Meus Membros Favoritos" (scroll horizontal)
//   Seção "Meus Chats" (lista vertical com cover, nome, preview, timestamp, badge)
//   FAB "+" no canto inferior direito
// =============================================================================
class MyCommunityChatsScreen extends ConsumerStatefulWidget {
  final String communityId;
  final String communityName;

  const MyCommunityChatsScreen({
    super.key,
    required this.communityId,
    required this.communityName,
  });

  @override
  ConsumerState<MyCommunityChatsScreen> createState() =>
      _MyCommunityChatsScreenState();
}

class _MyCommunityChatsScreenState
    extends ConsumerState<MyCommunityChatsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final chatsAsync = ref.watch(communityMyChatsProvider(widget.communityId));
    final membersAsync =
        ref.watch(communityMemberAvatarsProvider(widget.communityId));
    final favoritesAsync =
        ref.watch(favoriteMembersProvider(widget.communityId));

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar ──
            _buildAppBar(r),
            // ── Barra de busca ──
            _buildSearchBar(r),
            // ── Conteúdo scrollável ──
            Expanded(
              child: RefreshIndicator(
                color: context.nexusTheme.accentPrimary,
                onRefresh: () async {
                  ref.invalidate(communityMyChatsProvider(widget.communityId));
                  ref.invalidate(
                      communityMemberAvatarsProvider(widget.communityId));
                  ref.invalidate(favoriteMembersProvider(widget.communityId));
                  await Future.delayed(const Duration(milliseconds: 300));
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 80,
                  ),
                  children: [
                    // ── Todos os Membros ──
                    membersAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (members) => _buildAllMembersRow(r, members),
                    ),
                    SizedBox(height: r.s(4)),
                    // ── Meus Membros Favoritos ──
                    favoritesAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (favorites) => favorites.isEmpty
                          ? const SizedBox.shrink()
                          : _buildFavoritesSection(r, favorites),
                    ),
                    // ── Meus Chats ──
                    chatsAsync.when(
                      loading: () => Padding(
                        padding: EdgeInsets.only(top: r.s(40)),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: context.nexusTheme.accentPrimary,
                          ),
                        ),
                      ),
                      error: (e, _) => Padding(
                        padding: EdgeInsets.all(r.s(24)),
                        child: Center(
                          child: Text(
                            'Erro ao carregar chats.',
                            style: TextStyle(
                                color: context.nexusTheme.textSecondary,
                                fontSize: r.fs(13)),
                          ),
                        ),
                      ),
                      data: (chats) {
                        final filtered = _searchQuery.isEmpty
                            ? chats
                            : chats
                                .where((c) => c.title
                                    .toLowerCase()
                                    .contains(_searchQuery.toLowerCase()))
                                .toList();
                        return _buildChatsList(r, filtered);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // FAB "+" estilo cápsula (página interna)
      floatingActionButton: AminoCommunityFab(
        onTap: () => showCommunityCreateMenu(
          context,
          communityId: widget.communityId,
          communityName: widget.communityName,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // APP BAR
  // ---------------------------------------------------------------------------
  Widget _buildAppBar(Responsive r) {
    final s = getStrings();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(12)),
      child: Row(
        children: [
          // Botão voltar
          GestureDetector(
            onTap: () => context.pop(),
            behavior: HitTestBehavior.opaque,
            child: Icon(Icons.arrow_back_rounded,
                color: context.nexusTheme.textPrimary, size: r.s(24)),
          ),
          SizedBox(width: r.s(12)),
          // Título
          Expanded(
            child: Text(
              'Meus Chats',
              style: TextStyle(
                color: context.nexusTheme.textPrimary,
                fontSize: r.fs(18),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Botão Criar (verde)
          GestureDetector(
            onTap: () {
              context.push('/create-public-chat', extra: {
                'communityId': widget.communityId,
                'communityName': widget.communityName,
              });
            },
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(7)),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(r.s(20)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline_rounded,
                      color: Colors.white, size: r.s(16)),
                  SizedBox(width: r.s(4)),
                  Text(
                    s.create,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.fs(13),
                      fontWeight: FontWeight.w700,
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
  // BARRA DE BUSCA
  // ---------------------------------------------------------------------------
  Widget _buildSearchBar(Responsive r) {
    final s = getStrings();
    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(6)),
      padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
      decoration: BoxDecoration(
        color: context.nexusTheme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(24)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: context.nexusTheme.textHint, size: r.s(18)),
          SizedBox(width: r.s(8)),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(color: context.nexusTheme.textPrimary, fontSize: r.fs(13)),
              decoration: InputDecoration(
                hintText: s.searchMyChats,
                hintStyle:
                    TextStyle(color: context.nexusTheme.textHint, fontSize: r.fs(13)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: Icon(Icons.close_rounded,
                  color: context.nexusTheme.textHint, size: r.s(16)),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TODOS OS MEMBROS
  // ---------------------------------------------------------------------------
  Widget _buildAllMembersRow(Responsive r, List<Map<String, dynamic>> members) {
    final avatarUrls = members
        .map((m) {
          final p = m['profiles'] as Map<String, dynamic>?;
          return p?['icon_url'] as String?;
        })
        .where((u) => u != null)
        .take(4)
        .toList();

    return GestureDetector(
      onTap: () {
        context.push('/community/${widget.communityId}/members');
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
        padding: EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(10)),
        decoration: BoxDecoration(
          color: context.nexusTheme.surfacePrimary,
          borderRadius: BorderRadius.circular(r.s(12)),
        ),
        child: Row(
          children: [
            // Ícone azul de pessoa
            Container(
              width: r.s(32),
              height: r.s(32),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_rounded,
                  color: Colors.white, size: r.s(18)),
            ),
            SizedBox(width: r.s(12)),
            // Texto
            Expanded(
              child: Text(
                'Todos os Membros (${members.length})',
                style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontSize: r.fs(14),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Avatares sobrepostos
            SizedBox(
              width: r.s(avatarUrls.length * 20.0 + 28),
              height: r.s(32),
              child: Stack(
                children: [
                  ...avatarUrls.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final url = entry.value;
                    return Positioned(
                      left: idx * r.s(20),
                      child: Container(
                        width: r.s(30),
                        height: r.s(30),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: context.nexusTheme.surfacePrimary, width: 2),
                          color: context.nexusTheme.accentPrimary.withValues(alpha: 0.4),
                          image: url != null
                              ? DecorationImage(
                                  image: CachedNetworkImageProvider(url),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: url == null
                            ? Icon(Icons.person_rounded,
                                color: Colors.white, size: r.s(14))
                            : null,
                      ),
                    );
                  }),
                  // Botão "..."
                  Positioned(
                    left: avatarUrls.length * r.s(20),
                    child: Container(
                      width: r.s(30),
                      height: r.s(30),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[700],
                        border: Border.all(color: context.nexusTheme.surfacePrimary, width: 2),
                      ),
                      child: Icon(Icons.more_horiz_rounded,
                          color: Colors.white, size: r.s(14)),
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
  // MEUS MEMBROS FAVORITOS (horizontal scroll)
  // ---------------------------------------------------------------------------
  Widget _buildFavoritesSection(
      Responsive r, List<Map<String, dynamic>> favorites) {
    final s = getStrings();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(r.s(16), r.s(8), r.s(16), r.s(8)),
          child: Row(
            children: [
              Icon(Icons.star_rounded,
                  color: context.nexusTheme.warning, size: r.s(18)),
              SizedBox(width: r.s(6)),
              Expanded(
                child: Text(
                  'Meus Membros Favoritos',
                  style: TextStyle(
                    color: context.nexusTheme.textPrimary,
                    fontSize: r.fs(14),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.more_horiz_rounded,
                  color: context.nexusTheme.textHint, size: r.s(20)),
            ],
          ),
        ),
        SizedBox(
          height: r.s(90),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: r.s(12)),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final item = favorites[index];
              final profile = item['profiles'] as Map<String, dynamic>? ?? {};
              final nickname = profile['nickname'] as String? ?? s.member;
              final iconUrl = profile['icon_url'] as String?;
              final userId = item['following_id'] as String?;
              return GestureDetector(
                onTap: () {
                  if (userId != null) {
                    context.push('/user/$userId');
                  }
                },
                child: Container(
                  width: r.s(64),
                  margin: EdgeInsets.symmetric(horizontal: r.s(4)),
                  child: Column(
                    children: [
                      Container(
                        width: r.s(52),
                        height: r.s(52),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.nexusTheme.accentPrimary.withValues(alpha: 0.3),
                          image: iconUrl != null
                              ? DecorationImage(
                                  image: CachedNetworkImageProvider(iconUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: iconUrl == null
                            ? Icon(Icons.person_rounded,
                                color: Colors.white, size: r.s(26))
                            : null,
                      ),
                      SizedBox(height: r.s(4)),
                      Text(
                        nickname,
                        style: TextStyle(
                          color: context.nexusTheme.textSecondary,
                          fontSize: r.fs(10),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
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
  // LISTA DE CHATS
  // ---------------------------------------------------------------------------
  Widget _buildChatsList(Responsive r, List<ChatRoomModel> chats) {
    final s = getStrings();
    if (chats.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(r.s(32)),
        child: Column(
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                color: context.nexusTheme.textHint, size: r.s(48)),
            SizedBox(height: r.s(12)),
            Text(
              _searchQuery.isEmpty
                  ? s.noChatsJoinedYet
                  : 'Nenhum chat encontrado para "$_searchQuery".',
              style:
                  TextStyle(color: context.nexusTheme.textSecondary, fontSize: r.fs(13)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(r.s(16), r.s(12), r.s(16), r.s(4)),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Meus Chats',
                  style: TextStyle(
                    color: context.nexusTheme.textPrimary,
                    fontSize: r.fs(14),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.more_horiz_rounded,
                  color: context.nexusTheme.textHint, size: r.s(20)),
            ],
          ),
        ),
        ...chats.map((chat) => _CommunityChatTile(
              chatRoom: chat,
              communityId: widget.communityId,
            )),
      ],
    );
  }
}

// =============================================================================
// CHAT TILE — Estilo Amino com cover quadrado, nome, preview, timestamp, badge
// =============================================================================
class _CommunityChatTile extends ConsumerWidget {
  final ChatRoomModel chatRoom;
  final String communityId;

  const _CommunityChatTile({
    required this.chatRoom,
    required this.communityId,
  });

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
            Container(
              margin: EdgeInsets.only(top: r.s(10), bottom: r.s(4)),
              width: r.s(36),
              height: r.s(4),
              decoration: BoxDecoration(
                color: context.dividerClr,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
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
            // Fixar / Desafixar
            ListTile(
              leading: Icon(
                isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                color: isPinned ? context.nexusTheme.accentSecondary : context.nexusTheme.textSecondary,
                size: r.s(22),
              ),
              title: Text(
                isPinned ? s.unpinFromTop : s.pinToTop,
                style:
                    TextStyle(color: context.nexusTheme.textPrimary, fontSize: r.fs(14)),
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
                  ref.invalidate(communityMyChatsProvider(communityId));
                  ref.invalidate(chatListProvider);
                } catch (e) {
                  debugPrint('[MyCommunityChats] Pin error: $e');
                }
              },
            ),
            // Sair / Apagar
            ListTile(
              leading: Icon(Icons.exit_to_app_rounded,
                  color: context.nexusTheme.error, size: r.s(22)),
              title: Text(
                _usesDmDeleteFlow(chatRoom, communityId)
                    ? s.deleteConversation
                    : s.leaveChat,
                style:
                    TextStyle(color: context.nexusTheme.error, fontSize: r.fs(14)),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                if (!context.mounted) return;
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    backgroundColor: context.nexusTheme.surfacePrimary,
                    title: Text(
                      _usesDmDeleteFlow(chatRoom, communityId)
                          ? 'Apagar conversa?'
                          : 'Sair do chat?',
                      style: TextStyle(
                          color: context.nexusTheme.textPrimary,
                          fontSize: r.fs(16),
                          fontWeight: FontWeight.w700),
                    ),
                    content: Text(
                      _usesDmDeleteFlow(chatRoom, communityId)
                          ? s.conversationRemovedFromList
                          : 'Você poderá entrar novamente depois.',
                      style: TextStyle(
                          color: context.nexusTheme.textSecondary, fontSize: r.fs(13)),
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
                          _usesDmDeleteFlow(chatRoom, communityId)
                              ? s.deleteAction
                              : s.logout,
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
                try {
                  await SupabaseService.rpc('leave_public_chat', params: {
                    'p_thread_id': chatRoom.id,
                  });
                  ref.invalidate(communityMyChatsProvider(communityId));
                  ref.invalidate(chatListProvider);
                } catch (e) {
                  debugPrint('[MyCommunityChats] Leave error: $e');
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
    final isDirectLikeChat = _isDirectLikeChatRoom(chatRoom, communityId);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => context.push('/chat/${chatRoom.id}').then((_) {
        // Ao voltar do chat, invalidar todos os providers de unread para refletir
        // o unread_count zerado pelo mark_chat_read chamado no chat_room_screen
        ref.invalidate(communityMyChatsProvider(communityId));
        ref.invalidate(chatListProvider);
        ref.invalidate(chatCommunitiesProvider);
        ref.invalidate(unreadCountProvider);
        ref.invalidate(unreadCountByCommunityProvider);
      }),
      onLongPress: () => _showContextMenu(context, ref),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(10)),
        decoration: isPinned
            ? BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: context.nexusTheme.accentSecondary.withValues(alpha: 0.6),
                    width: 3,
                  ),
                ),
              )
            : null,
        child: Row(
          children: [
            // ── Avatar circular para DM / cover quadrado para grupo ──
            Stack(
              clipBehavior: Clip.none,
              children: [
                if (isDirectLikeChat)
                  SizedBox(
                    width: r.s(72),
                    height: r.s(72),
                    child: Center(
                      child: chatRoom.iconUrl != null &&
                              chatRoom.iconUrl!.trim().isNotEmpty
                          ? CosmeticAvatar(
                              userId: chatRoom.hostId,
                              avatarUrl: chatRoom.iconUrl,
                              size: r.s(56),
                            )
                          : Container(
                              width: r.s(56),
                              height: r.s(56),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: context.nexusTheme.accentPrimary
                                    .withValues(alpha: 0.35),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _dmFallbackInitial(chatRoom.title),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: r.fs(22),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(r.s(6)),
                    child: Container(
                      width: r.s(72),
                      height: r.s(72),
                      color: context.nexusTheme.accentPrimary.withValues(alpha: 0.3),
                      child: (chatRoom.coverImageUrl ?? chatRoom.iconUrl) != null
                          ? CachedNetworkImage(
                              imageUrl: (chatRoom.coverImageUrl ?? chatRoom.iconUrl)!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: context.nexusTheme.accentPrimary
                                    .withValues(alpha: 0.3),
                              ),
                              errorWidget: (_, __, ___) => Icon(
                                Icons.chat_bubble_rounded,
                                color: Colors.white,
                                size: r.s(32),
                              ),
                            )
                          : Icon(Icons.chat_bubble_rounded,
                              color: Colors.white, size: r.s(32)),
                    ),
                  ),
                if (hasUnread)
                  Positioned(
                    top: 4,
                    right: isDirectLikeChat ? 6 : 4,
                    child: Container(
                      width: r.s(10),
                      height: r.s(10),
                      decoration: BoxDecoration(
                        color: context.nexusTheme.error,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: context.nexusTheme.backgroundPrimary, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: r.s(12)),
            // ── Info ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tipo de chat (ex: "Chat Público")
                  Text(
                    _typeLabelForChat(chatRoom, communityId),
                    style: TextStyle(
                      color: context.nexusTheme.textHint,
                      fontSize: r.fs(10),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: r.s(2)),
                  // Nome do chat
                  Row(
                    children: [
                      if (isPinned) ...[
                        Icon(Icons.push_pin_rounded,
                            size: r.s(11), color: context.nexusTheme.accentSecondary),
                        SizedBox(width: r.s(3)),
                      ],
                      Expanded(
                        child: Text(
                          chatRoom.title,
                          style: TextStyle(
                            color: context.nexusTheme.textPrimary,
                            fontSize: r.fs(14),
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: r.s(3)),
                  // Preview da última mensagem
                  Text(
                    chatRoom.lastMessagePreview ?? s.noMessages,
                    style: TextStyle(
                      color:
                          hasUnread ? context.nexusTheme.textSecondary : context.nexusTheme.textHint,
                      fontSize: r.fs(12),
                      fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // ── Timestamp + Badge de contagem ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  chatRoom.lastMessageAt != null
                      ? timeago.format(chatRoom.lastMessageAt!, locale: 'pt_BR')
                      : '',
                  style: TextStyle(
                    color: hasUnread ? context.nexusTheme.accentSecondary : context.nexusTheme.textHint,
                    fontSize: r.fs(10),
                    fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (hasUnread && chatRoom.unreadCount > 1) ...[
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
    );
  }
}
