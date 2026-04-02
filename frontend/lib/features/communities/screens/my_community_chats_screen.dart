import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../config/app_theme.dart';
import '../../../core/models/chat_room_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/amino_bottom_nav.dart';
import '../../chat/screens/chat_list_screen.dart' show chatListProvider;
import '../widgets/community_create_menu.dart';

// =============================================================================
// Provider: chats do usuário filtrados por comunidade
// =============================================================================
final communityMyChatsProvider =
    FutureProvider.family<List<ChatRoomModel>, String>((ref, communityId) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];
  final response = await SupabaseService.table('chat_members')
      .select(
          'thread_id, status, is_pinned_by_user, pinned_at, unread_count, chat_threads(*)')
      .eq('user_id', userId)
      .neq('status', 'left');
  final all = (response as List? ?? [])
      .where((e) => e['chat_threads'] != null)
      .map((e) {
        final threadMap = Map<String, dynamic>.from(
            e['chat_threads'] as Map<String, dynamic>);
        threadMap['is_pinned_by_user'] =
            e['is_pinned_by_user'] as bool? ?? false;
        threadMap['pinned_at'] = e['pinned_at'];
        threadMap['membership_status'] = e['status'] as String? ?? 'active';
        threadMap['unread_count'] = e['unread_count'] as int? ?? 0;
        return ChatRoomModel.fromJson(threadMap);
      })
      .where((c) => c.communityId == communityId)
      .toList();
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
      .select('user_id, profiles(id, nickname, icon_url)')
      .eq('community_id', communityId)
      .order('joined_at', ascending: false)
      .limit(20);
  return List<Map<String, dynamic>>.from(response as List? ?? []);
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
      .select('following_id, profiles!follows_following_id_fkey(id, nickname, icon_url)')
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
    final chatsAsync =
        ref.watch(communityMyChatsProvider(widget.communityId));
    final membersAsync =
        ref.watch(communityMemberAvatarsProvider(widget.communityId));
    final favoritesAsync =
        ref.watch(favoriteMembersProvider(widget.communityId));

    return Scaffold(
      backgroundColor: context.scaffoldBg,
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
                color: AppTheme.primaryColor,
                onRefresh: () async {
                  ref.invalidate(
                      communityMyChatsProvider(widget.communityId));
                  ref.invalidate(
                      communityMemberAvatarsProvider(widget.communityId));
                  ref.invalidate(
                      favoriteMembersProvider(widget.communityId));
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
                      data: (members) =>
                          _buildAllMembersRow(r, members),
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
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      error: (e, _) => Padding(
                        padding: EdgeInsets.all(r.s(24)),
                        child: Center(
                          child: Text(
                            'Erro ao carregar chats.',
                            style: TextStyle(
                                color: context.textSecondary,
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
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(12)),
      child: Row(
        children: [
          // Botão voltar
          GestureDetector(
            onTap: () => context.pop(),
            behavior: HitTestBehavior.opaque,
            child: Icon(Icons.arrow_back_rounded,
                color: context.textPrimary, size: r.s(24)),
          ),
          SizedBox(width: r.s(12)),
          // Título
          Expanded(
            child: Text(
              'Meus Chats',
              style: TextStyle(
                color: context.textPrimary,
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
              padding: EdgeInsets.symmetric(
                  horizontal: r.s(14), vertical: r.s(7)),
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
                    'Criar',
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
    return Container(
      margin: EdgeInsets.symmetric(
          horizontal: r.s(16), vertical: r.s(6)),
      padding:
          EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(r.s(24)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded,
              color: context.textHint, size: r.s(18)),
          SizedBox(width: r.s(8)),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(
                  color: context.textPrimary, fontSize: r.fs(13)),
              decoration: InputDecoration(
                hintText: 'Procurar Meus Chats',
                hintStyle: TextStyle(
                    color: context.textHint, fontSize: r.fs(13)),
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
                  color: context.textHint, size: r.s(16)),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TODOS OS MEMBROS
  // ---------------------------------------------------------------------------
  Widget _buildAllMembersRow(
      Responsive r, List<Map<String, dynamic>> members) {
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
        margin: EdgeInsets.symmetric(
            horizontal: r.s(16), vertical: r.s(8)),
        padding: EdgeInsets.symmetric(
            horizontal: r.s(14), vertical: r.s(10)),
        decoration: BoxDecoration(
          color: context.cardBg,
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
                  color: context.textPrimary,
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
                          border: Border.all(
                              color: context.cardBg, width: 2),
                          color: AppTheme.primaryColor
                              .withValues(alpha: 0.4),
                          image: url != null
                              ? DecorationImage(
                                  image:
                                      CachedNetworkImageProvider(url),
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
                        border:
                            Border.all(color: context.cardBg, width: 2),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(r.s(16), r.s(8), r.s(16), r.s(8)),
          child: Row(
            children: [
              Icon(Icons.star_rounded,
                  color: AppTheme.warningColor, size: r.s(18)),
              SizedBox(width: r.s(6)),
              Expanded(
                child: Text(
                  'Meus Membros Favoritos',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: r.fs(14),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.more_horiz_rounded,
                  color: context.textHint, size: r.s(20)),
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
              final profile =
                  item['profiles'] as Map<String, dynamic>? ?? {};
              final nickname =
                  profile['nickname'] as String? ?? 'Membro';
              final iconUrl = profile['icon_url'] as String?;
              final userId = item['following_id'] as String?;
              return GestureDetector(
                onTap: () {
                  if (userId != null) {
                    context.push('/profile/$userId');
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
                          color: AppTheme.primaryColor
                              .withValues(alpha: 0.3),
                          image: iconUrl != null
                              ? DecorationImage(
                                  image:
                                      CachedNetworkImageProvider(iconUrl),
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
                          color: context.textSecondary,
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
  Widget _buildChatsList(
      Responsive r, List<ChatRoomModel> chats) {
    if (chats.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(r.s(32)),
        child: Column(
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                color: context.textHint, size: r.s(48)),
            SizedBox(height: r.s(12)),
            Text(
              _searchQuery.isEmpty
                  ? 'Você ainda não entrou em nenhum chat nesta comunidade.'
                  : 'Nenhum chat encontrado para "$_searchQuery".',
              style: TextStyle(
                  color: context.textSecondary, fontSize: r.fs(13)),
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
                    color: context.textPrimary,
                    fontSize: r.fs(14),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.more_horiz_rounded,
                  color: context.textHint, size: r.s(20)),
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

  String _typeLabel(String type) {
    switch (type) {
      case 'public':
        return 'Chat Público';
      case 'group':
        return 'Chat em Grupo';
      case 'dm':
        return 'Mensagem Direta';
      default:
        return 'Chat';
    }
  }

  Future<void> _showContextMenu(
      BuildContext context, WidgetRef ref) async {
    final r = context.r;
    final isPinned = chatRoom.isPinnedByUser;
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(r.s(20))),
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
              padding: EdgeInsets.symmetric(
                  horizontal: r.s(16), vertical: r.s(8)),
              child: Text(
                chatRoom.title,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: r.fs(15),
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Divider(
                color: context.dividerClr.withValues(alpha: 0.3),
                height: 1),
            // Fixar / Desafixar
            ListTile(
              leading: Icon(
                isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin_rounded,
                color: isPinned
                    ? AppTheme.accentColor
                    : context.textSecondary,
                size: r.s(22),
              ),
              title: Text(
                isPinned ? 'Desafixar do topo' : 'Fixar no topo',
                style: TextStyle(
                    color: context.textPrimary, fontSize: r.fs(14)),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                try {
                  if (isPinned) {
                    await SupabaseService.rpc('unpin_chat_for_user',
                        params: {
                          'p_thread_id': chatRoom.id,
                          'p_user_id': userId,
                        });
                  } else {
                    await SupabaseService.rpc('pin_chat_for_user',
                        params: {
                          'p_thread_id': chatRoom.id,
                          'p_user_id': userId,
                        });
                  }
                  ref.invalidate(
                      communityMyChatsProvider(communityId));
                  ref.invalidate(chatListProvider);
                } catch (e) {
                  debugPrint('[MyCommunityChats] Pin error: $e');
                }
              },
            ),
            // Sair / Apagar
            ListTile(
              leading: Icon(Icons.exit_to_app_rounded,
                  color: AppTheme.errorColor, size: r.s(22)),
              title: Text(
                chatRoom.type == 'dm'
                    ? 'Apagar conversa'
                    : 'Sair do chat',
                style: TextStyle(
                    color: AppTheme.errorColor, fontSize: r.fs(14)),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                if (!context.mounted) return;
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    backgroundColor: context.cardBg,
                    title: Text(
                      chatRoom.type == 'dm'
                          ? 'Apagar conversa?'
                          : 'Sair do chat?',
                      style: TextStyle(
                          color: context.textPrimary,
                          fontSize: r.fs(16),
                          fontWeight: FontWeight.w700),
                    ),
                    content: Text(
                      chatRoom.type == 'dm'
                          ? 'A conversa será removida da sua lista.'
                          : 'Você poderá entrar novamente depois.',
                      style: TextStyle(
                          color: context.textSecondary,
                          fontSize: r.fs(13)),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.of(dCtx).pop(false),
                        child: Text('Cancelar',
                            style: TextStyle(
                                color: context.textSecondary,
                                fontSize: r.fs(13))),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.of(dCtx).pop(true),
                        child: Text(
                          chatRoom.type == 'dm' ? 'Apagar' : 'Sair',
                          style: TextStyle(
                              color: AppTheme.errorColor,
                              fontWeight: FontWeight.w700,
                              fontSize: r.fs(13)),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm != true) return;
                try {
                  await SupabaseService.rpc('leave_public_chat',
                      params: {
                        'p_thread_id': chatRoom.id,
                        'p_user_id': userId,
                      });
                  ref.invalidate(
                      communityMyChatsProvider(communityId));
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
    final r = context.r;
    final hasUnread = chatRoom.unreadCount > 0;
    final isPinned = chatRoom.isPinnedByUser;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => context.push('/chat/${chatRoom.id}'),
      onLongPress: () => _showContextMenu(context, ref),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: r.s(16), vertical: r.s(10)),
        decoration: isPinned
            ? BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: AppTheme.accentColor.withValues(alpha: 0.6),
                    width: 3,
                  ),
                ),
              )
            : null,
        child: Row(
          children: [
            // ── Cover quadrado (72x72) com badge de não lido ──
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(r.s(6)),
                  child: Container(
                    width: r.s(72),
                    height: r.s(72),
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    child: chatRoom.iconUrl != null
                        ? CachedNetworkImage(
                            imageUrl: chatRoom.iconUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: AppTheme.primaryColor
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
                // Badge de não lido (ponto vermelho)
                if (hasUnread)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: r.s(10),
                      height: r.s(10),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: context.scaffoldBg, width: 1.5),
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
                    _typeLabel(chatRoom.type),
                    style: TextStyle(
                      color: context.textHint,
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
                            size: r.s(11),
                            color: AppTheme.accentColor),
                        SizedBox(width: r.s(3)),
                      ],
                      Expanded(
                        child: Text(
                          chatRoom.title,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: r.fs(14),
                            fontWeight: hasUnread
                                ? FontWeight.w700
                                : FontWeight.w600,
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
                    chatRoom.lastMessagePreview ?? 'Sem mensagens',
                    style: TextStyle(
                      color: hasUnread
                          ? context.textSecondary
                          : context.textHint,
                      fontSize: r.fs(12),
                      fontWeight: hasUnread
                          ? FontWeight.w500
                          : FontWeight.w400,
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
                      ? timeago.format(chatRoom.lastMessageAt!,
                          locale: 'pt_BR')
                      : '',
                  style: TextStyle(
                    color: hasUnread
                        ? AppTheme.accentColor
                        : context.textHint,
                    fontSize: r.fs(10),
                    fontWeight: hasUnread
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                if (hasUnread && chatRoom.unreadCount > 1) ...[
                  SizedBox(height: r.s(4)),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(6), vertical: 2),
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
