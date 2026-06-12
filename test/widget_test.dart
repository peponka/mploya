import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Mploya — Widget & theme smoke tests
//
//  These tests validate theme consistency and design system correctness
//  WITHOUT requiring Supabase or Firebase initialization.
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('NexTheme — Brand Colors', () {
    test('brand accent is warm orange', () {
      expect(NexTheme.brandAccent, const Color(0xFFF97316));
    });

    test('brand accent dark is lighter for dark mode contrast', () {
      // Dark mode brand should be lighter than light mode brand
      expect(
        NexTheme.brandAccentDark.computeLuminance(),
        greaterThan(NexTheme.brandAccent.computeLuminance()),
      );
    });

    test('all semantic colors are opaque', () {
      expect((NexTheme.openToWork.a * 255).round(), 255);
      expect((NexTheme.hiring.a * 255).round(), 255);
      expect((NexTheme.danger.a * 255).round(), 255);
      expect((NexTheme.success.a * 255).round(), 255);
      expect((NexTheme.info.a * 255).round(), 255);
    });
  });

  group('NexTheme — Spacing Grid', () {
    test('all spacing values follow 4pt or 2pt grid', () {
      final spacings = [
        NexTheme.spaceXXS,
        NexTheme.spaceXS,
        NexTheme.spaceSM,
        NexTheme.spaceMD,
        NexTheme.spaceLG,
        NexTheme.spaceXL,
        NexTheme.spaceXXL,
        NexTheme.spaceHuge,
      ];
      for (final s in spacings) {
        expect(s % 2, equals(0), reason: '$s is not on the 2pt grid');
      }
    });
  });

  group('NexTheme — Light/Dark Themes', () {
    test('light theme uses light brightness', () {
      expect(NexTheme.lightTheme.brightness, Brightness.light);
    });

    test('dark theme uses dark brightness', () {
      expect(NexTheme.darkTheme.brightness, Brightness.dark);
    });

    test('dark background is true black for OLED', () {
      expect(NexTheme.darkBg, const Color(0xFF000000));
    });

    test('light and dark text colors have proper contrast', () {
      // Dark text on light bg should be darker than light text on dark bg
      expect(
        NexTheme.lightText.computeLuminance(),
        lessThan(NexTheme.darkText.computeLuminance()),
      );
    });
  });

  group('NexTheme — Radii', () {
    test('pill radius is large enough for any element', () {
      expect(NexTheme.radiusPill, greaterThanOrEqualTo(999));
    });

    test('radii are in ascending order', () {
      expect(NexTheme.radiusSM, lessThan(NexTheme.radiusMD));
      expect(NexTheme.radiusMD, lessThan(NexTheme.radiusLG));
      expect(NexTheme.radiusLG, lessThan(NexTheme.radiusXL));
      expect(NexTheme.radiusXL, lessThan(NexTheme.radiusXXL));
    });
  });

  group('NexTheme — Glassmorphism', () {
    test('glass decoration creates semi-transparent container', () {
      final decoration = NexTheme.glassDecoration();
      expect(decoration.color, isNotNull);
      // Default opacity should be 0.7 (not fully opaque)
      expect((decoration.color!.a * 255).round(), lessThan(255));
    });

    test('dark glass decoration has low opacity', () {
      final decoration = NexTheme.darkGlassDecoration();
      expect(decoration.color, isNotNull);
      expect((decoration.color!.a * 255).round(), lessThan(128));
    });
  });

  group('MployaTheme backward compatibility', () {
    test('MployaTheme is an alias for NexTheme', () {
      expect(MployaTheme.brandAccent, NexTheme.brandAccent);
      expect(MployaTheme.lightTheme.brightness, NexTheme.lightTheme.brightness);
    });
  });
}
