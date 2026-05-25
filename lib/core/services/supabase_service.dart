/// Servicio singleton para interactuar con Supabase.
///
/// Inicializa el cliente de Supabase y expone helpers para autenticación
/// y acceso a la base de datos.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mploya/config/env.dart';

/// Servicio centralizado de Supabase.
///
/// Debe inicializarse una única vez llamando a [SupabaseService.initialize]
/// desde `main()` antes de usar cualquier otra funcionalidad.
///
/// ```dart
/// await SupabaseService.initialize();
/// final client = SupabaseService.instance.client;
/// ```
class SupabaseService {
  SupabaseService._();

  static SupabaseService? _instance;

  /// Instancia singleton del servicio. Lanza si no ha sido inicializado.
  static SupabaseService get instance {
    if (_instance == null) {
      throw StateError(
        'SupabaseService no ha sido inicializado. '
        'Llama a SupabaseService.initialize() en main().',
      );
    }
    return _instance!;
  }

  /// Inicializa la conexión con Supabase usando las credenciales del `.env`.
  ///
  /// Solo debe llamarse una vez al inicio de la aplicación.
  static Future<void> initialize() async {
    if (_instance != null) {
      debugPrint('SupabaseService ya fue inicializado.');
      return;
    }

    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      debug: kDebugMode,
    );

    _instance = SupabaseService._();
    debugPrint('✅ SupabaseService inicializado correctamente.');
  }

  // ─────────────────────────────────────────
  // Cliente
  // ─────────────────────────────────────────

  /// Cliente principal de Supabase.
  SupabaseClient get client => Supabase.instance.client;

  /// Acceso directo a GoTrue (autenticación).
  GoTrueClient get auth => client.auth;

  // ─────────────────────────────────────────
  // Helpers de Autenticación
  // ─────────────────────────────────────────

  /// Devuelve el usuario actualmente autenticado, o `null` si no hay sesión.
  User? get currentUser => auth.currentUser;

  /// `true` si hay un usuario autenticado con sesión activa.
  bool get isAuthenticated => auth.currentSession != null;

  /// Stream que emite cambios de estado de autenticación.
  ///
  /// Útil para redirigir al usuario al login cuando cierra sesión
  /// o cuando la sesión expira.
  Stream<AuthState> get authStateChanges => auth.onAuthStateChange;

  /// ID del usuario actual. Retorna `null` si no hay sesión.
  String? get currentUserId => currentUser?.id;

  /// Cierra la sesión actual del usuario.
  ///
  /// Envuelto en try-catch para manejar errores de red o sesión
  /// expirada sin crashear la app.
  Future<void> signOut() async {
    try {
      await auth.signOut();
      debugPrint('🔓 Sesión cerrada.');
    } catch (e, st) {
      debugPrint('⚠️ Error al cerrar sesión: $e\n$st');
      rethrow;
    }
  }
}
