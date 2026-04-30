import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Tela de verificação de e-mail acessível pelo Centro de Segurança.
///
/// Fluxo:
///   1. Se o e-mail já estiver verificado → exibe estado de sucesso.
///   2. Se não estiver → exibe botão para enviar o e-mail de verificação.
///   3. Após o envio → exibe estado de "e-mail enviado" com countdown de reenvio.
class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  // Estados: 'idle' | 'sending' | 'sent' | 'verified'
  String _state = 'idle';
  String? _error;
  int _resendCountdown = 0;
  Timer? _countdownTimer;

  late bool _isVerified;
  late String _email;

  @override
  void initState() {
    super.initState();
    final user = SupabaseService.client.auth.currentUser;
    _isVerified = user?.emailConfirmedAt != null;
    _email = user?.email ?? '';
    if (_isVerified) _state = 'verified';
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── Enviar e-mail de verificação ──────────────────────────────────────────
  Future<void> _sendVerificationEmail() async {
    if (_state == 'sending') return;
    setState(() {
      _state = 'sending';
      _error = null;
    });

    try {
      // Supabase: reenviar e-mail de confirmação via OTP tipo 'signup'
      await SupabaseService.client.auth.resend(
        type: OtpType.signup,
        email: _email,
      );

      _startCountdown(60);
      setState(() => _state = 'sent');
    } catch (e) {
      setState(() {
        _state = 'idle';
        _error = 'Erro ao enviar e-mail. Tente novamente.';
      });
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final theme = context.nexusTheme;

    return Scaffold(
      backgroundColor: theme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: theme.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          s.securityVerifyEmailTitle,
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: r.fs(18),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(r.s(24)),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: _state == 'verified'
                ? _buildVerified(context, r, theme, s)
                : _state == 'sent'
                    ? _buildSent(context, r, theme, s)
                    : _buildIdle(context, r, theme, s),
          ),
        ),
      ),
    );
  }

  // ── Estado: e-mail já verificado ──────────────────────────────────────────
  Widget _buildVerified(
      BuildContext context, Responsive r, dynamic theme, dynamic s) {
    return Column(
      key: const ValueKey('verified'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: r.s(40)),
        Container(
          width: r.s(96),
          height: r.s(96),
          decoration: BoxDecoration(
            color: theme.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.verified_rounded,
            color: theme.success,
            size: r.s(52),
          ),
        ),
        SizedBox(height: r.s(24)),
        Text(
          s.securityEmailVerified,
          style: TextStyle(
            fontSize: r.fs(20),
            fontWeight: FontWeight.w700,
            color: theme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: r.s(10)),
        Text(
          s.securityVerifyEmailAlreadyVerified,
          style: TextStyle(
            fontSize: r.fs(14),
            color: theme.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: r.s(12)),
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: r.s(16), vertical: r.s(10)),
          decoration: BoxDecoration(
            color: theme.surfacePrimary,
            borderRadius: BorderRadius.circular(r.s(10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.email_outlined,
                  color: theme.textSecondary, size: r.s(16)),
              SizedBox(width: r.s(8)),
              Text(
                _email,
                style: TextStyle(
                  fontSize: r.fs(13),
                  color: theme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: r.s(32)),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_rounded,
                size: r.s(16), color: theme.accentPrimary),
            label: Text(
              'Voltar',
              style: TextStyle(
                  color: theme.accentPrimary,
                  fontSize: r.fs(14),
                  fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                  color: theme.accentPrimary.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.s(12))),
              padding: EdgeInsets.symmetric(vertical: r.s(14)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Estado: e-mail enviado ────────────────────────────────────────────────
  Widget _buildSent(
      BuildContext context, Responsive r, dynamic theme, dynamic s) {
    return Column(
      key: const ValueKey('sent'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: r.s(40)),
        Container(
          width: r.s(96),
          height: r.s(96),
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.mark_email_read_rounded,
            color: const Color(0xFF2196F3),
            size: r.s(52),
          ),
        ),
        SizedBox(height: r.s(24)),
        Text(
          s.securityVerifyEmailSentTitle,
          style: TextStyle(
            fontSize: r.fs(20),
            fontWeight: FontWeight.w700,
            color: theme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: r.s(10)),
        Text(
          s.securityVerifyEmailSentBody,
          style: TextStyle(
            fontSize: r.fs(14),
            color: theme.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: r.s(12)),
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: r.s(16), vertical: r.s(10)),
          decoration: BoxDecoration(
            color: theme.surfacePrimary,
            borderRadius: BorderRadius.circular(r.s(10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.email_outlined,
                  color: theme.textSecondary, size: r.s(16)),
              SizedBox(width: r.s(8)),
              Text(
                _email,
                style: TextStyle(
                  fontSize: r.fs(13),
                  color: theme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: r.s(32)),

        // Botão de reenvio com countdown
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _resendCountdown > 0 ? null : _sendVerificationEmail,
            icon: Icon(Icons.send_rounded, size: r.s(16)),
            label: Text(
              _resendCountdown > 0
                  ? s.securityVerifyEmailResendIn
                      .replaceAll('{seconds}', '$_resendCountdown')
                  : s.securityVerifyEmailResend,
              style: TextStyle(
                  fontSize: r.fs(14), fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accentPrimary,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  theme.accentPrimary.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.s(12))),
              padding: EdgeInsets.symmetric(vertical: r.s(14)),
            ),
          ),
        ),
        SizedBox(height: r.s(12)),
        // Dica
        Container(
          padding: EdgeInsets.all(r.s(14)),
          decoration: BoxDecoration(
            color: theme.surfacePrimary,
            borderRadius: BorderRadius.circular(r.s(12)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  color: theme.textSecondary, size: r.s(16)),
              SizedBox(width: r.s(10)),
              Expanded(
                child: Text(
                  'Não encontrou o e-mail? Verifique a pasta de spam ou lixo eletrônico.',
                  style: TextStyle(
                    fontSize: r.fs(12),
                    color: theme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Estado: aguardando ação ───────────────────────────────────────────────
  Widget _buildIdle(
      BuildContext context, Responsive r, dynamic theme, dynamic s) {
    return Column(
      key: const ValueKey('idle'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(r.s(20)),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFF9800).withValues(alpha: 0.15),
                const Color(0xFFFF9800).withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(r.s(16)),
            border: Border.all(
                color: const Color(0xFFFF9800).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: r.s(52),
                height: r.s(52),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning_rounded,
                    color: const Color(0xFFFF9800), size: r.s(28)),
              ),
              SizedBox(width: r.s(16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.securityEmailNotVerified,
                      style: TextStyle(
                        fontSize: r.fs(15),
                        fontWeight: FontWeight.w700,
                        color: theme.textPrimary,
                      ),
                    ),
                    SizedBox(height: r.s(4)),
                    Text(
                      _email,
                      style: TextStyle(
                        fontSize: r.fs(12),
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: r.s(20)),
        Text(
          s.securityVerifyEmailSubtitle,
          style: TextStyle(
            fontSize: r.fs(14),
            color: theme.textSecondary,
            height: 1.5,
          ),
        ),
        SizedBox(height: r.s(24)),

        // Erro
        if (_error != null) ...[
          Container(
            padding: EdgeInsets.all(r.s(12)),
            decoration: BoxDecoration(
              color: theme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(r.s(10)),
              border:
                  Border.all(color: theme.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded,
                    color: theme.error, size: r.s(16)),
                SizedBox(width: r.s(8)),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(
                        color: theme.error, fontSize: r.fs(13)),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r.s(16)),
        ],

        // Botão principal
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _state == 'sending' ? null : _sendVerificationEmail,
            icon: _state == 'sending'
                ? SizedBox(
                    width: r.s(16),
                    height: r.s(16),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Icon(Icons.send_rounded, size: r.s(16)),
            label: Text(
              s.securityVerifyEmailResend,
              style: TextStyle(
                  fontSize: r.fs(15), fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accentPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.s(12))),
              padding: EdgeInsets.symmetric(vertical: r.s(16)),
            ),
          ),
        ),
        SizedBox(height: r.s(20)),

        // Benefícios da verificação
        Container(
          padding: EdgeInsets.all(r.s(14)),
          decoration: BoxDecoration(
            color: theme.surfacePrimary,
            borderRadius: BorderRadius.circular(r.s(12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_outlined,
                      color: theme.accentPrimary, size: r.s(16)),
                  SizedBox(width: r.s(8)),
                  Text(
                    'Por que verificar?',
                    style: TextStyle(
                      fontSize: r.fs(13),
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: r.s(10)),
              ...[
                'Recuperar sua conta em caso de perda de acesso',
                'Receber notificações importantes de segurança',
                'Aumentar o nível de segurança da sua conta',
              ].map(
                (tip) => Padding(
                  padding: EdgeInsets.only(bottom: r.s(6)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          color: theme.success, size: r.s(14)),
                      SizedBox(width: r.s(8)),
                      Expanded(
                        child: Text(
                          tip,
                          style: TextStyle(
                            fontSize: r.fs(12),
                            color: theme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
