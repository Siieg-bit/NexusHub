import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../providers/auth_provider.dart';

/// Tela de desafio 2FA exibida após login bem-sucedido com e-mail/senha
/// quando o usuário tem TOTP ou SMS ativo.
///
/// Parâmetros via `extra`:
///   - `factorId`: String — ID do fator MFA a verificar
///   - `method`: 'totp' | 'phone' — método ativo
class MfaChallengeScreen extends ConsumerStatefulWidget {
  final String factorId;
  final String method; // 'totp' | 'phone'

  const MfaChallengeScreen({
    super.key,
    required this.factorId,
    required this.method,
  });

  @override
  ConsumerState<MfaChallengeScreen> createState() => _MfaChallengeScreenState();
}

class _MfaChallengeScreenState extends ConsumerState<MfaChallengeScreen> {
  final _codeCtrl = TextEditingController();
  bool _isVerifying = false;
  bool _useBackup   = false;
  String? _error;

  // Para SMS
  String? _challengeId;
  bool _smsSent = false;
  int _resendCountdown = 0;

  @override
  void initState() {
    super.initState();
    if (widget.method == 'phone') _createSmsChallenge();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  /// Cria o challenge SMS e envia o código.
  Future<void> _createSmsChallenge() async {
    setState(() { _smsSent = false; _error = null; });
    try {
      final res = await SupabaseService.client.auth.mfa.challenge(
        params: MFAChallengeParams(factorId: widget.factorId),
      );
      setState(() {
        _challengeId = res.id;
        _smsSent = true;
        _resendCountdown = 60;
      });
      _startCountdown();
    } catch (e) {
      setState(() => _error = 'Erro ao enviar SMS. Tente novamente.');
    }
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || _resendCountdown <= 0) return;
      setState(() => _resendCountdown--);
      _startCountdown();
    });
  }

  /// Verifica o código (TOTP ou SMS) ou um backup code.
  Future<void> _verify() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() { _isVerifying = true; _error = null; });

    try {
      if (_useBackup) {
        // Verificação via backup code (RPC customizado)
        await SupabaseService.rpc('use_backup_code', params: {'p_code': code});
        // Após usar backup code, a sessão já está em AAL1 — completar auth
        await ref.read(authProvider.notifier).loadUserProfile();
        if (mounted) context.go('/');
        return;
      }

      // Verificação TOTP ou SMS via Supabase MFA
      String challengeId;
      if (widget.method == 'totp') {
        final res = await SupabaseService.client.auth.mfa.challenge(
          params: MFAChallengeParams(factorId: widget.factorId),
        );
        challengeId = res.id;
      } else {
        challengeId = _challengeId!;
      }

      await SupabaseService.client.auth.mfa.verify(
        params: MFAVerifyParams(
          factorId:    widget.factorId,
          challengeId: challengeId,
          code:        code,
        ),
      );

      // Sessão agora em AAL2 — carregar perfil e navegar
      await ref.read(authProvider.notifier).loadUserProfile();
      if (mounted) context.go('/');
    } catch (e) {
      String msg = 'Código inválido. Tente novamente.';
      if (e.toString().contains('expired')) msg = 'Código expirado. Solicite um novo.';
      if (e.toString().contains('backup_code_invalid')) msg = 'Código de recuperação inválido.';
      if (e.toString().contains('backup_code_used'))    msg = 'Este código já foi usado.';
      setState(() { _isVerifying = false; _error = msg; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;
    final isTotp = widget.method == 'totp';

    final pinTheme = PinTheme(
      width: r.s(52),
      height: r.s(60),
      textStyle: TextStyle(
        fontSize: r.s(22),
        color: theme.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(12)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
    );

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: theme.textPrimary, size: r.s(20)),
          onPressed: () async {
            // Fazer logout e voltar para o login
            await SupabaseService.auth.signOut();
            if (mounted) context.go('/login');
          },
        ),
        title: Text(
          'Verificação em 2 Etapas',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: r.s(18),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(r.s(24)),
        child: Column(
          children: [
            SizedBox(height: r.s(16)),

            // Ícone
            Container(
              padding: EdgeInsets.all(r.s(20)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isTotp
                      ? [const Color(0xFF00C853), const Color(0xFF1DE9B6)]
                      : [const Color(0xFF2979FF), const Color(0xFF00B0FF)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _useBackup
                    ? Icons.backup_rounded
                    : (isTotp ? Icons.qr_code_rounded : Icons.sms_rounded),
                color: Colors.white,
                size: r.s(36),
              ),
            ),

            SizedBox(height: r.s(20)),

            Text(
              _useBackup
                  ? 'Código de Recuperação'
                  : (isTotp ? 'App Autenticador' : 'Verificação por SMS'),
              style: TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: r.s(22),
              ),
            ),
            SizedBox(height: r.s(8)),
            Text(
              _useBackup
                  ? 'Insira um dos seus códigos de recuperação (formato XXXX-XXXX).'
                  : (isTotp
                      ? 'Insira o código de 6 dígitos do seu app autenticador.'
                      : (_smsSent
                          ? 'Insira o código de 6 dígitos enviado por SMS.'
                          : 'Enviando código por SMS...')),
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textSecondary, fontSize: r.s(14)),
            ),

            SizedBox(height: r.s(40)),

            // Campo de código
            if (!isTotp && !_smsSent && !_useBackup)
              const CircularProgressIndicator()
            else
              Pinput(
                controller: _codeCtrl,
                length: _useBackup ? 9 : 6, // XXXX-XXXX = 9 chars
                defaultPinTheme: pinTheme,
                focusedPinTheme: pinTheme.copyDecorationWith(
                  border: Border.all(color: theme.accentPrimary, width: 2),
                ),
                errorPinTheme: pinTheme.copyDecorationWith(
                  border: Border.all(color: theme.error, width: 2),
                ),
                keyboardType: _useBackup
                    ? TextInputType.text
                    : TextInputType.number,
                onCompleted: (_) => _verify(),
              ),

            if (_error != null) ...[
              SizedBox(height: r.s(12)),
              Text(_error!,
                  style: TextStyle(color: theme.error, fontSize: r.s(13))),
            ],

            SizedBox(height: r.s(32)),

            // Botão verificar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _verify,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: r.s(16)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.s(14))),
                  backgroundColor: theme.accentPrimary,
                ),
                child: _isVerifying
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('Verificar',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: r.s(15),
                        )),
              ),
            ),

            SizedBox(height: r.s(20)),

            // Reenviar SMS
            if (!isTotp && !_useBackup) ...[
              _resendCountdown > 0
                  ? Text(
                      'Reenviar em $_resendCountdown segundos',
                      style: TextStyle(
                          color: theme.textSecondary, fontSize: r.s(13)),
                    )
                  : GestureDetector(
                      onTap: _createSmsChallenge,
                      child: Text('Reenviar código por SMS',
                          style: TextStyle(
                              color: theme.accentPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: r.s(13))),
                    ),
              SizedBox(height: r.s(16)),
            ],

            // Alternar para backup code
            GestureDetector(
              onTap: () => setState(() {
                _useBackup = !_useBackup;
                _codeCtrl.clear();
                _error = null;
              }),
              child: Text(
                _useBackup
                    ? '← Voltar para o método principal'
                    : 'Não tenho acesso — usar código de recuperação',
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: r.s(13),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
