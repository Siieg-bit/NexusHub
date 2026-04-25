import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pinput/pinput.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

/// Tela de configuração do TOTP (App Autenticador).
/// Fluxo: Enroll → QR Code → Verificar código → Backup codes → Concluído
class TotpSetupScreen extends ConsumerStatefulWidget {
  const TotpSetupScreen({super.key});

  @override
  ConsumerState<TotpSetupScreen> createState() => _TotpSetupScreenState();
}

class _TotpSetupScreenState extends ConsumerState<TotpSetupScreen> {
  int _step = 0; // 0=loading, 1=qr, 2=verify, 3=backup, 4=done

  // Dados do enroll
  String? _factorId;
  String? _totpUri;
  String? _secret;

  // Verificação
  final _codeCtrl = TextEditingController();
  bool _isVerifying = false;
  String? _verifyError;

  // Backup codes
  List<String> _backupCodes = [];
  bool _backupSaved = false;
  bool _isSavingBackup = false;

  @override
  void initState() {
    super.initState();
    _enrollTotp();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  /// Chama o Supabase MFA enroll para obter o QR code e o secret.
  Future<void> _enrollTotp() async {
    try {
      final response = await SupabaseService.client.auth.mfa.enroll(
        factorType: FactorType.totp,
      );
      setState(() {
        _factorId = response.id;
        _totpUri  = response.totp.qrCode;
        _secret   = response.totp.secret;
        _step     = 1;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao iniciar configuração: $e')),
        );
        context.pop();
      }
    }
  }

  /// Verifica o código TOTP inserido pelo usuário.
  Future<void> _verifyCode() async {
    if (_codeCtrl.text.length != 6) return;
    setState(() { _isVerifying = true; _verifyError = null; });

    try {
      // 1. Cria o challenge
      final challengeRes = await SupabaseService.client.auth.mfa.challenge(
        factorId: _factorId!,
      );

      // 2. Verifica o código
      await SupabaseService.client.auth.mfa.verify(
        factorId:    _factorId!,
        challengeId: challengeRes.id,
        code:        _codeCtrl.text.trim(),
      );

      // 3. Gera backup codes e salva no banco
      _backupCodes = _generateBackupCodes();
      await SupabaseService.rpc('enable_totp_2fa', params: {
        'p_factor_id':    _factorId,
        'p_backup_codes': _backupCodes,
      });

      setState(() { _step = 3; _isVerifying = false; });
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _verifyError = 'Código inválido. Verifique o app e tente novamente.';
      });
    }
  }

  /// Gera 8 backup codes aleatórios no formato XXXX-XXXX.
  List<String> _generateBackupCodes() {
    final rng = Random.secure();
    return List.generate(8, (_) {
      final a = rng.nextInt(9000) + 1000;
      final b = rng.nextInt(9000) + 1000;
      return '$a-$b';
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    final theme = context.nexusTheme;

    return Scaffold(
      backgroundColor: context.nexusTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: context.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: theme.textPrimary, size: r.s(20)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Configurar App Autenticador',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: r.s(18),
          ),
        ),
      ),
      body: _buildStep(context, r, theme),
    );
  }

  Widget _buildStep(BuildContext context, Responsive r, NexusThemeData theme) {
    switch (_step) {
      case 0: return const Center(child: CircularProgressIndicator());
      case 1: return _buildQrStep(context, r, theme);
      case 2: return _buildVerifyStep(context, r, theme);
      case 3: return _buildBackupStep(context, r, theme);
      case 4: return _buildDoneStep(context, r, theme);
      default: return const SizedBox();
    }
  }

  // ── Etapa 1: QR Code ──────────────────────────────────
  Widget _buildQrStep(BuildContext context, Responsive r, NexusThemeData theme) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(r.s(24)),
      child: Column(
        children: [
          _StepIndicator(current: 1, total: 3),
          SizedBox(height: r.s(24)),

          Text('Escaneie o QR Code',
              style: TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: r.s(22),
              )),
          SizedBox(height: r.s(8)),
          Text(
            'Abra o Google Authenticator, Authy ou qualquer app compatível e escaneie o código abaixo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.textSecondary, fontSize: r.s(14)),
          ),
          SizedBox(height: r.s(32)),

          // QR Code
          Container(
            padding: EdgeInsets.all(r.s(16)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(r.s(20)),
            ),
            child: QrImageView(
              data: _totpUri ?? '',
              version: QrVersions.auto,
              size: r.s(200),
              backgroundColor: Colors.white,
            ),
          ),

          SizedBox(height: r.s(24)),

          // Secret manual
          Container(
            padding: EdgeInsets.all(r.s(16)),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(r.s(16)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Column(
              children: [
                Text('Não consegue escanear?',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: r.s(13),
                    )),
                SizedBox(height: r.s(6)),
                Text('Insira este código manualmente no app:',
                    style: TextStyle(
                        color: theme.textSecondary, fontSize: r.s(12))),
                SizedBox(height: r.s(10)),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _secret ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Código copiado!')),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: r.s(16), vertical: r.s(10)),
                    decoration: BoxDecoration(
                      color: theme.accentPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(r.s(12)),
                      border: Border.all(
                          color: theme.accentPrimary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _secret ?? '',
                          style: TextStyle(
                            color: theme.accentPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: r.s(14),
                            letterSpacing: 2,
                            fontFamily: 'monospace',
                          ),
                        ),
                        SizedBox(width: r.s(8)),
                        Icon(Icons.copy_rounded,
                            color: theme.accentPrimary, size: r.s(16)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: r.s(32)),

          // Botão próximo
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() => _step = 2),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: r.s(16)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.s(14))),
                backgroundColor: theme.accentPrimary,
              ),
              child: Text('Já escaneei — Continuar',
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

  // ── Etapa 2: Verificar código ─────────────────────────
  Widget _buildVerifyStep(BuildContext context, Responsive r, NexusThemeData theme) {
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
      padding: EdgeInsets.all(r.s(24)),
      child: Column(
        children: [
          _StepIndicator(current: 2, total: 3),
          SizedBox(height: r.s(24)),

          Text('Verificar Código',
              style: TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: r.s(22),
              )),
          SizedBox(height: r.s(8)),
          Text(
            'Insira o código de 6 dígitos gerado pelo app autenticador para confirmar a configuração.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.textSecondary, fontSize: r.s(14)),
          ),
          SizedBox(height: r.s(40)),

          Pinput(
            controller: _codeCtrl,
            length: 6,
            defaultPinTheme: pinTheme,
            focusedPinTheme: pinTheme.copyDecorationWith(
              border: Border.all(color: theme.accentPrimary, width: 2),
            ),
            errorPinTheme: pinTheme.copyDecorationWith(
              border: Border.all(color: theme.error, width: 2),
            ),
            keyboardType: TextInputType.number,
            onCompleted: (_) => _verifyCode(),
          ),

          if (_verifyError != null) ...[
            SizedBox(height: r.s(12)),
            Text(_verifyError!,
                style: TextStyle(color: theme.error, fontSize: r.s(13))),
          ],

          SizedBox(height: r.s(32)),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isVerifying ? null : _verifyCode,
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

          SizedBox(height: r.s(16)),
          GestureDetector(
            onTap: () => setState(() { _step = 1; _codeCtrl.clear(); _verifyError = null; }),
            child: Text('Voltar e escanear novamente',
                style: TextStyle(
                    color: theme.accentPrimary, fontSize: r.s(13))),
          ),
        ],
      ),
    );
  }

  // ── Etapa 3: Backup codes ─────────────────────────────
  Widget _buildBackupStep(BuildContext context, Responsive r, NexusThemeData theme) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(r.s(24)),
      child: Column(
        children: [
          _StepIndicator(current: 3, total: 3),
          SizedBox(height: r.s(24)),

          Icon(Icons.backup_rounded,
              color: theme.accentPrimary, size: r.s(48)),
          SizedBox(height: r.s(12)),
          Text('Salve seus Códigos de Recuperação',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: r.s(20),
              )),
          SizedBox(height: r.s(8)),
          Text(
            'Se você perder acesso ao app autenticador, use um destes códigos para entrar. Cada código pode ser usado apenas uma vez.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.textSecondary, fontSize: r.s(13)),
          ),
          SizedBox(height: r.s(24)),

          // Grid de backup codes
          Container(
            padding: EdgeInsets.all(r.s(16)),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(r.s(16)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Column(
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 3.5,
                    crossAxisSpacing: r.s(8),
                    mainAxisSpacing: r.s(8),
                  ),
                  itemCount: _backupCodes.length,
                  itemBuilder: (_, i) => Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.accentPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(r.s(8)),
                    ),
                    child: Text(
                      _backupCodes[i],
                      style: TextStyle(
                        color: theme.accentPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: r.s(13),
                        fontFamily: 'monospace',
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: r.s(12)),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: _backupCodes.join('\n')));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Códigos copiados para a área de transferência!')),
                    );
                    setState(() => _backupSaved = true);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.copy_rounded,
                          color: theme.accentPrimary, size: r.s(16)),
                      SizedBox(width: r.s(6)),
                      Text('Copiar todos',
                          style: TextStyle(
                              color: theme.accentPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: r.s(13))),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: r.s(16)),

          // Checkbox de confirmação
          GestureDetector(
            onTap: () => setState(() => _backupSaved = !_backupSaved),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: r.s(22),
                  height: r.s(22),
                  decoration: BoxDecoration(
                    color: _backupSaved
                        ? theme.accentPrimary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(r.s(6)),
                    border: Border.all(
                      color: _backupSaved
                          ? theme.accentPrimary
                          : Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: _backupSaved
                      ? Icon(Icons.check_rounded,
                          color: Colors.white, size: r.s(14))
                      : null,
                ),
                SizedBox(width: r.s(10)),
                Expanded(
                  child: Text(
                    'Salvei os códigos em um lugar seguro',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: r.s(13),
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
              onPressed: _backupSaved && !_isSavingBackup
                  ? () => setState(() => _step = 4)
                  : null,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: r.s(16)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(r.s(14))),
                backgroundColor: theme.accentPrimary,
                disabledBackgroundColor:
                    theme.accentPrimary.withValues(alpha: 0.4),
              ),
              child: Text('Concluir Configuração',
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

  // ── Etapa 4: Concluído ────────────────────────────────
  Widget _buildDoneStep(BuildContext context, Responsive r, NexusThemeData theme) {
    return Padding(
      padding: EdgeInsets.all(r.s(32)),
      child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(r.s(24)),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00C853), Color(0xFF1DE9B6)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.verified_user_rounded,
                color: Colors.white, size: r.s(48)),
          ),
          SizedBox(height: r.s(24)),
          Text('2FA Ativado!',
              style: TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: r.s(26),
              )),
          SizedBox(height: r.s(12)),
          Text(
            'O app autenticador foi configurado com sucesso. A partir de agora, você precisará inserir um código ao fazer login.',
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
    ));
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
