import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/widgets/rgb_color_picker.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// ACM — Amino Community Manager.
/// Gerenciamento de módulos (JSONB), Join Types, customização visual,
/// home layout e estatísticas.
class AcmScreen extends ConsumerStatefulWidget {
  final String communityId;
  const AcmScreen({super.key, required this.communityId});

  @override
  ConsumerState<AcmScreen> createState() => _AcmScreenState();
}

class _AcmScreenState extends ConsumerState<AcmScreen>
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
  String _themeGradientEnd = '';
  String _themeApplyMode = 'accent'; // accent | full | gradient
  String _iconUrl = '';
  String _bannerUrl = '';
  // Banners por contexto
  String _bannerHeaderUrl = '';
  String _bannerDrawerUrl = '';
  String _bannerCardUrl = '';
  String _bannerInfoUrl = '';
  String _welcomeMessage = '';
  // Conteúdo editorial
  String _description = '';
  String _rules = '';
  String _aboutText = '';
  String _tagline = '';

  // Home Layout customization
  Map<String, dynamic> _homeLayout = {};

  // Stats (loaded from DB)
  int _newMembers7d = 0;
  int _pendingFlags = 0;
  int _modActions30d = 0;
  int _totalPosts = 0;
  int _totalChats = 0;

  final _tabs = ['Módulos', 'Acesso', 'Visual', 'Banners', 'Conteúdo', 'Home', 'Categorias', 'Stats'];

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
      _themeGradientEnd = res['theme_gradient_end'] as String? ?? '';
      _themeApplyMode = res['theme_apply_mode'] as String? ?? 'accent';
      _iconUrl = res['icon_url'] as String? ?? '';
      _bannerUrl = res['banner_url'] as String? ?? '';
      _bannerHeaderUrl = res['banner_header_url'] as String? ?? '';
      _bannerDrawerUrl = res['banner_drawer_url'] as String? ?? '';
      _bannerCardUrl = res['banner_card_url'] as String? ?? '';
      _bannerInfoUrl = res['banner_info_url'] as String? ?? '';
      _welcomeMessage = res['welcome_message'] as String? ?? '';
      _description = res['description'] as String? ?? '';
      _rules = res['rules'] as String? ?? '';
      _aboutText = res['about_text'] as String? ?? '';
      _tagline = res['tagline'] as String? ?? '';
      _homeLayout = Map<String, dynamic>.from(
          res['home_layout'] as Map<String, dynamic>? ?? _defaultHomeLayout());

      // Load real stats
      await _loadStats();

      if (!mounted) return;
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStats() async {
    try {
      final sevenDaysAgo = DateTime.now()
          .subtract(const Duration(days: 7))
          .toUtc()
          .toIso8601String();
      final newMembersRes = await SupabaseService.table('community_members')
          .select('id')
          .eq('community_id', widget.communityId)
          .gte('joined_at', sevenDaysAgo);
      _newMembers7d = (newMembersRes as List?)?.length ?? 0;

      final flagsRes = await SupabaseService.table('flags')
          .select('id')
          .eq('community_id', widget.communityId)
          .eq('status', 'pending');
      _pendingFlags = (flagsRes as List?)?.length ?? 0;

      final thirtyDaysAgo = DateTime.now()
          .subtract(const Duration(days: 30))
          .toUtc()
          .toIso8601String();
      final modRes = await SupabaseService.table('moderation_logs')
          .select('id')
          .eq('community_id', widget.communityId)
          .gte('created_at', thirtyDaysAgo);
      _modActions30d = (modRes as List?)?.length ?? 0;

      final postsRes = await SupabaseService.table('posts')
          .select('id')
          .eq('community_id', widget.communityId)
          .eq('status', 'ok');
      _totalPosts = (postsRes as List?)?.length ?? 0;

      final chatsRes = await SupabaseService.table('chat_threads')
          .select('id')
          .eq('community_id', widget.communityId);
      _totalChats = (chatsRes as List?)?.length ?? 0;
    } catch (e) {
      debugPrint('[acm_screen] Erro: $e');
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

  Map<String, dynamic> _defaultHomeLayout() => {
        'sections_order': ['header', 'check_in', 'live_chats', 'tabs'],
        'sections_visible': {
          'check_in': true,
          'live_chats': true,
          'featured_posts': true,
          'latest_feed': true,
          'public_chats': true,
          'guidelines': true,
        },
        'featured_type': 'list',
        'welcome_banner': {
          'enabled': false,
          'image_url': null,
          'text': null,
          'link': null,
        },
        'pinned_chat_ids': [],
        'bottom_bar': {
          'show_online_count': true,
          'show_create_button': true,
        },
      };

  Future<void> _saveConfig() async {
    final s = getStrings();
    final r = context.r;
    try {
      final updates = <String, dynamic>{
        'configuration': _config,
        'join_type': _joinType,
        'listed_status': _listedStatus,
        'theme_color': _themeColor,
        'theme_apply_mode': _themeApplyMode,
        'welcome_message': _welcomeMessage,
        'home_layout': _homeLayout,
        'description': _description,
        'rules': _rules,
        'about_text': _aboutText,
        'tagline': _tagline,
      };
      if (_iconUrl.isNotEmpty) updates['icon_url'] = _iconUrl;
      if (_bannerUrl.isNotEmpty) updates['banner_url'] = _bannerUrl;
      if (_bannerHeaderUrl.isNotEmpty) updates['banner_header_url'] = _bannerHeaderUrl;
      if (_bannerDrawerUrl.isNotEmpty) updates['banner_drawer_url'] = _bannerDrawerUrl;
      if (_bannerCardUrl.isNotEmpty) updates['banner_card_url'] = _bannerCardUrl;
      if (_bannerInfoUrl.isNotEmpty) updates['banner_info_url'] = _bannerInfoUrl;
      if (_themeGradientEnd.isNotEmpty) updates['theme_gradient_end'] = _themeGradientEnd;

      await SupabaseService.table('communities')
          .update(updates)
          .eq('id', widget.communityId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.settingsSaved),
            backgroundColor: context.nexusTheme.accentPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.s(10))),
          ),
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
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return context.nexusTheme.accentPrimary;
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
        title: const Text('Community Manager',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          GestureDetector(
            onTap: _saveConfig,
            child: Container(
              margin:
                  EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(10)),
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
              child: Text(s.save,
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: context.nexusTheme.accentPrimary,
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: context.nexusTheme.accentPrimary,
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
                _buildBannersTab(),
                _buildContentTab(),
                _buildHomeLayoutTab(),
                _buildCategoriesTab(),
                _buildStatsTab(),
              ],
            ),
    );
  }

  // ========================================================================
  // TAB: Módulos
  // ========================================================================
  Widget _buildModulesTab() {
    final s = getStrings();
    final r = context.r;
    final modules = [
      _ModuleItem(
          'post', s.posts, Icons.article_rounded, 'Permitir criação de posts'),
      _ModuleItem(
          'chat', s.chat, Icons.chat_rounded, 'Habilitar chats na comunidade'),
      _ModuleItem('catalog', 'Catálogo (Wiki)', Icons.auto_stories_rounded,
          s.enableWikiCatalog),
      _ModuleItem('featured', s.featured, Icons.star_rounded,
          s.allowContentHighlight),
      _ModuleItem('ranking', s.ranking, Icons.leaderboard_rounded,
          'Habilitar leaderboard'),
      _ModuleItem('sharedFolder', 'Pasta Compartilhada',
          Icons.folder_shared_rounded, s.sharedFolder),
      _ModuleItem('influencer', 'Influenciador', Icons.verified_rounded,
          'Sistema de influenciadores'),
      _ModuleItem('externalContent', 'Conteúdo Externo', Icons.link_rounded,
          'Permitir links externos'),
      _ModuleItem('topicCategories', s.categories, Icons.category_rounded,
          s.topicCategories),
    ];

    return ListView.builder(
      padding: EdgeInsets.all(r.s(16)),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final mod = modules[index];
        final isEnabled = _config[mod.key] as bool? ?? false;
        return Container(
          margin: EdgeInsets.only(bottom: r.s(8)),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(r.s(12)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: SwitchListTile(
            secondary: Icon(mod.icon,
                color: isEnabled ? context.nexusTheme.accentPrimary : Colors.grey[600]),
            title: Text(mod.label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(mod.description,
                style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12))),
            value: isEnabled,
            activeColor: context.nexusTheme.accentPrimary,
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
    final s = getStrings();
    final r = context.r;
    return ListView(
      padding: EdgeInsets.all(r.s(16)),
      children: [
        Text(s.entryType, style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: r.s(12)),
        _AccessOption(
          icon: Icons.public_rounded,
          label: s.open,
          description: 'Qualquer pessoa pode entrar',
          isSelected: _joinType == 'open',
          onTap: () => setState(() => _joinType = 'open'),
        ),
        _AccessOption(
          icon: Icons.how_to_reg_rounded,
          label: s.requiresApproval,
          description: s.newMembersNeedApproval,
          isSelected: _joinType == 'request',
          onTap: () => setState(() => _joinType = 'request'),
        ),
        _AccessOption(
          icon: Icons.mail_rounded,
          label: s.inviteOnly,
          description: 'Somente por convite de membros',
          isSelected: _joinType == 'invite',
          onTap: () => setState(() => _joinType = 'invite'),
        ),
        SizedBox(height: r.s(32)),
        Text(s.visibility, style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: r.s(12)),
        _AccessOption(
          icon: Icons.visibility_rounded,
          label: s.listed,
          description: 'Aparece na busca e no Discover',
          isSelected: _listedStatus == 'listed',
          onTap: () => setState(() => _listedStatus = 'listed'),
        ),
        _AccessOption(
          icon: Icons.visibility_off_rounded,
          label: s.unlistedLabel,
          description: s.accessibleByDirectLink,
          isSelected: _listedStatus == 'unlisted',
          onTap: () => setState(() => _listedStatus = 'unlisted'),
        ),
        _AccessOption(
          icon: Icons.block_rounded,
          label: s.hiddenLabel,
          description: s.completelyInvisible,
          isSelected: _listedStatus == 'none',
          onTap: () => setState(() => _listedStatus = 'none'),
        ),
        SizedBox(height: r.s(32)),
        Text(s.welcomeMessage2,
            style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: r.s(12)),
        TextField(
          controller: TextEditingController(text: _welcomeMessage),
          onChanged: (v) => _welcomeMessage = v,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Mensagem exibida para novos membros...',
            filled: true,
            fillColor: context.surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(r.s(12)),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // TAB: Visual
  // ========================================================================
  Widget _buildVisualTab() {
    final s = getStrings();
    final r = context.r;
    final currentColor = _parseColor(_themeColor);

    return ListView(
      padding: EdgeInsets.all(r.s(16)),
      children: [
        Text(s.visualCustomization,
            style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: r.s(16)),

        // Color Picker — Seletor RGB avançado
        Container(
          padding: EdgeInsets.all(r.s(16)),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(r.s(12)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Icon(Icons.color_lens_rounded,
                  color: context.nexusTheme.accentPrimary),
              SizedBox(width: r.s(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cor Tema',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(height: r.s(4)),
                    Text(
                      _themeColor.toUpperCase(),
                      style: TextStyle(
                        color: currentColor,
                        fontSize: r.fs(12),
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              ColorPickerButton(
                color: currentColor,
                title: 'Cor Tema',
                size: 40,
                onColorChanged: (c) {
                  setState(() {
                    _themeColor = '#${c.r.round().toRadixString(16).padLeft(2, '0').toUpperCase()}${c.g.round().toRadixString(16).padLeft(2, '0').toUpperCase()}${c.b.round().toRadixString(16).padLeft(2, '0').toUpperCase()}';
                  });
                },
              ),
            ],
          ),
        ),

        SizedBox(height: r.s(16)),

        // Icon URL
        Container(
          padding: EdgeInsets.all(r.s(16)),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(r.s(12)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.image_rounded, color: context.nexusTheme.accentPrimary),
                  SizedBox(width: r.s(12)),
                  Text(s.communityIcon,
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              SizedBox(height: r.s(12)),
              if (_iconUrl.isNotEmpty)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(r.s(16)),
                    child: Image.network(_iconUrl,
                        width: r.s(80),
                        height: r.s(80),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                              width: r.s(80),
                              height: r.s(80),
                              color: context.surfaceColor,
                              child: const Icon(Icons.broken_image_rounded),
                            )),
                  ),
                ),
              SizedBox(height: r.s(8)),
              TextField(
                controller: TextEditingController(text: _iconUrl),
                onChanged: (v) => setState(() => _iconUrl = v),
                decoration: InputDecoration(
                  hintText: s.iconImageUrl,
                  prefixIcon: Icon(Icons.link_rounded, size: r.s(18)),
                  filled: true,
                  fillColor: context.nexusTheme.backgroundPrimary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.s(8)),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
                style: TextStyle(fontSize: r.fs(13)),
              ),
            ],
          ),
        ),

        SizedBox(height: r.s(16)),

        // Banner URL
        Container(
          padding: EdgeInsets.all(r.s(16)),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(r.s(12)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.panorama_rounded, color: context.nexusTheme.accentPrimary),
                  SizedBox(width: r.s(12)),
                  Text(s.bannerCover,
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              SizedBox(height: r.s(12)),
              if (_bannerUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  child: Image.network(_bannerUrl,
                      height: r.s(100),
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                            height: r.s(100),
                            color: context.surfaceColor,
                            child: const Center(
                                child: Icon(Icons.broken_image_rounded)),
                          )),
                ),
              SizedBox(height: r.s(8)),
              TextField(
                controller: TextEditingController(text: _bannerUrl),
                onChanged: (v) => setState(() => _bannerUrl = v),
                decoration: InputDecoration(
                  hintText: s.bannerImageUrl,
                  prefixIcon: Icon(Icons.link_rounded, size: r.s(18)),
                  filled: true,
                  fillColor: context.nexusTheme.backgroundPrimary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.s(8)),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
                style: TextStyle(fontSize: r.fs(13)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // TAB: Banners — Banners personalizados por contexto
  // ========================================================================
  Widget _buildBannersTab() {
    final r = context.r;

    Widget _bannerField({
      required String label,
      required String hint,
      required String value,
      required ValueChanged<String> onChanged,
      required IconData icon,
    }) {
      return Container(
        padding: EdgeInsets.all(r.s(16)),
        margin: EdgeInsets.only(bottom: r.s(12)),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(r.s(12)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: context.nexusTheme.accentPrimary, size: r.s(20)),
                SizedBox(width: r.s(10)),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: r.fs(14))),
                ),
              ],
            ),
            SizedBox(height: r.s(10)),
            if (value.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(r.s(10)),
                child: Image.network(
                  value,
                  height: r.s(90),
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: r.s(90),
                    color: context.nexusTheme.backgroundPrimary,
                    child: const Center(
                        child: Icon(Icons.broken_image_rounded)),
                  ),
                ),
              ),
            SizedBox(height: r.s(8)),
            TextField(
              controller: TextEditingController(text: value),
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hint,
                prefixIcon: Icon(Icons.link_rounded, size: r.s(16)),
                filled: true,
                fillColor: context.nexusTheme.backgroundPrimary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(8)),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
              style: TextStyle(fontSize: r.fs(13)),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(r.s(16)),
      children: [
        Text('Banners por Contexto',
            style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: r.s(6)),
        Text(
          'Cada local da comunidade pode ter um banner diferente. Se não configurado, usa o banner padrão.',
          style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12)),
        ),
        SizedBox(height: r.s(16)),
        _bannerField(
          label: 'Banner Padrão',
          hint: 'URL do banner padrão (fallback)',
          value: _bannerUrl,
          onChanged: (v) => setState(() => _bannerUrl = v),
          icon: Icons.panorama_rounded,
        ),
        _bannerField(
          label: 'Banner do Header',
          hint: 'URL do banner no topo da comunidade',
          value: _bannerHeaderUrl,
          onChanged: (v) => setState(() => _bannerHeaderUrl = v),
          icon: Icons.web_asset_rounded,
        ),
        _bannerField(
          label: 'Banner do Drawer (Menu Lateral)',
          hint: 'URL do banner no menu lateral',
          value: _bannerDrawerUrl,
          onChanged: (v) => setState(() => _bannerDrawerUrl = v),
          icon: Icons.menu_rounded,
        ),
        _bannerField(
          label: 'Banner do Card (Lista de Comunidades)',
          hint: 'URL do banner no card da lista',
          value: _bannerCardUrl,
          onChanged: (v) => setState(() => _bannerCardUrl = v),
          icon: Icons.grid_view_rounded,
        ),
        _bannerField(
          label: 'Banner da Página de Informações',
          hint: 'URL do banner na página de info/sobre',
          value: _bannerInfoUrl,
          onChanged: (v) => setState(() => _bannerInfoUrl = v),
          icon: Icons.info_outline_rounded,
        ),
        SizedBox(height: r.s(16)),
        // Modo de aplicação da cor
        Text('Aplicação da Cor Predominante',
            style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: r.s(12)),
        ...[('accent', 'Acento', 'Cor usada em botões e destaques'),
          ('full', 'Completo', 'Cor aplicada no fundo do header'),
          ('gradient', 'Gradiente', 'Gradiente da cor predominante até a cor secundária'),
        ].map((opt) {
          final (key, label, desc) = opt;
          return Container(
            margin: EdgeInsets.only(bottom: r.s(8)),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(r.s(12)),
              border: Border.all(
                color: _themeApplyMode == key
                    ? context.nexusTheme.accentPrimary
                    : Colors.white.withValues(alpha: 0.05),
                width: _themeApplyMode == key ? 1.5 : 1,
              ),
            ),
            child: RadioListTile<String>(
              title: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(desc,
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: r.fs(12))),
              value: key,
              groupValue: _themeApplyMode,
              onChanged: (v) => setState(() => _themeApplyMode = v!),
              activeColor: context.nexusTheme.accentPrimary,
            ),
          );
        }),
        if (_themeApplyMode == 'gradient') ...[
          SizedBox(height: r.s(12)),
          Container(
            padding: EdgeInsets.all(r.s(16)),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(r.s(12)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cor Final do Gradiente',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: r.s(8)),
                TextField(
                  controller: TextEditingController(text: _themeGradientEnd),
                  onChanged: (v) {
                    if (v.startsWith('#') && v.length == 7) {
                      setState(() => _themeGradientEnd = v);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: '#RRGGBB (cor final do gradiente)',
                    prefixIcon: Icon(Icons.tag_rounded, size: r.s(16)),
                    filled: true,
                    fillColor: context.nexusTheme.backgroundPrimary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(r.s(8)),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                  style: TextStyle(fontSize: r.fs(13)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ========================================================================
  // TAB: Conteúdo — Descrição, Regras e Sobre
  // ========================================================================
  Widget _buildContentTab() {
    final r = context.r;

    return ListView(
      padding: EdgeInsets.all(r.s(16)),
      children: [
        Text('Informações da Comunidade',
            style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: r.s(6)),
        Text(
          'Configure a descrição, tagline, regras e texto sobre a comunidade.',
          style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12)),
        ),
        SizedBox(height: r.s(16)),
        // Tagline
        _ContentField(
          label: 'Tagline',
          hint: 'Frase curta que define a comunidade...',
          value: _tagline,
          onChanged: (v) => setState(() => _tagline = v),
          maxLines: 2,
          icon: Icons.short_text_rounded,
        ),
        SizedBox(height: r.s(12)),
        // Descrição
        _ContentField(
          label: 'Descrição',
          hint: 'Descrição exibida na página de informações...',
          value: _description,
          onChanged: (v) => setState(() => _description = v),
          maxLines: 6,
          icon: Icons.description_rounded,
        ),
        SizedBox(height: r.s(12)),
        // Sobre (About)
        _ContentField(
          label: 'Sobre a Comunidade',
          hint: 'Texto detalhado sobre a comunidade, história, objetivos...',
          value: _aboutText,
          onChanged: (v) => setState(() => _aboutText = v),
          maxLines: 8,
          icon: Icons.info_rounded,
        ),
        SizedBox(height: r.s(24)),
        Text('Regras da Comunidade',
            style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: r.s(6)),
        Text(
          'As regras serão exibidas na aba de Guidelines. Suporta Markdown.',
          style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12)),
        ),
        SizedBox(height: r.s(12)),
        Container(
          padding: EdgeInsets.all(r.s(16)),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(r.s(12)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.gavel_rounded,
                      color: context.nexusTheme.accentPrimary, size: r.s(20)),
                  SizedBox(width: r.s(10)),
                  const Text('Regras',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              SizedBox(height: r.s(12)),
              TextField(
                controller: TextEditingController(text: _rules),
                onChanged: (v) => setState(() => _rules = v),
                maxLines: 12,
                decoration: InputDecoration(
                  hintText: '## Regra 1\nNão seja ofensivo...\n\n## Regra 2\n...',
                  filled: true,
                  fillColor: context.nexusTheme.backgroundPrimary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.s(8)),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(fontSize: r.fs(13)),
              ),
              SizedBox(height: r.s(8)),
              Text(
                'Dica: Use ## para títulos de regras, **negrito** para ênfase.',
                style: TextStyle(
                    color: Colors.grey[600], fontSize: r.fs(11)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // TAB: Home Layout — Customização da página inicial
  // ========================================================================
  Widget _buildHomeLayoutTab() {
    final s = getStrings();
    final r = context.r;
    final visible = Map<String, dynamic>.from(
        _homeLayout['sections_visible'] as Map<String, dynamic>? ?? {});
    final bottomBar = Map<String, dynamic>.from(
        _homeLayout['bottom_bar'] as Map<String, dynamic>? ?? {});
    final welcomeBanner = Map<String, dynamic>.from(
        _homeLayout['welcome_banner'] as Map<String, dynamic>? ?? {});
    final featuredType = _homeLayout['featured_type'] as String? ?? 'list';

    return ListView(
      padding: EdgeInsets.all(r.s(16)),
      children: [
        // ---- SEÇÕES VISÍVEIS ----
        Text(s.homePageSections,
            style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: r.s(6)),
        Text(s.chooseSections,
            style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12))),
        SizedBox(height: r.s(16)),

        ..._buildSectionToggles(visible),

        SizedBox(height: r.s(24)),

        // ---- TIPO DE DESTAQUE ----
        Text(s.highlightsStyle,
            style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: r.s(12)),
        Row(
          children: [
            _FeaturedStyleOption(
              icon: Icons.list_rounded,
              label: s.list,
              isSelected: featuredType == 'list',
              onTap: () {
                setState(() => _homeLayout['featured_type'] = 'list');
              },
            ),
            SizedBox(width: r.s(8)),
            _FeaturedStyleOption(
              icon: Icons.grid_view_rounded,
              label: s.grid2,
              isSelected: featuredType == 'grid',
              onTap: () {
                setState(() => _homeLayout['featured_type'] = 'grid');
              },
            ),
            SizedBox(width: r.s(8)),
            _FeaturedStyleOption(
              icon: Icons.view_carousel_rounded,
              label: s.carousel,
              isSelected: featuredType == 'carousel',
              onTap: () {
                setState(() => _homeLayout['featured_type'] = 'carousel');
              },
            ),
          ],
        ),

        SizedBox(height: r.s(24)),

        // ---- WELCOME BANNER ----
        Text(s.welcomeBanner,
            style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: r.s(6)),
        Text(s.customBannerDesc,
            style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12))),
        SizedBox(height: r.s(12)),

        Container(
          padding: EdgeInsets.all(r.s(16)),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(r.s(12)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ativar Banner',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                value: welcomeBanner['enabled'] as bool? ?? false,
                activeColor: context.nexusTheme.accentPrimary,
                onChanged: (val) {
                  setState(() {
                    welcomeBanner['enabled'] = val;
                    _homeLayout['welcome_banner'] = welcomeBanner;
                  });
                },
              ),
              if (welcomeBanner['enabled'] == true) ...[
                SizedBox(height: r.s(8)),
                TextField(
                  controller: TextEditingController(
                      text: welcomeBanner['text'] as String? ?? ''),
                  onChanged: (v) {
                    welcomeBanner['text'] = v;
                    _homeLayout['welcome_banner'] = welcomeBanner;
                  },
                  decoration: InputDecoration(
                    hintText: s.bannerTextHint,
                    prefixIcon: Icon(Icons.text_fields_rounded, size: r.s(18)),
                    filled: true,
                    fillColor: context.nexusTheme.backgroundPrimary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(r.s(8)),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                  style: TextStyle(fontSize: r.fs(13)),
                ),
                SizedBox(height: r.s(8)),
                TextField(
                  controller: TextEditingController(
                      text: welcomeBanner['image_url'] as String? ?? ''),
                  onChanged: (v) {
                    welcomeBanner['image_url'] = v.isEmpty ? null : v;
                    _homeLayout['welcome_banner'] = welcomeBanner;
                  },
                  decoration: InputDecoration(
                    hintText: s.bannerImageUrlOptional,
                    prefixIcon: Icon(Icons.image_rounded, size: r.s(18)),
                    filled: true,
                    fillColor: context.nexusTheme.backgroundPrimary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(r.s(8)),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                  style: TextStyle(fontSize: r.fs(13)),
                ),
                SizedBox(height: r.s(8)),
                TextField(
                  controller: TextEditingController(
                      text: welcomeBanner['link'] as String? ?? ''),
                  onChanged: (v) {
                    welcomeBanner['link'] = v.isEmpty ? null : v;
                    _homeLayout['welcome_banner'] = welcomeBanner;
                  },
                  decoration: InputDecoration(
                    hintText: s.linkOnClick,
                    prefixIcon: Icon(Icons.link_rounded, size: r.s(18)),
                    filled: true,
                    fillColor: context.nexusTheme.backgroundPrimary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(r.s(8)),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                  style: TextStyle(fontSize: r.fs(13)),
                ),
              ],
            ],
          ),
        ),

        SizedBox(height: r.s(24)),

        // ---- BOTTOM BAR ----
        Text(s.bottomBar, style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: r.s(6)),
        Text(s.configureBottomNav,
            style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12))),
        SizedBox(height: r.s(12)),

        Container(
          padding: EdgeInsets.all(r.s(16)),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(r.s(12)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mostrar Membros Online',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(s.showOnlineCount,
                    style:
                        TextStyle(color: Colors.grey[500], fontSize: r.fs(12))),
                value: bottomBar['show_online_count'] as bool? ?? true,
                activeColor: context.nexusTheme.accentPrimary,
                onChanged: (val) {
                  setState(() {
                    bottomBar['show_online_count'] = val;
                    _homeLayout['bottom_bar'] = bottomBar;
                  });
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.showCreateButton,
                    style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(s.centralButtonCreatePosts,
                    style:
                        TextStyle(color: Colors.grey[500], fontSize: r.fs(12))),
                value: bottomBar['show_create_button'] as bool? ?? true,
                activeColor: context.nexusTheme.accentPrimary,
                onChanged: (val) {
                  setState(() {
                    bottomBar['show_create_button'] = val;
                    _homeLayout['bottom_bar'] = bottomBar;
                  });
                },
              ),
            ],
          ),
        ),

        SizedBox(height: r.s(24)),

        // ---- RESET ----
        Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _homeLayout = _defaultHomeLayout();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(s.layoutResetToDefault),
                  backgroundColor: context.nexusTheme.warning,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.s(10))),
                ),
              );
            },
            icon: Icon(Icons.restore_rounded, color: Colors.grey[500]),
            label: Text(s.resetToDefault,
                style: TextStyle(color: Colors.grey[500])),
          ),
        ),
        SizedBox(height: r.s(32)),
      ],
    );
  }

  List<Widget> _buildSectionToggles(Map<String, dynamic> visible) {
    final s = getStrings();
    final r = context.r;
    final sections = [
      _SectionToggle(
        key: 'check_in',
        icon: Icons.check_circle_rounded,
        label: s.checkInLabel,
        description: s.dailyCheckInBarDesc,
      ),
      _SectionToggle(
        key: 'live_chats',
        icon: Icons.live_tv_rounded,
        label: s.liveChats2,
        description: 'Carrossel horizontal de chatrooms ativos',
      ),
      _SectionToggle(
        key: 'guidelines',
        icon: Icons.gavel_rounded,
        label: s.guidelines,
        description: 'Aba de regras/guidelines da comunidade',
      ),
      _SectionToggle(
        key: 'featured_posts',
        icon: Icons.star_rounded,
        label: s.featured,
        description: s.featuredPostsTab,
      ),
      _SectionToggle(
        key: 'latest_feed',
        icon: Icons.new_releases_rounded,
        label: s.recentFeed,
        description: s.recentPostsTab,
      ),
      _SectionToggle(
        key: 'public_chats',
        icon: Icons.chat_bubble_rounded,
        label: s.publicChatsLabel,
        description: s.communityPublicChatsTab,
      ),
    ];

    return sections.map((s) {
      final isEnabled = visible[s.key] as bool? ?? true;
      return Container(
        margin: EdgeInsets.only(bottom: r.s(8)),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(r.s(12)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: SwitchListTile(
          secondary: Icon(s.icon,
              color: isEnabled ? context.nexusTheme.accentPrimary : Colors.grey[600]),
          title: Text(s.label,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(s.description,
              style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12))),
          value: isEnabled,
          activeColor: context.nexusTheme.accentPrimary,
          onChanged: (val) {
            setState(() {
              visible[s.key] = val;
              _homeLayout['sections_visible'] = visible;
            });
          },
        ),
      );
    }).toList();
  }

  // ========================================================================
  // TAB: Stats
  // ========================================================================
  // ─────────────────────────────────────────────────────────────────────────
  // ABA: CATEGORIAS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCategoriesTab() {
    return _CategoriesTabContent(
      communityId: widget.communityId,
      themeColor: _parseColor(_themeColor),
    );
  }

  Widget _buildStatsTab() {
    final s = getStrings();
    final r = context.r;
    return RefreshIndicator(
      onRefresh: () async {
        await _loadStats();
        if (!mounted) return;
        setState(() {});
      },
      child: ListView(
        padding: EdgeInsets.all(r.s(16)),
        children: [
          Text(s.communityStatistics,
              style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: r.s(16)),
          _StatCard(
            icon: Icons.people_rounded,
            label: s.totalMembers2,
            value: _community?.membersCount.toString() ?? '0',
            color: context.nexusTheme.accentPrimary,
          ),
          _StatCard(
            icon: Icons.person_add_rounded,
            label: s.newMembers7d,
            value: _newMembers7d.toString(),
            color: context.nexusTheme.success,
          ),
          _StatCard(
            icon: Icons.article_rounded,
            label: s.posts,
            value: _totalPosts.toString(),
            color: context.nexusTheme.accentSecondary,
          ),
          _StatCard(
            icon: Icons.chat_rounded,
            label: s.chats,
            value: _totalChats.toString(),
            color: const Color(0xFF00BCD4),
          ),
          SizedBox(height: r.s(24)),
          Text(s.moderation, style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: r.s(12)),
          _StatCard(
            icon: Icons.flag_rounded,
            label: s.pendingReports,
            value: _pendingFlags.toString(),
            color: context.nexusTheme.error,
          ),
          _StatCard(
            icon: Icons.gavel_rounded,
            label: s.moderationActions30d,
            value: _modActions30d.toString(),
            color: context.nexusTheme.warning,
          ),
          SizedBox(height: r.s(12)),
          // Botão de acesso à Central de Moderação Avançada
          GestureDetector(
            onTap: () => context.push(
              '/community/${widget.communityId}/moderation',
            ),
            child: Container(
              padding: EdgeInsets.all(r.s(14)),
              decoration: BoxDecoration(
                color: context.nexusTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(r.s(12)),
                border: Border.all(
                    color: context.nexusTheme.error.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(r.s(8)),
                    decoration: BoxDecoration(
                      color: context.nexusTheme.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(r.s(8)),
                    ),
                    child: Icon(Icons.shield_rounded,
                        color: context.nexusTheme.error, size: r.s(20)),
                  ),
                  SizedBox(width: r.s(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Central de Moderação',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: r.fs(14),
                          ),
                        ),
                        Text(
                          'Denúncias, snapshots e bot de controle',
                          style: TextStyle(
                            color: context.nexusTheme.textSecondary,
                            fontSize: r.fs(12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_pendingFlags > 0)
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(8), vertical: r.s(4)),
                      decoration: BoxDecoration(
                        color: context.nexusTheme.error,
                        borderRadius: BorderRadius.circular(r.s(10)),
                      ),
                      child: Text(
                        '$_pendingFlags',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: r.fs(12),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  SizedBox(width: r.s(8)),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: r.s(14),
                      color: context.nexusTheme.textSecondary),
                ],
              ),
            ),
          ),
          SizedBox(height: r.s(24)),
          Text(s.currentConfiguration,
              style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: r.s(12)),
          Container(
            padding: EdgeInsets.all(r.s(16)),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(r.s(12)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                _InfoRow(s.entryType, _joinType.toUpperCase()),
                _InfoRow(s.visibility, _listedStatus.toUpperCase()),
                _InfoRow('Cor Tema', _themeColor),
                _InfoRow(
                    s.activeModules,
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
// WIDGET: _CategoriesTabContent
// ============================================================================

class _CategoriesTabContent extends ConsumerStatefulWidget {
  final String communityId;
  final Color themeColor;

  const _CategoriesTabContent({
    required this.communityId,
    required this.themeColor,
  });

  @override
  ConsumerState<_CategoriesTabContent> createState() =>
      _CategoriesTabContentState();
}

class _CategoriesTabContentState
    extends ConsumerState<_CategoriesTabContent> {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await SupabaseService.table('community_categories')
          .select()
          .eq('community_id', widget.communityId)
          .order('sort_order')
          .order('name');
      if (mounted) {
        setState(() {
          _categories = (res as List).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddDialog({Map<String, dynamic>? existing}) async {
    final nameCtrl =
        TextEditingController(text: existing?['name'] as String? ?? '');
    final descCtrl =
        TextEditingController(text: existing?['description'] as String? ?? '');
    String selectedColor = existing?['color'] as String? ?? '#7C4DFF';
    final r = context.r;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            existing == null ? 'Nova Categoria' : 'Editar Categoria',
            style: TextStyle(fontSize: r.fs(16), fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome da categoria',
                  hintText: 'Ex: Arte, Tecnologia, Humor...',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Cor: '),
                  const SizedBox(width: 8),
                  ...['#7C4DFF', '#00BCD4', '#FF5722', '#4CAF50', '#FF9800', '#E91E63']
                      .map((c) => GestureDetector(
                            onTap: () => setS(() => selectedColor = c),
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Color(int.parse(
                                    c.replaceFirst('#', '0xFF'))),
                                shape: BoxShape.circle,
                                border: selectedColor == c
                                    ? Border.all(
                                        color: Colors.white, width: 2)
                                    : null,
                              ),
                            ),
                          ))
                      .toList(),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                existing == null ? 'Criar' : 'Salvar',
                style: TextStyle(color: widget.themeColor),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    if (nameCtrl.text.trim().isEmpty) return;

    try {
      final result = await SupabaseService.rpc(
        'manage_community_category',
        params: {
          'p_community_id': widget.communityId,
          'p_action': existing == null ? 'create' : 'update',
          if (existing != null) 'p_category_id': existing['id'],
          'p_name': nameCtrl.text.trim(),
          'p_description': descCtrl.text.trim(),
          'p_color': selectedColor,
        },
      );
      final res = Map<String, dynamic>.from(result as Map);
      if (res['success'] == true) {
        await _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(existing == null
                ? 'Categoria criada!'
                : 'Categoria atualizada!'),
            backgroundColor: context.nexusTheme.accentPrimary,
            behavior: SnackBarBehavior.floating,
          ));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erro: ${res["error"]}'),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: ${e.toString()}')));
      }
    }
  }

  Future<void> _deleteCategory(Map<String, dynamic> cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Excluir Categoria'),
        content: Text(
            'Excluir a categoria "${cat['name']}"? Os posts desta categoria não serão excluídos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await SupabaseService.rpc(
        'manage_community_category',
        params: {
          'p_community_id': widget.communityId,
          'p_action': 'delete',
          'p_category_id': cat['id'],
        },
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Categoria excluída.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(),
        backgroundColor: widget.themeColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nova Categoria',
            style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: context.nexusTheme.accentPrimary))
          : _categories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.label_off_rounded,
                          size: r.s(56), color: Colors.grey[600]),
                      SizedBox(height: r.s(16)),
                      Text(
                        'Nenhuma categoria criada',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: r.fs(16),
                        ),
                      ),
                      SizedBox(height: r.s(8)),
                      Text(
                        'Crie categorias para organizar os posts da comunidade.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: r.fs(13),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                        r.s(16), r.s(16), r.s(16), r.s(100)),
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => SizedBox(height: r.s(8)),
                    itemBuilder: (_, i) {
                      final cat = _categories[i];
                      final catColor = Color(int.parse(
                          (cat['color'] as String? ?? '#7C4DFF')
                              .replaceFirst('#', '0xFF')));
                      return Container(
                        decoration: BoxDecoration(
                          color: context.nexusTheme.surfacePrimary,
                          borderRadius: BorderRadius.circular(r.s(12)),
                          border: Border.all(
                            color: catColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: r.s(40),
                            height: r.s(40),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(r.s(8)),
                            ),
                            child: Icon(
                              Icons.label_rounded,
                              color: catColor,
                              size: r.s(20),
                            ),
                          ),
                          title: Text(
                            cat['name'] as String? ?? '',
                            style: TextStyle(
                              color: context.nexusTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: r.fs(14),
                            ),
                          ),
                          subtitle: (cat['description'] as String?)?.isNotEmpty == true
                              ? Text(
                                  cat['description'] as String,
                                  style: TextStyle(
                                    color: context.nexusTheme.textSecondary,
                                    fontSize: r.fs(12),
                                  ),
                                )
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit_rounded,
                                    color: Colors.grey[400], size: r.s(18)),
                                onPressed: () => _showAddDialog(existing: cat),
                                tooltip: 'Editar',
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline_rounded,
                                    color: Colors.red[400], size: r.s(18)),
                                onPressed: () => _deleteCategory(cat),
                                tooltip: 'Excluir',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
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

class _SectionToggle {
  final String key;
  final IconData icon;
  final String label;
  final String description;
  const _SectionToggle({
    required this.key,
    required this.icon,
    required this.label,
    required this.description,
  });
}

class _FeaturedStyleOption extends ConsumerWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FeaturedStyleOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: r.s(16)),
          decoration: BoxDecoration(
            color: isSelected
                ? context.nexusTheme.accentPrimary.withValues(alpha: 0.15)
                : context.surfaceColor,
            borderRadius: BorderRadius.circular(r.s(12)),
            border: Border.all(
              color: isSelected
                  ? context.nexusTheme.accentPrimary
                  : Colors.white.withValues(alpha: 0.05),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? context.nexusTheme.accentPrimary : Colors.grey[600],
                  size: r.s(24)),
              SizedBox(height: r.s(6)),
              Text(label,
                  style: TextStyle(
                    color: isSelected
                        ? context.nexusTheme.accentPrimary
                        : context.nexusTheme.textSecondary,
                    fontSize: r.fs(11),
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessOption extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: r.s(8)),
        padding: EdgeInsets.all(r.s(16)),
        decoration: BoxDecoration(
          color: isSelected
              ? context.nexusTheme.accentPrimary.withValues(alpha: 0.1)
              : context.surfaceColor,
          borderRadius: BorderRadius.circular(r.s(12)),
          border: Border.all(
            color: isSelected
                ? context.nexusTheme.accentPrimary
                : Colors.white.withValues(alpha: 0.05),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: context.nexusTheme.accentPrimary.withValues(alpha: 0.2),
                    blurRadius: 8,
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? context.nexusTheme.accentPrimary : Colors.grey[600]),
            SizedBox(width: r.s(16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(description,
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: r.fs(12))),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: context.nexusTheme.accentPrimary),
          ],
        ),
      ),
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
    final r = context.r;
    return Container(
      margin: EdgeInsets.only(bottom: r.s(8)),
      padding: EdgeInsets.all(r.s(16)),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(12)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: r.s(44),
            height: r.s(44),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(r.s(12)),
            ),
            child: Icon(icon, color: color),
          ),
          SizedBox(width: r.s(16)),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: r.fs(18),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends ConsumerWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.s(6)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey[500], fontSize: r.fs(13))),
          Text(value,
              style:
                  TextStyle(fontWeight: FontWeight.w600, fontSize: r.fs(13))),
        ],
      ),
    );
  }
}

/// Campo de texto para edição de conteúdo editorial da comunidade.
class _ContentField extends StatelessWidget {
  final String label;
  final String hint;
  final String value;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final IconData icon;

  const _ContentField({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
    this.maxLines = 4,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      padding: EdgeInsets.all(r.s(16)),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(12)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: context.nexusTheme.accentPrimary, size: r.s(20)),
              SizedBox(width: r.s(10)),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: r.fs(14))),
            ],
          ),
          SizedBox(height: r.s(10)),
          TextField(
            controller: TextEditingController(text: value),
            onChanged: onChanged,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: context.nexusTheme.backgroundPrimary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(8)),
                borderSide: BorderSide.none,
              ),
            ),
            style: TextStyle(fontSize: r.fs(13)),
          ),
        ],
      ),
    );
  }
}
