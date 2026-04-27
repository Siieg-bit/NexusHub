import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/widgets/rgb_color_picker.dart';
import '../../../core/utils/media_utils.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import 'package:amino_clone/core/widgets/nexus_media_picker.dart';

/// Widget para editar visuais de uma comunidade
/// Inclui: capa, cores de tema, posição da capa, etc.

class CommunityVisualEditor extends ConsumerStatefulWidget {
  final String communityId;
  final String? initialCoverUrl;
  final String? initialPrimaryColor;
  final String? initialAccentColor;
  final String? initialSecondaryColor;
  final String? initialCoverPosition;
  final bool? initialCoverBlur;
  final double? initialCoverOpacity;
  final VoidCallback? onSaved;

  const CommunityVisualEditor({
    super.key,
    required this.communityId,
    this.initialCoverUrl,
    this.initialPrimaryColor,
    this.initialAccentColor,
    this.initialSecondaryColor,
    this.initialCoverPosition,
    this.initialCoverBlur,
    this.initialCoverOpacity,
    this.onSaved,
  });

  @override
  ConsumerState<CommunityVisualEditor> createState() => _CommunityVisualEditorState();
}

class _CommunityVisualEditorState extends ConsumerState<CommunityVisualEditor> {
  late String _coverUrl;
  late String _primaryColor;
  late String _accentColor;
  late String _secondaryColor;
  late String _coverPosition;
  late bool _coverBlur;
  late double _coverOpacity;
  bool _isSaving = false;
  bool _isUploadingCover = false;

  @override
  void initState() {
    super.initState();
    _coverUrl = widget.initialCoverUrl ?? '';
    _primaryColor = widget.initialPrimaryColor ?? '#0B0B0B';
    _accentColor = widget.initialAccentColor ?? '#FF6B6B';
    _secondaryColor = widget.initialSecondaryColor ?? '#4ECDC4';
    _coverPosition = widget.initialCoverPosition ?? 'center';
    _coverBlur = widget.initialCoverBlur ?? false;
    _coverOpacity = widget.initialCoverOpacity ?? 0.3;
  }

  Future<void> _pickCoverImage() async {
    final s = ref.read(stringsProvider);
    final _pickedFiles_image = await showNexusMediaPicker(
  context,
  maxSelect: 1,
  mode: NexusPickerMode.imageOnly,
);
if (_pickedFiles_image.isEmpty) return;
final image = _pickedFiles_image.first.file;
    if (image == null || !mounted) return;

    setState(() => _isUploadingCover = true);

    try {
      final userId = SupabaseService.currentUserId ?? 'unknown';
      final rawBytes = await image.readAsBytes();
      final bytes = await MediaUtils.compressImage(rawBytes);
      final path = 'community-covers/$userId/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      
      await SupabaseService.storage
          .from('post-media')
          .uploadBinary(path, bytes);
      
      final url = SupabaseService.storage.from('post-media').getPublicUrl(path);
      
      if (mounted) {
        setState(() => _coverUrl = url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorUploadTryAgain),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingCover = false);
      }
    }
  }

  Future<void> _saveVisuals() async {
    final s = ref.read(stringsProvider);
    
    setState(() => _isSaving = true);

    try {
      final result = await SupabaseService.rpc(
        'update_community_visuals',
        params: {
          'p_community_id': widget.communityId,
          'p_cover_image_url': _coverUrl.isNotEmpty ? _coverUrl : null,
          'p_theme_primary_color': _primaryColor,
          'p_theme_accent_color': _accentColor,
          'p_theme_secondary_color': _secondaryColor,
          'p_cover_position': _coverPosition,
          'p_cover_blur': _coverBlur,
          'p_cover_overlay_opacity': _coverOpacity,
        },
      );

      if (result is Map<String, dynamic> && result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(s.success),
              backgroundColor: context.nexusTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          widget.onSaved?.call();
        }
      } else {
        throw Exception(result is Map ? result['message'] ?? 'Erro ao salvar' : 'Erro ao salvar');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorSavingTryAgain),
            backgroundColor: context.nexusTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final s = ref.read(stringsProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.all(r.s(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── CAPA ──
          Text(
            'Capa da Comunidade',
            style: TextStyle(
              color: context.nexusTheme.textPrimary,
              fontSize: r.fs(16),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: r.s(12)),
          
          // Preview da capa
          if (_coverUrl.isNotEmpty)
            Container(
              width: double.infinity,
              height: r.s(180),
              margin: EdgeInsets.only(bottom: r.s(12)),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(r.s(12)),
                image: DecorationImage(
                  image: NetworkImage(_coverUrl),
                  fit: BoxFit.cover,
                ),
              ),
              child: _coverBlur
                  ? BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        color: Colors.black.withValues(alpha: _coverOpacity),
                      ),
                    )
                  : Container(
                      color: Colors.black.withValues(alpha: _coverOpacity),
                    ),
            ),

          // Botão para escolher capa
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isUploadingCover ? null : _pickCoverImage,
              icon: _isUploadingCover
                  ? SizedBox(
                      width: r.s(18),
                      height: r.s(18),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Icon(Icons.image_rounded),
              label: Text(_coverUrl.isEmpty ? 'Escolher Capa' : 'Mudar Capa'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.nexusTheme.accentPrimary,
                padding: EdgeInsets.symmetric(vertical: r.s(12)),
              ),
            ),
          ),

          SizedBox(height: r.s(24)),

          // ── POSIÇÃO DA CAPA ──
          Text(
            'Posição da Capa',
            style: TextStyle(
              color: context.nexusTheme.textPrimary,
              fontSize: r.fs(14),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: r.s(8)),
          Row(
            children: ['center', 'top', 'bottom'].map((pos) {
              final isSelected = _coverPosition == pos;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _coverPosition = pos),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: r.s(10)),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.nexusTheme.accentPrimary
                          : context.nexusTheme.surfacePrimary,
                      borderRadius: BorderRadius.circular(r.s(8)),
                      border: Border.all(
                        color: isSelected
                            ? context.nexusTheme.accentPrimary
                            : context.nexusTheme.accentSecondary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      pos.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Colors.white : context.nexusTheme.textPrimary,
                        fontSize: r.fs(12),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          SizedBox(height: r.s(20)),

          // ── EFEITOS DA CAPA ──
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Desfoque',
                      style: TextStyle(
                        color: context.nexusTheme.textPrimary,
                        fontSize: r.fs(12),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: r.s(8)),
                    Switch(
                      value: _coverBlur,
                      onChanged: (val) => setState(() => _coverBlur = val),
                      activeColor: context.nexusTheme.accentPrimary,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Opacidade: ${(_coverOpacity * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: context.nexusTheme.textPrimary,
                        fontSize: r.fs(12),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: r.s(8)),
                    Slider(
                      value: _coverOpacity,
                      onChanged: (val) => setState(() => _coverOpacity = val),
                      min: 0,
                      max: 1,
                      activeColor: context.nexusTheme.accentPrimary,
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: r.s(24)),

          // ── CORES DO TEMA ──
          Text(
            'Cores do Tema',
            style: TextStyle(
              color: context.nexusTheme.textPrimary,
              fontSize: r.fs(16),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: r.s(12)),

          // Cor Primária
          _buildColorPicker(
            label: 'Cor Primária',
            color: _primaryColor,
            onChanged: (color) => setState(() => _primaryColor = color),
            r: r,
          ),

          SizedBox(height: r.s(16)),

          // Cor de Destaque
          _buildColorPicker(
            label: 'Cor de Destaque',
            color: _accentColor,
            onChanged: (color) => setState(() => _accentColor = color),
            r: r,
          ),

          SizedBox(height: r.s(16)),

          // Cor Secundária
          _buildColorPicker(
            label: 'Cor Secundária',
            color: _secondaryColor,
            onChanged: (color) => setState(() => _secondaryColor = color),
            r: r,
          ),

          SizedBox(height: r.s(24)),

          // ── BOTÃO SALVAR ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveVisuals,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.nexusTheme.accentPrimary,
                disabledBackgroundColor: context.nexusTheme.accentPrimary.withValues(alpha: 0.5),
                padding: EdgeInsets.symmetric(vertical: r.s(14)),
              ),
              child: _isSaving
                  ? SizedBox(
                      height: r.s(20),
                      width: r.s(20),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(
                      s.save,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: r.fs(14),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPicker({
    required String label,
    required String color,
    required Function(String) onChanged,
    required Responsive r,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.nexusTheme.textPrimary,
            fontSize: r.fs(12),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: r.s(8)),
        Row(
          children: [
            GestureDetector(
              onTap: () async {
                final initialColorValue = Color(
                  int.parse(color.replaceFirst('#', '0xff')),
                );
                final pickedColor = await showRGBColorPicker(
                  context,
                  initialColor: initialColorValue,
                  title: label,
                );
                if (pickedColor != null) {
                  final hexColor = '#${pickedColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
                  onChanged(hexColor);
                }
              },
              child: Container(
                width: r.s(50),
                height: r.s(50),
                decoration: BoxDecoration(
                  color: Color(int.parse(color.replaceFirst('#', '0xff'))),
                  borderRadius: BorderRadius.circular(r.s(8)),
                  border: Border.all(
                    color: context.nexusTheme.accentSecondary.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            SizedBox(width: r.s(12)),
            Expanded(
              child: TextField(
                controller: TextEditingController(text: color),
                onChanged: (val) {
                  if (val.startsWith('#') && val.length == 7) {
                    onChanged(val);
                  }
                },
                style: TextStyle(
                  color: context.nexusTheme.textPrimary,
                  fontSize: r.fs(13),
                ),
                decoration: InputDecoration(
                  hintText: '#RRGGBB',
                  hintStyle: TextStyle(
                    color: context.nexusTheme.textPrimary.withValues(alpha: 0.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(r.s(8)),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: r.s(12),
                    vertical: r.s(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
