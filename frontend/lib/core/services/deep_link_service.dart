import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Serviço de Deep Links — processa URLs do tipo nexushub://
/// e https://nexushub.app/ para navegação direta.
///
/// Padrões suportados:
///   nexushub://community/{id}
///   nexushub://post/{id}
///   nexushub://user/{id}
///   nexushub://chat/{threadId}
///   nexushub://invite/{code}
///   https://nexushub.app/c/{id}
///   https://nexushub.app/p/{id}
///   https://nexushub.app/u/{id}
class DeepLinkService {
  DeepLinkService._();

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
  /// Necessário para processar o link de confirmação de email do Supabase.
  static void _listenToIncomingLinks() {
    _linkSubscription?.cancel();
    final appLinks = AppLinks();

    // Link recebido com o app já aberto
    _linkSubscription = appLinks.uriLinkStream.listen((uri) {
      _processAuthUri(uri);
    }, onError: (e) {
      debugPrint('DeepLink: Erro ao receber link: $e');
    });

    // Link que abriu o app (cold start)
    appLinks.getInitialLink().then((uri) {
      if (uri != null) _processAuthUri(uri);
    }).catchError((e) {
      debugPrint('DeepLink: Erro ao obter link inicial: $e');
    });
  }

  /// Processa URIs de autenticação do Supabase (confirmação de email, magic link).
  static Future<void> _processAuthUri(Uri uri) async {
    try {
      // O Supabase envia links no formato:
      // nexushub://auth?code=xxx  (PKCE flow)
      // nexushub://auth#access_token=xxx&...  (implicit flow legado)
      final code = uri.queryParameters['code'];
      final accessToken = uri.fragment.isNotEmpty
          ? Uri.splitQueryString(uri.fragment)['access_token']
          : null;
      final refreshToken = uri.fragment.isNotEmpty
          ? Uri.splitQueryString(uri.fragment)['refresh_token']
          : null;

      if (code != null) {
        // PKCE flow: trocar code por sessão
        await Supabase.instance.client.auth.exchangeCodeForSession(code);
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
      case 'community':
        if (segments.length > 1) {
          _router?.push('/community/${segments[1]}');
          return true;
        }
        break;
      case 'post':
        if (segments.length > 1) {
          _router?.push('/post/${segments[1]}');
          return true;
        }
        break;
      case 'user':
        if (segments.length > 1) {
          _router?.push('/user/${segments[1]}');
          return true;
        }
        break;
      case 'chat':
        if (segments.length > 1) {
          _router?.push('/chat/${segments[1]}');
          return true;
        }
        break;
      case 'invite':
        if (segments.length > 1) {
          _handleInviteCode(segments[1]);
          return true;
        }
        break;
      case 'wiki':
        if (segments.length > 1) {
          _router?.push('/wiki/${segments[1]}');
          return true;
        }
        break;
    }
    return false;
  }

  static bool _handleWebLink(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.isEmpty) return false;

    switch (segments[0]) {
      case 'c': // community
        if (segments.length > 1) {
          _router?.push('/community/${segments[1]}');
          return true;
        }
        break;
      case 'p': // post
        if (segments.length > 1) {
          _router?.push('/post/${segments[1]}');
          return true;
        }
        break;
      case 'u': // user
        if (segments.length > 1) {
          _router?.push('/user/${segments[1]}');
          return true;
        }
        break;
      case 'i': // invite
        if (segments.length > 1) {
          _handleInviteCode(segments[1]);
          return true;
        }
        break;
    }
    return false;
  }

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

  /// Gera uma URL de deep link para compartilhamento.
  static String generateLink({
    required String type,
    required String id,
    bool useWebUrl = true,
  }) {
    if (useWebUrl) {
      final prefix = {
            'community': 'c',
            'post': 'p',
            'user': 'u',
            'invite': 'i',
          }[type] ??
          type;
      return 'https://nexushub.app/$prefix/$id';
    }
    return 'nexushub://$type/$id';
  }
}
