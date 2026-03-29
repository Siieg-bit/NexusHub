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
      final res = await SupabaseService.table('comments')
          .select(
              '*, profiles!comments_author_id_fkey(id, nickname, icon_url)')
          .eq('profile_wall_id', widget.userId)
          .eq('status', 'ok')
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
      await SupabaseService.table('comments').insert({
        'profile_wall_id': widget.userId,
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
      await SupabaseService.table('comments').delete().eq('id', messageId);
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
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
        title: Text(isOwnWall ? 'Meu Mural' : 'Mural',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            )),
      ),
      body: Column(
        children: [
          // Lista de mensagens
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.dashboard_rounded,
                                size: 64, color: Colors.grey[600]),
                            const SizedBox(height: 16),
                            Text('Nenhuma mensagem no mural',
                                style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppTheme.primaryColor,
                        backgroundColor: context.surfaceColor,
                        onRefresh: _loadMessages,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final author =
                                (msg['profiles'] ?? msg['author']) as Map<String, dynamic>?;
                            final authorId = msg['author_id'] as String?;
                            final createdAt = DateTime.tryParse(
                                    msg['created_at'] as String? ?? '') ??
                                DateTime.now();
                            final canDelete = isOwnWall ||
                                authorId == SupabaseService.currentUserId;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: context.surfaceColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          if (authorId != null) {
                                            context.push('/user/$authorId');
                                          }
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppTheme.primaryColor
                                                  .withValues(alpha: 0.5),
                                              width: 2,
                                            ),
                                          ),
                                          child: CircleAvatar(
                                            radius: 16,
                                            backgroundColor: context.scaffoldBg,
                                            backgroundImage:
                                                author?['icon_url'] != null
                                                    ? CachedNetworkImageProvider(
                                                        author!['icon_url']
                                                            as String)
                                                    : null,
                                            child: author?['icon_url'] == null
                                                ? Icon(
                                                    Icons.person_rounded,
                                                    size: 16,
                                                    color: context.textPrimary)
                                                : null,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              author?['nickname'] as String? ??
                                                  'Anônimo',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: context.textPrimary,
                                                  fontSize: 14),
                                            ),
                                            Text(
                                              timeago.format(createdAt,
                                                  locale: 'pt_BR'),
                                              style: TextStyle(
                                                  color: Colors.grey[500],
                                                  fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (canDelete)
                                        IconButton(
                                          icon: Icon(
                                              Icons.delete_outline_rounded,
                                              size: 18,
                                              color: Colors.grey[500]),
                                          onPressed: () => _deleteMessage(
                                              msg['id'] as String),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    msg['content'] as String? ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: context.textPrimary,
                                    ),
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
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: context.scaffoldBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(color: context.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Escreva no mural...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                      maxLines: 3,
                      minLines: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _isSending ? null : _sendMessage,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryColor, AppTheme.accentColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _isSending
                        ? const Padding(
                            padding: EdgeInsets.all(14.0),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
