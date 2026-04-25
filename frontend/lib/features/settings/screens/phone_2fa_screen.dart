import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

/// Tela de configuração do 2FA por SMS/Telefone.
/// Fluxo: Inserir telefone → Enviar OTP → Verificar OTP → Concluído
class Phone2faScreen extends ConsumerStatefulWidget {
  const Phone2faScreen({super.key});

  @override
  ConsumerState<Phone2faScreen> createState() => _Phone2faScreenState();
}

class _Phone2faScreenState extends ConsumerState<Phone2faScreen> {
  int _step = 1; // 1=phone, 2=otp, 3=done

  final _phoneCtrl = TextEditingController();
  final _otpCtrl   = TextEditingController();
  final _formKey   = GlobalKey<FormState>();

  bool _isSending   = false;
  bool _isVerifying = false;
  String? _phoneError;
  String? _otpError;
  String? _phone; // telefone confirmado após envio
  int _resendCountdown = 0;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  /// Envia o OTP via Edge Function send-sms-otp (Twilio).
  Future<void> _sendOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _isSending = true; _phoneError = null; });

    final phone = _phoneCtrl.text.trim();

    try {
      final res = await SupabaseService.client.functions.invoke(
        'send-sms-otp',
        body: {'phone': phone},
      );
      final data = res.data as Map<String, dynamic>?;
      if (data != null && data['error'] != null) {
        throw Exception(data['error']);
      }
      setState(() {
        _phone = phone;
        _step  = 2;
        _isSending = false;
        _resendCountdown = 60;
      });
      _startCountdown();
    } catch (e) {
      String msg = e.toString().replaceAll('Exception: ', '');
      if (msg.length > 120) msg = 'Erro ao enviar SMS. Tente novamente.';
      setState(() { _isSending = false; _phoneError = msg; });
    }
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || _resendCountdown <= 0) return;
      setState(() => _resendCountdown--);
      _startCountdown();
    });
  }

  /// Verifica o OTP via Edge Function verify-sms-otp.
  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.length != 6) return;
    setState(() { _isVerifying = true; _otpError = null; });

    try {
      final res = await SupabaseService.client.functions.invoke(
        'verify-sms-otp',
        body: {
          'phone':  _phone,
          'code':   _otpCtrl.text.trim(),
          'action': 'setup',
        },
      );
      final data = res.data as Map<String, dynamic>?;
      if (data != null && data['error'] != null) {
        throw Exception(data['error']);
      }
      setState(() { _step = 3; _isVerifying = false; });
    } catch (e) {
      String msg = e.toString().replaceAll('Exception: ', '');
      if (msg.length > 120) msg = 'Código inválido. Tente novamente.';
      setState(() { _isVerifying = false; _otpError = msg; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: theme.textPrimary, size: r.s(20)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Verificação por SMS',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: r.s(18),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildStep(context, r, theme),
      ),
    );
  }

  Widget _buildStep(BuildContext context, Responsive r, NexusThemeExtension theme) {
    switch (_step) {
      case 1: return _buildPhoneStep(context, r, theme);
      case 2: return _buildOtpStep(context, r, theme);
      case 3: return _buildDoneStep(context, r, theme);
      default: return const SizedBox();
    }
  }

  // ── Etapa 1: Inserir telefone ─────────────────────────
  Widget _buildPhoneStep(BuildContext context, Responsive r, NexusThemeExtension theme) {
    return SingleChildScrollView(
      key: const ValueKey(1),
      padding: EdgeInsets.all(r.s(24)),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StepIndicator(current: 1, total: 2),
            SizedBox(height: r.s(24)),

            Text('Seu Número de Telefone',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: r.s(22),
                )),
            SizedBox(height: r.s(8)),
            Text(
              'Enviaremos um código de verificação por SMS para ativar a autenticação em 2 etapas.',
              style: TextStyle(color: theme.textSecondary, fontSize: r.s(14)),
            ),
            SizedBox(height: r.s(32)),

            // Campo de telefone
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: theme.textPrimary, fontSize: r.s(16)),
              decoration: InputDecoration(
                labelText: 'Número de telefone',
                hintText: '+5511999999999',
                labelStyle: TextStyle(color: theme.textSecondary),
                hintStyle: TextStyle(color: theme.textSecondary.withValues(alpha: 0.5)),
                prefixIcon: Icon(Icons.phone_rounded,
                    color: theme.accentPrimary, size: r.s(20)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(14)),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(14)),
                  borderSide:
                      BorderSide(color: theme.accentPrimary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(14)),
                  borderSide: BorderSide(color: theme.error),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(r.s(14)),
                  borderSide: BorderSide(color: theme.error, width: 2),
                ),
                filled: true,
                fillColor: context.surfaceColor,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Insira seu telefone';
                if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(v.trim())) {
                  return 'Formato inválido. Use +5511999999999';
                }
                return null;
              },
            ),

            if (_phoneError != null) ...[
              SizedBox(height: r.s(8)),
              Text(_phoneError!,
                  style: TextStyle(color: theme.error, fontSize: r.s(12))),
            ],

            SizedBox(height: r.s(16)),

            // Info
            Container(
              padding: EdgeInsets.all(r.s(12)),
              decoration: BoxDecoration(
                color: theme.accentPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(r.s(12)),
                border: Border.all(
                    color: theme.accentPrimary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: theme.accentPrimary, size: r.s(16)),
                  SizedBox(width: r.s(8)),
                  Expanded(
                    child: Text(
                      'Inclua o código do país. Ex: +55 para Brasil.',
                      style: TextStyle(
                        color: theme.accentPrimary,
                        fontSize: r.s(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: r.s(32)),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendOtp,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: r.s(16)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.s(14))),
                  backgroundColor: theme.accentPrimary,
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('Enviar Código por SMS',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: r.s(15),
                        )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Etapa 2: Verificar OTP ────────────────────────────
  Widget _buildOtpStep(BuildContext context, Responsive r, NexusThemeExtension theme) {
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

    return SingleChildScrollView(
      key: const ValueKey(2),
      padding: EdgeInsets.all(r.s(24)),
      child: Column(
        children: [
          _StepIndicator(current: 2, total: 2),
          SizedBox(height: r.s(24)),

          Icon(Icons.sms_rounded, color: theme.accentPrimary, size: r.s(48)),
          SizedBox(height: r.s(16)),
          Text('Código Enviado!',
              style: TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: r.s(22),
              )),
          SizedBox(height: r.s(8)),
          Text(
            'Insira o código de 6 dígitos enviado para\n${_phone ?? ''}',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.textSecondary, fontSize: r.s(14)),
          ),
          SizedBox(height: r.s(40)),

          Pinput(
            controller: _otpCtrl,
            length: 6,
            defaultPinTheme: pinTheme,
            focusedPinTheme: pinTheme.copyDecorationWith(
              border: Border.all(color: theme.accentPrimary, width: 2),
            ),
            errorPinTheme: pinTheme.copyDecorationWith(
              border: Border.all(color: theme.error, width: 2),
            ),
            keyboardType: TextInputType.number,
            onCompleted: (_) => _verifyOtp(),
          ),

          if (_otpError != null) ...[
            SizedBox(height: r.s(12)),
            Text(_otpError!,
                style: TextStyle(color: theme.error, fontSize: r.s(13))),
          ],

          SizedBox(height: r.s(24)),

          // Reenviar
          _resendCountdown > 0
              ? Text(
                  'Reenviar em $_resendCountdown segundos',
                  style: TextStyle(
                      color: theme.textSecondary, fontSize: r.s(13)),
                )
              : GestureDetector(
                  onTap: () {
                    setState(() { _step = 1; _otpCtrl.clear(); _otpError = null; });
                  },
                  child: Text('Não recebi o código — Tentar novamente',
                      style: TextStyle(
                          color: theme.accentPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: r.s(13))),
                ),

          SizedBox(height: r.s(32)),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isVerifying ? null : _verifyOtp,
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
                  : Text('Verificar e Ativar',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: r.s(15),
                      )),
            ),
          ),
        ],
      ),
    );
  }

  // ── Etapa 3: Concluído ────────────────────────────────
  Widget _buildDoneStep(BuildContext context, Responsive r, NexusThemeExtension theme) {
    return Center(
      key: const ValueKey(3),
      child: Padding(
        padding: EdgeInsets.all(r.s(32)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(r.s(24)),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2979FF), Color(0xFF00B0FF)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.phone_android_rounded,
                  color: Colors.white, size: r.s(48)),
            ),
            SizedBox(height: r.s(24)),
            Text('SMS Ativado!',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: r.s(26),
                )),
            SizedBox(height: r.s(12)),
            Text(
              'O número ${_phone ?? ''} foi vinculado à sua conta. A partir de agora, você receberá um código por SMS ao fazer login.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textSecondary, fontSize: r.s(14)),
            ),
            SizedBox(height: r.s(40)),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: r.s(16)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r.s(14))),
                  backgroundColor: theme.accentPrimary,
                ),
                child: Text('Voltar às Configurações',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: r.s(15),
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widget: indicador de etapas ───────────────────────────
class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i + 1 == current;
        final done   = i + 1 < current;
        return Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: active ? r.s(28) : r.s(10),
              height: r.s(10),
              decoration: BoxDecoration(
                color: done || active
                    ? theme.accentPrimary
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(r.s(5)),
              ),
            ),
            if (i < total - 1) SizedBox(width: r.s(6)),
          ],
        );
      }),
    );
  }
}
