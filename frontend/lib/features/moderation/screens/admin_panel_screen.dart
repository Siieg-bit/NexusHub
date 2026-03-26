import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';

/// Painel de Administração Global — Team Amino.
/// Visão geral de todas as comunidades, usuários e ações de moderação.
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
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
      final users = await SupabaseService.table('profiles')
          .select('id')
          .count();
      _totalUsers = users.count;

      final communities = await SupabaseService.table('communities')
          .select('id')
          .count();
      _totalCommunities = communities.count;

      final posts = await SupabaseService.table('posts')
          .select('id')
          .count();
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
      _recentActions = List<Map<String, dynamic>>.from(actions as List);

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Ações'),
            Tab(text: 'Ferramentas'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stats cards
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.people_rounded,
                label: 'Usuários',
                value: _totalUsers.toString(),
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.groups_rounded,
                label: 'Comunidades',
                value: _totalCommunities.toString(),
                color: AppTheme.accentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.article_rounded,
                label: 'Posts',
                value: _totalPosts.toString(),
                color: AppTheme.successColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.flag_rounded,
                label: 'Flags Pendentes',
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
    if (_recentActions.isEmpty) {
      return const Center(
        child: Text('Nenhuma ação de moderação registrada',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _recentActions.length,
      itemBuilder: (context, index) {
        final action = _recentActions[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.gavel_rounded,
                  color: AppTheme.warningColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action['action'] as String? ?? 'Ação',
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                    if (action['reason'] != null)
                      Text(
                        action['reason'] as String,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
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

  Widget _buildToolsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ToolItem(
          icon: Icons.broadcast_on_personal_rounded,
          label: 'Enviar Broadcast',
          description: 'Enviar mensagem para todos os usuários',
          onTap: () {/* TODO */},
        ),
        _ToolItem(
          icon: Icons.person_search_rounded,
          label: 'Buscar Usuário',
          description: 'Encontrar e gerenciar usuários',
          onTap: () {/* TODO */},
        ),
        _ToolItem(
          icon: Icons.analytics_rounded,
          label: 'Relatórios',
          description: 'Relatórios de uso e moderação',
          onTap: () {/* TODO */},
        ),
        _ToolItem(
          icon: Icons.settings_rounded,
          label: 'Configurações Globais',
          description: 'Configurações da plataforma',
          onTap: () {/* TODO */},
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ToolItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryColor),
        title: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(description,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: AppTheme.textHint),
        onTap: onTap,
      ),
    );
  }
}
