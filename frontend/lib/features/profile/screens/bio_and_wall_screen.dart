import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/utils/responsive.dart';
import '../widgets/rich_bio.dart';
import '../widgets/wall_comment_sheet.dart';

/// Tela expandida de Biografia & Mural — acessível ao tocar no título "Biografia"
/// no perfil de comunidade. Exibe a bio completa e o mural do usuário.
class BioAndWallScreen extends ConsumerStatefulWidget {
  final String userId;
  final String communityId;
  final String displayName;
  final String? avatarUrl;
  final String bio;
  final bool isOwnProfile;

  const BioAndWallScreen({
    super.key,
    required this.userId,
    required this.communityId,
    required this.displayName,
    this.avatarUrl,
    required this.bio,
    required this.isOwnProfile,
  });

  @override
  ConsumerState<BioAndWallScreen> createState() => _BioAndWallScreenState();
}

class _BioAndWallScreenState extends ConsumerState<BioAndWallScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: context.textPrimary, size: r.s(20)),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.displayName,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: r.fs(16),
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              s.bioAndWallTitle,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: r.fs(12),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: AppTheme.primaryColor,
          dividerColor: Colors.transparent,
          labelStyle:
              TextStyle(fontWeight: FontWeight.w700, fontSize: r.fs(14)),
          unselectedLabelStyle:
              TextStyle(fontWeight: FontWeight.w500, fontSize: r.fs(14)),
          tabs: [
            Tab(text: s.biography),
            Tab(text: s.wall),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Aba: Biografia ──────────────────────────────────────────────
          _BioTab(
            bio: widget.bio,
            avatarUrl: widget.avatarUrl,
            displayName: widget.displayName,
          ),
          // ── Aba: Mural ──────────────────────────────────────────────────
          WallCommentSheet(
            wallUserId: widget.userId,
            isOwnWall: widget.isOwnProfile,
            asBottomSheet: false,
          ),
        ],
      ),
    );
  }
}

class _BioTab extends StatelessWidget {
  final String bio;
  final String? avatarUrl;
  final String displayName;

  const _BioTab({
    required this.bio,
    this.avatarUrl,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    return SingleChildScrollView(
      padding: EdgeInsets.all(r.s(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + nome
          Row(
            children: [
              CircleAvatar(
                radius: r.s(28),
                backgroundColor: Colors.grey[800],
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                child: avatarUrl == null
                    ? Icon(Icons.person_rounded,
                        color: Colors.grey[500], size: r.s(28))
                    : null,
              ),
              SizedBox(width: r.s(14)),
              Expanded(
                child: Text(
                  displayName,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: r.fs(18),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: r.s(24)),
          // Divider
          Divider(color: Colors.white.withValues(alpha: 0.08)),
          SizedBox(height: r.s(16)),
          // Bio completa
          if (bio.isNotEmpty)
            RichBioRenderer(
              rawContent: bio,
              selectable: true,
              fontSize: r.fs(15),
              fallbackTextColor: Colors.grey[300],
            )
          else
            Center(
              child: Padding(
                padding: EdgeInsets.only(top: r.s(40)),
                child: Text(
                  '—',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: r.fs(14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
