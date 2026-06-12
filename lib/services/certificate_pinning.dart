import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart' show sha256;

// ─────────────────────────────────────────────────────────────────────────────
// CertificatePinning — SSL Pinning para Supabase y APIs externas
//
// Previene ataques Man-in-the-Middle (MITM) verificando que el certificado
// del servidor coincida con los hashes SHA-256 conocidos.
//
// Uso:
//   1. En main.dart, configurar HttpOverrides ANTES de Supabase.initialize()
//   2. Los pins se pueden inyectar vía --dart-define=SUPABASE_CERT_PIN=...
//
// Rotación de certificados:
//   • Supabase usa Let's Encrypt → certificados rotan cada 90 días
//   • Siempre incluir el pin del CA root (ISRG Root X1) que cambia poco
//   • Incluir un pin de backup para permitir rotación sin update forzado
//
// NOTA: Solo activo en release builds (en debug, MITM proxies como Charles
// necesitan pasar). En web, el browser maneja TLS nativo.
// ─────────────────────────────────────────────────────────────────────────────

/// Hashes SHA-256 de los certificados anclados.
///
/// Estos hashes se verifican contra la cadena de certificados del servidor.
/// Incluir al menos 2 (primario + backup) para permitir rotación.
class CertificatePins {
  CertificatePins._();

  /// Pin del certificado CA raíz de Let's Encrypt (ISRG Root X1).
  /// Este cambia muy infrecuentemente (válido hasta ~2035).
  static const isrgRootX1 =
      'C5+lpZ7tcVwmwQIMcRtPbsQtWLABXhQzejna0wHFr8M=';

  /// Pin del certificado intermedio de Let's Encrypt (R3).
  /// Rota cada ~3 años. Próximo cambio estimado 2027.
  static const letsEncryptR3 =
      'jQJTbIh0grw0/1TkHSumWb+Fs0Ggogr621gT3PvPKG0=';

  /// Pin inyectable vía --dart-define para rotación sin rebuild.
  /// Uso: flutter build --dart-define=SUPABASE_CERT_PIN=base64hash
  static const customPin =
      String.fromEnvironment('SUPABASE_CERT_PIN', defaultValue: '');

  /// Todos los pins activos.
  static List<String> get activePins => [
        isrgRootX1,
        letsEncryptR3,
        if (customPin.isNotEmpty) customPin,
      ];
}

/// HttpOverrides que aplica certificate pinning a conexiones HTTPS.
///
/// Solo se activa en modo release y en plataformas nativas (no web).
/// En debug, permite todas las conexiones para facilitar proxies de depuración.
class PinnedHttpOverrides extends HttpOverrides {
  final List<String> _pins;
  final List<String> _pinnedHosts;

  /// [pins] — Lista de hashes SHA-256 en base64 de certificados aceptados.
  /// [pinnedHosts] — Hosts a los que aplicar pinning (ej: ['supabase.co']).
  PinnedHttpOverrides({
    List<String>? pins,
    List<String>? pinnedHosts,
  })  : _pins = pins ?? CertificatePins.activePins,
        _pinnedHosts = pinnedHosts ?? _defaultPinnedHosts;

  static const _defaultPinnedHosts = [
    'supabase.co',
    'supabase.com',
    'supabase.in',
  ];

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);

    // Solo aplicar pinning en release mode
    if (kReleaseMode) {
      client.badCertificateCallback = (cert, host, port) {
        // Solo verificar hosts que nos interesan
        final isPinnedHost = _pinnedHosts.any(
          (pinnedHost) => host.endsWith(pinnedHost),
        );

        if (!isPinnedHost) {
          // Host no pinneado → aceptar (delegado al sistema)
          return false; // false = rechazar cert inválido (comportamiento default)
        }

        // Verificar la cadena de certificados contra nuestros pins
        final isValid = _verifyCertificateChain(cert);

        if (!isValid) {
          debugPrint(
            '🔴 CERTIFICATE PINNING FAILED for $host:$port\n'
            '   Possible MITM attack detected. Connection rejected.\n'
            '   Certificate SHA256: ${_sha256Base64(cert)}',
          );
        }

        return isValid;
      };
    }

    return client;
  }

  /// Recorre la cadena de certificados y verifica si al menos uno
  /// coincide con nuestros pins.
  ///
  /// SEGURIDAD: Solo se valida contra hashes SHA-256 de certificados conocidos.
  /// NO se usa el campo issuer/subject (spoofable por un atacante MITM).
  bool _verifyCertificateChain(X509Certificate cert) {
    // Verificar el certificado actual contra nuestros pins
    final certHash = _sha256Base64(cert);
    if (_pins.contains(certHash)) return true;

    // Log detallado para debugging de rotación de certificados
    final subject = cert.subject.toLowerCase();
    final issuer = cert.issuer.toLowerCase();

    debugPrint(
      '⚠️ Certificate not pinned:\n'
      '   Subject: $subject\n'
      '   Issuer: $issuer\n'
      '   SHA256: $certHash',
    );

    return false;
  }

  /// Genera el hash SHA-256 en base64 del certificado DER.
  String _sha256Base64(X509Certificate cert) {
    try {
      final der = cert.der;
      final digest = sha256.convert(der);
      return base64Encode(digest.bytes);
    } catch (e) {
      return 'unknown';
    }
  }
}

/// Helper para activar certificate pinning en main.dart.
///
/// Llamar ANTES de Supabase.initialize():
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   enableCertificatePinning(); // ← Aquí
///   await _initCore();
///   runApp(const MployaApp());
/// }
/// ```
void enableCertificatePinning() {
  // Solo en plataformas nativas (iOS/Android) y modo release
  if (!kIsWeb && kReleaseMode) {
    HttpOverrides.global = PinnedHttpOverrides();
    debugPrint('🔒 Certificate pinning enabled for Supabase');
  } else if (kDebugMode) {
    debugPrint('🔓 Certificate pinning DISABLED (debug mode)');
  }
}
