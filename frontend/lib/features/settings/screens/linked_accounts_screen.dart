import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
                    'identity_id': i.identityId,
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

  Future<void> _linkProvider(OAuthProvider provider) async {
    setState(() => _isLinking = true);
    try {
      final res = await SupabaseService.client.auth.getLinkIdentityUrl(
        provider,
      );
      // Abre a URL de vinculação no navegador
      await SupabaseService.client.auth.getSessionFromUrl(Uri.parse(res.url));
      await _loadIdentities();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conta ${provider.name} vinculada com sucesso!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao vincular ${provider.name}. Tente novamente.'),
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
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
    if (!mounted) return;

    if (confirm != true) return;

    setState(() => _isLinking = true);
    try {
      final identity =
          _identities.firstWhere((i) => i['provider'] == provider);
      await SupabaseService.client.auth.unlinkIdentity(
        UserIdentity(
          id: identity['id'] as String? ?? '',
          userId: SupabaseService.currentUserId ?? '',
          identityData: const {},
          identityId: identity['identity_id'] as String? ?? '',
          provider: provider,
          createdAt: (identity['created_at'] as DateTime?)
              ?.toIso8601String(),
          lastSignInAt: DateTime.now().toIso8601String(),
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
            content: Text('Erro ao desvincular. Tente novamente.'),
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
            color: context.textPrimary,
            fontSize: r.fs(18),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(r.s(16)),
              children: [
                Text(
                  'Vincule suas contas sociais para fazer login mais facilmente.',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: r.fs(14),
                  ),
                ),
                SizedBox(height: r.s(24)),
                _ProviderTile(
                  provider: 'google',
                  label: 'Google',
                  icon: Icons.g_mobiledata_rounded,
                  isLinked: _isProviderLinked('google'),
                  isLoading: _isLinking,
                  onLink: () => _linkProvider(OAuthProvider.google),
                  onUnlink: () => _unlinkProvider('google'),
                ),
                SizedBox(height: r.s(12)),
                _ProviderTile(
                  provider: 'apple',
                  label: 'Apple',
                  icon: Icons.apple_rounded,
                  isLinked: _isProviderLinked('apple'),
                  isLoading: _isLinking,
                  onLink: () => _linkProvider(OAuthProvider.apple),
                  onUnlink: () => _unlinkProvider('apple'),
                ),
              ],
            ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  final String provider;
  final String label;
  final IconData icon;
  final bool isLinked;
  final bool isLoading;
  final VoidCallback onLink;
  final VoidCallback onUnlink;

  const _ProviderTile({
    required this.provider,
    required this.label,
    required this.icon,
    required this.isLinked,
    required this.isLoading,
    required this.onLink,
    required this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.r;
    return Container(
      padding: EdgeInsets.all(r.s(16)),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(r.s(12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: r.s(28), color: context.textPrimary),
          SizedBox(width: r.s(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: r.fs(16),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  isLinked ? 'Vinculado' : 'Não vinculado',
                  style: TextStyle(
                    color: isLinked ? AppTheme.primaryColor : Colors.grey[500],
                    fontSize: r.fs(12),
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            SizedBox(
              width: r.s(20),
              height: r.s(20),
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton(
              onPressed: isLinked ? onUnlink : onLink,
              child: Text(
                isLinked ? 'Desvincular' : 'Vincular',
                style: TextStyle(
                  color: isLinked ? AppTheme.errorColor : AppTheme.primaryColor,
                  fontSize: r.fs(14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
