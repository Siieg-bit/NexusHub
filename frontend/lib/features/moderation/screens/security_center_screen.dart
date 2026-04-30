import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final securityOverviewProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) async {
    final result = await SupabaseService.rpc('get_security_overview');
    return Map<String, dynamic>.from(result as Map? ?? {});
  },
);

final securityEventsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) async {
    final result = await SupabaseService.rpc('get_security_events',
        params: {'p_limit': 20, 'p_offset': 0});
    return List<Map<String, dynamic>>.from(
      (result as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// Tela principal
// ─────────────────────────────────────────────────────────────────────────────

/// Centro de Segurança — hub de configurações e eventos de segurança da conta.
class SecurityCenterScreen extends ConsumerStatefulWidget {
  const SecurityCenterScreen({super.key});

  @override
  ConsumerState<SecurityCenterScreen> createState() =>
      _SecurityCenterScreenState();
}

class _SecurityCenterScreenState extends ConsumerState<SecurityCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final theme = context.nexusTheme;

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
          s.securityCenterTitle,
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
              ref.invalidate(securityOverviewProvider);
              ref.invalidate(securityEventsProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.accentPrimary,
          unselectedLabelColor: theme.textSecondary,
          indicatorColor: theme.accentPrimary,
          labelStyle: TextStyle(
              fontSize: r.fs(13), fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: s.securityTabOverview),
            Tab(text: s.securityTabSessions),
            Tab(text: s.securityTabActivity),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(),
          _SessionsTab(),
          _ActivityTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Visão Geral
// ─────────────────────────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final theme = context.nexusTheme;
    final overviewAsync = ref.watch(securityOverviewProvider);

    return overviewAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: theme.error, size: r.s(48)),
            SizedBox(height: r.s(12)),
            Text(s.anErrorOccurredTryAgain,
                style: TextStyle(color: theme.textSecondary, fontSize: r.fs(14))),
          ],
        ),
      ),
      data: (overview) {
        final securityLevel = (overview['security_level'] as num?)?.toInt() ?? 0;
        final has2fa = overview['has_2fa'] as bool? ?? false;

        return ListView(
          padding: EdgeInsets.all(r.s(16)),
          children: [
            // Score de segurança
            _SecurityScoreCard(
              level: securityLevel,
              has2fa: has2fa,
              r: r,
              theme: theme,
              s: s,
            ),
            SizedBox(height: r.s(16)),

            // Configurações de segurança
            Text(
              s.securitySettings,
              style: TextStyle(
                fontSize: r.fs(13),
                fontWeight: FontWeight.w700,
                color: theme.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: r.s(10)),
            _SecuritySettingTile(
              icon: Icons.email_rounded,
              title: s.securityEmailVerification,
              subtitle: has2fa ? s.securityEmailVerified : s.securityEmailNotVerified,
              trailing: has2fa
                  ? Icon(Icons.check_circle_rounded,
                      color: theme.success, size: r.s(20))
                  : Icon(Icons.warning_rounded,
                      color: theme.error, size: r.s(20)),
              theme: theme,
              r: r,
            ),
            _SecuritySettingTile(
              icon: Icons.lock_rounded,
              title: s.securityChangePassword,
              subtitle: s.securityChangePasswordSubtitle,
              trailing: Icon(Icons.chevron_right_rounded,
                  color: theme.textSecondary, size: r.s(20)),
              theme: theme,
              r: r,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(s.featureComingSoon)),
                );
              },
            ),
            _SecuritySettingTile(
              icon: Icons.devices_rounded,
              title: s.securityActiveSessions,
              subtitle: s.securityActiveSessionsSubtitle,
              trailing: Icon(Icons.chevron_right_rounded,
                  color: theme.textSecondary, size: r.s(20)),
              theme: theme,
              r: r,
              onTap: () {
                // Navega para a aba de sessões
                final tabCtrl = context
                    .findAncestorStateOfType<_SecurityCenterScreenState>()
                    ?._tabController;
                tabCtrl?.animateTo(1);
              },
            ),
            _SecuritySettingTile(
              icon: Icons.history_rounded,
              title: s.securityActivityLog,
              subtitle: s.securityActivityLogSubtitle,
              trailing: Icon(Icons.chevron_right_rounded,
                  color: theme.textSecondary, size: r.s(20)),
              theme: theme,
              r: r,
              onTap: () {
                final tabCtrl = context
                    .findAncestorStateOfType<_SecurityCenterScreenState>()
                    ?._tabController;
                tabCtrl?.animateTo(2);
              },
            ),
            SizedBox(height: r.s(16)),

            // Dicas de segurança
            _SecurityTipsCard(r: r, theme: theme, s: s),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Sessões Ativas
// ─────────────────────────────────────────────────────────────────────────────

class _SessionsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final theme = context.nexusTheme;
    final overviewAsync = ref.watch(securityOverviewProvider);

    return overviewAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(s.anErrorOccurredTryAgain,
            style: TextStyle(color: theme.textSecondary)),
      ),
      data: (overview) {
        final sessions = List<Map<String, dynamic>>.from(
          ((overview['active_sessions'] as List?) ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map)),
        );

        if (sessions.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.devices_rounded,
                    color: theme.textSecondary, size: r.s(48)),
                SizedBox(height: r.s(12)),
                Text(s.securityNoSessions,
                    style: TextStyle(
                        color: theme.textSecondary, fontSize: r.fs(14))),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(r.s(16)),
          itemCount: sessions.length,
          itemBuilder: (ctx, i) {
            final session = sessions[i];
            final isCurrent = session['is_current'] as bool? ?? false;
            final deviceName = session['device_name'] as String? ?? s.unknownDevice;
            final deviceType = session['device_type'] as String? ?? 'unknown';
            final ip = session['ip_address'] as String?;
            final location = session['location'] as String?;
            final lastActive = session['last_active'] != null
                ? DateTime.tryParse(session['last_active'] as String)
                : null;

            final deviceIcon = switch (deviceType) {
              'mobile' => Icons.smartphone_rounded,
              'tablet' => Icons.tablet_rounded,
              'desktop' => Icons.computer_rounded,
              _ => Icons.devices_rounded,
            };

            return Container(
              margin: EdgeInsets.only(bottom: r.s(10)),
              padding: EdgeInsets.all(r.s(14)),
              decoration: BoxDecoration(
                color: theme.surfacePrimary,
                borderRadius: BorderRadius.circular(r.s(14)),
                border: isCurrent
                    ? Border.all(
                        color: theme.accentPrimary.withValues(alpha: 0.4))
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: r.s(44),
                    height: r.s(44),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? theme.accentPrimary.withValues(alpha: 0.12)
                          : theme.surfaceSecondary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(deviceIcon,
                        color: isCurrent
                            ? theme.accentPrimary
                            : theme.textSecondary,
                        size: r.s(22)),
                  ),
                  SizedBox(width: r.s(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                deviceName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: r.fs(14),
                                  color: theme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCurrent)
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: r.s(8), vertical: r.s(2)),
                                decoration: BoxDecoration(
                                  color: theme.accentPrimary
                                      .withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(r.s(20)),
                                ),
                                child: Text(
                                  s.securityCurrentSession,
                                  style: TextStyle(
                                    color: theme.accentPrimary,
                                    fontSize: r.fs(10),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (ip != null || location != null)
                          Text(
                            [if (location != null) location, if (ip != null) ip]
                                .join(' · '),
                            style: TextStyle(
                                fontSize: r.fs(12),
                                color: theme.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (lastActive != null)
                          Text(
                            timeago.format(lastActive, locale: 'pt_BR'),
                            style: TextStyle(
                                fontSize: r.fs(11),
                                color: theme.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  if (!isCurrent) ...[
                    SizedBox(width: r.s(8)),
                    _RevokeButton(
                      sessionId: session['id'] as String,
                      r: r,
                      theme: theme,
                      s: s,
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Atividade de Segurança
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final theme = context.nexusTheme;
    final eventsAsync = ref.watch(securityEventsProvider);

    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(s.anErrorOccurredTryAgain,
            style: TextStyle(color: theme.textSecondary)),
      ),
      data: (events) {
        if (events.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_rounded,
                    color: theme.textSecondary, size: r.s(48)),
                SizedBox(height: r.s(12)),
                Text(s.securityNoActivity,
                    style: TextStyle(
                        color: theme.textSecondary, fontSize: r.fs(14))),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(r.s(16)),
          itemCount: events.length,
          itemBuilder: (ctx, i) {
            final event = events[i];
            final eventType = event['event_type'] as String? ?? 'unknown';
            final ip = event['ip_address'] as String?;
            final location = event['location'] as String?;
            final createdAt = event['created_at'] != null
                ? DateTime.tryParse(event['created_at'] as String)
                : null;

            final (icon, color, label) = _eventTypeInfo(eventType, s);

            return Container(
              margin: EdgeInsets.only(bottom: r.s(8)),
              padding: EdgeInsets.all(r.s(12)),
              decoration: BoxDecoration(
                color: theme.surfacePrimary,
                borderRadius: BorderRadius.circular(r.s(12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: r.s(36),
                    height: r.s(36),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: r.s(18)),
                  ),
                  SizedBox(width: r.s(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: r.fs(13),
                            color: theme.textPrimary,
                          ),
                        ),
                        if (ip != null || location != null)
                          Text(
                            [if (location != null) location, if (ip != null) ip]
                                .join(' · '),
                            style: TextStyle(
                                fontSize: r.fs(11),
                                color: theme.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (createdAt != null)
                    Text(
                      timeago.format(createdAt, locale: 'pt_BR'),
                      style: TextStyle(
                          fontSize: r.fs(11), color: theme.textSecondary),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  (IconData, Color, String) _eventTypeInfo(String type, dynamic s) {
    return switch (type) {
      'login' => (Icons.login_rounded, const Color(0xFF4CAF50), s.securityEventLogin),
      'logout' => (Icons.logout_rounded, const Color(0xFF9E9E9E), s.securityEventLogout),
      'password_change' => (Icons.lock_reset_rounded, const Color(0xFFFF9800), s.securityEventPasswordChange),
      'email_change' => (Icons.email_rounded, const Color(0xFF2196F3), s.securityEventEmailChange),
      'failed_login' => (Icons.warning_rounded, const Color(0xFFF44336), s.securityEventFailedLogin),
      'session_revoked' => (Icons.block_rounded, const Color(0xFFE91E63), s.securityEventSessionRevoked),
      'account_locked' => (Icons.lock_rounded, const Color(0xFFF44336), s.securityEventAccountLocked),
      _ => (Icons.info_rounded, const Color(0xFF9E9E9E), type),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _SecurityScoreCard extends StatelessWidget {
  final int level;
  final bool has2fa;
  final Responsive r;
  final NexusThemeExtension theme;
  final dynamic s;

  const _SecurityScoreCard({
    required this.level,
    required this.has2fa,
    required this.r,
    required this.theme,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (level) {
      >= 80 => (theme.success, s.securityLevelHigh, Icons.security_rounded),
      >= 50 => (const Color(0xFFFF9800), s.securityLevelMedium, Icons.shield_rounded),
      _ => (theme.error, s.securityLevelLow, Icons.shield_outlined),
    };

    return Container(
      padding: EdgeInsets.all(r.s(20)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(r.s(16)),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: r.s(56),
            height: r.s(56),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: r.s(30)),
          ),
          SizedBox(width: r.s(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.securityScoreTitle,
                  style: TextStyle(
                      fontSize: r.fs(12), color: theme.textSecondary),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$level',
                      style: TextStyle(
                        fontSize: r.fs(32),
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    Text(
                      '/100',
                      style: TextStyle(
                          fontSize: r.fs(14), color: theme.textSecondary),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(8), vertical: r.s(3)),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(r.s(20)),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: r.fs(11),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecuritySettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final NexusThemeExtension theme;
  final Responsive r;
  final VoidCallback? onTap;

  const _SecuritySettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.theme,
    required this.r,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: r.s(8)),
      decoration: BoxDecoration(
        color: theme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(12)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: r.s(38),
          height: r.s(38),
          decoration: BoxDecoration(
            color: theme.accentPrimary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: theme.accentPrimary, size: r.s(18)),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: r.fs(14),
            fontWeight: FontWeight.w600,
            color: theme.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: r.fs(12), color: theme.textSecondary),
        ),
        trailing: trailing,
        contentPadding:
            EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(4)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(r.s(12))),
      ),
    );
  }
}

class _SecurityTipsCard extends StatelessWidget {
  final Responsive r;
  final NexusThemeExtension theme;
  final dynamic s;

  const _SecurityTipsCard(
      {required this.r, required this.theme, required this.s});

  @override
  Widget build(BuildContext context) {
    final tips = [
      s.securityTip1,
      s.securityTip2,
      s.securityTip3,
    ];

    return Container(
      padding: EdgeInsets.all(r.s(14)),
      decoration: BoxDecoration(
        color: theme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  color: const Color(0xFFFFD600), size: r.s(18)),
              SizedBox(width: r.s(8)),
              Text(
                s.securityTipsTitle,
                style: TextStyle(
                  fontSize: r.fs(13),
                  fontWeight: FontWeight.w700,
                  color: theme.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: r.s(10)),
          ...tips.map((tip) => Padding(
                padding: EdgeInsets.only(bottom: r.s(6)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        color: theme.success, size: r.s(14)),
                    SizedBox(width: r.s(8)),
                    Expanded(
                      child: Text(
                        tip,
                        style: TextStyle(
                            fontSize: r.fs(12),
                            color: theme.textSecondary,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _RevokeButton extends ConsumerStatefulWidget {
  final String sessionId;
  final Responsive r;
  final NexusThemeExtension theme;
  final dynamic s;

  const _RevokeButton({
    required this.sessionId,
    required this.r,
    required this.theme,
    required this.s,
  });

  @override
  ConsumerState<_RevokeButton> createState() => _RevokeButtonState();
}

class _RevokeButtonState extends ConsumerState<_RevokeButton> {
  bool _isRevoking = false;

  @override
  Widget build(BuildContext context) {
    return _isRevoking
        ? SizedBox(
            width: widget.r.s(18),
            height: widget.r.s(18),
            child: CircularProgressIndicator(
                strokeWidth: 2, color: widget.theme.error),
          )
        : IconButton(
            icon: Icon(Icons.logout_rounded,
                color: widget.theme.error, size: widget.r.s(20)),
            tooltip: widget.s.securityRevokeSession,
            onPressed: _revoke,
          );
  }

  Future<void> _revoke() async {
    setState(() => _isRevoking = true);
    try {
      await SupabaseService.rpc('revoke_session',
          params: {'p_session_id': widget.sessionId});
      if (mounted) {
        ref.invalidate(securityOverviewProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.s.securitySessionRevoked),
            backgroundColor: widget.theme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.s.anErrorOccurredTryAgain),
            backgroundColor: widget.theme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRevoking = false);
    }
  }
}
