import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'package:mploya/features/auth/models/user_model.dart';
import 'package:mploya/features/auth/services/auth_service.dart';
import 'package:mploya/features/profile/models/company_profile_store.dart';

// ─── Auth State ────────────────────────────────────────────────────

/// Represents the current authentication state.
sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class Authenticated extends AuthState {
  const Authenticated({required this.user, this.profile});
  final User user;
  final UserProfile? profile;
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
}

// ─── Auth Notifier ─────────────────────────────────────────────────

/// Manages authentication state using Riverpod.
///
/// Listens to Supabase auth state changes and provides methods
/// for login, register, logout, and profile management.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthInitial()) {
    _init();
  }

  final AuthService _authService = AuthService.instance;
  StreamSubscription<AuthChangeEvent>? _authSubscription;

  /// Initialize auth listener.
  void _init() {
    // Check current session on startup
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      state = Authenticated(user: currentUser);
      _loadProfile();
    } else {
      state = const Unauthenticated();
    }

    // Listen for auth changes
    _authSubscription = _authService.authStateChanges.map((s) => s.event).listen(
      (event) {
        final session = _authService.currentSession;

        switch (event) {
          case AuthChangeEvent.signedIn:
          case AuthChangeEvent.tokenRefreshed:
          case AuthChangeEvent.userUpdated:
            if (session?.user != null) {
              state = Authenticated(user: session!.user);
              _loadProfile();
            }
            break;
          case AuthChangeEvent.signedOut:
            state = const Unauthenticated();
            break;
          case AuthChangeEvent.passwordRecovery:
            // Handle password recovery state if needed
            break;
          case AuthChangeEvent.initialSession:
            if (session?.user != null) {
              state = Authenticated(user: session!.user);
              _loadProfile();
            } else {
              state = const Unauthenticated();
            }
            break;
          default:
            break;
        }
      },
      onError: (error) {
        debugPrint('Auth state error: $error');
        state = AuthError(error.toString());
      },
    );
  }

  /// Load user profile from database.
  Future<void> _loadProfile() async {
    try {
      final profile = await _authService.getCurrentProfile();
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        state = Authenticated(user: currentUser, profile: profile);
        if (profile != null && profile.userType == UserType.employer) {
          CompanyProfileStore.isCompany = true;
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  // ─── Auth Actions ──────────────────────────────────────────────

  /// Sign in with email and password.
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AuthLoading();
    try {
      await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      // State will be updated by the auth listener
    } on AuthException catch (e) {
      state = AuthError(_mapAuthError(e.message));
    } catch (e) {
      state = AuthError('Error inesperado: ${e.toString()}');
    }
  }

  /// Sign up with email, password, and optional name.
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    state = const AuthLoading();
    try {
      await _authService.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
      );
      // State will be updated by the auth listener
    } on AuthException catch (e) {
      state = AuthError(_mapAuthError(e.message));
    } catch (e) {
      state = AuthError('Error inesperado: ${e.toString()}');
    }
  }

  /// Sign in with Google.
  Future<void> signInWithGoogle() async {
    state = const AuthLoading();
    try {
      await _authService.signInWithGoogle();
      // State will be updated by the auth listener
    } on AuthException catch (e) {
      state = AuthError(_mapAuthError(e.message));
    } catch (e) {
      state = AuthError('Error inesperado: ${e.toString()}');
    }
  }

  /// Send password reset email.
  Future<void> sendPasswordReset(String email) async {
    state = const AuthLoading();
    try {
      await _authService.sendPasswordResetEmail(email);
      state = const Unauthenticated(); // Return to unauthenticated
    } on AuthException catch (e) {
      state = AuthError(_mapAuthError(e.message));
    } catch (e) {
      state = AuthError('Error inesperado: ${e.toString()}');
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    state = const AuthLoading();
    try {
      await _authService.signOut();
      state = const Unauthenticated();
    } catch (e) {
      state = AuthError('Error al cerrar sesión: ${e.toString()}');
    }
  }

  /// Reload profile data.
  Future<void> refreshProfile() async {
    await _loadProfile();
  }

  /// Clear error and return to unauthenticated state.
  void clearError() {
    state = const Unauthenticated();
  }

  /// Map Supabase error messages to user-friendly Spanish messages.
  String _mapAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials')) {
      return 'Email o contraseña incorrectos';
    }
    if (lower.contains('email not confirmed')) {
      return 'Por favor, confirma tu email antes de iniciar sesión';
    }
    if (lower.contains('user already registered')) {
      return 'Este email ya está registrado';
    }
    if (lower.contains('signup_disabled')) {
      return 'El registro está deshabilitado temporalmente';
    }
    if (lower.contains('email_address_invalid')) {
      return 'El email ingresado no es válido';
    }
    if (lower.contains('weak_password') || lower.contains('password')) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    if (lower.contains('rate_limit') || lower.contains('too many requests')) {
      return 'Demasiados intentos. Espera un momento e intenta de nuevo';
    }
    if (lower.contains('network') || lower.contains('socket')) {
      return 'Error de conexión. Verifica tu internet';
    }
    return message;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

// ─── Providers ─────────────────────────────────────────────────────

/// Main auth state provider.
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

/// Convenience provider — whether user is currently authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState is Authenticated;
});

/// Convenience provider — current user profile, if authenticated.
final currentProfileProvider = Provider<UserProfile?>((ref) {
  final authState = ref.watch(authProvider);
  if (authState is Authenticated) {
    return authState.profile;
  }
  return null;
});

/// Convenience provider — current Supabase user, if authenticated.
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authProvider);
  if (authState is Authenticated) {
    return authState.user;
  }
  return null;
});
