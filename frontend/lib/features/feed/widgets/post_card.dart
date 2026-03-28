import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/post_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/amino_animations.dart';

/// Card de post no feed — estilo Amino Apps (web-preview).
/// Suporta todos os 9 tipos de post com renderização interativa.
class PostCard extends StatefulWidget {
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

class _PostCardState extends State<PostCard>
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
      _post = widget.post;
      _selectedPollOption = null;
      _selectedQuizOption = null;
      _quizAnswered = false;
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
      await SupabaseService.client.rpc('toggle_post_like', params: {
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
    } catch (_) {}
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
    return AminoAnimations.cardPress(
      onTap: () => context.push('/post/${_post.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
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
            if (_post.title != null && _post.title!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: Text(
                  _post.title!,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // ── Content ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                _post.content,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // ── Type-specific content ──
            _buildTypeSpecificContent(),

            // ── Media ──
            if (_post.mediaUrl != null && _post.mediaUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: _post.mediaUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.broken_image_rounded,
                          color: AppTheme.textHint),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          // Community icon
          if (_post.author?.iconUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 16,
                height: 16,
                color: AppTheme.surfaceColor,
                child: const Icon(Icons.groups_rounded,
                    size: 10, color: AppTheme.textHint),
              ),
            ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _post.communityId ?? '',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
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
                    fontSize: 8,
                    fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AUTHOR HEADER — Estilo Amino
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildAuthorHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          // Avatar (36px, rounded-full)
          GestureDetector(
            onTap: () => context.push('/user/${_post.authorId}'),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.surfaceColor,
              backgroundImage: _post.author?.iconUrl != null
                  ? CachedNetworkImageProvider(_post.author!.iconUrl!)
                  : null,
              child: _post.author?.iconUrl == null
                  ? Text(
                      (_post.author?.nickname ?? '?')[0].toUpperCase(),
                      style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + Role badge
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _post.author?.nickname ?? 'Usuário',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Role badges (Leader, Curator)
                    if (_post.author != null &&
                        _post.author!.level > 10) ...[
                      const SizedBox(width: 6),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.getLevelColor(_post.author!.level),
                              AppTheme.getLevelColor(_post.author!.level)
                                  .withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Lv.${_post.author!.level}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    // Time ago
                    Text(
                      timeago.format(_post.createdAt, locale: 'pt_BR'),
                      style: TextStyle(color: Colors.grey[600], fontSize: 10),
                    ),
                    // Type badge
                    if (_post.type != 'normal') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _typeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _typeLabel,
                          style: TextStyle(
                              color: _typeColor,
                              fontSize: 8,
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
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded,
                      size: 10, color: AppTheme.warningColor),
                  SizedBox(width: 2),
                  Text('Featured',
                      style: TextStyle(
                          color: AppTheme.warningColor,
                          fontSize: 8,
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
      default:
        return const SizedBox.shrink();
    }
  }

  // ── POLL ──
  Widget _buildPoll() {
    final pollData = _post.pollData;
    if (pollData == null) return const SizedBox.shrink();
    final options = (pollData['options'] as List<dynamic>?) ?? [];
    final totalVotes = (pollData['total_votes'] as int?) ??
        options.fold<int>(0, (sum, o) => sum + ((o['votes'] as int?) ?? 0));

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(options.length, (i) {
            final opt = options[i] as Map<String, dynamic>;
            final text = opt['text'] as String? ?? 'Opção ${i + 1}';
            final votes = (opt['votes'] as int?) ?? 0;
            final pct = totalVotes > 0 ? votes / totalVotes : 0.0;
            final isSelected = _selectedPollOption == i;

            return GestureDetector(
              onTap: () => _votePoll(i),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withValues(alpha: 0.15)
                      : AppTheme.scaffoldBg,
                  borderRadius: BorderRadius.circular(8),
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
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textPrimary))),
                    if (_selectedPollOption != null) ...[
                      Text('${(pct * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondary,
                          )),
                    ],
                  ],
                ),
              ),
            );
          }),
          if (_selectedPollOption != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('$totalVotes votos',
                  style: TextStyle(color: Colors.grey[600], fontSize: 10)),
            ),
        ],
      ),
    );
  }

  // ── QUIZ ──
  Widget _buildQuiz() {
    final quizData = _post.quizData;
    if (quizData == null) return const SizedBox.shrink();
    final questions = (quizData['questions'] as List<dynamic>?) ?? [];
    if (questions.isEmpty) return const SizedBox.shrink();
    final q = questions[0] as Map<String, dynamic>;
    final qText = q['text'] as String? ?? 'Pergunta';
    final opts = (q['options'] as List<dynamic>?) ?? [];
    final correctIndex = q['correct_index'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.scaffoldBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.quiz_rounded,
                    size: 14, color: AppTheme.accentColor),
                const SizedBox(width: 6),
                const Text('Quiz',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: AppTheme.accentColor)),
                if (questions.length > 1) ...[
                  const SizedBox(width: 4),
                  Text('(${questions.length} perguntas)',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(qText,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            ...List.generate(opts.length, (i) {
              final optText = opts[i] as String? ?? 'Opção ${i + 1}';
              final isCorrect = i == correctIndex;
              final isSelected = _selectedQuizOption == i;
              Color bgColor = AppTheme.cardColor;
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
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(optText,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textPrimary))),
                      if (_quizAnswered && isCorrect)
                        const Icon(Icons.check_circle_rounded,
                            size: 16, color: AppTheme.successColor),
                      if (_quizAnswered && isSelected && !isCorrect)
                        const Icon(Icons.cancel_rounded,
                            size: 16, color: AppTheme.errorColor),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A237E).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: const Color(0xFF3F51B5).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF3F51B5).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('Q',
                    style: TextStyle(
                        color: Color(0xFF3F51B5),
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pergunta & Resposta',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: Color(0xFF3F51B5))),
                  Text('${_post.commentsCount} respostas',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  // ── LINK PREVIEW ──
  Widget _buildLinkPreview() {
    final url = _post.externalUrl ?? '';
    final summary = _post.linkSummary;
    final linkTitle = summary?['title'] as String? ?? url;
    final linkDesc = summary?['description'] as String?;
    final linkImage = summary?['image'] as String?;

    if (url.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: GestureDetector(
        onTap: () async {
          final uri = Uri.tryParse(url);
          if (uri != null && await canLaunchUrl(uri)) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.scaffoldBg,
            borderRadius: BorderRadius.circular(10),
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
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(linkTitle,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: AppTheme.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (linkDesc != null) ...[
                      const SizedBox(height: 4),
                      Text(linkDesc,
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.link_rounded,
                            size: 11, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            Uri.tryParse(url)?.host ?? url,
                            style: TextStyle(
                                color: AppTheme.primaryColor, fontSize: 10),
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

  // ══════════════════════════════════════════════════════════════════════════
  // ACTIONS FOOTER — Estilo Amino (like com animação, comment, tags)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        children: [
          // Like button (animated heart)
          GestureDetector(
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
                    size: 16,
                    color: _post.isLiked
                        ? const Color(0xFFEF4444)
                        : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${_post.likesCount}',
                  style: TextStyle(
                    color: _post.isLiked
                        ? const Color(0xFFEF4444)
                        : Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Comment button
          GestureDetector(
            onTap: () => context.push('/post/${_post.id}'),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${_post.commentsCount}',
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Tags (right-aligned, max 2)
          if (_post.tags.isNotEmpty)
            ...(_post.tags.take(2).map((tag) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '#$tag',
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 9,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ))),

          // Tips indicator
          if (_post.tipsTotal > 0)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Row(
                children: [
                  const Icon(Icons.monetization_on_rounded,
                      size: 12, color: AppTheme.warningColor),
                  const SizedBox(width: 2),
                  Text('${_post.tipsTotal}',
                      style: const TextStyle(
                          color: AppTheme.warningColor,
                          fontSize: 10,
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
        return 'Enquete';
      case 'quiz':
        return 'Quiz';
      case 'qa':
        return 'Q&A';
      case 'link':
        return 'Link';
      case 'external':
        return 'Externo';
      case 'crosspost':
        return 'Crosspost';
      case 'repost':
        return 'Repost';
      case 'image':
        return 'Imagem';
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
        return AppTheme.textSecondary;
    }
  }
}
