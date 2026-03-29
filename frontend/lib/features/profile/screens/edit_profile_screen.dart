import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';

/// Tela de edição de perfil do usuário.
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

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nicknameController = TextEditingController(text: user?.nickname ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _aminoIdController = TextEditingController(text: user?.aminoId ?? '');
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    _aminoIdController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final userId = SupabaseService.currentUserId!;
      await SupabaseService.table('profiles').update({
        'nickname': _nicknameController.text.trim(),
        'bio': _bioController.text.trim(),
        'amino_id': _aminoIdController.text.trim(),
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
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
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

              // Bio
              _buildTextField(
                controller: _bioController,
                label: 'Bio',
                icon: Icons.info_outlined,
                maxLines: 4,
                maxLength: 500,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
      final r = context.r;
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
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
          contentPadding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(16)),
          counterStyle: TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }
}
