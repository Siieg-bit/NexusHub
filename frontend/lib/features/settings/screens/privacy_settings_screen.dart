import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

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
    final r = context.r;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Privacidade',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
          ),
        ),
        iconTheme: IconThemeData(color: context.textPrimary),
        actions: [
          GestureDetector(
            onTap: _saveSettings,
            child: Container(
              margin: EdgeInsets.only(right: r.s(16), top: r.s(10), bottom: r.s(10)),
              padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(6)),
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
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : ListView(
              padding: EdgeInsets.all(r.s(16)),
              children: [
                // ============================================================
                // PERFIL
                // ============================================================
                const _SectionHeader(title: 'Perfil'),
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

                SizedBox(height: r.s(24)),

                // ============================================================
                // COMUNICAÇÃO
                // ============================================================
                const _SectionHeader(title: 'Comunicação'),
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

                SizedBox(height: r.s(24)),

                // ============================================================
                // VISIBILIDADE
                // ============================================================
                const _SectionHeader(title: 'Visibilidade'),
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

                SizedBox(height: r.s(24)),

                // ============================================================
                // SEGUIDORES
                // ============================================================
                const _SectionHeader(title: 'Seguidores'),
                Container(
                  padding: EdgeInsets.all(r.s(16)),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(r.s(16)),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quem pode te seguir',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: r.fs(14),
                          color: context.textPrimary,
                        ),
                      ),
                      SizedBox(height: r.s(12)),
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

                SizedBox(height: r.s(24)),

                // ============================================================
                // DADOS
                // ============================================================
                const _SectionHeader(title: 'Dados'),
                Container(
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(r.s(16)),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.download_rounded,
                            color: AppTheme.primaryColor),
                        title: Text(
                          'Exportar Meus Dados',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          'Baixar uma cópia dos seus dados',
                          style: TextStyle(
                            fontSize: r.fs(12),
                            color: Colors.grey[500],
                          ),
                        ),
                        trailing: Icon(Icons.chevron_right_rounded,
                            color: Colors.grey[600]),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Exportação em desenvolvimento')),
                          );
                        },
                      ),
                      Divider(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.05)),
                      ListTile(
                        leading: Icon(Icons.block_rounded,
                            color: Colors.grey[500]),
                        title: Text(
                          'Usuários Bloqueados',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        trailing: Icon(Icons.chevron_right_rounded,
                            color: Colors.grey[600]),
                        onTap: () {
                          context.push('/settings/blocked-users');
                        },
                      ),
                      Divider(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.05)),
                      ListTile(
                        leading: const Icon(Icons.delete_forever_rounded,
                            color: AppTheme.errorColor),
                        title: const Text(
                          'Excluir Conta',
                          style: TextStyle(
                            color: AppTheme.errorColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: context.surfaceColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(r.s(16)),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                              title: Text(
                                'Excluir Conta',
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              content: Text(
                                'Tem certeza? Esta ação é irreversível e todos os seus dados serão apagados.',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text(
                                    'Cancelar',
                                    style: TextStyle(color: Colors.grey[500]),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    // Deletar conta
                                    showDialog(
                                      context: context,
                                      builder: (ctx2) {
                                        final confirmCtrl = TextEditingController();
                                        return AlertDialog(
                                          backgroundColor: context.surfaceColor,
                                          title: const Text('Confirmar Exclus\u00e3o',
                                              style: TextStyle(color: AppTheme.errorColor)),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('Digite "EXCLUIR" para confirmar:',
                                                  style: TextStyle(color: Colors.grey[400])),
                                              SizedBox(height: r.s(12)),
                                              TextField(
                                                controller: confirmCtrl,
                                                style: TextStyle(color: context.textPrimary),
                                                decoration: InputDecoration(
                                                  hintText: 'EXCLUIR',
                                                  hintStyle: TextStyle(color: Colors.grey[600]),
                                                  filled: true,
                                                  fillColor: context.scaffoldBg,
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
                                              onPressed: () => Navigator.pop(ctx2),
                                              child: const Text('Cancelar'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () async {
                                                if (confirmCtrl.text.trim() != 'EXCLUIR') {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Digite EXCLUIR para confirmar'),
                                                      behavior: SnackBarBehavior.floating,
                                                    ),
                                                  );
                                                  return;
                                                }
                                                try {
                                                  await SupabaseService.client.rpc('delete_user_account');
                                                  await SupabaseService.client.auth.signOut();
                                                  if (context.mounted) context.go('/login');
                                                } catch (e) {
                                                  if (ctx2.mounted) Navigator.pop(ctx2);
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('Erro: $e'),
                                                        behavior: SnackBarBehavior.floating,
                                                      ),
                                                    );
                                                  }
                                                }
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.errorColor,
                                              ),
                                              child: const Text('Excluir Permanentemente'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: r.s(16), vertical: r.s(8)),
                                    decoration: BoxDecoration(
                                      color: AppTheme.errorColor,
                                      borderRadius: BorderRadius.circular(r.s(12)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.errorColor
                                              .withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Text(
                                      'Excluir',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: r.s(32)),
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
    final r = context.r;
    return Padding(
      padding: EdgeInsets.only(bottom: r.s(12)),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: r.fs(16),
          color: AppTheme.primaryColor,
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
    final r = context.r;
    return Container(
      margin: EdgeInsets.only(bottom: r.s(8)),
      padding: EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(12)),
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
            padding: EdgeInsets.all(r.s(8)),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: r.s(20)),
          ),
          SizedBox(width: r.s(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: r.fs(14),
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: r.fs(12),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryColor,
            activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.grey[500],
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
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
    final r = context.r;
    return Theme(
      data: Theme.of(context).copyWith(
        unselectedWidgetColor: Colors.grey[500],
      ),
      child: RadioListTile<String>(
        title: Text(
          label,
          style: TextStyle(
            fontSize: r.fs(14),
            color: context.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        activeColor: AppTheme.primaryColor,
        dense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
