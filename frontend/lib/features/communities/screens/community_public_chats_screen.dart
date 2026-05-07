import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/models/chat_room_model.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// =============================================================================
// Provider: todas as salas públicas de uma comunidade
// =============================================================================
final communityPublicChatsProvider =
    FutureProvider.family<List<ChatRoomModel>, String>(
        (ref, communityId) async {
  final response = await SupabaseService.table('chat_threads')
      .select()
      .eq('community_id', communityId)
      .eq('type', 'public')
      .eq('status', 'ok')
      .order('members_count', ascending: false)
      .order('last_message_at', ascending: false);

  return (response as List? ?? [])
      .map((e) => ChatRoomModel.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

// =============================================================================
// Tela principal
// =============================================================================
class CommunityPublicChatsScreen extends ConsumerStatefulWidget {
  final String communityId;
  final String communityName;

  const CommunityPublicChatsScreen({
    super.key,
    required this.communityId,
    required this.communityName,
  });

  @override
  ConsumerState<CommunityPublicChatsScreen> createState() =>
      _CommunityPublicChatsScreenState();
}

class _CommunityPublicChatsScreenState
    extends ConsumerState<CommunityPublicChatsScreen> {
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
    final theme = context.nexusTheme;
    final chatsAsync =
        ref.watch(communityPublicChatsProvider(widget.communityId));

    return Scaffold(
      backgroundColor: theme.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(r, theme),
            _buildSearchBar(r, theme),
            Expanded(
              child: chatsAsync.when(
                loading: () => Center(
                  child: CircularProgressIndicator(color: theme.accentPrimary),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: theme.error, size: r.s(40)),
                      SizedBox(height: r.s(12)),
                      Text(
                        getStrings().somethingWentWrong,
                        style: TextStyle(
                            color: theme.textSecondary, fontSize: r.fs(14)),
                      ),
                      SizedBox(height: r.s(12)),
                      TextButton(
                        onPressed: () => ref.invalidate(
                            communityPublicChatsProvider(widget.communityId)),
                        child: Text(getStrings().retry,
                            style: TextStyle(color: theme.accentPrimary)),
                      ),
                    ],
                  ),
                ),
                data: (chats) {
                  final filtered = _searchQuery.isEmpty
                      ? chats
                      : chats.where((c) {
                          final title = c.title.toLowerCase();
                          final desc =
                              (c.description ?? '').toLowerCase();
                          final q = _searchQuery.toLowerCase();
                          return title.contains(q) || desc.contains(q);
                        }).toList();

                  if (filtered.isEmpty) {
                    return _buildEmptyState(r, theme, chats.isEmpty);
                  }

                  return RefreshIndicator(
                    color: theme.accentPrimary,
                    onRefresh: () async => ref.invalidate(
                        communityPublicChatsProvider(widget.communityId)),
                    child: ListView.builder(
                      padding: EdgeInsets.only(
                          top: r.s(8), bottom: r.s(24)),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) =>
                          _PublicChatTile(
                        chatRoom: filtered[index],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // FAB para criar nova sala (canto inferior direito)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create-public-chat', extra: {
          'communityId': widget.communityId,
          'communityName': widget.communityName,
        }),
        backgroundColor: theme.success,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          getStrings().createPublicChat,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // APP BAR
  // ---------------------------------------------------------------------------
  Widget _buildAppBar(Responsive r, dynamic theme) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: r.s(16), vertical: r.s(12)),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            behavior: HitTestBehavior.opaque,
            child: Icon(Icons.arrow_back_rounded,
                color: theme.textPrimary, size: r.s(24)),
          ),
          SizedBox(width: r.s(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  getStrings().drawerPublicChatrooms,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: r.fs(18),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  widget.communityName,
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: r.fs(12),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Botão de refresh
          GestureDetector(
            onTap: () => ref.invalidate(
                communityPublicChatsProvider(widget.communityId)),
            child: Icon(Icons.refresh_rounded,
                color: theme.textSecondary, size: r.s(22)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BARRA DE BUSCA
  // ---------------------------------------------------------------------------
  Widget _buildSearchBar(Responsive r, dynamic theme) {
    return Container(
      margin:
          EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(6)),
      padding:
          EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(8)),
      decoration: BoxDecoration(
        color: theme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(24)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded,
              color: theme.textHint, size: r.s(18)),
          SizedBox(width: r.s(8)),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(
                  color: theme.textPrimary, fontSize: r.fs(13)),
              decoration: InputDecoration(
                hintText: getStrings().search,
                hintStyle: TextStyle(
                    color: theme.textHint, fontSize: r.fs(13)),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
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
                  color: theme.textHint, size: r.s(16)),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ESTADO VAZIO
  // ---------------------------------------------------------------------------
  Widget _buildEmptyState(
      Responsive r, dynamic theme, bool noChatsAtAll) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(r.s(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined,
                color: theme.textHint, size: r.s(56)),
            SizedBox(height: r.s(16)),
            Text(
              noChatsAtAll
                  ? 'Nenhuma sala pública ainda'
                  : 'Nenhuma sala encontrada',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: r.fs(16),
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: r.s(8)),
            Text(
              noChatsAtAll
                  ? 'Seja o primeiro a criar uma sala pública nesta comunidade!'
                  : 'Tente outro termo de busca.',
              style: TextStyle(
                  color: theme.textSecondary, fontSize: r.fs(13)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _PublicChatTile — card de uma sala pública
// =============================================================================
class _PublicChatTile extends ConsumerWidget {
  final ChatRoomModel chatRoom;
  const _PublicChatTile({
    required this.chatRoom,
  });

  void _openReadOnly(BuildContext context) {
    context.push('/chat/${chatRoom.id}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final theme = context.nexusTheme;

    final hasIcon = chatRoom.iconUrl != null && chatRoom.iconUrl!.isNotEmpty;
    final lastMsgTime = chatRoom.lastMessageAt;
    final timeStr = lastMsgTime != null
        ? timeago.format(lastMsgTime, locale: 'pt_BR')
        : null;

    return GestureDetector(
      onTap: () => _openReadOnly(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: r.s(16), vertical: r.s(12)),
        child: Row(
          children: [
            // ── Ícone da sala ──────────────────────────────────────────────
            Container(
              width: r.s(52),
              height: r.s(52),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.accentPrimary.withValues(alpha: 0.25),
                image: hasIcon
                    ? DecorationImage(
                        image:
                            CachedNetworkImageProvider(chatRoom.iconUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: !hasIcon
                  ? Icon(Icons.forum_rounded,
                      color: theme.accentPrimary, size: r.s(26))
                  : null,
            ),
            SizedBox(width: r.s(12)),

            // ── Conteúdo central ───────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título + hora
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chatRoom.title,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: r.fs(14),
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (timeStr != null) ...[
                        SizedBox(width: r.s(6)),
                        Text(
                          timeStr,
                          style: TextStyle(
                              color: theme.textHint,
                              fontSize: r.fs(11)),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: r.s(3)),

                  // Descrição ou última mensagem
                  Text(
                    chatRoom.lastMessagePreview?.isNotEmpty == true
                        ? chatRoom.lastMessagePreview!
                        : (chatRoom.description?.isNotEmpty == true
                            ? chatRoom.description!
                            : 'Nenhuma mensagem ainda'),
                    style: TextStyle(
                      color: theme.textHint,
                      fontSize: r.fs(12),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: r.s(4)),

                  // Badges: membros + announcement only
                  Row(
                    children: [
                      Icon(Icons.people_rounded,
                          color: theme.textHint, size: r.s(12)),
                      SizedBox(width: r.s(3)),
                      Text(
                        '${chatRoom.membersCount}',
                        style: TextStyle(
                            color: theme.textHint, fontSize: r.fs(11)),
                      ),
                      if (chatRoom.isAnnouncementOnly) ...[
                        SizedBox(width: r.s(8)),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: r.s(6), vertical: r.s(2)),
                          decoration: BoxDecoration(
                            color: theme.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(r.s(4)),
                          ),
                          child: Text(
                            'Anúncios',
                            style: TextStyle(
                              color: theme.warning,
                              fontSize: r.fs(10),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // ── Seta ───────────────────────────────────────────────────────
            SizedBox(width: r.s(8)),
            Icon(Icons.chevron_right_rounded,
                color: theme.textHint, size: r.s(20)),
          ],
        ),
      ),
    );
  }
}
