import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/user_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/presence_service.dart';
import '../../../core/l10n/locale_provider.dart';

/// Estado de autenticação do app.
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final UserModel? user;
  final String? error;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    UserModel? user,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      error: error,
    );
  }
}

/// Listenable que notifica o GoRouter quando o estado de auth muda.
/// Isso faz o router re-avaliar o redirect sempre que o auth muda.
class AuthChangeNotifier extends ChangeNotifier {
  StreamSubscription? _subscription;

  AuthChangeNotifier() {
    _subscription = SupabaseService.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}

/// Instância global do notifier para o GoRouter.refreshListenable.
final authChangeNotifier = AuthChangeNotifier();

/// Provider principal de autenticação.
class AuthNotifier extends StateNotifier<AuthState> {
  StreamSubscription? _authSubscription;

  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
    super.dispose();
  }

  void _init() {
    // ══════════════════════════════════════════════════════════════════
    // CORREÇÃO CRÍTICA: Verificar sessão SINCRONAMENTE.
    //
    // O Supabase persiste a sessão localmente. Quando o app abre,
    // `currentSession` já está disponível de forma síncrona.
    // Precisamos setar `isAuthenticated = true` ANTES que o GoRouter
    // execute seu primeiro redirect, senão ele vê false e manda
    // para /onboarding mesmo com sessão válida.
    // ══════════════════════════════════════════════════════════════════
    final session = SupabaseService.currentSession;
    if (session != null) {
      // Setar autenticado imediatamente (síncrono)
      state = const AuthState(isAuthenticated: true, isLoading: true);
      // Carregar perfil completo em background
      _loadUserProfile();
    }

    // Escutar mudanças de auth
    _authSubscription?.cancel();
    _authSubscription = SupabaseService.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        state = state.copyWith(isAuthenticated: true);
        _loadUserProfile();
      } else if (data.event == AuthChangeEvent.signedOut) {
        state = const AuthState();
      } else if (data.event == AuthChangeEvent.tokenRefreshed) {
        // Token renovado — sessão continua válida
        if (!state.isAuthenticated) {
          state = state.copyWith(isAuthenticated: true);
          _loadUserProfile();
        }
      }
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final response = await SupabaseService.table('profiles')
          .select()
          .eq('id', userId)
          .single();

      final user = UserModel.fromJson(response);
      state = AuthState(isAuthenticated: true, user: user);

      // Inicializar presença em tempo real
      try {
        await PresenceService.instance.initialize();
      } catch (_) {
        // Presença é best-effort
      }
    } catch (e) {
      // Mesmo se o perfil falhar, a sessão é válida
      state = state.copyWith(
          isLoading: false, error: s.errorLoadingProfileRetry);
    }
  }

  /// Login com email e senha.
  Future<bool> signInWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await SupabaseService.auth.signInWithPassword(
        email: email,
        password: password,
      );
      state = state.copyWith(isAuthenticated: true);
      await _loadUserProfile();
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
          isLoading: false,
          error: s.unexpectedErrorRetry);
      return false;
    }
  }

  /// Cadastro com email e senha.
  Future<bool> signUp(String email, String password, String nickname) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await SupabaseService.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': nickname},
      );

      // Se o Supabase exige confirmação de email, a sessão retornada
      // não terá o campo email_confirmed_at preenchido.
      // Nesse caso NÃO autenticamos — apenas indicamos que o email
      // de confirmação foi enviado (retornamos false com erro null).
      final session = response.session;
      final user = response.user;
      final emailConfirmed = user?.emailConfirmedAt != null;

      if (session != null && emailConfirmed) {
        // Confirmação automática habilitada no Supabase (raro em produção)
        state = state.copyWith(isAuthenticated: true);
        await _loadUserProfile();
        return true;
      } else {
        // Email de confirmação enviado — aguardar clique no link
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          error: null,
        );
        return false;
      }
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
          isLoading: false,
          error: s.unexpectedErrorRetry);
      return false;
    }
  }

  /// Login com Google OAuth usando Google Sign-In nativo (Android/iOS).
  /// Usa signInWithIdToken para evitar problemas de redirect em apps nativos.
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Client ID do servidor Web (usado pelo Supabase para validar o token)
      const webClientId =
          '884602945431-7nn5dtr6l7d34n9iv221cii6906576et.apps.googleusercontent.com';

      final googleSignIn = GoogleSignIn(serverClientId: webClientId);
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // Usuário cancelou o login
        state = state.copyWith(isLoading: false, error: null);
        return false;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        state = state.copyWith(
            isLoading: false,
            error: s.googleTokenError);
        return false;
      }

      await SupabaseService.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      // Atualizar estado imediatamente e carregar perfil,
      // igual ao fluxo de signInWithEmail.
      state = state.copyWith(isAuthenticated: true);
      await _loadUserProfile();

      return true;
    } catch (e) {
      state = state.copyWith(
          isLoading: false,
          error: s.errorGoogleLogin);
      return false;
    }
  }

  /// Login com Apple OAuth.
  Future<bool> signInWithApple() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await SupabaseService.auth.signInWithOAuth(OAuthProvider.apple);
      return true;
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: s.errorAppleLogin);
      return false;
    }
  }

  /// Logout.
  Future<void> signOut() async {
    try {
      // Encerrar presença em tempo real
      try {
        await PresenceService.instance.dispose();
      } catch (e) {
        debugPrint('[auth_provider] Erro: $e');
      }
      await SupabaseService.auth.signOut();
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(error: s.errorLoggingOut);
    }
  }

  /// Atualizar perfil em cache.
  void updateUserProfile(UserModel updatedUser) {
    state = state.copyWith(user: updatedUser);
  }
}

/// Provider global de autenticação.
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

/// Provider do usuário atual (atalho).
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});
