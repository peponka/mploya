import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/services/certificate_pinning.dart';

void main() {
  group('CertificatePins', () {
    test('activePins contains at least 2 default pins', () {
      final pins = CertificatePins.activePins;
      expect(pins.length, greaterThanOrEqualTo(2));
    });

    test('ISRG Root X1 pin is non-empty base64', () {
      expect(CertificatePins.isrgRootX1.isNotEmpty, true);
      expect(CertificatePins.isrgRootX1.endsWith('='), true);
    });

    test('LetsEncrypt R3 pin is non-empty base64', () {
      expect(CertificatePins.letsEncryptR3.isNotEmpty, true);
      expect(CertificatePins.letsEncryptR3.endsWith('='), true);
    });

    test('customPin defaults to empty when no env var', () {
      expect(CertificatePins.customPin, '');
    });

    test('activePins does not include empty custom pin', () {
      final pins = CertificatePins.activePins;
      expect(pins.contains(''), false);
    });

    test('pins are unique', () {
      final pins = CertificatePins.activePins;
      expect(pins.toSet().length, pins.length);
    });

    test('pins look like valid base64 SHA-256', () {
      // SHA-256 hash in base64 is always 44 chars ending with =
      for (final pin in CertificatePins.activePins) {
        expect(pin.length, 44, reason: 'Pin $pin should be 44 chars (base64 SHA-256)');
      }
    });
  });

  group('PinnedHttpOverrides', () {
    test('can be created with default pins', () {
      final overrides = PinnedHttpOverrides();
      expect(overrides, isNotNull);
    });

    test('can be created with custom pins', () {
      final overrides = PinnedHttpOverrides(
        pins: ['abc123=', 'def456='],
        pinnedHosts: ['example.com'],
      );
      expect(overrides, isNotNull);
    });

    test('createHttpClient returns a valid client', () {
      final overrides = PinnedHttpOverrides();
      final client = overrides.createHttpClient(null);
      expect(client, isA<HttpClient>());
    });

    test('is a subclass of HttpOverrides', () {
      final overrides = PinnedHttpOverrides();
      expect(overrides, isA<HttpOverrides>());
    });
  });

  group('enableCertificatePinning', () {
    test('function exists and is callable', () {
      // In test mode (kDebugMode), this is a no-op
      // Just verify it doesn't throw
      enableCertificatePinning();
    });
  });
}
