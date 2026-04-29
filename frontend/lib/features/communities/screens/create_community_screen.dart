import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/media_upload_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/rgb_color_picker.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import 'package:amino_clone/config/nexus_theme_data.dart';
import 'package:image_cropper/image_cropper.dart';

// ============================================================
// TELA DE CRIAÇÃO DE COMUNIDADE — Wizard Multi-Etapas
// Etapas:
//   1. Identidade (nome, tagline, ícone, banner)
//   2. Sobre (descrição, about, tags)
//   3. Configurações (categoria, idioma, acesso, visibilidade, cor)
//   4. Regras (regras iniciais)
//   5. Preview + Confirmar
// ============================================================

class CreateCommunityScreen extends ConsumerStatefulWidget {
  const CreateCommunityScreen({super.key});
  @override
  ConsumerState<CreateCommunityScreen> createState() =>
      _CreateCommunityScreenState();
}

class _CreateCommunityScreenState
    extends ConsumerState<CreateCommunityScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  static const int _totalSteps = 5;

  // ── Etapa 1: Identidade ──────────────────────────────────
  final _nameController = TextEditingController();
  final _taglineController = TextEditingController();
  String _iconUrl = '';
  String _bannerUrl = '';
  bool _uploadingIcon = false;
  bool _uploadingBanner = false;

  // ── Etapa 2: Sobre ──────────────────────────────────────
  final _descriptionController = TextEditingController();
  final _aboutController = TextEditingController();
  final _tagInputController = TextEditingController();
  List<String> _tags = [];

  // ── Etapa 3: Configurações ──────────────────────────────
  String _category = 'general';
  String _language = 'pt-BR';
  String _joinType = 'open';
  String _listedStatus = 'listed';
  String _themeColor = '#6C5CE7';

  // ── Etapa 4: Regras ─────────────────────────────────────
  final _rulesController = TextEditingController();

  // ── Estado geral ────────────────────────────────────────
  bool _isLoading = false;
  final _formKeys = List.generate(5, (_) => GlobalKey<FormState>());

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _taglineController.dispose();
    _descriptionController.dispose();
    _aboutController.dispose();
    _tagInputController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  // ── Upload helpers ───────────────────────────────────────
  Future<String?> _uploadAsset(String folder, {bool isIcon = false}) async {
    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final file = await MediaUploadService.pickImage(
        context: context,
        maxWidth: isIcon ? 512 : 1920,
        maxHeight: isIcon ? 512 : 1080,
      );
      if (file == null || !mounted) return null;
      final fileToUpload = isIcon
          ? await MediaUploadService.cropImage(
                file,
                aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
                useCircleCrop: true,
                maxWidth: 512,
                maxHeight: 512,
              ) ??
              file
          : file;
      final customPath =
          '$userId/new/$folder/${DateTime.now().millisecondsSinceEpoch}.webp';
      final result = await MediaUploadService.uploadFile(
        file: fileToUpload,
        bucket:
            isIcon ? MediaBucket.communityIcons : MediaBucket.communityBanners,
        customPath: customPath,
        context: context,
      );
      return result?.url;
    } catch (e) {
      debugPrint('[create_community] upload error ($folder): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erro ao fazer upload. Tente novamente.'),
            backgroundColor: context.nexusTheme.error,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _pickIcon() async {
    setState(() => _uploadingIcon = true);
    final url = await _uploadAsset('icon', isIcon: true);
    if (mounted) {
      setState(() {
        _uploadingIcon = false;
        if (url != null) _iconUrl = url;
      });
    }
  }

  Future<void> _pickBanner() async {
    setState(() => _uploadingBanner = true);
    final url = await _uploadAsset('banner');
    if (mounted) {
      setState(() {
        _uploadingBanner = false;
        if (url != null) _bannerUrl = url;
      });
    }
  }

  // ── Navegação entre etapas ───────────────────────────────
  void _nextStep() {
    if (_formKeys[_currentStep].currentState?.validate() == false) return;
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      context.pop();
    }
  }

  // ── Criação da comunidade ────────────────────────────────
  Future<void> _createCommunity() async {
    final s = getStrings();
    setState(() => _isLoading = true);
    try {
      final result = await SupabaseService.rpc(
        'create_community',
        params: {
          'p_name': _nameController.text.trim(),
          'p_tagline': _taglineController.text.trim(),
          'p_description': _descriptionController.text.trim(),
          'p_category': _category,
          'p_join_type': _joinType,
          'p_theme_color': _themeColor,
          'p_primary_language': _language,
          'p_icon_url': _iconUrl.isNotEmpty ? _iconUrl : null,
          'p_banner_url': _bannerUrl.isNotEmpty ? _bannerUrl : null,
          'p_tags': _tags,
          'p_rules': _rulesController.text.trim(),
          'p_about': _aboutController.text.trim(),
          'p_listed_status': _listedStatus,
        },
      );
      final response = Map<String, dynamic>.from(result as Map);
      final communityId = response['community_id'] as String?;
      final success = response['success'] == true && communityId != null;
      if (!mounted) return;
      if (!success) {
        final error = response['error'] as String? ?? 'unknown';
        final message = switch (error) {
          'unauthenticated' => s.needLoginToCreateCommunity,
          'name_required' => s.communityNameRequired,
          _ => s.errorCreatingCommunity,
        };
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
        return;
      }
      context.pop();
      context.push('/community/$communityId');
    } catch (e) {
      debugPrint('[create_community] error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(getStrings().errorCreatingCommunity)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return context.nexusTheme.accentPrimary;
    }
  }

  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final theme = context.nexusTheme;

    final stepTitles = [
      'Identidade',
      'Sobre',
      'Configurações',
      'Regras',
      'Revisão',
    ];

    return Scaffold(
      backgroundColor: theme.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, r, theme, s, stepTitles),
            _buildProgressBar(r, theme),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1Identity(r, theme, s),
                  _buildStep2About(r, theme, s),
                  _buildStep3Settings(r, theme, s),
                  _buildStep4Rules(r, theme, s),
                  _buildStep5Preview(r, theme, s),
                ],
              ),
            ),
            _buildNavButtons(r, theme, s),
          ],
        ),
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context, Responsive r,
      NexusThemeData theme, AppStrings s, List<String> stepTitles) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(12)),
      child: Row(
        children: [
          GestureDetector(
            onTap: _prevStep,
            child: Container(
              padding: EdgeInsets.all(r.s(8)),
              decoration: BoxDecoration(
                color: theme.surfaceColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(r.s(10)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Icon(Icons.arrow_back_rounded,
                  color: theme.textPrimary, size: r.s(20)),
            ),
          ),
          SizedBox(width: r.s(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.createCommunityTitle,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: r.fs(17),
                  ),
                ),
                Text(
                  'Etapa ${_currentStep + 1} de $_totalSteps — ${stepTitles[_currentStep]}',
                  style: TextStyle(
                      color: theme.textSecondary, fontSize: r.fs(12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Barra de progresso ───────────────────────────────────
  Widget _buildProgressBar(Responsive r, NexusThemeData theme) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.s(16)),
      child: Row(
        children: List.generate(_totalSteps, (i) {
          final isCompleted = i < _currentStep;
          final isCurrent = i == _currentStep;
          return Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: r.s(2)),
              height: r.s(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r.s(2)),
                color: isCompleted
                    ? theme.accentPrimary
                    : isCurrent
                        ? theme.accentPrimary.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.1),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Etapa 1: Identidade ──────────────────────────────────
  Widget _buildStep1Identity(
      Responsive r, NexusThemeData theme, AppStrings s) {
    return Form(
      key: _formKeys[0],
      child: SingleChildScrollView(
        padding: EdgeInsets.all(r.s(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(r, theme, 'Identidade Visual', Icons.palette_rounded),
            SizedBox(height: r.s(4)),
            Text(
              'Defina o nome, tagline e as imagens que representam sua comunidade.',
              style: TextStyle(color: theme.textSecondary, fontSize: r.fs(13)),
            ),
            SizedBox(height: r.s(24)),
            _ImageUploadCard(
              label: 'Banner de capa',
              icon: Icons.panorama_rounded,
              imageUrl: _bannerUrl,
              isBanner: true,
              isLoading: _uploadingBanner,
              onPickImage: _pickBanner,
              onRemove:
                  _bannerUrl.isNotEmpty ? () => setState(() => _bannerUrl = '') : null,
              r: r,
              theme: theme,
              sizeSpec: '1920 × 1080 px · 16:9 · Máx. 5 MB · JPG/PNG/WebP',
            ),
            SizedBox(height: r.s(16)),
            _ImageUploadCard(
              label: 'Ícone da comunidade',
              icon: Icons.image_rounded,
              imageUrl: _iconUrl,
              isCircle: true,
              isLoading: _uploadingIcon,
              onPickImage: _pickIcon,
              onRemove:
                  _iconUrl.isNotEmpty ? () => setState(() => _iconUrl = '') : null,
              r: r,
              theme: theme,
              sizeSpec: '512 × 512 px · 1:1 · Máx. 2 MB · JPG/PNG/WebP',
            ),
            SizedBox(height: r.s(20)),
            _buildTextField(
              controller: _nameController,
              label: s.communityName,
              hint: 'Ex: Anime Brasil, Fotografia Urbana...',
              icon: Icons.group_rounded,
              r: r,
              theme: theme,
              maxLength: 30,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return s.communityNameRequired;
                if (v.trim().length < 3) return 'Mínimo 3 caracteres';
                return null;
              },
            ),
            SizedBox(height: r.s(16)),
            _buildTextField(
              controller: _taglineController,
              label: s.taglineLabel,
              hint: 'Uma frase curta que descreve sua comunidade',
              icon: Icons.short_text_rounded,
              r: r,
              theme: theme,
              maxLength: 60,
            ),
          ],
        ),
      ),
    );
  }

  // ── Etapa 2: Sobre ───────────────────────────────────────
  Widget _buildStep2About(
      Responsive r, NexusThemeData theme, AppStrings s) {
    return Form(
      key: _formKeys[1],
      child: SingleChildScrollView(
        padding: EdgeInsets.all(r.s(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
                r, theme, 'Sobre a Comunidade', Icons.info_outline_rounded),
            SizedBox(height: r.s(4)),
            Text(
              'Conte mais sobre o propósito e tema da sua comunidade.',
              style: TextStyle(color: theme.textSecondary, fontSize: r.fs(13)),
            ),
            SizedBox(height: r.s(24)),
            _buildTextField(
              controller: _descriptionController,
              label: s.communityDescription,
              hint: s.communityDescriptionHint,
              icon: Icons.description_rounded,
              r: r,
              theme: theme,
              maxLines: 4,
              maxLength: 500,
            ),
            SizedBox(height: r.s(16)),
            _buildTextField(
              controller: _aboutController,
              label: 'Texto "Sobre" (opcional)',
              hint:
                  'Texto mais longo exibido na página de informações da comunidade',
              icon: Icons.article_rounded,
              r: r,
              theme: theme,
              maxLines: 5,
              maxLength: 1000,
            ),
            SizedBox(height: r.s(20)),
            _sectionTitle(r, theme, 'Tags', Icons.label_outline_rounded),
            SizedBox(height: r.s(8)),
            Text(
              'Adicione até 10 tags para facilitar a descoberta da comunidade.',
              style: TextStyle(color: theme.textSecondary, fontSize: r.fs(12)),
            ),
            SizedBox(height: r.s(12)),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _tagInputController,
                    style:
                        TextStyle(color: theme.textPrimary, fontSize: r.fs(14)),
                    decoration: InputDecoration(
                      hintText: 'Digite uma tag e pressione Enter',
                      hintStyle: TextStyle(
                          color: Colors.grey[600], fontSize: r.fs(13)),
                      prefixIcon: Icon(Icons.tag_rounded,
                          color: theme.accentSecondary, size: r.s(18)),
                      filled: true,
                      fillColor: theme.surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(r.s(12)),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: r.s(12), vertical: r.s(12)),
                    ),
                    onFieldSubmitted: _addTag,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                  ),
                ),
                SizedBox(width: r.s(8)),
                GestureDetector(
                  onTap: () => _addTag(_tagInputController.text),
                  child: Container(
                    padding: EdgeInsets.all(r.s(12)),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        theme.accentPrimary,
                        theme.accentSecondary
                      ]),
                      borderRadius: BorderRadius.circular(r.s(12)),
                    ),
                    child: Icon(Icons.add_rounded,
                        color: Colors.white, size: r.s(20)),
                  ),
                ),
              ],
            ),
            if (_tags.isNotEmpty) ...[
              SizedBox(height: r.s(12)),
              Wrap(
                spacing: r.s(8),
                runSpacing: r.s(8),
                children: _tags
                    .map((tag) => _TagChip(
                          tag: tag,
                          color: _parseColor(_themeColor),
                          onRemove: () => setState(() => _tags.remove(tag)),
                          r: r,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _addTag(String value) {
    final tag = value.trim().replaceAll('#', '').toLowerCase();
    if (tag.isEmpty || _tags.contains(tag) || _tags.length >= 10) return;
    setState(() {
      _tags.add(tag);
      _tagInputController.clear();
    });
  }

  // ── Etapa 3: Configurações ───────────────────────────────
  Widget _buildStep3Settings(
      Responsive r, NexusThemeData theme, AppStrings s) {
    return Form(
      key: _formKeys[2],
      child: SingleChildScrollView(
        padding: EdgeInsets.all(r.s(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(r, theme, 'Configurações', Icons.settings_rounded),
            SizedBox(height: r.s(4)),
            Text(
              'Defina como sua comunidade funciona e quem pode entrar.',
              style: TextStyle(color: theme.textSecondary, fontSize: r.fs(13)),
            ),
            SizedBox(height: r.s(24)),
            _buildDropdown(
              label: s.category,
              icon: Icons.category_rounded,
              value: _category,
              items: const [
                ('general', 'Geral'),
                ('anime', 'Anime & Manga'),
                ('games', 'Games'),
                ('music', 'Música'),
                ('art', 'Arte & Design'),
                ('sports', 'Esportes'),
                ('technology', 'Tecnologia'),
                ('lifestyle', 'Estilo de Vida'),
                ('education', 'Educação'),
                ('entertainment', 'Entretenimento'),
                ('other', 'Outro'),
              ],
              onChanged: (v) => setState(() => _category = v),
              r: r,
              theme: theme,
            ),
            SizedBox(height: r.s(16)),
            _buildDropdown(
              label: s.primaryLanguage,
              icon: Icons.language_rounded,
              value: _language,
              items: const [
                ('pt-BR', 'Português (Brasil)'),
                ('en', 'English'),
                ('es', 'Español'),
                ('ja', '日本語'),
                ('ko', '한국어'),
                ('fr', 'Français'),
                ('de', 'Deutsch'),
              ],
              onChanged: (v) => setState(() => _language = v),
              r: r,
              theme: theme,
            ),
            SizedBox(height: r.s(20)),
            _sectionTitle(
                r, theme, 'Tipo de Acesso', Icons.lock_outline_rounded),
            SizedBox(height: r.s(12)),
            _buildRadioGroup(
              value: _joinType,
              options: [
                (
                  'open',
                  s.openEntry,
                  'Qualquer pessoa pode entrar',
                  Icons.public_rounded
                ),
                (
                  'request',
                  s.requestButton,
                  'Usuários precisam solicitar entrada',
                  Icons.how_to_reg_rounded
                ),
                (
                  'invite',
                  s.inviteOnly,
                  'Somente por convite',
                  Icons.mail_outline_rounded
                ),
              ],
              onChanged: (v) => setState(() => _joinType = v),
              r: r,
              theme: theme,
            ),
            SizedBox(height: r.s(20)),
            _sectionTitle(r, theme, 'Visibilidade', Icons.visibility_outlined),
            SizedBox(height: r.s(12)),
            _buildRadioGroup(
              value: _listedStatus,
              options: [
                (
                  'listed',
                  s.listedVisibility,
                  'Aparece nas buscas e no Discover',
                  Icons.search_rounded
                ),
                (
                  'unlisted',
                  s.unlistedVisibility,
                  'Só acessível por link direto',
                  Icons.link_off_rounded
                ),
              ],
              onChanged: (v) => setState(() => _listedStatus = v),
              r: r,
              theme: theme,
            ),
            SizedBox(height: r.s(20)),
            _sectionTitle(r, theme, s.themeColor, Icons.color_lens_rounded),
            SizedBox(height: r.s(12)),
            ColorPickerButton(
              color: _parseColor(_themeColor),
              onColorChanged: (color) => setState(() {
                _themeColor = '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
              }),
              title: 'Cor do Tema',
            ),
          ],
        ),
      ),
    );
  }

  // ── Etapa 4: Regras ──────────────────────────────────────
  Widget _buildStep4Rules(
      Responsive r, NexusThemeData theme, AppStrings s) {
    return Form(
      key: _formKeys[3],
      child: SingleChildScrollView(
        padding: EdgeInsets.all(r.s(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
                r, theme, 'Regras da Comunidade', Icons.gavel_rounded),
            SizedBox(height: r.s(4)),
            Text(
              'Defina as regras que os membros devem seguir. Você pode editar depois.',
              style: TextStyle(color: theme.textSecondary, fontSize: r.fs(13)),
            ),
            SizedBox(height: r.s(24)),
            Text(
              'Regras rápidas (toque para adicionar)',
              style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: r.fs(12),
                  fontWeight: FontWeight.w500),
            ),
            SizedBox(height: r.s(10)),
            Wrap(
              spacing: r.s(8),
              runSpacing: r.s(8),
              children: [
                'Seja respeitoso',
                'Sem spam',
                'Sem conteúdo NSFW',
                'Sem bullying',
                'Mantenha o tema',
                'Sem divulgação',
              ]
                  .map((rule) => GestureDetector(
                        onTap: () {
                          final current = _rulesController.text;
                          final newRule = '- $rule\n';
                          if (!current.contains(rule)) {
                            _rulesController.text = current + newRule;
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: r.s(12), vertical: r.s(6)),
                          decoration: BoxDecoration(
                            color: theme.accentPrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(r.s(20)),
                            border: Border.all(
                                color: theme.accentPrimary
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded,
                                  size: r.s(14), color: theme.accentPrimary),
                              SizedBox(width: r.s(4)),
                              Text(rule,
                                  style: TextStyle(
                                      color: theme.accentPrimary,
                                      fontSize: r.fs(12),
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
            SizedBox(height: r.s(16)),
            TextFormField(
              controller: _rulesController,
              maxLines: 12,
              style: TextStyle(color: theme.textPrimary, fontSize: r.fs(14)),
              decoration: InputDecoration(
                hintText:
                    'Ex:\n- Seja respeitoso com todos\n- Sem spam ou divulgação\n- Mantenha o conteúdo no tema da comunidade',
                hintStyle:
                    TextStyle(color: Colors.grey[600], fontSize: r.fs(13)),
                filled: true,
                fillColor: theme.surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  borderSide: BorderSide(color: theme.accentPrimary),
                ),
                contentPadding: EdgeInsets.all(r.s(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Etapa 5: Preview ─────────────────────────────────────
  Widget _buildStep5Preview(
      Responsive r, NexusThemeData theme, AppStrings s) {
    final accentColor = _parseColor(_themeColor);
    final name = _nameController.text.trim().isEmpty
        ? 'Nome da Comunidade'
        : _nameController.text.trim();
    final tagline = _taglineController.text.trim().isEmpty
        ? 'Tagline da comunidade'
        : _taglineController.text.trim();

    return Form(
      key: _formKeys[4],
      child: SingleChildScrollView(
        padding: EdgeInsets.all(r.s(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
                r, theme, 'Revisão Final', Icons.check_circle_outline_rounded),
            SizedBox(height: r.s(4)),
            Text(
              'Confira as informações antes de criar sua comunidade.',
              style: TextStyle(color: theme.textSecondary, fontSize: r.fs(13)),
            ),
            SizedBox(height: r.s(24)),
            // Preview card
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r.s(16)),
                border:
                    Border.all(color: accentColor.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    height: r.s(100),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: _bannerUrl.isEmpty
                          ? LinearGradient(
                              colors: [
                                accentColor,
                                accentColor.withValues(alpha: 0.5)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      image: _bannerUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(_bannerUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                  ),
                  Container(
                    color: theme.surfaceColor,
                    padding: EdgeInsets.all(r.s(16)),
                    child: Row(
                      children: [
                        Container(
                          width: r.s(56),
                          height: r.s(56),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor.withValues(alpha: 0.2),
                            border: Border.all(
                                color: accentColor.withValues(alpha: 0.5),
                                width: 2),
                            image: _iconUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(_iconUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _iconUrl.isEmpty
                              ? Icon(Icons.group_rounded,
                                  color: accentColor, size: r.s(28))
                              : null,
                        ),
                        SizedBox(width: r.s(12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style: TextStyle(
                                      color: theme.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: r.fs(16))),
                              SizedBox(height: r.s(2)),
                              Text(tagline,
                                  style: TextStyle(
                                      color: theme.textSecondary,
                                      fontSize: r.fs(12))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.s(20)),
            _buildSummaryCard(r, theme, s, accentColor),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Responsive r, NexusThemeData theme,
      AppStrings s, Color accentColor) {
    final joinLabels = {
      'open': 'Aberta',
      'request': 'Por solicitação',
      'invite': 'Somente convite',
    };
    final listedLabels = {
      'listed': 'Listada (visível no Discover)',
      'unlisted': 'Não listada (link direto)',
    };
    final categoryLabels = {
      'general': 'Geral',
      'anime': 'Anime & Manga',
      'games': 'Games',
      'music': 'Música',
      'art': 'Arte & Design',
      'sports': 'Esportes',
      'technology': 'Tecnologia',
      'lifestyle': 'Estilo de Vida',
      'education': 'Educação',
      'entertainment': 'Entretenimento',
      'other': 'Outro',
    };
    final rows = [
      (Icons.category_rounded, 'Categoria', categoryLabels[_category] ?? _category),
      (Icons.language_rounded, 'Idioma', _language),
      (Icons.lock_outline_rounded, 'Acesso', joinLabels[_joinType] ?? _joinType),
      (Icons.visibility_outlined, 'Visibilidade', listedLabels[_listedStatus] ?? _listedStatus),
      (Icons.label_outline_rounded, 'Tags', _tags.isEmpty ? 'Nenhuma' : _tags.map((t) => '#$t').join(' ')),
    ];
    return Container(
      padding: EdgeInsets.all(r.s(16)),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(12)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: rows.map((row) {
          final (icon, label, value) = row;
          return Padding(
            padding: EdgeInsets.symmetric(vertical: r.s(8)),
            child: Row(
              children: [
                Icon(icon, color: accentColor, size: r.s(18)),
                SizedBox(width: r.s(10)),
                Text(label,
                    style: TextStyle(
                        color: theme.textSecondary, fontSize: r.fs(13))),
                const Spacer(),
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: r.fs(13),
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Botões de navegação ──────────────────────────────────
  Widget _buildNavButtons(
      Responsive r, NexusThemeData theme, AppStrings s) {
    final isLast = _currentStep == _totalSteps - 1;
    return Container(
      padding: EdgeInsets.all(r.s(16)),
      decoration: BoxDecoration(
        color: theme.backgroundPrimary,
        border:
            Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : _prevStep,
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.textPrimary,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  padding: EdgeInsets.symmetric(vertical: r.s(14)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.s(12))),
                ),
                child: Text(s.back, style: TextStyle(fontSize: r.fs(15))),
              ),
            ),
            SizedBox(width: r.s(12)),
          ],
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: _isLoading
                  ? null
                  : isLast
                      ? _createCommunity
                      : _nextStep,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: r.s(14)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.accentPrimary, theme.accentSecondary],
                  ),
                  borderRadius: BorderRadius.circular(r.s(12)),
                  boxShadow: [
                    BoxShadow(
                      color: theme.accentPrimary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: _isLoading
                      ? SizedBox(
                          width: r.s(22),
                          height: r.s(22),
                          child: const CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isLast ? s.create : s.next,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: r.fs(15),
                              ),
                            ),
                            SizedBox(width: r.s(6)),
                            Icon(
                              isLast
                                  ? Icons.check_rounded
                                  : Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: r.s(18),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers de UI ────────────────────────────────────────
  Widget _sectionTitle(
      Responsive r, NexusThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: theme.accentPrimary, size: r.s(20)),
        SizedBox(width: r.s(8)),
        Text(
          title,
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: r.fs(16),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Responsive r,
    required NexusThemeData theme,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      style: TextStyle(color: theme.textPrimary, fontSize: r.fs(14)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[500]),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[600], fontSize: r.fs(13)),
        prefixIcon: Icon(icon, color: theme.accentSecondary, size: r.s(20)),
        alignLabelWithHint: maxLines > 1,
        filled: true,
        fillColor: theme.surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.s(12)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.s(12)),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.s(12)),
          borderSide: BorderSide(color: theme.accentPrimary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.s(12)),
          borderSide: BorderSide(color: theme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.s(12)),
          borderSide: BorderSide(color: theme.error),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<(String, String)> items,
    required void Function(String) onChanged,
    required Responsive r,
    required NexusThemeData theme,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(12)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        dropdownColor: theme.surfaceColor,
        style: TextStyle(color: theme.textPrimary, fontSize: r.fs(14)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(icon, color: theme.accentSecondary, size: r.s(20)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(r.s(12)),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(16)),
        ),
        items: items
            .map((item) =>
                DropdownMenuItem(value: item.$1, child: Text(item.$2)))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _buildRadioGroup({
    required String value,
    required List<(String, String, String, IconData)> options,
    required void Function(String) onChanged,
    required Responsive r,
    required NexusThemeData theme,
  }) {
    return Column(
      children: options.map((opt) {
        final (key, label, desc, icon) = opt;
        final isSelected = value == key;
        return GestureDetector(
          onTap: () => onChanged(key),
          child: Container(
            margin: EdgeInsets.only(bottom: r.s(8)),
            padding: EdgeInsets.all(r.s(14)),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.accentPrimary.withValues(alpha: 0.08)
                  : theme.surfaceColor,
              borderRadius: BorderRadius.circular(r.s(12)),
              border: Border.all(
                color: isSelected
                    ? theme.accentPrimary.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.05),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(r.s(8)),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.accentPrimary.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(r.s(8)),
                  ),
                  child: Icon(icon,
                      color: isSelected
                          ? theme.accentPrimary
                          : theme.textSecondary,
                      size: r.s(18)),
                ),
                SizedBox(width: r.s(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: TextStyle(
                              color: theme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: r.fs(14))),
                      Text(desc,
                          style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: r.fs(12))),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded,
                      color: theme.accentPrimary, size: r.s(20)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ============================================================
// WIDGET: Card de upload de imagem (reutilizável)
// ============================================================
class _ImageUploadCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String imageUrl;
  final bool isCircle;
  final bool isBanner;
  final bool isLoading;
  final VoidCallback onPickImage;
  final VoidCallback? onRemove;
  final Responsive r;
  final NexusThemeData theme;
  /// Especificações de tamanho exibidas abaixo do label.
  final String? sizeSpec;

  const _ImageUploadCard({
    required this.label,
    required this.icon,
    required this.imageUrl,
    this.isCircle = false,
    this.isBanner = false,
    required this.isLoading,
    required this.onPickImage,
    this.onRemove,
    required this.r,
    required this.theme,
    this.sizeSpec,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.isNotEmpty;
    return Container(
      padding: EdgeInsets.all(r.s(16)),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(12)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: r.s(1)),
                child: Icon(icon, color: theme.accentPrimary, size: r.s(18)),
              ),
              SizedBox(width: r.s(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: r.fs(14),
                            color: theme.textPrimary)),
                    if (sizeSpec != null) ...[  
                      SizedBox(height: r.s(3)),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.s(7), vertical: r.s(3)),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(r.s(4)),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.straighten_rounded,
                                size: r.s(10), color: Colors.grey[500]),
                            SizedBox(width: r.s(4)),
                            Flexible(
                              child: Text(
                                sizeSpec!,
                                style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: r.fs(10),
                                    fontFamily: 'monospace',
                                    letterSpacing: 0.2),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasImage && onRemove != null)
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: EdgeInsets.all(r.s(4)),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(r.s(6)),
                    ),
                    child: Icon(Icons.delete_outline_rounded,
                        color: Colors.red, size: r.s(16)),
                  ),
                ),
            ],
          ),
          SizedBox(height: r.s(12)),
          if (isCircle) ...[
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: r.s(90),
                    height: r.s(90),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.backgroundPrimary,
                      border: Border.all(
                        color: hasImage
                            ? theme.accentPrimary.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.1),
                        width: 2,
                      ),
                      image: hasImage
                          ? DecorationImage(
                              image: NetworkImage(imageUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: !hasImage
                        ? Icon(Icons.add_photo_alternate_rounded,
                            color: Colors.grey[600], size: r.s(28))
                        : null,
                  ),
                  if (isLoading)
                    Container(
                      width: r.s(90),
                      height: r.s(90),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                      child: Center(
                        child: SizedBox(
                          width: r.s(24),
                          height: r.s(24),
                          child: const CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: r.s(12)),
            Center(
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : onPickImage,
                icon: Icon(Icons.upload_rounded, size: r.s(16)),
                label: Text(
                    hasImage ? 'Trocar imagem' : 'Fazer upload',
                    style: TextStyle(fontSize: r.fs(13))),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.accentPrimary,
                  side: BorderSide(
                      color: theme.accentPrimary.withValues(alpha: 0.5)),
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(20), vertical: r.s(8)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.s(8))),
                ),
              ),
            ),
          ] else ...[
            Stack(
              children: [
                GestureDetector(
                  onTap: isLoading ? null : onPickImage,
                  child: Container(
                    height: r.s(110),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.backgroundPrimary,
                      borderRadius: BorderRadius.circular(r.s(10)),
                      border: Border.all(
                        color: hasImage
                            ? theme.accentPrimary.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.08),
                        width: hasImage ? 1.5 : 1,
                      ),
                      image: hasImage
                          ? DecorationImage(
                              image: NetworkImage(imageUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: !hasImage
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_rounded,
                                  color: Colors.grey[600], size: r.s(32)),
                              SizedBox(height: r.s(6)),
                              Text('Toque para fazer upload',
                                  style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: r.fs(12))),
                            ],
                          )
                        : null,
                  ),
                ),
                if (isLoading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(r.s(10)),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                    ),
                  ),
                if (hasImage && !isLoading)
                  Positioned(
                    bottom: r.s(8),
                    right: r.s(8),
                    child: GestureDetector(
                      onTap: onPickImage,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: r.s(10), vertical: r.s(5)),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(r.s(6)),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.upload_rounded,
                                color: Colors.white, size: r.s(13)),
                            SizedBox(width: r.s(4)),
                            Text('Trocar',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: r.fs(11),
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Tag chip ─────────────────────────────────────────────────
class _TagChip extends StatelessWidget {
  final String tag;
  final Color color;
  final VoidCallback onRemove;
  final Responsive r;

  const _TagChip({
    required this.tag,
    required this.color,
    required this.onRemove,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.s(10), vertical: r.s(5)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(r.s(20)),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('#$tag',
              style: TextStyle(
                  color: color,
                  fontSize: r.fs(12),
                  fontWeight: FontWeight.w600)),
          SizedBox(width: r.s(4)),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, color: color, size: r.s(14)),
          ),
        ],
      ),
    );
  }
}
