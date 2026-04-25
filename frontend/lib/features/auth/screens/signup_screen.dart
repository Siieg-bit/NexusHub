import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/amino_animations.dart';
import '../providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import 'package:amino_clone/config/nexus_theme_data.dart';

// ── Utilitário de força de senha ─────────────────────────────────────────────

class _PasswordStrength {
  final int score; // 0-4
  final List<String> missing;

  const _PasswordStrength(this.score, this.missing);

  static _PasswordStrength evaluate(String password) {
    final missing = <String>[];
    int score = 0;

    if (password.length >= 8) {
      score++;
    } else {
      missing.add('Mínimo 8 caracteres');
    }
    if (password.contains(RegExp(r'[A-Z]'))) {
      score++;
    } else {
      missing.add('Uma letra maiúscula');
    }
    if (password.contains(RegExp(r'[a-z]'))) {
      score++;
    } else {
      missing.add('Uma letra minúscula');
    }
    if (password.contains(RegExp(r'[0-9]'))) {
      score++;
    } else {
      missing.add('Um número');
    }
    if (password.contains(RegExp(r'[^a-zA-Z0-9]'))) {
      score++;
    } else {
      missing.add('Um caractere especial (!@#\$...)');
    }

    return _PasswordStrength(score, missing);
  }

  String get label {
    if (score <= 1) return 'Muito fraca';
    if (score == 2) return 'Fraca';
    if (score == 3) return 'Média';
    if (score == 4) return 'Forte';
    return 'Muito forte';
  }

  Color get color {
    if (score <= 1) return const Color(0xFFE53935);
    if (score == 2) return const Color(0xFFFF7043);
    if (score == 3) return const Color(0xFFFFB300);
    if (score == 4) return const Color(0xFF66BB6A);
    return const Color(0xFF00C853);
  }
}

/// Tela de cadastro — visual Amino Apps com validações de segurança robustas.
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
  bool _obscureConfirm = true;
  bool _acceptedTerms = false;
  _PasswordStrength _strength = const _PasswordStrength(0, []);

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    final s = _PasswordStrength.evaluate(_passwordController.text);
    if (s.score != _strength.score) {
      setState(() => _strength = s);
    }
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    final s = getStrings();
    if (_formKey.currentState?.validate() != true) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.acceptTermsToContinue)),
      );
      return;
    }

    // Bloquear senhas muito fracas
    if (_strength.score < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sua senha é muito fraca. Melhore-a antes de continuar.'),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final email = _emailController.text.trim();
    final success = await ref.read(authProvider.notifier).signUp(
          email,
          _passwordController.text,
          _nicknameController.text.trim(),
        );

    if (!mounted) return;

    if (success) {
      context.go('/');
    } else {
      final authState = ref.read(authProvider);
      if (authState.error == null) {
        // E-mail de confirmação enviado
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(ctx).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Verifique seu e-mail',
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enviamos um link de confirmação para:\n',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                Text(
                  email,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 12),
                Text(
                  'Abra o e-mail e clique no link para ativar sua conta. Verifique também a caixa de spam.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go('/login');
                },
                child: const Text('Entendi'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
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
                        color: context.nexusTheme.surfacePrimary,
                        borderRadius: BorderRadius.circular(r.s(12)),
                      ),
                      child: Icon(Icons.arrow_back_rounded,
                          color: context.nexusTheme.textPrimary, size: r.s(20)),
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
                        'Criar\nConta',
                        style: TextStyle(
                          color: context.nexusTheme.textPrimary,
                          fontSize: r.fs(32),
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: r.s(8)),
                      Text(
                        'Junte-se a milhares de comunidades',
                        style: TextStyle(
                          color: context.nexusTheme.textSecondary,
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
                    hint: s.nicknameHint,
                    icon: Icons.person_outline_rounded,
                    validator: (value) {
                      if (value == null || value.isEmpty) return s.chooseANickname;
                      if (value.length < 3) return s.min3Chars;
                      if (value.length > 30) return s.max30Chars;
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
                    hint: s.emailHint,
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) return s.enterYourEmail;
                      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                      if (!emailRegex.hasMatch(value.trim())) return s.invalidEmail;
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
                    hint: s.password,
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    suffixIcon: GestureDetector(
                      onTap: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      child: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: context.nexusTheme.textHint,
                        size: r.s(20),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return s.createAPassword;
                      if (value.length < 8) return 'Mínimo 8 caracteres';
                      if (!value.contains(RegExp(r'[A-Z]')))
                        return 'Inclua pelo menos uma letra maiúscula';
                      if (!value.contains(RegExp(r'[0-9]')))
                        return 'Inclua pelo menos um número';
                      return null;
                    },
                  ),
                ),

                // Indicador de força de senha
                if (_passwordController.text.isNotEmpty) ...[
                  SizedBox(height: r.s(8)),
                  _PasswordStrengthIndicator(
                    strength: _strength,
                    r: r,
                  ),
                ],

                SizedBox(height: r.s(14)),

                // Confirmar Senha
                AminoAnimations.slideUp(
                  delay: const Duration(milliseconds: 200),
                  child: _AminoTextField(
                    controller: _confirmPasswordController,
                    hint: 'Confirmar Senha',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscureConfirm,
                    suffixIcon: GestureDetector(
                      onTap: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      child: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: context.nexusTheme.textHint,
                        size: r.s(20),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Confirme sua senha';
                      if (value != _passwordController.text)
                        return s.passwordsDoNotMatch;
                      return null;
                    },
                  ),
                ),
                SizedBox(height: r.s(12)),

                // Termos
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
                                ? context.nexusTheme.accentPrimary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(r.s(6)),
                            border: Border.all(
                              color: _acceptedTerms
                                  ? context.nexusTheme.accentPrimary
                                  : context.nexusTheme.textHint,
                              width: 2,
                            ),
                          ),
                          child: _acceptedTerms
                              ? Icon(Icons.check_rounded,
                                  color: Colors.white, size: r.s(16))
                              : null,
                        ),
                        SizedBox(width: r.s(10)),
                        Expanded(
                          child: Text(
                            s.acceptTermsAndPrivacy,
                            style: TextStyle(
                                color: context.nexusTheme.textSecondary,
                                fontSize: r.fs(13)),
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
                          color: context.nexusTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(r.s(12)),
                          border: Border.all(
                            color: context.nexusTheme.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: context.nexusTheme.error, size: r.s(20)),
                            SizedBox(width: r.s(8)),
                            Expanded(
                              child: Text(authState.error!,
                                  style: TextStyle(
                                      color: context.nexusTheme.error,
                                      fontSize: r.fs(13))),
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
                        backgroundColor: context.nexusTheme.accentPrimary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            context.nexusTheme.accentPrimary.withValues(alpha: 0.5),
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
                    Expanded(child: Container(height: 0.5, color: context.dividerClr)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: r.s(16)),
                      child: Text(s.orLabel,
                          style: TextStyle(
                              color: context.nexusTheme.textHint, fontSize: r.fs(13))),
                    ),
                    Expanded(child: Container(height: 0.5, color: context.dividerClr)),
                  ],
                ),

                SizedBox(height: r.s(24)),

                // Google Signup
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
                            onPressed: () =>
                                ref.read(authProvider.notifier).signInWithGoogle(),
                            icon: Icon(Icons.g_mobiledata_rounded,
                                size: r.s(28), color: context.nexusTheme.textPrimary),
                            label: const Text('Continuar com Google'),
                            style: TextButton.styleFrom(
                              foregroundColor: context.nexusTheme.textPrimary,
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
                      Text(s.alreadyHaveAccountQuestion,
                          style: TextStyle(
                              color: context.nexusTheme.textSecondary,
                              fontSize: r.fs(14))),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: Text(s.logInAction,
                            style: TextStyle(
                              color: context.nexusTheme.accentPrimary,
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

// ── Indicador visual de força de senha ──────────────────────────────────────

class _PasswordStrengthIndicator extends StatelessWidget {
  final _PasswordStrength strength;
  final Responsive r;

  const _PasswordStrengthIndicator({required this.strength, required this.r});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barra de força (5 segmentos)
        Row(
          children: List.generate(5, (i) {
            final filled = i < strength.score;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: r.s(4),
                margin: EdgeInsets.only(right: i < 4 ? r.s(4) : 0),
                decoration: BoxDecoration(
                  color: filled
                      ? strength.color
                      : context.nexusTheme.surfacePrimary,
                  borderRadius: BorderRadius.circular(r.s(4)),
                ),
              ),
            );
          }),
        ),
        SizedBox(height: r.s(6)),
        // Label de força
        Row(
          children: [
            Text(
              strength.label,
              style: TextStyle(
                color: strength.color,
                fontSize: r.fs(12),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (strength.missing.isNotEmpty) ...[
              Text(
                '  •  ',
                style: TextStyle(
                    color: context.nexusTheme.textHint, fontSize: r.fs(12)),
              ),
              Expanded(
                child: Text(
                  'Falta: ${strength.missing.first}',
                  style: TextStyle(
                    color: context.nexusTheme.textHint,
                    fontSize: r.fs(12),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ── Input customizado ────────────────────────────────────────────────────────

class _AminoTextField extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final r = context.r;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: context.nexusTheme.textPrimary, fontSize: r.fs(15)),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.nexusTheme.textHint, fontSize: r.fs(15)),
        prefixIcon: Icon(icon, color: context.nexusTheme.textHint, size: r.s(20)),
        suffixIcon: suffixIcon != null
            ? Padding(
                padding: EdgeInsets.only(right: r.s(12)),
                child: suffixIcon,
              )
            : null,
        filled: true,
        fillColor: context.nexusTheme.surfacePrimary,
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
          borderSide: BorderSide(
            color: context.nexusTheme.accentPrimary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.s(14)),
          borderSide: BorderSide(
            color: context.nexusTheme.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r.s(14)),
          borderSide: BorderSide(
            color: context.nexusTheme.error,
            width: 2,
          ),
        ),
        contentPadding:
            EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(16)),
      ),
    );
  }
}
