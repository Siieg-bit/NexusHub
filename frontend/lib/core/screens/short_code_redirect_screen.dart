import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_theme.dart';
import '../services/deep_link_service.dart';

/// Tela de redirecionamento para short codes de URLs curtas.
///
/// Exibida brevemente enquanto o short code é resolvido via RPC.
/// Após resolução, navega para a tela correta. Em caso de erro,
/// exibe mensagem e permite voltar.
class ShortCodeRedirectScreen extends StatefulWidget {
  /// Tipo do recurso: 'post', 'wiki', 'chat', 'user', 'community', 'sticker_pack', 'invite'
  final String type;

  /// O código curto ou ID a ser resolvido.
  final String code;

  const ShortCodeRedirectScreen({
    super.key,
    required this.type,
    required this.code,
  });

  @override
  State<ShortCodeRedirectScreen> createState() =>
      _ShortCodeRedirectScreenState();
}

class _ShortCodeRedirectScreenState extends State<ShortCodeRedirectScreen> {
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      // Delegar ao DeepLinkService que já sabe resolver cada tipo
      final handled = DeepLinkService.handleDeepLink(
        'nexushub://${widget.type}/${widget.code}',
      );
      if (!handled) {
        // Tentar resolver via RPC diretamente
        final result = await Supabase.instance.client
            .rpc('resolve_short_url', params: {'p_code': widget.code});
        if (!mounted) return;
        if (result != null && result is List && result.isNotEmpty) {
          final row = result.first as Map<String, dynamic>;
          final type = row['type'] as String? ?? '';
          final targetId = row['target_id'] as String? ?? '';
          _navigateByType(type, targetId);
        } else {
          setState(() => _error = true);
        }
      }
      // Se handled == true, o DeepLinkService já navegou via _router
    } catch (e) {
      debugPrint('[ShortCodeRedirect] Erro: $e');
      if (mounted) setState(() => _error = true);
    }
  }

  void _navigateByType(String type, String targetId) {
    if (!mounted) return;
    switch (type) {
      case 'post':
      case 'blog':
        context.go('/post/$targetId');
        break;
      case 'wiki':
        context.go('/wiki/$targetId');
        break;
      case 'chat':
        context.go('/chat/$targetId');
        break;
      case 'user':
      case 'profile':
        context.go('/user/$targetId');
        break;
      case 'community':
        context.go('/community/$targetId');
        break;
      case 'sticker_pack':
        context.go('/stickers/pack/$targetId');
        break;
      default:
        context.go('/explore');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Center(
        child: _error
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link_off_rounded,
                      size: 48, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  Text(
                    'Link não encontrado',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'O conteúdo pode ter sido removido.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => context.go('/explore'),
                    child: const Text('Voltar ao início',
                        style: TextStyle(color: AppTheme.primaryColor)),
                  ),
                ],
              )
            : const CircularProgressIndicator(
                color: AppTheme.primaryColor,
                strokeWidth: 2,
              ),
      ),
    );
  }
}
