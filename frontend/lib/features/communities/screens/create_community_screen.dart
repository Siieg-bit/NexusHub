import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';

/// Tela para criação de nova comunidade.
class CreateCommunityScreen extends ConsumerStatefulWidget {
  const CreateCommunityScreen({super.key});

  @override
  ConsumerState<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
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
    '#6C5CE7', '#E74C3C', '#2ECC71', '#F39C12', '#3498DB',
    '#9B59B6', '#E84393', '#00CEC9', '#FD79A8', '#636E72',
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
      final userId = SupabaseService.currentUserId!;
      final response = await SupabaseService.table('communities').insert({
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
      }).select().single();

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
          SnackBar(content: Text('Erro ao criar comunidade: $e')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Comunidade'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createCommunity,
            child: _isLoading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Criar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview do banner com cor selecionada
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _parseColor(_selectedColor),
                      _parseColor(_selectedColor).withOpacity(0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(Icons.camera_alt_rounded, size: 40, color: Colors.white54),
                ),
              ),
              const SizedBox(height: 24),

              // Nome
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome da Comunidade *',
                  hintText: 'Ex: Anime Brasil, K-Pop Universe...',
                  prefixIcon: Icon(Icons.groups_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Nome é obrigatório';
                  if (value.trim().length < 3) return 'Mínimo 3 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Tagline
              TextFormField(
                controller: _taglineController,
                decoration: const InputDecoration(
                  labelText: 'Tagline',
                  hintText: 'Uma frase curta sobre a comunidade',
                  prefixIcon: Icon(Icons.short_text_rounded),
                ),
                maxLength: 100,
              ),
              const SizedBox(height: 16),

              // Descrição
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  hintText: 'Descreva sua comunidade em detalhes...',
                  prefixIcon: Icon(Icons.description_rounded),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                maxLength: 1000,
              ),
              const SizedBox(height: 24),

              // Cor do tema
              Text('Cor do Tema', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _colors.map((color) {
                  final isSelected = color == _selectedColor;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _parseColor(color),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [BoxShadow(
                                color: _parseColor(color).withOpacity(0.5),
                                blurRadius: 8,
                              )]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Idioma
              Text('Idioma Principal', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedLanguage,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.language_rounded),
                ),
                items: const [
                  DropdownMenuItem(value: 'pt-BR', child: Text('Português (Brasil)')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'es', child: Text('Español')),
                  DropdownMenuItem(value: 'ja', child: Text('日本語')),
                  DropdownMenuItem(value: 'ko', child: Text('한국어')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _selectedLanguage = value);
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
