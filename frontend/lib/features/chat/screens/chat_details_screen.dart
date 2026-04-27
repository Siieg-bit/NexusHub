// =============================================================================
// ChatDetailsScreen — Página de detalhes do chat público
//
// Exibe:
//   • Capa do chat (banner) com gradiente
//   • Avatar + nome + categoria + descrição
//   • Contagem de membros
//   • Grid de membros (avatares)
//   • Botão de convidar
//   • Ações de moderação (apenas para host/co_host)
// =============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/deep_link_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/app_strings.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/chat_cover_picker.dart';
import '../widgets/chat_moderation_sheet.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

class ChatDetailsScreen extends ConsumerStatefulWidget {
  final String threadId;
  const ChatDetailsScreen({super.key, required this.threadId});

  @override
  ConsumerState<ChatDetailsScreen> createState() => _ChatDetailsScreenState();
}

class _ChatDetailsScreenState extends ConsumerState<ChatDetailsScreen> {
  Map<String, dynamic>? _threadInfo;
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  String? _callerRole;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userId = SupabaseService.currentUserId;

      // Carregar info do thread
      final threadRes = await SupabaseService.table('chat_threads')
          .select()
          .eq('id', widget.threadId)
          .single();
      final threadInfo = Map<String, dynamic>.from(threadRes as Map);

      // Determinar role do usuário atual
      String? role;
      if (userId != null) {
        final hostId = threadInfo['host_id'] as String?;
        final coHosts = (threadInfo['co_hosts'] as List?) ?? [];
        if (userId == hostId) {
          role = 'host';
        } else if (coHosts.contains(userId)) {
          role = 'co_host';
        } else {
          final memberData = await SupabaseService.table('chat_members')
              .select('role')
              .eq('thread_id', widget.threadId)
              .eq('user_id', userId)
              .maybeSingle();
          role = memberData?['role'] as String?;
        }
      }

      // Carregar membros (limitado a 24 para o grid)
      final membersRes = await SupabaseService.table('chat_members')
          .select(
              '*, profiles!chat_members_user_id_fkey(id, nickname, icon_url)')
          .eq('thread_id', widget.threadId)
          .order('joined_at', ascending: true)
          .limit(24);
      final members =
          List<Map<String, dynamic>>.from(membersRes as List? ?? []);

      if (mounted) {
        setState(() {
          _threadInfo = threadInfo;
          _members = members;
          _callerRole = role ?? 'member';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[ChatDetails] Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openInvite() {
    final title = _threadInfo?['title'] as String? ?? '';
    DeepLinkService.shareUrl(
      type: 'chat',
      targetId: widget.threadId,
      title: title,
      text: title,
    );
  }

  void _openModeration() {
    showChatModerationSheet(
      context: context,
      threadId: widget.threadId,
      callerRole: _callerRole,
      isAnnouncementOnly:
          _threadInfo?['is_announcement_only'] as bool? ?? false,
      currentCover: _threadInfo?['cover_image_url'] as String?,
      currentTitle: _threadInfo?['title'] as String?,
      communityId: _threadInfo?['community_id'] as String?,
      onTitleChanged: () => _loadData(),
      onCoverChanged: (url) {
        if (mounted) {
          setState(() => _threadInfo?['cover_image_url'] = url);
        }
      },
      onAnnouncementOnlyChanged: (val) {
        if (mounted) {
          setState(() => _threadInfo?['is_announcement_only'] = val);
        }
      },
    );
  }

  void _editCover() {
    showChatCoverPicker(
      context: context,
      threadId: widget.threadId,
      currentCover: _threadInfo?['cover_image_url'] as String?,
      canEdit: true,
      onChanged: (url) {
        if (mounted) setState(() => _threadInfo?['cover_image_url'] = url);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final s = ref.watch(stringsProvider);
    final theme = context.nexusTheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: theme.backgroundPrimary,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: theme.iconPrimary, size: r.s(22)),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(
              color: theme.accentPrimary, strokeWidth: 2),
        ),
      );
    }

    final title = _threadInfo?['title'] as String? ?? '';
    final description = _threadInfo?['description'] as String?;
    final coverUrl = _threadInfo?['cover_image_url'] as String?;
    final iconUrl = _threadInfo?['icon_url'] as String?;
    final category = _threadInfo?['category'] as String?;
    final memberCount = _members.length;
    final isHost = _callerRole == 'host' || _callerRole == 'co_host';
    final currentUser = ref.read(currentUserProvider);
    final canManage = isHost || (currentUser?.isTeamMember ?? false);

    return Scaffold(
      backgroundColor: theme.backgroundPrimary,
      body: CustomScrollView(
        slivers: [
          // ── AppBar com capa ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: r.s(220),
            pinned: true,
            backgroundColor: theme.backgroundPrimary,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded,
                  color: Colors.white, size: r.s(22)),
              onPressed: () => context.pop(),
            ),
            actions: [
              if (canManage)
                IconButton(
                  icon: Icon(Icons.edit_rounded,
                      color: Colors.white, size: r.s(20)),
                  onPressed: _editCover,
                  tooltip: 'Editar capa',
                ),
              if (canManage)
                IconButton(
                  icon: Icon(Icons.settings_rounded,
                      color: Colors.white, size: r.s(20)),
                  onPressed: _openModeration,
                  tooltip: s.settings,
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Capa / banner
                  if (coverUrl != null)
                    CachedNetworkImage(
                      imageUrl: coverUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: theme.surfacePrimary,
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.accentPrimary.withValues(alpha: 0.7),
                            theme.accentSecondary.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                    ),
                  // Gradiente escuro na parte inferior para legibilidade
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                          stops: const [0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Conteúdo principal ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: r.s(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: r.s(20)),

                  // Avatar + nome + categoria
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar
                      Container(
                        width: r.s(64),
                        height: r.s(64),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: theme.accentPrimary, width: r.s(2)),
                          color: theme.surfacePrimary,
                        ),
                        child: ClipOval(
                          child: (iconUrl != null)
                              ? CachedNetworkImage(
                                  imageUrl: iconUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Icon(
                                    Icons.group_rounded,
                                    color: theme.iconSecondary,
                                    size: r.s(32),
                                  ),
                                )
                              : Icon(
                                  Icons.group_rounded,
                                  color: theme.iconSecondary,
                                  size: r.s(32),
                                ),
                        ),
                      ),
                      SizedBox(width: r.s(14)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: r.fs(20),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (category != null && category.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: r.s(4)),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: r.s(8), vertical: r.s(2)),
                                  decoration: BoxDecoration(
                                    color: theme.accentPrimary
                                        .withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(r.s(20)),
                                    border: Border.all(
                                        color: theme.accentPrimary
                                            .withValues(alpha: 0.4),
                                        width: 1),
                                  ),
                                  child: Text(
                                    _categoryLabel(category),
                                    style: TextStyle(
                                      color: theme.accentPrimary,
                                      fontSize: r.fs(11),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: r.s(16)),

                  // Descrição
                  if (description != null && description.isNotEmpty) ...[
                    Text(
                      description,
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: r.fs(14),
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: r.s(16)),
                  ],

                  // Contagem de membros
                  Row(
                    children: [
                      Icon(Icons.people_rounded,
                          color: theme.iconSecondary, size: r.s(16)),
                      SizedBox(width: r.s(6)),
                      Text(
                        '$memberCount ${s.members.toLowerCase()}',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: r.fs(13),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: r.s(20)),

                  // Botão de convidar
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openInvite,
                      icon: Icon(Icons.person_add_rounded,
                          size: r.s(18), color: Colors.white),
                      label: Text(
                        s.invite,
                        style: TextStyle(
                          fontSize: r.fs(14),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accentPrimary,
                        padding: EdgeInsets.symmetric(vertical: r.s(14)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.s(12)),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),

                  SizedBox(height: r.s(28)),

                  // Seção de membros
                  Text(
                    s.chatMembers,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: r.fs(16),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: r.s(14)),

                  // Grid de membros
                  _buildMembersGrid(r, theme, s),

                  SizedBox(height: r.s(32)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersGrid(Responsive r, dynamic theme, AppStrings s) {
    if (_members.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: r.s(20)),
          child: Text(
            s.noMemberFound,
            style:
                TextStyle(color: theme.textSecondary, fontSize: r.fs(13)),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: r.s(12),
        mainAxisSpacing: r.s(16),
        childAspectRatio: 0.75,
      ),
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final member = _members[index];
        final profile =
            member['profiles'] as Map<String, dynamic>? ?? {};
        final nickname = profile['nickname'] as String? ?? s.user;
        final iconUrl = profile['icon_url'] as String?;
        final userId = profile['id'] as String? ?? '';

        return GestureDetector(
          onTap: () {
            if (userId.isNotEmpty) {
              context.push('/profile/$userId');
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: r.s(56),
                height: r.s(56),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.surfacePrimary,
                  border: Border.all(
                    color: theme.accentPrimary.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: (iconUrl != null)
                      ? CachedNetworkImage(
                          imageUrl: iconUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Icon(
                            Icons.person_rounded,
                            color: theme.iconSecondary,
                            size: r.s(28),
                          ),
                        )
                      : Icon(
                          Icons.person_rounded,
                          color: theme.iconSecondary,
                          size: r.s(28),
                        ),
                ),
              ),
              SizedBox(height: r.s(6)),
              Text(
                nickname,
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: r.fs(11),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  String _categoryLabel(String category) {
    const labels = {
      'general': 'Geral',
      'gaming': 'Games',
      'anime': 'Anime',
      'music': 'Música',
      'art': 'Arte',
      'tech': 'Tecnologia',
      'sports': 'Esportes',
      'movies': 'Filmes',
      'books': 'Livros',
      'food': 'Comida',
      'travel': 'Viagens',
      'fashion': 'Moda',
      'science': 'Ciência',
      'news': 'Notícias',
      'other': 'Outro',
    };
    return labels[category] ?? category;
  }
}
