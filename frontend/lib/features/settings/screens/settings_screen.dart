import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../../../core/services/supabase_service.dart';
import 'package:amino_clone/core/providers/nexus_theme_provider.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/app_strings.dart';
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
    final s = getStrings();
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
            Icon(Icons.download_rounded, color: context.nexusTheme.accentPrimary),
            SizedBox(width: r.s(8)),
            Text(s.exportData2,
                style: TextStyle(
                    color: context.nexusTheme.textPrimary, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text('${s.prepareDataFile}\n${s.notificationWhenReady}',
            style: TextStyle(color: Colors.grey[500])),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
              child: Text(s.cancel,
                  style: TextStyle(
                      color: Colors.grey[500], fontWeight: FontWeight.w700)),
            ),
          ),
          GestureDetector(
            onTap: () async {
              Navigator.pop(ctx);
              try {
                await SupabaseService.rpc('request_data_export');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            s.requestSentNotification)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(s.anErrorOccurredTryAgain)),
                  );
                }
              }
            },
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.nexusTheme.accentPrimary, context.nexusTheme.accentSecondary],
                ),
                borderRadius: BorderRadius.circular(r.s(12)),
                boxShadow: [
                  BoxShadow(
                    color: context.nexusTheme.accentPrimary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(s.requestButton,
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final s = getStrings();
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
            Icon(Icons.warning_rounded, color: context.nexusTheme.error),
            SizedBox(width: r.s(8)),
            Text(s.deleteAccount2,
                style: TextStyle(
                    color: context.nexusTheme.textPrimary, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text('${s.irreversibleActionWarning}\nmensagens e itens comprados serão permanentemente deletados.\n\n${s.confirmContinue}',
            style: TextStyle(color: Colors.grey[500])),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pop(ctx, false),
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
              child: Text(s.cancel,
                  style: TextStyle(
                      color: Colors.grey[500], fontWeight: FontWeight.w700)),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(ctx, true),
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
              decoration: BoxDecoration(
                color: context.nexusTheme.error,
                borderRadius: BorderRadius.circular(r.s(12)),
                boxShadow: [
                  BoxShadow(
                    color: context.nexusTheme.error.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(s.yesDelete,
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
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
        title: Text(s.finalConfirmation,
            style: TextStyle(
                color: context.nexusTheme.textPrimary, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                s.typeDeleteConfirm,
                style: TextStyle(color: Colors.grey[500])),
            SizedBox(height: r.s(12)),
            TextField(
              controller: confirmCtrl,
              style: TextStyle(color: context.nexusTheme.textPrimary),
              decoration: InputDecoration(
                hintText: s.deleteButton,
                hintStyle: TextStyle(color: Colors.grey[600]),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  borderSide: BorderSide(color: context.nexusTheme.error),
                ),
              ),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pop(ctx, false),
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
              child: Text(s.cancel,
                  style: TextStyle(
                      color: Colors.grey[500], fontWeight: FontWeight.w700)),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (confirmCtrl.text.trim() == s.deleteButton) {
                Navigator.pop(ctx, true);
              }
            },
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
              decoration: BoxDecoration(
                color: context.nexusTheme.error,
                borderRadius: BorderRadius.circular(r.s(12)),
                boxShadow: [
                  BoxShadow(
                    color: context.nexusTheme.error.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(s.permanentDelete,
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );

    if (confirm2 != true || !mounted) return;

    try {
      // Reautenticação: pedir senha antes de deletar
      final passwordCtrl = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.confirmYourPassword),
          content: TextField(
            controller: passwordCtrl,
            obscureText: true,
            decoration: InputDecoration(hintText: s.currentPassword),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(s.cancel)),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(s.confirm)),
          ],
        ),
      );
      if (confirmed != true || passwordCtrl.text.isEmpty) return;
      // Verificar senha
      try {
        final email = SupabaseService.client.auth.currentUser?.email ?? '';
        await SupabaseService.client.auth
            .signInWithPassword(email: email, password: passwordCtrl.text);
      } catch (_) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(s.incorrectPassword)));
        return;
      }
      await SupabaseService.rpc('delete_user_account');
      await SupabaseService.client.auth.signOut();
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.deleteAccountError)),
        );
      }
    }
  }

  /// Fluxo completo de troca de email:
  /// 1. Pede a senha atual para reautenticar
  /// 2. Pede o novo email com validação de formato
  /// 3. Chama auth.updateUser — Supabase envia confirmação para AMBOS os emails
  Future<void> _showChangeEmailDialog(
      BuildContext context, AppStrings s, Responsive r) async {
    final s = getStrings();
    final currentEmail =
        SupabaseService.client.auth.currentUser?.email ?? '';

    // Etapa 1: reautenticação com senha
    final passwordCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r.s(16)),
        ),
        title: Text(s.confirmYourPassword,
            style: TextStyle(
                color: context.nexusTheme.textPrimary, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.emailChangeReauthInfo,
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            SizedBox(height: r.s(12)),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              autofocus: true,
              style: TextStyle(color: context.nexusTheme.textPrimary),
              decoration: InputDecoration(
                hintText: s.currentPassword,
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: context.nexusTheme.backgroundPrimary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  borderSide: BorderSide.none,
                ),
                prefixIcon:
                    Icon(Icons.lock_outline_rounded, color: Colors.grey[500]),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel, style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: context.nexusTheme.accentPrimary),
            child: Text(s.confirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    if (passwordCtrl.text.isEmpty) return;

    // Verificar senha
    try {
      await SupabaseService.client.auth
          .signInWithPassword(email: currentEmail, password: passwordCtrl.text);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(s.incorrectPassword),
        behavior: SnackBarBehavior.floating,
        backgroundColor: context.nexusTheme.error,
      ));
      return;
    } finally {
      passwordCtrl.dispose();
    }

    if (!mounted) return;

    // Etapa 2: pedir novo email
    final emailCtrl = TextEditingController();
    final emailFormKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(r.s(16)),
        ),
        title: Text(s.changeEmail,
            style: TextStyle(
                color: context.nexusTheme.textPrimary, fontWeight: FontWeight.w800)),
        content: Form(
          key: emailFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.emailChangeDualConfirmInfo,
                  style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              SizedBox(height: r.s(12)),
              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                style: TextStyle(color: context.nexusTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: s.newEmail,
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: context.nexusTheme.backgroundPrimary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.s(12)),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon:
                      Icon(Icons.email_outlined, color: Colors.grey[500]),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return s.requiredField;
                  final emailRegex =
                      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                  if (!emailRegex.hasMatch(v.trim())) return s.invalidEmail;
                  if (v.trim() == currentEmail) return s.emailSameAsCurrent;
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel, style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton(
            onPressed: () async {
              if (emailFormKey.currentState?.validate() != true) return;
              try {
                await SupabaseService.client.auth.updateUser(
                  UserAttributes(email: emailCtrl.text.trim()),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(s.emailChangeSentBoth),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 5),
                  ));
                }
              } catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(s.anErrorOccurredTryAgain),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: context.nexusTheme.error,
                  ));
                }
              }
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: context.nexusTheme.accentPrimary),
            child: Text(s.save),
          ),
        ],
      ),
    );
    emailCtrl.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final res = await SupabaseService.table('profiles')
          .select()
          .eq('id', userId)
          .single();
      if (!mounted) return;
      _profile = res;

      if (!mounted) return;
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(s.settings,
            style: TextStyle(
                fontWeight: FontWeight.w800, color: context.nexusTheme.textPrimary)),
        iconTheme: IconThemeData(color: context.nexusTheme.textPrimary),
      ),
      body: SafeArea(
        bottom: true,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: context.nexusTheme.accentPrimary))
            : ListView(
                padding: EdgeInsets.all(r.s(16)),
                children: [
                  // ============================================================
                  // PERFIL CARD
                  // ============================================================
                  GestureDetector(
                    onTap: () {
                      if (_profile != null) {
                        context.push('/user/${_profile!["id"]}');
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.all(r.s(16)),
                      decoration: BoxDecoration(
                        color: context.surfaceColor,
                        borderRadius: BorderRadius.circular(r.s(16)),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                        boxShadow: [
                          BoxShadow(
                            color: context.nexusTheme.accentPrimary.withValues(alpha: 0.05),
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
                                  color: context.nexusTheme.accentPrimary
                                      .withValues(alpha: 0.2),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor:
                                  context.nexusTheme.accentPrimary.withValues(alpha: 0.2),
                              backgroundImage: _profile?['icon_url'] != null
                                  ? CachedNetworkImageProvider(
                                      _profile!['icon_url'] as String? ?? '')
                                  : null,
                              child: _profile?['icon_url'] == null
                                  ? Icon(Icons.person_rounded,
                                      color: context.nexusTheme.accentPrimary, size: r.s(28))
                                  : null,
                            ),
                          ),
                          SizedBox(width: r.s(14)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _profile?['nickname'] as String? ?? s.user,
                                  style: TextStyle(
                                      color: context.nexusTheme.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: r.fs(16)),
                                ),
                                Text(
                                  'Nível ${_profile?["level"] ?? 1}',
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
                  _SectionLabel(title: s.account),
                  _SettingsGroup(items: [
                    _SettingsItem(
                      icon: Icons.person_rounded,
                      title: 'Editar Perfil',
                      onTap: () => context.push('/edit-profile'),
                    ),
                    _SettingsItem(
                      icon: Icons.email_rounded,
                      title: s.changeEmail,
                      subtitle:
                          SupabaseService.client.auth.currentUser?.email ?? '',
                      onTap: () => context.push('/settings/change-email'),
                    ),
                    _SettingsItem(
                      icon: Icons.lock_reset_rounded,
                      title: 'Trocar Senha',
                      subtitle: 'Altere sua senha de acesso',
                      onTap: () => context.push('/settings/change-password'),
                    ),
                    _SettingsItem(
                      icon: Icons.verified_user_rounded,
                      title: 'Verificação em 2 Etapas',
                      subtitle: 'App autenticador ou SMS',
                      onTap: () => context.push('/settings/2fa'),
                    ),
                    _SettingsItem(
                      icon: Icons.link_rounded,
                      title: 'Contas Vinculadas',
                      subtitle: s.googleApple,
                      onTap: () => context.push('/settings/linked-accounts'),
                    ),
                  ]),
                  SizedBox(height: r.s(20)),
  
                  // ============================================================
                  // PREFERÊNCIAS
                  // ============================================================
                  _SectionLabel(title: s.preferences),
                  _SettingsGroup(items: [
                    _SettingsItem(
                      icon: Icons.notifications_rounded,
                      title: s.notifications,
                      onTap: () => context.push('/settings/notifications'),
                    ),
                    _SettingsItem(
                      icon: Icons.lock_rounded,
                      title: s.privacy,
                      onTap: () => context.push('/settings/privacy'),
                    ),
                    const _ThemeSelectorItem(
                      currentMode: ThemeMode.system,
                      onSelect: _noopThemeSelect,
                    ),
                    _SettingsItem(
                      icon: Icons.language_rounded,
                      title: s.language,
                      subtitle: ref.watch(localeProvider).label,
                      onTap: () {
                        final currentLocale = ref.read(localeProvider);
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: context.surfaceColor,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (ctx) => Padding(
                            padding: EdgeInsets.all(r.s(24)),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(s.language,
                                    style: TextStyle(
                                        color: context.nexusTheme.textPrimary,
                                        fontSize: r.fs(18),
                                        fontWeight: FontWeight.w800)),
                                SizedBox(height: r.s(16)),
                                ...AppLocale.values.map((locale) => ListTile(
                                      leading: Text(locale.flag,
                                          style: TextStyle(fontSize: r.fs(24))),
                                      title: Text(locale.label,
                                          style: TextStyle(
                                              color: context.nexusTheme.textPrimary)),
                                      trailing: currentLocale == locale
                                          ? Icon(Icons.check_circle_rounded,
                                              color: context.nexusTheme.accentPrimary)
                                          : null,
                                      onTap: () {
                                        ref
                                            .read(localeProvider.notifier)
                                            .setLocale(locale);
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                s.languageChanged),
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
                      title: s.clearCache2,
                      subtitle: s.freeUpStorage,
                      onTap: () async {
                        final size = CacheService.getFormattedCacheSize();
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: context.surfaceColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(r.s(16)),
                              side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            title: Row(
                              children: [
                                Icon(Icons.cleaning_services_rounded,
                                    color: context.nexusTheme.accentSecondary),
                                SizedBox(width: r.s(8)),
                                Text(s.clearCache2,
                                    style: TextStyle(
                                        color: context.nexusTheme.textPrimary,
                                        fontWeight: FontWeight.w800)),
                              ],
                            ),
                            content: Text('Tamanho atual do cache: $size\n\n${s.clearTempDataDesc}\nSeus dados na nuvem não serão afetados.',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                            actions: [
                              GestureDetector(
                                onTap: () => Navigator.pop(ctx, false),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: r.s(16), vertical: r.s(8)),
                                  child: Text(s.cancel,
                                      style: TextStyle(
                                          color: Colors.grey[500],
                                          fontWeight: FontWeight.w700)),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(ctx, true),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: r.s(16), vertical: r.s(8)),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        context.nexusTheme.accentPrimary,
                                        context.nexusTheme.accentSecondary
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(r.s(12)),
                                  ),
                                  child: Text(s.clear,
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && mounted) {
                          await CacheService.clearAll();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(s.cacheCleared2),
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
                  _SectionLabel(title: s.gamification),
                  _SettingsGroup(items: [
                    _SettingsItem(
                      icon: Icons.account_balance_wallet_rounded,
                      title: s.wallet,
                      onTap: () => context.push('/wallet'),
                    ),
                    _SettingsItem(
                      icon: Icons.emoji_events_rounded,
                      title: s.achievements,
                      onTap: () => context.push('/achievements'),
                    ),
                    _SettingsItem(
                      icon: Icons.inventory_2_rounded,
                      title: s.inventory,
                      onTap: () => context.push('/inventory'),
                    ),
                  ]),
                  SizedBox(height: r.s(20)),
  
                  // ============================================================
                  // SEGURANÇA
                  // ============================================================
                  _SectionLabel(title: s.security),
                  _SettingsGroup(items: [
                    _SettingsItem(
                      icon: Icons.block_rounded,
                      title: s.blockedUsers2,
                      onTap: () => context.push('/settings/blocked-users'),
                    ),
                    _SettingsItem(
                      icon: Icons.security_rounded,
                      title: s.appPermissions2,
                      subtitle: s.cameraPermissionsDesc,
                      onTap: () => context.push('/settings/permissions'),
                    ),
                    _SettingsItem(
                      icon: Icons.devices_rounded,
                      title: s.connectedDevices,
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
                      title: s.helpCenter,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: context.surfaceColor,
                            title: Text(s.helpCenter,
                                style: TextStyle(color: context.nexusTheme.textPrimary)),
                            content: Text(
                              'Para suporte, entre em contato:\n\n\u2022 Email: suporte@nexushub.app\n\u2022 Discord: discord.gg/nexushub\n\u2022 FAQ: nexushub.app/faq',
                              style: TextStyle(color: context.nexusTheme.textSecondary),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(s.close),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.bug_report_rounded,
                      title: s.reportBug,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) {
                            final bugCtrl = TextEditingController();
                            return AlertDialog(
                              backgroundColor: context.surfaceColor,
                              title: Text(s.reportBug,
                                  style: TextStyle(color: context.nexusTheme.textPrimary)),
                              content: TextField(
                                controller: bugCtrl,
                                maxLines: 5,
                                style: TextStyle(color: context.nexusTheme.textPrimary),
                                decoration: InputDecoration(
                                  hintText: s.describeBugHint,
                                  hintStyle: TextStyle(color: Colors.grey[600]),
                                  filled: true,
                                  fillColor: context.nexusTheme.backgroundPrimary,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(r.s(12)),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text(s.cancel),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Bug reportado! Obrigado pelo feedback.'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: context.nexusTheme.accentPrimary,
                                  ),
                                  child: Text(s.send),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    _SettingsItem(
                      icon: Icons.privacy_tip_rounded,
                      title: s.privacyPolicyTitle,
                      onTap: () => context.push('/settings/privacy-policy'),
                    ),
                    _SettingsItem(
                      icon: Icons.gavel_rounded,
                      title: s.termsOfUse,
                      onTap: () => context.push('/settings/terms-of-use'),
                    ),
                    _SettingsItem(
                      icon: Icons.info_rounded,
                      title: 'Sobre o NexusHub',
                      subtitle: 'v1.0.0',
                      onTap: () {
                        showAboutDialog(
                          context: context,
                          applicationName: s.nexusHub,
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
                  _SectionLabel(title: s.data),
                  _SettingsGroup(items: [
                    _SettingsItem(
                      icon: Icons.download_rounded,
                      title: s.exportMyData,
                      onTap: () => _exportData(),
                    ),
                    _SettingsItem(
                      icon: Icons.delete_forever_rounded,
                      title: s.deleteAccount2,
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
                            side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          title: Text(s.logout,
                              style: TextStyle(
                                  color: context.nexusTheme.textPrimary,
                                  fontWeight: FontWeight.w800)),
                          content: Text(
                              'Tem certeza que deseja sair da sua conta?',
                              style: TextStyle(color: Colors.grey[500])),
                          actions: [
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx, false),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: r.s(16), vertical: r.s(8)),
                                child: Text(s.cancel,
                                    style: TextStyle(
                                        color: Colors.grey[500],
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx, true),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: r.s(16), vertical: r.s(8)),
                                decoration: BoxDecoration(
                                  color: context.nexusTheme.error,
                                  borderRadius: BorderRadius.circular(r.s(12)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.nexusTheme.error
                                          .withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(s.logout,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800)),
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
                        border: Border.all(color: context.nexusTheme.error),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, color: context.nexusTheme.error),
                          SizedBox(width: r.s(8)),
                          Text(s.logOutAction,
                              style: TextStyle(
                                  color: context.nexusTheme.error,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: r.s(32)),
                ],
              )
      ),
    );
  }
}

class _SectionLabel extends ConsumerWidget {
  final String title;
  const _SectionLabel({required this.title});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

class _SettingsGroup extends ConsumerWidget {
  final List<Widget> items;
  const _SettingsGroup({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              if (index > 0)
                Divider(
                    height: 1,
                    indent: 52,
                    color: Colors.white.withValues(alpha: 0.05)),
              item,
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsItem extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    return ListTile(
      leading: Icon(icon, color: context.nexusTheme.accentPrimary, size: r.s(22)),
      title: Text(title,
          style: TextStyle(
              color: context.nexusTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: r.fs(14))),
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

/// Item de Aparência — navega para a ThemeSelectorScreen com preview visual dos temas.
class _ThemeSelectorItem extends ConsumerWidget {
  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onSelect;

  const _ThemeSelectorItem({required this.currentMode, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final nexusTheme = context.nexusTheme;
    final activeTheme = ref.watch(nexusThemeProvider);

    return ListTile(
      leading: Container(
        width: r.s(36),
        height: r.s(36),
        decoration: BoxDecoration(
          gradient: nexusTheme.accentGradient,
          borderRadius: BorderRadius.circular(r.s(10)),
        ),
        child: Icon(
          Icons.palette_rounded,
          color: Colors.white,
          size: r.s(20),
        ),
      ),
      title: Text(
        s.appearance,
        style: TextStyle(
          color: nexusTheme.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: r.fs(14),
        ),
      ),
      subtitle: Text(
        activeTheme.name,
        style: TextStyle(
          color: nexusTheme.accentPrimary,
          fontSize: r.fs(11),
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini preview das cores do tema ativo
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ColorDot(color: nexusTheme.accentPrimary, size: r.s(10)),
              SizedBox(width: r.s(3)),
              _ColorDot(color: nexusTheme.accentSecondary, size: r.s(10)),
              SizedBox(width: r.s(3)),
              _ColorDot(color: nexusTheme.backgroundPrimary, size: r.s(10)),
            ],
          ),
          SizedBox(width: r.s(8)),
          Icon(
            Icons.chevron_right_rounded,
            color: nexusTheme.textHint,
            size: r.s(20),
          ),
        ],
      ),
      onTap: () => context.push('/settings/themes'),
    );
  }
}

/// Ponto colorido para preview rápido do tema.
class _ColorDot extends StatelessWidget {
  final Color color;
  final double size;
  const _ColorDot({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
    );
  }
}

/// Função noop para o parâmetro onSelect do _ThemeSelectorItem.
/// O item agora navega diretamente para /settings/themes, então onSelect não é usado.
void _noopThemeSelect(ThemeMode _) {}
