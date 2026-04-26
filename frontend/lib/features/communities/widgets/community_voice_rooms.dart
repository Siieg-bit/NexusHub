import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/call_service.dart';
import '../../../core/utils/amino_animations.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// =============================================================================
// COMMUNITY VOICE ROOMS — Salas de Voz e Palco ativas na comunidade
// Exibe call_sessions do tipo 'voice' e 'stage' com status 'active'
// vinculadas a threads da comunidade. Fica oculto quando não há salas ativas.
// =============================================================================

class CommunityVoiceRooms extends ConsumerStatefulWidget {
  final String communityId;
  const CommunityVoiceRooms({super.key, required this.communityId});

  @override
  ConsumerState<CommunityVoiceRooms> createState() =>
      _CommunityVoiceRoomsState();
}

class _CommunityVoiceRoomsState extends ConsumerState<CommunityVoiceRooms> {
  List<Map<String, dynamic>> _rooms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    try {
      // Busca call_sessions ativas (voice ou stage) cujo thread pertence à comunidade
      final response = await SupabaseService.table('call_sessions')
          .select(
              '*, chat_threads!call_sessions_thread_id_fkey(id, name, community_id), profiles!call_sessions_host_id_fkey(id, nickname, icon_url)')
          .eq('status', 'active')
          .inFilter('type', ['voice', 'stage'])
          .order('started_at', ascending: false)
          .limit(20);

      final all = List<Map<String, dynamic>>.from(response as List? ?? []);
      // Filtrar apenas as salas da comunidade atual
      final filtered = all.where((r) {
        final thread = r['chat_threads'] as Map<String, dynamic>?;
        return thread != null &&
            thread['community_id'] == widget.communityId;
      }).toList();

      if (mounted) {
        setState(() {
          _rooms = filtered;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[community_voice_rooms] Erro: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinRoom(Map<String, dynamic> room) async {
    final type = room['type'] as String? ?? 'voice';
    final sessionId = room['id'] as String;
    final threadId = (room['chat_threads'] as Map<String, dynamic>?)?['id'] as String?;
    final channelName = room['channel_name'] as String? ?? sessionId;
    final title = (room['chat_threads'] as Map<String, dynamic>?)?['name'] as String? ?? 'Sala de Voz';

    if (!mounted) return;

    final callType = type == 'stage' ? CallType.stage : CallType.voice;

    await CallService.joinCall(sessionId);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _rooms.isEmpty) return const SizedBox.shrink();

    final r = context.r;
    final theme = context.nexusTheme;

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(r.s(16), r.s(12), r.s(16), r.s(8)),
            child: Row(
              children: [
                Container(
                  width: r.s(8),
                  height: r.s(8),
                  decoration: BoxDecoration(
                    color: theme.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.success.withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: r.s(6)),
                Text(
                  'Salas de Voz Ativas',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: r.fs(14),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: r.s(6)),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(6), vertical: r.s(2)),
                  decoration: BoxDecoration(
                    color: theme.accentPrimary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(r.s(8)),
                  ),
                  child: Text(
                    '${_rooms.length}',
                    style: TextStyle(
                      color: theme.accentPrimary,
                      fontSize: r.fs(11),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Cards horizontais
          SizedBox(
            height: r.s(88),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: r.s(12)),
              itemCount: _rooms.length,
              itemBuilder: (context, index) =>
                  _VoiceRoomCard(room: _rooms[index], onJoin: _joinRoom),
            ),
          ),
          SizedBox(height: r.s(4)),
        ],
    );
  }
}

// =============================================================================
// CARD DE SALA DE VOZ
// =============================================================================
class _VoiceRoomCard extends StatelessWidget {
  final Map<String, dynamic> room;
  final Future<void> Function(Map<String, dynamic>) onJoin;

  const _VoiceRoomCard({required this.room, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;
    final type = room['type'] as String? ?? 'voice';
    final isStage = type == 'stage';
    final thread = room['chat_threads'] as Map<String, dynamic>?;
    final host = room['profiles'] as Map<String, dynamic>?;
    final title = thread?['name'] as String? ?? 'Sala de Voz';
    final hostName = host?['nickname'] as String? ?? 'Anônimo';
    final participantCount = room['participant_count'] as int? ?? 0;

    final color = isStage ? theme.accentPrimary : theme.success;
    final icon = isStage ? Icons.mic_external_on_rounded : Icons.headset_rounded;
    final label = isStage ? 'Palco' : 'Voz';

    return GestureDetector(
      onTap: () => onJoin(room),
      child: Container(
        width: r.s(180),
        margin: EdgeInsets.symmetric(horizontal: r.s(4), vertical: r.s(2)),
        padding: EdgeInsets.all(r.s(10)),
        decoration: BoxDecoration(
          color: theme.backgroundSecondary,
          borderRadius: BorderRadius.circular(r.s(14)),
          border: Border.all(
            color: color.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Tipo + participantes
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(6), vertical: r.s(2)),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(r.s(6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: color, size: r.s(11)),
                      SizedBox(width: r.s(3)),
                      Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontSize: r.fs(10),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (participantCount > 0) ...[
                  Icon(Icons.people_rounded,
                      color: theme.textHint, size: r.s(11)),
                  SizedBox(width: r.s(2)),
                  Text(
                    '$participantCount',
                    style: TextStyle(
                      color: theme.textHint,
                      fontSize: r.fs(10),
                    ),
                  ),
                ],
              ],
            ),
            // Título
            Text(
              title,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: r.fs(12),
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // Host
            Row(
              children: [
                Icon(Icons.person_rounded,
                    color: theme.textHint, size: r.s(11)),
                SizedBox(width: r.s(3)),
                Expanded(
                  child: Text(
                    hostName,
                    style: TextStyle(
                      color: theme.textHint,
                      fontSize: r.fs(10),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Botão entrar
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(8), vertical: r.s(3)),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(r.s(8)),
                  ),
                  child: Text(
                    'Entrar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.fs(10),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
