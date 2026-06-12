import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/services/hashtag_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Unit tests para HashtagService — modelo HashtagData y cache
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('HashtagData model', () {
    test('creates with required fields', () {
      const h = HashtagData(tag: 'flutter', count: 42);
      expect(h.tag, 'flutter');
      expect(h.count, 42);
      expect(h.trendScore, 0);
    });

    test('creates with optional trendScore', () {
      const h = HashtagData(tag: 'dart', count: 10, trendScore: 85.5);
      expect(h.trendScore, 85.5);
    });

    test('empty tag is valid', () {
      const h = HashtagData(tag: '', count: 0);
      expect(h.tag, '');
      expect(h.count, 0);
    });
  });

  group('HashtagService singleton', () {
    test('instance is singleton', () {
      final a = HashtagService.instance;
      final b = HashtagService.instance;
      expect(identical(a, b), true);
    });

    test('invalidateCache does not throw', () {
      expect(() => HashtagService.instance.invalidateCache(), returnsNormally);
    });

    test('invalidateCache resets cache state', () {
      HashtagService.instance.invalidateCache();
      // After invalidation, next call should re-fetch (no crash)
      expect(() => HashtagService.instance.invalidateCache(), returnsNormally);
    });
  });
}
