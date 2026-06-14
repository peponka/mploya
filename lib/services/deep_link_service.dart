import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../screens/profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DeepLinkService — Universal Links (iOS) + App Links (Android)
//
// Soporta los siguientes esquemas de URL:
//   • https://mploya.ai/p/{userId}    → Abre perfil de usuario
//   • https://mploya.ai/j/{jobId}     → Abre perfil de empresa (futuro)
//   • io.supabase.mploya://...        → OAuth callback (Supabase lo maneja)
//
// Paquete: app_links (recomendado por Flutter team)
//   - iOS: Universal Links vía Associated Domains
//   - Android: App Links vía assetlinks.json
//
// Archivos de plataforma requeridos:
//   - iOS: Runner.entitlements → applinks:mploya.ai
//   - Android: AndroidManifest.xml → intent-filter https://mploya.ai
//   - Web: /.well-known/apple-app-site-association
//   - Web: /.well-known/assetlinks.json
// ─────────────────────────────────────────────────────────────────────────────

class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  /// Clave global del Navigator para push de screens desde fuera del widget tree.
  /// Se asigna al CupertinoApp.navigatorKey en main.dart.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;
  bool _initialized = false;
  static const _maxRetries = 3;

  /// Deep link pendiente — se guarda cuando el usuario no está logueado
  /// para resolver después del login.
  Uri? _pendingDeepLink;

  /// Obtiene el deep link pendiente (si hay uno guardado).
  Uri? get pendingDeepLink => _pendingDeepLink;

  /// Limpia el deep link pendiente después de resolverlo.
  void clearPendingDeepLink() {
    _pendingDeepLink = null;
  }

  /// Inicializa el listener de deep links.
  /// Llamar una sola vez desde main.dart después de Supabase.initialize().
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _appLinks = AppLinks();

    // ── 1. Cold start: app abierta desde un link (killed state) ──
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        // Esperamos a que el Navigator esté montado
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Pequeño delay para que SplashScreen termine su routing
          Future.delayed(const Duration(milliseconds: 1500), () {
            handleDeepLink(initialUri);
          });
        });
      }
    } catch (e) {
      debugPrint('⚠️ Deep link initial: $e');
    }

    // ── 2. Warm start: app ya abierta, recibe link ──
    _linkSub = _appLinks.uriLinkStream.listen(
      (uri) => handleDeepLink(uri),
      onError: (err) => debugPrint('⚠️ Deep link stream error: $err'),
    );
  }

  /// Parsea un deep link URI y navega al destino correspondiente.
  /// Retorna true si el link fue manejado exitosamente.
  bool handleDeepLink(Uri uri) {
    debugPrint('🔗 Deep link recibido: $uri');

    // ── Ignorar OAuth callbacks (custom scheme) ──
    // Supabase maneja io.supabase.mploya:// automáticamente
    if (uri.scheme == 'io.supabase.mploya') {
      debugPrint('🔐 OAuth callback — Supabase lo maneja');
      return false;
    }

    // ── Solo procesar links de nuestro dominio ──
    final host = uri.host.toLowerCase();
    if (host != 'mploya.ai' && host != 'www.mploya.ai') {
      debugPrint('⚠️ Dominio no reconocido: ${uri.host}');
      return false;
    }

    final segments = uri.pathSegments;
    if (segments.isEmpty) return false;

    // ── Verificar si el usuario está autenticado ──
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      debugPrint('🔒 Usuario no logueado — guardando deep link pendiente');
      _pendingDeepLink = uri;
      // El SplashScreen/LoginScreen resolverá el deep link después del login
      return true;
    }

    switch (segments.first) {
      case 'p' when segments.length >= 2:
        // Profile: https://mploya.ai/p/{userId}
        _navigateToProfile(segments[1]);
        return true;

      case 'j' when segments.length >= 2:
        // Job: https://mploya.ai/j/{jobId} — implementar después
        debugPrint('📌 Job deep link: ${segments[1]} (próximamente)');
        return false;

      default:
        debugPrint('⚠️ Ruta deep link no reconocida: ${uri.path}');
        return false;
    }
  }

  /// Intenta resolver un deep link pendiente (después del login).
  /// Llamar desde el HomeScreen o después de autenticación exitosa.
  void resolvePendingDeepLink() {
    if (_pendingDeepLink != null) {
      debugPrint('🔗 Resolviendo deep link pendiente: $_pendingDeepLink');
      final uri = _pendingDeepLink!;
      _pendingDeepLink = null;
      handleDeepLink(uri);
    }
  }

  /// Navega al perfil de un usuario dado su ID.
  /// Usa un retry counter local por cada invocación para evitar
  /// corrupción si dos deep links llegan simultáneamente.
  Future<void> _navigateToProfile(String userId) async {
    await _navigateToProfileWithRetry(userId, 0);
  }

  Future<void> _navigateToProfileWithRetry(String userId, int retryCount) async {
    final nav = navigatorKey.currentState;
    if (nav == null) {
      if (retryCount >= _maxRetries) {
        debugPrint('⚠️ Navigator no disponible después de $_maxRetries intentos — abortando deep link');
        return;
      }
      debugPrint('⏳ Navigator no disponible (intento ${retryCount + 1}/$_maxRetries), reintentando...');
      Future.delayed(const Duration(seconds: 1), () {
        _navigateToProfileWithRetry(userId, retryCount + 1);
      });
      return;
    }

    try {
      debugPrint('🔍 Buscando perfil para deep link: $userId');

      // Fetch del perfil desde Supabase
      final data = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) {
        debugPrint('⚠️ Usuario no encontrado para deep link: $userId');
        return;
      }

      final user = NexUser.fromJson(data);

      // Push con animación Cupertino estándar
      nav.push(
        CupertinoPageRoute(
          builder: (_) => ProfileScreen(user: user),
        ),
      );

      debugPrint('✅ Navegación por deep link exitosa → ${user.name}');
    } catch (e) {
      debugPrint('❌ Error al navegar por deep link: $e');
    }
  }

  /// Liberar recursos al cerrar la app.
  void dispose() {
    _linkSub?.cancel();
  }
}

