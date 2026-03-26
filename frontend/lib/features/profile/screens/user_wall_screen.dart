import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';

/// Mural do Usuário (The Wall) — Mensagens públicas no perfil, estilo Amino.
class UserWallScreen extends StatefulWidget {
  final String userId;
  const UserWallScreen({super.key, required this.userId});

  @override
  State<UserWallScreen> createState() => _UserWallScreenState();
}

class _UserWallScreenState extends State<UserWallScreen> {
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  final _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final res = await SupabaseService.table('wall_messages')
          .select('*, profiles!wall_messages_author_id_fkey(nickname, icon_url)')
          .eq('target_user_id', widget.userId)
          .order('created_at', ascending: false)
          .limit(50);
      _messages = List<Map<String, dynamic>>.from(res as List);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await SupabaseService.table('wall_messages').insert({
        'target_user_id': widget.userId,
        'author_id': SupabaseService.currentUserId,
        'content': text,
      });
      _messageController.clear();
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await SupabaseService.table('wall_messages')
          .delete()
          .eq('id', messageId);
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOwnWall = widget.userId == SupabaseService.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(isOwnWall ? 'Meu Mural' : 'Mural',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Lista de mensagens
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.dashboard_rounded,
                                size: 64, color: AppTheme.textHint),
                            const SizedBox(height: 16),
                            const Text('Nenhuma mensagem no mural',
                                style: TextStyle(
                                    color: AppTheme.textSecondary)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadMessages,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final author = msg['profiles']
                                as Map<String, dynamic>?;
                            final authorId =
                                msg['author_id'] as String?;
                            final createdAt = DateTime.tryParse(
                                    msg['created_at'] as String? ??
                                        '') ??
                                DateTime.now();
                            final canDelete = isOwnWall ||
                                authorId ==
                                    SupabaseService.currentUserId;

                            return Container(
                              margin:
                                  const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.cardColor,
                                borderRadius:
                                    BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          if (authorId != null) {
                                            context.push(
                                                '/user/$authorId');
                                          }
                                        },
                                        child: CircleAvatar(
                                          radius: 16,
                                          backgroundImage: author?[
                                                      'icon_url'] !=
                                                  null
                                              ? CachedNetworkImageProvider(
                                                  author!['icon_url']
                                                      as String)
                                              : null,
                                          child: author?[
                                                      'icon_url'] ==
                                                  null
                                              ? const Icon(
                                                  Icons
                                                      .person_rounded,
                                                  size: 16)
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment
                                                  .start,
                                          children: [
                                            Text(
                                              author?['nickname']
                                                      as String? ??
                                                  'Anônimo',
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight
                                                          .w600,
                                                  fontSize: 13),
                                            ),
                                            Text(
                                              timeago.format(
                                                  createdAt,
                                                  locale: 'pt_BR'),
                                              style: const TextStyle(
                                                  color: AppTheme
                                                      .textHint,
                                                  fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (canDelete)
                                        IconButton(
                                          icon: const Icon(
                                              Icons
                                                  .delete_outline_rounded,
                                              size: 18,
                                              color: AppTheme
                                                  .textHint),
                                          onPressed: () =>
                                              _deleteMessage(
                                                  msg['id']
                                                      as String),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    msg['content'] as String? ?? '',
                                    style: const TextStyle(
                                        fontSize: 14),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),

          // Input para nova mensagem
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              border: Border(
                top: BorderSide(
                    color: AppTheme.dividerColor.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Escreva no mural...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                          color: AppTheme.textHint, fontSize: 14),
                    ),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
                IconButton(
                  onPressed: _isSending ? null : _sendMessage,
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded,
                          color: AppTheme.primaryColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
