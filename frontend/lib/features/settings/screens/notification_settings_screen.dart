import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';

/// Configurações de Notificações — Controles granulares de push e in-app.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _isLoading = true;

  // Push notifications
  bool _pushEnabled = true;
  bool _pushLikes = true;
  bool _pushComments = true;
  bool _pushFollows = true;
  bool _pushMentions = true;
  bool _pushChatMessages = true;
  bool _pushCommunityInvites = true;
  bool _pushAchievements = true;
  bool _pushLevelUp = true;
  bool _pushModeration = true;

  // In-app
  bool _inAppSounds = true;
  bool _inAppVibration = true;

  // Filtros granulares — apenas amigos
  bool _onlyFriendsLikes = false;
  bool _onlyFriendsComments = false;
  bool _onlyFriendsMessages = false;

  // Pausar todas as notificações temporariamente
  bool _pauseAllUntil = false;
  DateTime? _pauseUntilDate;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final res = await SupabaseService.table('notification_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (res != null) {
        if (!mounted) return;
        setState(() {
          _pushEnabled = res['push_enabled'] as bool? ?? true;
          _pushLikes = res['push_likes'] as bool? ?? true;
          _pushComments = res['push_comments'] as bool? ?? true;
          _pushFollows = res['push_follows'] as bool? ?? true;
          _pushMentions = res['push_mentions'] as bool? ?? true;
          _pushChatMessages = res['push_chat_messages'] as bool? ?? true;
          _pushCommunityInvites =
              res['push_community_invites'] as bool? ?? true;
          _pushAchievements = res['push_achievements'] as bool? ?? true;
          _pushLevelUp = res['push_level_up'] as bool? ?? true;
          _pushModeration = res['push_moderation'] as bool? ?? true;
          _inAppSounds = res['in_app_sounds'] as bool? ?? true;
          _inAppVibration = res['in_app_vibration'] as bool? ?? true;
          _onlyFriendsLikes = res['only_friends_likes'] as bool? ?? false;
          _onlyFriendsComments = res['only_friends_comments'] as bool? ?? false;
          _onlyFriendsMessages = res['only_friends_messages'] as bool? ?? false;
          _pauseAllUntil = res['pause_all_until'] != null;
          if (res['pause_all_until'] != null) {
            _pauseUntilDate =
                DateTime.tryParse(res['pause_all_until'] as String? ?? '');
          }
        });
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      await SupabaseService.table('notification_settings').upsert({
        'user_id': userId,
        'push_enabled': _pushEnabled,
        'push_likes': _pushLikes,
        'push_comments': _pushComments,
        'push_follows': _pushFollows,
        'push_mentions': _pushMentions,
        'push_chat_messages': _pushChatMessages,
        'push_community_invites': _pushCommunityInvites,
        'push_achievements': _pushAchievements,
        'push_level_up': _pushLevelUp,
        'push_moderation': _pushModeration,
        'in_app_sounds': _inAppSounds,
        'in_app_vibration': _inAppVibration,
        'only_friends_likes': _onlyFriendsLikes,
        'only_friends_comments': _onlyFriendsComments,
        'only_friends_messages': _onlyFriendsMessages,
        'pause_all_until': _pauseAllUntil && _pauseUntilDate != null
            ? _pauseUntilDate!.toIso8601String()
            : null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(s.settingsSaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.anErrorOccurredTryAgain)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
        title: Text(
          s.notifications,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: _saveSettings,
            child: Container(
              margin:
                  EdgeInsets.only(right: r.s(16), top: r.s(8), bottom: r.s(8)),
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                ),
                borderRadius: BorderRadius.circular(r.s(20)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                s.save,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: r.fs(14),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            )
          : ListView(
              padding: EdgeInsets.all(r.s(16)),
              children: [
                // Master toggle
                Container(
                  padding: EdgeInsets.all(r.s(16)),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(r.s(16)),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    boxShadow: [
                      if (_pushEnabled)
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(r.s(10)),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(r.s(12)),
                        ),
                        child: Icon(
                          Icons.notifications_rounded,
                          color: AppTheme.primaryColor,
                          size: r.s(24),
                        ),
                      ),
                      SizedBox(width: r.s(16)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.pushNotifications2,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: r.fs(16),
                                color: context.textPrimary,
                              ),
                            ),
                            SizedBox(height: r.s(4)),
                            Text(
                              'Ativar/desativar todas',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: r.fs(13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _pushEnabled,
                        onChanged: (v) => setState(() => _pushEnabled = v),
                        activeColor: AppTheme.primaryColor,
                        activeTrackColor:
                            AppTheme.primaryColor.withValues(alpha: 0.3),
                        inactiveThumbColor: Colors.grey[400],
                        inactiveTrackColor: Colors.grey[800],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: r.s(24)),

                // ============================================================
                // CATEGORIAS
                // ============================================================
                if (_pushEnabled) ...[
                  const _SectionTitle(title: 'Social'),
                  _NotifToggle(
                    icon: Icons.favorite_rounded,
                    title: 'Curtidas',
                    subtitle: _onlyFriendsLikes
                        ? s.fromFriendsOnly
                        : s.whenSomeoneLikes,
                    value: _pushLikes,
                    color: const Color(0xFFE91E63),
                    onChanged: (v) => setState(() => _pushLikes = v),
                    filterWidget: _pushLikes
                        ? _FriendsOnlyChip(
                            value: _onlyFriendsLikes,
                            onChanged: (v) =>
                                setState(() => _onlyFriendsLikes = v),
                          )
                        : null,
                  ),
                  _NotifToggle(
                    icon: Icons.comment_rounded,
                    title: s.comments,
                    subtitle: _onlyFriendsComments
                        ? s.fromFriendsOnly
                        : s.whenSomeoneComments,
                    value: _pushComments,
                    color: AppTheme.primaryColor,
                    onChanged: (v) => setState(() => _pushComments = v),
                    filterWidget: _pushComments
                        ? _FriendsOnlyChip(
                            value: _onlyFriendsComments,
                            onChanged: (v) =>
                                setState(() => _onlyFriendsComments = v),
                          )
                        : null,
                  ),
                  _NotifToggle(
                    icon: Icons.person_add_rounded,
                    title: 'Novos Seguidores',
                    subtitle: s.whenSomeoneFollows,
                    value: _pushFollows,
                    color: AppTheme.accentColor,
                    onChanged: (v) => setState(() => _pushFollows = v),
                  ),
                  _NotifToggle(
                    icon: Icons.alternate_email_rounded,
                    title: s.mentions,
                    subtitle: s.whenSomeoneMentions,
                    value: _pushMentions,
                    color: const Color(0xFF00BCD4),
                    onChanged: (v) => setState(() => _pushMentions = v),
                  ),
                  SizedBox(height: r.s(24)),
                  const _SectionTitle(title: s.chat),
                  _NotifToggle(
                    icon: Icons.chat_rounded,
                    title: 'Mensagens',
                    subtitle: _onlyFriendsMessages
                        ? s.fromFriendsOnly
                        : 'Novas mensagens no chat',
                    value: _pushChatMessages,
                    color: AppTheme.primaryColor,
                    onChanged: (v) => setState(() => _pushChatMessages = v),
                    filterWidget: _pushChatMessages
                        ? _FriendsOnlyChip(
                            value: _onlyFriendsMessages,
                            onChanged: (v) =>
                                setState(() => _onlyFriendsMessages = v),
                          )
                        : null,
                  ),
                  _NotifToggle(
                    icon: Icons.group_add_rounded,
                    title: 'Convites de Comunidade',
                    subtitle: 'Convites para entrar em comunidades',
                    value: _pushCommunityInvites,
                    color: AppTheme.successColor,
                    onChanged: (v) => setState(() => _pushCommunityInvites = v),
                  ),
                  SizedBox(height: r.s(24)),
                  const _SectionTitle(title: s.gamification),
                  _NotifToggle(
                    icon: Icons.emoji_events_rounded,
                    title: s.achievements,
                    subtitle: 'Quando desbloqueia uma conquista',
                    value: _pushAchievements,
                    color: AppTheme.warningColor,
                    onChanged: (v) => setState(() => _pushAchievements = v),
                  ),
                  _NotifToggle(
                    icon: Icons.arrow_upward_rounded,
                    title: s.leveledUp,
                    subtitle: s.whenLevelUp,
                    value: _pushLevelUp,
                    color: const Color(0xFF9C27B0),
                    onChanged: (v) => setState(() => _pushLevelUp = v),
                  ),
                  SizedBox(height: r.s(24)),
                  const _SectionTitle(title: s.moderation),
                  _NotifToggle(
                    icon: Icons.gavel_rounded,
                    title: s.moderationActionsTitle,
                    subtitle: s.warningsStrikesActions,
                    value: _pushModeration,
                    color: AppTheme.errorColor,
                    onChanged: (v) => setState(() => _pushModeration = v),
                  ),
                ],

                SizedBox(height: r.s(24)),

                // ============================================================
                // PAUSAR NOTIFICAÇÕES
                // ============================================================
                const _SectionTitle(title: s.pauseNotifications2),
                Container(
                  margin: EdgeInsets.only(bottom: r.s(12)),
                  padding: EdgeInsets.all(r.s(16)),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(r.s(16)),
                    border: Border.all(
                      color: _pauseAllUntil
                          ? AppTheme.warningColor.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: r.s(40),
                            height: r.s(40),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.warningColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(r.s(12)),
                            ),
                            child: Icon(Icons.do_not_disturb_on_rounded,
                                color: AppTheme.warningColor, size: r.s(20)),
                          ),
                          SizedBox(width: r.s(16)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.doNotDisturb,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: r.fs(15),
                                        color: context.textPrimary)),
                                SizedBox(height: r.s(4)),
                                Text(
                                  _pauseAllUntil && _pauseUntilDate != null
                                      ? s.pausedUntil('${_pauseUntilDate!.day}/${_pauseUntilDate!.month} ${_pauseUntilDate!.hour.toString().padLeft(2, "0")}:${_pauseUntilDate!.minute.toString().padLeft(2, "0")}')
                                      : s.pauseNotifications,
                                  style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: r.fs(13)),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _pauseAllUntil,
                            onChanged: (v) async {
                              if (v) {
                                final now = DateTime.now();
                                final picked = await showDateTimePicker(
                                  context: context,
                                  initialDate:
                                      now.add(const Duration(hours: 8)),
                                  firstDate: now,
                                  lastDate: now.add(const Duration(days: 30)),
                                );
                                if (picked != null) {
                                  if (!mounted) return;
                                  setState(() {
                                    _pauseAllUntil = true;
                                    _pauseUntilDate = picked;
                                  });
                                }
                              } else {
                                setState(() {
                                  _pauseAllUntil = false;
                                  _pauseUntilDate = null;
                                });
                              }
                            },
                            activeColor: AppTheme.warningColor,
                            activeTrackColor:
                                AppTheme.warningColor.withValues(alpha: 0.3),
                            inactiveThumbColor: Colors.grey[400],
                            inactiveTrackColor: Colors.grey[800],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: r.s(8)),
                const _SectionTitle(title: 'In-App'),
                _NotifToggle(
                  icon: Icons.volume_up_rounded,
                  title: 'Sons',
                  subtitle: s.notificationSoundsInApp,
                  value: _inAppSounds,
                  color: (Colors.grey[500] ?? Colors.grey),
                  onChanged: (v) => setState(() => _inAppSounds = v),
                ),
                _NotifToggle(
                  icon: Icons.vibration_rounded,
                  title: s.vibration,
                  subtitle: s.vibrateOnNotifications,
                  value: _inAppVibration,
                  color: (Colors.grey[500] ?? Colors.grey),
                  onChanged: (v) => setState(() => _inAppVibration = v),
                ),
                SizedBox(height: r.s(32)),
              ],
            ),
    );
  }
}

class _SectionTitle extends ConsumerWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return Padding(
      padding: EdgeInsets.only(bottom: r.s(12), left: r.s(4)),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: r.fs(16),
          color: context.textPrimary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _NotifToggle extends ConsumerWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;
  final Widget? filterWidget;
  const _NotifToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.color,
    required this.onChanged,
    this.filterWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return Container(
      margin: EdgeInsets.only(bottom: r.s(12)),
      padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(12)),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(16)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: r.s(40),
            height: r.s(40),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(r.s(12)),
            ),
            child: Icon(icon, color: color, size: r.s(20)),
          ),
          SizedBox(width: r.s(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: r.fs(15),
                    color: context.textPrimary,
                  ),
                ),
                SizedBox(height: r.s(4)),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: r.fs(13),
                  ),
                ),
                if (filterWidget != null) ...[
                  SizedBox(height: r.s(6)),
                  filterWidget!
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
            activeTrackColor: color.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.grey[400],
            inactiveTrackColor: Colors.grey[800],
          ),
        ],
      ),
    );
  }
}

/// Chip compacto para filtrar notificações apenas de amigos.
class _FriendsOnlyChip extends ConsumerWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _FriendsOnlyChip({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: value
              ? AppTheme.accentColor.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: value
                ? AppTheme.accentColor.withValues(alpha: 0.6)
                : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_rounded,
              size: 12,
              color: value ? AppTheme.accentColor : Colors.grey[500],
            ),
            const SizedBox(width: 4),
            Text(
              s.friendsOnly,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: value ? AppTheme.accentColor : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Abre um date picker seguido de time picker e retorna o DateTime combinado.
Future<DateTime?> showDateTimePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initialDate),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
