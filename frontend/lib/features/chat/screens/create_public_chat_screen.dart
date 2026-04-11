import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';

// =============================================================================
// CREATE PUBLIC CHAT SCREEN — Personalização Avançada
// Foto de capa, ícone, modo lento, anúncios, voz/vídeo/sala de projeção.
// =============================================================================

class CreatePublicChatScreen extends ConsumerStatefulWidget {
  final String communityId;
  final String communityName;

  const CreatePublicChatScreen({
    super.key,
    required this.communityId,
    required this.communityName,
  });

  @override
  ConsumerState<CreatePublicChatScreen> createState() =>
      _CreatePublicChatScreenState();
}

class _CreatePublicChatScreenState
    extends ConsumerState<CreatePublicChatScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Mídia
  File? _coverImageFile;
  File? _iconImageFile;
  String? _coverImageUrl;
  String? _iconImageUrl;
  bool _isUploadingCover = false;
  bool _isUploadingIcon = false;

  // Configurações
  bool _isAnnouncementOnly = false;
  bool _isVoiceEnabled = true;
  bool _isVideoEnabled = false;
  bool _isScreenRoomEnabled = false;
  int _slowModeInterval = 0; // 0 = desativado
  String _category = 'general';

  bool _isCreating = false;

  static const List<Map<String, dynamic>> _slowModeOptions = [
    {'label': 'Off', 'value': 0},
    {'label': '5s', 'value': 5},
    {'label': '10s', 'value': 10},
    {'label': '30s', 'value': 30},
    {'label': '1min', 'value': 60},
    {'label': '5min', 'value': 300},
  ];

  static const List<String> _categories = [
    'general',
    'gaming',
    'anime',
    'music',
    'art',
    'sports',
    'tech',
    'movies',
    'books',
    'other',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ─── Upload de imagens ────────────────────────────────────────────────────

  Future<void> _pickCoverImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 400,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _coverImageFile = File(picked.path);
        _isUploadingCover = true;
      });
      final bytes = await _coverImageFile!.readAsBytes();
      final fileName =
          'chat_covers/${DateTime.now().millisecondsSinceEpoch}_cover.jpg';
      await SupabaseService.client.storage
          .from('chat-media')
          .uploadBinary(fileName, bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'));
      final url = SupabaseService.client.storage
          .from('chat-media')
          .getPublicUrl(fileName);
      if (mounted) setState(() => _coverImageUrl = url);
    } catch (e) {
      debugPrint('[create_public_chat] cover upload error: $e');
    } finally {
      if (mounted) setState(() => _isUploadingCover = false);
    }
  }

  Future<void> _pickIconImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _iconImageFile = File(picked.path);
        _isUploadingIcon = true;
      });
      final bytes = await _iconImageFile!.readAsBytes();
      final fileName =
          'chat_icons/${DateTime.now().millisecondsSinceEpoch}_icon.jpg';
      await SupabaseService.client.storage
          .from('chat-media')
          .uploadBinary(fileName, bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'));
      final url = SupabaseService.client.storage
          .from('chat-media')
          .getPublicUrl(fileName);
      if (mounted) setState(() => _iconImageUrl = url);
    } catch (e) {
      debugPrint('[create_public_chat] icon upload error: $e');
    } finally {
      if (mounted) setState(() => _isUploadingIcon = false);
    }
  }

  // ─── Criar chat ───────────────────────────────────────────────────────────

  Future<void> _createChat() async {
    final s = getStrings();
    if (!_formKey.currentState!.validate()) return;
    if (_isUploadingCover || _isUploadingIcon) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Aguarde o upload das imagens...'),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);
    try {
      final result = await SupabaseService.rpc(
        'create_public_chat',
        params: {
          'p_community_id': widget.communityId,
          'p_title': _titleController.text.trim(),
          'p_description': _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          'p_icon_url': _iconImageUrl,
          'p_cover_image_url': _coverImageUrl,
          'p_category': _category,
          'p_slow_mode_interval': _slowModeInterval,
          'p_is_announcement_only': _isAnnouncementOnly,
          'p_is_voice_enabled': _isVoiceEnabled,
          'p_is_video_enabled': _isVideoEnabled,
          'p_is_screen_room_enabled': _isScreenRoomEnabled,
        },
      );

      final map = Map<String, dynamic>.from(result as Map);
      if (map['success'] == true) {
        final threadId = map['thread_id'] as String;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(s.chatCreatedSuccess),
              backgroundColor: AppTheme.primaryColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.go('/chat/$threadId');
        }
      } else {
        final error = map['error'] as String? ?? 'unknown';
        final message = switch (error) {
          'unauthenticated' => s.needToBeLoggedIn,
          'title_required' => s.chatNameRequired,
          'not_a_member' => s.mustBeCommunityMember,
          _ => s.errorCreatingChat,
        };
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[create_public_chat] Erro: $e');
      if (mounted) {
        final errStr = e.toString();
        String userMsg = s.errorCreatingChat;
        if (errStr.contains('not_a_member')) userMsg = s.mustBeCommunityMember;
        else if (errStr.contains('unauthenticated')) userMsg = s.needToBeLoggedIn;
        else if (errStr.contains('title_required')) userMsg = s.chatNameRequired;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMsg),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  // ─── Widgets auxiliares ───────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, {EdgeInsets? padding}) {
    final r = context.r;
    return Padding(
      padding: padding ?? EdgeInsets.only(bottom: r.s(8)),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: AppTheme.primaryColor,
          fontSize: r.fs(11),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? iconColor,
  }) {
    final r = context.r;
    return Container(
      margin: EdgeInsets.only(bottom: r.s(8)),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(r.s(12)),
      ),
      child: SwitchListTile(
        contentPadding:
            EdgeInsets.symmetric(horizontal: r.s(14), vertical: r.s(2)),
        secondary: Container(
          width: r.s(36),
          height: r.s(36),
          decoration: BoxDecoration(
            color: (iconColor ?? AppTheme.primaryColor).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(r.s(10)),
          ),
          child: Icon(icon,
              color: iconColor ?? AppTheme.primaryColor, size: r.s(18)),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: r.fs(14),
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: context.textPrimary.withValues(alpha: 0.55),
            fontSize: r.fs(11),
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primaryColor,
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          s.newPublicChat,
          style: TextStyle(
            fontSize: r.fs(17),
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: r.s(12)),
            child: TextButton(
              onPressed: _isCreating ? null : _createChat,
              child: _isCreating
                  ? SizedBox(
                      width: r.s(16),
                      height: r.s(16),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    )
                  : Text(
                      s.create,
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: r.fs(15),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(r.s(16)),
          children: [
            // ── Foto de Capa ──────────────────────────────────────────────
            _buildSectionHeader(s.coverPhoto),
            GestureDetector(
              onTap: _isUploadingCover ? null : _pickCoverImage,
              child: Container(
                height: r.s(160),
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(r.s(14)),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _isUploadingCover
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                                color: AppTheme.primaryColor),
                            SizedBox(height: r.s(8)),
                            Text('Enviando...',
                                style: TextStyle(
                                    color: context.textPrimary
                                        .withValues(alpha: 0.6),
                                    fontSize: r.fs(12))),
                          ],
                        ),
                      )
                    : _coverImageUrl != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: _coverImageUrl!,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                bottom: r.s(8),
                                right: r.s(8),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: r.s(10), vertical: r.s(5)),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius:
                                        BorderRadius.circular(r.s(20)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit_rounded,
                                          color: Colors.white, size: r.s(12)),
                                      SizedBox(width: r.s(4)),
                                      Text(s.tapToChangeCover,
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: r.fs(11))),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : _coverImageFile != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(_coverImageFile!,
                                      fit: BoxFit.cover),
                                  Positioned(
                                    bottom: r.s(8),
                                    right: r.s(8),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: r.s(10),
                                          vertical: r.s(5)),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.black.withValues(alpha: 0.6),
                                        borderRadius:
                                            BorderRadius.circular(r.s(20)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                              constraints: BoxConstraints(
                                                  maxWidth: r.s(12),
                                                  maxHeight: r.s(12))),
                                          SizedBox(width: r.s(6)),
                                          Text('Enviando...',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: r.fs(11))),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_rounded,
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.5),
                                    size: r.s(40),
                                  ),
                                  SizedBox(height: r.s(8)),
                                  Text(
                                    s.coverPhotoHint,
                                    style: TextStyle(
                                      color: context.textPrimary
                                          .withValues(alpha: 0.5),
                                      fontSize: r.fs(13),
                                    ),
                                  ),
                                ],
                              ),
              ),
            ),
            SizedBox(height: r.s(20)),

            // ── Ícone + Nome ──────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícone
                Column(
                  children: [
                    GestureDetector(
                      onTap: _isUploadingIcon ? null : _pickIconImage,
                      child: Container(
                        width: r.s(72),
                        height: r.s(72),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(r.s(18)),
                          border: Border.all(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _isUploadingIcon
                            ? Center(
                                child: CircularProgressIndicator(
                                    color: AppTheme.primaryColor,
                                    strokeWidth: 2),
                              )
                            : _iconImageUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: _iconImageUrl!,
                                    fit: BoxFit.cover,
                                  )
                                : _iconImageFile != null
                                    ? Image.file(_iconImageFile!,
                                        fit: BoxFit.cover)
                                    : Icon(
                                        Icons.camera_alt_rounded,
                                        color: AppTheme.primaryColor
                                            .withValues(alpha: 0.6),
                                        size: r.s(28),
                                      ),
                      ),
                    ),
                    SizedBox(height: r.s(4)),
                    Text(
                      s.chatIcon,
                      style: TextStyle(
                        color: context.textPrimary.withValues(alpha: 0.5),
                        fontSize: r.fs(10),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: r.s(14)),
                // Nome do chat
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.chatName2,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: r.fs(13),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: r.s(6)),
                      TextFormField(
                        controller: _titleController,
                        maxLength: 50,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: s.exampleChatName,
                          counterText: '',
                          filled: true,
                          fillColor: context.cardBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(r.s(12)),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(r.s(12)),
                            borderSide: BorderSide(
                                color: AppTheme.primaryColor, width: 1.5),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return s.chatNameIsRequired;
                          }
                          if (value.trim().length < 3) {
                            return s.nameMinLength2;
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: r.s(16)),

            // ── Descrição ─────────────────────────────────────────────────
            Text(
              s.descriptionOptional2,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: r.fs(13),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: r.s(8)),
            TextFormField(
              controller: _descriptionController,
              maxLength: 300,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: s.describeChatPurpose,
                counterText: '',
                filled: true,
                fillColor: context.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(12)),
                  borderSide:
                      BorderSide(color: AppTheme.primaryColor, width: 1.5),
                ),
              ),
            ),
            SizedBox(height: r.s(20)),

            // ── Categoria ─────────────────────────────────────────────────
            _buildSectionHeader(s.selectCategory),
            SizedBox(
              height: r.s(36),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => SizedBox(width: r.s(8)),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _category == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _category = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(14), vertical: r.s(6)),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : context.cardBg,
                        borderRadius: BorderRadius.circular(r.s(20)),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : context.textPrimary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Text(
                        cat[0].toUpperCase() + cat.substring(1),
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : context.textPrimary.withValues(alpha: 0.7),
                          fontSize: r.fs(12),
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: r.s(20)),

            // ── Modo Lento ────────────────────────────────────────────────
            _buildSectionHeader(s.chatSettings2),
            Container(
              padding: EdgeInsets.all(r.s(14)),
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(r.s(12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: r.s(36),
                        height: r.s(36),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(r.s(10)),
                        ),
                        child: Icon(Icons.timer_rounded,
                            color: Colors.orange, size: r.s(18)),
                      ),
                      SizedBox(width: r.s(12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.slowMode,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: r.fs(14),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              s.slowModeDesc,
                              style: TextStyle(
                                color:
                                    context.textPrimary.withValues(alpha: 0.55),
                                fontSize: r.fs(11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: r.s(12)),
                  Wrap(
                    spacing: r.s(8),
                    runSpacing: r.s(6),
                    children: _slowModeOptions.map((opt) {
                      final val = opt['value'] as int;
                      final label = opt['label'] as String;
                      final isSelected = _slowModeInterval == val;
                      return GestureDetector(
                        onTap: () => setState(() => _slowModeInterval = val),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(
                              horizontal: r.s(12), vertical: r.s(6)),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.orange
                                : Colors.orange.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(r.s(20)),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.orange
                                  : Colors.orange.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.orange,
                              fontSize: r.fs(12),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.s(8)),

            // ── Permissões ────────────────────────────────────────────────
            _buildSettingTile(
              icon: Icons.campaign_rounded,
              title: s.announcementOnlyMode,
              subtitle: s.announcementOnlyModeDesc,
              value: _isAnnouncementOnly,
              onChanged: (v) => setState(() => _isAnnouncementOnly = v),
              iconColor: Colors.deepPurple,
            ),
            SizedBox(height: r.s(12)),

            // ── Funcionalidades ───────────────────────────────────────────
            _buildSectionHeader(s.chatPermissions),
            _buildSettingTile(
              icon: Icons.mic_rounded,
              title: s.voiceChatEnabled,
              subtitle: s.voiceChatEnabledDesc,
              value: _isVoiceEnabled,
              onChanged: (v) => setState(() => _isVoiceEnabled = v),
              iconColor: Colors.green,
            ),
            _buildSettingTile(
              icon: Icons.videocam_rounded,
              title: s.videoChatEnabled,
              subtitle: s.videoChatEnabledDesc,
              value: _isVideoEnabled,
              onChanged: (v) => setState(() => _isVideoEnabled = v),
              iconColor: Colors.blue,
            ),
            _buildSettingTile(
              icon: Icons.movie_rounded,
              title: s.projectionRoomEnabled,
              subtitle: s.projectionRoomEnabledDesc,
              value: _isScreenRoomEnabled,
              onChanged: (v) => setState(() => _isScreenRoomEnabled = v),
              iconColor: Colors.red,
            ),
            SizedBox(height: r.s(20)),

            // ── Info ──────────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.all(r.s(12)),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(r.s(12)),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppTheme.primaryColor, size: r.s(16)),
                  SizedBox(width: r.s(8)),
                  Expanded(
                    child: Text(
                      '${s.publicChatsVisible}\n${s.anyMemberCanParticipate}',
                      style: TextStyle(
                        color: context.textPrimary.withValues(alpha: 0.7),
                        fontSize: r.fs(12),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.s(32)),

            // ── Botão criar ───────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createChat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: r.s(14)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.s(12)),
                  ),
                ),
                child: _isCreating
                    ? SizedBox(
                        width: r.s(20),
                        height: r.s(20),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        s.createPublicChat,
                        style: TextStyle(
                          fontSize: r.fs(15),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            SizedBox(height: r.s(20)),
          ],
        ),
      ),
    );
  }
}
