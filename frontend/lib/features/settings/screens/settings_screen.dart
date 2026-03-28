import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/providers/theme_provider.dart';

/// Tela de Configurações Gerais — Hub central para todas as configurações.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _exportData() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        title: const Row(
          children: [
            Icon(Icons.download_rounded, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Exportar Dados', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
            'Vamos preparar um arquivo com todos os seus dados (perfil, posts, comentários, mensagens). '
            'Você receberá uma notificação quando estiver pronto.',
            style: TextStyle(color: Colors.grey[500])),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w700)),
            ),
          ),
          GestureDetector(
            onTap: () async {
              Navigator.pop(ctx);
              try {
                await SupabaseService.rpc('request_data_export');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Solicitação enviada! Você receberá uma notificação.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro: $e')),
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text('Solicitar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: AppTheme.errorColor),
            SizedBox(width: 8),
            Text('Excluir Conta', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
            'Esta ação é IRREVERSÍVEL. Todos os seus dados, posts, comentários, '
            'mensagens e itens comprados serão permanentemente deletados.\n\n'
            'Tem certeza que deseja continuar?',
            style: TextStyle(color: Colors.grey[500])),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pop(ctx, false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w700)),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(ctx, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.errorColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text('Sim, excluir',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );

    if (confirm1 != true) return;

    // Segunda confirmação com digitação
    final confirmCtrl = TextEditingController();
    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        title: const Text('Confirmação Final', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Digite "EXCLUIR" para confirmar a exclusão permanente da sua conta.',
                style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'EXCLUIR',
                hintStyle: TextStyle(color: Colors.grey[600]),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.errorColor),
                ),
              ),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pop(ctx, false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w700)),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (confirmCtrl.text.trim() == 'EXCLUIR') {
                Navigator.pop(ctx, true);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.errorColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text('Excluir Permanentemente',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );

    if (confirm2 != true || !mounted) return;

    try {
      await SupabaseService.rpc('delete_user_account');
      await SupabaseService.client.auth.signOut();
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir conta: $e')),
        );
      }
    }
  }

  Future<void> _loadProfile() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final res = await SupabaseService.table('profiles')
          .select()
          .eq('id', userId)
          .single();
      _profile = res;

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Configurações',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ============================================================
                // PERFIL CARD
                // ============================================================
                GestureDetector(
                  onTap: () {
                    if (_profile != null) {
                      context.push('/user/${_profile!['id']}');
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 28,
                            backgroundColor:
                                AppTheme.primaryColor.withValues(alpha: 0.2),
                            backgroundImage: _profile?['icon_url'] != null
                                ? CachedNetworkImageProvider(
                                    _profile!['icon_url'] as String)
                                : null,
                            child: _profile?['icon_url'] == null
                                ? const Icon(Icons.person_rounded,
                                    color: AppTheme.primaryColor, size: 28)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _profile?['nickname'] as String? ?? 'Usuário',
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                              Text(
                                'Nível ${_profile?['level'] ?? 1}',
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: Colors.grey[600]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ============================================================
                // CONTA
                // ============================================================
                const _SectionLabel(title: 'Conta'),
                _SettingsGroup(items: [
                  _SettingsItem(
                    icon: Icons.person_rounded,
                    title: 'Editar Perfil',
                    onTap: () => context.push('/edit-profile'),
                  ),
                  _SettingsItem(
                    icon: Icons.email_rounded,
                    title: 'Email e Senha',
                    subtitle:
                        SupabaseService.client.auth.currentUser?.email ?? '',
                    onTap: () {
                      // TODO: Email/password change
                    },
                  ),
                  _SettingsItem(
                    icon: Icons.link_rounded,
                    title: 'Contas Vinculadas',
                    subtitle: 'Google, Apple',
                    onTap: () {
                      // TODO: Linked accounts
                    },
                  ),
                ]),
                const SizedBox(height: 20),

                // ============================================================
                // PREFERÊNCIAS
                // ============================================================
                const _SectionLabel(title: 'Preferências'),
                _SettingsGroup(items: [
                  _SettingsItem(
                    icon: Icons.notifications_rounded,
                    title: 'Notificações',
                    onTap: () => context.push('/settings/notifications'),
                  ),
                  _SettingsItem(
                    icon: Icons.lock_rounded,
                    title: 'Privacidade',
                    onTap: () => context.push('/settings/privacy'),
                  ),
                  _ThemeToggleItem(
                    isDark: ref.watch(themeProvider) == ThemeMode.dark,
                    onToggle: () => ref.read(themeProvider.notifier).toggle(),
                  ),
                  _SettingsItem(
                    icon: Icons.language_rounded,
                    title: 'Idioma',
                    subtitle: 'Português (Brasil)',
                    onTap: () {
                      // TODO: Language settings
                    },
                  ),
                ]),
                const SizedBox(height: 20),

                // ============================================================
                // GAMIFICAÇÃO
                // ============================================================
                const _SectionLabel(title: 'Gamificação'),
                _SettingsGroup(items: [
                  _SettingsItem(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Carteira',
                    onTap: () => context.push('/wallet'),
                  ),
                  _SettingsItem(
                    icon: Icons.emoji_events_rounded,
                    title: 'Conquistas',
                    onTap: () => context.push('/achievements'),
                  ),
                  _SettingsItem(
                    icon: Icons.inventory_2_rounded,
                    title: 'Inventário',
                    onTap: () => context.push('/inventory'),
                  ),
                ]),
                const SizedBox(height: 20),

                // ============================================================
                // SEGURANÇA
                // ============================================================
                const _SectionLabel(title: 'Segurança'),
                _SettingsGroup(items: [
                  _SettingsItem(
                    icon: Icons.block_rounded,
                    title: 'Usuários Bloqueados',
                    onTap: () => context.push('/settings/blocked-users'),
                  ),
                  _SettingsItem(
                    icon: Icons.devices_rounded,
                    title: 'Dispositivos Conectados',
                    onTap: () => context.push('/settings/devices'),
                  ),
                ]),
                const SizedBox(height: 20),

                // ============================================================
                // SUPORTE
                // ============================================================
                const _SectionLabel(title: 'Suporte'),
                _SettingsGroup(items: [
                  _SettingsItem(
                    icon: Icons.help_rounded,
                    title: 'Central de Ajuda',
                    onTap: () {
                      // TODO: Help center URL
                    },
                  ),
                  _SettingsItem(
                    icon: Icons.bug_report_rounded,
                    title: 'Reportar Bug',
                    onTap: () {
                      // TODO: Bug report
                    },
                  ),
                  _SettingsItem(
                    icon: Icons.info_rounded,
                    title: 'Sobre o NexusHub',
                    subtitle: 'v1.0.0',
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'NexusHub',
                        applicationVersion: '1.0.0',
                        applicationLegalese:
                            '© 2025 NexusHub. Todos os direitos reservados.',
                      );
                    },
                  ),
                ]),
                const SizedBox(height: 20),

                // ============================================================
                // DADOS
                // ============================================================
                const _SectionLabel(title: 'Dados'),
                _SettingsGroup(items: [
                  _SettingsItem(
                    icon: Icons.download_rounded,
                    title: 'Exportar Meus Dados',
                    onTap: () => _exportData(),
                  ),
                  _SettingsItem(
                    icon: Icons.delete_forever_rounded,
                    title: 'Excluir Conta',
                    onTap: () => _deleteAccount(),
                  ),
                ]),
                const SizedBox(height: 20),

                // ============================================================
                // LOGOUT
                // ============================================================
                GestureDetector(
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.surfaceColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        title: const Text('Sair', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
                        content: Text(
                            'Tem certeza que deseja sair da sua conta?',
                            style: TextStyle(color: Colors.grey[500])),
                        actions: [
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx, false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Text('Cancelar', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w700)),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx, true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.errorColor,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.errorColor.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Text('Sair', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && mounted) {
                      await SupabaseService.client.auth.signOut();
                      if (mounted) context.go('/login');
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.errorColor),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: AppTheme.errorColor),
                        SizedBox(width: 8),
                        Text('Sair da Conta',
                            style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 15,
          color: Colors.grey[500],
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> items;
  const _SettingsGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Column(
            children: [
              if (index > 0) Divider(height: 1, indent: 52, color: Colors.white.withValues(alpha: 0.05)),
              item,
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor, size: 22),
      title: Text(title,
          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: TextStyle(color: Colors.grey[600], fontSize: 11))
          : null,
      trailing: Icon(Icons.chevron_right_rounded,
          color: Colors.grey[600], size: 20),
      onTap: onTap,
    );
  }
}

class _ThemeToggleItem extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggle;

  const _ThemeToggleItem({required this.isDark, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
        color: AppTheme.primaryColor,
        size: 22,
      ),
      title: const Text('Aparência',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text(
        isDark ? 'Tema escuro' : 'Tema claro',
        style: TextStyle(color: Colors.grey[600], fontSize: 11),
      ),
      trailing: Switch(
        value: isDark,
        onChanged: (_) => onToggle(),
        activeColor: AppTheme.primaryColor,
      ),
      onTap: onToggle,
    );
  }
}
