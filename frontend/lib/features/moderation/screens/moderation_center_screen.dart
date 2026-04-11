import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/widgets/cosmetic_avatar.dart';

// ============================================================================
// MODERATION CENTER SCREEN
// Painel completo de moderação para staff (leader/curator/moderator/agent).
// Funcionalidades:
// • Lista de denúncias com filtros (pendente / resolvido / auto-removido)
// • Preview do snapshot de conteúdo diretamente na lista
// • Indicador de análise do bot (score + verdict)
// • Estatísticas do bot (total, auto-removidos, pendentes)
// • Acesso ao detalhe completo de cada denúncia
// ============================================================================
class ModerationCenterScreen extends ConsumerStatefulWidget {
  final String communityId;
  const ModerationCenterScreen({super.key, required this.communityId});

  @override
  ConsumerState<ModerationCenterScreen> createState() =>
      _ModerationCenterScreenState();
}

class _ModerationCenterScreenState
    extends ConsumerState<ModerationCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _flags = [];
  Map<String, dynamic>? _botStats;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _currentFilter = 'pending';
  int _offset = 0;
  int _total = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final filters = ['pending', 'approved', 'all'];
        _currentFilter = filters[_tabController.index];
        _reload();
      }
    });
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadFlags(), _loadBotStats()]);
  }

  Future<void> _reload() async {
    setState(() {
      _flags = [];
      _offset = 0;
      _isLoading = true;
    });
    await _loadFlags();
  }

  Future<void> _loadFlags() async {
    try {
      final result = await SupabaseService.rpc('get_community_flags', params: {
        'p_community_id': widget.communityId,
        'p_status':       _currentFilter,
        'p_limit':        _pageSize,
        'p_offset':       _offset,
      });
      final data = result as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          _flags = List<Map<String, dynamic>>.from(
              (data?['flags'] as List?) ?? []);
          _total = data?['total'] as int? ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _flags.length >= _total) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await SupabaseService.rpc('get_community_flags', params: {
        'p_community_id': widget.communityId,
        'p_status':       _currentFilter,
        'p_limit':        _pageSize,
        'p_offset':       _flags.length,
      });
      final data = result as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          _flags.addAll(List<Map<String, dynamic>>.from(
              (data?['flags'] as List?) ?? []));
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadBotStats() async {
    try {
      final result = await SupabaseService.rpc('get_bot_stats', params: {
        'p_community_id': widget.communityId,
        'p_days':         30,
      });
      if (mounted) {
        setState(() => _botStats = result as Map<String, dynamic>?);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        title: const Text('Central de Moderação'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.errorColor,
          labelColor: AppTheme.errorColor,
          unselectedLabelColor: context.textSecondary,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Pendentes'),
                  if (_currentFilter == 'pending' && _total > 0) ...[
                    SizedBox(width: r.s(6)),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(6), vertical: r.s(2)),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor,
                        borderRadius: BorderRadius.circular(r.s(8)),
                      ),
                      child: Text(
                        '$_total',
                        style: TextStyle(
                            color: Colors.white, fontSize: r.fs(10)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Resolvidas'),
            const Tab(text: 'Todas'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Stats do bot ──
          if (_botStats != null) _BotStatsBar(stats: _botStats!),

          // ── Lista de flags ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _flags.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _reload,
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (n) {
                            if (n is ScrollEndNotification &&
                                n.metrics.pixels >=
                                    n.metrics.maxScrollExtent - 200) {
                              _loadMore();
                            }
                            return false;
                          },
                          child: ListView.separated(
                            padding: EdgeInsets.all(r.s(12)),
                            itemCount:
                                _flags.length + (_isLoadingMore ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                SizedBox(height: r.s(8)),
                            itemBuilder: (ctx, i) {
                              if (i == _flags.length) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                              return _FlagCard(
                                flag: _flags[i],
                                onTap: () async {
                                  final refresh = await context.push<bool>(
                                    '/community/${widget.communityId}/flags/${_flags[i]['id']}',
                                  );
                                  if (refresh == true) _reload();
                                },
                                onQuickReject: () async {
                                  await SupabaseService.rpc('resolve_flag',
                                      params: {
                                        'p_flag_id': _flags[i]['id'],
                                        'p_action':  'rejected',
                                      });
                                  _reload();
                                },
                              );
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final r = context.r;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded,
              size: r.s(52),
              color: AppTheme.successColor.withValues(alpha: 0.5)),
          SizedBox(height: r.s(12)),
          Text(
            _currentFilter == 'pending'
                ? 'Nenhuma denúncia pendente'
                : 'Nenhuma denúncia encontrada',
            style: TextStyle(
              color: context.textSecondary,
              fontSize: r.fs(15),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: r.s(6)),
          Text(
            'A comunidade está segura!',
            style: TextStyle(
              color: context.textSecondary.withValues(alpha: 0.6),
              fontSize: r.fs(13),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BOT STATS BAR
// ============================================================================
class _BotStatsBar extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _BotStatsBar({required this.stats});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final total       = stats['total_flags']   as int? ?? 0;
    final pending     = stats['pending_flags'] as int? ?? 0;
    final analyzed    = stats['bot_analyzed']  as int? ?? 0;
    final autoActioned = stats['auto_actioned'] as int? ?? 0;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: r.s(16), vertical: r.s(10)),
      decoration: BoxDecoration(
        color: context.cardBg,
        border: Border(
          bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.smart_toy_rounded,
              size: r.s(16),
              color: AppTheme.primaryColor),
          SizedBox(width: r.s(6)),
          Text(
            'Bot (30 dias):',
            style: TextStyle(
              color: context.textSecondary,
              fontSize: r.fs(12),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: r.s(12)),
          _StatChip(
              label: 'Total', value: total, color: context.textSecondary),
          SizedBox(width: r.s(8)),
          _StatChip(
              label: 'Pendentes',
              value: pending,
              color: AppTheme.warningColor),
          SizedBox(width: r.s(8)),
          _StatChip(
              label: 'Analisados',
              value: analyzed,
              color: AppTheme.primaryColor),
          SizedBox(width: r.s(8)),
          _StatChip(
              label: 'Auto-removidos',
              value: autoActioned,
              color: AppTheme.errorColor),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: r.s(8), vertical: r.s(3)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(r.s(6)),
      ),
      child: Text(
        '$value $label',
        style: TextStyle(
          color: color,
          fontSize: r.fs(10),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ============================================================================
// FLAG CARD — item da lista
// ============================================================================
class _FlagCard extends StatelessWidget {
  final Map<String, dynamic> flag;
  final VoidCallback onTap;
  final VoidCallback onQuickReject;
  const _FlagCard({
    required this.flag,
    required this.onTap,
    required this.onQuickReject,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final flagType    = flag['flag_type']    as String? ?? '';
    final status      = flag['status']       as String? ?? 'pending';
    final botVerdict  = flag['bot_verdict']  as String?;
    final botScore    = flag['bot_score']    as num?;
    final autoActioned = flag['auto_actioned'] as bool? ?? false;
    final reporter    = flag['reporter']     as Map<String, dynamic>?;
    final snapshotPreview = flag['snapshot_preview'] as Map<String, dynamic>?;
    final preview     = snapshotPreview?['preview'] as String?;
    final createdAt   = flag['created_at']   as String?;

    final isPending = status == 'pending';

    // Cor do tipo de denúncia
    Color typeColor = _flagTypeColor(flagType);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(r.s(12)),
          border: Border.all(
            color: autoActioned
                ? AppTheme.errorColor.withValues(alpha: 0.3)
                : isPending
                    ? AppTheme.warningColor.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: EdgeInsets.fromLTRB(
                  r.s(12), r.s(10), r.s(12), r.s(8)),
              child: Row(
                children: [
                  // Tipo de denúncia
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(8), vertical: r.s(3)),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(r.s(6)),
                      border: Border.all(
                          color: typeColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _flagTypeLabel(flagType),
                      style: TextStyle(
                        color: typeColor,
                        fontSize: r.fs(11),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: r.s(8)),

                  // Bot verdict badge
                  if (botVerdict != null)
                    _BotBadge(verdict: botVerdict, score: botScore),

                  // Auto-actioned badge
                  if (autoActioned) ...[
                    SizedBox(width: r.s(6)),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(6), vertical: r.s(3)),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(r.s(6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.smart_toy_rounded,
                              size: r.s(10),
                              color: AppTheme.errorColor),
                          SizedBox(width: r.s(3)),
                          Text(
                            'Auto-removido',
                            style: TextStyle(
                              color: AppTheme.errorColor,
                              fontSize: r.fs(10),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Spacer(),
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: r.fs(10),
                    ),
                  ),
                ],
              ),
            ),

            // ── Preview do conteúdo ──
            if (preview?.isNotEmpty == true) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: r.s(12)),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(r.s(10)),
                  decoration: BoxDecoration(
                    color: context.scaffoldBg.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(r.s(8)),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Text(
                    preview!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: r.fs(13),
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
              SizedBox(height: r.s(8)),
            ],

            // ── Footer: reporter + ações rápidas ──
            Padding(
              padding: EdgeInsets.fromLTRB(
                  r.s(12), r.s(0), r.s(12), r.s(10)),
              child: Row(
                children: [
                  if (reporter != null) ...[
                    CosmeticAvatar(
                      userId: reporter['id'] as String?,
                      avatarUrl: reporter['avatar'] as String?,
                      size: r.s(22),
                    ),
                    SizedBox(width: r.s(6)),
                    Text(
                      reporter['nickname'] as String? ?? 'Anônimo',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: r.fs(11),
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Ações rápidas (apenas pendentes)
                  if (isPending && !autoActioned) ...[
                    GestureDetector(
                      onTap: onQuickReject,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.s(10), vertical: r.s(5)),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(r.s(6)),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Text(
                          'Rejeitar',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: r.fs(11),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: r.s(6)),
                    GestureDetector(
                      onTap: onTap,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.s(10), vertical: r.s(5)),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(r.s(6)),
                          border: Border.all(
                              color: AppTheme.errorColor
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'Ver detalhes',
                          style: TextStyle(
                            color: AppTheme.errorColor,
                            fontSize: r.fs(11),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    GestureDetector(
                      onTap: onTap,
                      child: Text(
                        'Ver detalhes →',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: r.fs(11),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _flagTypeColor(String type) {
    const colors = {
      'spam':           0xFFFF9800,
      'hate_speech':    0xFFE53935,
      'harassment':     0xFFE53935,
      'art_theft':      0xFF9C27B0,
      'nsfw':           0xFFE91E63,
      'misinformation': 0xFFFF5722,
      'other':          0xFF607D8B,
    };
    return Color(colors[type] ?? 0xFF607D8B);
  }

  String _flagTypeLabel(String type) {
    const labels = {
      'spam':           'Spam',
      'hate_speech':    'Ódio',
      'harassment':     'Assédio',
      'art_theft':      'Roubo de Arte',
      'nsfw':           'NSFW',
      'misinformation': 'Desinformação',
      'other':          'Outro',
    };
    return labels[type] ?? type;
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _BotBadge extends StatelessWidget {
  final String verdict;
  final num? score;
  const _BotBadge({required this.verdict, this.score});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    Color color;
    IconData icon;
    switch (verdict) {
      case 'clean':
        color = AppTheme.successColor;
        icon = Icons.check_circle_rounded;
        break;
      case 'suspicious':
        color = AppTheme.warningColor;
        icon = Icons.warning_rounded;
        break;
      case 'auto_removed':
        color = AppTheme.errorColor;
        icon = Icons.remove_circle_rounded;
        break;
      default:
        color = AppTheme.primaryColor;
        icon = Icons.info_rounded;
    }

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: r.s(6), vertical: r.s(3)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(r.s(6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.smart_toy_rounded, size: r.s(10), color: color),
          SizedBox(width: r.s(3)),
          Icon(icon, size: r.s(10), color: color),
          if (score != null) ...[
            SizedBox(width: r.s(3)),
            Text(
              '${(score! * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: color,
                fontSize: r.fs(10),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
