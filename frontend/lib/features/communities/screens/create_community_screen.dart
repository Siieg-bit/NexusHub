import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

/// Tela para criação de nova comunidade.
class CreateCommunityScreen extends ConsumerStatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  ConsumerState<CreateCommunityScreen> createState() =>
      _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends ConsumerState<CreateCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedColor = '#6C5CE7';
  String _selectedLanguage = 'pt-BR';
  bool _isLoading = false;

  final _colors = [
    '#6C5CE7',
    '#E74C3C',
    '#2ECC71',
    '#F39C12',
    '#3498DB',
    '#9B59B6',
    '#E84393',
    '#00CEC9',
    '#FD79A8',
    '#636E72',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createCommunity() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      final response = await SupabaseService.table('communities')
          .insert({
            'name': _nameController.text.trim(),
            'tagline': _taglineController.text.trim().isEmpty
                ? null
                : _taglineController.text.trim(),
            'description': _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            'agent_id': userId,
            'theme_color': _selectedColor,
            'primary_language': _selectedLanguage,
          })
          .select()
          .single();

      // Entrar na comunidade como leader
      await SupabaseService.table('community_members').insert({
        'user_id': userId,
        'community_id': response['id'],
        'role': 'agent',
      });

      if (mounted) {
        context.pop();
        context.push('/community/${response['id']}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar comunidade. Tente novamente.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
        title: Text(
          'Criar Comunidade',
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: _isLoading ? null : _createCommunity,
            child: Container(
              margin: EdgeInsets.only(right: r.s(16), top: r.s(8), bottom: r.s(8)),
              padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(8)),
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
              child: _isLoading
                  ? SizedBox(
                      width: r.s(20),
                      height: r.s(20),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Criar',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
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
              // Preview do banner com cor selecionada
              Container(
                height: r.s(120),
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _parseColor(_selectedColor),
                      _parseColor(_selectedColor).withValues(alpha: 0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(r.s(16)),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Center(
                  child: Icon(Icons.camera_alt_rounded,
                      size: r.s(40), color: Colors.white54),
                ),
              ),
              SizedBox(height: r.s(24)),

              // Nome
              _buildTextField(
                controller: _nameController,
                label: 'Nome da Comunidade *',
                hint: 'Ex: Anime Brasil, K-Pop Universe...',
                icon: Icons.groups_rounded,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nome é obrigatório';
                  }
                  if (value.trim().length < 3) return 'Mínimo 3 caracteres';
                  return null;
                },
              ),
              SizedBox(height: r.s(16)),

              // Tagline
              _buildTextField(
                controller: _taglineController,
                label: 'Tagline',
                hint: 'Uma frase curta sobre a comunidade',
                icon: Icons.short_text_rounded,
                maxLength: 100,
              ),
              SizedBox(height: r.s(16)),

              // Descrição
              _buildTextField(
                controller: _descriptionController,
                label: 'Descrição',
                hint: 'Descreva sua comunidade em detalhes...',
                icon: Icons.description_rounded,
                maxLines: 4,
                maxLength: 1000,
              ),
              SizedBox(height: r.s(24)),

              // Cor do tema
              Text(
                'Cor do Tema',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: r.fs(16),
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: r.s(12)),
              Container(
                padding: EdgeInsets.all(r.s(16)),
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(r.s(16)),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _colors.map((color) {
                    final isSelected = color == _selectedColor;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        width: r.s(44),
                        height: r.s(44),
                        decoration: BoxDecoration(
                          color: _parseColor(color),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: r.s(3))
                              : Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  width: 1,
                                ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: _parseColor(color)
                                        .withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  )
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? Icon(Icons.check_rounded,
                                color: Colors.white, size: r.s(20))
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: r.s(24)),

              // Idioma
              Text(
                'Idioma Principal',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: r.fs(16),
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: r.s(12)),
              Container(
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(r.s(16)),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedLanguage,
                  dropdownColor: context.surfaceColor,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.language_rounded,
                        color: AppTheme.accentColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(r.s(16)),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: r.s(16), vertical: r.s(16)),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'pt-BR', child: Text('Português (Brasil)')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'es', child: Text('Español')),
                    DropdownMenuItem(value: 'ja', child: Text('日本語')),
                    DropdownMenuItem(value: 'ko', child: Text('한국어')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedLanguage = value);
                    }
                  },
                ),
              ),
              SizedBox(height: r.s(40)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    final r = context.r;
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      style: TextStyle(color: context.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[500]),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[600]),
        prefixIcon: Icon(icon, color: AppTheme.accentColor),
        alignLabelWithHint: maxLines > 1,
        filled: true,
        fillColor: context.surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.s(16)),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.s(16)),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.s(16)),
          borderSide: const BorderSide(color: AppTheme.primaryColor),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.s(16)),
          borderSide: const BorderSide(color: AppTheme.errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.s(16)),
          borderSide: const BorderSide(color: AppTheme.errorColor),
        ),
      ),
    );
  }
}