import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../core/services/media_upload_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/widgets/rgb_color_picker.dart';
import '../../communities/providers/community_detail_providers.dart';
import '../widgets/frame_picker_sheet.dart';

/// Editar Perfil da Comunidade — estilo Amino Apps.
///
/// Layout fiel à referência do Amino:
///   - Topo: banner com avatar circular centralizado + "Editar Molduras de Perfil"
///   - Linha 1: ícone de pessoa cinza | campo de nickname estilizado
///   - Linha 2: (espaço para bio)
///   - Linha 3: ícone de paleta | "Plano de Fundo (Opcional)" | thumbnail à direita
///   - Linha 4: ícone de câmera | thumbnail da última foto | "Galeria (N)" + seta
///
/// Cada comunidade pode ter um perfil diferente (nickname, avatar, banner,
/// plano de fundo, galeria de fotos).
class EditCommunityProfileScreen extends ConsumerStatefulWidget {
  final String communityId;
  const EditCommunityProfileScreen({super.key, required this.communityId});

  @override
  ConsumerState<EditCommunityProfileScreen> createState() =>
      _EditCommunityProfileScreenState();
}

class _EditCommunityProfileScreenState
    extends ConsumerState<EditCommunityProfileScreen> {
  final _nicknameController = TextEditingController();
  final _bioController = TextEditingController();

  String? _localIconUrl;
  String? _localBannerUrl;
  String? _localBackgroundUrl;
  String? _localBackgroundColor; // hex string, ex: '#FF5733'
  List<String> _gallery = [];
  bool _galleryLoaded = false;
  bool _mediaLoaded = false;

  // Moldura selecionada temporariamente (só persiste ao salvar o perfil)
  String? _selectedFrameUrl;
  String? _selectedFramePurchaseId;
  bool _frameSelectionChanged = false;

  bool _isLoading = true;
  bool _isSaving = false;

  static const int _maxGalleryPhotos = 12;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final membership = await SupabaseService.table('community_members')
          .select(
              'local_nickname, local_bio, local_icon_url, local_banner_url, '
              'local_background_url, local_background_color, local_gallery, active_avatar_frame_id')
          .eq('community_id', widget.communityId)
          .eq('user_id', userId)
          .maybeSingle();

      Map<String, dynamic>? hydratedMembership = membership != null
          ? Map<String, dynamic>.from(membership as Map)
          : null;

      if (hydratedMembership != null) {
        final profileSeed = <String, dynamic>{};
        final profile = await SupabaseService.table('profiles')
            .select('nickname, bio, icon_url, banner_url')
            .eq('id', userId)
            .single();

        final localNickname =
            (hydratedMembership['local_nickname'] as String?)?.trim();
        final localBio = (hydratedMembership['local_bio'] as String?)?.trim();
        final localIconUrl =
            (hydratedMembership['local_icon_url'] as String?)?.trim();
        final localBannerUrl =
            (hydratedMembership['local_banner_url'] as String?)?.trim();

        if ((localNickname == null || localNickname.isEmpty) &&
            ((profile['nickname'] as String?)?.trim().isNotEmpty ?? false)) {
          profileSeed['local_nickname'] = (profile['nickname'] as String).trim();
        }
        if ((localBio == null || localBio.isEmpty) &&
            ((profile['bio'] as String?)?.trim().isNotEmpty ?? false)) {
          profileSeed['local_bio'] = (profile['bio'] as String).trim();
        }
        if ((localIconUrl == null || localIconUrl.isEmpty) &&
            ((profile['icon_url'] as String?)?.trim().isNotEmpty ?? false)) {
          profileSeed['local_icon_url'] = (profile['icon_url'] as String).trim();
        }
        if ((localBannerUrl == null || localBannerUrl.isEmpty) &&
            ((profile['banner_url'] as String?)?.trim().isNotEmpty ?? false)) {
          profileSeed['local_banner_url'] =
              (profile['banner_url'] as String).trim();
        }

        if (profileSeed.isNotEmpty) {
          await SupabaseService.table('community_members')
              .update(profileSeed)
              .eq('community_id', widget.communityId)
              .eq('user_id', userId);
          hydratedMembership.addAll(profileSeed);
        }
      }

      // Carregar moldura ativa fora do setState (operação async)
      String? resolvedFrameUrl;
      String? resolvedFramePurchaseId;
      if (hydratedMembership != null) {
        final activeFramePurchaseId =
            hydratedMembership['active_avatar_frame_id'] as String?;
        if (activeFramePurchaseId != null) {
          try {
            final fp = await SupabaseService.table('user_purchases')
                .select('id, store_items!user_purchases_item_id_fkey(preview_url, asset_url, asset_config)')
                .eq('id', activeFramePurchaseId)
                .maybeSingle();
            if (fp != null) {
              final si = fp['store_items'] as Map<String, dynamic>?;
              if (si != null) {
                String? fUrl = si['preview_url'] as String?;
                if (fUrl == null || fUrl.isEmpty) fUrl = si['asset_url'] as String?;
                if ((fUrl == null || fUrl.isEmpty) && si['asset_config'] is Map) {
                  fUrl = (si['asset_config'] as Map)['frame_url'] as String?;
                }
                resolvedFrameUrl = fUrl;
                resolvedFramePurchaseId = activeFramePurchaseId;
              }
            }
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          if (hydratedMembership != null) {
            _nicknameController.text =
                (hydratedMembership['local_nickname'] as String?) ?? '';
            _bioController.text =
                (hydratedMembership['local_bio'] as String?) ?? '';
            _localIconUrl = hydratedMembership['local_icon_url'] as String?;
            _localBannerUrl = hydratedMembership['local_banner_url'] as String?;
            _localBackgroundUrl =
                hydratedMembership['local_background_url'] as String?;
            _localBackgroundColor =
                hydratedMembership['local_background_color'] as String?;
            _selectedFrameUrl = resolvedFrameUrl;
            _selectedFramePurchaseId = resolvedFramePurchaseId;
            final rawGallery = hydratedMembership['local_gallery'];
            if (rawGallery is List) {
              _gallery = rawGallery.map((e) => e.toString()).toList();
            }
          }
          _galleryLoaded = true;
          _mediaLoaded = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Em caso de erro, NÃO definimos _mediaLoaded = true.
      // Isso faz o _save enviar null para icon/banner/background,
      // que o RPC trata como "sem mudança" via COALESCE.
      // Nota: o RPC 068 usa atribuição direta para esses campos,
      // então precisamos usar COALESCE no _save quando não carregou.
      if (mounted) setState(() {
        _galleryLoaded = true; // mesmo em erro, permite salvar sem apagar galeria
        _isLoading = false;
      });
    }
  }

  Future<void> _openBioEditor() async {
    final s = ref.read(stringsProvider);
    final updatedBio = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BioRichEditorSheet(
        initialValue: _bioController.text,
        title: s.bioInCommunityLabel,
        hintText: s.writeBioHint,
        saveLabel: s.saveChangesAction,
        cancelLabel: s.cancel,
        editorLabel: s.editor,
        previewLabel: s.preview,
        markdownLabel: s.supportsMarkdown,
        maxLength: 500,
      ),
    );

    if (!mounted || updatedBio == null) return;

    setState(() {
      _bioController.value = TextEditingValue(
        text: updatedBio,
        selection: TextSelection.collapsed(offset: updatedBio.length),
      );
    });
  }

  // ─── Upload helpers ──────────────────────────────────────────────────────────

  /// Retorna o bucket correto para cada tipo de mídia do perfil de comunidade.
  /// Avatar usa [MediaBucket.avatars] (bucket compartilhado com perfil global).
  /// Banner, background e galeria usam buckets dedicados.
  static MediaBucket _bucketForFolder(String folder) {
    switch (folder) {
      case 'avatar':
        return MediaBucket.avatars;
      case 'banner':
        return MediaBucket.communityProfileBanners;
      case 'background':
        return MediaBucket.communityProfileBackgrounds;
      case 'gallery':
        return MediaBucket.communityProfileGallery;
      default:
        return MediaBucket.communityProfileGallery;
    }
  }

  Future<String?> _uploadCommunityImage(String folder,
      {bool crop = false}) async {
    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      // Path: userId/communityId/timestamp.jpg
      // O primeiro segmento é sempre o userId, satisfazendo a política RLS
      // de todos os buckets (foldername[1] = auth.uid()).
      final customPath =
          '$userId/${widget.communityId}/'
          '${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Abre o picker
      final file = await MediaUploadService.pickImage(
        maxWidth: folder == 'avatar' ? 512 : 1200,
        maxHeight: folder == 'avatar' ? 512 : 1200,
        imageQuality: folder == 'gallery' ? 80 : 85,
      );
      if (file == null) return null;

      // Crop circular apenas para avatar
      final fileToUpload = (crop && folder == 'avatar')
          ? await MediaUploadService.cropImage(
              file,
              aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
              useCircleCrop: true,
              maxWidth: 512,
              maxHeight: 512,
            ) ?? file
          : file;

      final result = await MediaUploadService.uploadFile(
        file: fileToUpload,
        bucket: _bucketForFolder(folder),
        customPath: customPath,
      );
      return result?.url;
    } catch (e) {
      if (mounted) {
        final s = getStrings();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.errorUploadTryAgain),
          backgroundColor: AppTheme.errorColor,
        ));
      }
      return null;
    }
  }

  Future<void> _pickAvatar() async {
    final url = await _uploadCommunityImage('avatar', crop: true);
    if (url != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _localIconUrl = url);
      });
    }
  }

  Future<void> _pickBanner() async {
    final url = await _uploadCommunityImage('banner');
    if (url != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _localBannerUrl = url);
      });
    }
  }

  Color? _parseStoredBackgroundColor(String? rawColor) {
    if (rawColor == null || rawColor.trim().isEmpty) return null;
    final normalized = rawColor.trim().toUpperCase();
    try {
      if (normalized.startsWith('#')) {
        final hex = normalized.substring(1);
        if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
        if (hex.length == 8) return Color(int.parse(hex, radix: 16));
      }
      if (normalized.startsWith('0X')) {
        return Color(int.parse(normalized.substring(2), radix: 16));
      }
      if (normalized.length == 6) {
        return Color(int.parse('FF$normalized', radix: 16));
      }
      if (normalized.length == 8) {
        return Color(int.parse(normalized, radix: 16));
      }
    } catch (_) {}
    return null;
  }

  Future<void> _pickBackground() async {
    final s = getStrings();
    if (_gallery.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Adicione uma imagem à galeria antes de usá-la como fundo.'),
        backgroundColor: AppTheme.warningColor,
      ));
      return;
    }

    final selectedUrl = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.surfaceColor,
      isScrollControlled: true,
      builder: (sheetContext) {
        final r = sheetContext.r;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(r.s(16), r.s(16), r.s(16), r.s(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.backgroundFromGallery,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: r.fs(18),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: r.s(6)),
                Text(
                  'Escolha uma imagem já adicionada à sua galeria para usar como plano de fundo do perfil.',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: r.fs(13),
                  ),
                ),
                SizedBox(height: r.s(14)),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _gallery.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: r.s(10),
                    crossAxisSpacing: r.s(10),
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (_, index) {
                    final imageUrl = _gallery[index];
                    final isSelected = imageUrl == _localBackgroundUrl;
                    return GestureDetector(
                      onTap: () => Navigator.of(sheetContext).pop(imageUrl),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(r.s(12)),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.accentColor
                                : Colors.white.withValues(alpha: 0.08),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                color: Colors.grey[850],
                                child: Icon(Icons.broken_image_outlined,
                                    color: Colors.grey[500]),
                              ),
                            ),
                            if (isSelected)
                              Container(
                                color: Colors.black.withValues(alpha: 0.35),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: r.s(24),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedUrl != null && mounted) {
      setState(() {
        _localBackgroundUrl = selectedUrl;
        _localBackgroundColor = null;
      });
    }
  }

  Future<void> _pickBackgroundColor() async {
    final s = getStrings();
    final initialColor = _parseStoredBackgroundColor(_localBackgroundColor) ??
        const Color(0xFF1A1A2E);
    final picked = await showRGBColorPicker(
      context,
      initialColor: initialColor,
      title: s.backgroundTypeLabel,
    );
    if (picked != null && mounted) {
      final argb = picked.toARGB32();
      final red = (argb >> 16) & 0xFF;
      final green = (argb >> 8) & 0xFF;
      final blue = argb & 0xFF;
      final hex = '#${red.toRadixString(16).padLeft(2, '0').toUpperCase()}${green.toRadixString(16).padLeft(2, '0').toUpperCase()}${blue.toRadixString(16).padLeft(2, '0').toUpperCase()}';
      setState(() {
        _localBackgroundColor = hex;
        _localBackgroundUrl = null; // limpa imagem ao escolher cor
      });
    }
  }

  Future<void> _addGalleryPhoto() async {
    if (_gallery.length >= _maxGalleryPhotos) {
      final s = getStrings();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(s.maxGalleryPhotos),
        backgroundColor: AppTheme.warningColor,
      ));
      return;
    }
    final url = await _uploadCommunityImage('gallery');
    if (url != null && mounted) {
      setState(() => _gallery = [..._gallery, url]);
    }
  }

  void _removeGalleryPhoto(int index) {
    setState(() {
      final updated = List<String>.from(_gallery);
      final removedUrl = updated.removeAt(index);
      _gallery = updated;
      if (_localBackgroundUrl == removedUrl) {
        _localBackgroundUrl = null;
      }
    });
  }

  // ─── Save ────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final s = getStrings();
    setState(() => _isSaving = true);

    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception(s.notAuthenticated);

      final nickname = _nicknameController.text.trim();
      final bio = _bioController.text.trim();

      // Só envia a galeria se ela foi carregada com sucesso.
      // O RPC usa COALESCE para galeria: NULL preserva o valor atual,
      // array vazio limpa. Enviar null quando não carregou evita apagar
      // a galeria existente por acidente.
      final galleryPayload = _galleryLoaded ? _gallery : null;

      // Se o carregamento inicial falhou, buscamos os valores atuais do banco
      // antes de salvar para evitar apagar icon/banner/background por acidente.
      // O RPC usa atribuição direta para esses campos (NULL limpa o campo).
      String? iconUrlToSave = _localIconUrl;
      String? bannerUrlToSave = _localBannerUrl;
      String? backgroundUrlToSave = _localBackgroundUrl;
      String? backgroundColorToSave = _localBackgroundColor;

      if (!_mediaLoaded) {
        // Carregamento inicial falhou — buscar valores atuais antes de salvar
        try {
          final current = await SupabaseService.table('community_members')
              .select('local_icon_url, local_banner_url, local_background_url, local_background_color')
              .eq('community_id', widget.communityId)
              .eq('user_id', userId)
              .maybeSingle();
          if (current != null) {
            iconUrlToSave = current['local_icon_url'] as String?;
            bannerUrlToSave = current['local_banner_url'] as String?;
            backgroundUrlToSave = current['local_background_url'] as String?;
            backgroundColorToSave = current['local_background_color'] as String?;
          }
        } catch (_) {
          // Se falhar novamente, aborta o save para não apagar dados
          throw Exception(s.anErrorOccurredTryAgain);
        }
      }

      await SupabaseService.client.rpc('update_community_profile', params: {
        'p_community_id': widget.communityId,
        'p_local_nickname': nickname.isEmpty ? null : nickname,
        'p_local_bio': bio.isEmpty ? null : bio,
        'p_local_icon_url': iconUrlToSave,
        'p_local_banner_url': bannerUrlToSave,
        'p_local_background_url': backgroundUrlToSave,
        'p_local_background_color': backgroundColorToSave,
        'p_local_gallery': galleryPayload,
        'p_active_avatar_frame_purchase_id':
            _frameSelectionChanged ? _selectedFramePurchaseId : null,
        'p_frame_changed': _frameSelectionChanged,
      });

      // Nota: community_profile_screen usa _loadProfile() com estado local
      // (não usa communityMembershipProvider). O recarregamento é feito via
      // .then((_) => _loadProfile()) no onTap do botão de editar na tela de perfil.
      // O invalidate abaixo serve apenas para atualizar a community_detail_screen
      // caso ela esteja na pilha de navegação.
      ref.invalidate(communityMembershipProvider(widget.communityId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.communityProfileUpdated),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        final s = getStrings();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.anErrorOccurredTryAgain),
          backgroundColor: AppTheme.errorColor,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          s.editCommunityProfile,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: r.fs(17),
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: r.s(12)),
            child: GestureDetector(
              onTap: _isSaving ? null : _save,
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: r.s(16), vertical: r.s(8)),
                decoration: BoxDecoration(
                  color: _isSaving
                      ? AppTheme.accentColor.withValues(alpha: 0.5)
                      : AppTheme.accentColor,
                  borderRadius: BorderRadius.circular(r.s(20)),
                ),
                child: _isSaving
                    ? SizedBox(
                        width: r.s(16),
                        height: r.s(16),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        s.save,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: r.fs(13),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.accentColor,
                strokeWidth: 2.5,
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ══════════════════════════════════════════════════════
                  // SEÇÃO DO TOPO: Banner + Avatar + "Editar Molduras"
                  // ══════════════════════════════════════════════════════
                  _BannerAvatarSection(
                    bannerUrl: _localBannerUrl,
                    avatarUrl: _localIconUrl,
                    frameUrl: _selectedFrameUrl,
                    editFramesLabel: s.editProfileFrames,
                    onTapBanner: _pickBanner,
                    onTapAvatar: _pickAvatar,
                    onRemoveBanner: _localBannerUrl != null
                        ? () => setState(() => _localBannerUrl = null)
                        : null,
                    onTapEditFrames: () async {
                      final result = await showFramePickerSheet(
                        context,
                        currentAvatarUrl: _localIconUrl,
                        currentFrameUrl: _selectedFrameUrl,
                      );
                      if (result != null && mounted) {
                        setState(() {
                          _selectedFrameUrl = result.frameUrl;
                          _selectedFramePurchaseId = result.purchaseId;
                          _frameSelectionChanged = true;
                        });
                      }
                    },
                  ),

                  SizedBox(height: r.s(8)),

                  // ══════════════════════════════════════════════════════
                  // LINHA: Nickname local
                  // ══════════════════════════════════════════════════════
                  _AminoListTile(
                    leading: Icon(Icons.person_outline_rounded,
                        color: Colors.grey[500], size: r.s(28)),
                    content: _InlineTextField(
                      controller: _nicknameController,
                      hintText: s.leaveEmptyGlobal,
                      maxLength: 24,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: r.fs(15),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  _AminoDivider(),

                  // ══════════════════════════════════════════════════════
                  // LINHA: Bio local
                  // ══════════════════════════════════════════════════════
                  _AminoListTile(
                    leading: Icon(Icons.edit_note_rounded,
                        color: Colors.grey[500], size: r.s(28)),
                    content: _CommunityBioField(
                      controller: _bioController,
                      hintText: s.leaveEmptyBio,
                      markdownLabel: s.markdown,
                      previewLabel: s.preview,
                      onTap: _openBioEditor,
                    ),
                    trailing: Icon(Icons.chevron_right_rounded,
                        color: context.textHint, size: r.s(22)),
                  ),

                  _AminoDivider(),

                  // ══════════════════════════════════════════════════════
                  // SEÇÃO: Plano de Fundo — toggle Cor Sólida / Imagem
                  // ══════════════════════════════════════════════════════
                  _AminoListTile(
                    leading: Icon(Icons.palette_rounded,
                        color: const Color(0xFF2196F3), size: r.s(28)),
                    content: Text(
                      s.profileBackgroundOptional,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: r.fs(15),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: const SizedBox.shrink(),
                  ),
                  // Hint sobre galeria como banner
                  Padding(
                    padding: EdgeInsets.fromLTRB(r.s(16), 0, r.s(16), r.s(8)),
                    child: Text(
                      s.galleryAsBannerHint,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: r.fs(12),
                        height: 1.4,
                      ),
                    ),
                  ),
                  // Botões de toggle: Cor Sólida | Imagem
                  Padding(
                    padding: EdgeInsets.fromLTRB(r.s(16), 0, r.s(16), r.s(8)),
                    child: Row(
                      children: [
                        // Botão: Cor Sólida
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickBackgroundColor,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  vertical: r.s(10), horizontal: r.s(12)),
                              decoration: BoxDecoration(
                                color: _localBackgroundColor != null
                                    ? (_parseStoredBackgroundColor(_localBackgroundColor) ??
                                        AppTheme.accentColor.withValues(alpha: 0.15))
                                    : context.surfaceColor,
                                borderRadius: BorderRadius.circular(r.s(10)),
                                border: Border.all(
                                  color: _localBackgroundColor != null
                                      ? Colors.white.withValues(alpha: 0.3)
                                      : Colors.grey.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: r.s(16),
                                    color: _localBackgroundColor != null
                                        ? Colors.white
                                        : AppTheme.accentColor,
                                  ),
                                  SizedBox(width: r.s(6)),
                                  Flexible(
                                    child: Text(
                                      s.backgroundColorSolid,
                                      style: TextStyle(
                                        color: _localBackgroundColor != null
                                            ? Colors.white
                                            : context.textPrimary,
                                        fontSize: r.fs(13),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_localBackgroundColor != null) ...[  
                                    SizedBox(width: r.s(4)),
                                    GestureDetector(
                                      onTap: () => setState(() => _localBackgroundColor = null),
                                      child: Icon(Icons.close_rounded,
                                          color: Colors.white70, size: r.s(14)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: r.s(8)),
                        // Botão: Imagem
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickBackground,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  vertical: r.s(10), horizontal: r.s(12)),
                              decoration: BoxDecoration(
                                color: context.surfaceColor,
                                borderRadius: BorderRadius.circular(r.s(10)),
                                border: Border.all(
                                  color: _localBackgroundUrl != null
                                      ? AppTheme.accentColor
                                      : Colors.grey.withValues(alpha: 0.3),
                                  width: _localBackgroundUrl != null ? 2 : 1.5,
                                ),
                                image: _localBackgroundUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(_localBackgroundUrl!),
                                        fit: BoxFit.cover,
                                        colorFilter: ColorFilter.mode(
                                          Colors.black.withValues(alpha: 0.45),
                                          BlendMode.darken,
                                        ),
                                      )
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_rounded,
                                    size: r.s(16),
                                    color: _localBackgroundUrl != null
                                        ? Colors.white
                                        : AppTheme.accentColor,
                                  ),
                                  SizedBox(width: r.s(6)),
                                  Flexible(
                                    child: Text(
                                      s.backgroundFromGallery,
                                      style: TextStyle(
                                        color: _localBackgroundUrl != null
                                            ? Colors.white
                                            : context.textPrimary,
                                        fontSize: r.fs(13),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_localBackgroundUrl != null) ...[  
                                    SizedBox(width: r.s(4)),
                                    GestureDetector(
                                      onTap: () => setState(() => _localBackgroundUrl = null),
                                      child: Icon(Icons.close_rounded,
                                          color: Colors.white70, size: r.s(14)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  _AminoDivider(),

                  // ══════════════════════════════════════════════════════
                  // LINHA: Galeria de fotos
                  // ══════════════════════════════════════════════════════
                  GestureDetector(
                    onTap: _addGalleryPhoto,
                    child: _AminoListTile(
                      leading: Icon(Icons.camera_alt_rounded,
                          color: const Color(0xFF2196F3), size: r.s(28)),
                      content: _gallery.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(r.s(4)),
                              child: CachedNetworkImage(
                                imageUrl: _gallery.last,
                                width: r.s(44),
                                height: r.s(44),
                                fit: BoxFit.cover,
                              ),
                            )
                          : SizedBox(height: r.s(44)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${s.galleryCount} (${_gallery.length})',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: r.fs(15),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: r.s(4)),
                          Icon(Icons.chevron_right_rounded,
                              color: Colors.grey[400], size: r.s(22)),
                        ],
                      ),
                    ),
                  ),

                  // ── Grid da galeria (se houver fotos) ─────────────────
                  if (_gallery.isNotEmpty) ...[
                    _AminoDivider(),
                    _GalleryGrid(
                      photos: _gallery,
                      onAdd: _gallery.length < _maxGalleryPhotos
                          ? _addGalleryPhoto
                          : null,
                      onRemove: _removeGalleryPhoto,
                    ),
                  ],

                  _AminoDivider(),

                  // ══════════════════════════════════════════════════════
                  // NOTA INFORMATIVA
                  // ══════════════════════════════════════════════════════
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(16), vertical: r.s(12)),
                    child: Container(
                      padding: EdgeInsets.all(r.s(12)),
                      decoration: BoxDecoration(
                        color: AppTheme.accentColor.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(r.s(10)),
                        border: Border.all(
                          color: AppTheme.accentColor.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: AppTheme.accentColor, size: r.s(18)),
                          SizedBox(width: r.s(10)),
                          Expanded(
                            child: Text(
                              '${s.settingsApplyOnlyCommunity}\n${s.emptyFieldsGlobal}',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: r.fs(12),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: r.s(40)),
                ],
              ),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SEÇÃO DO TOPO: Banner + Avatar centralizado + "Editar Molduras de Perfil"
// ═══════════════════════════════════════════════════════════════════════════════

class _BannerAvatarSection extends ConsumerWidget {
  final String? bannerUrl;
  final String? avatarUrl;
  final String? frameUrl;
  final String editFramesLabel;
  final VoidCallback onTapBanner;
  final VoidCallback onTapAvatar;
  final VoidCallback? onRemoveBanner;
  final VoidCallback onTapEditFrames;

  const _BannerAvatarSection({
    required this.bannerUrl,
    required this.avatarUrl,
    this.frameUrl,
    required this.editFramesLabel,
    required this.onTapBanner,
    required this.onTapAvatar,
    this.onRemoveBanner,
    required this.onTapEditFrames,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;

    return Column(
      children: [
        // ── Banner ──────────────────────────────────────────────────────
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Banner
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTapBanner,
              child: Container(
                height: r.s(160),
                width: double.infinity,
                color: const Color(0xFFE8E0E0),
                child: bannerUrl != null
                    ? CachedNetworkImage(
                        imageUrl: bannerUrl!,
                        fit: BoxFit.cover,
                        color: Colors.black.withValues(alpha: 0.15),
                        colorBlendMode: BlendMode.darken,
                      )
                    : null,
              ),
            ),

            // Botão de remover banner (canto superior direito)
            if (bannerUrl != null && onRemoveBanner != null)
              Positioned(
                top: r.s(8),
                right: r.s(8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onRemoveBanner,
                    customBorder: const CircleBorder(),
                    child: Container(
                      padding: EdgeInsets.all(r.s(5)),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded,
                          color: Colors.white, size: r.s(14)),
                    ),
                  ),
                ),
              ),

              // Avatar sobreposto ao banner (metade dentro, metade fora)
              Positioned(
                bottom: -r.s(52),
                child: GestureDetector(
                  onTap: onTapAvatar,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Círculo do avatar
                      Container(
                        width: r.s(96),
                        height: r.s(96),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFD0C8C8),
                          border: Border.all(
                            color: const Color(0xFFE8E0E0),
                            width: 3,
                          ),
                        ),
                        child: ClipOval(
                          child: avatarUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: avatarUrl!,
                                  fit: BoxFit.cover,
                                )
                              : Icon(Icons.person_rounded,
                                  color: Colors.grey[600], size: r.s(52)),
                        ),
                      ),
                      // Ícone de câmera no canto inferior direito
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(r.s(5)),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFE8E0E0),
                              width: 2,
                            ),
                          ),
                          child: Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: r.s(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

        // Espaço para o avatar sobrepor o conteúdo seguinte
        SizedBox(height: r.s(60)),

        // "Editar Molduras de Perfil" — abre o FramePickerSheet
        GestureDetector(
          onTap: onTapEditFrames,
          child: Text(
            editFramesLabel,
            style: TextStyle(
              color: const Color(0xFF5B9BD5),
              fontSize: r.fs(14),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        SizedBox(height: r.s(16)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LIST TILE ESTILO AMINO (linha com leading, content e trailing)
// ═══════════════════════════════════════════════════════════════════════════════

class _AminoListTile extends StatelessWidget {
  final Widget leading;
  final Widget content;
  final Widget? trailing;

  const _AminoListTile({
    required this.leading,
    required this.content,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      color: context.surfaceColor,
      padding: EdgeInsets.symmetric(
          horizontal: r.s(16), vertical: r.s(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: r.s(32), child: leading),
          SizedBox(width: r.s(12)),
          Expanded(child: content),
          if (trailing != null) ...[
            SizedBox(width: r.s(8)),
            trailing!,
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DIVISOR ESTILO AMINO (linha fina de separação)
// ═══════════════════════════════════════════════════════════════════════════════

class _AminoDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      color: context.dividerClr,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CAMPO DE TEXTO INLINE (sem borda, integrado ao tile)
// ═══════════════════════════════════════════════════════════════════════════════

class _InlineTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final int? maxLength;
  final TextStyle? style;

  const _InlineTextField({
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
    this.maxLength,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      style: style ??
          TextStyle(color: context.textPrimary, fontSize: r.fs(15)),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: context.textHint, fontSize: r.fs(14)),
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        counterStyle:
            TextStyle(color: context.textHint, fontSize: r.fs(10)),
      ),
    );
  }
}

class _CommunityBioField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String markdownLabel;
  final String previewLabel;
  final VoidCallback onTap;

  const _CommunityBioField({
    required this.controller,
    required this.hintText,
    required this.markdownLabel,
    required this.previewLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final bio = controller.text.trim();
    final hasBio = bio.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r.s(12)),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: r.s(4)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasBio ? bio : hintText,
                maxLines: hasBio ? 4 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hasBio ? context.textPrimary : context.textHint,
                  fontSize: r.fs(14),
                  height: 1.45,
                ),
              ),
              SizedBox(height: r.s(8)),
              Wrap(
                spacing: r.s(6),
                runSpacing: r.s(6),
                children: [
                  _BioInfoChip(label: markdownLabel),
                  _BioInfoChip(label: previewLabel),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BioInfoChip extends StatelessWidget {
  final String label;

  const _BioInfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r.s(8),
        vertical: r.s(4),
      ),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(r.s(999)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppTheme.accentColor,
          fontSize: r.fs(11),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BioRichEditorSheet extends StatefulWidget {
  final String initialValue;
  final String title;
  final String hintText;
  final String saveLabel;
  final String cancelLabel;
  final String editorLabel;
  final String previewLabel;
  final String markdownLabel;
  final int maxLength;

  const _BioRichEditorSheet({
    required this.initialValue,
    required this.title,
    required this.hintText,
    required this.saveLabel,
    required this.cancelLabel,
    required this.editorLabel,
    required this.previewLabel,
    required this.markdownLabel,
    this.maxLength = 500,
  });

  @override
  State<_BioRichEditorSheet> createState() => _BioRichEditorSheetState();
}

class _BioRichEditorSheetState extends State<_BioRichEditorSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _replaceValue(String value, {TextSelection? selection}) {
    final safeOffset = selection?.extentOffset ?? value.length;
    final clampedOffset = safeOffset.clamp(0, value.length) as int;
    _controller.value = TextEditingValue(
      text: value,
      selection: selection != null
          ? TextSelection(
              baseOffset: selection.baseOffset.clamp(0, value.length) as int,
              extentOffset: selection.extentOffset.clamp(0, value.length) as int,
            )
          : TextSelection.collapsed(offset: clampedOffset),
    );
    setState(() {});
  }

  void _wrapSelection(String prefix, String suffix) {
    final value = _controller.value;
    final selection = value.selection;
    final text = value.text;

    if (!selection.isValid || selection.start < 0 || selection.end < 0) {
      final inserted = '$prefix$suffix';
      _replaceValue(
        '$text$inserted',
        selection: TextSelection.collapsed(offset: text.length + prefix.length),
      );
      return;
    }

    final start = selection.start;
    final end = selection.end;
    final selected = text.substring(start, end);
    final updated = text.replaceRange(start, end, '$prefix$selected$suffix');

    _replaceValue(
      updated,
      selection: selected.isEmpty
          ? TextSelection.collapsed(offset: start + prefix.length)
          : TextSelection(
              baseOffset: start + prefix.length,
              extentOffset: start + prefix.length + selected.length,
            ),
    );
  }

  void _toggleLinePrefix(String prefix) {
    final value = _controller.value;
    final selection = value.selection;
    final text = value.text;

    if (!selection.isValid || selection.start < 0 || selection.end < 0) {
      final updated = '$text${text.isNotEmpty ? '
' : ''}$prefix';
      _replaceValue(
        updated,
        selection: TextSelection.collapsed(offset: updated.length),
      );
      return;
    }

    final start = selection.start;
    final end = selection.end;
    final blockStart = text.lastIndexOf('
', start == 0 ? 0 : start - 1) + 1;
    final nextBreak = text.indexOf('
', end);
    final blockEnd = nextBreak == -1 ? text.length : nextBreak;
    final block = text.substring(blockStart, blockEnd);
    final lines = block.split('
');
    final allPrefixed = lines
        .where((line) => line.trim().isNotEmpty)
        .every((line) => line.startsWith(prefix));

    final updatedBlock = lines
        .map((line) {
          if (line.trim().isEmpty) return line;
          if (allPrefixed) {
            return line.startsWith(prefix) ? line.substring(prefix.length) : line;
          }
          return line.startsWith(prefix) ? line : '$prefix$line';
        })
        .join('
');

    final updated = text.replaceRange(blockStart, blockEnd, updatedBlock);
    _replaceValue(
      updated,
      selection: TextSelection(
        baseOffset: blockStart,
        extentOffset: blockStart + updatedBlock.length,
      ),
    );
  }

  void _insertDivider() {
    final text = _controller.text;
    final selection = _controller.selection;
    final insertText = '${text.isNotEmpty ? '

' : ''}---
';

    if (!selection.isValid || selection.start < 0) {
      final updated = '$text$insertText';
      _replaceValue(
        updated,
        selection: TextSelection.collapsed(offset: updated.length),
      );
      return;
    }

    final start = selection.start;
    final end = selection.end;
    final updated = text.replaceRange(start, end, insertText);
    _replaceValue(
      updated,
      selection: TextSelection.collapsed(offset: start + insertText.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(24))),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(r.s(16), r.s(12), r.s(16), r.s(16)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: r.s(44),
                    height: r.s(4),
                    decoration: BoxDecoration(
                      color: context.dividerClr,
                      borderRadius: BorderRadius.circular(r.s(999)),
                    ),
                  ),
                ),
                SizedBox(height: r.s(16)),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: r.fs(18),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(widget.cancelLabel),
                    ),
                    SizedBox(width: r.s(4)),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
                      child: Text(widget.saveLabel),
                    ),
                  ],
                ),
                SizedBox(height: r.s(6)),
                Text(
                  widget.markdownLabel,
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: r.fs(12),
                  ),
                ),
                SizedBox(height: r.s(14)),
                Wrap(
                  spacing: r.s(8),
                  runSpacing: r.s(8),
                  children: [
                    _FormatActionChip(
                      icon: Icons.format_bold_rounded,
                      label: 'Negrito',
                      onTap: () => _wrapSelection('**', '**'),
                    ),
                    _FormatActionChip(
                      icon: Icons.format_italic_rounded,
                      label: 'Itálico',
                      onTap: () => _wrapSelection('*', '*'),
                    ),
                    _FormatActionChip(
                      icon: Icons.format_strikethrough_rounded,
                      label: 'Tachado',
                      onTap: () => _wrapSelection('~~', '~~'),
                    ),
                    _FormatActionChip(
                      icon: Icons.title_rounded,
                      label: 'Título',
                      onTap: () => _toggleLinePrefix('## '),
                    ),
                    _FormatActionChip(
                      icon: Icons.format_quote_rounded,
                      label: 'Citação',
                      onTap: () => _toggleLinePrefix('> '),
                    ),
                    _FormatActionChip(
                      icon: Icons.format_list_bulleted_rounded,
                      label: 'Lista',
                      onTap: () => _toggleLinePrefix('- '),
                    ),
                    _FormatActionChip(
                      icon: Icons.horizontal_rule_rounded,
                      label: 'Divisor',
                      onTap: _insertDivider,
                    ),
                  ],
                ),
                SizedBox(height: r.s(14)),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.cardBg,
                      borderRadius: BorderRadius.circular(r.s(16)),
                      border: Border.all(color: context.dividerClr),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(r.s(8)),
                          child: Row(
                            children: [
                              Expanded(
                                child: SegmentedButton<bool>(
                                  segments: [
                                    ButtonSegment<bool>(
                                      value: false,
                                      icon: const Icon(Icons.edit_rounded),
                                      label: Text(widget.editorLabel),
                                    ),
                                    ButtonSegment<bool>(
                                      value: true,
                                      icon: const Icon(Icons.visibility_rounded),
                                      label: Text(widget.previewLabel),
                                    ),
                                  ],
                                  selected: {_showPreview},
                                  onSelectionChanged: (selection) {
                                    setState(() => _showPreview = selection.first);
                                    if (!_showPreview) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        if (mounted) _focusNode.requestFocus();
                                      });
                                    }
                                  },
                                ),
                              ),
                              SizedBox(width: r.s(8)),
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _controller,
                                builder: (_, value, __) => Text(
                                  '${value.text.length}/${widget.maxLength}',
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: r.fs(12),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _controller,
                            builder: (_, value, __) {
                              if (_showPreview) {
                                final previewText = value.text.trim();
                                return SingleChildScrollView(
                                  padding: EdgeInsets.all(r.s(16)),
                                  child: previewText.isEmpty
                                      ? Text(
                                          widget.hintText,
                                          style: TextStyle(
                                            color: context.textHint,
                                            fontSize: r.fs(14),
                                            height: 1.5,
                                          ),
                                        )
                                      : MarkdownBody(
                                          data: previewText,
                                          selectable: false,
                                          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                            p: TextStyle(
                                              color: context.textPrimary,
                                              fontSize: r.fs(14),
                                              height: 1.55,
                                            ),
                                            h2: TextStyle(
                                              color: context.textPrimary,
                                              fontSize: r.fs(18),
                                              fontWeight: FontWeight.w700,
                                            ),
                                            blockquote: TextStyle(
                                              color: context.textSecondary,
                                              fontSize: r.fs(14),
                                              fontStyle: FontStyle.italic,
                                            ),
                                            blockquoteDecoration: BoxDecoration(
                                              color: AppTheme.accentColor.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(r.s(12)),
                                              border: Border.all(
                                                color: AppTheme.accentColor.withValues(alpha: 0.18),
                                              ),
                                            ),
                                          ),
                                        ),
                                );
                              }

                              return TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                maxLines: null,
                                expands: true,
                                maxLength: widget.maxLength,
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: r.fs(14),
                                  height: 1.55,
                                ),
                                decoration: InputDecoration(
                                  hintText: widget.hintText,
                                  hintStyle: TextStyle(
                                    color: context.textHint,
                                    fontSize: r.fs(14),
                                  ),
                                  contentPadding: EdgeInsets.all(r.s(16)),
                                  border: InputBorder.none,
                                  counterText: '',
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormatActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FormatActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(r.s(999)),
      child: Ink(
        padding: EdgeInsets.symmetric(
          horizontal: r.s(10),
          vertical: r.s(8),
        ),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(r.s(999)),
          border: Border.all(
            color: context.dividerClr,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: r.s(16), color: context.textPrimary),
            SizedBox(width: r.s(6)),
            Text(
              label,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: r.fs(12),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GRID DA GALERIA
// ═══════════════════════════════════════════════════════════════════════════════

class _GalleryGrid extends StatelessWidget {
  final List<String> photos;
  final VoidCallback? onAdd;
  final void Function(int index) onRemove;

  const _GalleryGrid({
    required this.photos,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final itemSize = (MediaQuery.of(context).size.width - r.s(32) - r.s(8) * 2) / 3;

    return Padding(
      padding: EdgeInsets.all(r.s(16)),
      child: Wrap(
        spacing: r.s(8),
        runSpacing: r.s(8),
        children: [
          // Fotos existentes
          ...photos.asMap().entries.map((entry) {
            final index = entry.key;
            final url = entry.value;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(r.s(6)),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    width: itemSize,
                    height: itemSize,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: -r.s(6),
                  right: -r.s(6),
                  child: GestureDetector(
                    onTap: () => onRemove(index),
                    child: Container(
                      width: r.s(20),
                      height: r.s(20),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded,
                          color: Colors.white, size: r.s(12)),
                    ),
                  ),
                ),
              ],
            );
          }),

          // Botão de adicionar (se não atingiu o limite)
          if (onAdd != null)
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: itemSize,
                height: itemSize,
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(r.s(6)),
                  border: Border.all(
                    color: context.dividerClr,
                    width: 1,
                  ),
                ),
                child: Icon(Icons.add_rounded,
                    color: context.textHint, size: r.s(28)),
              ),
            ),
        ],
      ),
    );
  }
}
