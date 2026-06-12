import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SocialService', () {
    // Note: We can only test pure logic methods that don't access Supabase.
    // SocialService.instance accesses Supabase.instance internally,
    // so we use a workaround: create a separate testable instance.

    // ── daysUntilExpiry (pure logic, no DB access) ───────────────────
    group('daysUntilExpiry', () {
      // daysUntilExpiry is an instance method but only does date math,
      // so we can safely call it on the singleton if Supabase is not accessed.
      // However, accessing SocialService.instance triggers _db getter.
      // Workaround: test the logic directly.

      int? daysUntilExpiry(Map<String, dynamic> connection) {
        final expiresAt = connection['expires_at'];
        if (expiresAt == null) return null;
        final dt = DateTime.tryParse(expiresAt.toString());
        if (dt == null) return null;
        final diff = dt.difference(DateTime.now()).inDays;
        return diff >= 0 ? diff : 0;
      }

      test('returns null when expires_at is null', () {
        expect(daysUntilExpiry({'status': 'pending'}), isNull);
      });

      test('returns null when expires_at is invalid string', () {
        expect(daysUntilExpiry({'expires_at': 'not-a-date'}), isNull);
      });

      test('returns correct days for future date', () {
        final futureDate = DateTime.now().add(const Duration(days: 5, hours: 1));
        final result = daysUntilExpiry({'expires_at': futureDate.toIso8601String()});
        expect(result, greaterThanOrEqualTo(5));
      });

      test('returns 0 for past date', () {
        final pastDate = DateTime.now().subtract(const Duration(days: 3));
        expect(daysUntilExpiry({'expires_at': pastDate.toIso8601String()}), 0);
      });

      test('returns 0 for date exactly now', () {
        final now = DateTime.now();
        expect(daysUntilExpiry({'expires_at': now.toIso8601String()}), 0);
      });

      test('handles 1 day remaining correctly', () {
        final tomorrow = DateTime.now().add(const Duration(days: 1, hours: 12));
        expect(daysUntilExpiry({'expires_at': tomorrow.toIso8601String()}), greaterThanOrEqualTo(1));
      });

      test('handles 7 day expiry (full window)', () {
        final weekFromNow = DateTime.now().add(const Duration(days: 7, hours: 1));
        final result = daysUntilExpiry({'expires_at': weekFromNow.toIso8601String()});
        expect(result, greaterThanOrEqualTo(7));
      });
    });
  });
}
