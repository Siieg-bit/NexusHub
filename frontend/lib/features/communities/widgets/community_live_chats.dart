import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/amino_animations.dart';
import '../../../core/utils/responsive.dart';

// =============================================================================
// LIVE CHATROOMS SECTION — Estilo Amino (horizontal scroll cards)
// Exibe apenas chats do tipo 'public' da comunidade.
// O botão de criação fica no menu "+" da barra inferior.
// =============================================================================

class CommunityLiveChats extends StatefulWidget {
  final String communityId;
  final CommunityModel community;

  const CommunityLiveChats({
    super.key,
    required this.communityId,
    required this.community,
  });

  @override
  State<CommunityLiveChats> createState() => _CommunityLiveChatsState();
}

class _CommunityLiveChatsState extends State<CommunityLiveChats> {
  List<Map<String, dynamic>> _chats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    try {
      // Filtra apenas chats do tipo 'public' — DMs e grupos privados não aparecem aqui
      final response = await SupabaseService.table('chat_threads')
          .select()
          .eq('community_id', widget.communityId)
          .eq('type', 'public')
          .order('last_message_at', ascending: false)
          .limit(10);
      if (mounted) {
        setState(() {
          _chats = List<Map<String, dynamic>>.from(response as List? ?? []);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[community_live_chats] Erro: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    // Enquanto carrega ou sem chats, não ocupa espaço
    if (_loading || _chats.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(
          left: r.s(12), right: r.s(12), top: r.s(4), bottom: r.s(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cabeçalho ──────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.only(bottom: r.s(8)),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_rounded,
                    color: AppTheme.primaryColor, size: r.s(16)),
                SizedBox(width: r.s(6)),
                Text(
                  'Chats Públicos',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: r.fs(13),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // ── Lista horizontal de cards ───────────────────────────────────
          SizedBox(
            height: r.s(130),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _chats.length,
              itemBuilder: (context, index) {
                final chat = _chats[index];
                final membersCount = chat['members_count'] as int? ?? 0;

                return AminoAnimations.cardPress(
                  onTap: () => context.push('/chat/${chat['id']}'),
                  child: Container(
                    width: r.s(150),
                    margin: EdgeInsets.only(right: r.s(8)),
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(r.s(12)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cover
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(r.s(12))),
                                child: chat['icon_url'] != null
                                    ? CachedNetworkImage(
                                        imageUrl: chat['icon_url'] as String,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: AppTheme.primaryColor
                                            .withValues(alpha: 0.2),
                                        child: Icon(
                                            Icons.chat_bubble_rounded,
                                            color: AppTheme.primaryColor
                                                .withValues(alpha: 0.5),
                                            size: r.s(28)),
                                      ),
                              ),
                              // Badge de membros
                              Positioned(
                                top: r.s(6),
                                right: r.s(6),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: r.s(6), vertical: r.s(2)),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.black.withValues(alpha: 0.6),
                                    borderRadius:
                                        BorderRadius.circular(r.s(10)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.people_rounded,
                                          color: Colors.white,
                                          size: r.s(10)),
                                      SizedBox(width: r.s(3)),
                                      Text(
                                        '$membersCount',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: r.fs(9),
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Título
                        Padding(
                          padding: EdgeInsets.all(r.s(8)),
                          child: Text(
                            chat['title'] as String? ?? 'Chat',
                            style: TextStyle(
                                color: context.textPrimary,
                                fontSize: r.fs(11),
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
