import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text('Salvar'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Master toggle
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_rounded,
                          color: AppTheme.primaryColor, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Notificações Push',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('Ativar/desativar todas',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _pushEnabled,
                        onChanged: (v) => setState(() => _pushEnabled = v),
                        activeColor: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ============================================================
                // CATEGORIAS
                // ============================================================
                if (_pushEnabled) ...[
                  _SectionTitle(title: 'Social'),
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
                  const SizedBox(height: 16),
                  _SectionTitle(title: 'Chat'),
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
                  const SizedBox(height: 16),
                  _SectionTitle(title: 'Gamificação'),
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
                    title: 'Level Up',
                    subtitle: 'Quando sobe de nível',
                    value: _pushLevelUp,
                    color: const Color(0xFF9C27B0),
                    onChanged: (v) => setState(() => _pushLevelUp = v),
                  ),
                  const SizedBox(height: 16),
                  _SectionTitle(title: 'Moderação'),
                  _NotifToggle(
                    icon: Icons.gavel_rounded,
                    title: 'Ações de Moderação',
                    subtitle: 'Avisos, strikes e ações sobre seu conteúdo',
                    value: _pushModeration,
                    color: AppTheme.errorColor,
                    onChanged: (v) => setState(() => _pushModeration = v),
                  ),
                ],

                const SizedBox(height: 24),

                // ============================================================
                // IN-APP
                // ============================================================
                _SectionTitle(title: 'In-App'),
                _NotifToggle(
                  icon: Icons.volume_up_rounded,
                  title: 'Sons',
                  subtitle: 'Sons de notificação dentro do app',
                  value: _inAppSounds,
                  color: AppTheme.textSecondary,
                  onChanged: (v) => setState(() => _inAppSounds = v),
                ),
                _NotifToggle(
                  icon: Icons.vibration_rounded,
                  title: 'Vibração',
                  subtitle: 'Vibrar ao receber notificações',
                  value: _inAppVibration,
                  color: AppTheme.textSecondary,
                  onChanged: (v) => setState(() => _inAppVibration = v),
                ),
                const SizedBox(height: 32),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: AppTheme.textPrimary,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14)),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppTheme.textHint, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }
}
