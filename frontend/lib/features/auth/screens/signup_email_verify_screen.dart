import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../../../core/utils/amino_animations.dart';
import '../providers/auth_provider.dart';

/// Tela de verificação de e-mail no fluxo de cadastro.
///
/// Exibe 6 campos de dígito para o usuário inserir o código OTP enviado
/// ao e-mail informado no signup. Ao confirmar, chama
/// [SupabaseService.auth.verifyOTP] com [OtpType.signup].
class SignupEmailVerifyScreen extends ConsumerStatefulWidget {
  final String email;

  const SignupEmailVerifyScreen({super.key, required this.email});

  @override
  ConsumerState<SignupEmailVerifyScreen> createState() =>
      _SignupEmailVerifyScreenState();
}

class _SignupEmailVerifyScreenState
    extends ConsumerState<SignupEmailVerifyScreen> {
  // 6 controllers — um por dígito
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  String? _error;
  int _resendCountdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown(60);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String get _code =>
      _controllers.map((c) => c.text.trim()).join();

  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();
    setState(() => _resendCountdown = seconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) t.cancel();
      });
    });
  }

  // ── Verificar código ─────────────────────────────────────────────────────

  Future<void> _verify() async {
    final s = getStrings();
    final code = _code;
    if (code.length < 6) {
      setState(() => _error = s.signupVerifyEmailCodeHint);
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      await SupabaseService.auth.verifyOTP(
        email: widget.email,
        token: code,
        type: OtpType.signup,
      );

      if (!mounted) return;

      // Carregar perfil após verificação bem-sucedida
      await ref.read(authProvider.notifier).loadUserProfile();

      if (!mounted) return;
      context.go('/');
    } on AuthException catch (e) {
      if (!mounted) return;
      final msg = e.message.toLowerCase();
      if (msg.contains('expired') || msg.contains('expirado')) {
        setState(() => _error = s.signupVerifyEmailExpiredCode);
      } else {
        setState(() => _error = s.signupVerifyEmailInvalidCode);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = getStrings().somethingWentWrong);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  // ── Reenviar código ──────────────────────────────────────────────────────

  Future<void> _resend() async {
    if (_resendCountdown > 0) return;
    setState(() => _error = null);
    try {
      await SupabaseService.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );
      _startCountdown(60);
    } catch (_) {
      setState(() => _error = getStrings().somethingWentWrong);
    }
  }

  // ── Teclado: avançar/retroceder foco automaticamente ────────────────────

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    // Suporte a colar código completo no primeiro campo
    if (value.length == 6 && index == 0) {
      for (int i = 0; i < 6; i++) {
        _controllers[i].text = value[i];
      }
      _focusNodes[5].requestFocus();
      _verify();
    }
    setState(() {});
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = getStrings();
    final r = context.r;
    final theme = context.nexusTheme;

    final subtitle = s.signupVerifyEmailSubtitle
        .replaceAll('{email}', widget.email);

    return Scaffold(
      backgroundColor: theme.backgroundPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: r.s(28)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: r.s(16)),

              // Botão voltar
              AminoAnimations.fadeIn(
                child: GestureDetector(
                  onTap: () => context.go('/signup'),
                  child: Container(
                    width: r.s(40),
                    height: r.s(40),
                    decoration: BoxDecoration(
                      color: theme.surfacePrimary,
                      borderRadius: BorderRadius.circular(r.s(12)),
                    ),
                    child: Icon(Icons.arrow_back_rounded,
                        color: theme.textPrimary, size: r.s(20)),
                  ),
                ),
              ),

              SizedBox(height: r.s(32)),

              // Ícone + Título
              AminoAnimations.slideUp(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: r.s(64),
                      height: r.s(64),
                      decoration: BoxDecoration(
                        color: theme.accentPrimary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(r.s(18)),
                      ),
                      child: Icon(Icons.mark_email_read_rounded,
                          color: theme.accentPrimary, size: r.s(34)),
                    ),
                    SizedBox(height: r.s(20)),
                    Text(
                      s.signupVerifyEmailTitle,
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: r.fs(28),
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: r.s(10)),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: r.fs(14),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: r.s(36)),

              // Campos de dígito
              AminoAnimations.slideUp(
                delay: const Duration(milliseconds: 80),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) => _DigitField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    onChanged: (v) => _onDigitChanged(i, v),
                    onKeyEvent: (e) => _onKeyEvent(i, e),
                    hasError: _error != null,
                    theme: theme,
                    r: r,
                  )),
                ),
              ),

              // Mensagem de erro
              if (_error != null) ...[
                SizedBox(height: r.s(10)),
                AminoAnimations.fadeIn(
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: theme.error,
                      fontSize: r.fs(13),
                    ),
                  ),
                ),
              ],

              SizedBox(height: r.s(28)),

              // Botão verificar
              AminoAnimations.slideUp(
                delay: const Duration(milliseconds: 120),
                child: SizedBox(
                  width: double.infinity,
                  height: r.s(52),
                  child: ElevatedButton(
                    onPressed: (_isVerifying || _code.length < 6)
                        ? null
                        : _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accentPrimary,
                      disabledBackgroundColor:
                          theme.accentPrimary.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(r.s(14)),
                      ),
                    ),
                    child: _isVerifying
                        ? SizedBox(
                            width: r.s(22),
                            height: r.s(22),
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            s.signupVerifyEmailButton,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: r.fs(15),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),

              SizedBox(height: r.s(20)),

              // Reenviar código
              AminoAnimations.slideUp(
                delay: const Duration(milliseconds: 160),
                child: Center(
                  child: GestureDetector(
                    onTap: _resendCountdown > 0 ? null : _resend,
                    child: Text(
                      _resendCountdown > 0
                          ? s.signupVerifyEmailResendIn
                              .replaceAll('{seconds}', '$_resendCountdown')
                          : s.signupVerifyEmailResend,
                      style: TextStyle(
                        color: _resendCountdown > 0
                            ? theme.textHint
                            : theme.accentPrimary,
                        fontSize: r.fs(14),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: r.s(32)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widget: campo de um dígito ──────────────────────────────────────────────

class _DigitField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<KeyEvent> onKeyEvent;
  final bool hasError;
  final dynamic theme;
  final Responsive r;

  const _DigitField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onKeyEvent,
    required this.hasError,
    required this.theme,
    required this.r,
  });

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: onKeyEvent,
      child: SizedBox(
        width: r.s(44),
        height: r.s(54),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 6, // permite colar 6 dígitos de uma vez
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: r.fs(22),
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: theme.surfacePrimary,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(r.s(12)),
              borderSide: BorderSide(
                color: hasError
                    ? theme.error
                    : theme.surfacePrimary,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(r.s(12)),
              borderSide: BorderSide(
                color: hasError ? theme.error : theme.accentPrimary,
                width: 2,
              ),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
