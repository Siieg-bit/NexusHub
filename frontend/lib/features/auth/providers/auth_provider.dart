import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/user_model.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/presence_service.dart';

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
  AuthChangeNotifier() {
    SupabaseService.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }
}

/// Instância global do notifier para o GoRouter.refreshListenable.
final authChangeNotifier = AuthChangeNotifier();

/// Provider principal de autenticação.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _init();
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
    SupabaseService.auth.onAuthStateChange.listen((data) {
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
          isLoading: false, error: 'Erro ao carregar perfil. Tente novamente.');
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
          error: 'Ocorreu um erro inesperado. Tente novamente.');
      return false;
    }
  }

  /// Cadastro com email e senha.
  Future<bool> signUp(String email, String password, String nickname) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await SupabaseService.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': nickname},
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
          error: 'Ocorreu um erro inesperado. Tente novamente.');
      return false;
    }
  }

  /// Login com Google OAuth.
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await SupabaseService.auth.signInWithOAuth(OAuthProvider.google);
      return true;
    } catch (e) {
      state = state.copyWith(
          isLoading: false,
          error: 'Erro no login com Google. Tente novamente.');
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
          isLoading: false, error: 'Erro no login com Apple. Tente novamente.');
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
      state = state.copyWith(error: 'Erro ao sair. Tente novamente.');
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
