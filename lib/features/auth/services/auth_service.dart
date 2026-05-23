import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mploya/config/env.dart';
import 'package:mploya/features/auth/models/user_model.dart';
import 'package:mploya/features/profile/models/company_profile_store.dart';

/// Service handling all authentication operations with Supabase.
///
/// Provides methods for email/password auth, Google OAuth,
/// password recovery, and session management.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  SupabaseClient get _client => Supabase.instance.client;
  GoTrueClient get _auth => _client.auth;

  // ─── Session & User ──────────────────────────────────────────────

  /// Current authenticated user, or null.
  User? get currentUser => _auth.currentUser;

  /// Whether a user is currently signed in.
  bool get isAuthenticated => currentUser != null;

  /// Current session, or null.
  Session? get currentSession => _auth.currentSession;

  /// Stream of auth state changes.
  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  // ─── Email / Password ────────────────────────────────────────────

  /// Sign up with email and password.
  ///
  /// Creates a new user account and a corresponding profile in the
  /// `profiles` table.
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final response = await _auth.signUp(
      email: email,
      password: password,
      data: {
        // ignore: use_null_aware_elements
        if (fullName != null) 'full_name': fullName,
      },
    );

    // Create profile record if sign up successful
    if (response.user != null) {
      await _createProfile(
        userId: response.user!.id,
        email: email,
        fullName: fullName,
      );
    }

    return response;
  }

  /// Sign in with email and password.
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // ─── Google Sign-In ──────────────────────────────────────────────

  /// Sign in with Google OAuth.
  ///
  /// Uses the native Google Sign-In flow and then authenticates
  /// with Supabase using the Google ID token.
  Future<AuthResponse> signInWithGoogle() async {
    const webClientId = String.fromEnvironment(
      'GOOGLE_WEB_CLIENT_ID',
      defaultValue: '',
    );

    final googleSignIn = GoogleSignIn(
      serverClientId: webClientId.isNotEmpty ? webClientId : Env.googleWebClientId,
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw AuthException('Inicio de sesión con Google cancelado');
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw AuthException('No se pudo obtener el token de Google');
    }

    final response = await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );

    // Ensure profile exists for Google sign-in users
    if (response.user != null) {
      await _ensureProfileExists(
        userId: response.user!.id,
        email: response.user!.email ?? googleUser.email,
        fullName: googleUser.displayName,
        avatarUrl: googleUser.photoUrl,
      );
    }

    return response;
  }

  // ─── Apple Sign-In ───────────────────────────────────────────────

  /// Sign in with Apple OAuth via Supabase.
  Future<AuthResponse> signInWithApple() async {
    // Use Supabase's built-in Apple OAuth flow
    final response = await _auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'io.supabase.mploya://login-callback',
    );

    // Since OAuth opens a browser, we need to wait for the callback
    // The auth state change listener will handle the rest
    debugPrint('Apple sign-in initiated: $response');

    // Return a placeholder - the actual auth response comes via the callback
    return AuthResponse(session: currentSession, user: currentUser);
  }

  // ─── Password Recovery ───────────────────────────────────────────

  /// Send a password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.resetPasswordForEmail(
      email,
      redirectTo: 'io.supabase.mploya://login-callback',
    );
  }

  /// Update password (when user has a recovery token).
  Future<UserResponse> updatePassword(String newPassword) async {
    return await _auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  // ─── Session Management ──────────────────────────────────────────

  /// Sign out the current user.
  Future<void> signOut() async {
    try {
      // Sign out from Google if applicable
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint('Google sign out error: $e');
    }

    await _auth.signOut();
  }

  /// Refresh the current session.
  Future<AuthResponse> refreshSession() async {
    return await _auth.refreshSession();
  }

  // ─── Profile Management ──────────────────────────────────────────

  /// Get the current user's profile from the database.
  Future<UserProfile?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) return null;
      return UserProfile.fromJson(data);
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      return null;
    }
  }

  /// Update the current user's profile.
  Future<UserProfile?> updateProfile(Map<String, dynamic> updates) async {
    final user = currentUser;
    if (user == null) throw AuthException('No hay sesión activa');

    updates['updated_at'] = DateTime.now().toIso8601String();

    final data = await _client
        .from('profiles')
        .update(updates)
        .eq('id', user.id)
        .select()
        .single();

    return UserProfile.fromJson(data);
  }

  // ─── Private Helpers ─────────────────────────────────────────────

  /// Create a new profile record in Supabase.
  Future<void> _createProfile({
    required String userId,
    required String email,
    String? fullName,
    String? avatarUrl,
  }) async {
    try {
      await _client.from('profiles').upsert({
        'id': userId,
        'email': email,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'user_type': CompanyProfileStore.isCompany ? 'employer' : 'job_seeker',
        'is_verified': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error creating profile: $e');
    }
  }

  /// Ensure a profile exists for the given user (upsert).
  Future<void> _ensureProfileExists({
    required String userId,
    required String email,
    String? fullName,
    String? avatarUrl,
  }) async {
    try {
      final existing = await _client
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (existing == null) {
        await _createProfile(
          userId: userId,
          email: email,
          fullName: fullName,
          avatarUrl: avatarUrl,
        );
      }
    } catch (e) {
      debugPrint('Error ensuring profile: $e');
    }
  }
}
