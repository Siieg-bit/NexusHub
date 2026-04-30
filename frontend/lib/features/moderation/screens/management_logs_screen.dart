import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final _logsFilterProvider = StateProvider.autoDispose<String>((ref) => 'all');

final managementLogsStatsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, communityId) async {
    final result = await SupabaseService.rpc('get_management_logs_stats',
        params: {'p_community_id': communityId});
    return Map<String, dynamic>.from(result as Map? ?? {});
  },
);

final managementLogsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, (String, String)>(
  (ref, args) async {
    final (communityId, filter) = args;
    final result = await SupabaseService.rpc('get_management_logs', params: {
      'p_community_id': communityId,
      'p_action_filter': filter,
      'p_limit': 50,
      'p_offset': 0,
    });
    return List<Map<String, dynamic>>.from(
      (result as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// Tela principal
// ─────────────────────────────────────────────────────────────────────────────

/// Logs de Moderação — histórico de ações de moderação de uma comunidade.
/// Acessível apenas por staff (leader, curator, agent, moderator, admin).
class ManagementLogsScreen extends ConsumerWidget {
  final String communityId;

  const ManagementLogsScreen({super.key, required this.communityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final theme = context.nexusTheme;
    final filter = ref.watch(_logsFilterProvider);
    final statsAsync = ref.watch(managementLogsStatsProvider(communityId));
    final logsAsync = ref.watch(managementLogsProvider((communityId, filter)));

    return Scaffold(
      backgroundColor: theme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: theme.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          s.managementLogsTitle,
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: r.fs(18),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: theme.textSecondary),
            onPressed: () {
              ref.invalidate(managementLogsStatsProvider(communityId));
              ref.invalidate(
                  managementLogsProvider((communityId, filter)));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats
          statsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (stats) => _StatsRow(stats: stats, r: r, theme: theme, s: s),
          ),

          // Filtros
          _FilterChips(r: r, theme: theme, s: s),

          // Lista
          Expanded(
            child: logsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: theme.error, size: r.s(48)),
                    SizedBox(height: r.s(12)),
                    Text(
                      e.toString().contains('insufficient_permissions')
                          ? s.insufficientPermissions
                          : s.anErrorOccurredTryAgain,
                      style: TextStyle(
                          color: theme.textSecondary, fontSize: r.fs(14)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              data: (logs) => logs.isEmpty
                  ? _buildEmpty(context, r, theme, s)
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(16), vertical: r.s(8)),
                      itemCount: logs.length,
                      itemBuilder: (ctx, i) => _LogEntry(
                        log: logs[i],
                        communityId: communityId,
                        r: r,
                        theme: theme,
                        s: s,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, Responsive r,
      NexusThemeExtension theme, dynamic s) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded,
              color: theme.textSecondary, size: r.s(48)),
          SizedBox(height: r.s(12)),
          Text(
            s.managementLogsEmpty,
            style: TextStyle(
                color: theme.textSecondary, fontSize: r.fs(14)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats Row
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final Map<String, dynamic> stats;
  final Responsive r;
  final NexusThemeExtension theme;
  final dynamic s;

  const _StatsRow(
      {required this.stats,
      required this.r,
      required this.theme,
      required this.s});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.gavel_rounded,
        const Color(0xFF9C27B0),
        s.managementLogsTotalActions,
        '${stats['total_actions'] ?? 0}'
      ),
      (
        Icons.block_rounded,
        const Color(0xFFF44336),
        s.managementLogsBans,
        '${stats['bans'] ?? 0}'
      ),
      (
        Icons.flag_rounded,
        const Color(0xFFFF9800),
        s.managementLogsPendingFlags,
        '${stats['pending_flags'] ?? 0}'
      ),
      (
        Icons.gavel_rounded,
        const Color(0xFF2196F3),
        s.managementLogsPendingAppeals,
        '${stats['pending_appeals'] ?? 0}'
      ),
    ];

    return Container(
      margin: EdgeInsets.fromLTRB(r.s(16), r.s(8), r.s(16), 0),
      padding: EdgeInsets.all(r.s(12)),
      decoration: BoxDecoration(
        color: theme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(14)),
      ),
      child: Row(
        children: items
            .map((item) => Expanded(
                  child: Column(
                    children: [
                      Icon(item.$1, color: item.$2, size: r.s(20)),
                      SizedBox(height: r.s(4)),
                      Text(
                        item.$4,
                        style: TextStyle(
                          fontSize: r.fs(16),
                          fontWeight: FontWeight.w800,
                          color: theme.textPrimary,
                        ),
                      ),
                      Text(
                        item.$3,
                        style: TextStyle(
                            fontSize: r.fs(10), color: theme.textSecondary),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter Chips
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChips extends ConsumerWidget {
  final Responsive r;
  final NexusThemeExtension theme;
  final dynamic s;

  const _FilterChips(
      {required this.r, required this.theme, required this.s});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(_logsFilterProvider);
    final filters = [
      ('all', s.filterAll),
      ('ban', s.filterBan),
      ('warn', s.filterWarn),
      ('delete_post', s.filterDeletePost),
      ('mute', s.filterMute),
      ('unban', s.filterUnban),
    ];

    return SizedBox(
      height: r.s(44),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(6)),
        itemCount: filters.length,
        itemBuilder: (ctx, i) {
          final (value, label) = filters[i];
          final isSelected = current == value;
          return GestureDetector(
            onTap: () =>
                ref.read(_logsFilterProvider.notifier).state = value,
            child: Container(
              margin: EdgeInsets.only(right: r.s(8)),
              padding: EdgeInsets.symmetric(
                  horizontal: r.s(12), vertical: r.s(4)),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.accentPrimary
                    : theme.surfacePrimary,
                borderRadius: BorderRadius.circular(r.s(20)),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: r.fs(12),
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.white : theme.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Log Entry
// ─────────────────────────────────────────────────────────────────────────────

class _LogEntry extends StatefulWidget {
  final Map<String, dynamic> log;
  final String communityId;
  final Responsive r;
  final NexusThemeExtension theme;
  final dynamic s;

  const _LogEntry({
    required this.log,
    required this.communityId,
    required this.r,
    required this.theme,
    required this.s,
  });

  @override
  State<_LogEntry> createState() => _LogEntryState();
}

class _LogEntryState extends State<_LogEntry> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final r = widget.r;
    final theme = widget.theme;
    final s = widget.s;

    final action = log['action'] as String? ?? 'unknown';
    final severity = log['severity'] as String? ?? 'low';
    final actorName = log['actor_name'] as String? ?? s.unknownUser;
    final actorIcon = log['actor_icon'] as String?;
    final actorId = log['actor_id'] as String?;
    final targetName = log['target_user_name'] as String?;
    final targetId = log['target_user_id'] as String?;
    final reason = log['reason'] as String?;
    final isAutomated = log['is_automated'] as bool? ?? false;
    final createdAt = log['created_at'] != null
        ? DateTime.tryParse(log['created_at'] as String)
        : null;
    final durationHours = log['duration_hours'] as int?;
    final expiresAt = log['expires_at'] != null
        ? DateTime.tryParse(log['expires_at'] as String)
        : null;

    final (actionColor, actionIcon, actionLabel) =
        _actionInfo(action, s);
    final severityColor = switch (severity) {
      'critical' => const Color(0xFFF44336),
      'high' => const Color(0xFFFF5722),
      'medium' => const Color(0xFFFF9800),
      _ => const Color(0xFF4CAF50),
    };

    return Container(
      margin: EdgeInsets.only(bottom: r.s(8)),
      decoration: BoxDecoration(
        color: theme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(14)),
        border: Border(
          left: BorderSide(color: severityColor, width: 3),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(r.s(14)),
            child: Padding(
              padding: EdgeInsets.all(r.s(12)),
              child: Row(
                children: [
                  // Avatar do ator
                  CosmeticAvatar(
                    userId: actorId ?? '',
                    avatarUrl: actorIcon,
                    size: r.s(36),
                    onTap: actorId != null
                        ? () => context.push(
                            '/community/${widget.communityId}/profile/$actorId')
                        : null,
                  ),
                  SizedBox(width: r.s(10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Badge de ação
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: r.s(8), vertical: r.s(2)),
                              decoration: BoxDecoration(
                                color: actionColor.withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(r.s(20)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(actionIcon,
                                      color: actionColor, size: r.s(12)),
                                  SizedBox(width: r.s(4)),
                                  Text(
                                    actionLabel,
                                    style: TextStyle(
                                      color: actionColor,
                                      fontSize: r.fs(11),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isAutomated) ...[
                              SizedBox(width: r.s(4)),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: r.s(6), vertical: r.s(2)),
                                decoration: BoxDecoration(
                                  color: theme.textSecondary
                                      .withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(r.s(20)),
                                ),
                                child: Text(
                                  s.logAutomated,
                                  style: TextStyle(
                                    color: theme.textSecondary,
                                    fontSize: r.fs(10),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: r.s(3)),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                                fontSize: r.fs(13),
                                color: theme.textPrimary),
                            children: [
                              TextSpan(
                                text: actorName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              if (targetName != null) ...[
                                TextSpan(
                                  text: ' → ',
                                  style: TextStyle(
                                      color: theme.textSecondary),
                                ),
                                TextSpan(
                                  text: targetName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (createdAt != null)
                          Text(
                            timeago.format(createdAt, locale: 'pt_BR'),
                            style: TextStyle(
                                fontSize: r.fs(11),
                                color: theme.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: theme.textSecondary,
                    size: r.s(18),
                  ),
                ],
              ),
            ),
          ),

          // Detalhes expandidos
          if (_expanded) ...[
            Divider(height: 1, color: theme.divider),
            Padding(
              padding: EdgeInsets.all(r.s(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (reason != null && reason.isNotEmpty) ...[
                    _DetailRow(
                      label: s.logReason,
                      value: reason,
                      theme: theme,
                      r: r,
                    ),
                    SizedBox(height: r.s(8)),
                  ],
                  if (durationHours != null) ...[
                    _DetailRow(
                      label: s.logDuration,
                      value: durationHours >= 8760
                          ? s.logDurationPermanent
                          : '$durationHours ${s.logDurationHours}',
                      theme: theme,
                      r: r,
                    ),
                    SizedBox(height: r.s(8)),
                  ],
                  if (expiresAt != null) ...[
                    _DetailRow(
                      label: s.logExpiresAt,
                      value: timeago.format(expiresAt, locale: 'pt_BR'),
                      theme: theme,
                      r: r,
                    ),
                    SizedBox(height: r.s(8)),
                  ],
                  // Links para conteúdo alvo
                  if (log['target_post_id'] != null)
                    _ContentLink(
                      label: s.logTargetPost,
                      icon: Icons.article_rounded,
                      onTap: () => context.push(
                          '/post/${log['target_post_id']}'),
                      theme: theme,
                      r: r,
                    ),
                  if (log['target_user_id'] != null)
                    _ContentLink(
                      label: targetName ?? s.logTargetUser,
                      icon: Icons.person_rounded,
                      onTap: () => context.push(
                          '/community/${widget.communityId}/profile/${log['target_user_id']}'),
                      theme: theme,
                      r: r,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  (Color, IconData, String) _actionInfo(String action, dynamic s) {
    return switch (action) {
      'ban' => (const Color(0xFFF44336), Icons.block_rounded, s.actionBan),
      'unban' => (const Color(0xFF4CAF50), Icons.check_circle_rounded, s.actionUnban),
      'warn' => (const Color(0xFFFF9800), Icons.warning_rounded, s.actionWarn),
      'mute' => (const Color(0xFF9C27B0), Icons.volume_off_rounded, s.actionMute),
      'unmute' => (const Color(0xFF4CAF50), Icons.volume_up_rounded, s.actionUnmute),
      'delete_post' => (const Color(0xFFE91E63), Icons.delete_rounded, s.actionDeletePost),
      'delete_content' => (const Color(0xFFE91E63), Icons.delete_sweep_rounded, s.actionDeleteContent),
      'pin_post' => (const Color(0xFF2196F3), Icons.push_pin_rounded, s.actionPinPost),
      'unpin_post' => (const Color(0xFF9E9E9E), Icons.push_pin_outlined, s.actionUnpinPost),
      'approve_flag' => (const Color(0xFF4CAF50), Icons.flag_rounded, s.actionApproveFlag),
      'dismiss_flag' => (const Color(0xFF9E9E9E), Icons.flag_outlined, s.actionDismissFlag),
      'accept_appeal' => (const Color(0xFF4CAF50), Icons.gavel_rounded, s.actionAcceptAppeal),
      'reject_appeal' => (const Color(0xFFF44336), Icons.gavel_rounded, s.actionRejectAppeal),
      _ => (const Color(0xFF9E9E9E), Icons.info_rounded, action),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final NexusThemeExtension theme;
  final Responsive r;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.theme,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: r.s(80),
          child: Text(
            label,
            style: TextStyle(
              fontSize: r.fs(11),
              fontWeight: FontWeight.w600,
              color: theme.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
                fontSize: r.fs(12), color: theme.textPrimary, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _ContentLink extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final NexusThemeExtension theme;
  final Responsive r;

  const _ContentLink({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.theme,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: r.s(6)),
        padding: EdgeInsets.symmetric(
            horizontal: r.s(10), vertical: r.s(6)),
        decoration: BoxDecoration(
          color: theme.accentPrimary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(r.s(8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: theme.accentPrimary, size: r.s(14)),
            SizedBox(width: r.s(6)),
            Text(
              label,
              style: TextStyle(
                color: theme.accentPrimary,
                fontSize: r.fs(12),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: r.s(4)),
            Icon(Icons.open_in_new_rounded,
                color: theme.accentPrimary, size: r.s(12)),
          ],
        ),
      ),
    );
  }
}
