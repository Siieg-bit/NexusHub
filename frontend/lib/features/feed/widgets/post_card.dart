import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/post_model.dart';
import '../../../core/services/supabase_service.dart';

/// Card de post no feed — renderização interativa para todos os 9 tipos.
class PostCard extends StatefulWidget {
  final PostModel post;
  final VoidCallback? onLike;

  const PostCard({super.key, required this.post, this.onLike});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late PostModel _post;
  int? _selectedPollOption;
  int? _selectedQuizOption;
  bool _quizAnswered = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
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

  Future<void> _toggleLike() async {
    final wasLiked = _post.isLiked;
    setState(() {
      _post = _post.copyWith(
        isLiked: !wasLiked,
        likesCount: _post.likesCount + (wasLiked ? -1 : 1),
      );
    });
    try {
      await SupabaseService.client.rpc('toggle_post_like', params: {
        'p_post_id': _post.id,
      });
    } catch (_) {
      // Revert on error
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
    return GestureDetector(
      onTap: () => context.push('/post/${_post.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            if (_post.title != null && _post.title!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  _post.title!,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Text(
                _post.content,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // ── Type-specific content ──
            _buildTypeSpecificContent(),

            // ── Media ──
            if (_post.mediaUrl != null && _post.mediaUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: _post.mediaUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 200,
                      color: AppTheme.cardColorLight,
                      child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 200,
                      color: AppTheme.cardColorLight,
                      child: const Icon(Icons.broken_image_rounded,
                          color: AppTheme.textHint),
                    ),
                  ),
                ),
              ),

            // ── Tags ──
            if (_post.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Wrap(
                  spacing: 6,
                  children: _post.tags
                      .take(3)
                      .map((tag) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('#$tag',
                                style: const TextStyle(
                                    color: AppTheme.primaryLight,
                                    fontSize: 11)),
                          ))
                      .toList(),
                ),
              ),

            // ── Actions ──
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HEADER
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.push('/user/${_post.authorId}'),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.3),
              backgroundImage: _post.author?.iconUrl != null
                  ? CachedNetworkImageProvider(_post.author!.iconUrl!)
                  : null,
              child: _post.author?.iconUrl == null
                  ? Text(
                      (_post.author?.nickname ?? '?')[0].toUpperCase(),
                      style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _post.author?.nickname ?? 'Usuário',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_post.author != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.getLevelColor(_post.author!.level)
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Lv.${_post.author!.level}',
                          style: TextStyle(
                            color: AppTheme.getLevelColor(_post.author!.level),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    Text(
                      timeago.format(_post.createdAt, locale: 'pt_BR'),
                      style: const TextStyle(
                          color: AppTheme.textHint, fontSize: 11),
                    ),
                    if (_post.type != 'normal') ...[
                      const SizedBox(width: 6),
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
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (_post.isFeatured || _post.isPinned)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded,
                      size: 12, color: AppTheme.warningColor),
                  const SizedBox(width: 2),
                  Text(
                    _post.isFeatured ? 'Destaque' : 'Fixado',
                    style: const TextStyle(
                      color: AppTheme.warningColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded, size: 20),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
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
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.dividerColor,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                        child:
                            Text(text, style: const TextStyle(fontSize: 13))),
                    if (_selectedPollOption != null) ...[
                      Text('${(pct * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
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
                  style:
                      const TextStyle(color: AppTheme.textHint, fontSize: 11)),
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
    // Show first question inline
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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.quiz_rounded,
                    size: 16, color: AppTheme.accentColor),
                const SizedBox(width: 6),
                const Text('Quiz',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppTheme.accentColor)),
                if (questions.length > 1) ...[
                  const SizedBox(width: 4),
                  Text('(${questions.length} perguntas)',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textHint)),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(qText,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            ...List.generate(opts.length, (i) {
              final optText = opts[i] as String? ?? 'Opção ${i + 1}';
              final isCorrect = i == correctIndex;
              final isSelected = _selectedQuizOption == i;
              Color bgColor = AppTheme.cardColor;
              Color borderColor = AppTheme.dividerColor;
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
                              style: const TextStyle(fontSize: 13))),
                      if (_quizAnswered && isCorrect)
                        const Icon(Icons.check_circle_rounded,
                            size: 18, color: AppTheme.successColor),
                      if (_quizAnswered && isSelected && !isCorrect)
                        const Icon(Icons.cancel_rounded,
                            size: 18, color: AppTheme.errorColor),
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
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: const Color(0xFF3F51B5).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF3F51B5).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('Q',
                    style: TextStyle(
                        color: Color(0xFF3F51B5),
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pergunta & Resposta',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF3F51B5))),
                  Text('${_post.commentsCount} respostas',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textHint)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppTheme.textHint),
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
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (linkImage != null)
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
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
                            fontWeight: FontWeight.w600, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (linkDesc != null) ...[
                      const SizedBox(height: 4),
                      Text(linkDesc,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.link_rounded,
                            size: 12, color: AppTheme.textHint),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            Uri.tryParse(url)?.host ?? url,
                            style: const TextStyle(
                                color: AppTheme.primaryLight, fontSize: 11),
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
  // ACTIONS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Row(
        children: [
          _ActionButton(
            icon: _post.isLiked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: _post.likesCount > 0 ? '${_post.likesCount}' : 'Curtir',
            color: _post.isLiked ? AppTheme.errorColor : null,
            onTap: _toggleLike,
          ),
          _ActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            label:
                _post.commentsCount > 0 ? '${_post.commentsCount}' : 'Comentar',
            onTap: () => context.push('/post/${_post.id}'),
          ),
          _ActionButton(
            icon: Icons.share_outlined,
            label: 'Compartilhar',
            onTap: () {},
          ),
          const Spacer(),
          if (_post.tipsTotal > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Row(
                children: [
                  const Icon(Icons.monetization_on_rounded,
                      size: 14, color: AppTheme.warningColor),
                  const SizedBox(width: 2),
                  Text('${_post.tipsTotal}',
                      style: const TextStyle(
                          color: AppTheme.warningColor, fontSize: 11)),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                const Icon(Icons.visibility_outlined,
                    size: 14, color: AppTheme.textHint),
                const SizedBox(width: 4),
                Text('${_post.viewsCount}',
                    style: const TextStyle(
                        color: AppTheme.textHint, fontSize: 11)),
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
        return AppTheme.primaryLight;
      case 'crosspost':
        return const Color(0xFF9C27B0);
      case 'repost':
        return const Color(0xFF607D8B);
      default:
        return AppTheme.textSecondary;
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color ?? AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                  color: color ?? AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
