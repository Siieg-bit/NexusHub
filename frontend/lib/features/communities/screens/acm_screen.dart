import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';

/// ACM — Amino Community Manager.
/// Gerenciamento de módulos (JSONB), Join Types, customização visual,
/// home layout e estatísticas.
class AcmScreen extends ConsumerStatefulWidget {
  final String communityId;
  const AcmScreen({super.key, required this.communityId});

  @override
  State<AcmScreen> createState() => _AcmScreenState();
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
  String _iconUrl = '';
  String _bannerUrl = '';
  String _welcomeMessage = '';

  // Home Layout customization
  Map<String, dynamic> _homeLayout = {};

  // Stats (loaded from DB)
  int _newMembers7d = 0;
  int _pendingFlags = 0;
  int _modActions30d = 0;
  int _totalPosts = 0;
  int _totalChats = 0;

  final _tabs = ['Módulos', 'Acesso', 'Visual', 'Home', 'Stats'];

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
    final r = context.r;
    try {
      final updates = <String, dynamic>{
        'configuration': _config,
        'join_type': _joinType,
        'listed_status': _listedStatus,
        'theme_color': _themeColor,
        'welcome_message': _welcomeMessage,
        'home_layout': _homeLayout,
      };
      if (_iconUrl.isNotEmpty) updates['icon_url'] = _iconUrl;
      if (_bannerUrl.isNotEmpty) updates['banner_url'] = _bannerUrl;

      await SupabaseService.table('communities')
          .update(updates)
          .eq('id', widget.communityId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.settingsSaved),
            backgroundColor: AppTheme.primaryColor,
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
      return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
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
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey[500],
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
                _buildHomeLayoutTab(),
                _buildStatsTab(),
              ],
            ),
    );
  }

  // ========================================================================
  // TAB: Módulos
  // ========================================================================
  Widget _buildModulesTab() {
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
                color: isEnabled ? AppTheme.primaryColor : Colors.grey[600]),
            title: Text(mod.label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(mod.description,
                style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12))),
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
    final r = context.r;
    final currentColor = _parseColor(_themeColor);

    return ListView(
      padding: EdgeInsets.all(r.s(16)),
      children: [
        Text(s.visualCustomization,
            style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: r.s(16)),

        // Color Picker
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
                  const Icon(Icons.color_lens_rounded,
                      color: AppTheme.primaryColor),
                  SizedBox(width: r.s(12)),
                  const Text('Cor Tema',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Container(
                    width: r.s(32),
                    height: r.s(32),
                    decoration: BoxDecoration(
                      color: currentColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
                ],
              ),
              SizedBox(height: r.s(16)),
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
                      width: r.s(36),
                      height: r.s(36),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: r.s(3),
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
                          ? Icon(Icons.check_rounded,
                              color: Colors.white, size: r.s(18))
                          : null,
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: r.s(12)),
              TextField(
                controller: TextEditingController(text: _themeColor),
                onChanged: (v) {
                  if (v.startsWith('#') && v.length == 7) {
                    setState(() => _themeColor = v);
                  }
                },
                decoration: InputDecoration(
                  hintText: '#RRGGBB',
                  prefixIcon: Icon(Icons.tag_rounded, size: r.s(18)),
                  filled: true,
                  fillColor: context.scaffoldBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.s(8)),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
                style: TextStyle(fontSize: r.fs(14)),
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
                  Icon(Icons.image_rounded, color: AppTheme.primaryColor),
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
                  fillColor: context.scaffoldBg,
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
                  Icon(Icons.panorama_rounded, color: AppTheme.primaryColor),
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
                  fillColor: context.scaffoldBg,
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
  // TAB: Home Layout — Customização da página inicial
  // ========================================================================
  Widget _buildHomeLayoutTab() {
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
                activeColor: AppTheme.primaryColor,
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
                    fillColor: context.scaffoldBg,
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
                    fillColor: context.scaffoldBg,
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
                    fillColor: context.scaffoldBg,
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
                activeColor: AppTheme.primaryColor,
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
                activeColor: AppTheme.primaryColor,
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
                  backgroundColor: AppTheme.warningColor,
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
              color: isEnabled ? AppTheme.primaryColor : Colors.grey[600]),
          title: Text(s.label,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(s.description,
              style: TextStyle(color: Colors.grey[500], fontSize: r.fs(12))),
          value: isEnabled,
          activeColor: AppTheme.primaryColor,
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
  Widget _buildStatsTab() {
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
            color: AppTheme.primaryColor,
          ),
          _StatCard(
            icon: Icons.person_add_rounded,
            label: s.newMembers7d,
            value: _newMembers7d.toString(),
            color: AppTheme.successColor,
          ),
          _StatCard(
            icon: Icons.article_rounded,
            label: s.posts,
            value: _totalPosts.toString(),
            color: AppTheme.accentColor,
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
            color: AppTheme.errorColor,
          ),
          _StatCard(
            icon: Icons.gavel_rounded,
            label: s.moderationActions30d,
            value: _modActions30d.toString(),
            color: AppTheme.warningColor,
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
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: r.s(16)),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.15)
                : context.surfaceColor,
            borderRadius: BorderRadius.circular(r.s(12)),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor
                  : Colors.white.withValues(alpha: 0.05),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? AppTheme.primaryColor : Colors.grey[600],
                  size: r.s(24)),
              SizedBox(height: r.s(6)),
              Text(label,
                  style: TextStyle(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : context.textSecondary,
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
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: r.s(8)),
        padding: EdgeInsets.all(r.s(16)),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : context.surfaceColor,
          borderRadius: BorderRadius.circular(r.s(12)),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : Colors.white.withValues(alpha: 0.05),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? AppTheme.primaryColor : Colors.grey[600]),
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
              Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor),
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
      final s = ref.watch(stringsProvider);
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
      final s = ref.watch(stringsProvider);
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
