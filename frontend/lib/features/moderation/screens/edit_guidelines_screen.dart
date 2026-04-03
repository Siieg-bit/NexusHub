import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

/// Tela para Leaders/Curators editarem as guidelines da comunidade.
/// Réplica fiel do Amino Apps — editor de texto rico com preview.
class EditGuidelinesScreen extends StatefulWidget {
  final String communityId;
  final String? currentGuidelines;

  const EditGuidelinesScreen({
    super.key,
    required this.communityId,
    this.currentGuidelines,
  });

  @override
  State<EditGuidelinesScreen> createState() => _EditGuidelinesScreenState();
}

class _EditGuidelinesScreenState extends State<EditGuidelinesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _guidelinesController;
  bool _isSaving = false;
  bool _hasChanges = false;

  // Seções pré-definidas do Amino
  static const _templateSections = [
    {
      'title': 'Regras Gerais',
      'icon': Icons.gavel_rounded,
      'template':
          '1. Seja respeitoso com todos os membros\n2. Não faça spam ou flood\n3. Mantenha o conteúdo relevante à comunidade\n4. Não compartilhe informações pessoais',
    },
    {
      'title': 'Conteúdo Permitido',
      'icon': Icons.check_circle_rounded,
      'template':
          '• Posts relacionados ao tema da comunidade\n• Fan arts e criações originais\n• Discussões construtivas\n• Memes relacionados ao tema',
    },
    {
      'title': 'Conteúdo Proibido',
      'icon': Icons.block_rounded,
      'template':
          '• NSFW / Conteúdo explícito\n• Bullying ou assédio\n• Roubo de arte (art theft)\n• Propaganda não autorizada\n• Conteúdo discriminatório',
    },
    {
      'title': 'Sistema de Strikes',
      'icon': Icons.warning_rounded,
      'template':
          '• 1º Strike: Aviso formal\n• 2º Strike: Silenciamento temporário (24h)\n• 3º Strike: Ban permanente da comunidade',
    },
    {
      'title': 'Cargos e Responsabilidades',
      'icon': Icons.people_rounded,
      'template':
          '• Leader: Gerencia a comunidade e modera conteúdo\n• Curator: Auxilia na moderação e curadoria de wikis\n• Member: Participa ativamente da comunidade',
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
                Text('Guidelines salvas com sucesso!'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
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
            content: Text('Erro ao salvar. Tente novamente.'),
            backgroundColor: AppTheme.errorColor,
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
    final r = context.r;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Editar Guidelines',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: context.textPrimary,
          ),
        ),
        iconTheme: IconThemeData(color: context.textPrimary),
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
                    colors: [AppTheme.primaryColor, AppTheme.accentColor],
                  ),
                  borderRadius: BorderRadius.circular(r.s(20)),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
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
                        'Salvar',
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
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: AppTheme.primaryColor,
          dividerColor: Colors.white.withValues(alpha: 0.05),
          tabs: const [
            Tab(text: 'Editor'),
            Tab(text: 'Preview'),
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
            itemCount: _templateSections.length,
            itemBuilder: (context, index) {
              final section = _templateSections[index];
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
                        color: AppTheme.primaryColor,
                        size: r.s(14),
                      ),
                      SizedBox(width: r.s(6)),
                      Text(
                        section['title'] as String? ?? '',
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
                color: context.textPrimary,
                fontSize: r.fs(14),
                height: 1.6,
              ),
              decoration: InputDecoration(
                hintText:
                    'Escreva as guidelines da sua comunidade aqui...\n\nUse ## para títulos de seção\nUse • ou - para listas\nUse ** para negrito',
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
                'Suporta formatação Markdown',
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
              'Nenhum conteúdo para visualizar',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: r.fs(16),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: r.s(8)),
            Text(
              'Escreva as guidelines na aba Editor',
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
                color: AppTheme.primaryColor,
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
                color: context.textPrimary,
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
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    line.substring(2),
                    style: TextStyle(
                      color: context.textPrimary,
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
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      match.group(1)!,
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: r.fs(11),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      match.group(2)!,
                      style: TextStyle(
                        color: context.textPrimary,
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
              color: context.textPrimary,
              fontSize: r.fs(14),
              height: 1.5,
            ),
          ),
        );
      },
    );
  }
}
