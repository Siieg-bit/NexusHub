import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/amino_animations.dart';
import '../../../core/utils/responsive.dart';

// =============================================================================
// TAB: Chat — Public + private chats the user belongs to
// Bug #3 fix: Adicionado RefreshIndicator para pull-to-refresh.
// =============================================================================

class CommunityChatTab extends StatefulWidget {
  final String communityId;

  const CommunityChatTab({super.key, required this.communityId});

  @override
  State<CommunityChatTab> createState() => _CommunityChatTabState();
}

class _CommunityChatTabState extends State<CommunityChatTab> {
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    try {
      final userId = SupabaseService.currentUserId;

      // Buscar chats públicos da comunidade (visíveis para todos)
      final publicResponse = await SupabaseService.table('chat_threads')
          .select()
          .eq('community_id', widget.communityId)
          .eq('type', 'public')
          .order('last_message_at', ascending: false)
          .limit(20);

      // Buscar chats privados/grupo onde o usuário é membro
      List<dynamic> privateChats = [];
      if (userId != null) {
        final memberResponse = await SupabaseService.table('chat_members')
            .select('thread_id, chat_threads!inner(*)')
            .eq('user_id', userId)
            .neq('chat_threads.type', 'public');
        privateChats = (memberResponse as List? ?? [])
            .where((e) =>
                e['chat_threads'] != null &&
                e['chat_threads']['community_id'] == widget.communityId)
            .map((e) => e['chat_threads'] as Map<String, dynamic>)
            .toList();
      }

      // Combinar e deduplicar por id
      final allChats = <String, Map<String, dynamic>>{};
      for (final c
          in List<Map<String, dynamic>>.from(publicResponse as List? ?? [])) {
        allChats[c['id'] as String? ?? ''] = c;
      }
      for (final c in privateChats) {
        allChats[c['id'] as String? ?? ''] = c as Map<String, dynamic>;
      }

      _chats = allChats.values.toList()
        ..sort((a, b) {
          final aTime = a['last_message_at'] as String? ?? '';
          final bTime = b['last_message_at'] as String? ?? '';
          return bTime.compareTo(aTime);
        });

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    await _loadChats();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
            color: AppTheme.primaryColor, strokeWidth: 2.5),
      );
    }

    if (_chats.isEmpty) {
      // Bug #3 fix: Mesmo o estado vazio permite pull-to-refresh
      return RefreshIndicator(
        onRefresh: _refresh,
        color: AppTheme.primaryColor,
        backgroundColor: context.surfaceColor,
        child: LayoutBuilder(
          builder: (ctx, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded,
                        size: r.s(48), color: context.textHint),
                    SizedBox(height: r.s(12)),
                    Text('Nenhum chat nesta comunidade ainda',
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: r.fs(13))),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppTheme.primaryColor,
      backgroundColor: context.surfaceColor,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(r.s(12)),
        itemCount: _chats.length,
        itemBuilder: (context, index) {
          final chat = _chats[index];
          return AminoAnimations.staggerItem(
            index: index,
            child: AminoAnimations.cardPress(
              onTap: () => context.push('/chat/${chat['id']}'),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: r.s(10)),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: context.dividerClr.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: r.s(44),
                      height: r.s(44),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        shape: BoxShape.circle,
                      ),
                      child: chat['icon_url'] != null
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: chat['icon_url'] as String? ?? '',
                                fit: BoxFit.cover,
                              ),
                            )
                          : Icon(Icons.tag_rounded,
                              color: context.textHint, size: r.s(18)),
                    ),
                    SizedBox(width: r.s(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chat['title'] as String? ?? 'Chat',
                            style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: r.fs(13)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${chat['members_count'] ?? 0} membros',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: r.fs(10)),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: Colors.grey[600], size: r.s(16)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
