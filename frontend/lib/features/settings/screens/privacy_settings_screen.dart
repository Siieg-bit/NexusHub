import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';

/// Configurações de Privacidade — Controles de quem pode ver perfil, enviar DM, etc.
/// Réplica 1:1 das opções de privacidade do Amino.
class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _isLoading = true;

  // Configurações de privacidade
  bool _profilePublic = true;
  bool _showOnlineStatus = true;
  bool _allowDMs = true;
  bool _allowChatInvites = true;
  bool _showCommunitiesList = true;
  bool _showFollowersList = true;
  bool _allowMentions = true;
  bool _showRecentPosts = true;
  bool _allowSearchByName = true;
  bool _showWall = true;
  String _whoCanFollow = 'everyone'; // everyone, mutual, nobody

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
          _profilePublic = res['profile_public'] as bool? ?? true;
          _showOnlineStatus = res['show_online_status'] as bool? ?? true;
          _allowDMs = res['allow_dms'] as bool? ?? true;
          _allowChatInvites = res['allow_chat_invites'] as bool? ?? true;
          _showCommunitiesList = res['show_communities_list'] as bool? ?? true;
          _showFollowersList = res['show_followers_list'] as bool? ?? true;
          _allowMentions = res['allow_mentions'] as bool? ?? true;
          _showRecentPosts = res['show_recent_posts'] as bool? ?? true;
          _allowSearchByName = res['allow_search_by_name'] as bool? ?? true;
          _showWall = res['show_wall'] as bool? ?? true;
          _whoCanFollow = res['who_can_follow'] as String? ?? 'everyone';
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
        'profile_public': _profilePublic,
        'show_online_status': _showOnlineStatus,
        'allow_dms': _allowDMs,
        'allow_chat_invites': _allowChatInvites,
        'show_communities_list': _showCommunitiesList,
        'show_followers_list': _showFollowersList,
        'allow_mentions': _allowMentions,
        'show_recent_posts': _showRecentPosts,
        'allow_search_by_name': _allowSearchByName,
        'show_wall': _showWall,
        'who_can_follow': _whoCanFollow,
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
        title: const Text('Privacidade',
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
                // ============================================================
                // PERFIL
                // ============================================================
                _SectionHeader(title: 'Perfil'),
                _SettingToggle(
                  icon: Icons.public_rounded,
                  title: 'Perfil Público',
                  subtitle: 'Qualquer pessoa pode ver seu perfil',
                  value: _profilePublic,
                  onChanged: (v) => setState(() => _profilePublic = v),
                ),
                _SettingToggle(
                  icon: Icons.circle,
                  title: 'Status Online',
                  subtitle: 'Mostrar quando você está online',
                  value: _showOnlineStatus,
                  onChanged: (v) => setState(() => _showOnlineStatus = v),
                ),
                _SettingToggle(
                  icon: Icons.article_rounded,
                  title: 'Posts Recentes',
                  subtitle: 'Mostrar posts recentes no perfil',
                  value: _showRecentPosts,
                  onChanged: (v) => setState(() => _showRecentPosts = v),
                ),
                _SettingToggle(
                  icon: Icons.dashboard_rounded,
                  title: 'Mural (Wall)',
                  subtitle: 'Permitir mensagens no seu mural',
                  value: _showWall,
                  onChanged: (v) => setState(() => _showWall = v),
                ),

                const SizedBox(height: 24),

                // ============================================================
                // COMUNICAÇÃO
                // ============================================================
                _SectionHeader(title: 'Comunicação'),
                _SettingToggle(
                  icon: Icons.chat_rounded,
                  title: 'Mensagens Diretas',
                  subtitle: 'Permitir que outros enviem DMs',
                  value: _allowDMs,
                  onChanged: (v) => setState(() => _allowDMs = v),
                ),
                _SettingToggle(
                  icon: Icons.group_add_rounded,
                  title: 'Convites para Chat',
                  subtitle: 'Permitir convites para chats em grupo',
                  value: _allowChatInvites,
                  onChanged: (v) => setState(() => _allowChatInvites = v),
                ),
                _SettingToggle(
                  icon: Icons.alternate_email_rounded,
                  title: 'Menções',
                  subtitle: 'Permitir que outros mencionem você',
                  value: _allowMentions,
                  onChanged: (v) => setState(() => _allowMentions = v),
                ),

                const SizedBox(height: 24),

                // ============================================================
                // VISIBILIDADE
                // ============================================================
                _SectionHeader(title: 'Visibilidade'),
                _SettingToggle(
                  icon: Icons.groups_rounded,
                  title: 'Lista de Comunidades',
                  subtitle: 'Mostrar comunidades que você participa',
                  value: _showCommunitiesList,
                  onChanged: (v) => setState(() => _showCommunitiesList = v),
                ),
                _SettingToggle(
                  icon: Icons.people_rounded,
                  title: 'Lista de Seguidores',
                  subtitle: 'Mostrar seus seguidores/seguindo',
                  value: _showFollowersList,
                  onChanged: (v) => setState(() => _showFollowersList = v),
                ),
                _SettingToggle(
                  icon: Icons.search_rounded,
                  title: 'Busca por Nome',
                  subtitle: 'Permitir que encontrem você por nome',
                  value: _allowSearchByName,
                  onChanged: (v) => setState(() => _allowSearchByName = v),
                ),

                const SizedBox(height: 24),

                // ============================================================
                // SEGUIDORES
                // ============================================================
                _SectionHeader(title: 'Seguidores'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Quem pode te seguir',
                          style: TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 14)),
                      const SizedBox(height: 12),
                      _RadioOption(
                        label: 'Todos',
                        value: 'everyone',
                        groupValue: _whoCanFollow,
                        onChanged: (v) => setState(() => _whoCanFollow = v!),
                      ),
                      _RadioOption(
                        label: 'Apenas quem eu sigo de volta',
                        value: 'mutual',
                        groupValue: _whoCanFollow,
                        onChanged: (v) => setState(() => _whoCanFollow = v!),
                      ),
                      _RadioOption(
                        label: 'Ninguém',
                        value: 'nobody',
                        groupValue: _whoCanFollow,
                        onChanged: (v) => setState(() => _whoCanFollow = v!),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ============================================================
                // DADOS
                // ============================================================
                _SectionHeader(title: 'Dados'),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.download_rounded,
                            color: AppTheme.primaryColor),
                        title: const Text('Exportar Meus Dados'),
                        subtitle: const Text('Baixar uma cópia dos seus dados',
                            style: TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right_rounded,
                            color: AppTheme.textHint),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Exportação em desenvolvimento')),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.block_rounded,
                            color: AppTheme.textSecondary),
                        title: const Text('Usuários Bloqueados'),
                        trailing: const Icon(Icons.chevron_right_rounded,
                            color: AppTheme.textHint),
                        onTap: () {
                          // TODO: Navegar para lista de bloqueados
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.delete_forever_rounded,
                            color: AppTheme.errorColor),
                        title: const Text('Excluir Conta',
                            style: TextStyle(color: AppTheme.errorColor)),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Excluir Conta'),
                              content: const Text(
                                  'Tem certeza? Esta ação é irreversível e todos os seus dados serão apagados.'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancelar')),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    // TODO: Delete account flow
                                  },
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.errorColor),
                                  child: const Text('Excluir'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}

class _SettingToggle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 20),
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

class _RadioOption extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  const _RadioOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      activeColor: AppTheme.primaryColor,
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}
