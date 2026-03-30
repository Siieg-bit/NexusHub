import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/services/cache_service.dart';
import '../../../core/utils/responsive.dart';

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

      final r = context.r;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r.s(16)),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        title: Row(
          children: [
            Icon(Icons.download_rounded, color: AppTheme.primaryColor),
            SizedBox(width: r.s(8)),
            Text('Exportar Dados', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w800)),
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
              padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
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
                    SnackBar(content: Text('Ocorreu um erro. Tente novamente.')),
                  );
                }
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                ),
                borderRadius: BorderRadius.circular(r.s(12)),
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

      final r = context.r;
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r.s(16)),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppTheme.errorColor),
            SizedBox(width: r.s(8)),
            Text('Excluir Conta', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w800)),
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
              padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w700)),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(ctx, true),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
              decoration: BoxDecoration(
                color: AppTheme.errorColor,
                borderRadius: BorderRadius.circular(r.s(12)),
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
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r.s(16)),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        title: Text('Confirmação Final', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Digite "EXCLUIR" para confirmar a exclusão permanente da sua conta.',
                style: TextStyle(color: Colors.grey[500])),
            SizedBox(height: r.s(12)),
            TextField(
              controller: confirmCtrl,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'EXCLUIR',
                hintStyle: TextStyle(color: Colors.grey[600]),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
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
              padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
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
              padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
              decoration: BoxDecoration(
                color: AppTheme.errorColor,
                borderRadius: BorderRadius.circular(r.s(12)),
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
          SnackBar(content: Text('Erro ao excluir conta. Tente novamente.')),
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

      if (!mounted) return;
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
        title: Text('Configurações',
            style: TextStyle(fontWeight: FontWeight.w800, color: context.textPrimary)),
        iconTheme: IconThemeData(color: context.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : ListView(
              padding: EdgeInsets.all(r.s(16)),
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
                    padding: EdgeInsets.all(r.s(16)),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(r.s(16)),
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
                                    _profile!['icon_url'] as String? ?? '')
                                : null,
                            child: _profile?['icon_url'] == null
                                ? Icon(Icons.person_rounded,
                                    color: AppTheme.primaryColor, size: r.s(28))
                                : null,
                          ),
                        ),
                        SizedBox(width: r.s(14)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _profile?['nickname'] as String? ?? 'Usuário',
                                style: TextStyle(
                                    color: context.textPrimary,
                                    fontWeight: FontWeight.w800, fontSize: r.fs(16)),
                              ),
                              Text(
                                'Nível ${_profile?['level'] ?? 1}',
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: r.fs(12),
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
                SizedBox(height: r.s(24)),

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
                      showDialog(
                        context: context,
                        builder: (ctx) {
                          final emailCtrl = TextEditingController(
                            text: SupabaseService.client.auth.currentUser?.email ?? '',
                          );
                          return AlertDialog(
                            backgroundColor: context.surfaceColor,
                            title: Text('Alterar Email',
                                style: TextStyle(color: context.textPrimary)),
                            content: TextField(
                              controller: emailCtrl,
                              style: TextStyle(color: context.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Novo email',
                                hintStyle: TextStyle(color: Colors.grey[600]),
                                filled: true,
                                fillColor: context.scaffoldBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(r.s(12)),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  try {
                                    await SupabaseService.client.auth.updateUser(
                                      UserAttributes(email: emailCtrl.text.trim()),
                                    );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Email de confirma\u00e7\u00e3o enviado!'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Ocorreu um erro. Tente novamente.'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                ),
                                child: const Text('Salvar'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  _SettingsItem(
                    icon: Icons.link_rounded,
                    title: 'Contas Vinculadas',
                    subtitle: 'Google, Apple',
                    onTap: () => context.push('/settings/linked-accounts'),
                  ),
                ]),
                SizedBox(height: r.s(20)),

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
                  _ThemeSelectorItem(
                    currentMode: ref.watch(themeProvider),
                    onSelect: (mode) => ref.read(themeProvider.notifier).setTheme(mode),
                  ),
                  _SettingsItem(
                    icon: Icons.language_rounded,
                    title: 'Idioma',
                    subtitle: ref.watch(localeProvider).label,
                    onTap: () {
                      final currentLocale = ref.read(localeProvider);
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: context.surfaceColor,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (ctx) => Padding(
                          padding: EdgeInsets.all(r.s(24)),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Idioma',
                                  style: TextStyle(
                                      color: context.textPrimary,
                                      fontSize: r.fs(18),
                                      fontWeight: FontWeight.w800)),
                              SizedBox(height: r.s(16)),
                              ...AppLocale.values.map((locale) => ListTile(
                                leading: Text(locale.flag, style: TextStyle(fontSize: r.fs(24))),
                                title: Text(locale.label,
                                    style: TextStyle(color: context.textPrimary)),
                                trailing: currentLocale == locale
                                    ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor)
                                    : null,
                                onTap: () {
                                  ref.read(localeProvider.notifier).setLocale(locale);
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Idioma alterado para ${locale.label}'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                              )),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  _SettingsItem(
                    icon: Icons.cleaning_services_rounded,
                    title: 'Limpar Cache',
                    subtitle: 'Liberar espaço de armazenamento',
                    onTap: () async {
                      final size = CacheService.getFormattedCacheSize();
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: context.surfaceColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(r.s(16)),
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          title: Row(
                            children: [
                              Icon(Icons.cleaning_services_rounded, color: AppTheme.accentColor),
                              SizedBox(width: r.s(8)),
                              Text('Limpar Cache', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w800)),
                            ],
                          ),
                          content: Text(
                            'Tamanho atual do cache: $size\n\n'
                            'Isso vai limpar dados temporários salvos localmente. '
                            'Seus dados na nuvem não serão afetados.',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                          actions: [
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx, false),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
                                child: Text('Cancelar', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w700)),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx, true),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppTheme.primaryColor, AppTheme.accentColor],
                                  ),
                                  borderRadius: BorderRadius.circular(r.s(12)),
                                ),
                                child: const Text('Limpar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && mounted) {
                        await CacheService.clearAll();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cache limpo com sucesso!'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ]),
                SizedBox(height: r.s(20)),

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
                SizedBox(height: r.s(20)),

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
                    icon: Icons.security_rounded,
                    title: 'Permissões do App',
                    subtitle: 'Câmera, microfone, notificações',
                    onTap: () => context.push('/settings/permissions'),
                  ),
                  _SettingsItem(
                    icon: Icons.devices_rounded,
                    title: 'Dispositivos Conectados',
                    onTap: () => context.push('/settings/devices'),
                  ),
                ]),
                SizedBox(height: r.s(20)),

                // ============================================================
                // SUPORTE
                // ============================================================
                const _SectionLabel(title: 'Suporte'),
                _SettingsGroup(items: [
                  _SettingsItem(
                    icon: Icons.help_rounded,
                    title: 'Central de Ajuda',
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: context.surfaceColor,
                          title: Text('Central de Ajuda',
                              style: TextStyle(color: context.textPrimary)),
                          content: Text(
                            'Para suporte, entre em contato:\n\n\u2022 Email: suporte@nexushub.app\n\u2022 Discord: discord.gg/nexushub\n\u2022 FAQ: nexushub.app/faq',
                            style: TextStyle(color: context.textSecondary),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Fechar'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  _SettingsItem(
                    icon: Icons.bug_report_rounded,
                    title: 'Reportar Bug',
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) {
                          final bugCtrl = TextEditingController();
                          return AlertDialog(
                            backgroundColor: context.surfaceColor,
                            title: Text('Reportar Bug',
                                style: TextStyle(color: context.textPrimary)),
                            content: TextField(
                              controller: bugCtrl,
                              maxLines: 5,
                              style: TextStyle(color: context.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Descreva o bug encontrado...',
                                hintStyle: TextStyle(color: Colors.grey[600]),
                                filled: true,
                                fillColor: context.scaffoldBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(r.s(12)),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Bug reportado! Obrigado pelo feedback.'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                ),
                                child: const Text('Enviar'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  _SettingsItem(
                    icon: Icons.privacy_tip_rounded,
                    title: 'Política de Privacidade',
                    onTap: () => context.push('/settings/privacy-policy'),
                  ),
                  _SettingsItem(
                    icon: Icons.gavel_rounded,
                    title: 'Termos de Uso',
                    onTap: () => context.push('/settings/terms-of-use'),
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
                SizedBox(height: r.s(20)),

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
                SizedBox(height: r.s(20)),

                // ============================================================
                // LOGOUT
                // ============================================================
                GestureDetector(
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: context.surfaceColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.s(16)),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        title: Text('Sair', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w800)),
                        content: Text(
                            'Tem certeza que deseja sair da sua conta?',
                            style: TextStyle(color: Colors.grey[500])),
                        actions: [
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx, false),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
                              child: Text('Cancelar', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w700)),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx, true),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
                              decoration: BoxDecoration(
                                color: AppTheme.errorColor,
                                borderRadius: BorderRadius.circular(r.s(12)),
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
                    height: r.s(48),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(r.s(12)),
                      border: Border.all(color: AppTheme.errorColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: AppTheme.errorColor),
                        SizedBox(width: r.s(8)),
                        Text('Sair da Conta',
                            style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: r.s(32)),
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
    final r = context.r;
    return Padding(
      padding: EdgeInsets.only(bottom: r.s(8)),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: r.fs(15),
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
    final r = context.r;
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(16)),
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
    final r = context.r;
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor, size: r.s(22)),
      title: Text(title,
          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700, fontSize: r.fs(14))),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: TextStyle(color: Colors.grey[600], fontSize: r.fs(11)))
          : null,
      trailing: Icon(Icons.chevron_right_rounded,
          color: Colors.grey[600], size: r.s(20)),
      onTap: onTap,
    );
  }
}

class _ThemeSelectorItem extends StatelessWidget {
  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onSelect;

  const _ThemeSelectorItem({required this.currentMode, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final labels = {
      ThemeMode.light: 'Claro',
      ThemeMode.dark: 'Escuro',
      ThemeMode.system: 'Sistema',
    };
    final icons = {
      ThemeMode.light: Icons.light_mode_rounded,
      ThemeMode.dark: Icons.dark_mode_rounded,
      ThemeMode.system: Icons.brightness_auto_rounded,
    };
    return ListTile(
      leading: Icon(
        icons[currentMode]!,
        color: AppTheme.primaryColor,
        size: r.s(22),
      ),
      title: Text('Aparência',
          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700, fontSize: r.fs(14))),
      subtitle: Text(
        labels[currentMode]!,
        style: TextStyle(color: Colors.grey[600], fontSize: r.fs(11)),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey[600], size: r.s(20)),
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: context.surfaceColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => Padding(
            padding: EdgeInsets.all(r.s(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Aparência',
                    style: TextStyle(
                        color: context.textPrimary,
                        fontSize: r.fs(18),
                        fontWeight: FontWeight.w800)),
                SizedBox(height: r.s(16)),
                ...ThemeMode.values.map((mode) => ListTile(
                  leading: Icon(icons[mode]!, color: AppTheme.primaryColor),
                  title: Text(labels[mode]!,
                      style: TextStyle(color: context.textPrimary)),
                  trailing: currentMode == mode
                      ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor)
                      : null,
                  onTap: () {
                    onSelect(mode);
                    Navigator.pop(ctx);
                  },
                )),
                SizedBox(height: r.s(8)),
              ],
            ),
          ),
        );
      },
    );
  }
}
