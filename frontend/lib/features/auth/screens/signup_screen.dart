import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/utils/amino_animations.dart';
import '../providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';

/// Tela de cadastro — visual Amino Apps (fundo escuro, inputs arredondados, verde).
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aceite os termos de uso para continuar')),
      );
      return;
    }

    final success = await ref.read(authProvider.notifier).signUp(
          _emailController.text.trim(),
          _passwordController.text,
          _nicknameController.text.trim(),
        );

    if (success && mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: r.s(28)),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: r.s(16)),

                // Botão voltar
                AminoAnimations.fadeIn(
                  child: GestureDetector(
                    onTap: () => context.go('/onboarding'),
                    child: Container(
                      width: r.s(40),
                      height: r.s(40),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(r.s(12)),
                      ),
                      child: Icon(Icons.arrow_back_rounded,
                          color: context.textPrimary, size: r.s(20)),
                    ),
                  ),
                ),

                SizedBox(height: r.s(32)),

                // Título
                AminoAnimations.slideUp(
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Criar\nConta',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: r.fs(32),
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: r.s(8)),
                      Text(
                        'Junte-se a milhares de comunidades',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: r.fs(15),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: r.s(36)),

                // Nickname
                AminoAnimations.slideUp(
                  delay: const Duration(milliseconds: 80),
                  child: _AminoTextField(
                    controller: _nicknameController,
                    hint: 'Nickname',
                    icon: Icons.person_outline_rounded,
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Escolha um nickname';
                      if (value.length < 3) return 'Mínimo 3 caracteres';
                      if (value.length > 30) return 'Máximo 30 caracteres';
                      return null;
                    },
                  ),
                ),
                SizedBox(height: r.s(14)),

                // Email
                AminoAnimations.slideUp(
                  delay: const Duration(milliseconds: 120),
                  child: _AminoTextField(
                    controller: _emailController,
                    hint: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Informe seu email';
                      if (!value.contains('@')) return 'Email inválido';
                      return null;
                    },
                  ),
                ),
                SizedBox(height: r.s(14)),

                // Senha
                AminoAnimations.slideUp(
                  delay: const Duration(milliseconds: 160),
                  child: _AminoTextField(
                    controller: _passwordController,
                    hint: 'Senha',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    suffixIcon: GestureDetector(
                      onTap: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      child: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: context.textHint,
                        size: r.s(20),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Crie uma senha';
                      if (value.length < 6) return 'Mínimo 6 caracteres';
                      return null;
                    },
                  ),
                ),
                SizedBox(height: r.s(14)),

                // Confirmar Senha
                AminoAnimations.slideUp(
                  delay: const Duration(milliseconds: 200),
                  child: _AminoTextField(
                    controller: _confirmPasswordController,
                    hint: 'Confirmar Senha',
                    icon: Icons.lock_outline_rounded,
                    obscureText: true,
                    validator: (value) {
                      if (value != _passwordController.text)
                        return 'As senhas não coincidem';
                      return null;
                    },
                  ),
                ),
                SizedBox(height: r.s(12)),

                // Termos (checkbox estilo Amino)
                AminoAnimations.fadeIn(
                  delay: const Duration(milliseconds: 240),
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _acceptedTerms = !_acceptedTerms),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: r.s(22),
                          height: r.s(22),
                          decoration: BoxDecoration(
                            color: _acceptedTerms
                                ? AppTheme.primaryColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(r.s(6)),
                            border: Border.all(
                              color: _acceptedTerms
                                  ? AppTheme.primaryColor
                                  : context.textHint,
                              width: 2,
                            ),
                          ),
                          child: _acceptedTerms
                              ? Icon(Icons.check_rounded,
                                  color: Colors.white, size: r.s(16))
                              : null,
                        ),
                        SizedBox(width: r.s(10)),
                        const Expanded(
                          child: Text(
                            'Aceito os Termos de Uso e Política de Privacidade',
                            style: TextStyle(
                                color: context.textSecondary, fontSize: r.fs(13)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Erro
                if (authState.error != null)
                  Padding(
                    padding: EdgeInsets.only(top: r.s(12)),
                    child: AminoAnimations.scaleIn(
                      child: Container(
                        padding: EdgeInsets.all(r.s(12)),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(r.s(12)),
                          border: Border.all(
                            color: AppTheme.errorColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: AppTheme.errorColor, size: r.s(20)),
                            SizedBox(width: r.s(8)),
                            Expanded(
                              child: Text(authState.error!,
                                  style: TextStyle(
                                      color: AppTheme.errorColor, fontSize: r.fs(13))),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                SizedBox(height: r.s(20)),

                // Botão Criar Conta
                AminoAnimations.slideUp(
                  delay: const Duration(milliseconds: 280),
                  child: SizedBox(
                    width: double.infinity,
                    height: r.s(52),
                    child: ElevatedButton(
                      onPressed: authState.isLoading ? null : _handleSignup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppTheme.primaryColor.withValues(alpha: 0.5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.s(14)),
                        ),
                        textStyle: TextStyle(
                          fontSize: r.fs(16),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: authState.isLoading
                          ? SizedBox(
                              height: r.s(20),
                              width: r.s(20),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Criar Conta'),
                    ),
                  ),
                ),

                SizedBox(height: r.s(24)),

                // Divisor "ou"
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 0.5,
                        color: context.dividerClr,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: r.s(16)),
                      child: Text('ou',
                          style: TextStyle(
                              color: context.textHint, fontSize: r.fs(13))),
                    ),
                    Expanded(
                      child: Container(
                        height: 0.5,
                        color: context.dividerClr,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: r.s(24)),

                // Google Signup (translúcido)
                AminoAnimations.slideUp(
                  delay: const Duration(milliseconds: 320),
                  child: SizedBox(
                    width: double.infinity,
                    height: r.s(52),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(r.s(14)),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(r.s(14)),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: TextButton.icon(
                            onPressed: () => ref
                                .read(authProvider.notifier)
                                .signInWithGoogle(),
                            icon: Icon(Icons.g_mobiledata_rounded,
                                size: r.s(28), color: context.textPrimary),
                            label: const Text('Continuar com Google'),
                            style: TextButton.styleFrom(
                              foregroundColor: context.textPrimary,
                              textStyle: TextStyle(
                                fontSize: r.fs(15),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: r.s(32)),

                // Link para login
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Já tem conta? ',
                          style: TextStyle(
                              color: context.textSecondary, fontSize: r.fs(14))),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: const Text('Fazer login',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w700,
                              fontSize: r.fs(14),
                            )),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: r.s(32)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// AMINO TEXT FIELD — Input customizado no padrão Amino
// ==============================================================================

class _AminoTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _AminoTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: context.textPrimary, fontSize: r.fs(15)),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.textHint, fontSize: r.fs(15)),
        prefixIcon: Icon(icon, color: context.textHint, size: r.s(20)),
        suffixIcon: suffixIcon != null
            ? Padding(
                padding: EdgeInsets.only(right: r.s(12)),
                child: suffixIcon,
              )
            : null,
        filled: true,
        fillColor: context.cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.s(14)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.s(14)),
          borderSide: BorderSide(
            color: context.dividerClr.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.s(14)),
          borderSide: const BorderSide(
            color: AppTheme.primaryColor,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.s(14)),
          borderSide: const BorderSide(
            color: AppTheme.errorColor,
            width: 1,
          ),
        ),
        contentPadding:
            EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(16)),
      ),
    );
  }
}
