import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

/// Configurações de Notificações — Controles granulares de push e in-app.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final res = await SupabaseService.table('user_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (res != null) {
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

      await SupabaseService.table('user_settings').upsert({
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
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações salvas!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
        title: Text(
          'Notificações',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: _saveSettings,
            child: Container(
              margin: EdgeInsets.only(right: r.s(16), top: r.s(8), bottom: r.s(8)),
              padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
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
                'Salvar',
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
                              'Notificações Push',
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
                        activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.3),
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
                    subtitle: 'Quando alguém curte seu post',
                    value: _pushLikes,
                    color: const Color(0xFFE91E63),
                    onChanged: (v) => setState(() => _pushLikes = v),
                  ),
                  _NotifToggle(
                    icon: Icons.comment_rounded,
                    title: 'Comentários',
                    subtitle: 'Quando alguém comenta no seu post',
                    value: _pushComments,
                    color: AppTheme.primaryColor,
                    onChanged: (v) => setState(() => _pushComments = v),
                  ),
                  _NotifToggle(
                    icon: Icons.person_add_rounded,
                    title: 'Novos Seguidores',
                    subtitle: 'Quando alguém começa a te seguir',
                    value: _pushFollows,
                    color: AppTheme.accentColor,
                    onChanged: (v) => setState(() => _pushFollows = v),
                  ),
                  _NotifToggle(
                    icon: Icons.alternate_email_rounded,
                    title: 'Menções',
                    subtitle: 'Quando alguém menciona você',
                    value: _pushMentions,
                    color: const Color(0xFF00BCD4),
                    onChanged: (v) => setState(() => _pushMentions = v),
                  ),
                  SizedBox(height: r.s(24)),
                  const _SectionTitle(title: 'Chat'),
                  _NotifToggle(
                    icon: Icons.chat_rounded,
                    title: 'Mensagens',
                    subtitle: 'Novas mensagens no chat',
                    value: _pushChatMessages,
                    color: AppTheme.primaryColor,
                    onChanged: (v) => setState(() => _pushChatMessages = v),
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
                  const _SectionTitle(title: 'Gamificação'),
                  _NotifToggle(
                    icon: Icons.emoji_events_rounded,
                    title: 'Conquistas',
                    subtitle: 'Quando desbloqueia uma conquista',
                    value: _pushAchievements,
                    color: AppTheme.warningColor,
                    onChanged: (v) => setState(() => _pushAchievements = v),
                  ),
                  _NotifToggle(
                    icon: Icons.arrow_upward_rounded,
                    title: 'Subiu de Nível',
                    subtitle: 'Quando sobe de nível',
                    value: _pushLevelUp,
                    color: const Color(0xFF9C27B0),
                    onChanged: (v) => setState(() => _pushLevelUp = v),
                  ),
                  SizedBox(height: r.s(24)),
                  const _SectionTitle(title: 'Moderação'),
                  _NotifToggle(
                    icon: Icons.gavel_rounded,
                    title: 'Ações de Moderação',
                    subtitle: 'Avisos, strikes e ações sobre seu conteúdo',
                    value: _pushModeration,
                    color: AppTheme.errorColor,
                    onChanged: (v) => setState(() => _pushModeration = v),
                  ),
                ],

                SizedBox(height: r.s(24)),

                // ============================================================
                // IN-APP
                // ============================================================
                const _SectionTitle(title: 'In-App'),
                _NotifToggle(
                  icon: Icons.volume_up_rounded,
                  title: 'Sons',
                  subtitle: 'Sons de notificação dentro do app',
                  value: _inAppSounds,
                  color: Colors.grey[500]!,
                  onChanged: (v) => setState(() => _inAppSounds = v),
                ),
                _NotifToggle(
                  icon: Icons.vibration_rounded,
                  title: 'Vibração',
                  subtitle: 'Vibrar ao receber notificações',
                  value: _inAppVibration,
                  color: Colors.grey[500]!,
                  onChanged: (v) => setState(() => _inAppVibration = v),
                ),
                SizedBox(height: r.s(32)),
              ],
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
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

class _NotifToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  const _NotifToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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