import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/screening_participant.dart';
import '../providers/screening_room_provider.dart';
import '../providers/screening_chat_provider.dart';

// =============================================================================
// ScreeningTransferHostSheet — Bottom sheet para transferir o controle de host
//
// Exibe a lista de participantes e permite ao host atual transferir o controle
// para qualquer outro participante. Ao confirmar:
// 1. Chama ScreeningRoomNotifier.transferHost(newHostId)
// 2. Injeta mensagem de sistema no chat ("Host transferido para [nome]")
// 3. Fecha o bottom sheet
// =============================================================================

class ScreeningTransferHostSheet extends ConsumerWidget {
  final String sessionId;
  final String threadId;

  const ScreeningTransferHostSheet({
    super.key,
    required this.sessionId,
    required this.threadId,
  });

  static Future<void> show(
    BuildContext context, {
    required String sessionId,
    required String threadId,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ScreeningTransferHostSheet(
        sessionId: sessionId,
        threadId: threadId,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomState = ref.watch(screeningRoomProvider(threadId));
    final currentHostId = roomState.hostUserId ?? '';

    // Apenas participantes que não são o host atual
    final candidates = roomState.participants
        .where((p) => p.userId != currentHostId)
        .toList();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Título
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              children: [
                Icon(Icons.swap_horiz_rounded, color: Colors.amberAccent, size: 20),
                SizedBox(width: 8),
                Text(
                  'Transferir controle',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Escolha quem vai controlar a reprodução',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // Lista de candidatos
          if (candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Nenhum outro participante na sala.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 13,
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: candidates.length,
              itemBuilder: (context, index) {
                final participant = candidates[index];
                return _CandidateTile(
                  participant: participant,
                  onTransfer: () async {
                    Navigator.of(context).pop();
                    await _transferHost(context, ref, participant);
                  },
                );
              },
            ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Future<void> _transferHost(
    BuildContext context,
    WidgetRef ref,
    ScreeningParticipant newHost,
  ) async {
    try {
      await ref
          .read(screeningRoomProvider(threadId).notifier)
          .transferHost(newHost.userId);

      // Mensagem de sistema no chat
      ref.read(screeningChatProvider(sessionId).notifier).addSystemMessage(
            'Host transferido para ${newHost.username}',
          );
    } catch (e) {
      debugPrint('[TransferHost] error: $e');
    }
  }
}

// ── Tile de candidato ─────────────────────────────────────────────────────────

class _CandidateTile extends StatelessWidget {
  final ScreeningParticipant participant;
  final VoidCallback onTransfer;

  const _CandidateTile({
    required this.participant,
    required this.onTransfer,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.white24,
        backgroundImage: participant.avatarUrl != null
            ? NetworkImage(participant.avatarUrl!)
            : null,
        child: participant.avatarUrl == null
            ? Text(
                participant.username.isNotEmpty
                    ? participant.username[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Text(
        participant.username,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: TextButton(
        onPressed: onTransfer,
        style: TextButton.styleFrom(
          backgroundColor: Colors.amberAccent.withValues(alpha: 0.15),
          foregroundColor: Colors.amberAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.amberAccent, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        ),
        child: const Text(
          'Transferir',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
