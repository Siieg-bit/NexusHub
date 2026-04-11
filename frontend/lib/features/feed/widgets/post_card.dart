import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/post_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/amino_animations.dart';
import 'block_content_renderer.dart';
import '../../../core/widgets/cosmetic_avatar.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/app_strings.dart';

/// Card de post no feed — estilo Amino Apps (web-preview).
/// Suporta todos os 9 tipos de post com renderização interativa.
class PostCard extends ConsumerStatefulWidget {
  final PostModel post;
  final VoidCallback? onLike;
  final bool showCommunity;

  const PostCard({
    super.key,
    required this.post,
    this.onLike,
    this.showCommunity = true,
  });

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard>
    with SingleTickerProviderStateMixin {
  late PostModel _post;
  int? _selectedPollOption;
  int? _selectedQuizOption;
  bool _quizAnswered = false;
  late AnimationController _likeController;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _likeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      // Post diferente: sincronizar tudo
      _post = widget.post;
      _selectedPollOption = null;
      _selectedQuizOption = null;
      _quizAnswered = false;
    } else if (oldWidget.post.isLiked != widget.post.isLiked ||
        oldWidget.post.likesCount != widget.post.likesCount) {
      // Bug #8 fix: Mesmo post, mas is_liked ou likesCount mudou no provider
      // (ex: refresh do feed após navegar de volta). Sincronizar estado local
      // sem resetar as seleções de poll/quiz.
      _post = widget.post;
    }
  }

  @override
  void dispose() {
    _likeController.dispose();
    super.dispose();
  }

  // ── REPOST ──
  Future<void> _doRepost() async {
    final s = ref.read(stringsProvider);
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) return;

    // Impedir auto-repost
    if (_post.authorId == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não é possível republicar seu próprio post.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Impedir repost de repost
    if (_post.type == 'repost') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não é possível republicar um repost.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // Modal de confirmação
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _RepostConfirmSheet(post: _post),
    );

    if (confirm != true || !mounted) return;

    try {
      await SupabaseService.rpc('repost_post', params: {
        'p_original_post_id': _post.id,
        'p_community_id': _post.communityId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.repostSuccess),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      final isAlreadyReposted = msg.contains('já republicou');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAlreadyReposted ? s.repostAlreadyExists : s.anErrorOccurredTryAgain),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isAlreadyReposted ? AppTheme.warningColor : AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _toggleLike() async {
    final wasLiked = _post.isLiked;
    setState(() {
      _post = _post.copyWith(
        isLiked: !wasLiked,
        likesCount: _post.likesCount + (wasLiked ? -1 : 1),
      );
    });
    if (!wasLiked) {
      _likeController.forward(from: 0);
    }
    try {
      await SupabaseService.client.rpc('toggle_like_with_reputation', params: {
        'p_community_id': _post.communityId,
        'p_user_id': SupabaseService.currentUserId,
        'p_post_id': _post.id,
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _post = _post.copyWith(
            isLiked: wasLiked,
            likesCount: _post.likesCount + (wasLiked ? 1 : -1),
          );
        });
      }
    }
    widget.onLike?.call();
  }

  Future<void> _votePoll(int optionIndex) async {
    if (_selectedPollOption != null) return;
    setState(() => _selectedPollOption = optionIndex);
    try {
      await SupabaseService.table('poll_votes').upsert({
        'post_id': _post.id,
        'user_id': SupabaseService.currentUserId,
        'option_index': optionIndex,
      });
    } catch (e) {
      debugPrint('[post_card] Erro: $e');
    }
  }

  void _answerQuiz(int optionIndex) {
    if (_quizAnswered) return;
    setState(() {
      _selectedQuizOption = optionIndex;
      _quizAnswered = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return AminoAnimations.cardPress(
      onTap: () => context.push('/post/${_post.id}'),
      child: Container(
        margin: EdgeInsets.only(bottom: r.s(10)),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(r.s(12)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.03),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Community header (se showCommunity) ──
            if (widget.showCommunity) _buildCommunityHeader(),

            // ── Author header ──
            _buildAuthorHeader(context),

            // ── Title (oculto para reposts — título fica no card aninhado) ──
            if (_post.type != 'repost' && (_post.title ?? '').isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(r.s(12), 0, r.s(12), r.s(4)),
                child: Text(
                  _post.title ?? '',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: r.fs(14),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // ── Content (oculto para reposts — conteúdo fica no card aninhado) ──
            if (_post.type != 'repost') ...[  
              if (_post.hasBlockContent)
                Padding(
                  padding: EdgeInsets.fromLTRB(r.s(12), 0, r.s(12), r.s(8)),
                  child: BlockContentPreview(
                    blocks: _post.contentBlocks ?? [],
                    maxLines: 3,
                  ),
                )
              else
                Padding(
                  padding: EdgeInsets.fromLTRB(r.s(12), 0, r.s(12), r.s(8)),
                  child: Text(
                    _post.content,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: r.fs(12),
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],

            // ── Type-specific content ──
            _buildTypeSpecificContent(),

            // ── Media (oculto para reposts — mídia fica no card aninhado) ──
            if (_post.type != 'repost' && (_post.mediaUrl ?? '').isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(r.s(12), 0, r.s(12), r.s(8)),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(r.s(10)),
                    child: CachedNetworkImage(
                      imageUrl: _post.mediaUrl ?? '',
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(r.s(10)),
                        ),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryColor,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(r.s(10)),
                        ),
                        child: Icon(Icons.broken_image_rounded,
                            color: context.textHint),
                      ),
                    ),
                  ),
                ),
              ),

            // ── Actions footer ──
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COMMUNITY HEADER (small, above author)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildCommunityHeader() {
    final s = ref.read(stringsProvider);
    final r = context.r;
    return Padding(
      padding: EdgeInsets.fromLTRB(r.s(12), r.s(10), r.s(12), 0),
      child: Row(
        children: [
          // Community icon
          if (_post.author?.iconUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(r.s(4)),
              child: Container(
                width: r.s(16),
                height: r.s(16),
                color: context.surfaceColor,
                child: Icon(Icons.groups_rounded,
                    size: r.s(10), color: context.textHint),
              ),
            ),
          SizedBox(width: r.s(6)),
          Expanded(
            child: Text(
              _post.communityId,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: r.fs(10),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_post.isPinned)
            Text(s.pinnedLabel,
                style: TextStyle(
                    color: Colors.yellow[600],
                    fontSize: r.fs(8),
                    fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AUTHOR HEADER — Estilo Amino
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildAuthorHeader(BuildContext context) {
    final s = ref.read(stringsProvider);
    final r = context.r;
    final displayAuthorName =
        _post.authorLocalNickname?.trim().isNotEmpty == true
            ? _post.authorLocalNickname!.trim()
            : (_post.author?.nickname ?? s.user);
    final displayAuthorAvatar =
        _post.authorLocalIconUrl?.trim().isNotEmpty == true
            ? _post.authorLocalIconUrl!.trim()
            : _post.author?.iconUrl;
    return Padding(
      padding: EdgeInsets.fromLTRB(r.s(12), r.s(10), r.s(12), r.s(8)),
      child: Row(
        children: [
          // Avatar (36px, rounded-full)
          CosmeticAvatar(
            userId: _post.authorId,
            avatarUrl: displayAuthorAvatar,
            size: r.s(36),
            onTap: () => context.push('/user/${_post.authorId}'),
          ),
          SizedBox(width: r.s(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + Role badge
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayAuthorName,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: r.fs(13),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Role badges (Leader, Curator)
                    if (_post.author != null &&
                        (_post.authorLocalLevel ?? 0) > 10) ...[
                      SizedBox(width: r.s(6)),
                      // Role badge baseado no nível LOCAL da comunidade
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                // Level badge + time + type
                Row(
                  children: [
                    // Level badge (gradient pill)
                    if (_post.author != null && (_post.authorLocalLevel ?? 0) > 0)
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.s(6), vertical: 2),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.getLevelColor(_post.authorLocalLevel ?? 0),
                              AppTheme.getLevelColor(_post.authorLocalLevel ?? 0)
                                  .withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(r.s(10)),
                        ),
                        child: Text(
                          s.lvBadge(_post.authorLocalLevel ?? 0),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: r.fs(8),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    SizedBox(width: r.s(8)),
                    // Time ago
                    Text(
                      timeago.format(_post.createdAt, locale: 'pt_BR'),
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: r.fs(10)),
                    ),
                    // Type badge
                    if (_post.type != 'normal') ...[
                      SizedBox(width: r.s(8)),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.s(6), vertical: 1),
                        decoration: BoxDecoration(
                          color: _typeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(r.s(6)),
                        ),
                        child: Text(
                          _typeLabel,
                          style: TextStyle(
                              color: _typeColor,
                              fontSize: r.fs(8),
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Featured/Pinned badge
          if (_post.isFeatured)
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: r.s(6), vertical: r.s(3)),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(r.s(6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded,
                      size: r.s(10), color: AppTheme.warningColor),
                  SizedBox(width: 2),
                  Text(s.featured,
                      style: TextStyle(
                          color: AppTheme.warningColor,
                          fontSize: r.fs(8),
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TYPE-SPECIFIC CONTENT
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildTypeSpecificContent() {
    switch (_post.type) {
      case 'poll':
        return _buildPoll();
      case 'quiz':
        return _buildQuiz();
      case 'qa':
        return _buildQA();
      case 'link':
      case 'external':
        return _buildLinkPreview();
      case 'crosspost':
      case 'repost':
        return _buildCrosspostBanner();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── POLL ──
  Widget _buildPoll() {
    final s = ref.read(stringsProvider);
    final r = context.r;
    final pollData = _post.pollData;
    if (pollData == null) return const SizedBox.shrink();
    final options = (pollData['options'] as List<dynamic>?) ?? [];
    final totalVotes = (pollData['total_votes'] as int?) ??
        options.fold<int>(0, (sum, o) => sum + ((o['votes'] as int?) ?? 0));

    return Padding(
      padding: EdgeInsets.fromLTRB(r.s(12), 0, r.s(12), r.s(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(options.length, (i) {
            final opt = options[i] as Map<String, dynamic>;
            final text = opt['text'] as String? ?? s.optionNumber(i + 1);
            final votes = (opt['votes'] as int?) ?? 0;
            final pct = totalVotes > 0 ? votes / totalVotes : 0.0;
            final isSelected = _selectedPollOption == i;

            return GestureDetector(
              onTap: () => _votePoll(i),
              child: Container(
                margin: EdgeInsets.only(bottom: r.s(6)),
                padding: EdgeInsets.symmetric(
                    horizontal: r.s(12), vertical: r.s(10)),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withValues(alpha: 0.15)
                      : context.scaffoldBg,
                  borderRadius: BorderRadius.circular(r.s(8)),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(text,
                            style: TextStyle(
                                fontSize: r.fs(12),
                                color: context.textPrimary))),
                    if (_selectedPollOption != null) ...[
                      Text('${(pct * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: r.fs(11),
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : context.textSecondary,
                          )),
                    ],
                  ],
                ),
              ),
            );
          }),
          if (_selectedPollOption != null)
            Padding(
              padding: EdgeInsets.only(top: r.s(4)),
              child: Text(s.totalVotesLabel(totalVotes),
                  style:
                      TextStyle(color: Colors.grey[600], fontSize: r.fs(10))),
            ),
        ],
      ),
    );
  }

  // ── QUIZ ──
  Widget _buildQuiz() {
    final s = ref.read(stringsProvider);
    final r = context.r;
    final quizData = _post.quizData;
    if (quizData == null) return const SizedBox.shrink();
    final questions = (quizData['questions'] as List<dynamic>?) ?? [];
    if (questions.isEmpty) return const SizedBox.shrink();
    final q = questions[0] as Map<String, dynamic>;
    final qText = q['text'] as String? ?? s.question;
    final opts = (q['options'] as List<dynamic>?) ?? [];
    final correctIndex = q['correct_index'] as int? ?? 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(r.s(12), 0, r.s(12), r.s(8)),
      child: Container(
        padding: EdgeInsets.all(r.s(12)),
        decoration: BoxDecoration(
          color: context.scaffoldBg,
          borderRadius: BorderRadius.circular(r.s(10)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.quiz_rounded,
                    size: r.s(14), color: AppTheme.accentColor),
                SizedBox(width: r.s(6)),
                Text(s.quiz,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: r.fs(11),
                        color: AppTheme.accentColor)),
                if (questions.length > 1) ...[
                  SizedBox(width: r.s(4)),
                  Text('(${questions.length} perguntas)',
                      style: TextStyle(
                          fontSize: r.fs(10), color: Colors.grey[600])),
                ],
              ],
            ),
            SizedBox(height: r.s(8)),
            Text(qText,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: r.fs(13),
                    color: context.textPrimary)),
            SizedBox(height: r.s(8)),
            ...List.generate(opts.length, (i) {
              final optText = opts[i] as String? ?? s.optionNumber(i + 1);
              final isCorrect = i == correctIndex;
              final isSelected = _selectedQuizOption == i;
              Color bgColor = context.cardBg;
              Color borderColor = Colors.white.withValues(alpha: 0.05);
              if (_quizAnswered) {
                if (isCorrect) {
                  bgColor = AppTheme.successColor.withValues(alpha: 0.15);
                  borderColor = AppTheme.successColor;
                } else if (isSelected && !isCorrect) {
                  bgColor = AppTheme.errorColor.withValues(alpha: 0.15);
                  borderColor = AppTheme.errorColor;
                }
              }
              return GestureDetector(
                onTap: () => _answerQuiz(i),
                child: Container(
                  margin: EdgeInsets.only(bottom: r.s(6)),
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(12), vertical: r.s(10)),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(r.s(8)),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(optText,
                              style: TextStyle(
                                  fontSize: r.fs(12),
                                  color: context.textPrimary))),
                      if (_quizAnswered && isCorrect)
                        Icon(Icons.check_circle_rounded,
                            size: r.s(16), color: AppTheme.successColor),
                      if (_quizAnswered && isSelected && !isCorrect)
                        Icon(Icons.cancel_rounded,
                            size: r.s(16), color: AppTheme.errorColor),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Q&A ──
  Widget _buildQA() {
    final s = ref.read(stringsProvider);
    final r = context.r;
    return Padding(
      padding: EdgeInsets.fromLTRB(r.s(12), 0, r.s(12), r.s(8)),
      child: Container(
        padding: EdgeInsets.all(r.s(12)),
        decoration: BoxDecoration(
          color: const Color(0xFF1A237E).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(r.s(10)),
          border:
              Border.all(color: const Color(0xFF3F51B5).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: r.s(32),
              height: r.s(32),
              decoration: BoxDecoration(
                color: const Color(0xFF3F51B5).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(r.s(8)),
              ),
              child: Center(
                child: Text('Q',
                    style: TextStyle(
                        color: Color(0xFF3F51B5),
                        fontWeight: FontWeight.w700,
                        fontSize: r.fs(16))),
              ),
            ),
            SizedBox(width: r.s(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.questionAndAnswer,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: r.fs(11),
                          color: Color(0xFF3F51B5))),
                  Text(s.postCommentsCountReplies(_post.commentsCount),
                      style: TextStyle(
                          fontSize: r.fs(10), color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: r.s(12), color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  // ── LINK PREVIEW ──
  Widget _buildLinkPreview() {
    final r = context.r;
    final url = _post.externalUrl ?? '';
    final summary = _post.linkSummary;
    final linkTitle = summary?['title'] as String? ?? url;
    final linkDesc = summary?['description'] as String?;
    final linkImage = summary?['image'] as String?;

    if (url.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(r.s(12), 0, r.s(12), r.s(8)),
      child: GestureDetector(
        onTap: () async {
          final uri = Uri.tryParse(url);
          if (uri != null && await canLaunchUrl(uri)) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: context.scaffoldBg,
            borderRadius: BorderRadius.circular(r.s(10)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (linkImage != null)
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(10)),
                  child: CachedNetworkImage(
                    imageUrl: linkImage,
                    height: r.s(120),
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(r.s(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(linkTitle,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: r.fs(12),
                            color: context.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (linkDesc != null) ...[
                      SizedBox(height: r.s(4)),
                      Text(linkDesc,
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: r.fs(11)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                    SizedBox(height: r.s(4)),
                    Row(
                      children: [
                        Icon(Icons.link_rounded,
                            size: r.s(11), color: Colors.grey[600]),
                        SizedBox(width: r.s(4)),
                        Expanded(
                          child: Text(
                            Uri.tryParse(url)?.host ?? url,
                            style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: r.fs(10)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── CROSSPOST / REPOST BANNER ──
  Widget _buildCrosspostBanner() {
    final s = ref.read(stringsProvider);
    final r = context.r;
    if (_post.type == 'repost') {
      return _buildRepostCard(s, r);
    }
    // crosspost legacy
    final color = const Color(0xFF9C27B0);
    return Padding(
      padding: EdgeInsets.fromLTRB(r.s(12), 0, r.s(12), r.s(8)),
      child: GestureDetector(
        onTap: () {
          if (_post.originalPostId != null) {
            context.push('/post/${_post.originalPostId}');
          }
        },
        child: Container(
          padding: EdgeInsets.all(r.s(12)),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(r.s(10)),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.share_rounded, color: color, size: r.s(18)),
              SizedBox(width: r.s(8)),
              Text(s.crosspost,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: r.fs(12))),
            ],
          ),
        ),
      ),
    );
  }

  /// Card de repost estilo Twitter/X:
  /// - Linha "X repostou" acima do card
  /// - Card aninhado com o conteúdo do post original (clicável)
  Widget _buildRepostCard(AppStrings s, Responsive r) {
    final originalPost = _post.originalPost;
    final originalAuthor = _post.originalAuthor ?? originalPost?.author;
    final reposterName = _post.author?.nickname ?? s.user;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── "X repostou" banner ──
        Padding(
          padding: EdgeInsets.fromLTRB(r.s(12), 0, r.s(12), r.s(6)),
          child: Row(
            children: [
              _RepostIconBox(
                color: Colors.grey[500]!,
                icon: Icons.repeat_rounded,
                size: r.s(20),
                iconSize: r.s(12),
              ),
              SizedBox(width: r.s(6)),
              Text(
                s.repostedBy(reposterName),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: r.fs(11),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // ── Card aninhado do post original ──
        Padding(
          padding: EdgeInsets.fromLTRB(r.s(12), 0, r.s(12), r.s(8)),
          child: GestureDetector(
            onTap: () {
              if (_post.originalPostId != null) {
                context.push('/post/${_post.originalPostId}');
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(r.s(10)),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header do post original
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        r.s(10), r.s(10), r.s(10), r.s(6)),
                    child: Row(
                      children: [
                        if (originalAuthor?.iconUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(r.s(14)),
                            child: CachedNetworkImage(
                              imageUrl: originalAuthor!.iconUrl!,
                              width: r.s(28),
                              height: r.s(28),
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => CircleAvatar(
                                radius: r.s(14),
                                backgroundColor:
                                    AppTheme.primaryColor.withValues(alpha: 0.3),
                                child: Icon(Icons.person_rounded,
                                    size: r.s(14),
                                    color: AppTheme.primaryColor),
                              ),
                            ),
                          )
                        else
                          CircleAvatar(
                            radius: r.s(14),
                            backgroundColor:
                                AppTheme.primaryColor.withValues(alpha: 0.3),
                            child: Icon(Icons.person_rounded,
                                size: r.s(14),
                                color: AppTheme.primaryColor),
                          ),
                        SizedBox(width: r.s(8)),
                        Expanded(
                          child: Text(
                            originalAuthor?.nickname ?? s.user,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: r.fs(12),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.open_in_new_rounded,
                            size: r.s(12), color: Colors.grey[600]),
                      ],
                    ),
                  ),
                  // Título do post original
                  if ((originalPost?.title ?? '').isNotEmpty)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          r.s(10), 0, r.s(10), r.s(4)),
                      child: Text(
                        originalPost!.title!,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: r.fs(13),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  // Conteúdo do post original
                  if (originalPost != null &&
                      (originalPost.content).isNotEmpty)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          r.s(10), 0, r.s(10), r.s(8)),
                      child: Text(
                        originalPost.content,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: r.fs(12),
                          height: 1.5,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  // Imagem de capa do post original
                  if (originalPost?.coverImageUrl != null ||
                      originalPost?.mediaUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(r.s(10)),
                        bottomRight: Radius.circular(r.s(10)),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: originalPost?.coverImageUrl ??
                            originalPost!.mediaUrl!,
                        width: double.infinity,
                        height: r.s(160),
                        fit: BoxFit.cover,
                      ),
                    )
                  else if (originalPost == null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          r.s(10), 0, r.s(10), r.s(10)),
                      child: Text(
                        s.postNotFoundMsg,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: r.fs(11),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    SizedBox(height: r.s(4)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACTIONS FOOTER — Estilo Amino (like com animação, comment, tags)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildActions(BuildContext context) {
    final s = ref.read(stringsProvider);
    final r = context.r;
    return Padding(
      padding: EdgeInsets.fromLTRB(r.s(12), 0, r.s(12), r.s(10)),
      child: Row(
        children: [
          // Like button (animated heart)
          Semantics(
            label: _post.isLiked
                ? 'Descurtir post, ${_post.likesCount} curtidas'
                : 'Curtir post, ${_post.likesCount} curtidas',
            button: true,
            child: GestureDetector(
              onTap: _toggleLike,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  ScaleTransition(
                    scale: Tween<double>(begin: 1.0, end: 1.3)
                        .chain(CurveTween(curve: Curves.easeOut))
                        .animate(_likeController),
                    child: Icon(
                      _post.isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: r.s(16),
                      color: _post.isLiked
                          ? const Color(0xFFEF4444)
                          : Colors.grey[600],
                    ),
                  ),
                  SizedBox(width: r.s(4)),
                  Text(
                    '${_post.likesCount}',
                    style: TextStyle(
                      color: _post.isLiked
                          ? const Color(0xFFEF4444)
                          : Colors.grey[600],
                      fontSize: r.fs(12),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: r.s(16)),

          // Comment button
          Semantics(
            label: s.viewCommentsCount(_post.commentsCount),
            button: true,
            child: GestureDetector(
              onTap: () => context.push('/post/${_post.id}'),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: r.s(16), color: Colors.grey[600]),
                  SizedBox(width: r.s(4)),
                  Text(
                    '${_post.commentsCount}',
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: r.fs(12),
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),

          // Repost button
          if (_post.type != 'repost') ...[
            SizedBox(width: r.s(16)),
            Semantics(
              label: s.repostAction,
              button: true,
              child: GestureDetector(
                onTap: _doRepost,
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  Icons.repeat_rounded,
                  size: r.s(16),
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],

          const Spacer(),

          // Tags (right-aligned, max 2)
          if (_post.tags.isNotEmpty)
            ...(_post.tags.take(2).map((tag) => Padding(
                  padding: EdgeInsets.only(left: r.s(6)),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(8), vertical: r.s(3)),
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(r.s(12)),
                    ),
                    child: Text(
                      '#$tag',
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: r.fs(9),
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ))),

          // Tips indicator
          if (_post.tipsTotal > 0)
            Padding(
              padding: EdgeInsets.only(left: r.s(8)),
              child: Row(
                children: [
                  Icon(Icons.monetization_on_rounded,
                      size: r.s(12), color: AppTheme.warningColor),
                  const SizedBox(width: 2),
                  Text('${_post.tipsTotal}',
                      style: TextStyle(
                          color: AppTheme.warningColor,
                          fontSize: r.fs(10),
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Helpers ──
  String get _typeLabel {
    final s = getStrings();
    switch (_post.type) {
      case 'poll':
        return s.poll;
      case 'quiz':
        return s.quiz;
      case 'qa':
        return 'Q&A';
      case 'link':
        return s.link;
      case 'external':
        return 'Externo';
      case 'crosspost':
        return s.crosspost;
      case 'repost':
        return 'Repost';
      case 'image':
        return s.image;
      default:
        return _post.type;
    }
  }

  Color get _typeColor {
    switch (_post.type) {
      case 'poll':
        return const Color(0xFF00BCD4);
      case 'quiz':
        return AppTheme.accentColor;
      case 'qa':
        return const Color(0xFF3F51B5);
      case 'link':
      case 'external':
        return AppTheme.primaryColor;
      case 'crosspost':
        return const Color(0xFF9C27B0);
      case 'repost':
        return const Color(0xFF607D8B);
      default:
        return context.textSecondary;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget auxiliar: caixa de ícone para o banner de repost/crosspost
// ─────────────────────────────────────────────────────────────────────────────
class _RepostIconBox extends ConsumerWidget {
  final Color color;
  final IconData icon;
  final double size;
  final double iconSize;
  const _RepostIconBox({
    required this.color,
    required this.icon,
    required this.size,
    required this.iconSize,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modal de confirmação de repost
// ─────────────────────────────────────────────────────────────────────────────
class _RepostConfirmSheet extends ConsumerWidget {
  final PostModel post;
  const _RepostConfirmSheet({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    final s = ref.watch(stringsProvider);
    const repostColor = Color(0xFF607D8B);

    return Padding(
      padding: EdgeInsets.fromLTRB(r.s(20), r.s(20), r.s(20), r.s(32)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: r.s(40),
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: r.s(20)),
          // Ícone + título
          Row(
            children: [
              Container(
                width: r.s(44),
                height: r.s(44),
                decoration: BoxDecoration(
                  color: repostColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(r.s(12)),
                ),
                child: const Icon(Icons.repeat_rounded,
                    color: repostColor, size: 22),
              ),
              SizedBox(width: r.s(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.repostConfirmTitle,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: r.fs(17),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: r.s(2)),
                    Text(
                      s.repostConfirmMsg,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: r.fs(12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: r.s(20)),
          // Preview do post original
          Container(
            padding: EdgeInsets.all(r.s(12)),
            decoration: BoxDecoration(
              color: repostColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(r.s(10)),
              border: Border.all(color: repostColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                // Avatar do autor
                if (post.author?.iconUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(r.s(16)),
                    child: CachedNetworkImage(
                      imageUrl: post.author!.iconUrl!,
                      width: r.s(32),
                      height: r.s(32),
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  CircleAvatar(
                    radius: r.s(16),
                    backgroundColor: repostColor.withValues(alpha: 0.2),
                    child: Icon(Icons.person_rounded,
                        size: r.s(16), color: repostColor),
                  ),
                SizedBox(width: r.s(10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '@${post.author?.nickname ?? s.user}',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: r.fs(11),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (post.title != null && post.title!.isNotEmpty)
                        Text(
                          post.title!,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: r.fs(12),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r.s(24)),
          // Botões
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[700]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.s(12)),
                    ),
                    padding: EdgeInsets.symmetric(vertical: r.s(14)),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    s.cancel,
                    style: TextStyle(
                        color: context.textSecondary,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              SizedBox(width: r.s(12)),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: repostColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.s(12)),
                    ),
                    padding: EdgeInsets.symmetric(vertical: r.s(14)),
                  ),
                  icon: const Icon(Icons.repeat_rounded, size: 18),
                  label: Text(
                    s.repostAction,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
