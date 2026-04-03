import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_theme.dart';
import '../../../core/utils/amino_animations.dart';
import '../../../core/services/supabase_service.dart';
import '../providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';

/// Tela de login — visual Amino Apps (fundo escuro, inputs arredondados, verde).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if ((_formKey.currentState?.validate() != true)) return;

    final success = await ref.read(authProvider.notifier).signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bem-vindo\nde volta!',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: r.fs(32),
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: r.s(8)),
                      Text(
                        'Faça login para continuar',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: r.fs(15),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: r.s(40)),

                // Campo Email
                AminoAnimations.slideUp(
                  delay: const Duration(milliseconds: 100),
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

                SizedBox(height: r.s(16)),

                // Campo Senha
                AminoAnimations.slideUp(
                  delay: const Duration(milliseconds: 150),
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
                      if (value == null || value.isEmpty)
                        return 'Informe sua senha';
                      if (value.length < 6) return 'Mínimo 6 caracteres';
                      return null;
                    },
                  ),
                ),

                SizedBox(height: r.s(8)),

                // Esqueceu a senha
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      final email = _emailController.text.trim();
                      if (email.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Digite seu email primeiro'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      SupabaseService.auth.resetPasswordForEmail(email);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Email de recupera\u00e7\u00e3o enviado para $email'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      textStyle: TextStyle(
                        fontSize: r.fs(13),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Esqueceu a senha?'),
                  ),
                ),

                // Erro
                if (authState.error != null)
                  AminoAnimations.scaleIn(
                    child: Container(
                      padding: EdgeInsets.all(r.s(12)),
                      margin: EdgeInsets.only(bottom: r.s(16)),
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
                                    color: AppTheme.errorColor,
                                    fontSize: r.fs(13))),
                          ),
                        ],
                      ),
                    ),
                  ),

                SizedBox(height: r.s(8)),

                // Botão Login
                AminoAnimations.slideUp(
                  delay: const Duration(milliseconds: 200),
                  child: SizedBox(
                    width: double.infinity,
                    height: r.s(52),
                    child: ElevatedButton(
                      onPressed: authState.isLoading ? null : _handleLogin,
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
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Entrar'),
                    ),
                  ),
                ),

                SizedBox(height: r.s(28)),

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

                SizedBox(height: r.s(28)),

                // Google Login (translúcido)
                AminoAnimations.slideUp(
                  delay: const Duration(milliseconds: 250),
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

                SizedBox(height: r.s(12)),
                // Apple Login
                AminoAnimations.slideUp(
                  delay: const Duration(milliseconds: 300),
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
                                .signInWithApple(),
                            icon: Icon(Icons.apple_rounded,
                                size: r.s(24), color: context.textPrimary),
                            label: const Text('Continuar com Apple'),
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
                SizedBox(height: r.s(40)),
                // Link para cadastro
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Não tem conta? ',
                          style: TextStyle(
                              color: context.textSecondary,
                              fontSize: r.fs(14))),
                      GestureDetector(
                        onTap: () => context.go('/signup'),
                        child: Text('Criar conta',
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
