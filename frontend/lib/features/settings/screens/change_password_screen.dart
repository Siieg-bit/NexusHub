import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

// ── Utilitário de força de senha ─────────────────────────────────────────────

class _PasswordStrength {
  final int score; // 0-5
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

/// Tela de troca de senha com fluxo seguro:
///   1. Reautenticação com senha atual
///   2. Definir nova senha (com indicador de força + confirmação)
///   3. Aplicar via Supabase Auth + registrar no audit log
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState
    extends ConsumerState<ChangePasswordScreen> {
  // Etapas: 1 = reauth, 2 = nova senha, 3 = sucesso
  int _step = 1;

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _reauthFormKey = GlobalKey<FormState>();
  final _newPasswordFormKey = GlobalKey<FormState>();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _error;
  _PasswordStrength _strength = const _PasswordStrength(0, []);

  String get _currentEmail =>
      SupabaseService.client.auth.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_onNewPasswordChanged);
  }

  void _onNewPasswordChanged() {
    final s = _PasswordStrength.evaluate(_newPasswordController.text);
    if (s.score != _strength.score) {
      setState(() => _strength = s);
    }
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_onNewPasswordChanged);
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Etapa 1: Verificar senha atual ─────────────────────────────────────────
  Future<void> _verifyCurrentPassword() async {
    if (_reauthFormKey.currentState?.validate() != true) return;
    setState(() { _isLoading = true; _error = null; });

    try {
      // Verificar rate limit
      final rateCheck = await SupabaseService.rpc('check_auth_rate_limit',
          params: {'p_action': 'reauth'});
      if (rateCheck is Map && rateCheck['allowed'] == false) {
        setState(() {
          _error = 'Muitas tentativas. Aguarde antes de tentar novamente.';
          _isLoading = false;
        });
        return;
      }

      // Tentar login com a senha atual
      await SupabaseService.client.auth.signInWithPassword(
        email: _currentEmail,
        password: _currentPasswordController.text,
      );

      await SupabaseService.rpc('log_auth_event', params: {
        'p_event': 'reauth_success',
        'p_details': {'context': 'password_change'},
      });

      setState(() { _step = 2; _isLoading = false; });
    } catch (e) {
      try {
        await SupabaseService.rpc('log_auth_event', params: {
          'p_event': 'reauth_failed',
          'p_details': {'context': 'password_change'},
        });
      } catch (_) {}

      setState(() {
        _error = 'Senha incorreta. Verifique e tente novamente.';
        _isLoading = false;
      });
    }
  }

  // ── Etapa 2: Aplicar nova senha ────────────────────────────────────────────
  Future<void> _applyNewPassword() async {
    if (_newPasswordFormKey.currentState?.validate() != true) return;

    if (_strength.score < 3) {
      setState(() => _error = 'Sua senha é muito fraca. Melhore-a antes de continuar.');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      // Verificar rate limit para troca de senha
      final rateCheck = await SupabaseService.rpc('check_auth_rate_limit',
          params: {'p_action': 'password_change'});
      if (rateCheck is Map && rateCheck['allowed'] == false) {
        setState(() {
          _error = 'Limite de trocas de senha atingido. Aguarde antes de tentar novamente.';
          _isLoading = false;
        });
        return;
      }

      // Registrar no audit log antes de aplicar
      await SupabaseService.rpc('request_password_change');

      // Aplicar nova senha via Supabase Auth
      await SupabaseService.client.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );

      // Registrar evento de sucesso
      await SupabaseService.rpc('log_auth_event', params: {
        'p_event': 'password_changed',
        'p_details': {'strength_score': _strength.score},
      });

      setState(() { _step = 3; _isLoading = false; });
    } catch (e) {
      setState(() {
        _error = 'Erro ao alterar senha. Tente novamente.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Trocar Senha',
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
            duration: const Duration(milliseconds: 300),
            child: _step == 1
                ? _buildStep1(context, r, theme)
                : _step == 2
                    ? _buildStep2(context, r, theme)
                    : _buildStep3(context, r, theme),
          ),
        ),
      ),
    );
  }

  // ── UI: Etapa 1 — Confirmar senha atual ────────────────────────────────────
  Widget _buildStep1(BuildContext context, Responsive r, NexusThemeData theme) {
    return Form(
      key: _reauthFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIndicator(current: 1, total: 2, r: r, theme: theme),
          SizedBox(height: r.s(24)),
          _SectionHeader(
            icon: Icons.shield_outlined,
            title: 'Confirme sua identidade',
            subtitle: 'Por segurança, informe sua senha atual antes de definir uma nova.',
            r: r,
            theme: theme,
          ),
          TextFormField(
            controller: _currentPasswordController,
            obscureText: _obscureCurrent,
            style: TextStyle(color: theme.textPrimary, fontSize: r.fs(15)),
            decoration: _inputDecoration(
              hint: 'Senha atual',
              icon: Icons.lock_outline_rounded,
              theme: theme,
              r: r,
              suffix: IconButton(
                icon: Icon(
                  _obscureCurrent
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: theme.textHint,
                  size: r.s(20),
                ),
                onPressed: () =>
                    setState(() => _obscureCurrent = !_obscureCurrent),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Informe sua senha atual';
              return null;
            },
          ),
          SizedBox(height: r.s(12)),
          // Link "Esqueci minha senha"
          GestureDetector(
            onTap: () async {
              try {
                await SupabaseService.client.auth
                    .resetPasswordForEmail(_currentEmail);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        'E-mail de redefinição enviado para $_currentEmail'),
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              } catch (_) {}
            },
            child: Text(
              'Esqueci minha senha',
              style: TextStyle(
                color: theme.accentPrimary,
                fontSize: r.fs(13),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_error != null) ...[
            SizedBox(height: r.s(12)),
            _ErrorBox(message: _error!, r: r, theme: theme),
          ],
          SizedBox(height: r.s(24)),
          _PrimaryButton(
            label: 'Continuar',
            isLoading: _isLoading,
            onPressed: _verifyCurrentPassword,
            r: r,
            theme: theme,
          ),
        ],
      ),
    );
  }

  // ── UI: Etapa 2 — Nova senha ───────────────────────────────────────────────
  Widget _buildStep2(BuildContext context, Responsive r, NexusThemeData theme) {
    return Form(
      key: _newPasswordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIndicator(current: 2, total: 2, r: r, theme: theme),
          SizedBox(height: r.s(24)),
          _SectionHeader(
            icon: Icons.lock_reset_rounded,
            title: 'Nova senha',
            subtitle: 'Escolha uma senha forte com pelo menos 8 caracteres.',
            r: r,
            theme: theme,
          ),
          // Nova senha
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNew,
            style: TextStyle(color: theme.textPrimary, fontSize: r.fs(15)),
            decoration: _inputDecoration(
              hint: 'Nova senha',
              icon: Icons.lock_outline_rounded,
              theme: theme,
              r: r,
              suffix: IconButton(
                icon: Icon(
                  _obscureNew
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: theme.textHint,
                  size: r.s(20),
                ),
                onPressed: () =>
                    setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Defina uma nova senha';
              if (v.length < 8) return 'Mínimo 8 caracteres';
              if (!v.contains(RegExp(r'[A-Z]')))
                return 'Inclua pelo menos uma letra maiúscula';
              if (!v.contains(RegExp(r'[0-9]')))
                return 'Inclua pelo menos um número';
              if (v == _currentPasswordController.text)
                return 'A nova senha não pode ser igual à atual';
              return null;
            },
          ),

          // Indicador de força
          if (_newPasswordController.text.isNotEmpty) ...[
            SizedBox(height: r.s(8)),
            _PasswordStrengthIndicator(strength: _strength, r: r, theme: theme),
          ],

          SizedBox(height: r.s(14)),

          // Confirmar nova senha
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            style: TextStyle(color: theme.textPrimary, fontSize: r.fs(15)),
            decoration: _inputDecoration(
              hint: 'Confirmar nova senha',
              icon: Icons.lock_outline_rounded,
              theme: theme,
              r: r,
              suffix: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: theme.textHint,
                  size: r.s(20),
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Confirme a nova senha';
              if (v != _newPasswordController.text)
                return 'As senhas não coincidem';
              return null;
            },
          ),

          if (_error != null) ...[
            SizedBox(height: r.s(12)),
            _ErrorBox(message: _error!, r: r, theme: theme),
          ],
          SizedBox(height: r.s(24)),
          _PrimaryButton(
            label: 'Alterar Senha',
            isLoading: _isLoading,
            onPressed: _applyNewPassword,
            r: r,
            theme: theme,
          ),
        ],
      ),
    );
  }

  // ── UI: Etapa 3 — Sucesso ─────────────────────────────────────────────────
  Widget _buildStep3(BuildContext context, Responsive r, NexusThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: r.s(40)),
        Container(
          width: r.s(80),
          height: r.s(80),
          decoration: BoxDecoration(
            color: const Color(0xFF66BB6A).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_circle_outline_rounded,
              color: const Color(0xFF66BB6A), size: r.s(40)),
        ),
        SizedBox(height: r.s(24)),
        Text(
          'Senha alterada!',
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: r.fs(22),
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: r.s(12)),
        Text(
          'Sua senha foi alterada com sucesso. Use a nova senha no próximo login.',
          style: TextStyle(
              color: theme.textSecondary, fontSize: r.fs(14), height: 1.5),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: r.s(32)),
        _PrimaryButton(
          label: 'Voltar para Configurações',
          isLoading: false,
          onPressed: () => context.pop(),
          r: r,
          theme: theme,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required NexusThemeData theme,
    required Responsive r,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: theme.textHint, fontSize: r.fs(15)),
      prefixIcon: Icon(icon, color: theme.textHint, size: r.s(20)),
      suffixIcon: suffix,
      filled: true,
      fillColor: theme.surfacePrimary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r.s(14)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r.s(14)),
        borderSide: BorderSide(color: theme.textHint.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r.s(14)),
        borderSide: BorderSide(color: theme.accentPrimary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(r.s(14)),
        borderSide: BorderSide(color: theme.error),
      ),
      contentPadding:
          EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(16)),
    );
  }
}

// ── Widgets auxiliares ───────────────────────────────────────────────────────

class _PasswordStrengthIndicator extends StatelessWidget {
  final _PasswordStrength strength;
  final Responsive r;
  final NexusThemeData theme;

  const _PasswordStrengthIndicator(
      {required this.strength, required this.r, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(5, (i) {
            final filled = i < strength.score;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: r.s(4),
                margin: EdgeInsets.only(right: i < 4 ? r.s(4) : 0),
                decoration: BoxDecoration(
                  color: filled ? strength.color : theme.surfacePrimary,
                  borderRadius: BorderRadius.circular(r.s(4)),
                ),
              ),
            );
          }),
        ),
        SizedBox(height: r.s(6)),
        Row(
          children: [
            Text(strength.label,
                style: TextStyle(
                    color: strength.color,
                    fontSize: r.fs(12),
                    fontWeight: FontWeight.w600)),
            if (strength.missing.isNotEmpty) ...[
              Text('  •  ',
                  style: TextStyle(
                      color: theme.textHint, fontSize: r.fs(12))),
              Expanded(
                child: Text(
                  'Falta: ${strength.missing.first}',
                  style: TextStyle(
                      color: theme.textHint, fontSize: r.fs(12)),
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

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  final Responsive r;
  final NexusThemeData theme;

  const _StepIndicator(
      {required this.current,
      required this.total,
      required this.r,
      required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i + 1 <= current;
        return Expanded(
          child: Container(
            height: r.s(4),
            margin: EdgeInsets.only(right: i < total - 1 ? r.s(6) : 0),
            decoration: BoxDecoration(
              color: active
                  ? theme.accentPrimary
                  : theme.textHint.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(r.s(4)),
            ),
          ),
        );
      }),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Responsive r;
  final NexusThemeData theme;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.r,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: theme.accentPrimary, size: r.s(22)),
            SizedBox(width: r.s(8)),
            Text(title,
                style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: r.fs(18),
                    fontWeight: FontWeight.w700)),
          ],
        ),
        SizedBox(height: r.s(8)),
        Text(subtitle,
            style: TextStyle(
                color: theme.textSecondary, fontSize: r.fs(13), height: 1.4)),
        SizedBox(height: r.s(16)),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final Responsive r;
  final NexusThemeData theme;

  const _ErrorBox(
      {required this.message, required this.r, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(r.s(12)),
      decoration: BoxDecoration(
        color: theme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(r.s(10)),
        border: Border.all(color: theme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: theme.error, size: r.s(18)),
          SizedBox(width: r.s(8)),
          Expanded(
            child: Text(message,
                style: TextStyle(color: theme.error, fontSize: r.fs(13))),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;
  final Responsive r;
  final NexusThemeData theme;

  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    required this.r,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: r.s(52),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.accentPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: theme.accentPrimary.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(r.s(14))),
          textStyle: TextStyle(
              fontSize: r.fs(16), fontWeight: FontWeight.w700),
        ),
        child: isLoading
            ? SizedBox(
                width: r.s(20),
                height: r.s(20),
                child: const CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(label),
      ),
    );
  }
}
