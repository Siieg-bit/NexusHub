import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/community_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../providers/community_shared_providers.dart';

/// ============================================================================
/// CommunityInfoScreen — Tela de detalhes/informações da comunidade.
///
/// Referência visual: Amino Apps (prints de referência).
/// Exibe: banner, ícone, nome, membros, idioma, Amino ID, descrição,
/// tags, botão "Entrar na comunidade" / "Abrir comunidade".
/// ============================================================================
class CommunityInfoScreen extends ConsumerStatefulWidget {
  final String communityId;

  const CommunityInfoScreen({super.key, required this.communityId});

  @override
  ConsumerState<CommunityInfoScreen> createState() =>
      _CommunityInfoScreenState();
}

class _CommunityInfoScreenState extends ConsumerState<CommunityInfoScreen> {
  CommunityModel? _community;
  bool _isLoading = true;
  bool _isMember = false;
  bool _isJoining = false;
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _loadCommunity();
  }

  Future<void> _loadCommunity() async {
    try {
      final res = await SupabaseService.table('communities')
          .select()
          .eq('id', widget.communityId)
          .maybeSingle();

      if (res == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final community = CommunityModel.fromJson(res);

      // Check membership
      bool isMember = false;
      final userId = SupabaseService.currentUserId;
      if (userId != null) {
        final memberCheck = await SupabaseService.table('community_members')
            .select('id')
            .eq('community_id', widget.communityId)
            .eq('user_id', userId)
            .maybeSingle();
        isMember = memberCheck != null;
      }

      // Extract tags from configuration or tagline
      List<String> tags = [];
      if (community.configuration.containsKey('tags')) {
        final rawTags = community.configuration['tags'];
        if (rawTags is List) {
          tags = rawTags.map((t) => t.toString()).toList();
        }
      }
      // Fallback: split category as tag
      if (tags.isEmpty &&
          community.category.isNotEmpty &&
          community.category != 'general') {
        tags = [community.category];
      }

      if (mounted) {
        setState(() {
          _community = community;
          _isMember = isMember;
          _tags = tags;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinCommunity() async {
    if (_isJoining) return;
    setState(() => _isJoining = true);

    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      await SupabaseService.table('community_members').insert({
        'community_id': widget.communityId,
        'user_id': userId,
        'role': 'member',
      });

      if (mounted) {
        setState(() {
          _isMember = true;
          _isJoining = false;
        });
        ref.invalidate(userCommunitiesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Você entrou em "${_community?.name ?? ''}"!'),
            backgroundColor: AppTheme.accentColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isJoining = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erro ao entrar na comunidade.'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.aminoPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.scaffoldBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.accentColor),
        ),
      );
    }

    if (_community == null) {
      return Scaffold(
        backgroundColor: context.scaffoldBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Text(
            'Comunidade não encontrada.',
            style: TextStyle(color: context.textSecondary, fontSize: r.fs(14)),
          ),
        ),
      );
    }

    final community = _community!;
    final themeColor = _parseColor(community.themeColor);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          // ── AppBar com banner ──
          SliverAppBar(
            expandedHeight: r.s(200),
            pinned: true,
            backgroundColor: context.surfaceColor,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share_rounded,
                      color: Colors.white, size: 20),
                ),
                onPressed: () {
                  // Share community link
                  final link =
                      community.link ?? community.endpoint ?? community.id;
                  Clipboard.setData(ClipboardData(text: link));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Link copiado!'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.more_horiz_rounded,
                      color: Colors.white, size: 20),
                ),
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Banner image
                  if (community.bannerUrl != null &&
                      community.bannerUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: community.bannerUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              themeColor,
                              themeColor.withValues(alpha: 0.5)
                            ],
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              themeColor,
                              themeColor.withValues(alpha: 0.5)
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            themeColor,
                            themeColor.withValues(alpha: 0.5)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  // Gradient overlay at bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: r.s(80),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            context.scaffoldBg.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Content ──
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: r.s(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: r.s(8)),

                  // ── Icon + Name + Members + Language ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Community icon
                      Container(
                        width: r.s(80),
                        height: r.s(80),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(r.s(16)),
                          color: context.cardBg,
                          border: Border.all(color: themeColor, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
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
                            : Icon(Icons.groups_rounded,
                                color: context.textHint, size: r.s(36)),
                      ),
                      SizedBox(width: r.s(16)),
                      // Name + stats
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              community.name,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: r.fs(22),
                                fontWeight: FontWeight.w900,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: r.s(4)),
                            // Activity bar (visual only)
                            _buildActivityBar(context, community.communityHeat),
                            SizedBox(height: r.s(4)),
                            Text(
                              '${_formatCount(community.membersCount)} Members',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: r.fs(14),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: r.s(2)),
                            // Language badge
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: r.s(8), vertical: r.s(2)),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(r.s(4)),
                              ),
                              child: Text(
                                _languageLabel(community.primaryLanguage),
                                style: TextStyle(
                                  color: Colors.grey[300],
                                  fontSize: r.fs(11),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: r.s(20)),

                  // ── Amino ID ──
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(16), vertical: r.s(10)),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(r.s(8)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Amino ID: ',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: r.fs(13),
                          ),
                        ),
                        Text(
                          community.endpoint ?? community.id.substring(0, 8),
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: r.fs(15),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: r.s(16)),

                  // ── Tagline ──
                  if (community.tagline.isNotEmpty) ...[
                    Text(
                      community.tagline,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: r.fs(14),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: r.s(12)),
                  ],

                  // ── Tags ──
                  if (_tags.isNotEmpty) ...[
                    Wrap(
                      spacing: r.s(6),
                      runSpacing: r.s(6),
                      alignment: WrapAlignment.center,
                      children: _tags.map((tag) {
                        return Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: r.s(12), vertical: r.s(6)),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(r.s(16)),
                            border: Border.all(
                              color:
                                  AppTheme.accentColor.withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: AppTheme.accentColor,
                              fontSize: r.fs(12),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: r.s(16)),
                  ],

                  // ── Join / Open button ──
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: () {
                        if (_isMember) {
                          context.push('/community/${community.id}');
                        } else {
                          _joinCommunity();
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: r.s(14)),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor,
                          borderRadius: BorderRadius.circular(r.s(24)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!_isMember) ...[
                              Icon(Icons.lock_rounded,
                                  color: Colors.white, size: r.s(18)),
                              SizedBox(width: r.s(8)),
                            ],
                            if (_isJoining)
                              SizedBox(
                                width: r.s(18),
                                height: r.s(18),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            else
                              Text(
                                _isMember
                                    ? 'ABRIR COMUNIDADE'
                                    : 'JOIN COMMUNITY',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: r.fs(15),
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: r.s(24)),

                  // ── Description ──
                  if (community.description.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Description',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: r.fs(16),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(height: r.s(10)),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        community.description,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: r.fs(14),
                          height: 1.5,
                        ),
                      ),
                    ),
                    SizedBox(height: r.s(24)),
                  ],

                  // ── Additional info ──
                  _buildInfoRow(context, 'Categoria', community.category),
                  _buildInfoRow(
                      context,
                      'Tipo de acesso',
                      community.joinType == 'open'
                          ? 'Aberta'
                          : community.joinType == 'request'
                              ? 'Solicitar entrada'
                              : 'Somente convite'),
                  _buildInfoRow(context, 'Criada em',
                      '${community.createdAt.day}/${community.createdAt.month}/${community.createdAt.year}'),

                  SizedBox(
                      height: MediaQuery.of(context).padding.bottom + r.s(32)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityBar(BuildContext context, double heat) {
    final r = context.r;
    final normalizedHeat = (heat / 100).clamp(0.0, 1.0);
    final barCount = 5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: r.s(6), vertical: r.s(2)),
          decoration: BoxDecoration(
            color: Colors.green[800],
            borderRadius: BorderRadius.circular(r.s(4)),
          ),
          child: Text(
            'Activity',
            style: TextStyle(
              color: Colors.green[200],
              fontSize: r.fs(10),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(width: r.s(4)),
        ...List.generate(barCount, (i) {
          final filled = i < (normalizedHeat * barCount).ceil();
          return Container(
            width: r.s(16),
            height: r.s(12),
            margin: EdgeInsets.only(right: r.s(2)),
            decoration: BoxDecoration(
              color: filled
                  ? Color.lerp(Colors.green, Colors.orange, i / barCount)
                  : Colors.grey[800],
              borderRadius: BorderRadius.circular(r.s(2)),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final r = context.r;
    return Padding(
      padding: EdgeInsets.only(bottom: r.s(12)),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: r.fs(13),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: r.fs(13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _languageLabel(String code) {
    switch (code.toLowerCase()) {
      case 'pt':
        return 'Português';
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'fr':
        return 'Français';
      case 'de':
        return 'Deutsch';
      case 'ja':
        return '日本語';
      case 'ko':
        return '한국어';
      case 'zh':
        return '中文';
      default:
        return code;
    }
  }
}
