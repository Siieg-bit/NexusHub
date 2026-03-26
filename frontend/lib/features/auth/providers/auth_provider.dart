import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/user_model.dart';
import '../../../core/services/supabase_service.dart';

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

/// Provider principal de autenticação.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _init();
  }

  void _init() {
    // Verificar sessão existente
    final session = SupabaseService.currentSession;
    if (session != null) {
      _loadUserProfile();
    }

    // Escutar mudanças de auth
    SupabaseService.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        _loadUserProfile();
      } else if (data.event == AuthChangeEvent.signedOut) {
        state = const AuthState();
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

      // Atualizar status online (1 = Online)
      await SupabaseService.table('profiles')
          .update({
            'online_status': 1,
            'last_seen_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId);
    } catch (e) {
      state = state.copyWith(error: 'Erro ao carregar perfil: $e');
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
      await _loadUserProfile();
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Erro inesperado: $e');
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
      await _loadUserProfile();
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Erro inesperado: $e');
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
      state = state.copyWith(isLoading: false, error: 'Erro no login com Google: $e');
      return false;
    }
  }

  /// Logout.
  Future<void> signOut() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId != null) {
        // Atualizar status offline (2 = Offline)
        await SupabaseService.table('profiles')
            .update({
              'online_status': 2,
              'last_seen_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', userId);
      }
      await SupabaseService.auth.signOut();
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(error: 'Erro ao sair: $e');
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
