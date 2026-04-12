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
import '../widgets/rich_bio.dart';
import '../widgets/frame_picker_sheet.dart';
import '../../../../config/nexus_theme_extension.dart';
import '../../../../config/nexus_theme_extension.dart';

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
        // Não reidratar automaticamente a capa global quando a capa local está
        // nula. Nesse contexto, null pode significar que o usuário removeu a
        // capa da comunidade intencionalmente.

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
            final storedBannerUrl =
                (hydratedMembership['local_banner_url'] as String?)?.trim();
            _localBackgroundUrl =
                hydratedMembership['local_background_url'] as String?;
            _localBackgroundColor =
                hydratedMembership['local_background_color'] as String?;
            _selectedFrameUrl = resolvedFrameUrl;
            _selectedFramePurchaseId = resolvedFramePurchaseId;
            final rawGallery = hydratedMembership['local_gallery'];
            final initialGallery = rawGallery is List
                ? rawGallery.map((e) => e.toString()).toList()
                : <String>[];
            if (initialGallery.isEmpty &&
                storedBannerUrl != null &&
                storedBannerUrl.isNotEmpty) {
              initialGallery.add(storedBannerUrl);
            }
            _gallery = initialGallery;
            _localBannerUrl =
                initialGallery.isNotEmpty ? initialGallery.first : storedBannerUrl;
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
    final updatedBio = await showRichBioEditorSheet(
      context,
      initialValue: _bioController.text,
      title: s.bioInCommunityLabel,
      hintText: s.writeBioHint,
      saveLabel: s.save,
      cancelLabel: s.cancel,
      editorLabel: s.edit,
      previewLabel: s.preview,
      markdownLabel: 'Markdown disponível',
      maxLength: 500,
    );

    if (!mounted || updatedBio == null) return;
    setState(() => _bioController.text = updatedBio);
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
          backgroundColor: context.nexusTheme.error,
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
        backgroundColor: context.nexusTheme.warning,
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
                    color: context.nexusTheme.textPrimary,
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
                                ? context.nexusTheme.accentSecondary
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

  void _applyGalleryUpdate(List<String> updatedGallery) {
    final sanitizedGallery = List<String>.from(updatedGallery);
    final removedImages = _gallery.toSet().difference(sanitizedGallery.toSet());

    _gallery = sanitizedGallery;
    _localBannerUrl = sanitizedGallery.isNotEmpty ? sanitizedGallery.first : null;

    if (_localBackgroundUrl != null && removedImages.contains(_localBackgroundUrl)) {
      _localBackgroundUrl = null;
    }
  }

  Future<void> _addGalleryPhoto() async {
    if (_gallery.length >= _maxGalleryPhotos) {
      final s = getStrings();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(s.maxGalleryPhotos),
        backgroundColor: context.nexusTheme.warning,
      ));
      return;
    }
    final url = await _uploadCommunityImage('gallery');
    if (url != null && mounted) {
      setState(() {
        _applyGalleryUpdate([..._gallery, url]);
      });
    }
  }

  Future<void> _openGalleryManager() async {
    final updatedGallery = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => _CommunityGalleryManagerScreen(
          initialPhotos: _gallery,
          maxPhotos: _maxGalleryPhotos,
          onPickPhoto: () => _uploadCommunityImage('gallery'),
        ),
      ),
    );

    if (updatedGallery != null && mounted) {
      setState(() {
        _applyGalleryUpdate(updatedGallery);
      });
    }
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

      if (_galleryLoaded) {
        bannerUrlToSave = _gallery.isNotEmpty ? _gallery.first : null;
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
          backgroundColor: context.nexusTheme.success,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        final s = getStrings();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.anErrorOccurredTryAgain),
          backgroundColor: context.nexusTheme.error,
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
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: context.nexusTheme.textPrimary, size: r.s(20)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          s.editCommunityProfile,
          style: TextStyle(
            color: context.nexusTheme.textPrimary,
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
                      ? context.nexusTheme.accentSecondary.withValues(alpha: 0.5)
                      : context.nexusTheme.accentSecondary,
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
                color: context.nexusTheme.accentSecondary,
                strokeWidth: 2.5,
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.only(bottom: r.s(32)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BannerAvatarSection(
                    bannerUrl:
                        _gallery.isNotEmpty ? _gallery.first : _localBannerUrl,
                    avatarUrl: _localIconUrl,
                    frameUrl: _selectedFrameUrl,
                    editFramesLabel: s.editProfileFrames,
                    onTapAvatar: _pickAvatar,
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
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      r.s(16),
                      r.s(8),
                      r.s(16),
                      0,
                    ),
                    child: Column(
                      children: [
                        _SettingsSectionCard(
                          child: Padding(
                            padding: EdgeInsets.all(r.s(14)),
                            child: Column(
                              children: [
                                _SectionHeader(
                                  icon: Icons.tune_rounded,
                                  iconColor: context.nexusTheme.accentSecondary,
                                  title: 'Perfil',
                                  subtitle: 'Nome e apresentação',
                                ),
                                SizedBox(height: r.s(14)),
                                _AminoListTile(
                                  leading: Icon(Icons.person_outline_rounded,
                                      color: Colors.grey[300], size: r.s(22)),
                                  title: 'Nome',
                                  content: _InlineTextField(
                                    controller: _nicknameController,
                                    hintText: s.leaveEmptyGlobal,
                                    maxLength: 24,
                                    style: TextStyle(
                                      color: context.nexusTheme.textPrimary,
                                      fontSize: r.fs(16),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                SizedBox(height: r.s(10)),
                                _AminoListTile(
                                  leading: Icon(Icons.notes_rounded,
                                      color: Colors.grey[300], size: r.s(22)),
                                  title: 'Bio',
                                  onTap: _openBioEditor,
                                  content: _CommunityBioField(
                                    controller: _bioController,
                                    hintText: s.leaveEmptyBio,
                                  ),
                                  trailing: Icon(Icons.chevron_right_rounded,
                                      color: context.nexusTheme.textHint, size: r.s(20)),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: r.s(16)),
                        _SettingsSectionCard(
                          child: Padding(
                            padding: EdgeInsets.all(r.s(14)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionHeader(
                                  icon: Icons.palette_rounded,
                                  iconColor: const Color(0xFF2196F3),
                                  title: s.profileBackgroundOptional,
                                  subtitle: 'Plano de fundo e galeria',
                                ),
                                SizedBox(height: r.s(14)),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _BackgroundOptionButton(
                                        icon: Icons.circle,
                                        label: s.backgroundColorSolid,
                                        selected: _localBackgroundColor != null,
                                        selectedColor: _parseStoredBackgroundColor(
                                                _localBackgroundColor) ??
                                            context.nexusTheme.accentSecondary,
                                        onTap: _pickBackgroundColor,
                                        onClear: _localBackgroundColor != null
                                            ? () => setState(() =>
                                                _localBackgroundColor = null)
                                            : null,
                                      ),
                                    ),
                                    SizedBox(width: r.s(10)),
                                    Expanded(
                                      child: _BackgroundOptionButton(
                                        icon: Icons.image_rounded,
                                        label: s.backgroundFromGallery,
                                        selected: _localBackgroundUrl != null,
                                        imageUrl: _localBackgroundUrl,
                                        selectedColor: context.nexusTheme.accentSecondary,
                                        onTap: _pickBackground,
                                        onClear: _localBackgroundUrl != null
                                            ? () => setState(() =>
                                                _localBackgroundUrl = null)
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: r.s(12)),
                                GestureDetector(
                                  onTap: _openGalleryManager,
                                  child: Container(
                                    padding: EdgeInsets.all(r.s(14)),
                                    decoration: BoxDecoration(
                                      color: context.nexusTheme.backgroundPrimary.withValues(alpha: 0.45),
                                      borderRadius: BorderRadius.circular(r.s(18)),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.06),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _GallerySummaryContent(
                                            photos: _gallery,
                                            itemSize: r.s(50),
                                          ),
                                        ),
                                        SizedBox(width: r.s(12)),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: r.s(10),
                                            vertical: r.s(6),
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.06),
                                            borderRadius:
                                                BorderRadius.circular(r.s(999)),
                                          ),
                                          child: Text(
                                            '${_gallery.length}',
                                            style: TextStyle(
                                              color: context.nexusTheme.textPrimary,
                                              fontSize: r.fs(12),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: r.s(6)),
                                        Icon(Icons.chevron_right_rounded,
                                            color: Colors.grey[400],
                                            size: r.s(22)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: r.s(6)),
                      ],
                    ),
                  ),
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
  final VoidCallback onTapAvatar;
  final VoidCallback onTapEditFrames;

  const _BannerAvatarSection({
    required this.bannerUrl,
    required this.avatarUrl,
    this.frameUrl,
    required this.editFramesLabel,
    required this.onTapAvatar,
    required this.onTapEditFrames,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: r.s(188),
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(r.s(28)),
                  bottomRight: Radius.circular(r.s(28)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 22,
                    offset: Offset(0, r.s(8)),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(r.s(28)),
                  bottomRight: Radius.circular(r.s(28)),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (bannerUrl != null)
                      CachedNetworkImage(
                        imageUrl: bannerUrl!,
                        fit: BoxFit.cover,
                      )
                    else
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF24384D), Color(0xFF132235)],
                          ),
                        ),
                      ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.10),
                            Colors.black.withValues(alpha: 0.42),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: -r.s(50),
              child: GestureDetector(
                onTap: onTapAvatar,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: r.s(124),
                  height: r.s(124),
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: r.s(104),
                          height: r.s(104),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.nexusTheme.backgroundPrimary,
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.22),
                                blurRadius: 18,
                                offset: Offset(0, r.s(8)),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: avatarUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: avatarUrl!,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: context.surfaceColor,
                                    child: Icon(Icons.person_rounded,
                                        color: Colors.grey[500], size: r.s(56)),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: r.s(2),
                          right: r.s(2),
                          child: Container(
                            width: r.s(30),
                            height: r.s(30),
                            decoration: BoxDecoration(
                              color: context.nexusTheme.accentSecondary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.nexusTheme.backgroundPrimary,
                                width: 2,
                              ),
                            ),
                            child: Icon(Icons.camera_alt_rounded,
                                color: Colors.white, size: r.s(14)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: r.s(62)),
        Center(
          child: GestureDetector(
            onTap: onTapEditFrames,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: r.s(14),
                vertical: r.s(8),
              ),
              decoration: BoxDecoration(
                color: context.surfaceColor.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(r.s(999)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      color: const Color(0xFF5B9BD5), size: r.s(15)),
                  SizedBox(width: r.s(8)),
                  Text(
                    editFramesLabel,
                    style: TextStyle(
                      color: const Color(0xFF5B9BD5),
                      fontSize: r.fs(13),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LIST TILE ESTILO AMINO (linha com leading, content e trailing)
// ═══════════════════════════════════════════════════════════════════════════════

class _AminoListTile extends StatelessWidget {
  final Widget leading;
  final String? title;
  final Widget content;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _AminoListTile({
    required this.leading,
    required this.content,
    this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final borderRadius = BorderRadius.circular(r.s(18));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Ink(
          padding: EdgeInsets.all(r.s(14)),
          decoration: BoxDecoration(
            color: context.nexusTheme.backgroundPrimary.withValues(alpha: 0.42),
            borderRadius: borderRadius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: r.s(40),
                height: r.s(40),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(r.s(14)),
                ),
                child: leading,
              ),
              SizedBox(width: r.s(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null) ...[
                      Text(
                        title!,
                        style: TextStyle(
                          color: context.nexusTheme.textSecondary,
                          fontSize: r.fs(11),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(height: r.s(6)),
                    ],
                    content,
                  ],
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: r.s(10)),
                Padding(
                  padding: EdgeInsets.only(
                    top: title != null ? r.s(18) : r.s(6),
                  ),
                  child: trailing!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  final Widget child;

  const _SettingsSectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(22)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: Offset(0, r.s(8)),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;

  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Row(
      children: [
        Container(
          width: r.s(40),
          height: r.s(40),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(r.s(14)),
          ),
          child: Icon(icon, color: iconColor, size: r.s(22)),
        ),
        SizedBox(width: r.s(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontSize: r.fs(16),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: r.s(2)),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: context.nexusTheme.textSecondary,
                    fontSize: r.fs(12),
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BackgroundOptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color selectedColor;
  final String? imageUrl;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _BackgroundOptionButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.selectedColor,
    this.imageUrl,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final foreground = selected ? Colors.white : context.nexusTheme.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: r.s(12),
          vertical: r.s(12),
        ),
        decoration: BoxDecoration(
          color: selected ? selectedColor : context.nexusTheme.backgroundPrimary.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(r.s(16)),
          border: Border.all(
            color: selected
                ? selectedColor.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.8 : 1,
          ),
          image: imageUrl != null
              ? DecorationImage(
                  image: NetworkImage(imageUrl!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.40),
                    BlendMode.darken,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: r.s(16), color: selected ? Colors.white : context.nexusTheme.accentSecondary),
            SizedBox(width: r.s(8)),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: r.fs(13),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded,
                    color: selected ? Colors.white70 : context.nexusTheme.textHint,
                    size: r.s(16)),
              ),
          ],
        ),
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
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      style: style ??
          TextStyle(color: context.nexusTheme.textPrimary, fontSize: r.fs(15)),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: context.nexusTheme.textHint, fontSize: r.fs(14)),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        filled: false,
        fillColor: Colors.transparent,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        counterText: '',
      ),
      buildCounter: (
        BuildContext context, {
        required int currentLength,
        required bool isFocused,
        required int? maxLength,
      }) {
        if (maxLength == null) return null;
        return Padding(
          padding: EdgeInsets.only(top: r.s(8)),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$currentLength/$maxLength',
              style: TextStyle(
                color: context.nexusTheme.textHint,
                fontSize: r.fs(10),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CommunityBioField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  const _CommunityBioField({
    required this.controller,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final bio = controller.text.trim();
    final hasBio = bio.isNotEmpty;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.s(4)),
      child: hasBio
          ? RichBioRenderer(
              rawContent: bio,
              fontSize: r.fs(14),
              maxPreviewLines: 3,
              fallbackTextColor: context.nexusTheme.textPrimary,
            )
          : Text(
              hintText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.nexusTheme.textHint,
                fontSize: r.fs(14),
                height: 1.45,
                fontWeight: FontWeight.w400,
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
        color: context.nexusTheme.accentSecondary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(r.s(999)),
        border: Border.all(
          color: context.nexusTheme.accentSecondary.withValues(alpha: 0.12),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.nexusTheme.accentSecondary,
          fontSize: r.fs(10),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
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
      final updated = '$text${text.isNotEmpty ? '\n' : ''}$prefix';
      _replaceValue(
        updated,
        selection: TextSelection.collapsed(offset: updated.length),
      );
      return;
    }

    final start = selection.start;
    final end = selection.end;
    final blockStart = text.lastIndexOf('\n', start == 0 ? 0 : start - 1) + 1;
    final nextBreak = text.indexOf('\n', end);
    final blockEnd = nextBreak == -1 ? text.length : nextBreak;
    final block = text.substring(blockStart, blockEnd);
    final lines = block.split('\n');
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
        .join('\n');

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
    final insertText = '${text.isNotEmpty ? '\n\n' : ''}---\n';

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

  void _insertSnippet(String snippet, {int? cursorOffset}) {
    final value = _controller.value;
    final selection = value.selection;
    final text = value.text;

    if (!selection.isValid || selection.start < 0 || selection.end < 0) {
      final updated = '$text$snippet';
      _replaceValue(
        updated,
        selection: TextSelection.collapsed(
          offset: text.length + (cursorOffset ?? snippet.length),
        ),
      );
      return;
    }

    final start = selection.start;
    final end = selection.end;
    final updated = text.replaceRange(start, end, snippet);
    _replaceValue(
      updated,
      selection: TextSelection.collapsed(
        offset: start + (cursorOffset ?? snippet.length),
      ),
    );
  }

  void _insertImageTemplate() {
    const snippet = '![descrição](https://exemplo.com/imagem.png)';
    _insertSnippet(snippet, cursorOffset: 2);
  }

  void _insertGifTemplate() {
    const snippet = '![gif](https://exemplo.com/animacao.gif)';
    _insertSnippet(snippet, cursorOffset: 2);
  }

  void _insertVideoTemplate() {
    const snippet = '[Vídeo](https://exemplo.com/video)';
    _insertSnippet(snippet, cursorOffset: 1);
  }

  Widget _buildToolbarSection(
    BuildContext context, {
    required String title,
    required List<Widget> actions,
  }) {
    final r = context.r;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: context.nexusTheme.textSecondary,
            fontSize: r.fs(12),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: r.s(8)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: actions),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final maxSheetHeight = mediaQuery.size.height * 0.92;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(24))),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 22,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(r.s(16), r.s(12), r.s(16), r.s(16)),
            child: Column(
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              color: context.nexusTheme.textPrimary,
                              fontSize: r.fs(18),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: r.s(6)),
                          Text(
                            '${widget.markdownLabel}. Imagens e GIFs podem ser adicionados por URL.',
                            style: TextStyle(
                              color: context.nexusTheme.textSecondary,
                              fontSize: r.fs(12),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: r.s(12)),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(widget.cancelLabel),
                    ),
                    SizedBox(width: r.s(6)),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
                      child: Text(widget.saveLabel),
                    ),
                  ],
                ),
                SizedBox(height: r.s(16)),
                _buildToolbarSection(
                  context,
                  title: 'Formatação',
                  actions: [
                    _FormatActionChip(
                      icon: Icons.format_bold_rounded,
                      label: 'Negrito',
                      onTap: () => _wrapSelection('**', '**'),
                    ),
                    SizedBox(width: r.s(8)),
                    _FormatActionChip(
                      icon: Icons.format_italic_rounded,
                      label: 'Itálico',
                      onTap: () => _wrapSelection('*', '*'),
                    ),
                    SizedBox(width: r.s(8)),
                    _FormatActionChip(
                      icon: Icons.format_strikethrough_rounded,
                      label: 'Tachado',
                      onTap: () => _wrapSelection('~~', '~~'),
                    ),
                    SizedBox(width: r.s(8)),
                    _FormatActionChip(
                      icon: Icons.title_rounded,
                      label: 'Título',
                      onTap: () => _toggleLinePrefix('## '),
                    ),
                    SizedBox(width: r.s(8)),
                    _FormatActionChip(
                      icon: Icons.format_quote_rounded,
                      label: 'Citação',
                      onTap: () => _toggleLinePrefix('> '),
                    ),
                    SizedBox(width: r.s(8)),
                    _FormatActionChip(
                      icon: Icons.format_list_bulleted_rounded,
                      label: 'Lista',
                      onTap: () => _toggleLinePrefix('- '),
                    ),
                    SizedBox(width: r.s(8)),
                    _FormatActionChip(
                      icon: Icons.horizontal_rule_rounded,
                      label: 'Divisor',
                      onTap: _insertDivider,
                    ),
                  ],
                ),
                SizedBox(height: r.s(12)),
                _buildToolbarSection(
                  context,
                  title: 'Mídia e links',
                  actions: [
                    _FormatActionChip(
                      icon: Icons.image_outlined,
                      label: 'Imagem',
                      onTap: _insertImageTemplate,
                    ),
                    SizedBox(width: r.s(8)),
                    _FormatActionChip(
                      icon: Icons.gif_box_outlined,
                      label: 'GIF',
                      onTap: _insertGifTemplate,
                    ),
                    SizedBox(width: r.s(8)),
                    _FormatActionChip(
                      icon: Icons.smart_display_outlined,
                      label: 'Vídeo',
                      onTap: _insertVideoTemplate,
                    ),
                  ],
                ),
                SizedBox(height: r.s(14)),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.nexusTheme.surfacePrimary,
                      borderRadius: BorderRadius.circular(r.s(18)),
                      border: Border.all(
                        color: _showPreview
                            ? context.dividerClr
                            : context.nexusTheme.accentSecondary.withValues(alpha: 0.55),
                        width: 1.4,
                      ),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(r.s(10), r.s(10), r.s(10), r.s(8)),
                          child: Row(
                            children: [
                              Expanded(
                                child: SegmentedButton<bool>(
                                  showSelectedIcon: true,
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
                                    } else {
                                      _focusNode.unfocus();
                                    }
                                  },
                                ),
                              ),
                              SizedBox(width: r.s(10)),
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _controller,
                                builder: (_, value, __) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${value.text.length}/${widget.maxLength}',
                                      style: TextStyle(
                                        color: context.nexusTheme.textSecondary,
                                        fontSize: r.fs(12),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: r.s(2)),
                                    Text(
                                      _showPreview ? 'Prévia' : 'Editor ativo',
                                      style: TextStyle(
                                        color: context.nexusTheme.textHint,
                                        fontSize: r.fs(10),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(r.s(12), 0, r.s(12), r.s(10)),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _showPreview
                                  ? 'Veja abaixo como a bio vai aparecer.'
                                  : 'O texto começa no topo e continua rolando naturalmente conforme você digita.',
                              style: TextStyle(
                                color: context.nexusTheme.textSecondary,
                                fontSize: r.fs(11),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(r.s(18))),
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
                                              color: context.nexusTheme.textHint,
                                              fontSize: r.fs(14),
                                              height: 1.55,
                                            ),
                                          )
                                        : MarkdownBody(
                                            data: previewText,
                                            selectable: false,
                                            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                              p: TextStyle(
                                                color: context.nexusTheme.textPrimary,
                                                fontSize: r.fs(14),
                                                height: 1.6,
                                              ),
                                              h2: TextStyle(
                                                color: context.nexusTheme.textPrimary,
                                                fontSize: r.fs(18),
                                                fontWeight: FontWeight.w700,
                                              ),
                                              blockquote: TextStyle(
                                                color: context.nexusTheme.textSecondary,
                                                fontSize: r.fs(14),
                                                fontStyle: FontStyle.italic,
                                              ),
                                              blockquoteDecoration: BoxDecoration(
                                                color: context.nexusTheme.accentSecondary.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(r.s(12)),
                                                border: Border.all(
                                                  color: context.nexusTheme.accentSecondary.withValues(alpha: 0.18),
                                                ),
                                              ),
                                            ),
                                          ),
                                  );
                                }

                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _focusNode.requestFocus(),
                                  child: ColoredBox(
                                    color: context.nexusTheme.surfacePrimary,
                                    child: TextField(
                                      controller: _controller,
                                      focusNode: _focusNode,
                                      autofocus: true,
                                      keyboardType: TextInputType.multiline,
                                      textInputAction: TextInputAction.newline,
                                      maxLines: null,
                                      expands: true,
                                      maxLength: widget.maxLength,
                                      textAlignVertical: TextAlignVertical.top,
                                      scrollPadding: EdgeInsets.only(
                                        left: r.s(16),
                                        right: r.s(16),
                                        top: r.s(16),
                                        bottom: bottomInset + r.s(28),
                                      ),
                                      style: TextStyle(
                                        color: context.nexusTheme.textPrimary,
                                        fontSize: r.fs(15),
                                        height: 1.6,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: widget.hintText,
                                        hintStyle: TextStyle(
                                          color: context.nexusTheme.textHint,
                                          fontSize: r.fs(14),
                                          height: 1.5,
                                        ),
                                        contentPadding: EdgeInsets.fromLTRB(
                                          r.s(16),
                                          r.s(16),
                                          r.s(16),
                                          r.s(24),
                                        ),
                                        border: InputBorder.none,
                                        counterText: '',
                                        isCollapsed: false,
                                      ),
                                      onTapOutside: (_) => _focusNode.unfocus(),
                                    ),
                                  ),
                                );
                              },
                            ),
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
          color: context.nexusTheme.surfacePrimary,
          borderRadius: BorderRadius.circular(r.s(999)),
          border: Border.all(
            color: context.dividerClr,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: r.s(16), color: context.nexusTheme.textPrimary),
            SizedBox(width: r.s(6)),
            Text(
              label,
              style: TextStyle(
                color: context.nexusTheme.textPrimary,
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
// RESUMO + GERENCIADOR DA GALERIA
// ═══════════════════════════════════════════════════════════════════════════════

class _GallerySummaryContent extends StatelessWidget {
  final List<String> photos;
  final double itemSize;

  const _GallerySummaryContent({
    required this.photos,
    required this.itemSize,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    if (photos.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Galeria',
            style: TextStyle(
              color: context.nexusTheme.textPrimary,
              fontSize: r.fs(15),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: r.s(3)),
          Text(
            'Adicione imagens',
            style: TextStyle(
              color: context.nexusTheme.textSecondary,
              fontSize: r.fs(12),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    final previewPhotos = photos.take(2).toList();

    return Row(
      children: [
        SizedBox(
          width: itemSize + r.s(18),
          height: itemSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: previewPhotos.asMap().entries.map((entry) {
              final index = entry.key;
              final photo = entry.value;
              return Positioned(
                left: index * r.s(18),
                child: Container(
                  width: itemSize,
                  height: itemSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(r.s(14)),
                    border: Border.all(
                      color: context.surfaceColor,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: Offset(0, r.s(4)),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(r.s(12)),
                    child: CachedNetworkImage(
                      imageUrl: photo,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(width: r.s(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'Galeria',
                    style: TextStyle(
                      color: context.nexusTheme.textPrimary,
                      fontSize: r.fs(15),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: r.s(8)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: r.s(8),
                      vertical: r.s(4),
                    ),
                    decoration: BoxDecoration(
                      color: context.nexusTheme.accentSecondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(r.s(999)),
                    ),
                    child: Text(
                      '${photos.length}',
                      style: TextStyle(
                        color: context.nexusTheme.accentSecondary,
                        fontSize: r.fs(11),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: r.s(4)),
              Text(
                photos.length == 1 ? 'Toque para gerenciar' : 'Toque para organizar',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.nexusTheme.textSecondary,
                  fontSize: r.fs(12),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommunityGalleryManagerScreen extends StatefulWidget {
  final List<String> initialPhotos;
  final int maxPhotos;
  final Future<String?> Function() onPickPhoto;

  const _CommunityGalleryManagerScreen({
    required this.initialPhotos,
    required this.maxPhotos,
    required this.onPickPhoto,
  });

  @override
  State<_CommunityGalleryManagerScreen> createState() =>
      _CommunityGalleryManagerScreenState();
}

class _CommunityGalleryManagerScreenState
    extends State<_CommunityGalleryManagerScreen> {
  late List<String> _photos;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _photos = List<String>.from(widget.initialPhotos);
  }

  Future<void> _addPhoto() async {
    if (_isUploading || _photos.length >= widget.maxPhotos) return;

    setState(() => _isUploading = true);
    try {
      final url = await widget.onPickPhoto();
      if (url != null && mounted) {
        setState(() {
          _photos = [..._photos, url];
        });
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _removePhoto(int index) {
    setState(() {
      final updated = List<String>.from(_photos)..removeAt(index);
      _photos = updated;
    });
  }

  void _reorderPhotos(int oldIndex, int newIndex) {
    setState(() {
      final updated = List<String>.from(_photos);
      if (newIndex > oldIndex) newIndex -= 1;
      final moved = updated.removeAt(oldIndex);
      updated.insert(newIndex, moved);
      _photos = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.nexusTheme.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: context.nexusTheme.textPrimary, size: r.s(20)),
          onPressed: () => Navigator.of(context).pop(_photos),
        ),
        title: Text(
          'Gerenciar galeria',
          style: TextStyle(
            color: context.nexusTheme.textPrimary,
            fontSize: r.fs(17),
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: r.s(12)),
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(_photos),
              child: Text(
                'Concluir',
                style: TextStyle(
                  color: context.nexusTheme.accentSecondary,
                  fontSize: r.fs(13),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _photos.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: r.s(24)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: r.s(64),
                            height: r.s(64),
                            decoration: BoxDecoration(
                              color: context.nexusTheme.accentSecondary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(r.s(20)),
                            ),
                            child: Icon(
                              Icons.photo_library_outlined,
                              color: context.nexusTheme.accentSecondary,
                              size: r.s(30),
                            ),
                          ),
                          SizedBox(height: r.s(14)),
                          Text(
                            'Sua galeria está vazia',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.nexusTheme.textPrimary,
                              fontSize: r.fs(16),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: r.s(6)),
                          Text(
                            'Adicione imagens para começar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: context.nexusTheme.textSecondary,
                              fontSize: r.fs(13),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: EdgeInsets.fromLTRB(r.s(16), r.s(8), r.s(16), r.s(16)),
                    itemCount: _photos.length,
                    onReorder: _reorderPhotos,
                    buildDefaultDragHandles: false,
                    itemBuilder: (context, index) {
                      final photo = _photos[index];
                      return Container(
                        key: ValueKey('$photo-$index'),
                        margin: EdgeInsets.only(bottom: r.s(12)),
                        decoration: BoxDecoration(
                          color: context.surfaceColor,
                          borderRadius: BorderRadius.circular(r.s(12)),
                          border: Border.all(color: context.dividerClr),
                        ),
                        child: Row(
                          children: [
                            Padding(
                              padding: EdgeInsets.all(r.s(12)),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(r.s(10)),
                                child: CachedNetworkImage(
                                  imageUrl: photo,
                                  width: r.s(84),
                                  height: r.s(84),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: r.s(12)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: r.s(8),
                                        vertical: r.s(4),
                                      ),
                                      decoration: BoxDecoration(
                                        color: index == 0
                                            ? context.nexusTheme.accentSecondary.withValues(alpha: 0.14)
                                            : context.dividerClr.withValues(alpha: 0.35),
                                        borderRadius: BorderRadius.circular(r.s(999)),
                                      ),
                                      child: Text(
                                        index == 0 ? 'Capa' : 'Imagem ${index + 1}',
                                        style: TextStyle(
                                          color: index == 0
                                              ? context.nexusTheme.accentSecondary
                                              : context.nexusTheme.textSecondary,
                                          fontSize: r.fs(11),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: r.s(8)),
                                    Text(
                                      index == 0 ? 'Capa atual' : 'Arraste para reordenar',
                                      style: TextStyle(
                                        color: context.nexusTheme.textSecondary,
                                        fontSize: r.fs(12),
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Column(
                              children: [
                                IconButton(
                                  tooltip: 'Remover imagem',
                                  onPressed: () => _removePhoto(index),
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: context.nexusTheme.error,
                                    size: r.s(22),
                                  ),
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Padding(
                                    padding: EdgeInsets.all(r.s(8)),
                                    child: Icon(
                                      Icons.drag_handle_rounded,
                                      color: context.nexusTheme.textSecondary,
                                      size: r.s(22),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(width: r.s(4)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(r.s(16), r.s(8), r.s(16), r.s(16)),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isUploading || _photos.length >= widget.maxPhotos
                      ? null
                      : _addPhoto,
                  icon: _isUploading
                      ? SizedBox(
                          width: r.s(16),
                          height: r.s(16),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                        _photos.length >= widget.maxPhotos
                            ? 'Limite de ${widget.maxPhotos} imagens'
                            : 'Adicionar imagem',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.nexusTheme.accentSecondary,
                    disabledBackgroundColor:
                        context.nexusTheme.accentSecondary.withValues(alpha: 0.45),
                    padding: EdgeInsets.symmetric(vertical: r.s(14)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.s(12)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
