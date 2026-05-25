/// Configuración de entorno para mploya.
///
/// Lee las variables de entorno desde el archivo `.env` ubicado en
/// `assets/.env` usando `flutter_dotenv`. Todas las credenciales
/// sensibles se mantienen fuera del código fuente.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Provee acceso tipado a las variables de entorno de la aplicación.
///
/// Antes de usar cualquier getter, asegúrate de llamar a
/// `await dotenv.load(fileName: 'assets/.env')` en `main()`.
abstract final class Env {
  // ─────────────────────────────────────────
  // Supabase
  // ─────────────────────────────────────────

  /// URL del proyecto en Supabase.
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? _throwMissing('SUPABASE_URL');

  /// Clave anónima (pública) de Supabase.
  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? _throwMissing('SUPABASE_ANON_KEY');

  // ─────────────────────────────────────────
  // Jitsi (videollamadas)
  // ─────────────────────────────────────────

  /// URL del servidor Jitsi Meet. Por defecto: `https://meet.jit.si`.
  static String get jitsiServerUrl =>
      dotenv.env['JITSI_SERVER_URL'] ?? 'https://meet.jit.si';

  // ─────────────────────────────────────────
  // Google OAuth
  // ─────────────────────────────────────────

  /// Client ID de Google para autenticación web/Android.
  static String get googleWebClientId =>
      dotenv.env['GOOGLE_WEB_CLIENT_ID'] ??
      _throwMissing('GOOGLE_WEB_CLIENT_ID');

  // ─────────────────────────────────────────
  // Gemini AI
  // ─────────────────────────────────────────

  /// API Key de Google Gemini para funcionalidades de IA.
  /// Retorna cadena vacía si no está configurada (las features de IA
  /// se desactivan graciosamente).
  static String get geminiApiKey {
    final key = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (key.isEmpty) {
      debugPrint(
        '⚠️ Env: GEMINI_API_KEY no configurada. '
        'Las funcionalidades de IA estarán desactivadas.',
      );
    }
    return key;
  }

  // ─────────────────────────────────────────
  // Stripe (pagos)
  // ─────────────────────────────────────────

  /// Clave pública de Stripe. Vacía si no está configurada.
  static String get stripePublishableKey {
    final key = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
    if (key.isEmpty) {
      debugPrint(
        '⚠️ Env: STRIPE_PUBLISHABLE_KEY no configurada. '
        'Los pagos con Stripe estarán desactivados.',
      );
    }
    return key;
  }

  // ─────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────

  /// Lanza una excepción clara cuando falta una variable requerida.
  static Never _throwMissing(String key) {
    throw StateError(
      'Variable de entorno "$key" no encontrada. '
      'Asegúrate de definirla en assets/.env',
    );
  }
}
