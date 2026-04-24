import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Configurações de Privacidade — Controles de quem pode ver perfil, enviar DM, etc.
/// Réplica 1:1 das opções de privacidade do Amino.
class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  bool _isLoading = true;
  bool _isExporting = false;
  // Configurações de privacidade
  bool _profilePublic = true;
  bool _showOnlineStatus = true;
  bool _allowDMs = true;
  bool _allowChatInvites = true;
  // Funcionalidades MÉDIA — Ghost Mode
  bool _isGhostMode = false;
  bool _disableIncomingChats = false;
  bool _disableProfileComments = false;
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

  // ===========================================================================
  // EXPORTAR DADOS DO USUÁRIO (LGPD)
  // ===========================================================================
  Future<void> _exportUserData() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      final session = SupabaseService.client.auth.currentSession;
      if (session == null) throw Exception('Não autenticado');

      final response = await SupabaseService.client.functions.invoke(
        'export-user-data',
        body: {},
      );

      if (response.status != 200) {
        final errBody = response.data;
        final msg = (errBody is Map && errBody['error'] != null)
            ? errBody['error'].toString()
            : 'Erro ao exportar dados (${response.status})';
        throw Exception(msg);
      }

      // Serializar o JSON retornado
      final jsonString = jsonEncode(response.data);
      final bytes = utf8.encode(jsonString);

      // Salvar em arquivo temporário
      final dir = await getTemporaryDirectory();
      final userId = SupabaseService.currentUserId ?? 'user';
      final file = File('${dir.path}/nexushub_export_$userId.json');
      await file.writeAsBytes(bytes);

      if (!mounted) return;

      // Compartilhar / fazer download via share sheet nativa
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'NexusHub — Exportação de Dados',
        text: 'Seus dados do NexusHub exportados conforme a LGPD.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _loadSettings() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      // Carregar ghost mode / disable chats / disable comments do profiles
      final profileRes = await SupabaseService.table('profiles')
          .select(
              'is_ghost_mode, disable_incoming_chats, disable_profile_comments')
          .eq('id', userId)
          .maybeSingle();
      if (!mounted) return;
      if (profileRes != null) {
        if (!mounted) return;
        setState(() {
          _isGhostMode = profileRes['is_ghost_mode'] as bool? ?? false;
          _disableIncomingChats =
              profileRes['disable_incoming_chats'] as bool? ?? false;
          _disableProfileComments =
              profileRes['disable_profile_comments'] as bool? ?? false;
        });
      }

      final res = await SupabaseService.table('user_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (!mounted) return;

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
    final s = getStrings();
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      // Salvar ghost mode / disable chats / disable comments no profiles
      await SupabaseService.table('profiles').update({
        'is_ghost_mode': _isGhostMode,
        'disable_incoming_chats': _disableIncomingChats,
        'disable_profile_comments': _disableProfileComments,
      }).eq('id', userId);

      await SupabaseService.rpc('update_user_settings', params: {
        'p_settings': {
          'profile_public':        _profilePublic,
          'show_online_status':    _showOnlineStatus,
          'allow_dms':             _allowDMs,
          'allow_chat_invites':    _allowChatInvites,
          'show_communities_list': _showCommunitiesList,
          'show_followers_list':   _showFollowersList,
          'allow_mentions':        _allowMentions,
          'show_recent_posts':     _showRecentPosts,
          'allow_search_by_name':  _allowSearchByName,
          'show_wall':             _showWall,
          'who_can_follow':        _whoCanFollow,
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.settingsSaved)),
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
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          s.privacy,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: context.nexusTheme.textPrimary,
          ),
        ),
        iconTheme: IconThemeData(color: context.nexusTheme.textPrimary),
        actions: [
          GestureDetector(
            onTap: _saveSettings,
            child: Container(
              margin: EdgeInsets.only(
                  right: r.s(16), top: r.s(10), bottom: r.s(10)),
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(6)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.nexusTheme.accentPrimary, context.nexusTheme.accentSecondary],
                ),
                borderRadius: BorderRadius.circular(r.s(20)),
                boxShadow: [
                  BoxShadow(
                    color: context.nexusTheme.accentPrimary.withValues(alpha: 0.3),
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
      body: SafeArea(
        bottom: true,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: context.nexusTheme.accentPrimary))
            : ListView(
                padding: EdgeInsets.all(r.s(16)),
                children: [
                  // ============================================================
                  // PERFIL
                  // ============================================================
                  _SectionHeader(title: s.profile),
                  _SettingToggle(
                    icon: Icons.public_rounded,
                    title: s.publicProfile,
                    subtitle: 'Qualquer pessoa pode ver seu perfil',
                    value: _profilePublic,
                    onChanged: (v) => setState(() => _profilePublic = v),
                  ),
                  _SettingToggle(
                    icon: Icons.circle,
                    title: 'Status Online',
                    subtitle: s.showWhenOnline,
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
                  // MODO FANTASMA
                  // ============================================================
                  const _SectionHeader(title: 'Modo Fantasma'),
                  _SettingToggle(
                    icon: Icons.visibility_off_rounded,
                    title: 'Modo Fantasma',
                    subtitle: s.appearOfflineDesc,
                    value: _isGhostMode,
                    onChanged: (v) => setState(() => _isGhostMode = v),
                  ),
                  _SettingToggle(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Desabilitar novos chats',
                    subtitle: s.preventNewUsersConversations,
                    value: _disableIncomingChats,
                    onChanged: (v) => setState(() => _disableIncomingChats = v),
                  ),
                  _SettingToggle(
                    icon: Icons.comments_disabled_rounded,
                    title: s.disableProfileComments,
                    subtitle: s.noOneCanCommentWall,
                    value: _disableProfileComments,
                    onChanged: (v) => setState(() => _disableProfileComments = v),
                  ),
  
                  SizedBox(height: r.s(24)),
  
                  // ============================================================
                  // COMUNICAÇÃO
                  // ============================================================
                  _SectionHeader(title: s.communication),
                  _SettingToggle(
                    icon: Icons.chat_rounded,
                    title: s.directMessages,
                    subtitle: s.allowOthersToSendDms,
                    value: _allowDMs,
                    onChanged: (v) => setState(() => _allowDMs = v),
                  ),
                  _SettingToggle(
                    icon: Icons.group_add_rounded,
                    title: s.chatInvitations,
                    subtitle: s.allowGroupChatInvitations,
                    value: _allowChatInvites,
                    onChanged: (v) => setState(() => _allowChatInvites = v),
                  ),
                  _SettingToggle(
                    icon: Icons.alternate_email_rounded,
                    title: s.mentions,
                    subtitle: s.allowMentions,
                    value: _allowMentions,
                    onChanged: (v) => setState(() => _allowMentions = v),
                  ),
  
                  SizedBox(height: r.s(24)),
  
                  // ============================================================
                  // VISIBILIDADE
                  // ============================================================
                  _SectionHeader(title: s.visibility),
                  _SettingToggle(
                    icon: Icons.groups_rounded,
                    title: s.communitiesList,
                    subtitle: s.showParticipatedCommunities,
                    value: _showCommunitiesList,
                    onChanged: (v) => setState(() => _showCommunitiesList = v),
                  ),
                  _SettingToggle(
                    icon: Icons.people_rounded,
                    title: s.followersList,
                    subtitle: s.showFollowersFollowing,
                    value: _showFollowersList,
                    onChanged: (v) => setState(() => _showFollowersList = v),
                  ),
                  _SettingToggle(
                    icon: Icons.search_rounded,
                    title: s.searchByName,
                    subtitle: s.allowFindByName,
                    value: _allowSearchByName,
                    onChanged: (v) => setState(() => _allowSearchByName = v),
                  ),
  
                  SizedBox(height: r.s(24)),
  
                  // ============================================================
                  // SEGUIDORES
                  // ============================================================
                  _SectionHeader(title: s.followers),
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
                          s.whoCanFollow,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: r.fs(14),
                            color: context.nexusTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: r.s(12)),
                        _RadioOption(
                          label: s.everyone,
                          value: 'everyone',
                          groupValue: _whoCanFollow,
                          onChanged: (v) => setState(() => _whoCanFollow = v!),
                        ),
                        _RadioOption(
                          label: s.onlyFollowBack,
                          value: 'mutual',
                          groupValue: _whoCanFollow,
                          onChanged: (v) => setState(() => _whoCanFollow = v!),
                        ),
                        _RadioOption(
                          label: s.nobody,
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
                  _SectionHeader(title: s.data),
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
                          leading: Icon(Icons.download_rounded,
                              color: context.nexusTheme.accentPrimary),
                          title: Text(
                            s.exportMyData,
                            style: TextStyle(
                              color: context.nexusTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            s.downloadDataCopy,
                            style: TextStyle(
                              fontSize: r.fs(12),
                              color: Colors.grey[500],
                            ),
                          ),
                          trailing: _isExporting
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: context.nexusTheme.accentPrimary,
                                  ),
                                )
                              : Icon(Icons.chevron_right_rounded,
                                  color: Colors.grey[600]),
                          onTap: _isExporting ? null : _exportUserData,
                        ),
                        Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.05)),
                        ListTile(
                          leading:
                              Icon(Icons.block_rounded, color: Colors.grey[500]),
                          title: Text(
                            s.blockedUsers2,
                            style: TextStyle(
                              color: context.nexusTheme.textPrimary,
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
                          leading: Icon(Icons.delete_forever_rounded,
                              color: context.nexusTheme.error),
                          title:  Text(
                            s.deleteAccount2,
                            style: TextStyle(
                              color: context.nexusTheme.error,
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
                                  s.deleteAccount2,
                                  style: TextStyle(
                                    color: context.nexusTheme.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                content: Text(
                                  s.confirmDeletion,
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: Text(
                                      s.cancel,
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
                                          final confirmCtrl =
                                              TextEditingController();
                                          return AlertDialog(
                                            backgroundColor: context.surfaceColor,
                                            title: Text(
                                                'Confirmar Exclus\u00e3o',
                                                style: TextStyle(
                                                    color: context.nexusTheme.error)),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                    s.typeDeleteToConfirm,
                                                    style: TextStyle(
                                                        color: Colors.grey[400])),
                                                SizedBox(height: r.s(12)),
                                                TextField(
                                                  controller: confirmCtrl,
                                                  style: TextStyle(
                                                      color: context.nexusTheme.textPrimary),
                                                  decoration: InputDecoration(
                                                    hintText: s.deleteButton,
                                                    hintStyle: TextStyle(
                                                        color: Colors.grey[600]),
                                                    filled: true,
                                                    fillColor: context.nexusTheme.backgroundPrimary,
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              r.s(12)),
                                                      borderSide: BorderSide.none,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx2),
                                                child: Text(s.cancel),
                                              ),
                                              ElevatedButton(
                                                onPressed: () async {
                                                  if (confirmCtrl.text.trim() !=
                                                      s.deleteButton) {
                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(
                                                       SnackBar(
                                                        content: Text(
                                                            s.typeDeleteToConfirmAlt),
                                                        behavior: SnackBarBehavior
                                                            .floating,
                                                      ),
                                                    );
                                                    return;
                                                  }
                                                  try {
                                                    await SupabaseService.client
                                                        .rpc(
                                                            'delete_user_account');
                                                    await SupabaseService
                                                        .client.auth
                                                        .signOut();
                                                    if (context.mounted)
                                                      context.go('/login');
                                                  } catch (e) {
                                                    if (ctx2.mounted)
                                                      Navigator.pop(ctx2);
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                              s.anErrorOccurredTryAgain),
                                                          behavior:
                                                              SnackBarBehavior
                                                                  .floating,
                                                        ),
                                                      );
                                                    }
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      context.nexusTheme.error,
                                                ),
                                                child:  Text(
                                                    s.permanentDelete),
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
                                        color: context.nexusTheme.error,
                                        borderRadius:
                                            BorderRadius.circular(r.s(12)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: context.nexusTheme.error
                                                .withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child:  Text(
                                        s.delete,
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
              )
      ),
    );
  }
}

class _SectionHeader extends ConsumerWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.only(bottom: r.s(12)),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: r.fs(16),
          color: context.nexusTheme.accentPrimary,
        ),
      ),
    );
  }
}

class _SettingToggle extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
              color: context.nexusTheme.accentPrimary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: context.nexusTheme.accentPrimary, size: r.s(20)),
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
                    color: context.nexusTheme.textPrimary,
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
            activeColor: context.nexusTheme.accentPrimary,
            activeTrackColor: context.nexusTheme.accentPrimary.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.grey[500],
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }
}

class _RadioOption extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
            color: context.nexusTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        activeColor: context.nexusTheme.accentPrimary,
        dense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
