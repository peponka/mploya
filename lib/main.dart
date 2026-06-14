import 'package:flutter/foundation.dart'
    show kIsWeb, kReleaseMode, defaultTargetPlatform, TargetPlatform;
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'services/push_notification_service.dart';
import 'firebase_options.dart';
import 'services/deep_link_service.dart';
import 'utils/supabase_config.dart';
import 'services/connectivity_service.dart';
import 'services/block_user_service.dart';
import 'services/auth_service.dart';
import 'services/certificate_pinning.dart';

// ── Notifier global de Dark Mode ──────────────────────────────────────────
/// Se usa desde settings_screen.dart para cambiar el tema en tiempo real.
final ValueNotifier<bool> darkModeNotifier = ValueNotifier<bool>(false);

/// Modo de tema elegido por el usuario: 'auto' | 'light' | 'dark'.
/// 'auto' sigue el brillo del sistema (y reacciona si cambia en caliente).
final ValueNotifier<String> themeModeNotifier = ValueNotifier<String>('light');

const String kThemeModeKey = 'settings_theme_mode';

/// Aplica el modo elegido y actualiza [darkModeNotifier] con el valor efectivo.
void applyThemeMode(String mode) {
  themeModeNotifier.value = mode;
  switch (mode) {
    case 'dark':
      darkModeNotifier.value = true;
    case 'light':
      darkModeNotifier.value = false;
    default: // 'auto'
      darkModeNotifier.value =
          PlatformDispatcher.instance.platformBrightness == Brightness.dark;
  }
}

/// Lee la preferencia guardada.
String readThemeMode(SharedPreferences prefs) {
  final stored = prefs.getString(kThemeModeKey);
  if (stored != null) return stored;
  if (prefs.containsKey('settings_dark_mode')) {
    return (prefs.getBool('settings_dark_mode') ?? false) ? 'dark' : 'light';
  }
  return 'auto';
}

bool _isRefreshTokenError(String msg) =>
    msg.contains('refresh_token') ||
    msg.contains('already_used') ||
    msg.contains('invalid refresh token');

void _handleFlutterError(FlutterErrorDetails details) {
  if (_isRefreshTokenError(details.exceptionAsString().toLowerCase())) {
    debugPrint('⚠️ Refresh token corrupto → forzando sign-out');
    AuthService.instance.forceSignOutCorruptSession();
    return;
  }
  try {
    if (FirebaseCrashlytics.instance.isCrashlyticsCollectionEnabled) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      return;
    }
  } catch (_) {}
  FlutterError.presentError(details);
  debugPrint('Flutter Error: ${details.exceptionAsString()}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Error handling — Fase 1: captura básica antes de Firebase
  FlutterError.onError = _handleFlutterError;
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('⚠️ ErrorWidget caught: ${details.exceptionAsString()}');
    return const SizedBox.shrink();
  };

  // ── Certificate Pinning (antes de cualquier request) ─────────────────
  if (!kIsWeb) {
    enableCertificatePinning();
  }

  // ── Inicialización crítica con retry ──────────────────────────────────
  try {
    await _initCore();
  } catch (e) {
    debugPrint('⚠️ First init failed ($e), retrying in 1s...');
    await Future.delayed(const Duration(seconds: 1));
    try {
      await _initCore();
    } catch (e2) {
      debugPrint('🔴 Critical init failed: $e2');
    }
  }

  // Set system UI overlay style (solo mobile)
  if (!kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.light,
      ),
    );
  }

  runApp(
    const ProviderScope(
      child: MployaApp(),
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════
  // NO BLOQUEANTE: Se inicia DESPUÉS de que la UI ya está visible
  // ═══════════════════════════════════════════════════════════════════════
  _initDeferredServices();
}

/// Carga Supabase + SharedPreferences.
Future<void> _initCore() async {
  if (!SupabaseConfig.isInjected) {
    debugPrint('⚠️ Using default Supabase credentials (not injected via --dart-define)');
  }

  final prefsFuture = SharedPreferences.getInstance();
  final supabaseFuture = Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  final results = await Future.wait([prefsFuture, supabaseFuture]);
  final prefs = results[0] as SharedPreferences;
  applyThemeMode(readThemeMode(prefs));

  // En modo 'auto', reaccionar si el sistema cambia entre claro y oscuro
  PlatformDispatcher.instance.onPlatformBrightnessChanged = () {
    if (themeModeNotifier.value == 'auto') {
      darkModeNotifier.value =
          PlatformDispatcher.instance.platformBrightness == Brightness.dark;
    }
  };
}

/// Servicios secundarios: Firebase, Deep Links.
/// Se ejecutan en background sin bloquear el splash.
Future<void> _initDeferredServices() async {
  // Connectivity monitoring (no-blocking)
  ConnectivityService.instance.initialize();

  // Load blocked users cache for feed filtering
  BlockUserService.instance.loadBlockedUsers();

  // Deep Links (no crítico para el primer frame)
  try {
    await DeepLinkService.instance.initialize();
  } catch (e) {
    debugPrint('DeepLink init: $e');
  }

  // ATT (solo iOS — skip on web)
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    // app_tracking_transparency omitted for web builds
    debugPrint('ℹ️ ATT skipped (web/non-iOS platform)');
  }

  // Firebase + Crashlytics + Push
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // ── Crashlytics: reusa el handler unificado + captura errores async ──
    FlutterError.onError = _handleFlutterError;
    if (!kIsWeb) {
      PlatformDispatcher.instance.onError = (error, stack) {
        if (_isRefreshTokenError(error.toString().toLowerCase())) {
          debugPrint('⚠️ Refresh token corrupto (async) → forzando sign-out');
          AuthService.instance.forceSignOutCorruptSession();
          return true;
        }
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        debugPrint('🔴 Crashlytics Async Error: $error');
        return true;
      };
    }

    if (!kIsWeb) {
      await PushNotificationService.instance.initialize();
    }
  } catch (e) {
    debugPrint('Firebase/Crashlytics init: $e');
  }
}

class MployaApp extends StatelessWidget {
  const MployaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: darkModeNotifier,
      builder: (context, isDark, _) {
        // Update system UI based on theme
        if (!kIsWeb) {
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
              statusBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
            ),
          );
        }

        return CupertinoApp(
          navigatorKey: DeepLinkService.navigatorKey,
          title: 'Mploya',
          debugShowCheckedModeBanner: false,
          theme: isDark ? MployaTheme.darkTheme : MployaTheme.lightTheme,
          // ── Internationalization (ES/EN/PT) ──
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            final bgColor =
                isDark ? const Color(0xFF000000) : const Color(0xFFF5F5F7);
            final containerColor =
                isDark ? const Color(0xFF000000) : CupertinoColors.white;
            final content = child ?? const SizedBox.shrink();

            // ── Web ancho: usar todo el viewport (layout web real). ──
            // El frame "celular" de 430px se reserva solo para móvil real o
            // ventanas angostas. Cada pantalla decide su propio ancho interno.
            final isWideWeb =
                kIsWeb && MediaQuery.of(context).size.width > 700;
            if (isWideWeb) {
              return Container(color: containerColor, child: content);
            }

            return Container(
              color: bgColor,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Container(
                    decoration: BoxDecoration(
                      color: containerColor,
                      boxShadow: isDark
                          ? []
                          : [
                              BoxShadow(
                                color: const Color(0xFF000000)
                                    .withValues(alpha: 0.05),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                    ),
                    child: ClipRect(
                      child: content,
                    ),
                  ),
                ),
              ),
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}
