import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';

/// Painel de Administração Global — Team Amino.
/// Visão geral de todas as comunidades, usuários e ações de moderação.
class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  int _totalUsers = 0;
  int _totalCommunities = 0;
  int _totalPosts = 0;
  int _pendingFlags = 0;
  List<Map<String, dynamic>> _recentActions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      // Contagens básicas
      final users =
          await SupabaseService.table('profiles').select('id').count();
      _totalUsers = users.count;

      final communities =
          await SupabaseService.table('communities').select('id').count();
      _totalCommunities = communities.count;

      final posts = await SupabaseService.table('posts').select('id').count();
      _totalPosts = posts.count;

      final flags = await SupabaseService.table('flags')
          .select('id')
          .eq('status', 'pending')
          .count();
      _pendingFlags = flags.count;

      // Ações recentes
      final actions = await SupabaseService.table('moderation_logs')
          .select('*, profiles(*)')
          .order('created_at', ascending: false)
          .limit(20);
      _recentActions = List<Map<String, dynamic>>.from(actions as List? ?? []);

      if (!mounted) return;
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Admin Panel',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: AppTheme.primaryColor,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: s.actionsLabel),
            Tab(text: 'Ferramentas'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildActionsTab(),
                _buildToolsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    final r = context.r;
    return ListView(
      padding: EdgeInsets.all(r.s(16)),
      children: [
        // Stats cards
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.people_rounded,
                label: s.usersLabel,
                value: _totalUsers.toString(),
                color: AppTheme.primaryColor,
              ),
            ),
            SizedBox(width: r.s(12)),
            Expanded(
              child: _StatCard(
                icon: Icons.groups_rounded,
                label: s.communities,
                value: _totalCommunities.toString(),
                color: AppTheme.accentColor,
              ),
            ),
          ],
        ),
        SizedBox(height: r.s(12)),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.article_rounded,
                label: s.posts,
                value: _totalPosts.toString(),
                color: AppTheme.successColor,
              ),
            ),
            SizedBox(width: r.s(12)),
            Expanded(
              child: _StatCard(
                icon: Icons.flag_rounded,
                label: s.pendingFlags,
                value: _pendingFlags.toString(),
                color: AppTheme.errorColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionsTab() {
    final r = context.r;
    if (_recentActions.isEmpty) {
      return Center(
        child: Text(
          s.noModerationActions,
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.all(r.s(16)),
      itemCount: _recentActions.length,
      itemBuilder: (context, index) {
        final action = _recentActions[index];
        return Container(
          margin: EdgeInsets.only(bottom: r.s(12)),
          padding: EdgeInsets.all(r.s(16)),
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
                padding: EdgeInsets.all(r.s(10)),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.gavel_rounded,
                    color: AppTheme.warningColor, size: r.s(20)),
              ),
              SizedBox(width: r.s(16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action['action'] as String? ?? s.actionLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: r.fs(15),
                        color: context.textPrimary,
                      ),
                    ),
                    SizedBox(height: r.s(4)),
                    if (action['reason'] != null)
                      Text(
                        action['reason'] as String? ?? '',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: r.fs(13),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBroadcastDialog(BuildContext context) async {
    final r = context.r;
    final msgCtrl = TextEditingController();
    final titleCtrl = TextEditingController(text: 'Broadcast');

    // Carregar comunidades onde o admin é agent/leader
    final userId = SupabaseService.currentUserId;
    List<Map<String, dynamic>> communities = [];
    String? selectedCommunityId;
    try {
      final res = await SupabaseService.table('community_members')
          .select('community_id, communities(id, title)')
          .eq('user_id', userId ?? '')
          .inFilter('role', ['agent', 'leader']);
      communities = (res as List).cast<Map<String, dynamic>>();
    } catch (_) {}

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: context.surfaceColor,
          title: Text(s.sendBroadcast,
              style: TextStyle(color: context.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  s.messageToAllMembers,
                  style:
                      TextStyle(color: Colors.grey[400], fontSize: r.fs(13))),
              SizedBox(height: r.s(12)),
              // Seletor de comunidade
              DropdownButtonFormField<String>(
                value: selectedCommunityId,
                dropdownColor: context.surfaceColor,
                style: TextStyle(color: context.textPrimary),
                decoration: InputDecoration(
                  labelText: s.community,
                  labelStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: context.scaffoldBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.s(12)),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: communities.map((c) {
                  final comm = c['communities'] as Map<String, dynamic>?;
                  return DropdownMenuItem<String>(
                    value: comm?['id'] as String? ?? '',
                    child: Text(comm?['title'] as String? ?? 'Sem nome',
                        overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (v) => setDialogState(() => selectedCommunityId = v),
              ),
              SizedBox(height: r.s(12)),
              // Título
              TextField(
                controller: titleCtrl,
                style: TextStyle(color: context.textPrimary),
                decoration: InputDecoration(
                  labelText: s.title,
                  labelStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: context.scaffoldBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.s(12)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: r.s(12)),
              // Mensagem
              TextField(
                controller: msgCtrl,
                maxLines: 4,
                style: TextStyle(color: context.textPrimary),
                decoration: InputDecoration(
                  hintText: s.typeMessageHint,
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
              onPressed: () {
                titleCtrl.dispose();
                msgCtrl.dispose();
                Navigator.pop(ctx);
              },
              child: Text(s.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                if (msgCtrl.text.trim().isEmpty) return;
                if (selectedCommunityId == null ||
                    selectedCommunityId!.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text(s.selectCommunity2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                try {
                  await SupabaseService.client.rpc('send_broadcast', params: {
                    'p_community_id': selectedCommunityId,
                    'p_title': titleCtrl.text.trim().isEmpty
                        ? 'Broadcast'
                        : titleCtrl.text.trim(),
                    'p_content': msgCtrl.text.trim(),
                  });
                  titleCtrl.dispose();
                  msgCtrl.dispose();
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(s.broadcastSent),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  titleCtrl.dispose();
                  msgCtrl.dispose();
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(s.anErrorOccurredTryAgain),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: Text(s.send),
            ),
          ],
        ),
      ),
    ).then((_) {
      msgCtrl.dispose();
    });
  }

  Widget _buildToolsTab() {
    final r = context.r;
    return ListView(
      padding: EdgeInsets.all(r.s(16)),
      children: [
        _ToolItem(
          icon: Icons.broadcast_on_personal_rounded,
          label: s.sendBroadcast,
          description: s.sendMessageToAll,
          onTap: () {
            _showBroadcastDialog(context);
          },
        ),
        _ToolItem(
          icon: Icons.person_search_rounded,
          label: 'Buscar Usu\u00e1rio',
          description: 'Encontrar e gerenciar usu\u00e1rios',
          onTap: () => context.push('/search'),
        ),
        _ToolItem(
          icon: Icons.analytics_rounded,
          label: 'Relat\u00f3rios',
          description: 'Relat\u00f3rios de uso e modera\u00e7\u00e3o',
          onTap: () => context.push('/admin/reports'),
        ),
        _ToolItem(
          icon: Icons.settings_rounded,
          label: 'Configura\u00e7\u00f5es Globais',
          description: 'Configura\u00e7\u00f5es da plataforma',
          onTap: () => context.push('/settings'),
        ),
      ],
    );
  }
}

class _StatCard extends ConsumerWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return Container(
      padding: EdgeInsets.all(r.s(20)),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(16)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(r.s(10)),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(r.s(12)),
            ),
            child: Icon(icon, color: color, size: r.s(24)),
          ),
          SizedBox(height: r.s(16)),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: r.fs(28),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: r.s(4)),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: r.fs(13),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolItem extends ConsumerWidget {
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  const _ToolItem({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: r.s(12)),
        padding: EdgeInsets.all(r.s(16)),
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
              padding: EdgeInsets.all(r.s(12)),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(r.s(12)),
              ),
              child: Icon(icon, color: AppTheme.primaryColor, size: r.s(24)),
            ),
            SizedBox(width: r.s(16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: r.fs(16),
                      color: context.textPrimary,
                    ),
                  ),
                  SizedBox(height: r.s(4)),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: r.fs(13),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }
}
