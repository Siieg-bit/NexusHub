import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import 'screening_room_screen.dart';

/// Tela Live — exibe Screening Rooms, Voice Chats e Video Chats ativos.
///
/// No Amino original, esta tela mostra todas as salas ativas
/// da comunidade com contagem de participantes, tipo de sala,
/// e permite criar novas salas.
class LiveScreen extends StatefulWidget {
  final String? communityId;
  const LiveScreen({super.key, this.communityId});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
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
          .select('*, call_participants(count), profiles!creator_id(username, avatar_url)')
          .eq('status', 'active')
          .order('created_at', ascending: false);

      final res = await query;
      _activeSessions = List<Map<String, dynamic>>.from(res as List);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createScreeningRoom() async {
    // Precisa de um thread_id — criar um chat thread temporário ou usar existente
    final threadIdController = TextEditingController();
    final titleController = TextEditingController(text: 'Screening Room');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Criar Screening Room',
            style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Nome da sala',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: const Icon(Icons.live_tv_rounded,
                    color: AppTheme.accentColor),
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, {
              'title': titleController.text.trim(),
            }),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Criar',
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
      // Criar um chat thread para a screening room
      final thread = await SupabaseService.table('chat_threads')
          .insert({
            'community_id': widget.communityId,
            'type': 'screening_room',
            'title': result['title'] ?? 'Screening Room',
            'creator_id': SupabaseService.currentUserId,
          })
          .select()
          .single();

      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ScreeningRoomScreen(
            threadId: thread['id'] as String,
          ),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar sala: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'screening_room':
        return 'Screening Room';
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
        return AppTheme.primaryColor;
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}min';
    return 'agora';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        title: const Text(
          'Live',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createScreeningRoom,
        backgroundColor: AppTheme.aminoPink,
        icon: const Icon(Icons.live_tv_rounded, color: Colors.white),
        label: const Text('Screening Room',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              onRefresh: _loadActiveSessions,
              color: AppTheme.accentColor,
              child: _activeSessions.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _activeSessions.length,
                      itemBuilder: (ctx, i) =>
                          _buildSessionCard(_activeSessions[i]),
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                ),
                child: const Icon(Icons.live_tv_rounded,
                    size: 48, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: 24),
              const Text(
                'Nenhuma Sala Ativa',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Screening Rooms, Voice Chats e Video Chats\naparecerão aqui quando estiverem ativos.',
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
    final type = session['type'] as String? ?? 'voice';
    final color = _typeColor(type);
    final creatorProfile = session['profiles'] as Map<String, dynamic>?;
    final creatorName = creatorProfile?['username'] as String? ?? 'Anônimo';
    final creatorAvatar = creatorProfile?['avatar_url'] as String?;
    final participantCount =
        (session['call_participants'] as List?)?.first?['count'] as int? ?? 0;
    final createdAt = session['created_at'] as String?;

    return GestureDetector(
      onTap: () {
        if (type == 'screening_room') {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ScreeningRoomScreen(
              threadId: session['thread_id'] as String,
              callSessionId: session['id'] as String,
            ),
          ));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            // Ícone do tipo
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_typeIcon(type), color: color, size: 26),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _typeLabel(type),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
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
                          backgroundColor: AppTheme.surfaceColor,
                          child: Text(creatorName[0].toUpperCase(),
                              style: const TextStyle(fontSize: 8)),
                        ),
                      const SizedBox(width: 6),
                      Text(
                        creatorName,
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      Text(
                        '  •  ${_timeAgo(createdAt)}',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 12),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_rounded, color: color, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '$participantCount',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ENTRAR',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
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
