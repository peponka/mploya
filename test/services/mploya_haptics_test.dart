import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/services/mploya_haptics.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Unit tests para MployaHaptics — Patterns never throw
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock the haptic feedback platform channel
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter/haptic'),
      (MethodCall methodCall) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async => null,
    );
  });

  group('MployaHaptics patterns', () {
    test('success does not throw', () {
      expect(() => MployaHaptics.success(), returnsNormally);
    });

    test('warning does not throw', () {
      expect(() => MployaHaptics.warning(), returnsNormally);
    });

    test('error does not throw', () {
      expect(() => MployaHaptics.error(), returnsNormally);
    });

    test('selection does not throw', () {
      expect(() => MployaHaptics.selection(), returnsNormally);
    });

    test('light does not throw', () {
      expect(() => MployaHaptics.light(), returnsNormally);
    });

    test('impact does not throw', () {
      expect(() => MployaHaptics.impact(), returnsNormally);
    });

    test('notification does not throw', () {
      expect(() => MployaHaptics.notification(), returnsNormally);
    });
  });

  group('MployaHaptics class structure', () {
    test('all 7 haptic methods exist', () {
      // Compile-time check: if these don't exist, test won't compile
      MployaHaptics.success;
      MployaHaptics.warning;
      MployaHaptics.error;
      MployaHaptics.selection;
      MployaHaptics.light;
      MployaHaptics.impact;
      MployaHaptics.notification;
    });
  });
}
