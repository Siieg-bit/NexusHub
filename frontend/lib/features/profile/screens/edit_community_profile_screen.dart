import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../core/services/media_upload_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../communities/providers/community_detail_providers.dart';

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
  List<String> _gallery = [];
  bool _galleryLoaded = false; // garante que galeria só é enviada após carregamento
  bool _mediaLoaded = false;  // garante que icon/banner/background só são enviados após carregamento

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
              'local_background_url, local_gallery')
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
    if (url != null && mounted) setState(() => _localIconUrl = url);
  }

  Future<void> _pickBanner() async {
    final url = await _uploadCommunityImage('banner');
    if (url != null && mounted) setState(() => _localBannerUrl = url);
  }

  Future<void> _pickBackground() async {
    final url = await _uploadCommunityImage('background');
    if (url != null && mounted) setState(() => _localBackgroundUrl = url);
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
      updated.removeAt(index);
      _gallery = updated;
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

      if (!_mediaLoaded) {
        // Carregamento inicial falhou — buscar valores atuais antes de salvar
        try {
          final current = await SupabaseService.table('community_members')
              .select('local_icon_url, local_banner_url, local_background_url')
              .eq('community_id', widget.communityId)
              .eq('user_id', userId)
              .maybeSingle();
          if (current != null) {
            iconUrlToSave = current['local_icon_url'] as String?;
            bannerUrlToSave = current['local_banner_url'] as String?;
            backgroundUrlToSave = current['local_background_url'] as String?;
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
        'p_local_gallery': galleryPayload,
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
                    editFramesLabel: s.editProfileFrames,
                    onTapBanner: _pickBanner,
                    onTapAvatar: _pickAvatar,
                    onRemoveBanner: _localBannerUrl != null
                        ? () => setState(() => _localBannerUrl = null)
                        : null,
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
                    content: _InlineTextField(
                      controller: _bioController,
                      hintText: s.leaveEmptyBio,
                      maxLines: 3,
                      maxLength: 500,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: r.fs(14),
                      ),
                    ),
                  ),

                  _AminoDivider(),

                  // ══════════════════════════════════════════════════════
                  // LINHA: Plano de Fundo (Opcional)
                  // ══════════════════════════════════════════════════════
                  GestureDetector(
                    onTap: _pickBackground,
                    child: _AminoListTile(
                      leading: Icon(Icons.palette_rounded,
                          color: const Color(0xFF2196F3), size: r.s(28)),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            s.profileBackgroundOptional,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: r.fs(15),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      trailing: _localBackgroundUrl != null
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Thumbnail clicável: abre o picker para trocar o background
                                GestureDetector(
                                  onTap: _pickBackground,
                                  child: ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(r.s(4)),
                                    child: CachedNetworkImage(
                                      imageUrl: _localBackgroundUrl!,
                                      width: r.s(44),
                                      height: r.s(44),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                SizedBox(width: r.s(4)),
                                // Botão X: remove o background
                                GestureDetector(
                                  onTap: () => setState(
                                      () => _localBackgroundUrl = null),
                                  child: Icon(Icons.close_rounded,
                                      color: Colors.grey[500],
                                      size: r.s(18)),
                                ),
                              ],
                            )
                          : Icon(Icons.chevron_right_rounded,
                              color: Colors.grey[400], size: r.s(22)),
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
  final String editFramesLabel;
  final VoidCallback onTapBanner;
  final VoidCallback onTapAvatar;
  final VoidCallback? onRemoveBanner;

  const _BannerAvatarSection({
    required this.bannerUrl,
    required this.avatarUrl,
    required this.editFramesLabel,
    required this.onTapBanner,
    required this.onTapAvatar,
    this.onRemoveBanner,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;

    return Column(
      children: [
        // ── Banner ──────────────────────────────────────────────────────
        GestureDetector(
          onTap: onTapBanner,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // Banner
              Container(
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

              // Botão de remover banner (canto superior direito)
              if (bannerUrl != null && onRemoveBanner != null)
                Positioned(
                  top: r.s(8),
                  right: r.s(8),
                  child: GestureDetector(
                    onTap: onRemoveBanner,
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
        ),

        // Espaço para o avatar que sobrepõe
        SizedBox(height: r.s(60)),

        // "Editar Molduras de Perfil" — link azul clicável
        GestureDetector(
          onTap: () => context.push('/inventory'),
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
