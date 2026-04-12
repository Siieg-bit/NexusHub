import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/media_upload_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../widgets/rich_bio.dart';
import '../../../../config/nexus_theme_extension.dart';
import '../../../../config/nexus_theme_extension.dart';

/// Tela de edição de perfil do usuário com Rich Bio Editor.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nicknameController;
  late TextEditingController _bioController;
  late TextEditingController _aminoIdController;
  bool _isLoading = false;
  bool _bioPreviewMode = false;
  late TabController _bioTabController;
  Timer? _aminoIdDebounce;
  bool _isCheckingAminoId = false;
  bool? _isAminoIdAvailable;
  String? _aminoIdAvailabilityMessage;
  String _initialAminoId = '';

  // FIX Bug #4: FocusNode persistente para o campo de bio
  final FocusNode _bioFocusNode = FocusNode();

  // FIX Bug #5: Estado do avatar
  String? _avatarUrl;
  String? _originalAvatarUrl; // para detectar mudança real
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nicknameController = TextEditingController(text: user?.nickname ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _aminoIdController = TextEditingController(text: user?.aminoId ?? '');
    _initialAminoId = _normalizeAminoId(user?.aminoId ?? '');
    _isAminoIdAvailable = _initialAminoId.isEmpty ? null : true;
    _avatarUrl = user?.iconUrl;
    _originalAvatarUrl = user?.iconUrl;
    _bioTabController = TabController(length: 2, vsync: this);
    _bioTabController.addListener(() {
      setState(() => _bioPreviewMode = _bioTabController.index == 1);
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    _aminoIdDebounce?.cancel();
    _aminoIdController.dispose();
    _bioTabController.dispose();
    _bioFocusNode.dispose();
    super.dispose();
  }

  String _normalizeAminoId(String value) {
    return value.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();
  }

  String? _validateAminoIdValue(String? value, dynamic s) {
    if (value == null || value.trim().isEmpty) return null;
    final trimmed = _normalizeAminoId(value);
    if (trimmed.length < 3) return s.min3Chars;
    if (trimmed.length > 30) return s.max30Chars;
    final validChars = RegExp(r'^[a-z0-9_]+$');
    if (!validChars.hasMatch(trimmed)) {
      return 'Use apenas letras minúsculas, números e _';
    }
    return null;
  }

  Future<bool> _checkAminoIdAvailability({required bool silent}) async {
    final s = getStrings();
    final userId = SupabaseService.currentUserId;
    final normalizedAminoId = _normalizeAminoId(_aminoIdController.text);
    final validationError = _validateAminoIdValue(normalizedAminoId, s);

    if (normalizedAminoId.isEmpty) {
      if (mounted) {
        setState(() {
          _isCheckingAminoId = false;
          _isAminoIdAvailable = null;
          _aminoIdAvailabilityMessage = null;
        });
      }
      return true;
    }

    if (validationError != null) {
      if (mounted && !silent) {
        setState(() {
          _isCheckingAminoId = false;
          _isAminoIdAvailable = false;
          _aminoIdAvailabilityMessage = validationError;
        });
      }
      return false;
    }

    if (normalizedAminoId == _initialAminoId) {
      if (mounted) {
        setState(() {
          _isCheckingAminoId = false;
          _isAminoIdAvailable = true;
          _aminoIdAvailabilityMessage = 'Seu @username global atual';
        });
      }
      return true;
    }

    if (mounted) {
      setState(() {
        _isCheckingAminoId = true;
        _isAminoIdAvailable = null;
        _aminoIdAvailabilityMessage = null;
      });
    }

    try {
      final existing = await SupabaseService.table('profiles')
          .select('id')
          .eq('amino_id', normalizedAminoId)
          .neq('id', userId ?? '')
          .maybeSingle();
      final available = existing == null;
      if (mounted) {
        setState(() {
          _isCheckingAminoId = false;
          _isAminoIdAvailable = available;
          _aminoIdAvailabilityMessage = available
              ? '@username disponível globalmente'
              : s.aminoIdInUse;
        });
      }
      return available;
    } catch (_) {
      if (mounted) {
        setState(() {
          _isCheckingAminoId = false;
          _isAminoIdAvailable = null;
          _aminoIdAvailabilityMessage = s.tryAgainGeneric;
        });
      }
      return false;
    }
  }

  void _onAminoIdChanged(String value) {
    _aminoIdDebounce?.cancel();
    setState(() {
      _aminoIdAvailabilityMessage = null;
      _isAminoIdAvailable = null;
    });

    final normalizedAminoId = _normalizeAminoId(value);
    final s = getStrings();
    final validationError = _validateAminoIdValue(normalizedAminoId, s);

    if (normalizedAminoId.isEmpty) {
      return;
    }

    if (validationError != null) {
      setState(() {
        _isCheckingAminoId = false;
        _isAminoIdAvailable = false;
        _aminoIdAvailabilityMessage = validationError;
      });
      return;
    }

    _aminoIdDebounce = Timer(const Duration(milliseconds: 450), () {
      _checkAminoIdAvailability(silent: false);
    });
  }

  Future<void> _saveProfile() async {
    final s = getStrings();
    if ((_formKey.currentState?.validate() != true)) return;

    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final aminoId = _aminoIdController.text.trim();
      final normalizedAminoId = _normalizeAminoId(aminoId);
      final isAminoIdAvailable = await _checkAminoIdAvailability(silent: false);
      if (!isAminoIdAvailable) {
        setState(() => _isLoading = false);
        return;
      }
      final updateData = <String, dynamic>{
        'nickname': _nicknameController.text.trim(),
        'bio': _bioController.text.trim(),
        // amino_id representa o @username global — enviar null se vazio para evitar violação
        'amino_id': normalizedAminoId.isEmpty ? null : normalizedAminoId,
      };
      // Incluir avatar apenas se foi alterado pelo usuário
      if (_avatarUrl != null && _avatarUrl != _originalAvatarUrl) {
        updateData['icon_url'] = _avatarUrl;
      }
      await SupabaseService.table('profiles')
          .update(updateData)
          .eq('id', userId);

      // Atualizar estado local do authProvider para refletir imediatamente
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null) {
        ref.read(authProvider.notifier).updateUserProfile(
          currentUser.copyWith(
            nickname: _nicknameController.text.trim(),
            bio: _bioController.text.trim(),
            iconUrl: (_avatarUrl != null && _avatarUrl != _originalAvatarUrl)
                ? _avatarUrl
                : currentUser.iconUrl,
            // Atualizar o @username global no estado local para refletir imediatamente.
            // String vazia quando apagado (consistente com fromJson: ?? '').
            aminoId: normalizedAminoId,
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.profileUpdatedSuccess),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        final isDuplicate = e.toString().contains('duplicate') ||
            e.toString().contains('unique') ||
            e.toString().contains('23505');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isDuplicate ? s.aminoIdInUse : s.tryAgainGeneric),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// FIX Bug #5: Upload de avatar via MediaUploadService
  Future<void> _pickAndUploadAvatar() async {
    final s = getStrings();
    setState(() => _isUploadingAvatar = true);
    try {
      final url = await MediaUploadService.uploadAvatar();
      if (url != null && mounted) {
        setState(() => _avatarUrl = url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorUploadingImage),
            backgroundColor: context.nexusTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  /// Insere formatação Markdown no campo de bio.
  void _applyFormat(String prefix, String suffix,
      {String placeholder = 'texto'}) {
    final ctrl = _bioController;
    final sel = ctrl.selection;
    final text = ctrl.text;
    final selectedText = sel.isValid && sel.start != sel.end
        ? text.substring(sel.start, sel.end)
        : placeholder;
    final replacement = '$prefix$selectedText$suffix';
    final newText = sel.isValid
        ? text.replaceRange(sel.start, sel.end, replacement)
        : text + replacement;
    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
          offset:
              sel.isValid ? sel.start + replacement.length : newText.length),
    );
    // FIX Bug #4: Re-focar o campo de bio após aplicar formatação
    _bioFocusNode.requestFocus();
  }

  Widget _buildBioPreviewPane(Responsive r,
      {EdgeInsetsGeometry? padding, double? fontSize}) {
    final s = getStrings();
    return SingleChildScrollView(
      padding: padding ?? EdgeInsets.all(r.s(12)),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _bioController,
        builder: (context, value, _) => RichBioRenderer(
          rawContent: value.text,
          emptyPlaceholder: s.noContentYet,
          fontSize: fontSize ?? r.fs(14),
          fallbackTextColor: context.nexusTheme.textPrimary,
        ),
      ),
    );
  }

  Future<void> _openBioEditorSheet() async {
    final s = getStrings();
    final updatedBio = await showRichBioEditorSheet(
      context,
      initialValue: _bioController.text,
      title: s.bio,
      hintText: s.writeBioHint,
      saveLabel: s.save,
      cancelLabel: s.cancel,
      editorLabel: s.edit,
      previewLabel: s.preview,
      markdownLabel: 'Formate sua bio com Markdown',
      maxLength: 500,
    );

    if (updatedBio == null || !mounted) return;

    setState(() {
      _bioController.value = TextEditingValue(
        text: updatedBio,
        selection: TextSelection.collapsed(offset: updatedBio.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.nexusTheme.textPrimary),
        title: Text(
          s.editProfile,
          style: TextStyle(
            color: context.nexusTheme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? SizedBox(
                    width: r.s(20),
                    height: r.s(20),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(context.nexusTheme.accentPrimary),
                    ),
                  )
                :  Text(
                    s.save,
                    style: TextStyle(
                      color: context.nexusTheme.accentPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(r.s(20)),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar — FIX Bug #5: GestureDetector com upload
              Center(
                child: GestureDetector(
                  onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  context.nexusTheme.accentPrimary.withValues(alpha: 0.2),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: context.surfaceColor,
                          backgroundImage:
                              _avatarUrl != null && _avatarUrl!.isNotEmpty
                                  ? CachedNetworkImageProvider(_avatarUrl!)
                                  : null,
                          child: _avatarUrl == null || _avatarUrl!.isEmpty
                              ? Text(
                                  (user?.nickname ?? '?')[0].toUpperCase(),
                                  style: TextStyle(
                                    fontSize: r.fs(36),
                                    fontWeight: FontWeight.w800,
                                    color: context.nexusTheme.accentPrimary,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(r.s(8)),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                context.nexusTheme.accentPrimary,
                                context.nexusTheme.accentSecondary
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.nexusTheme.backgroundPrimary,
                              width: r.s(3),
                            ),
                          ),
                          child: _isUploadingAvatar
                              ? SizedBox(
                                  width: r.s(18),
                                  height: r.s(18),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: r.s(18),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: r.s(32)),

              // Nickname
              _buildTextField(
                controller: _nicknameController,
                label: s.nicknameHint,
                icon: Icons.person_outlined,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return s.requiredField;
                  }
                  if (value.trim().length < 3) return s.min3Chars;
                  return null;
                },
              ),
              SizedBox(height: r.s(16)),

              // @username global
              _buildTextField(
                controller: _aminoIdController,
                label: '@username',
                icon: Icons.alternate_email_rounded,
                hintText: 'Único no app inteiro • exibido só no perfil global',
                validator: (value) => _validateAminoIdValue(value, s),
                maxLength: 30,
                onChanged: _onAminoIdChanged,
                suffixIcon: _isCheckingAminoId
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: r.s(18),
                          height: r.s(18),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(context.nexusTheme.accentPrimary),
                          ),
                        ),
                      )
                    : _isAminoIdAvailable == null
                        ? null
                        : Icon(
                            _isAminoIdAvailable!
                                ? Icons.check_circle_rounded
                                : Icons.error_outline_rounded,
                            color: _isAminoIdAvailable!
                                ? context.nexusTheme.accentPrimary
                                : context.nexusTheme.error,
                          ),
              ),
              SizedBox(height: r.s(6)),
              Text(
                _aminoIdAvailabilityMessage ??
                    'Esse @username é o identificador único da sua conta em todo o app. Ele não aparece dentro das comunidades.',
                style: TextStyle(
                  color: (_isAminoIdAvailable == false)
                      ? context.nexusTheme.error
                      : (_isAminoIdAvailable == true
                          ? context.nexusTheme.accentPrimary
                          : Colors.grey[500]),
                  fontSize: r.fs(12),
                ),
              ),
              SizedBox(height: r.s(16)),
              // Rich Bio Editor
              _buildRichBioEditor(r),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildRichBioEditor(Responsive r) {
    final s = getStrings();
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(16)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Padding(
        padding: EdgeInsets.all(r.s(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  color: context.nexusTheme.accentPrimary,
                  size: r.s(20),
                ),
                SizedBox(width: r.s(8)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.bio,
                        style: TextStyle(
                          color: context.nexusTheme.textPrimary,
                          fontSize: r.fs(15),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: r.s(4)),
                      Text(
                        'Use o editor completo para formatar a bio, trocar a cor do texto e anexar mídia.',
                        style: TextStyle(
                          color: context.nexusTheme.textSecondary,
                          fontSize: r.fs(12),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: r.s(12)),
                FilledButton.icon(
                  onPressed: _openBioEditorSheet,
                  icon: const Icon(Icons.open_in_full_rounded),
                  label: Text(s.edit),
                ),
              ],
            ),
            SizedBox(height: r.s(14)),
            Container(
              width: double.infinity,
              constraints: BoxConstraints(minHeight: r.s(140)),
              decoration: BoxDecoration(
                color: context.nexusTheme.surfacePrimary,
                borderRadius: BorderRadius.circular(r.s(14)),
                border: Border.all(color: context.dividerClr),
              ),
              child: _buildBioPreviewPane(
                r,
                padding: EdgeInsets.all(r.s(14)),
                fontSize: r.fs(14),
              ),
            ),
            SizedBox(height: r.s(10)),
            Text(
              'A mesma experiência de edição também será usada nas comunidades, mas o salvamento global continua separado.',
              style: TextStyle(
                color: context.nexusTheme.textHint,
                fontSize: r.fs(11),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatToolbar(Responsive r) {
    final s = getStrings();
    final buttons = [
      _FormatButton(
          icon: Icons.format_bold,
          tooltip: s.bold,
          onTap: () => _applyFormat('**', '**')),
      _FormatButton(
          icon: Icons.format_italic,
          tooltip: s.italic,
          onTap: () => _applyFormat('*', '*')),
      _FormatButton(
          icon: Icons.format_strikethrough,
          tooltip: s.strikethrough,
          onTap: () => _applyFormat('~~', '~~')),
      _FormatButton(
          icon: Icons.link_rounded,
          tooltip: s.link,
          onTap: () => _showLinkDialog()),
      _FormatButton(
          icon: Icons.format_list_bulleted_rounded,
          tooltip: s.list,
          onTap: () => _applyFormat('\n- ', '', placeholder: 'item')),
    ];

    return Container(
      height: r.s(36),
      margin: EdgeInsets.symmetric(horizontal: r.s(8), vertical: r.s(4)),
      decoration: BoxDecoration(
        color: context.nexusTheme.backgroundPrimary,
        borderRadius: BorderRadius.circular(r.s(8)),
      ),
      child: Row(
        children: buttons
            .map((b) => Tooltip(
                  message: b.tooltip,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: b.onTap,
                      borderRadius: BorderRadius.circular(r.s(6)),
                      splashColor: context.nexusTheme.accentPrimary.withValues(alpha: 0.2),
                      highlightColor:
                          context.nexusTheme.accentPrimary.withValues(alpha: 0.1),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: r.s(8)),
                        child: Icon(b.icon,
                            size: r.s(18), color: Colors.grey[400]),
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  void _showLinkDialog() {
    final s = getStrings();
    final urlCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text(s.insertLink2,
            style: TextStyle(
                color: context.nexusTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              style: TextStyle(color: context.nexusTheme.textPrimary),
              decoration: InputDecoration(
                labelText: s.linkTitle,
                labelStyle: TextStyle(color: Colors.grey[500]),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              style: TextStyle(color: context.nexusTheme.textPrimary),
              decoration: InputDecoration(
                labelText: s.linkUrl,
                labelStyle: TextStyle(color: Colors.grey[500]),
                hintText: 'https://',
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel, style: TextStyle(color: Colors.grey[500])),
          ),
          TextButton(
            onPressed: () {
              final label = labelCtrl.text.trim().isEmpty
                  ? urlCtrl.text.trim()
                  : labelCtrl.text.trim();
              final url = urlCtrl.text.trim();
              if (url.isNotEmpty) {
                _applyFormat('[$label](', ')', placeholder: url);
              }
              Navigator.pop(ctx);
            },
            child: Text(s.insertLink,
                style: const TextStyle(
                    color: context.nexusTheme.accentPrimary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ).then((_) {
      urlCtrl.dispose();
      labelCtrl.dispose();
    });
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    Widget? suffixIcon,
  }) {
    final r = context.r;
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(16)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        validator: validator,
        onChanged: onChanged,
        style: TextStyle(color: context.nexusTheme.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[500]),
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(icon, color: context.nexusTheme.accentPrimary),
          suffixIcon: suffixIcon,
          alignLabelWithHint: maxLines > 1,
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(16)),
          counterStyle: TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }
}

class _FormatButton {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _FormatButton(
      {required this.icon, required this.tooltip, required this.onTap});
}
