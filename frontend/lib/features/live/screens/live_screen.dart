import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import 'screening_room_screen.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../../config/nexus_theme_extension.dart';
import '../../../../config/nexus_theme_extension.dart';

/// Tela Live — exibe Salas de Projeção, Voice Chats e Video Chats ativos.
///
/// No Amino original, esta tela mostra todas as salas ativas
/// da comunidade com contagem de participantes, tipo de sala,
/// e permite criar novas salas.
class LiveScreen extends ConsumerStatefulWidget {
  final String? communityId;
  const LiveScreen({super.key, this.communityId});

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _activeSessions = [];

  @override
  void initState() {
    super.initState();
    _loadActiveSessions();
  }

  Future<void> _loadActiveSessions() async {
    try {
      final query = SupabaseService.table('call_sessions')
          .select(
              '*, call_participants(count), profiles!call_sessions_creator_id_fkey(username, avatar_url)')
          .eq('status', 'active')
          .order('created_at', ascending: false);

      final res = await query;
      if (!mounted) return;
      _activeSessions = List<Map<String, dynamic>>.from(res as List? ?? []);
      if (!mounted) return;
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createScreeningRoom() async {
    final s = getStrings();
    final r = context.r;
    // Precisa de um thread_id — criar um chat thread temporário ou usar existente
    final threadIdController = TextEditingController();
    final titleController = TextEditingController(text: 'Sala de Projeção');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.s(16))),
        title: Text(s.createScreeningRoom,
            style: TextStyle(
                color: context.nexusTheme.textPrimary, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: TextStyle(color: context.nexusTheme.textPrimary),
              decoration: InputDecoration(
                hintText: s.roomName,
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: const Icon(Icons.live_tv_rounded,
                    color: context.nexusTheme.accentSecondary),
                filled: true,
                fillColor: context.nexusTheme.surfacePrimary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel, style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, {
              'title': titleController.text.trim(),
            }),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.nexusTheme.accentPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.s(10))),
            ),
            child: Text(s.create,
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    titleController.dispose();
    threadIdController.dispose();

    if (result == null) return;

    try {
      // Criar um chat thread para a Sala de Projeção
      final thread = await SupabaseService.table('chat_threads')
          .insert({
            'community_id': widget.communityId,
            'type': 'screening_room',
            'title': result['title'] ?? 'Sala de Projeção',
            'host_id': SupabaseService.currentUserId,
          })
          .select()
          .single();

      // Adicionar criador como membro do chat
      await SupabaseService.table('chat_members').insert({
        'thread_id': thread['id'] as String,
        'user_id': SupabaseService.currentUserId,
        'status': 'active',
      });

      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ScreeningRoomScreen(
            threadId: thread['id'] as String? ?? '',
          ),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorCreatingRoom),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'screening_room':
        return 'Sala de Projeção';
      case 'voice':
        return 'Voice Chat';
      case 'video':
        return 'Video Chat';
      default:
        return 'Live';
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'screening_room':
        return Icons.live_tv_rounded;
      case 'voice':
        return Icons.headset_mic_rounded;
      case 'video':
        return Icons.videocam_rounded;
      default:
        return Icons.live_tv_rounded;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'screening_room':
        return const Color(0xFFE91E63);
      case 'voice':
        return const Color(0xFF4CAF50);
      case 'video':
        return const Color(0xFF2196F3);
      default:
        return context.nexusTheme.accentPrimary;
    }
  }

  String _timeAgo(String? dateStr) {
    final s = getStrings();
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}min';
    return s.now;
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        iconTheme: IconThemeData(color: context.nexusTheme.textPrimary),
        title: Text(
          'Live',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: context.nexusTheme.textPrimary,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createScreeningRoom,
        backgroundColor: context.nexusTheme.accentSecondary,
        icon: const Icon(Icons.live_tv_rounded, color: Colors.white),
        label: const Text('Sala de Projeção',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: context.nexusTheme.accentPrimary))
          : RefreshIndicator(
              onRefresh: _loadActiveSessions,
              color: context.nexusTheme.accentSecondary,
              child: _activeSessions.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: EdgeInsets.all(r.s(12)),
                      itemCount: _activeSessions.length,
                      itemBuilder: (ctx, i) =>
                          _buildSessionCard(_activeSessions[i]),
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    final r = context.r;
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: r.s(100),
                height: r.s(100),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.nexusTheme.accentPrimary.withValues(alpha: 0.1),
                ),
                child: Icon(Icons.live_tv_rounded,
                    size: r.s(48), color: context.nexusTheme.accentPrimary),
              ),
              SizedBox(height: r.s(24)),
              Text(
                'Nenhuma Sala Ativa',
                style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: r.fs(20),
                ),
              ),
              SizedBox(height: r.s(8)),
              Text(
                'Salas de Projeção, Voice Chats e Video Chats\naparecerão aqui quando estiverem ativos.',
                style: TextStyle(color: Colors.grey[500], height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final s = getStrings();
    final r = context.r;
    final type = session['type'] as String? ?? 'voice';
    final color = _typeColor(type);
    final creatorProfile = session['profiles'] as Map<String, dynamic>?;
    final creatorName = creatorProfile?['username'] as String? ?? s.anonymous;
    final creatorAvatar = creatorProfile?['avatar_url'] as String?;
    final participantCount =
        (session['call_participants'] as List?)?.first?['count'] as int? ?? 0;
    final createdAt = session['created_at'] as String?;

    return GestureDetector(
      onTap: () {
        if (type == 'screening_room') {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ScreeningRoomScreen(
              threadId: session['thread_id'] as String? ?? '',
              callSessionId: session['id'] as String?,
            ),
          ));
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: r.s(10)),
        padding: EdgeInsets.all(r.s(14)),
        decoration: BoxDecoration(
          color: context.nexusTheme.surfacePrimary,
          borderRadius: BorderRadius.circular(r.s(16)),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            // Ícone do tipo
            Container(
              width: r.s(50),
              height: r.s(50),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(r.s(14)),
              ),
              child: Icon(_typeIcon(type), color: color, size: r.s(26)),
            ),
            SizedBox(width: r.s(14)),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _typeLabel(type),
                    style: TextStyle(
                      color: context.nexusTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: r.fs(15),
                    ),
                  ),
                  SizedBox(height: r.s(4)),
                  Row(
                    children: [
                      if (creatorAvatar != null)
                        CircleAvatar(
                          radius: 8,
                          backgroundImage: NetworkImage(creatorAvatar),
                        )
                      else
                        CircleAvatar(
                          radius: 8,
                          backgroundColor: context.surfaceColor,
                          child: Text(creatorName[0].toUpperCase(),
                              style: TextStyle(fontSize: r.fs(8))),
                        ),
                      SizedBox(width: r.s(6)),
                      Text(
                        creatorName,
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: r.fs(12)),
                      ),
                      Text(
                        '  •  ${_timeAgo(createdAt)}',
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: r.fs(12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Participantes
            Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(10), vertical: r.s(6)),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(r.s(20)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_rounded, color: color, size: r.s(14)),
                      SizedBox(width: r.s(4)),
                      Text(
                        '$participantCount',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: r.fs(13),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: r.s(4)),
                Text(
                  'ENTRAR',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: r.fs(9),
                    letterSpacing: 0.5,
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
