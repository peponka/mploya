import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_strings.dart';
import 'feed_service.dart';
import 'video_preload_manager.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthService — Singleton centralizado para toda la lógica de autenticación.
//
// Métodos públicos:
//  • signInWithEmail(email, password)  — Solo login; nunca registra automáticamente
//  • signUpWithEmail(email, password)  — Solo registro de cuenta nueva
//  • signInWithGoogle()                — OAuth Google
//  • signInWithApple()                 — OAuth Apple
//  • upsertUserProfile(user)           — Fallback para crear fila en public.users
//  • updatePitchUrl(userId, url)       — Guarda URL del Video-Pitch
//  • signOut()                         — Cierra sesión activa
//
// Todos los métodos devuelven null en éxito, String en español si fallan.
// AuthErrorCode.noAccount se emite cuando el email no existe, para que la UI
// pueda ofrecer "¿No tienes cuenta? Regístrate" sin mezclar flujos.
// ─────────────────────────────────────────────────────────────────────────────

/// Código especial que la UI puede inspeccionar para distinguir
/// "credenciales incorrectas" de "este email no está registrado".
const String kAuthErrorNoAccount = 'AUTH_NO_ACCOUNT';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  SupabaseClient get _client => Supabase.instance.client;

  // ── Rate Limiting — Protección anti brute-force ─────────────────────────
  static const int _maxAttempts = 5;
  static const Duration _lockoutDuration = Duration(seconds: 60);
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  /// Verifica si el login está bloqueado por exceso de intentos.
  bool get isLockedOut =>
      _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);

  /// Segundos restantes de bloqueo (0 si no está bloqueado).
  int get lockoutSecondsRemaining => isLockedOut
      ? _lockoutUntil!.difference(DateTime.now()).inSeconds
      : 0;

  /// Resetea el contador de intentos (llamar tras login exitoso).
  void _resetAttempts() {
    _failedAttempts = 0;
    _lockoutUntil = null;
  }

  /// Registra un intento fallido y activa lockout si supera el límite.
  void _recordFailedAttempt() {
    _failedAttempts++;
    if (_failedAttempts >= _maxAttempts) {
      _lockoutUntil = DateTime.now().add(_lockoutDuration);
      debugPrint('🔒 Login locked for ${_lockoutDuration.inSeconds}s after $_failedAttempts failed attempts');
    }
  }

  // ── Estado de sesión ─────────────────────────────────────────────────────

  /// Sesión activa o null si el usuario no está autenticado.
  Session? get currentSession => _client.auth.currentSession;

  /// Stream de eventos de auth para reaccionar a signIn / signOut en la UI.
  Stream<AuthState> get authStateStream => _client.auth.onAuthStateChange;

  // ── Email + Contraseña ── login y registro son flujos separados ─────────

  /// Inicia sesión con email y contraseña.
  ///
  /// Retorna null en éxito, [kAuthErrorNoAccount] si el email no existe
  /// (para que la UI ofrezca registro), o un String de error en español.
  Future<String?> signInWithEmail(String email, String password) async {
    // ── Rate limiting check ──
    if (isLockedOut) {
      return 'Demasiados intentos fallidos. Esperá ${lockoutSecondsRemaining}s antes de intentar de nuevo.';
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      return 'Por favor, ingresá un email válido.';
    }
    if (password.length < 6) return 'La contraseña debe tener al menos 6 caracteres.';

    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      _resetAttempts(); // Login exitoso → resetear contador
      return null;
    } on AuthException catch (e) {
      _recordFailedAttempt(); // Login fallido → incrementar contador
      return _translateAuthError(e.message, e.statusCode);
    } catch (e) {
      return _classifyNetworkError(e, context: 'signInWithEmail');
    }
  }

  /// Registra una cuenta nueva con email y contraseña.
  ///
  /// Separado intencionalmente de [signInWithEmail] para evitar registros
  /// accidentales al escribir mal la contraseña en el login.
  /// Retorna null en éxito, String de error en español si falla.
  Future<String?> signUpWithEmail(String email, String password) async {
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      return 'Por favor, ingresá un email válido.';
    }
    if (password.length < 8) return 'La contraseña debe tener al menos 8 caracteres.';
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'La contraseña debe incluir al menos una mayúscula.';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'La contraseña debe incluir al menos un número.';
    }

    try {
      await _client.auth.signUp(email: email, password: password);
      return null;
    } on AuthException catch (e) {
      return _translateAuthError(e.message, e.statusCode);
    } catch (e) {
      return _classifyNetworkError(e, context: 'signUpWithEmail');
    }
  }

  /// Envía un correo con el enlace o PIN para restaurar la contraseña.
  /// Retorna null en éxito, String de error si falla.
  Future<String?> resetPasswordForEmail(String email) async {
    if (!email.contains('@')) return 'Por favor, ingresa un email válido para recuperar la cuenta.';
    try {
      await _client.auth.resetPasswordForEmail(email);
      return null;
    } on AuthException catch (e) {
      return _translateAuthError(e.message, e.statusCode);
    } catch (e) {
      return _classifyNetworkError(e, context: 'resetPasswordForEmail');
    }
  }

  // ── OAuth ────────────────────────────────────────────────────────────────

  /// Inicia sesión con Google (OAuth). Abre el navegador/WebView del sistema.
  Future<String?> signInWithGoogle() async {
    try {
      // En web usamos la URL actual del navegador (funciona en local y en producción).
      // En Android/iOS el scheme io.supabase.mploya captura el callback via intent-filter.
      final redirectTo = kIsWeb
          ? '${Uri.base.origin}/app/'
          : 'io.supabase.mploya://login-callback';
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
      );
      return null;
    } on AuthException catch (e) {
      return _translateAuthError(e.message, e.statusCode);
    } catch (e) {
      return _classifyNetworkError(e, context: 'signInWithGoogle');
    }
  }

  /// Inicia sesión con Apple (OAuth). Solo disponible en iOS/macOS.
  Future<String?> signInWithApple() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: 'io.supabase.mploya://login-callback',
      );
      return null;
    } on AuthException catch (e) {
      return _translateAuthError(e.message, e.statusCode);
    } catch (e) {
      return _classifyNetworkError(e, context: 'signInWithApple');
    }
  }

  // ── Perfil de usuario ────────────────────────────────────────────────────

  /// Garantiza que exista la fila del usuario en public.users.
  /// Solo escribe id + email + onboarding_step=0.
  /// NO deriva name del email para evitar datos basura que engañen al routing.
  /// El trigger on_auth_user_created es la fuente primaria; este método
  /// actúa como fallback en caso de que el trigger no esté activo.
  Future<void> upsertUserProfile(User user) async {
    try {
      final fallbackName = user.userMetadata?['full_name']?.toString()
          ?? user.userMetadata?['name']?.toString()
          ?? user.email?.split('@').first
          ?? 'Usuario';
      await _client.from('users').upsert(
        {'id': user.id, 'email': user.email ?? '', 'name': fallbackName, 'onboarding_step': 0},
        onConflict: 'id',
        ignoreDuplicates: true, // no sobreescribe si la fila ya existe
      );
    } catch (e) {
      // Fallo silencioso: si RLS bloquea el upsert, el trigger ya creó la fila.
      debugPrint('⚠️ AuthService.upsertUserProfile (non-blocking): $e');
    }
  }

  /// Guarda la URL pública del Video-Pitch en el perfil del usuario.
  ///
  /// Usa UPSERT en lugar de UPDATE para garantizar que la fila existe
  /// aunque el trigger de Postgres no haya creado el registro previo.
  /// Un UPDATE sobre 0 filas retorna 200 OK vacío sin excepción — este
  /// patrón elimina ese fallo silencioso definitivamente.
  /// Guarda la URL del Video-Pitch y marca onboarding_step = 3.
  /// Usa UPDATE (no UPSERT) porque la fila siempre existe en este punto del flujo.
  Future<String?> updatePitchUrl(String userId, String videoUrl, [List<String>? tags]) async {
    try {
      final res = await _client.from('users').update({
        'video_url': videoUrl,
        'onboarding_step': 3,
        if (tags != null && tags.isNotEmpty) 'tags': tags,
      }).eq('id', userId).select();
      
      if (res.isEmpty) {
        return 'No se pudo vincular el video al perfil (Fila no encontrada). Intenta iniciar sesión de nuevo.';
      }
      return null;
    } catch (e) {
      debugPrint('🔴 updatePitchUrl error: $e');
      return _classifyNetworkError(e, context: 'updatePitchUrl');
    }
  }

  // ── Cerrar sesión ────────────────────────────────────────────────────────

  /// Cierra la sesión activa. Retorna null si OK, mensaje de error si falla.
  Future<String?> signOut() async {
    try {
      // Limpiar caché del feed para evitar mezcla de datos entre cuentas
      FeedService.instance.invalidateCache();
      // Limpiar el tipo de cuenta cacheado: si no, al cambiar de cuenta queda
      // pegado el rol anterior (empresa/candidato) y la nav/feed se confunden.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('mploya_account_type');
      } catch (_) {}
      await _client.auth.signOut();
      return null;
    } on AuthException catch (e) {
      return _translateAuthError(e.message, e.statusCode);
    } catch (e) {
      return _classifyNetworkError(e, context: 'signOut');
    }
  }

  // ── Forzar cierre de sesión corrupta ─────────────────────────────────────

  /// Se llama desde el global error handler cuando Supabase lanza
  /// `refresh_token_already_used`.
  /// Hace signOut local (scope: local) para limpiar tokens sin contactar
  /// el servidor — porque el token ya es inválido y el servidor lo rechazaría.
  /// NO lanza excepciones — es fire-and-forget.
  bool _isForceSigningOut = false;
  Future<void> forceSignOutCorruptSession() async {
    if (_isForceSigningOut) return; // Evitar recursión
    _isForceSigningOut = true;
    debugPrint('🔴 forceSignOutCorruptSession: limpiando sesión corrupta...');
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      debugPrint('⚠️ forceSignOut fallback: $e');
    } finally {
      _isForceSigningOut = false;
    }
  }

  // ── Cambiar contraseña ──────────────────────────────────────────────────

  /// Actualiza la contraseña del usuario autenticado.
  /// Retorna null si OK, String de error si falla.
  Future<String?> updatePassword(String newPassword) async {
    if (newPassword.length < 8) {
      return AppStrings.passwordTooShort;
    }
    if (!RegExp(r'[A-Z]').hasMatch(newPassword)) {
      return AppStrings.passwordNeedsUppercase;
    }
    if (!RegExp(r'[0-9]').hasMatch(newPassword)) {
      return AppStrings.passwordNeedsNumber;
    }

    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return null;
    } on AuthException catch (e) {
      return _translateAuthError(e.message, e.statusCode);
    } catch (e) {
      return _classifyNetworkError(e, context: 'updatePassword');
    }
  }

  // ── Eliminar cuenta ─────────────────────────────────────────────────────

  /// Elimina la cuenta del usuario actual y todos sus datos asociados.
  /// 
  /// Flujo:
  ///  1. Eliminar datos de tablas públicas (connections, messages, etc.)
  ///  2. Llamar Edge Function `delete-user` que usa service_role para
  ///     borrar al usuario de auth.users (GDPR "right to be forgotten").
  ///  3. Limpiar recursos locales + cerrar sesión.
  ///
  /// ⚠️ NO hay fallback soft-delete. Si la Edge Function falla,
  /// retornamos error para que el usuario contacte soporte.
  /// Esto es requisito de Apple Guideline 5.1.1 y GDPR Art. 17.
  ///
  /// Retorna null si OK, String de error si falla.
  Future<String?> deleteAccount() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return AppStrings.noSession;

    try {
      // Paso 1: Limpiar datos del usuario en tablas públicas
      await _cleanupUserData(uid);

      // Paso 2: Edge Function con service_role para eliminar de auth.users
      // (El SDK del cliente NO puede auto-eliminarse por seguridad)
      final response = await _client.functions.invoke(
        'delete-user',
        body: {'user_id': uid},
      );

      if (response.status != 200) {
        // NO hacer soft-delete — violaría GDPR
        final errorMsg = response.data?['error']?.toString() ?? 'Error desconocido';
        debugPrint('🔴 delete-user Edge Function failed: $errorMsg');
        return AppStrings.deleteAccountFailed;
      }

      // Paso 3: Limpiar recursos locales
      try {
        // Importar dinámicamente para no acoplar
        final videoMgr = VideoPreloadManager.instance;
        videoMgr.disposeAll(); // Aquí SÍ corresponde disposeAll()
      } catch (e) {
        debugPrint('⚠️ deleteAccount cleanup VideoPreloadManager: $e');
      }

      // Paso 4: Cerrar sesión
      await _client.auth.signOut();
      return null;
    } on FunctionException catch (e) {
      // La Edge Function no está deployada o hay error de red
      debugPrint('🔴 deleteAccount FunctionException: ${e.details}');
      return AppStrings.deleteServiceUnavailable;
    } catch (e) {
      debugPrint('🔴 deleteAccount error: $e');
      return _classifyNetworkError(e, context: 'deleteAccount');
    }
  }

  /// Limpia todos los datos del usuario en tablas públicas.
  Future<void> _cleanupUserData(String uid) async {
    // Orden importa por FK constraints
    final tables = [
      {'table': 'moderation_log', 'column': 'user_id'},
      {'table': 'content_reports', 'column': 'reporter_id'},
      {'table': 'pitch_reactions', 'column': 'user_id'},
      {'table': 'pitch_reactions', 'column': 'target_user_id'},
      {'table': 'pitch_comments', 'column': 'author_id'},
      {'table': 'saved_profiles', 'column': 'user_id'},
      {'table': 'saved_profiles', 'column': 'saved_user_id'},
      {'table': 'nexus_signals', 'column': 'sender_id'},
      {'table': 'nexus_signals', 'column': 'receiver_id'},
      {'table': 'profile_views', 'column': 'viewer_id'},
      {'table': 'profile_views', 'column': 'viewed_id'},
      {'table': 'connections', 'column': 'requester_id'},
      {'table': 'connections', 'column': 'addressee_id'},
      {'table': 'messages', 'column': 'sender_id'},
      {'table': 'messages', 'column': 'receiver_id'},
      {'table': 'notifications', 'column': 'user_id'},
      {'table': 'jobs', 'column': 'company_id'},
    ];

    for (final t in tables) {
      try {
        await _client.from(t['table']!).delete().eq(t['column']!, uid);
      } catch (e) {
        debugPrint('⚠️ Cleanup ${t['table']}.${t['column']}: $e');
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers privados
  // ─────────────────────────────────────────────────────────────────────────

  String _classifyNetworkError(Object e, {required String context}) {
    final raw = e.toString().toLowerCase();

    if (raw.contains('failed to fetch') ||
        raw.contains('xmlhttprequest') ||
        raw.contains('cors')) {
      return AppStrings.networkError;
    }
    if (raw.contains('clientexception')) {
      return AppStrings.networkError;
    }
    if (raw.contains('socketexception') ||
        raw.contains('connection refused') ||
        raw.contains('network is unreachable') ||
        raw.contains('no address associated')) {
      return AppStrings.noInternet;
    }
    if (raw.contains('timeout') || raw.contains('timed out')) {
      return AppStrings.requestTimeout;
    }
    return AppStrings.unexpectedError(context);
  }

  String _translateAuthError(String message, String? statusCode) {
    final m = message.toLowerCase();

    // Token corrupto — forzar sign-out silencioso
    if (m.contains('refresh_token') || m.contains('already_used') || m.contains('already used')) {
      forceSignOutCorruptSession();
      return AppStrings.sessionExpired;
    }

    if (m.contains('email not confirmed')) {
      return AppStrings.emailNotConfirmed;
    }
    if (m.contains('invalid login') ||
        m.contains('user not found') ||
        m.contains('invalid credentials')) {
      return AppStrings.invalidCredentials;
    }
    if (m.contains('email rate limit') || m.contains('rate limit')) {
      return AppStrings.rateLimitExceeded;
    }
    if (m.contains('email already registered') || m.contains('already exists')) {
      return AppStrings.emailAlreadyRegistered;
    }
    if (m.contains('signup disabled') || m.contains('signups not allowed')) {
      return AppStrings.signupDisabled;
    }
    if (m.contains('weak password') || m.contains('should be at least')) {
      return AppStrings.weakPassword;
    }
    if (m.contains('network') || m.contains('fetch')) {
      return AppStrings.networkError;
    }
    return AppStrings.authError(message);
  }
}
