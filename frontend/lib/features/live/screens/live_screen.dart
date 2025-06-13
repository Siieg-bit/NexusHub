import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/call_service.dart';
import '../../chat/screens/call_screen.dart';
import 'screening_room_screen.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../config/nexus_theme_data.dart';

/// Tela Live — exibe Salas de Projeção e Voice Chats ativos.
///
/// Permite criar novas sessões e entrar em sessões existentes.
/// Chamadas de vídeo não são suportadas neste app.
class LiveScreen extends ConsumerStatefulWidget {
  final String? communityId;
  const LiveScreen({super.key, this.communityId});

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  bool _isLoading = true;
  bool _isCreating = false;
  List<Map<String, dynamic>> _activeSessions = [];

  @override
  void initState() {
    super.initState();
    _loadActiveSessions();
  }

  Future<void> _loadActiveSessions() async {
    try {
      var query = SupabaseService.table('call_sessions')
          .select(
              '*, call_participants(count), profiles!call_sessions_creator_id_fkey(nickname, icon_url)')
          .eq('status', 'active')
          // Excluir video sessions (não suportado)
          .neq('type', 'video')
          .order('created_at', ascending: false);

      if (widget.communityId != null) {
        // Filtrar por comunidade via chat_threads
        final threads = await SupabaseService.table('chat_threads')
            .select('id')
            .eq('community_id', widget.communityId!);
        final threadIds = (threads as List)
            .map((t) => t['id'] as String)
            .toList();
        if (threadIds.isNotEmpty) {
          query = SupabaseService.table('call_sessions')
              .select(
                  '*, call_participants(count), profiles!call_sessions_creator_id_fkey(nickname, icon_url)')
              .eq('status', 'active')
              .neq('type', 'video')
              .inFilter('thread_id', threadIds)
              .order('created_at', ascending: false);
        }
      }

      final res = await query;
      if (!mounted) return;
      setState(() {
        _activeSessions = List<Map<String, dynamic>>.from(res as List? ?? []);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // CRIAR SALA DE PROJEÇÃO
  // ============================================================
  Future<void> _createScreeningRoom() async {
    final s = getStrings();
    final r = context.r;
    final titleController = TextEditingController(text: 'Sala de Projeção');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.s(16))),
        title: Text(s.createScreeningRoom,
            style: TextStyle(
                color: context.nexusTheme.textPrimary,
                fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: TextStyle(color: context.nexusTheme.textPrimary),
              decoration: InputDecoration(
                hintText: s.roomName,
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: Icon(Icons.live_tv_rounded,
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
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    titleController.dispose();
    if (result == null) return;

    setState(() => _isCreating = true);
    try {
      final thread = await SupabaseService.table('chat_threads')
          .insert({
            'community_id': widget.communityId,
            'type': 'screening_room',
            'title': result['title'] ?? 'Sala de Projeção',
            'host_id': SupabaseService.currentUserId,
          })
          .select()
          .single();

      await SupabaseService.table('chat_members').insert({
        'thread_id': thread['id'] as String,
        'user_id': SupabaseService.currentUserId,
        'status': 'active',
      });

      if (mounted) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ScreeningRoomScreen(
            threadId: thread['id'] as String? ?? '',
          ),
        ));
        _loadActiveSessions();
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
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  // ============================================================
  // CRIAR VOICE CHAT
  // ============================================================
  Future<void> _createVoiceChat() async {
    final s = getStrings();
    final r = context.r;
    final titleController = TextEditingController(text: 'Voice Chat');

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.s(16))),
        title: Text(
          'Criar Voice Chat',
          style: TextStyle(
              color: context.nexusTheme.textPrimary,
              fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: titleController,
          style: TextStyle(color: context.nexusTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Nome do Voice Chat',
            hintStyle: TextStyle(color: Colors.grey[600]),
            prefixIcon: Icon(Icons.headset_mic_rounded,
                color: const Color(0xFF4CAF50)),
            filled: true,
            fillColor: context.nexusTheme.surfacePrimary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(r.s(12)),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel, style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, titleController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.s(10))),
            ),
            child: Text(s.create,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    titleController.dispose();
    if (result == null) return;

    setState(() => _isCreating = true);
    try {
      // Criar um chat thread para o Voice Chat
      final thread = await SupabaseService.table('chat_threads')
          .insert({
            'community_id': widget.communityId,
            'type': 'voice',
            'title': result.isEmpty ? 'Voice Chat' : result,
            'host_id': SupabaseService.currentUserId,
          })
          .select()
          .single();

      await SupabaseService.table('chat_members').insert({
        'thread_id': thread['id'] as String,
        'user_id': SupabaseService.currentUserId,
        'status': 'active',
      });

      final threadId = thread['id'] as String;

      // Criar e entrar na sessão via CallService
      final callResult = await CallService.openThreadCallDetailed(
        threadId: threadId,
        type: CallType.voice,
      );

      if (!mounted) return;

      if (callResult == null) {
        final report = CallService.buildLastErrorReport(
          title: 'LIVE VOICE CHAT CREATION FAILURE',
        );
        debugPrint(report);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Falha ao criar Voice Chat. Verifique as permissões de microfone.'),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await CallScreen.show(context, callResult.session);
      if (mounted) _loadActiveSessions();
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
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  // ============================================================
  // ENTRAR EM SESSÃO EXISTENTE
  // ============================================================
  Future<void> _joinSession(Map<String, dynamic> session) async {
    final type = session['type'] as String? ?? 'voice';
    final sessionId = session['id'] as String?;
    final threadId = session['thread_id'] as String?;

    if (sessionId == null || threadId == null) return;

    if (type == 'screening_room') {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ScreeningRoomScreen(
          threadId: threadId,
          callSessionId: sessionId,
        ),
      ));
      if (mounted) _loadActiveSessions();
      return;
    }

    if (type == 'voice') {
      setState(() => _isCreating = true);
      try {
        final callResult = await CallService.openThreadCallDetailed(
          threadId: threadId,
          type: CallType.voice,
        );

        if (!mounted) return;

        if (callResult == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Falha ao entrar no Voice Chat.'),
              backgroundColor: context.nexusTheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        await CallScreen.show(context, callResult.session);
        if (mounted) _loadActiveSessions();
      } finally {
        if (mounted) setState(() => _isCreating = false);
      }
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================
  String _typeLabel(String type) {
    switch (type) {
      case 'screening_room':
        return 'Sala de Projeção';
      case 'voice':
        return 'Voice Chat';
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

  // ============================================================
  // BUILD
  // ============================================================
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
        actions: [
          if (_isCreating)
            Padding(
              padding: EdgeInsets.only(right: r.s(16)),
              child: SizedBox(
                width: r.s(20),
                height: r.s(20),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.nexusTheme.accentPrimary,
                ),
              ),
            ),
        ],
      ),
      // FAB expandido com menu de opções
      floatingActionButton: _isCreating
          ? null
          : _buildCreateFab(r),
      body: SafeArea(
        bottom: true,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                    color: context.nexusTheme.accentPrimary))
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
      ),
    );
  }

  Widget _buildCreateFab(Responsive r) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Mini FAB: Voice Chat
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: r.s(12), vertical: r.s(6)),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(r.s(8)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'Voice Chat',
                style: TextStyle(
                    color: context.nexusTheme.textPrimary,
                    fontSize: r.fs(13),
                    fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(width: r.s(8)),
            FloatingActionButton.small(
              heroTag: 'fab_voice',
              onPressed: _createVoiceChat,
              backgroundColor: const Color(0xFF4CAF50),
              child: const Icon(Icons.headset_mic_rounded,
                  color: Colors.white),
            ),
          ],
        ),
        SizedBox(height: r.s(10)),
        // Mini FAB: Sala de Projeção
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: r.s(12), vertical: r.s(6)),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(r.s(8)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'Sala de Projeção',
                style: TextStyle(
                    color: context.nexusTheme.textPrimary,
                    fontSize: r.fs(13),
                    fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(width: r.s(8)),
            FloatingActionButton.small(
              heroTag: 'fab_screening',
              onPressed: _createScreeningRoom,
              backgroundColor: const Color(0xFFE91E63),
              child: const Icon(Icons.live_tv_rounded, color: Colors.white),
            ),
          ],
        ),
      ],
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
                  color: context.nexusTheme.accentPrimary
                      .withValues(alpha: 0.1),
                ),
                child: Icon(Icons.live_tv_rounded,
                    size: r.s(48),
                    color: context.nexusTheme.accentPrimary),
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
                'Salas de Projeção e Voice Chats\naparecerão aqui quando estiverem ativos.',
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
    final creatorName =
        creatorProfile?['nickname'] as String? ?? s.anonymous;
    final creatorAvatar = creatorProfile?['icon_url'] as String?;
    final participantCount =
        (session['call_participants'] as List?)?.first?['count'] as int? ?? 0;
    final createdAt = session['created_at'] as String?;

    return GestureDetector(
      onTap: () => _joinSession(session),
      child: Container(
        margin: EdgeInsets.only(bottom: r.s(10)),
        padding: EdgeInsets.all(r.s(14)),
        decoration: BoxDecoration(
          color: context.nexusTheme.surfacePrimary,
          borderRadius: BorderRadius.circular(r.s(16)),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
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
                          child: Text(
                            creatorName.isNotEmpty
                                ? creatorName[0].toUpperCase()
                                : '?',
                            style: TextStyle(fontSize: r.fs(8)),
                          ),
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
            // Participantes + botão Entrar
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
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
                      Icon(Icons.people_rounded,
                          color: color, size: r.s(14)),
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
                SizedBox(height: r.s(6)),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(10), vertical: r.s(4)),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(r.s(8)),
                  ),
                  child: Text(
                    'Entrar',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: r.fs(11),
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
