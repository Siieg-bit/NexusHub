import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../config/nexus_theme_data.dart';
import 'package:amino_clone/config/nexus_theme_extension.dart';

/// Tela de redefinição de senha.
///
/// Exibida após o usuário clicar no link de recuperação de senha enviado
/// por e-mail. Neste ponto, o Supabase já estabeleceu uma sessão temporária
/// (via [DeepLinkService._processAuthUri]), portanto podemos chamar
/// [updateUser] diretamente.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _success = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await SupabaseService.client.auth.updateUser(
        UserAttributes(password: _passwordController.text.trim()),
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _success = true;
      });
      // Aguardar 2 segundos e redirecionar para home
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) context.go('/');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = _mapError(e.toString());
      });
    }
  }

  String _mapError(String raw) {
    if (raw.contains('same_password')) {
      return 'A nova senha não pode ser igual à senha atual.';
    }
    if (raw.contains('weak_password') || raw.contains('Password should be')) {
      return 'A senha deve ter pelo menos 8 caracteres.';
    }
    if (raw.contains('session_not_found') || raw.contains('not authenticated')) {
      return 'Sessão expirada. Solicite um novo link de recuperação.';
    }
    return 'Ocorreu um erro. Tente novamente.';
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final r = context.r;
    final theme = context.nexusTheme;

    return Scaffold(
      backgroundColor: theme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: theme.textPrimary, size: r.s(20)),
          onPressed: () => context.go('/login'),
        ),
        title: Text(
          'Redefinir Senha',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: r.fs(17),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: r.s(24), vertical: r.s(32)),
          child: _success ? _buildSuccess(r, theme) : _buildForm(s, r, theme),
        ),
      ),
    );
  }

  Widget _buildSuccess(Responsive r, NexusThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: r.s(60)),
        Container(
          width: r.s(80),
          height: r.s(80),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_circle_rounded,
              color: Colors.green, size: r.s(48)),
        ),
        SizedBox(height: r.s(24)),
        Text(
          'Senha redefinida!',
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: r.fs(22),
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: r.s(12)),
        Text(
          'Sua senha foi alterada com sucesso.\nVocê será redirecionado em instantes.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: r.fs(14),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(dynamic s, Responsive r, NexusThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ícone de cadeado
          Center(
            child: Container(
              width: r.s(72),
              height: r.s(72),
              decoration: BoxDecoration(
                color: theme.accentPrimary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_reset_rounded,
                  color: theme.accentPrimary, size: r.s(40)),
            ),
          ),
          SizedBox(height: r.s(24)),
          Text(
            'Crie uma nova senha',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: r.fs(20),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: r.s(8)),
          Text(
            'Sua nova senha deve ter pelo menos 8 caracteres.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: r.fs(13),
            ),
          ),
          SizedBox(height: r.s(32)),

          // Campo: Nova senha
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(color: theme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Nova senha',
              labelStyle: TextStyle(color: theme.textSecondary),
              prefixIcon:
                  Icon(Icons.lock_rounded, color: theme.accentPrimary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: theme.textSecondary,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: theme.surfacePrimary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(12)),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(12)),
                borderSide:
                    BorderSide(color: theme.accentPrimary, width: 1.5),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Informe a nova senha';
              if (v.trim().length < 8) return 'Mínimo 8 caracteres';
              return null;
            },
          ),
          SizedBox(height: r.s(16)),

          // Campo: Confirmar senha
          TextFormField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            style: TextStyle(color: theme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Confirmar nova senha',
              labelStyle: TextStyle(color: theme.textSecondary),
              prefixIcon: Icon(Icons.lock_outline_rounded,
                  color: theme.accentPrimary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: theme.textSecondary,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              filled: true,
              fillColor: theme.surfacePrimary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(12)),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(r.s(12)),
                borderSide:
                    BorderSide(color: theme.accentPrimary, width: 1.5),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Confirme a nova senha';
              if (v.trim() != _passwordController.text.trim()) {
                return 'As senhas não coincidem';
              }
              return null;
            },
          ),
          SizedBox(height: r.s(12)),

          // Mensagem de erro
          if (_errorMessage != null) ...[
            Container(
              padding: EdgeInsets.all(r.s(12)),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(r.s(10)),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: Colors.red, size: r.s(18)),
                  SizedBox(width: r.s(8)),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                          color: Colors.red, fontSize: r.fs(13)),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.s(12)),
          ],

          SizedBox(height: r.s(8)),

          // Botão de confirmar
          SizedBox(
            height: r.s(50),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accentPrimary,
                disabledBackgroundColor:
                    theme.accentPrimary.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(r.s(14)),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? SizedBox(
                      width: r.s(22),
                      height: r.s(22),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Redefinir Senha',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: r.fs(15),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
