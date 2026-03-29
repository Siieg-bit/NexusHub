import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Guidelines salvas com sucesso!'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
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
    final title = section['title'] as String;
    final template = section['template'] as String;
    final newText =
        '$current${current.isEmpty ? '' : '\n\n'}## $title\n\n$template';
    _guidelinesController.text = newText;
    _guidelinesController.selection =
        TextSelection.collapsed(offset: newText.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
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
                margin: const EdgeInsets.only(right: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.accentColor],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Salvar',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
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
    return Column(
      children: [
        // Templates rápidos
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _templateSections.length,
            itemBuilder: (context, index) {
              final section = _templateSections[index];
              return GestureDetector(
                onTap: () => _insertTemplate(section),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
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
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        section['title'] as String,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 12,
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
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(16),
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
                fontSize: 14,
                height: 1.6,
              ),
              decoration: InputDecoration(
                hintText:
                    'Escreva as guidelines da sua comunidade aqui...\n\nUse ## para títulos de seção\nUse • ou - para listas\nUse ** para negrito',
                hintStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  height: 1.6,
                ),
                contentPadding: const EdgeInsets.all(16),
                border: InputBorder.none,
              ),
            ),
          ),
        ),

        // Contagem de caracteres
        Padding(
          padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_guidelinesController.text.length} caracteres',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
              Text(
                'Suporta formatação Markdown',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
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
    final text = _guidelinesController.text;
    if (text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_rounded, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'Nenhum conteúdo para visualizar',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Escreva as guidelines na aba Editor',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    // Renderizar preview simples com formatação básica
    final lines = text.split('\n');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final line = lines[index];

        // Título ##
        if (line.startsWith('## ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              line.substring(3),
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        }

        // Título #
        if (line.startsWith('# ')) {
          return Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 10),
            child: Text(
              line.substring(2),
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 22,
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
            padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 7, right: 10),
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
                      fontSize: 14,
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
              padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      match.group(1)!,
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      match.group(2)!,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 14,
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
          return const SizedBox(height: 8);
        }

        // Texto normal
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            line,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        );
      },
    );
  }
}
