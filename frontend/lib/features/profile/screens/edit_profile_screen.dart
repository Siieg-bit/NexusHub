import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';

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

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nicknameController = TextEditingController(text: user?.nickname ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _aminoIdController = TextEditingController(text: user?.aminoId ?? '');
    _bioTabController = TabController(length: 2, vsync: this);
    _bioTabController.addListener(() {
      setState(() => _bioPreviewMode = _bioTabController.index == 1);
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    _aminoIdController.dispose();
    _bioTabController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if ((_formKey.currentState?.validate() != true)) return;

    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final aminoId = _aminoIdController.text.trim();
      await SupabaseService.table('profiles').update({
        'nickname': _nicknameController.text.trim(),
        'bio': _bioController.text.trim(),
        // amino_id tem UNIQUE constraint — enviar null se vazio para evitar violação
        'amino_id': aminoId.isEmpty ? null : aminoId,
      }).eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado com sucesso!')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
          content: Text('Erro ao salvar: ${e.toString().contains('duplicate') ? 'Esse Amino ID já está em uso.' : 'Tente novamente.'}'),
          backgroundColor: AppTheme.errorColor,
        ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Insere formatação Markdown no campo de bio.
  void _applyFormat(String prefix, String suffix, {String placeholder = 'texto'}) {
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
          offset: sel.isValid ? sel.start + replacement.length : newText.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
        title: Text(
          'Editar Perfil',
          style: TextStyle(
            color: context.textPrimary,
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
                          AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                  )
                : const Text(
                    'Salvar',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
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
              // Avatar
              Center(
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.2),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: context.surfaceColor,
                        child: Text(
                          (user?.nickname ?? '?')[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: r.fs(36),
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.all(r.s(8)),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryColor, AppTheme.accentColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.scaffoldBg,
                            width: r.s(3),
                          ),
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: r.s(18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.s(32)),

              // Nickname
              _buildTextField(
                controller: _nicknameController,
                label: 'Nickname',
                icon: Icons.person_outlined,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Obrigatório';
                  }
                  if (value.trim().length < 3) return 'Mínimo 3 caracteres';
                  return null;
                },
              ),
              SizedBox(height: r.s(16)),

              // Amino ID
              _buildTextField(
                controller: _aminoIdController,
                label: 'Amino ID',
                icon: Icons.alternate_email_rounded,
                hintText: 'Seu identificador único',
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
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(16)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com tabs Editar / Prévia
          Padding(
            padding: EdgeInsets.fromLTRB(r.s(16), r.s(12), r.s(8), 0),
            child: Row(
              children: [
                Icon(Icons.edit_note_rounded,
                    color: AppTheme.primaryColor, size: r.s(20)),
                SizedBox(width: r.s(8)),
                Text('Bio',
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: r.fs(14))),
                const Spacer(),
                TabBar(
                  controller: _bioTabController,
                  isScrollable: true,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: AppTheme.primaryColor,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: TextStyle(
                      fontSize: r.fs(12), fontWeight: FontWeight.w700),
                  tabs: const [
                    Tab(text: 'Editar'),
                    Tab(text: 'Prévia'),
                  ],
                ),
              ],
            ),
          ),

          // Toolbar de formatação (visível apenas no modo edição)
          if (!_bioPreviewMode)
            _buildFormatToolbar(r),

          // Área de edição ou prévia
          SizedBox(
            height: r.s(140),
            child: TabBarView(
              controller: _bioTabController,
              children: [
                // Aba Editar
                TextField(
                  controller: _bioController,
                  maxLines: null,
                  expands: true,
                  maxLength: 500,
                  style: TextStyle(
                      color: context.textPrimary, fontSize: r.fs(14)),
                  decoration: InputDecoration(
                    hintText:
                        'Escreva sua bio... Use **negrito**, *itálico*, ~~tachado~~',
                    hintStyle: TextStyle(
                        color: Colors.grey[600], fontSize: r.fs(13)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(r.s(12)),
                    counterStyle: TextStyle(
                        color: Colors.grey[600], fontSize: r.fs(11)),
                  ),
                ),
                // Aba Prévia
                SingleChildScrollView(
                  padding: EdgeInsets.all(r.s(12)),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _bioController,
                    builder: (context, value, _) {
                      final text = value.text.trim();
                      if (text.isEmpty) {
                        return Text(
                          'Nenhum conteúdo ainda...',
                          style: TextStyle(
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                              fontSize: r.fs(13)),
                        );
                      }
                      return MarkdownBody(
                        data: text,
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(
                              color: context.textPrimary,
                              fontSize: r.fs(14)),
                          strong: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: r.fs(14)),
                          em: TextStyle(
                              color: context.textPrimary,
                              fontStyle: FontStyle.italic,
                              fontSize: r.fs(14)),
                          del: TextStyle(
                              color: Colors.grey[500],
                              decoration: TextDecoration.lineThrough,
                              fontSize: r.fs(14)),
                          a: const TextStyle(
                              color: AppTheme.primaryColor,
                              decoration: TextDecoration.underline),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatToolbar(Responsive r) {
    final buttons = [
      _FormatButton(
          icon: Icons.format_bold,
          tooltip: 'Negrito',
          onTap: () => _applyFormat('**', '**')),
      _FormatButton(
          icon: Icons.format_italic,
          tooltip: 'Itálico',
          onTap: () => _applyFormat('*', '*')),
      _FormatButton(
          icon: Icons.format_strikethrough,
          tooltip: 'Tachado',
          onTap: () => _applyFormat('~~', '~~')),
      _FormatButton(
          icon: Icons.link_rounded,
          tooltip: 'Link',
          onTap: () => _showLinkDialog()),
      _FormatButton(
          icon: Icons.format_list_bulleted_rounded,
          tooltip: 'Lista',
          onTap: () => _applyFormat('\n- ', '', placeholder: 'item')),
    ];

    return Container(
      height: r.s(36),
      margin: EdgeInsets.symmetric(horizontal: r.s(8), vertical: r.s(4)),
      decoration: BoxDecoration(
        color: context.scaffoldBg,
        borderRadius: BorderRadius.circular(r.s(8)),
      ),
      child: Row(
        children: buttons
            .map((b) => Tooltip(
                  message: b.tooltip,
                  child: InkWell(
                    onTap: b.onTap,
                    borderRadius: BorderRadius.circular(r.s(6)),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: r.s(8)),
                      child: Icon(b.icon,
                          size: r.s(18), color: Colors.grey[400]),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  void _showLinkDialog() {
    final urlCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text('Inserir Link',
            style: TextStyle(
                color: context.textPrimary, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                labelText: 'Texto do link',
                labelStyle: TextStyle(color: Colors.grey[500]),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                labelText: 'URL',
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
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[500])),
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
            child: const Text('Inserir',
                style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w700)),
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
        style: TextStyle(color: context.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[500]),
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(icon, color: AppTheme.primaryColor),
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
