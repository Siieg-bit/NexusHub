import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// ============================================================================
// FLAG CENTER SCREEN
// Centro de denúncias para Leaders/Curators/Moderators.
// • Usa o RPC get_community_flags (com preview do snapshot)
// • Ao clicar num card, navega para FlagDetailScreen (conteúdo original completo)
// • O conteúdo original é preservado mesmo após exclusão (content_snapshots)
// ============================================================================
class FlagCenterScreen extends ConsumerStatefulWidget {
  final String communityId;
  const FlagCenterScreen({super.key, required this.communityId});

  @override
  ConsumerState<FlagCenterScreen> createState() => _FlagCenterScreenState();
}

class _FlagCenterScreenState extends ConsumerState<FlagCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _pendingFlags = [];
  List<Map<String, dynamic>> _resolvedFlags = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFlags();
  }

  Future<void> _loadFlags() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Usar o RPC get_community_flags que retorna preview do snapshot
      final pendingResult = await SupabaseService.rpc('get_community_flags', params: {
        'p_community_id': widget.communityId,
        'p_status': 'pending',
        'p_limit': 50,
        'p_offset': 0,
      });
      final resolvedResult = await SupabaseService.rpc('get_community_flags', params: {
        'p_community_id': widget.communityId,
        'p_status': 'all',
        'p_limit': 50,
        'p_offset': 0,
      });

      final pendingData = pendingResult as Map<String, dynamic>?;
      final resolvedData = resolvedResult as Map<String, dynamic>?;

      final allPending = List<Map<String, dynamic>>.from(
          (pendingData?['flags'] as List?) ?? []);
      final allResolved = List<Map<String, dynamic>>.from(
          (resolvedData?['flags'] as List?) ?? [])
        .where((f) => (f['status'] as String?) != 'pending')
        .toList();

      if (!mounted) return;
      setState(() {
        _pendingFlags = allPending;
        _resolvedFlags = allResolved;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _openFlagDetail(String flagId) async {
    final result = await context.push(
      '/community/${widget.communityId}/flags/$flagId',
    );
    // Se o moderador tomou uma ação, recarregar a lista
    if (result == true && mounted) {
      _loadFlags();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Flag Center',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: context.nexusTheme.textPrimary,
          ),
        ),
        iconTheme: IconThemeData(color: context.nexusTheme.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadFlags,
            tooltip: 'Atualizar',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: context.nexusTheme.accentPrimary,
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: context.nexusTheme.accentPrimary,
          dividerColor: Colors.white.withValues(alpha: 0.05),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.pendingFlagsCount),
                  if (_pendingFlags.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.nexusTheme.warning,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_pendingFlags.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(text: s.resolved2),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: context.nexusTheme.accentPrimary,
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 48, color: context.nexusTheme.error),
                      const SizedBox(height: 12),
                      Text(
                        'Erro ao carregar denúncias',
                        style: TextStyle(color: context.nexusTheme.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loadFlags,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildFlagList(_pendingFlags, isPending: true),
                    _buildFlagList(_resolvedFlags, isPending: false),
                  ],
                ),
    );
  }

  Widget _buildFlagList(List<Map<String, dynamic>> flags,
      {required bool isPending}) {
    final s = getStrings();
    final r = context.r;
    if (flags.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.check_circle_rounded : Icons.history_rounded,
              size: r.s(64),
              color: Colors.grey[600],
            ),
            SizedBox(height: r.s(16)),
            Text(
              isPending ? s.noPendingReports : s.noResolvedReports,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: r.fs(16),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFlags,
      color: context.nexusTheme.accentPrimary,
      backgroundColor: context.surfaceColor,
      child: ListView.builder(
        padding: EdgeInsets.all(r.s(16)),
        itemCount: flags.length,
        itemBuilder: (context, index) {
          final flag = flags[index];
          return _FlagCard(
            flag: flag,
            isPending: isPending,
            onTap: () => _openFlagDetail(flag['id'] as String),
          );
        },
      ),
    );
  }
}

// ============================================================================
// _FlagCard — Card de denúncia com preview do conteúdo original
// ============================================================================
class _FlagCard extends ConsumerWidget {
  final Map<String, dynamic> flag;
  final bool isPending;
  final VoidCallback onTap;

  const _FlagCard({
    required this.flag,
    required this.isPending,
    required this.onTap,
  });

  Color _flagTypeColor(BuildContext context, String type) {
    switch (type) {
      case 'bullying':              return context.nexusTheme.error;
      case 'art_theft':             return context.nexusTheme.warning;
      case 'inappropriate_content': return Colors.purpleAccent;
      case 'spam':                  return Colors.amber;
      case 'off_topic':             return context.nexusTheme.accentSecondary;
      default:                      return Colors.grey[500] ?? Colors.grey;
    }
  }

  String _flagTypeLabel(BuildContext context, String type) {
    final s = getStrings();
    switch (type) {
      case 'bullying':              return s.bullying;
      case 'art_theft':             return s.artTheft;
      case 'inappropriate_content': return s.inappropriateContent2;
      case 'spam':                  return s.spam;
      case 'off_topic':             return s.offTopic;
      default:                      return s.other;
    }
  }

  String _contentTypeLabel(String type) {
    switch (type) {
      case 'post':         return 'Post';
      case 'comment':      return 'Comentário';
      case 'chat_message': return 'Mensagem';
      case 'wiki':         return 'Wiki';
      case 'story':        return 'Story';
      case 'profile':      return 'Perfil';
      default:             return 'Conteúdo';
    }
  }

  IconData _contentTypeIcon(String type) {
    switch (type) {
      case 'post':         return Icons.article_rounded;
      case 'comment':      return Icons.comment_rounded;
      case 'chat_message': return Icons.chat_bubble_rounded;
      case 'wiki':         return Icons.menu_book_rounded;
      case 'story':        return Icons.auto_stories_rounded;
      case 'profile':      return Icons.person_rounded;
      default:             return Icons.description_rounded;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final r = context.r;

    final type = flag['flag_type'] as String? ?? 'other';
    final reason = flag['reason'] as String? ?? '';
    final reporter = flag['reporter'] as Map<String, dynamic>?;
    final status = flag['status'] as String? ?? 'pending';
    final createdAt = flag['created_at'] as String?;
    final snapshotPreview = flag['snapshot_preview'] as Map<String, dynamic>?;
    final snapshotCaptured = flag['snapshot_captured'] as bool? ?? false;
    final botVerdict = flag['bot_verdict'] as String?;

    final typeColor = _flagTypeColor(context, type);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: r.s(16)),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(r.s(16)),
          border: Border.all(
            color: isPending
                ? typeColor.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.05),
          ),
          boxShadow: isPending
              ? [
                  BoxShadow(
                    color: typeColor.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(r.s(14), r.s(14), r.s(14), r.s(10)),
              child: Row(
                children: [
                  // Badge tipo de flag
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(10), vertical: r.s(4)),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(r.s(12)),
                      border: Border.all(
                          color: typeColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _flagTypeLabel(context, type),
                      style: TextStyle(
                        color: typeColor,
                        fontSize: r.fs(11),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Badge tipo de conteúdo (se há snapshot)
                  if (snapshotPreview != null) ...[
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(8), vertical: r.s(4)),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(r.s(10)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _contentTypeIcon(
                                snapshotPreview['content_type'] as String? ?? ''),
                            size: r.s(11),
                            color: context.nexusTheme.textSecondary,
                          ),
                          SizedBox(width: r.s(4)),
                          Text(
                            _contentTypeLabel(
                                snapshotPreview['content_type'] as String? ?? ''),
                            style: TextStyle(
                              color: context.nexusTheme.textSecondary,
                              fontSize: r.fs(11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Status badge (resolvido)
                  if (!isPending)
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(8), vertical: r.s(4)),
                      decoration: BoxDecoration(
                        color: status == 'approved'
                            ? context.nexusTheme.success.withValues(alpha: 0.15)
                            : context.nexusTheme.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(r.s(10)),
                      ),
                      child: Text(
                        status == 'approved' ? s.approved2 : s.rejected2,
                        style: TextStyle(
                          color: status == 'approved'
                              ? context.nexusTheme.success
                              : context.nexusTheme.error,
                          fontSize: r.fs(11),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  // Seta para ver detalhes
                  SizedBox(width: r.s(6)),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: r.s(18),
                    color: context.nexusTheme.textSecondary,
                  ),
                ],
              ),
            ),

            // ── Preview do conteúdo original (snapshot) ───────────────────
            if (snapshotPreview != null) ...[
              Container(
                margin: EdgeInsets.symmetric(horizontal: r.s(14)),
                padding: EdgeInsets.all(r.s(12)),
                decoration: BoxDecoration(
                  color: context.nexusTheme.backgroundPrimary.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(r.s(10)),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Autor do conteúdo denunciado
                    if ((snapshotPreview['author_nickname'] as String?)
                            ?.isNotEmpty ==
                        true) ...[
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded,
                              size: r.s(12),
                              color: context.nexusTheme.textSecondary),
                          SizedBox(width: r.s(4)),
                          Text(
                            snapshotPreview['author_nickname'] as String,
                            style: TextStyle(
                              color: context.nexusTheme.textSecondary,
                              fontSize: r.fs(11),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: r.s(6)),
                    ],
                    // Preview do texto
                    if ((snapshotPreview['preview'] as String?)
                            ?.isNotEmpty ==
                        true)
                      Text(
                        snapshotPreview['preview'] as String,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.nexusTheme.textPrimary,
                          fontSize: r.fs(13),
                          height: 1.4,
                        ),
                      )
                    else
                      Row(
                        children: [
                          Icon(Icons.image_rounded,
                              size: r.s(14),
                              color: context.nexusTheme.textSecondary),
                          SizedBox(width: r.s(6)),
                          Text(
                            'Conteúdo de mídia',
                            style: TextStyle(
                              color: context.nexusTheme.textSecondary,
                              fontSize: r.fs(12),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    // Indicador de mídia
                    if (snapshotPreview['has_media'] == true &&
                        (snapshotPreview['preview'] as String?)
                                ?.isNotEmpty ==
                            true) ...[
                      SizedBox(height: r.s(4)),
                      Row(
                        children: [
                          Icon(Icons.attach_file_rounded,
                              size: r.s(11),
                              color: context.nexusTheme.textSecondary),
                          SizedBox(width: r.s(3)),
                          Text(
                            'Contém mídia',
                            style: TextStyle(
                              color: context.nexusTheme.textSecondary,
                              fontSize: r.fs(10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: r.s(10)),
            ] else if (!snapshotCaptured) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.s(14)),
                child: Container(
                  padding: EdgeInsets.all(r.s(10)),
                  decoration: BoxDecoration(
                    color: context.nexusTheme.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(r.s(8)),
                    border: Border.all(
                      color: context.nexusTheme.warning.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: r.s(14),
                          color: context.nexusTheme.warning),
                      SizedBox(width: r.s(6)),
                      Expanded(
                        child: Text(
                          'Snapshot não capturado — conteúdo pode ter sido excluído',
                          style: TextStyle(
                            color: context.nexusTheme.warning,
                            fontSize: r.fs(11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: r.s(10)),
            ],

            // ── Reporter + motivo ─────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(r.s(14), 0, r.s(14), r.s(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CosmeticAvatar(
                        userId: reporter?['id'] as String?,
                        avatarUrl: reporter?['avatar'] as String?,
                        size: r.s(28),
                      ),
                      SizedBox(width: r.s(8)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reportado por: ${reporter?['nickname'] ?? 'Anônimo'}',
                              style: TextStyle(
                                color: context.nexusTheme.textSecondary,
                                fontSize: r.fs(12),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _formatDate(createdAt),
                              style: TextStyle(
                                color: context.nexusTheme.textSecondary
                                    .withValues(alpha: 0.6),
                                fontSize: r.fs(10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Bot verdict badge
                      if (botVerdict != null && botVerdict.isNotEmpty)
                        _BotVerdictBadge(verdict: botVerdict),
                    ],
                  ),
                  if (reason.isNotEmpty) ...[
                    SizedBox(height: r.s(8)),
                    Text(
                      '"$reason"',
                      style: TextStyle(
                        color: context.nexusTheme.textSecondary,
                        fontSize: r.fs(12),
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // Botão "Ver detalhes completos"
                  SizedBox(height: r.s(12)),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onTap,
                      icon: Icon(Icons.visibility_rounded, size: r.s(16)),
                      label: Text(
                        'Ver conteúdo original e tomar ação',
                        style: TextStyle(fontSize: r.fs(13)),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: typeColor,
                        side: BorderSide(color: typeColor.withValues(alpha: 0.4)),
                        padding: EdgeInsets.symmetric(vertical: r.s(10)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.s(10)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// _BotVerdictBadge — Badge compacto com o veredito do bot
// ============================================================================
class _BotVerdictBadge extends StatelessWidget {
  final String verdict;
  const _BotVerdictBadge({required this.verdict});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;
    switch (verdict) {
      case 'clean':
        color = context.nexusTheme.success;
        label = 'Limpo';
        icon = Icons.check_circle_rounded;
        break;
      case 'suspicious':
        color = context.nexusTheme.warning;
        label = 'Suspeito';
        icon = Icons.warning_rounded;
        break;
      case 'auto_removed':
        color = context.nexusTheme.error;
        label = 'Auto-removido';
        icon = Icons.block_rounded;
        break;
      case 'escalated':
        color = Colors.purpleAccent;
        label = 'Escalado';
        icon = Icons.escalator_warning_rounded;
        break;
      default:
        color = Colors.grey[500] ?? Colors.grey;
        label = 'Bot';
        icon = Icons.smart_toy_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
