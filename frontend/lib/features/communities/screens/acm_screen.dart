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

  // Join Type: open, request, invite
  String _joinType = 'open';
  // Listed Status: listed, unlisted, none
  String _listedStatus = 'listed';

  // Visual customization
  String _themeColor = '#2196F3';
  String _iconUrl = '';
  String _bannerUrl = '';
  String _welcomeMessage = '';

  // Stats (loaded from DB)
  int _newMembers7d = 0;
  int _pendingFlags = 0;
  int _modActions30d = 0;
  int _totalPosts = 0;
  int _totalChats = 0;

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
      _themeColor = res['theme_color'] as String? ?? '#2196F3';
      _iconUrl = res['icon_url'] as String? ?? '';
      _bannerUrl = res['banner_url'] as String? ?? '';
      _welcomeMessage = res['welcome_message'] as String? ?? '';

      // Load real stats
      await _loadStats();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStats() async {
    try {
      // New members in last 7 days
      final sevenDaysAgo = DateTime.now()
          .subtract(const Duration(days: 7))
          .toUtc()
          .toIso8601String();
      final newMembersRes = await SupabaseService.table('community_members')
          .select('id')
          .eq('community_id', widget.communityId)
          .gte('joined_at', sevenDaysAgo);
      _newMembers7d = (newMembersRes as List).length;

      // Pending flags
      final flagsRes = await SupabaseService.table('flags')
          .select('id')
          .eq('community_id', widget.communityId)
          .eq('status', 'pending');
      _pendingFlags = (flagsRes as List).length;

      // Moderation actions in last 30 days
      final thirtyDaysAgo = DateTime.now()
          .subtract(const Duration(days: 30))
          .toUtc()
          .toIso8601String();
      final modRes = await SupabaseService.table('moderation_logs')
          .select('id')
          .eq('community_id', widget.communityId)
          .gte('created_at', thirtyDaysAgo);
      _modActions30d = (modRes as List).length;

      // Total posts
      final postsRes = await SupabaseService.table('posts')
          .select('id')
          .eq('community_id', widget.communityId)
          .eq('status', 'ok');
      _totalPosts = (postsRes as List).length;

      // Total chats
      final chatsRes = await SupabaseService.table('chat_threads')
          .select('id')
          .eq('community_id', widget.communityId);
      _totalChats = (chatsRes as List).length;
    } catch (_) {
      // Stats are best-effort
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
      final updates = <String, dynamic>{
        'configuration': _config,
        'join_type': _joinType,
        'listed_status': _listedStatus,
        'theme_color': _themeColor,
        'welcome_message': _welcomeMessage,
      };
      if (_iconUrl.isNotEmpty) updates['icon_url'] = _iconUrl;
      if (_bannerUrl.isNotEmpty) updates['banner_url'] = _bannerUrl;

      await SupabaseService.table('communities')
          .update(updates)
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

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
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
      _ModuleItem(
          'post', 'Posts', Icons.article_rounded, 'Permitir criação de posts'),
      _ModuleItem(
          'chat', 'Chat', Icons.chat_rounded, 'Habilitar chats na comunidade'),
      _ModuleItem('catalog', 'Catálogo (Wiki)', Icons.auto_stories_rounded,
          'Habilitar wiki/catálogo'),
      _ModuleItem('featured', 'Featured', Icons.star_rounded,
          'Permitir destaque de conteúdo'),
      _ModuleItem('ranking', 'Ranking', Icons.leaderboard_rounded,
          'Habilitar leaderboard'),
      _ModuleItem('sharedFolder', 'Shared Folder', Icons.folder_shared_rounded,
          'Pasta compartilhada'),
      _ModuleItem('influencer', 'Influencer', Icons.verified_rounded,
          'Sistema de influenciadores'),
      _ModuleItem('externalContent', 'Conteúdo Externo', Icons.link_rounded,
          'Permitir links externos'),
      _ModuleItem('topicCategories', 'Categorias', Icons.category_rounded,
          'Categorias de tópicos'),
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
        Text('Tipo de Entrada', style: Theme.of(context).textTheme.titleLarge),
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
        Text('Visibilidade', style: Theme.of(context).textTheme.titleLarge),
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
        const SizedBox(height: 32),
        Text('Mensagem de Boas-Vindas',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
          controller: TextEditingController(text: _welcomeMessage),
          onChanged: (v) => _welcomeMessage = v,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Mensagem exibida para novos membros...',
            filled: true,
            fillColor: AppTheme.cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // TAB: Visual (com color picker funcional e image URL inputs)
  // ========================================================================
  Widget _buildVisualTab() {
    final currentColor = _parseColor(_themeColor);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Customização Visual',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),

        // Color Picker
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.color_lens_rounded,
                      color: AppTheme.primaryColor),
                  const SizedBox(width: 12),
                  const Text('Cor Tema',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: currentColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  '#F44336',
                  '#E91E63',
                  '#9C27B0',
                  '#673AB7',
                  '#3F51B5',
                  '#2196F3',
                  '#03A9F4',
                  '#00BCD4',
                  '#009688',
                  '#4CAF50',
                  '#8BC34A',
                  '#CDDC39',
                  '#FFC107',
                  '#FF9800',
                  '#FF5722',
                  '#795548',
                  '#607D8B',
                  '#000000',
                ].map((hex) {
                  final c = _parseColor(hex);
                  final isSelected =
                      _themeColor.toLowerCase() == hex.toLowerCase();
                  return GestureDetector(
                    onTap: () => setState(() => _themeColor = hex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                    color: c.withValues(alpha: 0.5),
                                    blurRadius: 8)
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              // Custom hex input
              TextField(
                controller: TextEditingController(text: _themeColor),
                onChanged: (v) {
                  if (v.startsWith('#') && v.length == 7) {
                    setState(() => _themeColor = v);
                  }
                },
                decoration: InputDecoration(
                  hintText: '#RRGGBB',
                  prefixIcon: const Icon(Icons.tag_rounded, size: 18),
                  filled: true,
                  fillColor: AppTheme.scaffoldBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Icon URL
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.image_rounded, color: AppTheme.primaryColor),
                  SizedBox(width: 12),
                  Text('Ícone da Comunidade',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              if (_iconUrl.isNotEmpty)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(_iconUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                              width: 80,
                              height: 80,
                              color: AppTheme.cardColorLight,
                              child: const Icon(Icons.broken_image_rounded),
                            )),
                  ),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: TextEditingController(text: _iconUrl),
                onChanged: (v) => setState(() => _iconUrl = v),
                decoration: InputDecoration(
                  hintText: 'URL da imagem do ícone',
                  prefixIcon: const Icon(Icons.link_rounded, size: 18),
                  filled: true,
                  fillColor: AppTheme.scaffoldBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Banner URL
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.panorama_rounded, color: AppTheme.primaryColor),
                  SizedBox(width: 12),
                  Text('Banner / Capa',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              if (_bannerUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(_bannerUrl,
                      height: 100,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                            height: 100,
                            color: AppTheme.cardColorLight,
                            child: const Center(
                                child: Icon(Icons.broken_image_rounded)),
                          )),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: TextEditingController(text: _bannerUrl),
                onChanged: (v) => setState(() => _bannerUrl = v),
                decoration: InputDecoration(
                  hintText: 'URL da imagem do banner',
                  prefixIcon: const Icon(Icons.link_rounded, size: 18),
                  filled: true,
                  fillColor: AppTheme.scaffoldBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // TAB: Stats (com dados reais do banco)
  // ========================================================================
  Widget _buildStatsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadStats();
        setState(() {});
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Estatísticas da Comunidade',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _StatCard(
            icon: Icons.people_rounded,
            label: 'Membros Total',
            value: _community?.membersCount.toString() ?? '0',
            color: AppTheme.primaryColor,
          ),
          _StatCard(
            icon: Icons.person_add_rounded,
            label: 'Novos Membros (7d)',
            value: _newMembers7d.toString(),
            color: AppTheme.successColor,
          ),
          _StatCard(
            icon: Icons.article_rounded,
            label: 'Posts',
            value: _totalPosts.toString(),
            color: AppTheme.accentColor,
          ),
          _StatCard(
            icon: Icons.chat_rounded,
            label: 'Chats',
            value: _totalChats.toString(),
            color: const Color(0xFF00BCD4),
          ),
          const SizedBox(height: 24),
          Text('Moderação', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _StatCard(
            icon: Icons.flag_rounded,
            label: 'Denúncias Pendentes',
            value: _pendingFlags.toString(),
            color: AppTheme.errorColor,
          ),
          _StatCard(
            icon: Icons.gavel_rounded,
            label: 'Ações de Moderação (30d)',
            value: _modActions30d.toString(),
            color: AppTheme.warningColor,
          ),
          const SizedBox(height: 24),
          Text('Configuração Atual',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _InfoRow('Tipo de Entrada', _joinType.toUpperCase()),
                _InfoRow('Visibilidade', _listedStatus.toUpperCase()),
                _InfoRow('Cor Tema', _themeColor),
                _InfoRow(
                    'Módulos Ativos',
                    _config.entries
                        .where((e) => e.value == true)
                        .length
                        .toString()),
              ],
            ),
          ),
        ],
      ),
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
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
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
              color: color.withValues(alpha: 0.15),
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
