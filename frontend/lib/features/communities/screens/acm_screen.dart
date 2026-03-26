import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/services/supabase_service.dart';

/// ACM — Amino Community Manager.
/// Gerenciamento de módulos (JSONB), Join Types, customização visual e estatísticas.
class AcmScreen extends StatefulWidget {
  final String communityId;
  const AcmScreen({super.key, required this.communityId});

  @override
  State<AcmScreen> createState() => _AcmScreenState();
}

class _AcmScreenState extends State<AcmScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CommunityModel? _community;
  Map<String, dynamic> _config = {};
  bool _isLoading = true;

  // Join Type: 0=Open, 1=Request, 2=Invite
  String _joinType = 'open';
  // Listed Status: 0=None, 1=Unlisted, 2=Listed
  String _listedStatus = 'listed';

  final _tabs = const ['Módulos', 'Acesso', 'Visual', 'Stats'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadCommunity();
  }

  Future<void> _loadCommunity() async {
    try {
      final res = await SupabaseService.table('communities')
          .select()
          .eq('id', widget.communityId)
          .single();
      _community = CommunityModel.fromJson(res);
      _config = Map<String, dynamic>.from(
          res['configuration'] as Map<String, dynamic>? ?? _defaultConfig());
      _joinType = res['join_type'] as String? ?? 'open';
      _listedStatus = res['listed_status'] as String? ?? 'listed';
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _defaultConfig() => {
        'post': true,
        'chat': true,
        'catalog': true,
        'featured': true,
        'ranking': true,
        'sharedFolder': true,
        'influencer': false,
        'externalContent': false,
        'topicCategories': true,
      };

  Future<void> _saveConfig() async {
    try {
      await SupabaseService.table('communities')
          .update({
            'configuration': _config,
            'join_type': _joinType,
            'listed_status': _listedStatus,
          })
          .eq('id', widget.communityId);
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Manager',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _saveConfig,
            child: const Text('Salvar',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildModulesTab(),
                _buildAccessTab(),
                _buildVisualTab(),
                _buildStatsTab(),
              ],
            ),
    );
  }

  // ========================================================================
  // TAB: Módulos
  // ========================================================================
  Widget _buildModulesTab() {
    final modules = [
      _ModuleItem('post', 'Posts', Icons.article_rounded, 'Permitir criação de posts'),
      _ModuleItem('chat', 'Chat', Icons.chat_rounded, 'Habilitar chats na comunidade'),
      _ModuleItem('catalog', 'Catálogo (Wiki)', Icons.auto_stories_rounded, 'Habilitar wiki/catálogo'),
      _ModuleItem('featured', 'Featured', Icons.star_rounded, 'Permitir destaque de conteúdo'),
      _ModuleItem('ranking', 'Ranking', Icons.leaderboard_rounded, 'Habilitar leaderboard'),
      _ModuleItem('sharedFolder', 'Shared Folder', Icons.folder_shared_rounded, 'Pasta compartilhada'),
      _ModuleItem('influencer', 'Influencer', Icons.verified_rounded, 'Sistema de influenciadores'),
      _ModuleItem('externalContent', 'Conteúdo Externo', Icons.link_rounded, 'Permitir links externos'),
      _ModuleItem('topicCategories', 'Categorias', Icons.category_rounded, 'Categorias de tópicos'),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final mod = modules[index];
        final isEnabled = _config[mod.key] as bool? ?? false;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SwitchListTile(
            secondary: Icon(mod.icon,
                color: isEnabled ? AppTheme.primaryColor : AppTheme.textHint),
            title: Text(mod.label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(mod.description,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
            value: isEnabled,
            activeColor: AppTheme.primaryColor,
            onChanged: (val) {
              setState(() => _config[mod.key] = val);
            },
          ),
        );
      },
    );
  }

  // ========================================================================
  // TAB: Acesso
  // ========================================================================
  Widget _buildAccessTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Join Type
        Text('Tipo de Entrada',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _AccessOption(
          icon: Icons.public_rounded,
          label: 'Aberta',
          description: 'Qualquer pessoa pode entrar',
          isSelected: _joinType == 'open',
          onTap: () => setState(() => _joinType = 'open'),
        ),
        _AccessOption(
          icon: Icons.how_to_reg_rounded,
          label: 'Requer Aprovação',
          description: 'Novos membros precisam de aprovação',
          isSelected: _joinType == 'request',
          onTap: () => setState(() => _joinType = 'request'),
        ),
        _AccessOption(
          icon: Icons.mail_rounded,
          label: 'Apenas Convite',
          description: 'Somente por convite de membros',
          isSelected: _joinType == 'invite',
          onTap: () => setState(() => _joinType = 'invite'),
        ),

        const SizedBox(height: 32),

        // Listed Status
        Text('Visibilidade',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _AccessOption(
          icon: Icons.visibility_rounded,
          label: 'Listada',
          description: 'Aparece na busca e no Discover',
          isSelected: _listedStatus == 'listed',
          onTap: () => setState(() => _listedStatus = 'listed'),
        ),
        _AccessOption(
          icon: Icons.visibility_off_rounded,
          label: 'Não Listada',
          description: 'Acessível apenas por link direto',
          isSelected: _listedStatus == 'unlisted',
          onTap: () => setState(() => _listedStatus = 'unlisted'),
        ),
        _AccessOption(
          icon: Icons.block_rounded,
          label: 'Oculta',
          description: 'Completamente invisível',
          isSelected: _listedStatus == 'none',
          onTap: () => setState(() => _listedStatus = 'none'),
        ),
      ],
    );
  }

  // ========================================================================
  // TAB: Visual
  // ========================================================================
  Widget _buildVisualTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Customização Visual',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _VisualOption(
          icon: Icons.color_lens_rounded,
          label: 'Cor Tema',
          value: _community?.themeColor ?? '#2196F3',
          onTap: () {/* TODO: Color picker */},
        ),
        _VisualOption(
          icon: Icons.image_rounded,
          label: 'Ícone da Comunidade',
          value: _community?.iconUrl != null ? 'Definido' : 'Não definido',
          onTap: () {/* TODO: Image picker */},
        ),
        _VisualOption(
          icon: Icons.panorama_rounded,
          label: 'Banner / Capa',
          value: _community?.bannerUrl != null ? 'Definido' : 'Não definido',
          onTap: () {/* TODO: Banner picker */},
        ),
        _VisualOption(
          icon: Icons.view_module_rounded,
          label: 'Layout de Navegação',
          value: 'Padrão',
          onTap: () {/* TODO: Layout picker */},
        ),
      ],
    );
  }

  // ========================================================================
  // TAB: Stats
  // ========================================================================
  Widget _buildStatsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Estatísticas da Comunidade',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _StatCard(
          icon: Icons.people_rounded,
          label: 'Membros',
          value: _community?.membersCount.toString() ?? '0',
          color: AppTheme.primaryColor,
        ),
        _StatCard(
          icon: Icons.article_rounded,
          label: 'Posts',
          value: _community?.postsCount.toString() ?? '0',
          color: AppTheme.accentColor,
        ),
        _StatCard(
          icon: Icons.trending_up_rounded,
          label: 'Novos Membros (7d)',
          value: '--',
          color: AppTheme.successColor,
        ),
        _StatCard(
          icon: Icons.timer_rounded,
          label: 'Tempo Médio de Atividade',
          value: '--',
          color: AppTheme.warningColor,
        ),
        const SizedBox(height: 24),
        Text('Moderação',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _StatCard(
          icon: Icons.flag_rounded,
          label: 'Denúncias Pendentes',
          value: '--',
          color: AppTheme.errorColor,
        ),
        _StatCard(
          icon: Icons.gavel_rounded,
          label: 'Ações de Moderação (30d)',
          value: '--',
          color: AppTheme.warningColor,
        ),
      ],
    );
  }
}

// ============================================================================
// WIDGETS AUXILIARES
// ============================================================================

class _ModuleItem {
  final String key;
  final String label;
  final IconData icon;
  final String description;
  const _ModuleItem(this.key, this.label, this.icon, this.description);
}

class _AccessOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _AccessOption({
    required this.icon,
    required this.label,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textHint),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(description,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }
}

class _VisualOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _VisualOption({
    required this.icon,
    required this.label,
    required this.value,
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
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(value,
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: AppTheme.textHint),
        onTap: onTap,
      ),
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
