import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

/// Tela de Contas Vinculadas — Google, Apple e outros provedores OAuth.
class LinkedAccountsScreen extends StatefulWidget {
  const LinkedAccountsScreen({super.key});

  @override
  State<LinkedAccountsScreen> createState() => _LinkedAccountsScreenState();
}

class _LinkedAccountsScreenState extends State<LinkedAccountsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _identities = [];
  bool _isLinking = false;

  @override
  void initState() {
    super.initState();
    _loadIdentities();
  }

  Future<void> _loadIdentities() async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user != null) {
        setState(() {
          _identities = (user.identities ?? [])
              .map((i) => {
                    'provider': i.provider,
                    'created_at': i.createdAt,
                    'id': i.id,
                  })
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  bool _isProviderLinked(String provider) {
    return _identities.any((i) => i['provider'] == provider);
  }

  Future<void> _linkGoogle() async {
    setState(() => _isLinking = true);
    try {
      await SupabaseService.client.auth.linkIdentity(
        OAuthProvider.google,
      );
      await _loadIdentities();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conta Google vinculada com sucesso!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao vincular Google: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }

  Future<void> _linkApple() async {
    setState(() => _isLinking = true);
    try {
      await SupabaseService.client.auth.linkIdentity(
        OAuthProvider.apple,
      );
      await _loadIdentities();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conta Apple vinculada com sucesso!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao vincular Apple: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }

  Future<void> _unlinkProvider(String provider) async {
    if (_identities.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Não é possível desvincular a única forma de login.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceColor,
        title: Text('Desvincular conta',
            style: TextStyle(color: context.textPrimary)),
        content: Text(
          'Tem certeza que deseja desvincular sua conta $provider?',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desvincular',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLinking = true);
    try {
      final identity =
          _identities.firstWhere((i) => i['provider'] == provider);
      await SupabaseService.client.auth.unlinkIdentity(
        UserIdentity(
          id: identity['id'] as String,
          userId: SupabaseService.currentUserId ?? '',
          identityData: const {},
          provider: provider,
          lastSignInAt: DateTime.now().toIso8601String(),
          createdAt: (identity['created_at'] as DateTime?)
              ?.toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        ),
      );
      await _loadIdentities();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conta $provider desvinculada.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao desvincular: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLinking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textPrimary),
        title: Text(
          'Contas Vinculadas',
          style: TextStyle(
              color: context.textPrimary, fontWeight: FontWeight.w800),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(r.s(16)),
              children: [
                Container(
                  padding: EdgeInsets.all(r.s(16)),
                  decoration: BoxDecoration(
                    color: context.surfaceColor,
                    borderRadius: BorderRadius.circular(r.s(16)),
                  ),
                  child: Text(
                    'Vincule suas contas de redes sociais para fazer login mais facilmente no NexusHub.',
                    style: TextStyle(
                        color: Colors.grey[400], fontSize: r.fs(13)),
                  ),
                ),
                SizedBox(height: r.s(20)),
                _buildProviderTile(
                  r: r,
                  provider: 'google',
                  label: 'Google',
                  icon: Icons.g_mobiledata_rounded,
                  color: Colors.red,
                  onLink: _linkGoogle,
                ),
                SizedBox(height: r.s(12)),
                _buildProviderTile(
                  r: r,
                  provider: 'apple',
                  label: 'Apple',
                  icon: Icons.apple_rounded,
                  color: Colors.white,
                  onLink: _linkApple,
                ),
                SizedBox(height: r.s(12)),
                _buildProviderTile(
                  r: r,
                  provider: 'email',
                  label: 'E-mail / Senha',
                  icon: Icons.email_rounded,
                  color: AppTheme.primaryColor,
                  onLink: null, // E-mail é gerenciado nas configurações de conta
                ),
              ],
            ),
    );
  }

  Widget _buildProviderTile({
    required Responsive r,
    required String provider,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onLink,
  }) {
    final isLinked = _isProviderLinked(provider);
    return Container(
      padding: EdgeInsets.all(r.s(16)),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(r.s(16)),
        border: Border.all(
          color: isLinked
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: r.s(44),
            height: r.s(44),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: r.s(24)),
          ),
          SizedBox(width: r.s(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: r.fs(15),
                  ),
                ),
                Text(
                  isLinked ? 'Vinculado' : 'Não vinculado',
                  style: TextStyle(
                    color: isLinked ? Colors.green : Colors.grey[600],
                    fontSize: r.fs(12),
                  ),
                ),
              ],
            ),
          ),
          if (provider != 'email')
            _isLinking
                ? SizedBox(
                    width: r.s(20),
                    height: r.s(20),
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryColor)),
                  )
                : isLinked
                    ? TextButton(
                        onPressed: () => _unlinkProvider(provider),
                        child: Text(
                          'Desvincular',
                          style: TextStyle(
                              color: Colors.red, fontSize: r.fs(13)),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: onLink,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: EdgeInsets.symmetric(
                              horizontal: r.s(16), vertical: r.s(8)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(r.s(20)),
                          ),
                        ),
                        child: Text('Vincular',
                            style: TextStyle(fontSize: r.fs(13))),
                      ),
        ],
      ),
    );
  }
}
