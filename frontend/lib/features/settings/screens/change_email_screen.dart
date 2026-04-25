import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Tela de troca de e-mail com fluxo seguro:
///   1. Reautenticação com senha atual
///   2. Informar novo e-mail (validação de formato + duplicidade via RPC)
///   3. Supabase envia confirmação para o e-mail ANTIGO e para o NOVO
///   4. Ambos precisam confirmar para a troca ser efetivada
class ChangeEmailScreen extends ConsumerStatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  ConsumerState<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends ConsumerState<ChangeEmailScreen> {
  // Etapas: 1 = reauth, 2 = novo email, 3 = confirmação enviada
  int _step = 1;

  final _passwordController = TextEditingController();
  final _newEmailController = TextEditingController();
  final _passwordFormKey = GlobalKey<FormState>();
  final _emailFormKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  String get _currentEmail =>
      SupabaseService.client.auth.currentUser?.email ?? '';

  @override
  void dispose() {
    _passwordController.dispose();
    _newEmailController.dispose();
    super.dispose();
  }

  // ── Etapa 1: Reautenticar com senha ────────────────────────────────────────
  Future<void> _verifyPassword() async {
    if (_passwordFormKey.currentState?.validate() != true) return;
    setState(() { _isLoading = true; _error = null; });

    try {
      // Verificar rate limit antes de tentar
      final rateCheck = await SupabaseService.rpc('check_auth_rate_limit',
          params: {'p_action': 'reauth'});
      if (rateCheck is Map && rateCheck['allowed'] == false) {
        final blockedUntil = rateCheck['blocked_until'];
        setState(() {
          _error = 'Muitas tentativas. Tente novamente após $blockedUntil.';
          _isLoading = false;
        });
        return;
      }

      // Tentar login com a senha fornecida
      await SupabaseService.client.auth.signInWithPassword(
        email: _currentEmail,
        password: _passwordController.text,
      );

      // Registrar evento de reauth bem-sucedida
      await SupabaseService.rpc('log_auth_event', params: {
        'p_event': 'reauth_success',
        'p_details': {'context': 'email_change'},
      });

      setState(() { _step = 2; _isLoading = false; });
    } catch (e) {
      // Registrar falha de reauth
      try {
        await SupabaseService.rpc('log_auth_event', params: {
          'p_event': 'reauth_failed',
          'p_details': {'context': 'email_change'},
        });
      } catch (_) {}

      setState(() {
        _error = 'Senha incorreta. Verifique e tente novamente.';
        _isLoading = false;
      });
    }
  }

  // ── Etapa 2: Solicitar troca de e-mail ─────────────────────────────────────
  Future<void> _requestEmailChange() async {
    if (_emailFormKey.currentState?.validate() != true) return;
    setState(() { _isLoading = true; _error = null; });

    final newEmail = _newEmailController.text.trim();

    try {
      // Verificar rate limit e duplicidade via RPC
      final result = await SupabaseService.rpc('request_email_change',
          params: {'p_new_email': newEmail});

      if (result is Map && result['success'] == false) {
        final errorCode = result['error'] as String?;
        String msg;
        switch (errorCode) {
          case 'rate_limited':
            msg = 'Limite de tentativas atingido. Aguarde antes de tentar novamente.';
            break;
          case 'same_email':
            msg = 'O novo e-mail é igual ao atual.';
            break;
          case 'email_already_in_use':
            msg = 'Este e-mail já está sendo usado por outra conta.';
            break;
          default:
            msg = 'Erro ao processar a solicitação. Tente novamente.';
        }
        setState(() { _error = msg; _isLoading = false; });
        return;
      }

      // Chamar Supabase Auth para enviar os e-mails de confirmação
      await SupabaseService.client.auth.updateUser(
        UserAttributes(email: newEmail),
      );

      setState(() { _step = 3; _isLoading = false; });
    } catch (e) {
      setState(() {
        _error = 'Erro ao solicitar troca de e-mail. Tente novamente.';
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
          'Trocar E-mail',
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

  // ── UI: Etapa 1 — Confirmar senha ──────────────────────────────────────────
  Widget _buildStep1(BuildContext context, ResponsiveHelper r, NexusThemeExtension theme) {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIndicator(current: 1, total: 2, r: r, theme: theme),
          SizedBox(height: r.s(24)),
          _SectionHeader(
            icon: Icons.lock_outline_rounded,
            title: 'Confirme sua identidade',
            subtitle: 'Por segurança, informe sua senha atual antes de trocar o e-mail.',
            r: r,
            theme: theme,
          ),
          SizedBox(height: r.s(8)),
          // E-mail atual (somente leitura)
          _InfoRow(
            label: 'E-mail atual',
            value: _currentEmail,
            r: r,
            theme: theme,
          ),
          SizedBox(height: r.s(20)),
          // Campo de senha
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(color: theme.textPrimary, fontSize: r.fs(15)),
            decoration: _inputDecoration(
              hint: 'Senha atual',
              icon: Icons.lock_outline_rounded,
              theme: theme,
              r: r,
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: theme.textHint,
                  size: r.s(20),
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Informe sua senha atual';
              if (v.length < 6) return 'Senha muito curta';
              return null;
            },
          ),
          if (_error != null) ...[
            SizedBox(height: r.s(12)),
            _ErrorBox(message: _error!, r: r, theme: theme),
          ],
          SizedBox(height: r.s(24)),
          _PrimaryButton(
            label: 'Continuar',
            isLoading: _isLoading,
            onPressed: _verifyPassword,
            r: r,
            theme: theme,
          ),
        ],
      ),
    );
  }

  // ── UI: Etapa 2 — Novo e-mail ──────────────────────────────────────────────
  Widget _buildStep2(BuildContext context, ResponsiveHelper r, NexusThemeExtension theme) {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIndicator(current: 2, total: 2, r: r, theme: theme),
          SizedBox(height: r.s(24)),
          _SectionHeader(
            icon: Icons.email_outlined,
            title: 'Novo e-mail',
            subtitle:
                'Enviaremos um link de confirmação para o e-mail antigo e para o novo. Ambos precisam confirmar.',
            r: r,
            theme: theme,
          ),
          SizedBox(height: r.s(20)),
          TextFormField(
            controller: _newEmailController,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            style: TextStyle(color: theme.textPrimary, fontSize: r.fs(15)),
            decoration: _inputDecoration(
              hint: 'Novo e-mail',
              icon: Icons.email_outlined,
              theme: theme,
              r: r,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Informe o novo e-mail';
              final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
              if (!emailRegex.hasMatch(v.trim()))
                return 'Formato de e-mail inválido';
              if (v.trim().toLowerCase() == _currentEmail.toLowerCase())
                return 'O novo e-mail é igual ao atual';
              return null;
            },
          ),
          SizedBox(height: r.s(12)),
          // Aviso de segurança
          Container(
            padding: EdgeInsets.all(r.s(12)),
            decoration: BoxDecoration(
              color: theme.accentPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(r.s(10)),
              border: Border.all(
                  color: theme.accentPrimary.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    color: theme.accentPrimary, size: r.s(18)),
                SizedBox(width: r.s(8)),
                Expanded(
                  child: Text(
                    'A troca só será efetivada após você confirmar nos dois e-mails. Até lá, seu e-mail atual permanece ativo.',
                    style: TextStyle(
                        color: theme.textSecondary, fontSize: r.fs(13)),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            SizedBox(height: r.s(12)),
            _ErrorBox(message: _error!, r: r, theme: theme),
          ],
          SizedBox(height: r.s(24)),
          _PrimaryButton(
            label: 'Enviar confirmação',
            isLoading: _isLoading,
            onPressed: _requestEmailChange,
            r: r,
            theme: theme,
          ),
        ],
      ),
    );
  }

  // ── UI: Etapa 3 — Confirmação enviada ─────────────────────────────────────
  Widget _buildStep3(BuildContext context, ResponsiveHelper r, NexusThemeExtension theme) {
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
          child: Icon(Icons.mark_email_read_outlined,
              color: const Color(0xFF66BB6A), size: r.s(40)),
        ),
        SizedBox(height: r.s(24)),
        Text(
          'Confirmação enviada!',
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: r.fs(22),
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: r.s(12)),
        Text(
          'Enviamos links de confirmação para:\n\n'
          '$_currentEmail  (e-mail atual)\n'
          '${_newEmailController.text.trim()}  (e-mail novo)\n\n'
          'Abra os dois e-mails e clique nos links para confirmar a troca. Verifique também a caixa de spam.',
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
    required NexusThemeExtension theme,
    required ResponsiveHelper r,
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

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  final ResponsiveHelper r;
  final NexusThemeExtension theme;

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
  final ResponsiveHelper r;
  final NexusThemeExtension theme;

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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final ResponsiveHelper r;
  final NexusThemeExtension theme;

  const _InfoRow(
      {required this.label,
      required this.value,
      required this.r,
      required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: r.s(16), vertical: r.s(12)),
      decoration: BoxDecoration(
        color: theme.surfacePrimary,
        borderRadius: BorderRadius.circular(r.s(12)),
      ),
      child: Row(
        children: [
          Text('$label: ',
              style: TextStyle(
                  color: theme.textHint, fontSize: r.fs(13))),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: r.fs(14),
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final ResponsiveHelper r;
  final NexusThemeExtension theme;

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
  final ResponsiveHelper r;
  final NexusThemeExtension theme;

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
