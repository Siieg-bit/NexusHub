import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/nexus_empty_state.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// ── Provider ──────────────────────────────────────────────────────────────────
final chatRequestsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return [];
  final result = await SupabaseService.client
      .from('chat_requests')
      .select('''
        id, message, status, created_at,
        sender:profiles!sender_id (
          id, nickname, icon_url, is_nickname_verified
        )
      ''')
      .eq('receiver_id', userId)
      .eq('status', 'pending')
      .order('created_at', ascending: false);
  return (result as List).map((e) => e as Map<String, dynamic>).toList();
});

// ── Screen ────────────────────────────────────────────────────────────────────
class ChatRequestsScreen extends ConsumerWidget {
  const ChatRequestsScreen({super.key});

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    String requestId,
    bool accept,
  ) async {
    final result = await SupabaseService.rpc('respond_chat_request', params: {
      'p_request_id': requestId,
      'p_accept': accept,
    });
    if (!context.mounted) return;
    final success = result?['success'] as bool? ?? false;
    if (success) {
      ref.invalidate(chatRequestsProvider);
      if (accept) {
        final threadId = result?['thread_id'] as String?;
        if (threadId != null) {
          context.push('/chat/$threadId');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitação recusada.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: ${result?['error'] ?? 'desconhecido'}')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final requestsAsync = ref.watch(chatRequestsProvider);

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Solicitações de Chat',
          style: TextStyle(
            color: context.nexusTheme.textPrimary,
            fontSize: r.fs(17),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Erro: $e',
              style: TextStyle(color: context.nexusTheme.textSecondary)),
        ),
        data: (requests) {
          if (requests.isEmpty) {
            return NexusEmptyState(
              icon: Icons.mark_chat_unread_rounded,
              title: 'Nenhuma solicitação',
              subtitle:
                  'Quando alguém quiser te enviar uma mensagem, aparecerá aqui.',
            );
          }
          return ListView.builder(
            padding: EdgeInsets.all(r.s(16)),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              final sender =
                  req['sender'] as Map<String, dynamic>? ?? {};
              final nickname =
                  sender['nickname'] as String? ?? 'Usuário';
              final iconUrl = sender['icon_url'] as String?;
              final senderId = sender['id'] as String? ?? '';
              final isVerified =
                  sender['is_nickname_verified'] as bool? ?? false;
              final message = req['message'] as String?;
              final createdAt = req['created_at'] as String?;
              final requestId = req['id'] as String;

              return Container(
                margin: EdgeInsets.only(bottom: r.s(12)),
                padding: EdgeInsets.all(r.s(16)),
                decoration: BoxDecoration(
                  color: context.nexusTheme.backgroundSecondary,
                  borderRadius: BorderRadius.circular(r.s(16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Cabeçalho ──────────────────────────────────────────
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.push('/profile/$senderId'),
                          child: CircleAvatar(
                            radius: r.s(24),
                            backgroundImage: iconUrl != null
                                ? CachedNetworkImageProvider(iconUrl)
                                : null,
                            backgroundColor: context.nexusTheme.accentPrimary
                                .withValues(alpha: 0.2),
                            child: iconUrl == null
                                ? Icon(Icons.person_rounded,
                                    color: context.nexusTheme.accentPrimary,
                                    size: r.s(24))
                                : null,
                          ),
                        ),
                        SizedBox(width: r.s(12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    nickname,
                                    style: TextStyle(
                                      color: context.nexusTheme.textPrimary,
                                      fontSize: r.fs(15),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (isVerified) ...[
                                    SizedBox(width: r.s(4)),
                                    Icon(
                                      Icons.verified_rounded,
                                      color: context.nexusTheme.accentPrimary,
                                      size: r.s(14),
                                    ),
                                  ],
                                ],
                              ),
                              if (createdAt != null)
                                Text(
                                  timeago.format(
                                    DateTime.parse(createdAt),
                                    locale: 'pt_BR',
                                  ),
                                  style: TextStyle(
                                    color: context.nexusTheme.textSecondary,
                                    fontSize: r.fs(11),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // ── Mensagem de apresentação ───────────────────────────
                    if (message != null && message.isNotEmpty) ...[
                      SizedBox(height: r.s(10)),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(r.s(10)),
                        decoration: BoxDecoration(
                          color: context.nexusTheme.backgroundPrimary,
                          borderRadius: BorderRadius.circular(r.s(10)),
                        ),
                        child: Text(
                          message,
                          style: TextStyle(
                            color: context.nexusTheme.textPrimary,
                            fontSize: r.fs(13),
                          ),
                        ),
                      ),
                    ],

                    SizedBox(height: r.s(12)),

                    // ── Ações ──────────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                _respond(context, ref, requestId, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: context.nexusTheme.textSecondary,
                              side: BorderSide(
                                  color: context.nexusTheme.textSecondary
                                      .withValues(alpha: 0.3)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(r.s(10)),
                              ),
                            ),
                            child: const Text('Recusar'),
                          ),
                        ),
                        SizedBox(width: r.s(10)),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                _respond(context, ref, requestId, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  context.nexusTheme.accentPrimary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(r.s(10)),
                              ),
                            ),
                            child: const Text('Aceitar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
