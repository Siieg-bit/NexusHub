import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/l10n/app_strings.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Tela para Leaders/Curators editarem as guidelines da comunidade.
/// Réplica fiel do Amino Apps — editor de texto rico com preview.
class EditGuidelinesScreen extends ConsumerStatefulWidget {
  final String communityId;
  final String? currentGuidelines;

  const EditGuidelinesScreen({
    super.key,
    required this.communityId,
    this.currentGuidelines,
  });

  @override
  ConsumerState<EditGuidelinesScreen> createState() => _EditGuidelinesScreenState();
}

class _EditGuidelinesScreenState extends ConsumerState<EditGuidelinesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _guidelinesController;
  bool _isSaving = false;
  bool _hasChanges = false;

  // Seções pré-definidas do Amino
  static List<Map<String, dynamic>> _templateSections(AppStrings s) => [
    {
      'title': s.generalRules,
      'icon': Icons.gavel_rounded,
      'template':
          s.defaultGuidelines,
    },
    {
      'title': s.allowedContent,
      'icon': Icons.check_circle_rounded,
      'template':
          s.defaultAllowedContent,
    },
    {
      'title': s.prohibitedContent,
      'icon': Icons.block_rounded,
      'template':
          s.defaultProhibitedContent,
    },
    {
      'title': s.strikeSystem,
      'icon': Icons.warning_rounded,
      'template':
          s.defaultStrikePolicy,
    },
    {
      'title': s.rolesResponsibilities,
      'icon': Icons.people_rounded,
      'template':
          s.defaultRoles,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _guidelinesController =
        TextEditingController(text: widget.currentGuidelines ?? '');
    _guidelinesController.addListener(() {
      if (!_hasChanges && mounted) {
        setState(() => _hasChanges = true);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _guidelinesController.dispose();
    super.dispose();
  }

  Future<void> _saveGuidelines() async {
    final s = getStrings();
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await SupabaseService.table('communities')
          .update({'guidelines': _guidelinesController.text.trim()}).eq(
              'id', widget.communityId);

      if (mounted) {
        final r = context.r;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: r.s(18)),
                SizedBox(width: r.s(8)),
                Text(s.guidelinesSaved),
              ],
            ),
            backgroundColor: context.nexusTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.s(12))),
          ),
        );
        Navigator.pop(context, true);
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _insertTemplate(Map<String, dynamic> section) {
    final current = _guidelinesController.text;
    final title = section['title'] as String?;
    final template = section['template'] as String?;
    final newText =
        '$current${current.isEmpty ? '' : '\n\n'}## $title\n\n$template';
    _guidelinesController.text = newText;
    _guidelinesController.selection =
        TextSelection.collapsed(offset: newText.length);
  }

  @override
  Widget build(BuildContext context) {
      final s = ref.watch(stringsProvider);
    final r = context.r;
    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          s.editGuidelines2,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: context.nexusTheme.textPrimary,
          ),
        ),
        iconTheme: IconThemeData(color: context.nexusTheme.textPrimary),
        actions: [
          if (_hasChanges)
            GestureDetector(
              onTap: _isSaving ? null : _saveGuidelines,
              child: Container(
                margin: EdgeInsets.only(right: r.s(16)),
                padding:
                    EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [context.nexusTheme.accentPrimary, context.nexusTheme.accentSecondary],
                  ),
                  borderRadius: BorderRadius.circular(r.s(20)),
                  boxShadow: [
                    BoxShadow(
                      color: context.nexusTheme.accentPrimary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _isSaving
                    ? SizedBox(
                        width: r.s(16),
                        height: r.s(16),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
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
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: context.nexusTheme.accentPrimary,
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: context.nexusTheme.accentPrimary,
          dividerColor: Colors.white.withValues(alpha: 0.05),
          tabs: [
            Tab(text: s.editor),
            Tab(text: s.preview2),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEditorTab(),
          _buildPreviewTab(),
        ],
      ),
    );
  }

  Widget _buildEditorTab() {
    final s = getStrings();
    final r = context.r;
    return Column(
      children: [
        // Templates rápidos
        Container(
          height: r.s(50),
          padding: EdgeInsets.symmetric(vertical: r.s(8)),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: r.s(16)),
            itemCount: _templateSections(s).length,
            itemBuilder: (context, index) {
              final section = _templateSections(s)[index];
              return GestureDetector(
                onTap: () => _insertTemplate(section),
                child: Container(
                  margin: EdgeInsets.only(right: r.s(8)),
                  padding: EdgeInsets.symmetric(
                      horizontal: r.s(12), vertical: r.s(6)),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(r.s(20)),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        section['icon'] as IconData,
                        color: context.nexusTheme.accentPrimary,
                        size: r.s(14),
                      ),
                      SizedBox(width: r.s(6)),
                      Text(
                        section['title'] as String? ?? '',
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
            },
          ),
        ),

        // Editor de texto
        Expanded(
          child: Container(
            margin: EdgeInsets.all(r.s(16)),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(r.s(16)),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: TextField(
              controller: _guidelinesController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(
                color: context.nexusTheme.textPrimary,
                fontSize: r.fs(14),
                height: 1.6,
              ),
              decoration: InputDecoration(
                hintText:
                    s.guidelinesEditorHint,
                hintStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: r.fs(14),
                  height: 1.6,
                ),
                contentPadding: EdgeInsets.all(r.s(16)),
                border: InputBorder.none,
              ),
            ),
          ),
        ),

        // Contagem de caracteres
        Padding(
          padding:
              EdgeInsets.only(bottom: r.s(16), left: r.s(16), right: r.s(16)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_guidelinesController.text.length} caracteres',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: r.fs(12),
                ),
              ),
              Text(
                s.supportsMarkdown,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: r.fs(11),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewTab() {
    final s = getStrings();
    final r = context.r;
    final text = _guidelinesController.text;
    if (text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_rounded,
                size: r.s(64), color: Colors.grey[600]),
            SizedBox(height: r.s(16)),
            Text(
              s.noContentToDisplay,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: r.fs(16),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: r.s(8)),
            Text(
              s.writeGuidelinesTab,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: r.fs(13),
              ),
            ),
          ],
        ),
      );
    }

    // Renderizar preview simples com formatação básica
    final lines = text.split('\n');
    return ListView.builder(
      padding: EdgeInsets.all(r.s(16)),
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final line = lines[index];

        // Título ##
        if (line.startsWith('## ')) {
          return Padding(
            padding: EdgeInsets.only(top: r.s(16), bottom: r.s(8)),
            child: Text(
              line.substring(3),
              style: TextStyle(
                color: context.nexusTheme.accentPrimary,
                fontSize: r.fs(18),
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        }

        // Título #
        if (line.startsWith('# ')) {
          return Padding(
            padding: EdgeInsets.only(top: r.s(20), bottom: r.s(10)),
            child: Text(
              line.substring(2),
              style: TextStyle(
                color: context.nexusTheme.textPrimary,
                fontSize: r.fs(22),
                fontWeight: FontWeight.w900,
              ),
            ),
          );
        }

        // Lista com bullet
        if (line.startsWith('• ') ||
            line.startsWith('- ') ||
            line.startsWith('* ')) {
          return Padding(
            padding: EdgeInsets.only(left: r.s(8), top: r.s(4), bottom: r.s(4)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: r.s(6),
                  height: r.s(6),
                  margin: EdgeInsets.only(top: r.s(7), right: r.s(10)),
                  decoration: const BoxDecoration(
                    color: context.nexusTheme.accentPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    line.substring(2),
                    style: TextStyle(
                      color: context.nexusTheme.textPrimary,
                      fontSize: r.fs(14),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Lista numerada
        if (RegExp(r'^\d+\.\s').hasMatch(line)) {
          final match = RegExp(r'^(\d+)\.\s(.*)').firstMatch(line);
          if (match != null) {
            return Padding(
              padding:
                  EdgeInsets.only(left: r.s(8), top: r.s(4), bottom: r.s(4)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: r.s(22),
                    height: r.s(22),
                    margin: EdgeInsets.only(right: r.s(8)),
                    decoration: BoxDecoration(
                      color: context.nexusTheme.accentPrimary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      match.group(1)!,
                      style: TextStyle(
                        color: context.nexusTheme.accentPrimary,
                        fontSize: r.fs(11),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      match.group(2)!,
                      style: TextStyle(
                        color: context.nexusTheme.textPrimary,
                        fontSize: r.fs(14),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        }

        // Linha vazia
        if (line.trim().isEmpty) {
          return SizedBox(height: r.s(8));
        }

        // Texto normal
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            line,
            style: TextStyle(
              color: context.nexusTheme.textPrimary,
              fontSize: r.fs(14),
              height: 1.5,
            ),
          ),
        );
      },
    );
  }
}
