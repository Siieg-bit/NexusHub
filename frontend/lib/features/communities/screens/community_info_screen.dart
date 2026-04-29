import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/community_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../providers/community_shared_providers.dart';
import '../providers/community_detail_providers.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/services/deep_link_service.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../../auth/providers/auth_provider.dart';

// =============================================================================
// CommunityInfoScreen — Tela de informações da comunidade (redesign moderno)
//
// Exibida para não-membros ao tentar acessar /community/:id.
// Após o join, navega diretamente para a comunidade.
// =============================================================================
class CommunityInfoScreen extends ConsumerStatefulWidget {
  final String communityId;

  const CommunityInfoScreen({super.key, required this.communityId});

  @override
  ConsumerState<CommunityInfoScreen> createState() =>
      _CommunityInfoScreenState();
}

class _CommunityInfoScreenState extends ConsumerState<CommunityInfoScreen>
    with SingleTickerProviderStateMixin {
  bool _isJoining = false;
  late AnimationController _joinController;
  late Animation<double> _joinScale;

  @override
  void initState() {
    super.initState();
    _joinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _joinScale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _joinController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _joinController.dispose();
    super.dispose();
  }

  Future<void> _joinCommunity(CommunityModel community) async {
    final s = getStrings();
    if (_isJoining) return;
    setState(() => _isJoining = true);
    _joinController.forward().then((_) => _joinController.reverse());
    try {
      await SupabaseService.rpc('join_community', params: {
        'p_community_id': widget.communityId,
      });
      if (!mounted) return;
      ref.invalidate(userCommunitiesProvider);
      ref.invalidate(communityMembershipProvider(widget.communityId));
      ref.invalidate(communityDetailProvider(widget.communityId));
      final welcomeMsg = community.welcomeMessage;
      final displayMsg = (welcomeMsg.isNotEmpty)
          ? welcomeMsg
          : s.joinedCommunityName(community.name);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(displayMsg),
          backgroundColor: context.nexusTheme.accentSecondary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      // Navega para a comunidade após o join
      context.replace('/community/${widget.communityId}');
    } catch (e) {
      debugPrint('[CommunityInfoScreen] joinCommunity error: $e');
      if (!mounted) return;
      setState(() => _isJoining = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erro ao entrar na comunidade. Tente novamente.'),
          backgroundColor: context.nexusTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showMoreMenu(BuildContext context, CommunityModel community) {
    final r = context.r;
    final theme = context.nexusTheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: theme.surfacePrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          top: r.s(8),
          bottom: MediaQuery.of(ctx).padding.bottom + r.s(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: r.s(36),
              height: r.s(4),
              margin: EdgeInsets.only(bottom: r.s(12)),
              decoration: BoxDecoration(
                color: theme.textHint.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Compartilhar
            _MoreMenuItem(
              icon: Icons.share_rounded,
              label: 'Compartilhar comunidade',
              onTap: () {
                Navigator.pop(ctx);
                final link = community.link ??
                    'https://nexushub.app/community/${community.endpoint ?? community.id}';
                DeepLinkService.shareUrl(
                  type: 'community',
                  targetId: community.id,
                  title: community.name,
                  text:
                      'Confira a comunidade ${community.name} no NexusHub!\n$link',
                );
              },
            ),
            // Copiar link
            _MoreMenuItem(
              icon: Icons.link_rounded,
              label: 'Copiar link',
              onTap: () {
                Navigator.pop(ctx);
                final link = community.link ??
                    'https://nexushub.app/community/${community.endpoint ?? community.id}';
                Clipboard.setData(ClipboardData(text: link));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Link copiado!'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            // Copiar ID
            _MoreMenuItem(
              icon: Icons.tag_rounded,
              label: 'Copiar ID da comunidade',
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(
                    text: community.endpoint ?? community.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('ID copiado!'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            Divider(color: theme.textHint.withValues(alpha: 0.15), height: 1),
            // Reportar
            _MoreMenuItem(
              icon: Icons.flag_rounded,
              label: 'Reportar comunidade',
              color: theme.error,
              onTap: () {
                Navigator.pop(ctx);
                _showReportDialog(context, community);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context, CommunityModel community) {
    final theme = context.nexusTheme;
    final reasons = [
      'Conteúdo inapropriado',
      'Spam ou enganoso',
      'Assédio ou bullying',
      'Discurso de ódio',
      'Violação de direitos autorais',
      'Outro',
    ];
    String? selected;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: theme.surfacePrimary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Reportar comunidade',
              style: TextStyle(
                  color: theme.textPrimary, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons
                .map((r) => RadioListTile<String>(
                      value: r,
                      groupValue: selected,
                      onChanged: (v) => setS(() => selected = v),
                      title: Text(r,
                          style: TextStyle(
                              color: theme.textPrimary, fontSize: 14)),
                      activeColor: theme.accentPrimary,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ))
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar',
                  style: TextStyle(color: theme.textSecondary)),
            ),
            TextButton(
              onPressed: selected == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      try {
                        await SupabaseService.rpc('report_content', params: {
                          'p_content_type': 'community',
                          'p_content_id': community.id,
                          'p_reason': selected,
                        });
                      } catch (e) {
                        debugPrint('[CommunityInfoScreen] report error: $e');
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Denúncia enviada. Obrigado!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              child: Text('Enviar',
                  style: TextStyle(
                      color: theme.accentPrimary,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return context.nexusTheme.accentPrimary;
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  String _languageLabel(String code) {
    switch (code.toLowerCase()) {
      case 'pt':
        return '🇧🇷 Português';
      case 'en':
        return '🇺🇸 English';
      case 'es':
        return '🇪🇸 Español';
      case 'fr':
        return '🇫🇷 Français';
      case 'de':
        return '🇩🇪 Deutsch';
      case 'ja':
        return '🇯🇵 日本語';
      case 'ko':
        return '🇰🇷 한국어';
      case 'zh':
        return '🇨🇳 中文';
      default:
        return code.toUpperCase();
    }
  }

  String _categoryLabel(String cat) {
    const map = {
      'anime': 'Anime & Manga',
      'gaming': 'Games',
      'music': 'Música',
      'art': 'Arte',
      'sports': 'Esportes',
      'technology': 'Tecnologia',
      'science': 'Ciência',
      'movies': 'Filmes & Séries',
      'books': 'Livros',
      'food': 'Gastronomia',
      'travel': 'Viagens',
      'fashion': 'Moda',
      'fitness': 'Fitness',
      'education': 'Educação',
      'general': 'Geral',
    };
    return map[cat.toLowerCase()] ?? cat;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final communityAsync =
        ref.watch(communityDetailProvider(widget.communityId));
    final membershipAsync =
        ref.watch(communityMembershipProvider(widget.communityId));
    final membersAsync =
        ref.watch(communityMembersProvider(widget.communityId));

    return communityAsync.when(
      loading: () => _buildLoading(context),
      error: (e, _) => _buildError(context, e.toString()),
      data: (community) {
        final isMember = membershipAsync.valueOrNull != null;
        // Se já é membro, redireciona para a tela da comunidade
        if (isMember) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.replace('/community/${widget.communityId}');
            }
          });
          return _buildLoading(context);
        }

        final themeColor = _parseColor(community.themeColor);
        final gradientEnd = community.themeGradientEnd != null
            ? _parseColor(community.themeGradientEnd!)
            : themeColor.withValues(alpha: 0.4);
        final bannerUrl =
            community.bannerForContext('info') ?? community.bannerUrl;
        final members = membersAsync.valueOrNull ?? [];
        final tags = community.communityTags.isNotEmpty
            ? community.communityTags
            : (community.configuration['tags'] as List?)
                    ?.map((t) => t.toString())
                    .toList() ??
                [];

        return Scaffold(
          backgroundColor: context.nexusTheme.backgroundPrimary,
          body: CustomScrollView(
            slivers: [
              // ── Hero Banner SliverAppBar ────────────────────────────────────
              SliverAppBar(
                expandedHeight: r.s(260),
                pinned: true,
                stretch: true,
                backgroundColor: context.nexusTheme.backgroundPrimary,
                leading: Padding(
                  padding: EdgeInsets.all(r.s(8)),
                  child: _GlassButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                actions: [
                  Padding(
                    padding: EdgeInsets.only(right: r.s(8), top: r.s(8)),
                    child: _GlassButton(
                      icon: Icons.more_horiz_rounded,
                      onTap: () => _showMoreMenu(context, community),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.blurBackground,
                  ],
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Banner
                      if (bannerUrl != null && bannerUrl.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: bannerUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [themeColor, gradientEnd],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [themeColor, gradientEnd],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [themeColor, gradientEnd],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      // Gradient overlay bottom
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: r.s(120),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                context.nexusTheme.backgroundPrimary,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Body content ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: r.s(20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header: Icon + Name + Tagline ──────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Community icon with glow
                          Container(
                            width: r.s(80),
                            height: r.s(80),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(r.s(18)),
                              border:
                                  Border.all(color: themeColor, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: themeColor.withValues(alpha: 0.45),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: community.iconUrl != null &&
                                    community.iconUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: community.iconUrl!,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color:
                                        themeColor.withValues(alpha: 0.2),
                                    child: Icon(Icons.groups_rounded,
                                        color: themeColor, size: r.s(36)),
                                  ),
                          ),
                          SizedBox(width: r.s(14)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  community.name,
                                  style: TextStyle(
                                    color: context.nexusTheme.textPrimary,
                                    fontSize: r.fs(22),
                                    fontWeight: FontWeight.w900,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (community.tagline.isNotEmpty) ...[
                                  SizedBox(height: r.s(4)),
                                  Text(
                                    community.tagline,
                                    style: TextStyle(
                                      color:
                                          context.nexusTheme.textSecondary,
                                      fontSize: r.fs(13),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: r.s(20)),

                      // ── Stats row ──────────────────────────────────────────
                      _StatsRow(
                        community: community,
                        themeColor: themeColor,
                        formatCount: _formatCount,
                      ),

                      SizedBox(height: r.s(16)),

                      // ── Tags ───────────────────────────────────────────────
                      if (tags.isNotEmpty) ...[
                        Wrap(
                          spacing: r.s(8),
                          runSpacing: r.s(8),
                          children: tags.map((tag) {
                            return Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: r.s(12), vertical: r.s(5)),
                              decoration: BoxDecoration(
                                color: themeColor.withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(r.s(20)),
                                border: Border.all(
                                  color: themeColor.withValues(alpha: 0.35),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '#$tag',
                                style: TextStyle(
                                  color: themeColor,
                                  fontSize: r.fs(12),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        SizedBox(height: r.s(20)),
                      ],

                      // ── Join / Open button ─────────────────────────────────
                      ScaleTransition(
                        scale: _joinScale,
                        child: SizedBox(
                          width: double.infinity,
                          child: _buildJoinButton(
                              context, community, themeColor, s),
                        ),
                      ),

                      SizedBox(height: r.s(28)),

                      // ── About ──────────────────────────────────────────────
                      if (community.aboutText.isNotEmpty ||
                          community.description.isNotEmpty) ...[
                        _SectionHeader(
                          icon: Icons.info_outline_rounded,
                          label: 'Sobre a Comunidade',
                          themeColor: themeColor,
                        ),
                        SizedBox(height: r.s(10)),
                        Text(
                          community.aboutText.isNotEmpty
                              ? community.aboutText
                              : community.description,
                          style: TextStyle(
                            color: context.nexusTheme.textSecondary,
                            fontSize: r.fs(14),
                            height: 1.65,
                          ),
                        ),
                        SizedBox(height: r.s(28)),
                      ],

                      // ── Membros recentes ───────────────────────────────────
                      if (members.isNotEmpty) ...[
                        _SectionHeader(
                          icon: Icons.people_outline_rounded,
                          label:
                              'Membros (${_formatCount(community.membersCount)})',
                          themeColor: themeColor,
                        ),
                        SizedBox(height: r.s(12)),
                        SizedBox(
                          height: r.s(72),
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: members.length.clamp(0, 12),
                            separatorBuilder: (_, __) =>
                                SizedBox(width: r.s(12)),
                            itemBuilder: (ctx, i) {
                              final member = members[i];
                              final profile =
                                  member['profiles'] as Map<String, dynamic>?;
                              final nickname =
                                  profile?['nickname'] as String? ?? '?';
                              final iconUrl =
                                  profile?['icon_url'] as String?;
                              final role =
                                  member['role'] as String? ?? 'member';
                              return _MemberAvatar(
                                nickname: nickname,
                                iconUrl: iconUrl,
                                role: role,
                                themeColor: themeColor,
                              );
                            },
                          ),
                        ),
                        SizedBox(height: r.s(28)),
                      ],

                      // ── Regras ─────────────────────────────────────────────
                      if (community.rules.isNotEmpty) ...[
                        _SectionHeader(
                          icon: Icons.gavel_rounded,
                          label: 'Regras da Comunidade',
                          themeColor: themeColor,
                        ),
                        SizedBox(height: r.s(12)),
                        _RulesCard(
                            rules: community.rules, themeColor: themeColor),
                        SizedBox(height: r.s(28)),
                      ],

                      // ── Informações gerais ─────────────────────────────────
                      _SectionHeader(
                        icon: Icons.settings_outlined,
                        label: 'Informações',
                        themeColor: themeColor,
                      ),
                      SizedBox(height: r.s(12)),
                      _InfoCard(
                        children: [
                          _InfoRow(
                            icon: Icons.category_outlined,
                            label: 'Categoria',
                            value: _categoryLabel(community.category),
                          ),
                          _InfoRow(
                            icon: Icons.language_rounded,
                            label: 'Idioma',
                            value: _languageLabel(community.primaryLanguage),
                          ),
                          _InfoRow(
                            icon: community.joinType == 'open'
                                ? Icons.lock_open_rounded
                                : community.joinType == 'request'
                                    ? Icons.how_to_reg_rounded
                                    : Icons.lock_rounded,
                            label: 'Acesso',
                            value: community.joinType == 'open'
                                ? 'Aberta para todos'
                                : community.joinType == 'request'
                                    ? 'Solicitar entrada'
                                    : 'Somente convite',
                          ),
                          _InfoRow(
                            icon: Icons.article_outlined,
                            label: 'Postagens',
                            value: _formatCount(community.postsCount),
                          ),
                          if (community.rpgModeEnabled)
                            _InfoRow(
                              icon: Icons.auto_awesome_rounded,
                              label: 'Modo RPG',
                              value: 'Ativado',
                              valueColor: themeColor,
                            ),
                          _InfoRow(
                            icon: Icons.tag_rounded,
                            label: 'ID',
                            value:
                                community.endpoint ?? community.id.substring(0, 8),
                            onTap: () {
                              Clipboard.setData(ClipboardData(
                                  text: community.endpoint ?? community.id));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('ID copiado!'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            trailing: Icon(Icons.copy_rounded,
                                size: r.s(14),
                                color: context.nexusTheme.textHint),
                          ),
                          _InfoRow(
                            icon: Icons.calendar_today_rounded,
                            label: 'Criada em',
                            value:
                                '${community.createdAt.day.toString().padLeft(2, '0')}/${community.createdAt.month.toString().padLeft(2, '0')}/${community.createdAt.year}',
                          ),
                        ],
                      ),

                      SizedBox(
                          height:
                              MediaQuery.of(context).padding.bottom + r.s(40)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJoinButton(BuildContext context, CommunityModel community,
      Color themeColor, dynamic s) {
    final r = context.r;
    final isMember = ref.watch(communityMembershipProvider(widget.communityId))
            .valueOrNull !=
        null;

    return GestureDetector(
      onTapDown: (_) => _joinController.forward(),
      onTapUp: (_) {
        _joinController.reverse();
        if (isMember) {
          context.replace('/community/${community.id}');
        } else {
          _joinCommunity(community);
        }
      },
      onTapCancel: () => _joinController.reverse(),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: r.s(16)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              themeColor,
              themeColor.withValues(alpha: 0.75),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(r.s(28)),
          boxShadow: [
            BoxShadow(
              color: themeColor.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isJoining)
              SizedBox(
                width: r.s(20),
                height: r.s(20),
                child: const CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            else ...[
              Icon(
                isMember
                    ? Icons.open_in_new_rounded
                    : community.joinType == 'open'
                        ? Icons.group_add_rounded
                        : community.joinType == 'request'
                            ? Icons.how_to_reg_rounded
                            : Icons.lock_open_rounded,
                color: Colors.white,
                size: r.s(20),
              ),
              SizedBox(width: r.s(10)),
              Text(
                isMember
                    ? 'ABRIR COMUNIDADE'
                    : community.joinType == 'open'
                        ? 'ENTRAR NA COMUNIDADE'
                        : community.joinType == 'request'
                            ? 'SOLICITAR ENTRADA'
                            : 'ENTRAR COM CONVITE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: r.fs(15),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildError(BuildContext context, String msg) {
    final r = context.r;
    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Text(
          'Comunidade não encontrada.\n$msg',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: context.nexusTheme.textSecondary, fontSize: r.fs(14)),
        ),
      ),
    );
  }
}

// =============================================================================
// Sub-widgets
// =============================================================================

/// Botão circular com efeito glass para o AppBar
class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15), width: 1),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Row de estatísticas (membros, posts, atividade)
class _StatsRow extends StatelessWidget {
  final CommunityModel community;
  final Color themeColor;
  final String Function(int) formatCount;

  const _StatsRow({
    required this.community,
    required this.themeColor,
    required this.formatCount,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;
    final heat = (community.communityHeat / 100).clamp(0.0, 1.0);
    final heatLabel = heat > 0.7
        ? 'Alta'
        : heat > 0.4
            ? 'Média'
            : 'Baixa';
    final heatColor = heat > 0.7
        ? Colors.orange
        : heat > 0.4
            ? Colors.yellow[700]!
            : Colors.green;

    return Container(
      padding: EdgeInsets.all(r.s(16)),
      decoration: BoxDecoration(
        color: theme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(16)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          _StatItem(
            value: formatCount(community.membersCount),
            label: 'Membros',
            icon: Icons.people_rounded,
            color: themeColor,
          ),
          _StatDivider(),
          _StatItem(
            value: formatCount(community.postsCount),
            label: 'Posts',
            icon: Icons.article_rounded,
            color: themeColor,
          ),
          _StatDivider(),
          _StatItem(
            value: heatLabel,
            label: 'Atividade',
            icon: Icons.local_fire_department_rounded,
            color: heatColor,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: r.s(20)),
          SizedBox(height: r.s(4)),
          Text(
            value,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: r.fs(16),
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: theme.textHint,
              fontSize: r.fs(11),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}

/// Cabeçalho de seção com ícone e linha decorativa
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color themeColor;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(r.s(6)),
          decoration: BoxDecoration(
            color: themeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(r.s(8)),
          ),
          child: Icon(icon, color: themeColor, size: r.s(16)),
        ),
        SizedBox(width: r.s(10)),
        Text(
          label,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: r.fs(15),
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(width: r.s(10)),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ],
    );
  }
}

/// Avatar de membro na lista horizontal
class _MemberAvatar extends StatelessWidget {
  final String nickname;
  final String? iconUrl;
  final String role;
  final Color themeColor;

  const _MemberAvatar({
    required this.nickname,
    this.iconUrl,
    required this.role,
    required this.themeColor,
  });

  Color _roleColor(Color base) {
    switch (role) {
      case 'leader':
      case 'admin':
        return Colors.amber;
      case 'curator':
      case 'moderator':
        return Colors.lightBlue;
      case 'agent':
        return Colors.purple;
      default:
        return base;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;
    final roleColor = _roleColor(themeColor);
    return Column(
      children: [
        Container(
          width: r.s(46),
          height: r.s(46),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: roleColor, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: iconUrl != null && iconUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: iconUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: themeColor.withValues(alpha: 0.2),
                    child: Icon(Icons.person_rounded,
                        color: themeColor, size: r.s(22)),
                  ),
                )
              : Container(
                  color: themeColor.withValues(alpha: 0.2),
                  child: Icon(Icons.person_rounded,
                      color: themeColor, size: r.s(22)),
                ),
        ),
        SizedBox(height: r.s(4)),
        SizedBox(
          width: r.s(52),
          child: Text(
            nickname,
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: r.fs(10),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// Card de regras com numeração
class _RulesCard extends StatefulWidget {
  final String rules;
  final Color themeColor;

  const _RulesCard({required this.rules, required this.themeColor});

  @override
  State<_RulesCard> createState() => _RulesCardState();
}

class _RulesCardState extends State<_RulesCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;
    final lines = widget.rules
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    final preview = _expanded ? lines : lines.take(3).toList();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(r.s(16)),
      decoration: BoxDecoration(
        color: theme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(14)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...preview.asMap().entries.map((e) {
            return Padding(
              padding: EdgeInsets.only(bottom: r.s(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: r.s(22),
                    height: r.s(22),
                    decoration: BoxDecoration(
                      color: widget.themeColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${e.key + 1}',
                        style: TextStyle(
                          color: widget.themeColor,
                          fontSize: r.fs(11),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: r.s(10)),
                  Expanded(
                    child: Text(
                      e.value,
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: r.fs(13),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (lines.length > 3)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded ? 'Ver menos' : 'Ver todas as ${lines.length} regras',
                style: TextStyle(
                  color: widget.themeColor,
                  fontSize: r.fs(13),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Card de informações gerais
class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(14)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: children
            .asMap()
            .entries
            .map((e) => Column(
                  children: [
                    e.value,
                    if (e.key < children.length - 1)
                      Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.06),
                        indent: 16,
                        endIndent: 16,
                      ),
                  ],
                ))
            .toList(),
      ),
    );
  }
}

/// Linha de informação dentro do _InfoCard
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(r.s(14)),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: r.s(16), vertical: r.s(13)),
        child: Row(
          children: [
            Icon(icon, color: theme.textHint, size: r.s(17)),
            SizedBox(width: r.s(12)),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: r.fs(13),
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: valueColor ?? theme.textPrimary,
                fontSize: r.fs(13),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (trailing != null) ...[
              SizedBox(width: r.s(6)),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Item do menu "mais opções"
class _MoreMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _MoreMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;
    final c = color ?? theme.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: r.s(20), vertical: r.s(14)),
        child: Row(
          children: [
            Icon(icon, color: c, size: r.s(22)),
            SizedBox(width: r.s(16)),
            Text(
              label,
              style: TextStyle(
                color: c,
                fontSize: r.fs(15),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
