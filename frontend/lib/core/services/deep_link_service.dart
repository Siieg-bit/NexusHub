import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Serviço de Deep Links e URLs Curtas do NexusHub.
///
/// ## Padrão de URLs
/// | Prefixo | Tipo         | Exemplo                          |
/// |---------|--------------|----------------------------------|
/// | /u/     | Perfil       | nexushub.app/u/crystopher        |
/// | /c/     | Comunidade   | nexushub.app/c/anime-br          |
/// | /p/     | Post / Blog  | nexushub.app/p/xK9mZ             |
/// | /w/     | Wiki         | nexushub.app/w/aB3nQ             |
/// | /ch/    | Chat público | nexushub.app/ch/yT7pL            |
/// | /s/     | Sticker pack | nexushub.app/s/mN2kR             |
/// | /i/     | Convite      | nexushub.app/i/abc123            |
class DeepLinkService {
  DeepLinkService._();

  static const String _baseUrl = 'https://nexushub.app';

  static GoRouter? _router;
  static StreamSubscription? _authSubscription;
  static StreamSubscription? _linkSubscription;

  /// Inicializa o serviço com o router do app.
  static void init(GoRouter router) {
    _router = router;
    _listenToAuthDeepLinks();
    _listenToIncomingLinks();
  }

  /// Cancela subscriptions para evitar memory leaks.
  static void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }

  /// Escuta deep links de autenticação do Supabase (magic link, OAuth callback).
  static void _listenToAuthDeepLinks() {
    _authSubscription?.cancel();
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        // Após login via deep link, navegar para home
        _router?.go('/');
      }
    });
  }

  /// Escuta links recebidos enquanto o app está aberto ou em background.
  static void _listenToIncomingLinks() {
    _linkSubscription?.cancel();
    final appLinks = AppLinks();

    // Link recebido com o app já aberto
    _linkSubscription = appLinks.uriLinkStream.listen((uri) {
      _processUri(uri);
    }, onError: (e) {
      debugPrint('DeepLink: Erro ao receber link: $e');
    });

    // Link que abriu o app (cold start)
    appLinks.getInitialLink().then((uri) {
      if (uri != null) _processUri(uri);
    }).catchError((e) {
      debugPrint('DeepLink: Erro ao obter link inicial: $e');
    });
  }

  static Future<void> _processUri(Uri uri) async {
    // Auth URIs do Supabase (confirmação de email, magic link)
    if (_isAuthUri(uri)) {
      await _processAuthUri(uri);
      return;
    }
    // Deep links de navegação
    handleDeepLink(uri.toString());
  }

  static bool _isAuthUri(Uri uri) {
    return uri.queryParameters.containsKey('code') ||
        uri.fragment.contains('access_token') ||
        uri.path.contains('/auth/');
  }

  /// Processa URIs de autenticação do Supabase (confirmação de email, magic link).
  static Future<void> _processAuthUri(Uri uri) async {
    try {
      // O Supabase envia links no formato:
      // nexushub://auth?code=xxx  (PKCE flow)
      // nexushub://auth#access_token=xxx&...  (implicit flow legado)
      //
      // IMPORTANTE: o SDK do supabase_flutter só aceita http/https no
      // exchangeCodeForSession / getSessionFromUrl. Por isso convertemos
      // o scheme nexushub:// para https:// antes de passar para o SDK.
      Uri normalizedUri = uri;
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        // Substitui o scheme por https e usa o Supabase URL como host
        final supabaseHost =
            Uri.parse('https://ylvzqqvcanzzswjkqeya.supabase.co').host;
        normalizedUri = uri.replace(
          scheme: 'https',
          host: supabaseHost,
        );
      }

      final code = normalizedUri.queryParameters['code'];
      final accessToken = normalizedUri.fragment.isNotEmpty
          ? Uri.splitQueryString(normalizedUri.fragment)['access_token']
          : null;
      final refreshToken = normalizedUri.fragment.isNotEmpty
          ? Uri.splitQueryString(normalizedUri.fragment)['refresh_token']
          : null;

      if (code != null) {
        // PKCE flow: trocar code por sessão usando a URL normalizada
        await Supabase.instance.client.auth
            .exchangeCodeForSession(normalizedUri.toString());
      } else if (accessToken != null && refreshToken != null) {
        // Implicit flow legado
        await Supabase.instance.client.auth.setSession(accessToken);
      }
      // O onAuthStateChange vai disparar signedIn e redirecionar para home
    } catch (e) {
      debugPrint('DeepLink: Erro ao processar auth URI: $e');
    }
  }

  /// Processa uma URL de deep link e navega para a tela correspondente.
  /// Retorna true se o link foi processado com sucesso.
  static bool handleDeepLink(String url) {
    try {
      final uri = Uri.parse(url);

      // Scheme personalizado: nexushub://
      if (uri.scheme == 'nexushub') {
        return _handleCustomScheme(uri);
      }

      // HTTPS links: https://nexushub.app/
      if (uri.host == 'nexushub.app' || uri.host == 'www.nexushub.app') {
        return _handleWebLink(uri);
      }

      return false;
    } catch (e) {
      debugPrint('DeepLink: Erro ao processar: $e');
      return false;
    }
  }

  static bool _handleCustomScheme(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.isEmpty) return false;

    switch (segments[0]) {
      case 'u':
      case 'user':
        if (segments.length > 1) { _navigateToUser(segments[1]); return true; }
        break;
      case 'c':
      case 'community':
        if (segments.length > 1) { _navigateToCommunity(segments[1]); return true; }
        break;
      case 'p':
      case 'post':
        if (segments.length > 1) { _navigateToPost(segments[1]); return true; }
        break;
      case 'w':
      case 'wiki':
        if (segments.length > 1) { _navigateToWiki(segments[1]); return true; }
        break;
      case 'chat':
        if (segments.length > 1) { _navigateToChat(segments[1]); return true; }
        break;
      case 's':
      case 'sticker':
        if (segments.length > 1) { _navigateToStickerPack(segments[1]); return true; }
        break;
      case 'invite':
        if (segments.length > 1) { _handleInviteCode(segments[1]); return true; }
        break;
      // Legado
      case 'ch':
        if (segments.length > 1) { _navigateToChat(segments[1]); return true; }
        break;
      case 'i':
        if (segments.length > 1) { _handleInviteCode(segments[1]); return true; }
        break;
    }
    return false;
  }

  static bool _handleWebLink(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.isEmpty) return false;

    switch (segments[0]) {
      case 'u': _navigateToUser(segments.length > 1 ? segments[1] : ''); return segments.length > 1;
      case 'c': _navigateToCommunity(segments.length > 1 ? segments[1] : ''); return segments.length > 1;
      case 'p': _navigateToPost(segments.length > 1 ? segments[1] : ''); return segments.length > 1;
      case 'w': _navigateToWiki(segments.length > 1 ? segments[1] : ''); return segments.length > 1;
      case 'chat': _navigateToChat(segments.length > 1 ? segments[1] : ''); return segments.length > 1;
      case 's': _navigateToStickerPack(segments.length > 1 ? segments[1] : ''); return segments.length > 1;
      case 'invite': if (segments.length > 1) { _handleInviteCode(segments[1]); return true; } break;
      // Legado (compatibilidade retroativa)
      case 'ch': _navigateToChat(segments.length > 1 ? segments[1] : ''); return segments.length > 1;
      case 'i': if (segments.length > 1) { _handleInviteCode(segments[1]); return true; } break;
      case 'user': if (segments.length > 1) { _router?.push('/user/${segments[1]}'); return true; } break;
      case 'community': if (segments.length > 1) { _router?.push('/community/${segments[1]}'); return true; } break;
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────
  // Navegação por tipo (resolve short codes via RPC quando necessário)
  // ─────────────────────────────────────────────────────────────

  static Future<void> _navigateToUser(String idOrSlug) async {
    if (idOrSlug.isEmpty) return;
    if (_isUuid(idOrSlug)) { _router?.push('/user/$idOrSlug'); return; }
    try {
      final r = await Supabase.instance.client
          .from('profiles').select('id').eq('amino_id', idOrSlug).maybeSingle();
      if (r != null) _router?.push('/user/${r['id']}');
    } catch (e) { debugPrint('DeepLink: Erro ao resolver perfil: $e'); }
  }

  static Future<void> _navigateToCommunity(String idOrSlug) async {
    if (idOrSlug.isEmpty) return;
    if (_isUuid(idOrSlug)) { _router?.push('/community/$idOrSlug'); return; }
    try {
      final r = await Supabase.instance.client
          .from('communities').select('id').eq('endpoint', idOrSlug).maybeSingle();
      if (r != null) _router?.push('/community/${r['id']}');
    } catch (e) { debugPrint('DeepLink: Erro ao resolver comunidade: $e'); }
  }

  static Future<void> _navigateToPost(String codeOrId) async {
    if (codeOrId.isEmpty) return;
    if (_isUuid(codeOrId)) { _router?.push('/post/$codeOrId'); return; }
    await _resolveShortCode(codeOrId, onResolved: (_, targetId, __, ___) {
      _router?.push('/post/$targetId');
    });
  }

  static Future<void> _navigateToWiki(String codeOrId) async {
    if (codeOrId.isEmpty) return;
    if (_isUuid(codeOrId)) { _router?.push('/wiki/$codeOrId'); return; }
    await _resolveShortCode(codeOrId, onResolved: (_, targetId, __, ___) {
      _router?.push('/wiki/$targetId');
    });
  }

  static Future<void> _navigateToChat(String codeOrId) async {
    if (codeOrId.isEmpty) return;
    if (_isUuid(codeOrId)) { _router?.push('/chat/$codeOrId'); return; }
    await _resolveShortCode(codeOrId, onResolved: (_, targetId, __, ___) {
      _router?.push('/chat/$targetId');
    });
  }

  static Future<void> _navigateToStickerPack(String codeOrId) async {
    if (codeOrId.isEmpty) return;
    if (_isUuid(codeOrId)) { _router?.push('/stickers/pack/$codeOrId'); return; }
    await _resolveShortCode(codeOrId, onResolved: (_, targetId, __, ___) {
      _router?.push('/stickers/pack/$targetId');
    });
  }

  static Future<void> _resolveShortCode(
    String code, {
    required void Function(String type, String targetId, String? communityId, Map<String, dynamic>? extra) onResolved,
  }) async {
    try {
      final result = await Supabase.instance.client
          .rpc('resolve_short_url', params: {'p_code': code});
      if (result != null && result is List && result.isNotEmpty) {
        final row = result.first as Map<String, dynamic>;
        onResolved(row['type'] as String, row['target_id'] as String,
            row['community_id'] as String?, row['extra_data'] as Map<String, dynamic>?);
      }
    } catch (e) { debugPrint('DeepLink: Erro ao resolver short code "$code": $e'); }
  }

  static bool _isUuid(String value) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(value);

  /// Processa um código de convite para entrar em uma comunidade.
  static Future<void> _handleInviteCode(String code) async {
    try {
      final result = await Supabase.instance.client
          .rpc('accept_invite', params: {'p_invite_code': code});
      if (result != null) {
        final data = result as Map<String, dynamic>;
        final communityId = data['community_id'] as String?;
        if (communityId != null) {
          _router?.push('/community/$communityId');
        }
      }
    } catch (e) {
      debugPrint('DeepLink: Erro ao processar convite: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Geração de URLs para compartilhamento
  // ─────────────────────────────────────────────────────────────

  static String _prefixForType(String type) {
    switch (type) {
      case 'user':         return 'u';
      case 'community':    return 'c';
      case 'post':
      case 'blog':         return 'p';
      case 'wiki':         return 'w';
      case 'chat':         return 'chat';
      case 'sticker_pack': return 's';
      case 'invite':       return 'invite';
      default:             return type;
    }
  }

  /// Gera URL curta via RPC do banco (usa slug/amino_id quando disponível,
  /// short code Base62 de 5 chars para posts/wiki/chat/stickers).
  static Future<String> generateShareUrl({
    required String type,
    required String targetId,
  }) async {
    try {
      final result = await Supabase.instance.client.rpc(
        'get_share_url',
        params: {'p_type': type, 'p_target_id': targetId},
      );
      if (result != null && result is String && result.isNotEmpty) return result;
    } catch (e) {
      debugPrint('DeepLink: Erro ao gerar share URL: $e');
    }
    return '$_baseUrl/${_prefixForType(type)}/$targetId';
  }

  /// Compartilha uma URL usando o share sheet nativo do sistema.
  static Future<void> shareUrl({
    required String type,
    required String targetId,
    String? title,
    String? text,
  }) async {
    final url = await generateShareUrl(type: type, targetId: targetId);
    final shareText = text != null ? '$text\n$url' : url;
    await Share.share(shareText, subject: title);
  }

  /// [Legado] Gera URL de forma síncrona sem short code.
  /// Prefira usar [generateShareUrl] para URLs curtas reais.
  static String generateLink({
    required String type,
    required String id,
    bool useWebUrl = true,
  }) {
    if (useWebUrl) return '$_baseUrl/${_prefixForType(type)}/$id';
    return 'nexushub://$type/$id';
  }
}
