/// Punto de entrada de la aplicación mploya.
///
/// Inicializa todos los servicios necesarios antes de ejecutar la app:
/// - Flutter bindings
/// - Variables de entorno (.env)
/// - Supabase
/// - Firebase (opcional, con fallback para desarrollo)
/// - Orientación y estilos del sistema
library;

import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mploya/app.dart';
import 'package:mploya/firebase_options.dart';
import 'package:mploya/core/services/notification_service.dart';
import 'package:mploya/core/services/stripe_service.dart';
import 'package:mploya/core/services/supabase_service.dart';

Future<void> main() async {
  // Asegurar que los bindings de Flutter estén inicializados.
  WidgetsFlutterBinding.ensureInitialized();

  // ── Variables de entorno ──
  await dotenv.load(fileName: 'assets/.env');

  // ── Supabase ──
  await SupabaseService.initialize();

  // ── Firebase ──
  // Envuelto en try-catch para permitir desarrollo sin Firebase configurado.
  // Nota: firebase_options.dart se genera con `flutterfire configure`.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Configurar Crashlytics solo en release.
    if (kReleaseMode) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }

    // Registrar handler de notificaciones en background.
    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );

    // Inicializar servicio de notificaciones push.
    await NotificationService.instance.initialize();

    debugPrint('✅ Firebase inicializado correctamente.');
  } catch (e) {
    debugPrint('⚠️ Firebase no pudo inicializarse: $e');
    debugPrint('   La app continuará sin Firebase.');
  }

  // ── Stripe ──
  // Inicializar servicio de pagos (falla silenciosamente si no hay clave).
  await StripeService.instance.initialize();

  // ── Orientación ──
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Estilo del system chrome ──
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // ── Error handling global ──
  // Previene la pantalla roja mostrando un widget amigable.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('⚠️ ErrorWidget: ${details.exception}');
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh_rounded, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Cargando...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  };

  // Captura errores de Flutter sin crashear.
  // Chain with the previous handler (e.g. Crashlytics) instead of overwriting.
  final previousErrorHandler = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    previousErrorHandler?.call(details);
    debugPrint('⚠️ FlutterError: ${details.exception}');
    debugPrint('   ${details.stack}');
  };

  // ── Ejecutar la app ──
  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
