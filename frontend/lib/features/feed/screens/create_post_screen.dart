import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/app_theme.dart';
import '../../../core/utils/media_utils.dart';
import '../../../core/services/supabase_service.dart';
import '../widgets/block_editor.dart';
import '../../chat/widgets/giphy_picker.dart';
import '../widgets/crosspost_picker.dart';
import '../../../core/utils/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/draft_provider.dart';
import '../../../core/providers/post_provider.dart';
import '../../../core/models/post_model.dart';
import '../../../core/l10n/locale_provider.dart';

/// Editor rico unificado de criação e edição de posts — estilo Amino Apps.
/// Suporta todos os tipos: Story, Pergunta, Chat Público, Imagem, Link,
/// Quiz, Enquete, Entrada Wiki, Blog, Normal, Crosspost, Repost, Externo.
///
/// Quando [editingPost] é fornecido, funciona como editor de edição,
/// pré-preenchendo todos os campos com os dados do post existente.
class CreatePostScreen extends ConsumerStatefulWidget {
  final String communityId;

  /// Tipo de post pré-selecionado ao abrir.
  final String? initialType;

  /// Post existente para edição. Se não-nulo, o editor entra em modo de edição.
  final PostModel? editingPost;

  const CreatePostScreen({
    super.key,
    required this.communityId,
    this.initialType,
    this.editingPost,
  });

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  late String _selectedType;
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _contentController = TextEditingController();
  final _linkController = TextEditingController();
  final _backgroundUrlController = TextEditingController();
  bool _isSubmitting = false;
  final List<String> _mediaUrls = [];
  String? _coverImageUrl;

  // Block Editor para modo Blog
  List<ContentBlock> _contentBlocks = [];
  bool _useBlogEditor = false;
  final _blockEditorKey = GlobalKey();

  // Poll
  final List<TextEditingController> _pollOptions = [
    TextEditingController(),
    TextEditingController(),
  ];

  // Quiz
  final List<_QuizQuestion> _quizQuestions = [_QuizQuestion()];

  // Q&A
  bool _isQaClosed = false;

  // Crosspost
  Map<String, dynamic>? _crosspostCommunity;

  // Visibilidade e controle de comentários
  String _postVisibility = 'public';
  bool _commentsBlocked = false;

  // GIF e Música
  String? _gifUrl;
  String? _musicUrl;
  String? _musicTitle;

  // ── Personalização avançada ──
  Color _textColor = Colors.white;
  Color _bgColor = const Color(0xFF0D1B2A);
  String _fontFamily = 'Plus Jakarta Sans';
  double _bodyFontSize = 15.0;
  String _dividerStyle = 'solid'; // solid, dashed, dotted, none
  Color _dividerColor = Colors.white24;

  // Wiki
  final _wikiCategoryController = TextEditingController();
  final List<_WikiSection> _wikiSections = [_WikiSection()];

  // Story
  final _storyDurationController = TextEditingController(text: '24');

  // Chat Público
  final _chatDescriptionController = TextEditingController();

  bool get _isEditing => widget.editingPost != null;

  // Fontes disponíveis
  static const _availableFonts = [
    'Plus Jakarta Sans',
    'Roboto',
    'Poppins',
    'Inter',
    'Lato',
    'Montserrat',
    'Open Sans',
    'Nunito',
    'Raleway',
    'Playfair Display',
  ];

  List<_PostTypeOption> _getPostTypes() {
    final s = getStrings();
    return [
      _PostTypeOption('normal', s.blog, Icons.article_rounded),
      _PostTypeOption('story', 'Story', Icons.auto_stories_rounded),
      _PostTypeOption('qa', s.quiz, Icons.question_answer_rounded),
      _PostTypeOption('public_chat', 'Chat', Icons.forum_rounded),
      _PostTypeOption('image', s.image, Icons.image_rounded),
      _PostTypeOption('link', s.link, Icons.link_rounded),
      _PostTypeOption('quiz', 'Quiz', Icons.quiz_rounded),
      _PostTypeOption('poll', s.poll, Icons.poll_rounded),
      _PostTypeOption('wiki', 'Wiki', Icons.menu_book_rounded),
      _PostTypeOption('blog', 'Blog', Icons.edit_note_rounded),
      _PostTypeOption('crosspost', s.crosspost, Icons.share_rounded),
      _PostTypeOption('repost', 'Repost', Icons.repeat_rounded),
      _PostTypeOption('external', 'Externo', Icons.open_in_new_rounded),
    ];
  }

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? widget.editingPost?.type ?? 'normal';

    // Se estiver editando, preencher todos os campos
    if (_isEditing) {
      _populateFromPost(widget.editingPost!);
    }
  }

  void _populateFromPost(PostModel post) {
    _titleController.text = post.title ?? '';
    _contentController.text = post.content;
    _coverImageUrl = post.coverImageUrl;
    _linkController.text = post.externalUrl ?? '';
    _backgroundUrlController.text = post.backgroundUrl ?? '';
    _gifUrl = post.editorMetadata.extra['gif_url'] as String?;
    _musicUrl = post.editorMetadata.extra['music_url'] as String?;
    _musicTitle = post.editorMetadata.extra['music_title'] as String?;
    _postVisibility = post.editorMetadata.extra['visibility'] as String? ?? 'public';
    _commentsBlocked = post.editorMetadata.extra['comments_blocked'] == true;
    _selectedType = post.editorType ?? post.type;

    // Mídia
    for (final media in post.mediaList) {
      if (media is Map && media['url'] != null) {
        _mediaUrls.add(media['url'] as String);
      }
    }

    // Personalização do editor metadata
    final meta = post.editorMetadata;
    _textColor = _parseColor(meta.bodyStyle.textColor) ?? Colors.white;
    _bgColor = _parseColor(meta.coverStyle.backgroundColor) ?? const Color(0xFF0D1B2A);
    _fontFamily = meta.bodyStyle.fontFamily ?? 'Plus Jakarta Sans';
    _bodyFontSize = meta.bodyStyle.fontSize ?? 15.0;
    _dividerStyle = meta.dividerStyle.style;
    _dividerColor = _parseColor(meta.dividerStyle.color) ?? Colors.white24;

    // Poll options
    if (post.pollData != null) {
      final options = post.pollData!['options'] as List?;
      if (options != null && options.isNotEmpty) {
        _pollOptions.clear();
        for (final opt in options) {
          _pollOptions.add(TextEditingController(
            text: (opt as Map?)?['text'] as String? ?? '',
          ));
        }
      }
    }

    // Quiz questions
    if (post.quizData != null) {
      final questions = post.quizData!['questions'] as List?;
      if (questions != null && questions.isNotEmpty) {
        _quizQuestions.clear();
        for (final q in questions) {
          final qMap = q as Map<String, dynamic>;
          final quiz = _QuizQuestion();
          quiz.questionController.text = qMap['question_text'] as String? ?? qMap['prompt'] as String? ?? '';
          quiz.correctIndex = (qMap['correct_option_index'] as num?)?.toInt() ?? (qMap['correct_index'] as num?)?.toInt() ?? 0;
          final opts = qMap['options'] as List?;
          if (opts != null && opts.isNotEmpty) {
            quiz.options.clear();
            for (final o in opts) {
              quiz.options.add(TextEditingController(
                text: (o as Map?)?['text'] as String? ?? '',
              ));
            }
          }
          _quizQuestions.add(quiz);
        }
      }
    }

    // Blog editor
    if (post.contentBlocks != null && post.contentBlocks!.isNotEmpty) {
      _useBlogEditor = true;
    }
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      final cleaned = hex.replaceAll('#', '');
      if (cleaned.length == 6) return Color(int.parse('FF$cleaned', radix: 16));
      if (cleaned.length == 8) return Color(int.parse(cleaned, radix: 16));
    } catch (_) {}
    return null;
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  Future<void> _pickImage() async {
    final s = getStrings();
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final path = 'posts/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final rawBytes = await image.readAsBytes();
      final bytes = await MediaUtils.compressImage(rawBytes);

      await SupabaseService.storage
          .from('post_media')
          .uploadBinary(path, bytes);
      if (!mounted) return;

      final url = SupabaseService.storage.from('post_media').getPublicUrl(path);

      if (!mounted) return;
      setState(() => _mediaUrls.add(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorUploadTryAgain),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _pickCoverImage() async {
    final s = getStrings();
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final path =
          'covers/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final rawBytes = await image.readAsBytes();
      final bytes = await MediaUtils.compressImage(rawBytes);

      await SupabaseService.storage
          .from('post_media')
          .uploadBinary(path, bytes);
      if (!mounted) return;

      final url = SupabaseService.storage.from('post_media').getPublicUrl(path);

      if (!mounted) return;
      setState(() => _coverImageUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorUploadTryAgain),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _pickBackgroundImage() async {
    final s = getStrings();
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final path =
          'backgrounds/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final rawBytes = await image.readAsBytes();
      final bytes = await MediaUtils.compressImage(rawBytes);

      await SupabaseService.storage
          .from('post_media')
          .uploadBinary(path, bytes);
      if (!mounted) return;

      final url = SupabaseService.storage.from('post_media').getPublicUrl(path);

      if (!mounted) return;
      setState(() => _backgroundUrlController.text = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorUploadTryAgain),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _buildEditorMetadata() {
    return {
      'editor_type': _selectedType,
      'title_style': {
        'text_color': _colorToHex(_textColor),
        'font_family': _fontFamily,
        'font_size': 22.0,
        'bold': true,
      },
      'subtitle_style': {
        'text_color': _colorToHex(_textColor.withValues(alpha: 0.8)),
        'font_family': _fontFamily,
        'font_size': 16.0,
      },
      'body_style': {
        'text_color': _colorToHex(_textColor),
        'font_family': _fontFamily,
        'font_size': _bodyFontSize,
      },
      'divider_style': {
        'style': _dividerStyle,
        'color': _colorToHex(_dividerColor),
        'thickness': 1.0,
        'spacing': 20.0,
      },
      'cover_style': {
        if (_coverImageUrl != null) 'cover_image_url': _coverImageUrl,
        if (_backgroundUrlController.text.trim().isNotEmpty)
          'background_image_url': _backgroundUrlController.text.trim(),
        'background_color': _colorToHex(_bgColor),
      },
      'extra': {
        if (_gifUrl != null) 'gif_url': _gifUrl,
        if (_musicUrl != null) 'music_url': _musicUrl,
        if (_musicTitle != null) 'music_title': _musicTitle,
        'visibility': _postVisibility,
        'comments_blocked': _commentsBlocked,
      },
    };
  }

  Future<void> _submitPost() async {
    final s = getStrings();
    if (_titleController.text.trim().isEmpty &&
        _contentController.text.trim().isEmpty &&
        _selectedType != 'image') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.fillTitleOrContent),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_selectedType == 'crosspost' && _crosspostCommunity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.selectCrosspostCommunity),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception(s.notAuthenticated);

      final contentText = _useBlogEditor
          ? _contentBlocks
              .where((b) =>
                  b.type == BlockType.text || b.type == BlockType.heading)
              .map((b) => b.controller?.text ?? b.text)
              .where((t) => t.isNotEmpty)
              .join('\n\n')
          : _contentController.text.trim();

      final mediaList = _mediaUrls.isNotEmpty
          ? _mediaUrls.map((url) => {'url': url, 'type': 'image'}).toList()
          : <Map<String, dynamic>>[];

      final titleText = _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : null;

      final editorMetadata = _buildEditorMetadata();

      // ── Modo de EDIÇÃO ──
      if (_isEditing) {
        final postData = {
          'title': titleText ?? '',
          'content': contentText,
          'type': _selectedType,
          'media_list': mediaList,
          'tags': <String>[],
          'cover_image_url': _coverImageUrl,
          'background_url': _backgroundUrlController.text.trim().isNotEmpty
              ? _backgroundUrlController.text.trim()
              : null,
          'external_url': _linkController.text.trim().isNotEmpty
              ? _linkController.text.trim()
              : null,
          'gif_url': _gifUrl,
          'music_url': _musicUrl,
          'music_title': _musicTitle,
          'visibility': _postVisibility,
          'comments_blocked': _commentsBlocked,
          'editor_type': _selectedType,
          'editor_metadata': editorMetadata,
        };

        // Adicionar poll_options se for enquete
        if (_selectedType == 'poll') {
          postData['poll_options'] = _pollOptions
              .where((c) => c.text.trim().isNotEmpty)
              .map((c) => {'text': c.text.trim()})
              .toList();
        }

        final success = await ref
            .read(communityFeedProvider(widget.communityId).notifier)
            .editPost(widget.editingPost!.id, postData);

        if (mounted) {
          if (success) {
            context.pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(s.postUpdated),
                backgroundColor: AppTheme.successColor,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(s.anErrorOccurredTryAgain),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
        return;
      }

      // ── Modo de CRIAÇÃO ──
      String? postId;

      if (_selectedType == 'quiz') {
        final questions = _quizQuestions
            .where((q) => q.questionController.text.trim().isNotEmpty)
            .toList()
            .asMap()
            .entries
            .map((e) => {
                  'question_text': e.value.questionController.text.trim(),
                  'correct_option_index': e.value.correctIndex,
                  'options': e.value.options
                      .where((o) => o.text.trim().isNotEmpty)
                      .map((o) => {'text': o.text.trim()})
                      .toList(),
                })
            .toList();

        postId = await SupabaseService.rpc(
          'create_quiz_with_questions',
          params: {
            'p_community_id': widget.communityId,
            'p_title': titleText ?? '',
            'p_content': contentText,
            'p_media_urls': mediaList,
            'p_questions': questions,
            'p_allow_comments': !_commentsBlocked,
          },
        ) as String?;
      } else {
        List<Map<String, dynamic>>? pollOpts;
        if (_selectedType == 'poll') {
          pollOpts = _pollOptions
              .where((c) => c.text.trim().isNotEmpty)
              .map((c) => {'text': c.text.trim()})
              .toList();
        }

        // Mapear tipos especiais para o tipo base do DB
        String dbType = _selectedType;
        if (['story', 'blog', 'wiki', 'public_chat'].contains(_selectedType)) {
          dbType = 'normal';
        }

        postId = await SupabaseService.rpc(
          'create_post_with_reputation',
          params: {
            'p_community_id': widget.communityId,
            'p_title': titleText ?? '',
            'p_content': contentText,
            'p_type': dbType,
            'p_media_list': mediaList,
            'p_tags': <String>[],
            'p_cover_image_url': _coverImageUrl,
            'p_background_url': _backgroundUrlController.text.trim().isNotEmpty
                ? _backgroundUrlController.text.trim()
                : null,
            'p_external_url': _linkController.text.trim().isNotEmpty
                ? _linkController.text.trim()
                : null,
            'p_gif_url': _gifUrl,
            'p_music_url': _musicUrl,
            'p_music_title': _musicTitle,
            'p_visibility': _postVisibility,
            'p_comments_blocked': _commentsBlocked,
            if (pollOpts != null) 'p_poll_options': pollOpts,
          },
        ) as String?;

        // Atualizar editor_metadata e editor_type no post criado
        if (postId != null) {
          try {
            // Incluir editor_type dentro do editor_metadata (coluna editor_type
            // não existe na tabela, então salvamos no JSON de metadata).
            editorMetadata['editor_type'] = _selectedType;
            await SupabaseService.table('posts').update({
              'editor_metadata': editorMetadata,
              if (_selectedType == 'story')
                'story_data': {
                  'duration_hours': int.tryParse(_storyDurationController.text) ?? 24,
                },
              if (_selectedType == 'wiki')
                'wiki_data': {
                  'category': _wikiCategoryController.text.trim(),
                  'sections': _wikiSections
                      .where((s) => s.titleController.text.trim().isNotEmpty)
                      .map((s) => {
                            'title': s.titleController.text.trim(),
                            'content': s.contentController.text.trim(),
                          })
                      .toList(),
                },
              if (_selectedType == 'public_chat')
                'chat_data': {
                  'description': _chatDescriptionController.text.trim(),
                },
            }).eq('id', postId);
          } catch (_) {
            // best-effort metadata update
          }
        }
      }

      // Crosspost espelho
      if (_selectedType == 'crosspost' &&
          _crosspostCommunity != null &&
          postId != null) {
        try {
          await SupabaseService.rpc('create_crosspost', params: {
            'p_target_community_id': _crosspostCommunity!['id'],
            'p_original_post_id': postId,
            'p_original_community_id': widget.communityId,
            'p_title': titleText,
            'p_content': contentText,
            'p_media_list': mediaList,
            'p_cover_image_url': _coverImageUrl,
          });
        } catch (_) {}
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.postCreatedSuccess),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.anErrorOccurredTryAgain),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _wrapSelection(String prefix, String suffix) {
    final text = _contentController.text;
    final sel = _contentController.selection;
    if (sel.isValid && sel.start != sel.end) {
      final selected = text.substring(sel.start, sel.end);
      final newText =
          text.replaceRange(sel.start, sel.end, '$prefix$selected$suffix');
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: sel.start + prefix.length + selected.length + suffix.length,
        ),
      );
    } else {
      final pos = sel.isValid ? sel.start : text.length;
      final newText =
          '${text.substring(0, pos)}${prefix}texto${suffix}${text.substring(pos)}';
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: pos + prefix.length,
          extentOffset: pos + prefix.length + 5,
        ),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _contentController.dispose();
    _linkController.dispose();
    _backgroundUrlController.dispose();
    _wikiCategoryController.dispose();
    _storyDurationController.dispose();
    _chatDescriptionController.dispose();
    for (final c in _pollOptions) {
      c.dispose();
    }
    for (final q in _quizQuestions) {
      q.dispose();
    }
    for (final s in _wikiSections) {
      s.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: _textColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _isEditing ? s.editPost : 'Criar Post',
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.w700,
            fontSize: r.fs(16),
          ),
        ),
        centerTitle: true,
        actions: [
          if (!_isEditing) ...[
            // Botão de rascunhos
            IconButton(
              icon: Icon(Icons.drafts_rounded,
                  color: _textColor.withValues(alpha: 0.6), size: r.s(22)),
              tooltip: s.drafts,
              onPressed: () => context.push('/drafts'),
            ),
            // Botão de salvar como rascunho
            IconButton(
              icon: Icon(Icons.save_outlined,
                  color: _textColor.withValues(alpha: 0.6), size: r.s(22)),
              tooltip: 'Salvar rascunho',
              onPressed: () async {
                final title = _titleController.text.trim();
                final content = _contentController.text.trim();
                if (title.isEmpty && content.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(s.nothingToSave)),
                  );
                  return;
                }
                try {
                  await ref.read(postDraftsProvider.notifier).createDraft(
                        communityId: widget.communityId,
                        title: title.isNotEmpty ? title : null,
                        content: content.isNotEmpty ? content : null,
                        postType: _selectedType,
                      );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Rascunho salvo!'),
                        backgroundColor: AppTheme.primaryColor,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(s.errorSavingTryAgain)),
                    );
                  }
                }
              },
            ),
          ],
          Padding(
            padding: EdgeInsets.only(right: r.s(12)),
            child: GestureDetector(
              onTap: _isSubmitting ? null : _submitPost,
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: r.s(20), vertical: r.s(8)),
                decoration: BoxDecoration(
                  color: _isSubmitting
                      ? AppTheme.primaryColor.withValues(alpha: 0.5)
                      : AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(r.s(8)),
                ),
                child: _isSubmitting
                    ? SizedBox(
                        width: r.s(16),
                        height: r.s(16),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _isEditing ? s.save : 'Postar',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: r.fs(14),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Type selector (horizontal scroll) — oculto em edição ──
          if (!_isEditing)
            Container(
              height: r.s(48),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: _textColor.withValues(alpha: 0.05)),
                ),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: r.s(12)),
                itemCount: _getPostTypes().length,
                itemBuilder: (context, index) {
                  final type = _getPostTypes()[index];
                  final isSelected = _selectedType == type.value;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = type.value),
                    child: Container(
                      margin: EdgeInsets.only(right: r.s(6)),
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(12), vertical: r.s(8)),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(r.s(20)),
                        border: isSelected
                            ? Border.all(
                                color:
                                    AppTheme.primaryColor.withValues(alpha: 0.4))
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(type.icon,
                              size: r.s(14),
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : Colors.grey[600]),
                          SizedBox(width: r.s(6)),
                          Text(
                            type.label,
                            style: TextStyle(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : Colors.grey[600],
                              fontSize: r.fs(12),
                              fontWeight:
                                  isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // ── Body ──
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(r.s(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover image picker
                  GestureDetector(
                    onTap: _pickCoverImage,
                    child: Container(
                      width: double.infinity,
                      height: r.s(140),
                      decoration: BoxDecoration(
                        color: _bgColor.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(r.s(12)),
                        border: Border.all(
                            color: _textColor.withValues(alpha: 0.08)),
                        image: _coverImageUrl != null
                            ? DecorationImage(
                                image: NetworkImage(_coverImageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _coverImageUrl == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_rounded,
                                    color: _textColor.withValues(alpha: 0.4), size: r.s(32)),
                                SizedBox(height: r.s(6)),
                                Text(s.addCover,
                                    style: TextStyle(
                                        color: _textColor.withValues(alpha: 0.4),
                                        fontSize: r.fs(12))),
                              ],
                            )
                          : Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: EdgeInsets.all(r.s(8)),
                                child: GestureDetector(
                                  onTap: () => setState(() => _coverImageUrl = null),
                                  child: Container(
                                    padding: EdgeInsets.all(r.s(4)),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.close_rounded,
                                        color: Colors.white, size: r.s(16)),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: r.s(16)),

                  // Title (borderless, large)
                  TextField(
                    controller: _titleController,
                    style: TextStyle(
                      fontSize: r.fs(22),
                      fontWeight: FontWeight.w700,
                      color: _textColor,
                      fontFamily: _fontFamily,
                    ),
                    decoration: InputDecoration(
                      hintText: s.titleHint,
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                          color: _textColor.withValues(alpha: 0.3),
                          fontWeight: FontWeight.w700),
                      contentPadding: EdgeInsets.zero,
                    ),
                    maxLines: 2,
                    minLines: 1,
                  ),

                  // Subtitle
                  TextField(
                    controller: _subtitleController,
                    style: TextStyle(
                      fontSize: r.fs(16),
                      fontWeight: FontWeight.w500,
                      color: _textColor.withValues(alpha: 0.7),
                      fontFamily: _fontFamily,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Subtítulo (opcional)',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                          color: _textColor.withValues(alpha: 0.2),
                          fontWeight: FontWeight.w500),
                      contentPadding: EdgeInsets.zero,
                    ),
                    maxLines: 1,
                  ),

                  // Divider preview
                  _buildDividerPreview(),
                  SizedBox(height: r.s(8)),

                  // Toggle Blog Editor
                  if (_selectedType == 'normal' || _selectedType == 'blog')
                    Padding(
                      padding: EdgeInsets.only(bottom: r.s(8)),
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _useBlogEditor = !_useBlogEditor),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: r.s(12), vertical: r.s(6)),
                          decoration: BoxDecoration(
                            color: _useBlogEditor
                                ? AppTheme.accentColor.withValues(alpha: 0.15)
                                : _bgColor.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(r.s(20)),
                            border: _useBlogEditor
                                ? Border.all(
                                    color: AppTheme.accentColor
                                        .withValues(alpha: 0.4))
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.dashboard_customize_rounded,
                                size: r.s(14),
                                color: _useBlogEditor
                                    ? AppTheme.accentColor
                                    : _textColor.withValues(alpha: 0.5),
                              ),
                              SizedBox(width: r.s(6)),
                              Text(
                                'Editor de Blocos',
                                style: TextStyle(
                                  fontSize: r.fs(12),
                                  fontWeight: FontWeight.w600,
                                  color: _useBlogEditor
                                      ? AppTheme.accentColor
                                      : _textColor.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Content — Block Editor ou TextField com caixa maior
                  if (_useBlogEditor &&
                      (_selectedType == 'normal' || _selectedType == 'blog'))
                    BlockEditor(
                      key: _blockEditorKey,
                      communityId: widget.communityId,
                      initialBlocks: _contentBlocks.isEmpty
                          ? [ContentBlock(type: BlockType.text)]
                          : _contentBlocks,
                      onChanged: (blocks) => _contentBlocks = blocks,
                    )
                  else
                    Container(
                      constraints: BoxConstraints(minHeight: r.s(180)),
                      decoration: BoxDecoration(
                        color: _textColor.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(r.s(12)),
                        border: Border.all(color: _textColor.withValues(alpha: 0.06)),
                      ),
                      padding: EdgeInsets.all(r.s(12)),
                      child: TextField(
                        controller: _contentController,
                        style: TextStyle(
                          fontSize: r.fs(_bodyFontSize),
                          height: 1.6,
                          color: _textColor,
                          fontFamily: _fontFamily,
                        ),
                        decoration: InputDecoration(
                          hintText: s.writeContentHere,
                          border: InputBorder.none,
                          hintStyle: TextStyle(
                              color: _textColor.withValues(alpha: 0.25)),
                          contentPadding: EdgeInsets.zero,
                        ),
                        maxLines: null,
                        minLines: 8,
                      ),
                    ),

                  // Type-specific editors
                  if (_selectedType == 'poll') _buildPollEditor(),
                  if (_selectedType == 'quiz') _buildQuizEditor(),
                  if (_selectedType == 'link' || _selectedType == 'external')
                    _buildLinkEditor(),
                  if (_selectedType == 'image') _buildImageEditor(),
                  if (_selectedType == 'story') _buildStoryEditor(),
                  if (_selectedType == 'wiki') _buildWikiEditor(),
                  if (_selectedType == 'public_chat') _buildChatEditor(),
                  if (_selectedType == 'qa') _buildQaEditor(),
                  if (_selectedType == 'crosspost')
                    CrosspostPicker(
                      currentCommunityId: widget.communityId,
                      selectedCommunity: _crosspostCommunity,
                      onCommunitySelected: (c) {
                        setState(() => _crosspostCommunity = c);
                      },
                    ),

                  // ── Personalização avançada ──
                  SizedBox(height: r.s(16)),
                  _buildCustomizationSection(),

                  // ── Opções avançadas ──
                  SizedBox(height: r.s(8)),
                  _buildAdvancedOptions(),
                ],
              ),
            ),
          ),

          // ── Bottom toolbar ──
          _buildToolbar(),
        ],
      ),
    );
  }

  // ========================================================================
  // DIVIDER PREVIEW
  // ========================================================================
  Widget _buildDividerPreview() {
    final r = context.r;
    if (_dividerStyle == 'none') return const SizedBox.shrink();
    BorderSide border;
    switch (_dividerStyle) {
      case 'dashed':
        border = BorderSide(color: _dividerColor, width: 1);
        break;
      case 'dotted':
        border = BorderSide(color: _dividerColor, width: 1);
        break;
      default:
        border = BorderSide(color: _dividerColor, width: 1);
    }
    return Container(
      margin: EdgeInsets.symmetric(vertical: r.s(8)),
      width: double.infinity,
      height: 1,
      decoration: BoxDecoration(
        border: Border(bottom: border),
      ),
    );
  }

  // ========================================================================
  // CUSTOMIZATION SECTION — Cores, fontes, divisores
  // ========================================================================
  Widget _buildCustomizationSection() {
    final r = context.r;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Row(
          children: [
            Icon(Icons.palette_rounded, size: r.s(16), color: _textColor.withValues(alpha: 0.5)),
            SizedBox(width: r.s(8)),
            Text('Personalização',
                style: TextStyle(
                    fontSize: r.fs(13),
                    color: _textColor.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600)),
          ],
        ),
        iconColor: _textColor.withValues(alpha: 0.4),
        collapsedIconColor: _textColor.withValues(alpha: 0.4),
        children: [
          // Cor do texto
          _buildColorRow('Cor do texto', _textColor, (color) {
            setState(() => _textColor = color);
          }),
          SizedBox(height: r.s(10)),

          // Cor de fundo
          _buildColorRow('Cor de fundo', _bgColor, (color) {
            setState(() => _bgColor = color);
          }),
          SizedBox(height: r.s(10)),

          // Imagem de fundo
          GestureDetector(
            onTap: _pickBackgroundImage,
            child: Container(
              padding: EdgeInsets.all(r.s(12)),
              decoration: BoxDecoration(
                color: _textColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(r.s(10)),
              ),
              child: Row(
                children: [
                  Icon(Icons.wallpaper_rounded, size: r.s(18), color: _textColor.withValues(alpha: 0.5)),
                  SizedBox(width: r.s(10)),
                  Expanded(
                    child: Text(
                      _backgroundUrlController.text.isNotEmpty
                          ? 'Imagem de fundo definida'
                          : 'Adicionar imagem de fundo',
                      style: TextStyle(
                        color: _textColor.withValues(alpha: 0.6),
                        fontSize: r.fs(13),
                      ),
                    ),
                  ),
                  if (_backgroundUrlController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _backgroundUrlController.clear()),
                      child: Icon(Icons.close_rounded,
                          size: r.s(16), color: _textColor.withValues(alpha: 0.4)),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: r.s(10)),

          // Fonte
          Container(
            padding: EdgeInsets.all(r.s(12)),
            decoration: BoxDecoration(
              color: _textColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(r.s(10)),
            ),
            child: Row(
              children: [
                Icon(Icons.font_download_rounded, size: r.s(18), color: _textColor.withValues(alpha: 0.5)),
                SizedBox(width: r.s(10)),
                Expanded(
                  child: DropdownButton<String>(
                    value: _fontFamily,
                    dropdownColor: _bgColor,
                    style: TextStyle(color: _textColor, fontSize: r.fs(13)),
                    underline: const SizedBox.shrink(),
                    isExpanded: true,
                    items: _availableFonts
                        .map((f) => DropdownMenuItem(
                              value: f,
                              child: Text(f, style: TextStyle(fontFamily: f)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _fontFamily = v);
                    },
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r.s(10)),

          // Tamanho da fonte do corpo
          Container(
            padding: EdgeInsets.all(r.s(12)),
            decoration: BoxDecoration(
              color: _textColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(r.s(10)),
            ),
            child: Row(
              children: [
                Icon(Icons.format_size_rounded, size: r.s(18), color: _textColor.withValues(alpha: 0.5)),
                SizedBox(width: r.s(10)),
                Text('Tamanho: ${_bodyFontSize.toInt()}',
                    style: TextStyle(color: _textColor.withValues(alpha: 0.6), fontSize: r.fs(13))),
                Expanded(
                  child: Slider(
                    value: _bodyFontSize,
                    min: 12,
                    max: 28,
                    divisions: 16,
                    activeColor: AppTheme.primaryColor,
                    inactiveColor: _textColor.withValues(alpha: 0.1),
                    onChanged: (v) => setState(() => _bodyFontSize = v),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r.s(10)),

          // Estilo do divisor
          Container(
            padding: EdgeInsets.all(r.s(12)),
            decoration: BoxDecoration(
              color: _textColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(r.s(10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.horizontal_rule_rounded, size: r.s(18), color: _textColor.withValues(alpha: 0.5)),
                    SizedBox(width: r.s(10)),
                    Text('Estilo do divisor',
                        style: TextStyle(color: _textColor.withValues(alpha: 0.6), fontSize: r.fs(13))),
                  ],
                ),
                SizedBox(height: r.s(8)),
                Wrap(
                  spacing: r.s(8),
                  children: ['solid', 'dashed', 'dotted', 'none'].map((style) {
                    final isSelected = _dividerStyle == style;
                    return GestureDetector(
                      onTap: () => setState(() => _dividerStyle = style),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.s(12), vertical: r.s(6)),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryColor.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(r.s(16)),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primaryColor.withValues(alpha: 0.4)
                                : _textColor.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          style == 'solid'
                              ? 'Sólido'
                              : style == 'dashed'
                                  ? 'Tracejado'
                                  : style == 'dotted'
                                      ? 'Pontilhado'
                                      : 'Nenhum',
                          style: TextStyle(
                            fontSize: r.fs(11),
                            color: isSelected
                                ? AppTheme.primaryColor
                                : _textColor.withValues(alpha: 0.5),
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          SizedBox(height: r.s(16)),
        ],
      ),
    );
  }

  Widget _buildColorRow(String label, Color current, ValueChanged<Color> onChanged) {
    final r = context.r;
    final presetColors = [
      Colors.white,
      Colors.black,
      const Color(0xFF0D1B2A),
      const Color(0xFF1B2838),
      AppTheme.primaryColor,
      AppTheme.accentColor,
      AppTheme.fabPink,
      AppTheme.aminoPurple,
      AppTheme.aminoOrange,
      AppTheme.aminoYellow,
      AppTheme.aminoBlue,
      AppTheme.aminoRed,
    ];
    return Container(
      padding: EdgeInsets.all(r.s(12)),
      decoration: BoxDecoration(
        color: _textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(r.s(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: _textColor.withValues(alpha: 0.6), fontSize: r.fs(12))),
          SizedBox(height: r.s(8)),
          Wrap(
            spacing: r.s(6),
            runSpacing: r.s(6),
            children: presetColors.map((color) {
              final isSelected = current.toARGB32() == color.toARGB32();
              return GestureDetector(
                onTap: () => onChanged(color),
                child: Container(
                  width: r.s(28),
                  height: r.s(28),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.grey.withValues(alpha: 0.3),
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // ADVANCED OPTIONS
  // ========================================================================
  Widget _buildAdvancedOptions() {
    final s = getStrings();
    final r = context.r;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(s.advancedOptions,
            style: TextStyle(
                fontSize: r.fs(13),
                color: _textColor.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500)),
        iconColor: _textColor.withValues(alpha: 0.4),
        collapsedIconColor: _textColor.withValues(alpha: 0.4),
        children: [
          // Visibilidade
          Container(
            padding: EdgeInsets.all(r.s(12)),
            decoration: BoxDecoration(
              color: _textColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(r.s(10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: r.s(16), color: _textColor.withValues(alpha: 0.5)),
                    SizedBox(width: r.s(8)),
                    Text(s.visibility,
                        style: TextStyle(
                            fontSize: r.fs(13),
                            color: _textColor.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                SizedBox(height: r.s(8)),
                Wrap(
                  spacing: r.s(8),
                  children: [
                    _visibilityChip('public', s.publicLabel, Icons.public_rounded),
                    _visibilityChip('followers', s.followers, Icons.people_rounded),
                    _visibilityChip('private', s.privateLabel, Icons.lock_rounded),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: r.s(8)),
          // Bloquear comentários
          GestureDetector(
            onTap: () => setState(() => _commentsBlocked = !_commentsBlocked),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: r.s(12), vertical: r.s(10)),
              decoration: BoxDecoration(
                color: _commentsBlocked
                    ? AppTheme.errorColor.withValues(alpha: 0.1)
                    : _textColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(r.s(10)),
                border: Border.all(
                  color: _commentsBlocked
                      ? AppTheme.errorColor.withValues(alpha: 0.3)
                      : _textColor.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _commentsBlocked
                        ? Icons.comments_disabled_rounded
                        : Icons.comment_rounded,
                    size: r.s(16),
                    color: _commentsBlocked
                        ? AppTheme.errorColor
                        : _textColor.withValues(alpha: 0.5),
                  ),
                  SizedBox(width: r.s(8)),
                  Text(
                    _commentsBlocked ? s.commentsBlocked : s.allowComments,
                    style: TextStyle(
                      fontSize: r.fs(13),
                      color: _commentsBlocked
                          ? AppTheme.errorColor
                          : _textColor.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: !_commentsBlocked,
                    onChanged: (v) => setState(() => _commentsBlocked = !v),
                    activeColor: AppTheme.primaryColor,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: r.s(16)),
        ],
      ),
    );
  }

  // ========================================================================
  // VISIBILITY CHIP HELPER
  // ========================================================================
  Widget _visibilityChip(String value, String label, IconData icon) {
    final r = context.r;
    final isSelected = _postVisibility == value;
    return GestureDetector(
      onTap: () => setState(() => _postVisibility = value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: r.s(10), vertical: r.s(6)),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(r.s(20)),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.4)
                : _textColor.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: r.s(13),
                color: isSelected ? AppTheme.primaryColor : _textColor.withValues(alpha: 0.4)),
            SizedBox(width: r.s(4)),
            Text(label,
                style: TextStyle(
                    fontSize: r.fs(12),
                    color: isSelected ? AppTheme.primaryColor : _textColor.withValues(alpha: 0.4),
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // AMINO INPUT FIELD
  // ========================================================================
  Widget _buildAminoInput({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    int minLines = 1,
  }) {
    final r = context.r;
    return Container(
      decoration: BoxDecoration(
        color: _textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(r.s(10)),
        border: Border.all(color: _textColor.withValues(alpha: 0.05)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        minLines: minLines,
        style: TextStyle(fontSize: r.fs(13), color: _textColor),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: _textColor.withValues(alpha: 0.25), fontSize: r.fs(13)),
          prefixIcon: icon != null
              ? Icon(icon, size: r.s(18), color: _textColor.withValues(alpha: 0.4))
              : null,
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: r.s(12), vertical: r.s(12)),
        ),
      ),
    );
  }

  // ========================================================================
  // POLL EDITOR
  // ========================================================================
  Widget _buildPollEditor() {
    final s = getStrings();
    final r = context.r;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: r.s(16)),
        _buildDividerPreview(),
        SizedBox(height: r.s(12)),
        Text(s.pollOptionsLabel,
            style: TextStyle(
                color: _textColor.withValues(alpha: 0.6),
                fontSize: r.fs(13),
                fontWeight: FontWeight.w600)),
        SizedBox(height: r.s(8)),
        ...List.generate(_pollOptions.length, (i) {
          return Padding(
            padding: EdgeInsets.only(bottom: r.s(8)),
            child: Row(
              children: [
                Expanded(
                  child: _buildAminoInput(
                    controller: _pollOptions[i],
                    hint: 'Option ${i + 1}',
                    icon: Icons.circle_outlined,
                  ),
                ),
                if (_pollOptions.length > 2)
                  IconButton(
                    icon: Icon(Icons.remove_circle_rounded,
                        color: AppTheme.errorColor, size: r.s(18)),
                    onPressed: () {
                      setState(() {
                        _pollOptions[i].dispose();
                        _pollOptions.removeAt(i);
                      });
                    },
                  ),
              ],
            ),
          );
        }),
        GestureDetector(
          onTap: () =>
              setState(() => _pollOptions.add(TextEditingController())),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: r.s(10)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded,
                    size: r.s(16), color: AppTheme.primaryColor),
                SizedBox(width: r.s(6)),
                Text(s.addOptionLabel,
                    style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: r.fs(13),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // QUIZ EDITOR
  // ========================================================================
  Widget _buildQuizEditor() {
    final s = getStrings();
    final r = context.r;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: r.s(16)),
        _buildDividerPreview(),
        SizedBox(height: r.s(12)),
        Text(s.quizQuestionsLabel,
            style: TextStyle(
                color: _textColor.withValues(alpha: 0.6),
                fontSize: r.fs(13),
                fontWeight: FontWeight.w600)),
        SizedBox(height: r.s(8)),
        ...List.generate(_quizQuestions.length, (qi) {
          final q = _quizQuestions[qi];
          return Container(
            margin: EdgeInsets.only(bottom: r.s(12)),
            padding: EdgeInsets.all(r.s(12)),
            decoration: BoxDecoration(
              color: _textColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(r.s(12)),
              border: Border.all(color: _textColor.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(s.questionN(qi + 1),
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: r.fs(13),
                            color: _textColor)),
                    const Spacer(),
                    if (_quizQuestions.length > 1)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _quizQuestions[qi].dispose();
                            _quizQuestions.removeAt(qi);
                          });
                        },
                        child: Icon(Icons.delete_rounded,
                            color: AppTheme.errorColor, size: r.s(18)),
                      ),
                  ],
                ),
                SizedBox(height: r.s(8)),
                TextField(
                  controller: q.questionController,
                  style: TextStyle(fontSize: r.fs(13), color: _textColor),
                  decoration: InputDecoration(
                    hintText: 'Type the question...',
                    hintStyle: TextStyle(
                        color: _textColor.withValues(alpha: 0.25), fontSize: r.fs(13)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                SizedBox(height: r.s(8)),
                ...List.generate(q.options.length, (oi) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: r.s(4)),
                    child: Row(
                      children: [
                        Radio<int>(
                          value: oi,
                          groupValue: q.correctIndex,
                          onChanged: (v) {
                            setState(() => q.correctIndex = v ?? 0);
                          },
                          activeColor: AppTheme.successColor,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        Expanded(
                          child: TextField(
                            controller: q.options[oi],
                            style: TextStyle(
                                fontSize: r.fs(12), color: _textColor),
                            decoration: InputDecoration(
                              hintText: s.optionN(oi + 1),
                              hintStyle: TextStyle(
                                  color: _textColor.withValues(alpha: 0.25),
                                  fontSize: r.fs(12)),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () =>
                      setState(() => q.options.add(TextEditingController())),
                  child: Padding(
                    padding: EdgeInsets.only(top: r.s(4)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded,
                            size: r.s(14), color: AppTheme.primaryColor),
                        SizedBox(width: r.s(4)),
                        Text(s.optionLabel,
                            style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: r.fs(11),
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        GestureDetector(
          onTap: () => setState(() => _quizQuestions.add(_QuizQuestion())),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: r.s(10)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded,
                    size: r.s(16), color: AppTheme.primaryColor),
                SizedBox(width: r.s(6)),
                Text(s.addQuestion2,
                    style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: r.fs(13),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // LINK EDITOR
  // ========================================================================
  Widget _buildLinkEditor() {
    final s = getStrings();
    final r = context.r;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: r.s(16)),
        _buildDividerPreview(),
        SizedBox(height: r.s(12)),
        Text(s.externalLink,
            style: TextStyle(
                color: _textColor.withValues(alpha: 0.6),
                fontSize: r.fs(13),
                fontWeight: FontWeight.w600)),
        SizedBox(height: r.s(8)),
        _buildAminoInput(
          controller: _linkController,
          hint: 'https://...',
          icon: Icons.link_rounded,
          keyboardType: TextInputType.url,
        ),
      ],
    );
  }

  // ========================================================================
  // IMAGE EDITOR
  // ========================================================================
  Widget _buildImageEditor() {
    final s = getStrings();
    final r = context.r;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: r.s(16)),
        _buildDividerPreview(),
        SizedBox(height: r.s(12)),
        Text(s.imagesLabel,
            style: TextStyle(
                color: _textColor.withValues(alpha: 0.6),
                fontSize: r.fs(13),
                fontWeight: FontWeight.w600)),
        SizedBox(height: r.s(8)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._mediaUrls.map((url) => Stack(
                  children: [
                    Container(
                      width: r.s(80),
                      height: r.s(80),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(r.s(10)),
                        image: DecorationImage(
                          image: NetworkImage(url),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _mediaUrls.remove(url)),
                        child: Container(
                          padding: EdgeInsets.all(r.s(3)),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close_rounded,
                              color: Colors.white, size: r.s(12)),
                        ),
                      ),
                    ),
                  ],
                )),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: r.s(80),
                height: r.s(80),
                decoration: BoxDecoration(
                  color: _textColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(r.s(10)),
                  border: Border.all(color: _textColor.withValues(alpha: 0.08)),
                ),
                child: Icon(Icons.add_photo_alternate_rounded,
                    color: _textColor.withValues(alpha: 0.4), size: r.s(24)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ========================================================================
  // STORY EDITOR
  // ========================================================================
  Widget _buildStoryEditor() {
    final r = context.r;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: r.s(16)),
        _buildDividerPreview(),
        SizedBox(height: r.s(12)),
        Text('Configurações da Story',
            style: TextStyle(
                color: _textColor.withValues(alpha: 0.6),
                fontSize: r.fs(13),
                fontWeight: FontWeight.w600)),
        SizedBox(height: r.s(8)),
        _buildAminoInput(
          controller: _storyDurationController,
          hint: 'Duração (horas)',
          icon: Icons.timer_rounded,
          keyboardType: TextInputType.number,
        ),
        SizedBox(height: r.s(8)),
        _buildImageEditor(),
      ],
    );
  }

  // ========================================================================
  // WIKI EDITOR
  // ========================================================================
  Widget _buildWikiEditor() {
    final r = context.r;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: r.s(16)),
        _buildDividerPreview(),
        SizedBox(height: r.s(12)),
        Text('Entrada Wiki',
            style: TextStyle(
                color: _textColor.withValues(alpha: 0.6),
                fontSize: r.fs(13),
                fontWeight: FontWeight.w600)),
        SizedBox(height: r.s(8)),
        _buildAminoInput(
          controller: _wikiCategoryController,
          hint: 'Categoria',
          icon: Icons.category_rounded,
        ),
        SizedBox(height: r.s(12)),
        ...List.generate(_wikiSections.length, (i) {
          final section = _wikiSections[i];
          return Container(
            margin: EdgeInsets.only(bottom: r.s(12)),
            padding: EdgeInsets.all(r.s(12)),
            decoration: BoxDecoration(
              color: _textColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(r.s(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Seção ${i + 1}',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: r.fs(13),
                            color: _textColor)),
                    const Spacer(),
                    if (_wikiSections.length > 1)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _wikiSections[i].dispose();
                            _wikiSections.removeAt(i);
                          });
                        },
                        child: Icon(Icons.delete_rounded,
                            color: AppTheme.errorColor, size: r.s(18)),
                      ),
                  ],
                ),
                SizedBox(height: r.s(8)),
                TextField(
                  controller: section.titleController,
                  style: TextStyle(
                      fontSize: r.fs(14),
                      fontWeight: FontWeight.w600,
                      color: _textColor),
                  decoration: InputDecoration(
                    hintText: 'Título da seção',
                    hintStyle: TextStyle(color: _textColor.withValues(alpha: 0.25)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                SizedBox(height: r.s(4)),
                Container(
                  constraints: BoxConstraints(minHeight: r.s(80)),
                  child: TextField(
                    controller: section.contentController,
                    style: TextStyle(fontSize: r.fs(13), color: _textColor),
                    maxLines: null,
                    minLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Conteúdo da seção...',
                      hintStyle: TextStyle(color: _textColor.withValues(alpha: 0.25)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        GestureDetector(
          onTap: () => setState(() => _wikiSections.add(_WikiSection())),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: r.s(10)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded,
                    size: r.s(16), color: AppTheme.primaryColor),
                SizedBox(width: r.s(6)),
                Text('Adicionar seção',
                    style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: r.fs(13),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // CHAT PÚBLICO EDITOR
  // ========================================================================
  Widget _buildChatEditor() {
    final r = context.r;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: r.s(16)),
        _buildDividerPreview(),
        SizedBox(height: r.s(12)),
        Text('Chat Público',
            style: TextStyle(
                color: _textColor.withValues(alpha: 0.6),
                fontSize: r.fs(13),
                fontWeight: FontWeight.w600)),
        SizedBox(height: r.s(8)),
        _buildAminoInput(
          controller: _chatDescriptionController,
          hint: 'Descrição do chat...',
          icon: Icons.forum_rounded,
          maxLines: 3,
          minLines: 2,
        ),
        SizedBox(height: r.s(8)),
        _buildImageEditor(),
      ],
    );
  }

  // ========================================================================
  // Q&A EDITOR
  // ========================================================================
  Widget _buildQaEditor() {
    final r = context.r;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: r.s(16)),
        _buildDividerPreview(),
        SizedBox(height: r.s(12)),
        Text('Pergunta (Q&A)',
            style: TextStyle(
                color: _textColor.withValues(alpha: 0.6),
                fontSize: r.fs(13),
                fontWeight: FontWeight.w600)),
        SizedBox(height: r.s(8)),
        Container(
          padding: EdgeInsets.all(r.s(12)),
          decoration: BoxDecoration(
            color: AppTheme.accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(r.s(12)),
            border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Icon(Icons.help_outline_rounded,
                  color: AppTheme.accentColor, size: r.s(20)),
              SizedBox(width: r.s(10)),
              Expanded(
                child: Text(
                  'Use o campo de conteúdo acima para escrever sua pergunta. A comunidade poderá responder nos comentários.',
                  style: TextStyle(
                    color: _textColor.withValues(alpha: 0.7),
                    fontSize: r.fs(12),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: r.s(8)),
        GestureDetector(
          onTap: () => setState(() => _isQaClosed = !_isQaClosed),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: r.s(12), vertical: r.s(8)),
            decoration: BoxDecoration(
              color: _isQaClosed
                  ? AppTheme.warningColor.withValues(alpha: 0.1)
                  : _textColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(r.s(10)),
            ),
            child: Row(
              children: [
                Icon(
                  _isQaClosed ? Icons.lock_rounded : Icons.lock_open_rounded,
                  size: r.s(16),
                  color: _isQaClosed ? AppTheme.warningColor : _textColor.withValues(alpha: 0.5),
                ),
                SizedBox(width: r.s(8)),
                Text(
                  _isQaClosed ? 'Pergunta fechada' : 'Pergunta aberta',
                  style: TextStyle(
                    fontSize: r.fs(13),
                    color: _isQaClosed ? AppTheme.warningColor : _textColor.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // BOTTOM TOOLBAR
  // ========================================================================
  Widget _buildToolbar() {
    final s = getStrings();
    final r = context.r;
    return Container(
      padding: EdgeInsets.symmetric(vertical: r.s(8), horizontal: r.s(16)),
      decoration: BoxDecoration(
        color: _bgColor,
        border: Border(
          top: BorderSide(color: _textColor.withValues(alpha: 0.05)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ToolbarButton(Icons.image_rounded, s.image2, _pickImage, _textColor),
            _ToolbarButton(Icons.gif_rounded, s.gif, () async {
              final url = await GiphyPicker.show(context);
              if (url != null && mounted) {
                setState(() => _gifUrl = url);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(s.gifAddedToPost),
                      behavior: SnackBarBehavior.floating),
                );
              }
            }, _textColor),
            _ToolbarButton(Icons.music_note_rounded, 'Music', () {
              _showMusicPicker();
            }, _textColor),
            _ToolbarButton(Icons.format_bold_rounded, 'Bold',
                () => _wrapSelection('**', '**'), _textColor),
            _ToolbarButton(Icons.format_italic_rounded, 'Italic',
                () => _wrapSelection('_', '_'), _textColor),
            _ToolbarButton(Icons.format_strikethrough_rounded, s.strike,
                () => _wrapSelection('~~', '~~'), _textColor),
          ],
        ),
      ),
    );
  }

  void _showMusicPicker() {
    final s = getStrings();
    final r = context.r;
    final urlCtrl = TextEditingController(text: _musicUrl ?? '');
    final titleCtrl = TextEditingController(text: _musicTitle ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: r.s(20),
          right: r.s(20),
          top: r.s(20),
          bottom: MediaQuery.of(ctx).viewInsets.bottom + r.s(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.addMusicAction,
                style: TextStyle(
                    fontSize: r.fs(18),
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary)),
            SizedBox(height: r.s(16)),
            TextField(
              controller: titleCtrl,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: s.songNameHint,
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: context.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(10)),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.music_note_rounded,
                    color: AppTheme.primaryColor, size: r.s(18)),
              ),
            ),
            SizedBox(height: r.s(12)),
            TextField(
              controller: urlCtrl,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: s.audioFileUrl,
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: context.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(10)),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.link_rounded,
                    color: Colors.grey[600], size: r.s(18)),
              ),
            ),
            SizedBox(height: r.s(16)),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _musicUrl = urlCtrl.text.trim().isNotEmpty
                        ? urlCtrl.text.trim()
                        : null;
                    _musicTitle = titleCtrl.text.trim().isNotEmpty
                        ? titleCtrl.text.trim()
                        : null;
                  });
                  Navigator.pop(ctx);
                  if (_musicUrl != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(s.musicAddedToPost),
                          behavior: SnackBarBehavior.floating),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor),
                child: Text(s.confirm),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGETS E MODELOS AUXILIARES
// ============================================================================

class _PostTypeOption {
  final String value;
  final String label;
  final IconData icon;
  const _PostTypeOption(this.value, this.label, this.icon);
}

class _QuizQuestion {
  final TextEditingController questionController = TextEditingController();
  final List<TextEditingController> options = [
    TextEditingController(),
    TextEditingController(),
  ];
  int correctIndex = 0;

  void dispose() {
    questionController.dispose();
    for (final c in options) {
      c.dispose();
    }
  }
}

class _WikiSection {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController contentController = TextEditingController();

  void dispose() {
    titleController.dispose();
    contentController.dispose();
  }
}

class _ToolbarButton extends ConsumerWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color textColor;

  const _ToolbarButton(this.icon, this.tooltip, this.onTap, this.textColor);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(r.s(10)),
          child: Icon(icon, color: textColor.withValues(alpha: 0.4), size: r.s(20)),
        ),
      ),
    );
  }
}
