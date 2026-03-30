import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/chat_room_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

/// Bottom sheet para encaminhar uma mensagem para um ou mais chats.
class ForwardMessageSheet extends ConsumerStatefulWidget {
  final String messageContent;
  final String? mediaUrl;
  final String? mediaType;

  const ForwardMessageSheet({
    super.key,
    required this.messageContent,
    this.mediaUrl,
    this.mediaType,
  });

  @override
  ConsumerState<ForwardMessageSheet> createState() =>
      _ForwardMessageSheetState();
}

class _ForwardMessageSheetState extends ConsumerState<ForwardMessageSheet> {
  List<ChatRoomModel> _chats = [];
  List<ChatRoomModel> _filtered = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _sending = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadChats();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final rows = await SupabaseService.table('chat_members')
          .select('thread_id, chat_threads(*)')
          .eq('user_id', userId)
          .eq('status', 'accepted');
      final chats = (rows as List? ?? [])
          .where((e) => e['chat_threads'] != null)
          .map((e) =>
              ChatRoomModel.fromJson(e['chat_threads'] as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _chats = chats;
          _filtered = chats;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _chats
          : _chats
              .where((c) => c.title.toLowerCase().contains(q))
              .toList();
    });
  }

  Future<void> _send() async {
    if (_selected.isEmpty) return;
    setState(() => _sending = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      for (final threadId in _selected) {
        await SupabaseService.table('chat_messages').insert({
          'thread_id': threadId,
          'sender_id': userId,
          'content': widget.messageContent,
          'type': widget.mediaType == 'gif' ? 'gif' : 'forward',
          'media_url': widget.mediaUrl,
          'media_type': widget.mediaType,
          'is_forwarded': true,
        });
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_selected.length == 1
                ? 'Mensagem encaminhada!'
                : 'Mensagem encaminhada para ${_selected.length} chats!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao encaminhar. Tente novamente.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(24))),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: EdgeInsets.only(top: r.s(12)),
              width: r.s(40),
              height: r.s(4),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(r.s(2)),
              ),
            ),
          ),
          // Header
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: r.s(20), vertical: r.s(12)),
            child: Row(
              children: [
                Text(
                  'Encaminhar para',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: r.fs(18),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (_selected.isNotEmpty)
                  TextButton(
                    onPressed: _sending ? null : _send,
                    child: _sending
                        ? SizedBox(
                            width: r.s(18),
                            height: r.s(18),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryColor),
                            ),
                          )
                        : Text(
                            'Enviar (${_selected.length})',
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
              ],
            ),
          ),
          // Preview da mensagem
          Container(
            margin: EdgeInsets.symmetric(horizontal: r.s(20)),
            padding: EdgeInsets.all(r.s(12)),
            decoration: BoxDecoration(
              color: context.scaffoldBg,
              borderRadius: BorderRadius.circular(r.s(12)),
              border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.forward_rounded,
                    color: AppTheme.primaryColor, size: r.s(16)),
                SizedBox(width: r.s(8)),
                Expanded(
                  child: Text(
                    widget.mediaUrl != null
                        ? '[${widget.mediaType ?? 'mídia'}]'
                        : (widget.messageContent.length > 60
                            ? '${widget.messageContent.substring(0, 60)}...'
                            : widget.messageContent),
                    style: TextStyle(
                        color: Colors.grey[400], fontSize: r.fs(13)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r.s(12)),
          // Busca
          Padding(
            padding: EdgeInsets.symmetric(horizontal: r.s(20)),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'Buscar chat...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon:
                    Icon(Icons.search_rounded, color: Colors.grey[600]),
                filled: true,
                fillColor: context.scaffoldBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: r.s(10)),
              ),
            ),
          ),
          SizedBox(height: r.s(8)),
          // Lista de chats
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhum chat encontrado',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (context, i) {
                          final chat = _filtered[i];
                          final isSelected = _selected.contains(chat.id);
                          return ListTile(
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  radius: r.s(22),
                                  backgroundColor: AppTheme.primaryColor
                                      .withValues(alpha: 0.2),
                                  backgroundImage: chat.iconUrl != null
                                      ? CachedNetworkImageProvider(
                                          chat.iconUrl!)
                                      : null,
                                  child: chat.iconUrl == null
                                      ? Text(
                                          chat.title[0].toUpperCase(),
                                          style: TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.w700,
                                            fontSize: r.fs(16),
                                          ),
                                        )
                                      : null,
                                ),
                                if (isSelected)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: r.s(18),
                                      height: r.s(18),
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primaryColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.check_rounded,
                                          color: Colors.white,
                                          size: r.s(12)),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              chat.title,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: r.fs(14),
                              ),
                            ),
                            subtitle: Text(
                              chat.type == 'dm'
                                  ? 'Mensagem direta'
                                  : '${chat.membersCount} membros',
                              style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: r.fs(12)),
                            ),
                            trailing: Checkbox(
                              value: isSelected,
                              onChanged: (_) => setState(() {
                                if (isSelected) {
                                  _selected.remove(chat.id);
                                } else {
                                  _selected.add(chat.id);
                                }
                              }),
                              activeColor: AppTheme.primaryColor,
                              shape: const CircleBorder(),
                            ),
                            onTap: () => setState(() {
                              if (isSelected) {
                                _selected.remove(chat.id);
                              } else {
                                _selected.add(chat.id);
                              }
                            }),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
