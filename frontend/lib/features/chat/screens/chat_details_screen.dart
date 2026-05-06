// =============================================================================
// ChatDetailsScreen — Página de detalhes do chat público
//
// Exibe:
//   • Capa do chat (banner) com gradiente
//   • Avatar + nome + categoria + descrição
//   • Contagem de membros
//   • Grid de membros (avatares)
//   • Botão de convidar
//   • Seções de configurações completas (Personalização, Membros, Notificações,
//     Moderação, Zona de perigo)
// =============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/deep_link_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/providers/chat_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/chat_cover_picker.dart';
import '../widgets/chat_moderation_sheet.dart';
import '../widgets/chat_background_picker.dart';
import 'chat_room_screen.dart' show showBubblePickerFromDetails;
import 'chat_list_screen.dart' show chatListProvider;
import 'package:amino_clone/config/nexus_theme_extension.dart';

class ChatDetailsScreen extends ConsumerStatefulWidget {
  final String threadId;
  const ChatDetailsScreen({super.key, required this.threadId});

  @override
  ConsumerState<ChatDetailsScreen> createState() => _ChatDetailsScreenState();
}

class _ChatDetailsScreenState extends ConsumerState<ChatDetailsScreen> {
  Map<String, dynamic>? _threadInfo;
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  String? _callerRole;
  bool _isAnnouncementOnly = false;
  bool _isReadOnly = false;
  bool _isMuted = false;
  bool _isTogglingMute = false;
  bool _isVoiceOpenToAll = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userId = SupabaseService.currentUserId;

      // Carregar info do thread
      final threadRes = await SupabaseService.table('chat_threads')
          .select()
          .eq('id', widget.threadId)
          .single();
      final threadInfo = Map<String, dynamic>.from(threadRes as Map);

      // Determinar role do usuário atual
      String? role;
      if (userId != null) {
        final hostId = threadInfo['host_id'] as String?;
        final coHosts = (threadInfo['co_hosts'] as List?) ?? [];
        if (userId == hostId) {
          role = 'host';
        } else if (coHosts.contains(userId)) {
          role = 'co_host';
        } else {
          final memberData = await SupabaseService.table('chat_members')
              .select('role')
              .eq('thread_id', widget.threadId)
              .eq('user_id', userId)
              .maybeSingle();
          role = memberData?['role'] as String?;
        }
      }

      // Carregar membros (limitado a 24 para o grid)
       final membersRes = await SupabaseService.table('chat_members')
          .select(
              '*, profiles!chat_members_user_id_fkey(id, nickname, icon_url)')
          .eq('thread_id', widget.threadId)
          .order('joined_at', ascending: true)
          .limit(24);
      final members =
          List<Map<String, dynamic>>.from(membersRes as List? ?? []);
      // Carregar is_muted do usuário atual
      bool isMuted = false;
      if (userId != null) {
        final myMember = await SupabaseService.table('chat_members')
            .select('is_muted')
            .eq('thread_id', widget.threadId)
            .eq('user_id', userId)
            .maybeSingle();
        isMuted = myMember?['is_muted'] as bool? ?? false;
      }
      if (mounted) {
        setState(() {
          _threadInfo = threadInfo;
          _members = members;
          _callerRole = role ?? 'member';
          _isAnnouncementOnly =
              threadInfo['is_announcement_only'] as bool? ?? false;
          _isReadOnly = threadInfo['is_read_only'] as bool? ?? false;
          _isMuted = isMuted;
          _isVoiceOpenToAll =
              threadInfo['is_voice_open_to_all'] as bool? ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[ChatDetails] Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openInvite() {
    final title = _threadInfo?['title'] as String? ?? '';
    DeepLinkService.shareUrl(
      type: 'chat',
      targetId: widget.threadId,
      title: title,
      text: title,
    );
  }

  void _openModeration() {
    showChatModerationSheet(
      context: context,
      threadId: widget.threadId,
      callerRole: _callerRole,
      isAnnouncementOnly:
          _threadInfo?['is_announcement_only'] as bool? ?? false,
      currentCover: _threadInfo?['cover_image_url'] as String?,
      currentTitle: _threadInfo?['title'] as String?,
      communityId: _threadInfo?['community_id'] as String?,
      onTitleChanged: () => _loadData(),
      onCoverChanged: (url) {
        if (mounted) {
          setState(() => _threadInfo?['cover_image_url'] = url);
        }
      },
      onAnnouncementOnlyChanged: (val) {
        if (mounted) {
          setState(() => _threadInfo?['is_announcement_only'] = val);
        }
      },
    );
  }

  void _editCover() {
    showChatCoverPicker(
      context: context,
      threadId: widget.threadId,
      currentCover: _threadInfo?['cover_image_url'] as String?,
      canEdit: true,
      onChanged: (url) {
        if (mounted) setState(() => _threadInfo?['cover_image_url'] = url);
      },
    );
  }

  void _showBackgroundPicker() {
    showChatBackgroundPicker(
      context: context,
      threadId: widget.threadId,
      currentBackground: null,
      onChanged: (_) {},
    );
  }

  void _showBubblePicker() {
    showBubblePickerFromDetails(context, ref);
  }

  void _leaveChatConfirm() {
    final s = ref.read(stringsProvider);
    final r = context.r;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.s(16))),
        title: Text(s.leaveChatTitle,
            style: TextStyle(
                color: context.nexusTheme.textPrimary,
                fontWeight: FontWeight.w700)),
        content: Text(s.confirmLeaveChat,
            style: TextStyle(
                color: Colors.grey[400], fontSize: r.fs(14))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text(s.cancel, style: TextStyle(color: Colors.grey[500])),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _leaveChat();
            },
            child: Text(s.logout,
                style: TextStyle(
                    color: context.nexusTheme.error,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveChat() async {
    try {
      await SupabaseService.rpc('leave_public_chat',
          params: {'p_thread_id': widget.threadId});
      ref.invalidate(chatListProvider);
      if (mounted) context.go('/chat');
    } catch (e) {
      debugPrint('[ChatDetails] leave error: $e');
    }
  }

  void _deleteChatConfirm() {
    final s = ref.read(stringsProvider);
    final r = context.r;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.s(16))),
        title: Text(s.deleteChatTitle,
            style: TextStyle(
                color: context.nexusTheme.textPrimary,
                fontWeight: FontWeight.w700)),
        content: Text(s.confirmDeleteChat2,
            style: TextStyle(
                color: Colors.grey[400], fontSize: r.fs(14))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text(s.cancel, style: TextStyle(color: Colors.grey[500])),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteChat();
            },
            child: Text(s.delete,
                style: TextStyle(
                    color: context.nexusTheme.error,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteChat() async {
    try {
      await SupabaseService.rpc('delete_public_chat',
          params: {'p_thread_id': widget.threadId});
      ref.invalidate(chatListProvider);
      if (mounted) context.go('/chat');
    } catch (e) {
      debugPrint('[ChatDetails] delete error: $e');
    }
  }

  Future<void> _toggleVoiceOpenToAll() async {
    final newVal = !_isVoiceOpenToAll;
    try {
      await SupabaseService.table('chat_threads')
          .update({'is_voice_open_to_all': newVal})
          .eq('id', widget.threadId);
      if (mounted) {
        setState(() => _isVoiceOpenToAll = newVal);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newVal
                ? 'Qualquer membro pode iniciar o voice chat'
                : 'Apenas host pode iniciar o voice chat'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[ChatDetails] toggle voice open to all: $e');
    }
  }

  Future<void> _toggleAnnouncementOnly() async {
    final newVal = !_isAnnouncementOnly;
    try {
      await SupabaseService.table('chat_threads')
          .update({'is_announcement_only': newVal})
          .eq('id', widget.threadId);
      if (mounted) setState(() => _isAnnouncementOnly = newVal);
    } catch (e) {
      debugPrint('[ChatDetails] toggle announcement: $e');
    }
  }

  Future<void> _toggleReadOnly() async {
    final newVal = !_isReadOnly;
    try {
      final result = await SupabaseService.rpc(
        'toggle_chat_read_only',
        params: {
          'p_thread_id': widget.threadId,
          'p_enabled': newVal,
        },
      );
      final res = result as Map<String, dynamic>?;
      if (res?['success'] == true && mounted) {
        setState(() => _isReadOnly = newVal);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newVal
                ? 'Modo somente leitura ativado'
                : 'Modo somente leitura desativado'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[ChatDetails] toggle read-only: $e');
    }
  }

  Future<void> _toggleMute(bool muted) async {
    if (_isTogglingMute) return;
    setState(() => _isTogglingMute = true);
    try {
      await SupabaseService.rpc('toggle_chat_mute', params: {
        'p_thread_id': widget.threadId,
        'p_muted': muted,
      });
      if (mounted) {
        setState(() {
          _isMuted = muted;
          _isTogglingMute = false;
        });
      }
    } catch (e) {
      debugPrint('[ChatDetails] toggle mute: $e');
      if (mounted) setState(() => _isTogglingMute = false);
    }
  }

  Future<void> _toggleChatDisabled(bool disabled) async {
    try {
      final result = await SupabaseService.rpc(
          'toggle_chat_thread_status',
          params: {
            'p_thread_id': widget.threadId,
            'p_disabled': disabled,
          });
      final res = result is Map<String, dynamic>
          ? result
          : (result is Map
              ? Map<String, dynamic>.from(result)
              : <String, dynamic>{});
      if (res['success'] == true && mounted) {
        setState(() {
          _threadInfo = {
            ...?_threadInfo,
            'status': disabled ? 'disabled' : 'ok',
          };
        });
        ref.invalidate(chatListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(disabled
                ? 'Chat desativado com sucesso.'
                : 'Chat reativado com sucesso.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[ChatDetails] toggle disabled: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final s = ref.watch(stringsProvider);
    final theme = context.nexusTheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: theme.backgroundPrimary,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: theme.iconPrimary, size: r.s(22)),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(
              color: theme.accentPrimary, strokeWidth: 2),
        ),
      );
    }

    final title = _threadInfo?['title'] as String? ?? '';
    final description = _threadInfo?['description'] as String?;
    final coverUrl = _threadInfo?['cover_image_url'] as String?;
    final iconUrl = _threadInfo?['icon_url'] as String?;
    final category = _threadInfo?['category'] as String?;
    final threadType = _threadInfo?['type'] as String? ?? 'public';
    final isPublic = threadType == 'public';
    final memberCount = _members.length;
    final isHost = _callerRole == 'host' || _callerRole == 'co_host';
    final currentUser = ref.read(currentUserProvider);
    final canManage = isHost || (currentUser?.isTeamMember ?? false);
    final canDelete = (SupabaseService.currentUserId != null &&
            SupabaseService.currentUserId ==
                (_threadInfo?['host_id'] as String?)) ||
        (currentUser?.isTeamMember ?? false);
    final isChatDisabled =
        (_threadInfo?['status'] as String? ?? 'ok') == 'disabled';

    return Scaffold(
      backgroundColor: theme.backgroundPrimary,
      body: CustomScrollView(
        slivers: [
          // ── AppBar com capa ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: r.s(220),
            pinned: true,
            backgroundColor: theme.backgroundPrimary,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: r.s(22)),
              onPressed: () => context.pop(),
            ),
            actions: [
              if (isHost)
                IconButton(
                  icon: Icon(Icons.edit_rounded,
                      color: Colors.white, size: r.s(20)),
                  onPressed: _editCover,
                  tooltip: 'Editar capa',
                ),
              if (canManage)
                IconButton(
                  icon: Icon(Icons.settings_rounded,
                      color: Colors.white, size: r.s(20)),
                  onPressed: _openModeration,
                  tooltip: s.settings,
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Capa / banner
                  if (coverUrl != null)
                    CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: theme.surfacePrimary,
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.accentPrimary.withValues(alpha: 0.7),
                            theme.accentSecondary.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                    ),
                  // Gradiente escuro na parte inferior para legibilidade
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                          stops: const [0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Conteúdo principal ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: r.s(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: r.s(20)),

                  // Avatar + nome + categoria
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar
                      Container(
                        width: r.s(64),
                        height: r.s(64),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: theme.accentPrimary, width: r.s(2)),
                          color: theme.surfacePrimary,
                        ),
                        child: ClipOval(
                          child: (iconUrl != null)
                              ? CachedNetworkImage(
                                  imageUrl: iconUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Icon(
                                    Icons.group_rounded,
                                    color: theme.iconSecondary,
                                    size: r.s(32),
                                  ),
                                )
                              : Icon(
                                  Icons.group_rounded,
                                  color: theme.iconSecondary,
                                  size: r.s(32),
                                ),
                        ),
                      ),
                      SizedBox(width: r.s(14)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: r.fs(20),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (category != null && category.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: r.s(4)),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: r.s(8), vertical: r.s(2)),
                                  decoration: BoxDecoration(
                                    color: theme.accentPrimary
                                        .withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(r.s(20)),
                                    border: Border.all(
                                        color: theme.accentPrimary
                                            .withValues(alpha: 0.4),
                                        width: 1),
                                  ),
                                  child: Text(
                                    _categoryLabel(category),
                                    style: TextStyle(
                                      color: theme.accentPrimary,
                                      fontSize: r.fs(11),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: r.s(16)),

                  // Descrição
                  if (description != null && description.isNotEmpty) ...[
                    Text(
                      description,
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: r.fs(14),
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: r.s(16)),
                  ],

                  // Contagem de membros
                  Row(
                    children: [
                      Icon(Icons.people_rounded,
                          color: theme.iconSecondary, size: r.s(16)),
                      SizedBox(width: r.s(6)),
                      Text(
                        '$memberCount ${s.members.toLowerCase()}',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: r.fs(13),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: r.s(20)),

                  // Botão de convidar (apenas público)
                  if (isPublic) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openInvite,
                        icon: Icon(Icons.person_add_rounded,
                            size: r.s(18), color: Colors.white),
                        label: Text(
                          s.invite,
                          style: TextStyle(
                            fontSize: r.fs(14),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.accentPrimary,
                          padding:
                              EdgeInsets.symmetric(vertical: r.s(14)),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(r.s(12)),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    SizedBox(height: r.s(28)),
                  ],

                  // Seção de membros
                  Text(
                    s.chatMembers,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: r.fs(16),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: r.s(14)),

                  // Grid de membros
                  _buildMembersGrid(r, theme, s),

                  SizedBox(height: r.s(32)),

                  // ══════════════════════════════════════════════════════════
                  // SEÇÕES DE CONFIGURAÇÕES
                  // ══════════════════════════════════════════════════════════

                  // ── Personalização ────────────────────────────────────────
                  _sectionLabel(r, 'Personalização'),
                  _settingsTile(r, Icons.wallpaper_rounded,
                      s.chatBackground, _showBackgroundPicker),
                  _settingsTile(r, Icons.chat_bubble_rounded,
                      'Meu Bubble', _showBubblePicker),
                  if (isHost)
                    _settingsTile(r, Icons.image_rounded, 'Capa do chat',
                        _editCover),
                  SizedBox(height: r.s(8)),

                  // ── Membros ───────────────────────────────────────────────
                  _sectionLabel(r, 'Membros'),
                  _settingsTile(r, Icons.info_outline_rounded,
                      'Detalhes do chat', () {
                    // já estamos nessa tela, não faz nada
                  }),
                  if (isPublic)
                    _settingsTile(r, Icons.share_rounded,
                        'Compartilhar chat', _openInvite),
                  SizedBox(height: r.s(8)),

                  // ── Notificações ──────────────────────────────────────────
                  _sectionLabel(r, 'Notificações'),
                  _muteTile(r, theme),
                  SizedBox(height: r.s(8)),

                  // ── Voice Chat (host + público) ─────────────────────────────────
                  if (isHost && isPublic) ...[                    
                    _sectionLabel(r, 'Voice Chat'),
                    _voiceOpenToAllTile(r, theme),
                    SizedBox(height: r.s(8)),
                  ],
                  // ── Moderação (host + público) ────────────────────────────
                  if (isHost && isPublic) ...[
                    _sectionLabel(r, 'Moderação'),
                    _settingsTile(
                        r,
                        Icons.manage_accounts_rounded,
                        'Gerenciar membros',
                        _openModeration),
                    _settingsTile(
                      r,
                      _isAnnouncementOnly
                          ? Icons.record_voice_over_rounded
                          : Icons.voice_over_off_rounded,
                      _isAnnouncementOnly
                          ? 'Desativar modo anúncio'
                          : 'Modo somente anúncio',
                      _toggleAnnouncementOnly,
                    ),
                    _settingsTile(
                      r,
                      _isReadOnly
                          ? Icons.lock_open_rounded
                          : Icons.lock_outline_rounded,
                      _isReadOnly
                          ? 'Desativar modo somente leitura'
                          : 'Modo somente leitura',
                      _toggleReadOnly,
                    ),
                    _settingsTile(
                      r,
                      isChatDisabled
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      isChatDisabled ? 'Reativar chat' : 'Desativar chat',
                      () => _toggleChatDisabled(!isChatDisabled),
                      isDestructive: !isChatDisabled,
                    ),
                    SizedBox(height: r.s(8)),
                  ],

                  // ── Zona de perigo ────────────────────────────────────────
                  if (canDelete || !isHost) ...[
                    Divider(
                        color: Colors.white.withValues(alpha: 0.07),
                        height: r.s(16)),
                    if (!isHost)
                      _settingsTile(
                        r,
                        Icons.exit_to_app_rounded,
                        s.leaveChatTitle,
                        _leaveChatConfirm,
                        isDestructive: true,
                      ),
                    if (canDelete)
                      _settingsTile(
                        r,
                        Icons.delete_rounded,
                        s.deleteChatTitle,
                        _deleteChatConfirm,
                        isDestructive: true,
                      ),
                  ],

                  SizedBox(height: r.s(40)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers de UI ──────────────────────────────────────────────────────────

  Widget _sectionLabel(Responsive r, String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: r.s(4), top: r.s(2)),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: r.fs(10),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _settingsTile(
      Responsive r, IconData icon, String label, VoidCallback onTap,
      {bool isDestructive = false}) {
    final color = isDestructive
        ? context.nexusTheme.error
        : Colors.grey[400]!;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: r.s(12)),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.05))),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: r.s(20)),
            SizedBox(width: r.s(12)),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: isDestructive
                          ? context.nexusTheme.error
                          : context.nexusTheme.textPrimary,
                      fontSize: r.fs(14))),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey[600], size: r.s(18)),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersGrid(Responsive r, dynamic theme, AppStrings s) {
    if (_members.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: r.s(20)),
          child: Text(
            s.noMemberFound,
            style: TextStyle(
                color: theme.textSecondary, fontSize: r.fs(13)),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: r.s(12),
        mainAxisSpacing: r.s(16),
        childAspectRatio: 0.75,
      ),
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final member = _members[index];
        final profile =
            member['profiles'] as Map<String, dynamic>? ?? {};
        final nickname = profile['nickname'] as String? ?? s.user;
        final iconUrl = profile['icon_url'] as String?;
        final userId = profile['id'] as String? ?? '';

        return GestureDetector(
          onTap: () {
            if (userId.isNotEmpty) {
              context.push('/profile/$userId');
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: r.s(56),
                height: r.s(56),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.surfacePrimary,
                  border: Border.all(
                    color: theme.accentPrimary.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: (iconUrl != null)
                      ? CachedNetworkImage(
                          imageUrl: iconUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Icon(
                            Icons.person_rounded,
                            color: theme.iconSecondary,
                            size: r.s(28),
                          ),
                        )
                      : Icon(
                          Icons.person_rounded,
                          color: theme.iconSecondary,
                          size: r.s(28),
                        ),
                ),
              ),
              SizedBox(height: r.s(6)),
              Text(
                nickname,
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: r.fs(11),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _muteTile(Responsive r, dynamic theme) {
    return GestureDetector(
      onTap: _isTogglingMute ? null : () => _toggleMute(!_isMuted),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: r.s(12)),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.05))),
        ),
        child: Row(
          children: [
            Icon(
              _isMuted
                  ? Icons.notifications_off_rounded
                  : Icons.notifications_active_rounded,
              color: _isMuted
                  ? Colors.grey[600]!
                  : Colors.grey[400]!,
              size: r.s(20),
            ),
            SizedBox(width: r.s(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isMuted
                        ? 'Notificações silenciadas'
                        : 'Silenciar notificações',
                    style: TextStyle(
                      color: _isMuted
                          ? Colors.grey[600]!
                          : theme.textPrimary,
                      fontSize: r.fs(14),
                    ),
                  ),
                  Text(
                    _isMuted
                        ? 'Toque para reativar'
                        : 'Desativar notificações deste chat',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: r.fs(11),
                    ),
                  ),
                ],
              ),
            ),
            _isTogglingMute
                ? SizedBox(
                    width: r.s(20),
                    height: r.s(20),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.accentPrimary,
                    ),
                  )
                : Switch(
                    value: _isMuted,
                    onChanged: (val) => _toggleMute(val),
                    activeColor: theme.accentPrimary,
                    inactiveThumbColor: Colors.grey[600],
                    inactiveTrackColor: Colors.grey[800],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _voiceOpenToAllTile(Responsive r, dynamic theme) {
    return GestureDetector(
      onTap: _toggleVoiceOpenToAll,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: r.s(12)),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.05))),
        ),
        child: Row(
          children: [
            Icon(
              Icons.mic_external_on_rounded,
              color: _isVoiceOpenToAll
                  ? context.nexusTheme.accentPrimary
                  : Colors.grey[400]!,
              size: r.s(20),
            ),
            SizedBox(width: r.s(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Qualquer membro pode iniciar',
                    style: TextStyle(
                      color: _isVoiceOpenToAll
                          ? context.nexusTheme.accentPrimary
                          : context.nexusTheme.textPrimary,
                      fontSize: r.fs(14),
                    ),
                  ),
                  Text(
                    _isVoiceOpenToAll
                        ? 'Membros podem iniciar o voice chat'
                        : 'Somente host pode iniciar o voice chat',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: r.fs(11),
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _isVoiceOpenToAll,
              onChanged: (_) => _toggleVoiceOpenToAll(),
              activeColor: context.nexusTheme.accentPrimary,
              inactiveThumbColor: Colors.grey[600],
              inactiveTrackColor: Colors.grey[800],
            ),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(String category) {
    const labels = {
      'general': 'Geral',
      'gaming': 'Games',
      'anime': 'Anime',
      'music': 'Música',
      'art': 'Arte',
      'tech': 'Tecnologia',
      'sports': 'Esportes',
      'movies': 'Filmes',
      'books': 'Livros',
      'food': 'Comida',
      'travel': 'Viagens',
      'fashion': 'Moda',
      'science': 'Ciência',
      'news': 'Notícias',
      'other': 'Outro',
    };
    return labels[category] ?? category;
  }
}
