import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';

/// Editar Perfil da Comunidade — estilo Amino Apps.
///
/// Permite ao usuário customizar seu perfil LOCAL dentro de uma comunidade:
///   - Nickname local (diferente do global)
///   - Bio local
///   - Avatar local
///   - Banner local
///
/// No Amino, cada comunidade pode ter um perfil diferente.
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
  bool _isLoading = true;
  bool _isSaving = false;

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
          .select('local_nickname, local_bio, local_icon_url, local_banner_url')
          .eq('community_id', widget.communityId)
          .eq('user_id', userId)
          .single();

      if (mounted) {
        setState(() {
          _nicknameController.text =
              (membership['local_nickname'] as String?) ?? '';
          _bioController.text = (membership['local_bio'] as String?) ?? '';
          _localIconUrl = membership['local_icon_url'] as String?;
          _localBannerUrl = membership['local_banner_url'] as String?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _uploadImage(String folder) async {
    final s = getStrings();
    final r = context.r;
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: r.w(1200),
      imageQuality: 85,
    );
    if (image == null) return null;

    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final bytes = await image.readAsBytes();
      final ext = image.name.split('.').last;
      final path =
          'community_profiles/${widget.communityId}/$userId/$folder/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await SupabaseService.client.storage
          .from('avatars')
          .uploadBinary(path, bytes);

      return SupabaseService.client.storage.from('avatars').getPublicUrl(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorUploadTryAgain),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _pickAvatar() async {
    final url = await _uploadImage('avatar');
    if (url != null && mounted) {
      setState(() => _localIconUrl = url);
    }
  }

  Future<void> _pickBanner() async {
    final url = await _uploadImage('banner');
    if (url != null && mounted) {
      setState(() => _localBannerUrl = url);
    }
  }

  Future<void> _save() async {
    final s = getStrings();
    setState(() => _isSaving = true);

    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception(s.notAuthenticated);

      final updates = <String, dynamic>{};

      final nickname = _nicknameController.text.trim();
      updates['local_nickname'] = nickname.isEmpty ? null : nickname;

      final bio = _bioController.text.trim();
      updates['local_bio'] = bio.isEmpty ? null : bio;

      updates['local_icon_url'] = _localIconUrl;
      updates['local_banner_url'] = _localBannerUrl;

      await SupabaseService.table('community_members')
          .update(updates)
          .eq('community_id', widget.communityId)
          .eq('user_id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: Text(s.communityProfileUpdated),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

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
          icon: Icon(Icons.close_rounded, color: context.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Editar Perfil',
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
                padding:
                    EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
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
                        child: CircularProgressIndicator(
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
              padding: EdgeInsets.symmetric(horizontal: r.s(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: r.s(16)),

                  // ══════════════════════════════════════════════════════
                  // BANNER
                  // ══════════════════════════════════════════════════════
                  const _SectionLabel(text: 'Banner'),
                  SizedBox(height: r.s(8)),
                  GestureDetector(
                    onTap: _pickBanner,
                    child: Container(
                      height: r.s(140),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(r.s(12)),
                        color: context.cardBg,
                        image: _localBannerUrl != null
                            ? DecorationImage(
                                image: NetworkImage(_localBannerUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _localBannerUrl == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_rounded,
                                    color: context.textHint, size: r.s(36)),
                                SizedBox(height: r.s(4)),
                                Text(
                                  'Toque para adicionar banner',
                                  style: TextStyle(
                                    color: context.textHint,
                                    fontSize: r.fs(12),
                                  ),
                                ),
                              ],
                            )
                          : Stack(
                              children: [
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: Container(
                                    padding: EdgeInsets.all(r.s(6)),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.edit_rounded,
                                        color: Colors.white, size: r.s(16)),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (_localBannerUrl != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setState(() => _localBannerUrl = null),
                        child: Text(
                          s.removeBanner,
                          style: TextStyle(
                            color: AppTheme.errorColor,
                            fontSize: r.fs(12),
                          ),
                        ),
                      ),
                    ),

                  SizedBox(height: r.s(20)),

                  // ══════════════════════════════════════════════════════
                  // AVATAR
                  // ══════════════════════════════════════════════════════
                  const _SectionLabel(text: 'Avatar'),
                  SizedBox(height: r.s(8)),
                  Center(
                    child: GestureDetector(
                      onTap: _pickAvatar,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: context.cardBg,
                            backgroundImage: _localIconUrl != null
                                ? NetworkImage(_localIconUrl!)
                                : null,
                            child: _localIconUrl == null
                                ? Icon(Icons.person_rounded,
                                    color: context.textHint, size: r.s(40))
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: EdgeInsets.all(r.s(6)),
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.scaffoldBg,
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
                  if (_localIconUrl != null)
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() => _localIconUrl = null),
                        child: Text(
                          'Remover avatar local',
                          style: TextStyle(
                            color: AppTheme.errorColor,
                            fontSize: r.fs(12),
                          ),
                        ),
                      ),
                    ),

                  SizedBox(height: r.s(24)),

                  // ══════════════════════════════════════════════════════
                  // NICKNAME LOCAL
                  // ══════════════════════════════════════════════════════
                  const _SectionLabel(text: 'Nickname nesta comunidade'),
                  SizedBox(height: r.s(8)),
                  _AminoTextField(
                    controller: _nicknameController,
                    hintText: s.leaveEmptyGlobal,
                    maxLength: 24,
                  ),

                  SizedBox(height: r.s(20)),

                  // ══════════════════════════════════════════════════════
                  // BIO LOCAL
                  // ══════════════════════════════════════════════════════
                  _SectionLabel(text: s.bioInCommunity),
                  SizedBox(height: r.s(8)),
                  _AminoTextField(
                    controller: _bioController,
                    hintText: s.leaveEmptyBio,
                    maxLines: 5,
                    maxLength: 500,
                  ),

                  SizedBox(height: r.s(16)),

                  // ══════════════════════════════════════════════════════
                  // NOTA INFORMATIVA
                  // ══════════════════════════════════════════════════════
                  Container(
                    padding: EdgeInsets.all(r.s(12)),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(r.s(10)),
                      border: Border.all(
                        color: AppTheme.accentColor.withValues(alpha: 0.2),
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

                  SizedBox(height: r.s(40)),
                ],
              ),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends ConsumerWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: context.textSecondary,
        fontSize: r.fs(11),
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _AminoTextField extends ConsumerWidget {
  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final int? maxLength;

  const _AminoTextField({
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      style: TextStyle(
        color: context.textPrimary,
        fontSize: r.fs(15),
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: context.textHint,
          fontSize: r.fs(14),
        ),
        filled: true,
        fillColor: context.cardBg,
        counterStyle: TextStyle(
          color: context.textHint,
          fontSize: r.fs(11),
        ),
        contentPadding:
            EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(12)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.s(10)),
          borderSide: BorderSide(
            color: context.dividerClr,
            width: 0.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.s(10)),
          borderSide: BorderSide(
            color: context.dividerClr,
            width: 0.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.s(10)),
          borderSide: const BorderSide(
            color: AppTheme.accentColor,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
