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
  State<PostCard> createState() => _PostCardState();
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
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
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

            // ── Title ──
            if ((_post.title ?? '').isNotEmpty)
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

            // ── Content (Block Editor ou texto simples) ──
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

            // ── Type-specific content ──
            _buildTypeSpecificContent(),

            // ── Media (formato square 1:1) ──
            if ((_post.mediaUrl ?? '').isNotEmpty)
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
            Text('📌 Pinned',
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
    final r = context.r;
    return Padding(
      padding: EdgeInsets.fromLTRB(r.s(12), r.s(10), r.s(12), r.s(8)),
      child: Row(
        children: [
          // Avatar (36px, rounded-full)
          CosmeticAvatar(
            userId: _post.authorId,
            avatarUrl: _post.author?.iconUrl,
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
                        _post.author?.nickname ?? s.user,
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
                        (_post.author?.level ?? 0) > 10) ...[
                      SizedBox(width: r.s(6)),
                      // Simulated role badge based on level
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                // Level badge + time + type
                Row(
                  children: [
                    // Level badge (gradient pill)
                    if (_post.author != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.s(6), vertical: 2),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.getLevelColor(_post.author?.level ?? 0),
                              AppTheme.getLevelColor(_post.author?.level ?? 0)
                                  .withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(r.s(10)),
                        ),
                        child: Text(
                          'Lv.${_post.author?.level ?? 0}',
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
    final r = context.r;
    final isRepost = _post.type == 'repost';
    final label = isRepost ? 'Repost' : s.crosspost;
    final icon = isRepost ? Icons.repeat_rounded : Icons.share_rounded;
    final color = isRepost ? const Color(0xFF607D8B) : const Color(0xFF9C27B0);
    final originId = _post.originalCommunityId;

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
              Container(
                width: r.s(36),
                height: r.s(36),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(r.s(8)),
                ),
                child: Icon(icon, color: color, size: r.s(18)),
              ),
              SizedBox(width: r.s(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: r.fs(12),
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      originId != null
                          ? 'De outra comunidade'
                          : 'Post compartilhado',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: r.fs(10),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.open_in_new_rounded,
                  size: r.s(14), color: Colors.grey[600]),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACTIONS FOOTER — Estilo Amino (like com animação, comment, tags)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildActions(BuildContext context) {
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
