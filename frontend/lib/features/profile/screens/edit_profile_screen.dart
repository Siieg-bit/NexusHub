import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/services/media_upload_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../widgets/rich_bio.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../../../core/widgets/user_status_badge.dart';
import 'edit_interests_screen.dart';

/// Tela de edição de perfil do usuário com Rich Bio Editor.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nicknameController;
  late TextEditingController _bioController;
  late TextEditingController _aminoIdController;
  bool _isLoading = false;
  Timer? _aminoIdDebounce;
  bool _isCheckingAminoId = false;
  bool? _isAminoIdAvailable;
  String? _aminoIdAvailabilityMessage;
  String _initialAminoId = '';
  String _initialNickname = '';
  String _initialBio = '';

  // FIX Bug #4: FocusNode persistente para o campo de bio
  final FocusNode _bioFocusNode = FocusNode();

  // FIX Bug #5: Estado do avatar
  String? _avatarUrl;
  String? _originalAvatarUrl; // para detectar mudança real
  bool _isUploadingAvatar = false;

  /// Retorna true se houver alguma mudança não salva.
  bool get _hasUnsavedChanges =>
      _nicknameController.text.trim() != _initialNickname ||
      _bioController.text.trim() != _initialBio ||
      _avatarUrl != _originalAvatarUrl;

  // Status / Mood
  String? _statusEmoji;
  String? _statusText;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nicknameController = TextEditingController(text: user?.nickname ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _aminoIdController = TextEditingController(text: user?.aminoId ?? '');
    _initialAminoId = _normalizeAminoId(user?.aminoId ?? '');
    _initialNickname = user?.nickname?.trim() ?? '';
    _initialBio = user?.bio?.trim() ?? '';
    _isAminoIdAvailable = _initialAminoId.isEmpty ? null : true;
    _avatarUrl = user?.iconUrl;
    _originalAvatarUrl = user?.iconUrl;
    _statusEmoji = user?.statusEmoji;
    _statusText = user?.statusText;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    _aminoIdDebounce?.cancel();
    _aminoIdController.dispose();
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

    if (_isUploadingAvatar) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Aguarde o upload do avatar terminar antes de salvar.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

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
        'status_emoji': _statusEmoji,
        'status_text': _statusText,
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
    } catch (e, stack) {
      // Log detalhado para facilitar debug — visível no flutter run / logcat
      debugPrint('[EditProfileScreen._saveProfile] ERRO ao salvar perfil:');
      debugPrint('  erro: $e');
      debugPrint('  stack: $stack');
      if (mounted) {
        final errStr = e.toString();
        final isDuplicate = errStr.contains('duplicate') ||
            errStr.contains('unique') ||
            errStr.contains('23505');
        final isColumnMissing = errStr.contains('column') &&
            errStr.contains('does not exist');
        final isPermission = errStr.contains('permission denied') ||
            errStr.contains('42501');
        String message;
        if (isDuplicate) {
          message = s.aminoIdInUse;
        } else if (isColumnMissing) {
          // Coluna faltando no banco — erro de migration
          message = 'Erro de configuração do servidor. Contate o suporte.';
          debugPrint('[EditProfileScreen] ATENÇÃO: coluna faltando no banco — verifique as migrations: $errStr');
        } else if (isPermission) {
          message = 'Sem permissão para atualizar o perfil.';
        } else {
          message = s.tryAgainGeneric;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Upload de avatar: faz upload, salva no banco e atualiza o authProvider imediatamente.
  /// Garante propagação em tempo real para todos os widgets via currentUserAvatarProvider.
  Future<void> _pickAndUploadAvatar() async {
    final s = getStrings();
    setState(() => _isUploadingAvatar = true);
    try {
      final url = await MediaUploadService.uploadAvatar(context: context, );
      if (url != null && mounted) {
        // 1. Atualizar estado local da tela
        setState(() => _avatarUrl = url);
        // 2. Salvar imediatamente no banco (sem esperar o botão Salvar)
        final userId = SupabaseService.currentUserId;
        if (userId != null) {
          await SupabaseService.table('profiles')
              .update({'icon_url': url})
              .eq('id', userId);
        }
        // 3. Atualizar o authProvider → currentUserAvatarProvider propaga em tempo real
        final currentUser = ref.read(currentUserProvider);
        if (currentUser != null && mounted) {
          ref.read(authProvider.notifier).updateUserProfile(
            currentUser.copyWith(iconUrl: url),
          );
          // Marcar como já salvo para que _saveProfile não inclua icon_url novamente
          _originalAvatarUrl = url;
        }
      }
    } catch (e, stack) {
      debugPrint('[EditProfileScreen._pickAndUploadAvatar] ERRO ao fazer upload do avatar:');
      debugPrint('  erro: $e');
      debugPrint('  stack: $stack');
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

    return PopScope(
      canPop: !_hasUnsavedChanges || _isLoading,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: context.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
            title: Text(
              'Descartar alterações?',
              style: TextStyle(
                color: context.nexusTheme.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: Text(
              'Suas alterações não foram salvas. Deseja descartá-las?',
              style: TextStyle(color: context.nexusTheme.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Continuar editando',
                    style: TextStyle(color: context.nexusTheme.accentPrimary)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Descartar',
                    style: TextStyle(color: context.nexusTheme.error)),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
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
            onPressed: (_isLoading || _isUploadingAvatar) ? null : _saveProfile,
            child: (_isLoading || _isUploadingAvatar)
                ? SizedBox(
                    width: r.s(20),
                    height: r.s(20),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(context.nexusTheme.accentPrimary),
                    ),
                  )
                : Text(
                    s.save,
                    style: TextStyle(
                      color: context.nexusTheme.accentPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(r.s(20)),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar — FIX Bug #5: GestureDetector com upload
                Center(
                  child: GestureDetector(
                    onTap: (_isUploadingAvatar || _isLoading)
                        ? null
                        : _pickAndUploadAvatar,
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
                              gradient: LinearGradient(
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
                            child: CircularProgressIndicator(
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
                // Status / Mood
                _buildStatusField(r),
                SizedBox(height: r.s(16)),
                // Interesses
                _buildInterestsField(r),
                SizedBox(height: r.s(16)),
                // Rich Bio Editor
                _buildRichBioEditor(r),
              ],
            ),
          ),
        ),
      ), // body: SafeArea
    ), // child: Scaffold
    ); // PopScope
  }
  Widget _buildStatusField(Responsive r) {
    final hasStatus = (_statusEmoji?.isNotEmpty == true) || (_statusText?.isNotEmpty == true);
    return GestureDetector(
      onTap: () async {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => EditStatusSheet(
            currentEmoji: _statusEmoji,
            currentText: _statusText,
            onSaved: (emoji, text) {
              setState(() {
                _statusEmoji = emoji;
                _statusText = text;
              });
            },
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(r.s(16)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(14)),
        child: Row(
          children: [
            Icon(
              Icons.mood_rounded,
              color: context.nexusTheme.accentPrimary,
              size: r.s(22),
            ),
            SizedBox(width: r.s(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status / Mood',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: r.fs(12),
                    ),
                  ),
                  SizedBox(height: r.s(4)),
                  if (hasStatus)
                    UserStatusBadge(
                      emoji: _statusEmoji,
                      text: _statusText,
                      compact: false,
                    )
                  else
                    Text(
                      'Toque para definir seu status',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: r.fs(14),
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[600],
              size: r.s(20),
            ),
          ],
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
  Widget _buildInterestsField(Responsive r) {
    final theme = context.nexusTheme;
    final user = ref.watch(currentUserProvider);
    final interests = user?.selectedInterests ?? [];
    return GestureDetector(
      onTap: () => context.push('/edit-interests'),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: r.s(16), vertical: r.s(14)),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(r.s(16)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Icon(Icons.interests_rounded,
                color: theme.accentPrimary, size: r.s(20)),
            SizedBox(width: r.s(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Interesses',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: r.fs(12),
                    ),
                  ),
                  SizedBox(height: r.s(4)),
                  if (interests.isEmpty)
                    Text(
                      'Nenhum interesse selecionado',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: r.fs(13),
                      ),
                    )
                  else
                    Wrap(
                      spacing: r.s(4),
                      runSpacing: r.s(4),
                      children: interests
                          .take(5)
                          .map((i) => Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: r.s(8), vertical: r.s(2)),
                                decoration: BoxDecoration(
                                  color: theme.accentPrimary
                                      .withValues(alpha: 0.15),
                                  borderRadius:
                                      BorderRadius.circular(r.s(20)),
                                ),
                                child: Text(
                                  i,
                                  style: TextStyle(
                                    color: theme.accentPrimary,
                                    fontSize: r.fs(11),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  if (interests.length > 5)
                    Padding(
                      padding: EdgeInsets.only(top: r.s(4)),
                      child: Text(
                        '+${interests.length - 5} mais',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: r.fs(11),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: theme.textSecondary, size: r.s(20)),
          ],
        ),
      ),
    );
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
