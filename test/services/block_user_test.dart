import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/services/block_user_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Unit tests para BlockUserService — cache local de bloqueos
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  late BlockUserService service;

  setUp(() {
    service = BlockUserService.instance;
    service.clear(); // Reset state
  });

  group('Local cache', () {
    test('blockedIds starts empty after clear', () {
      expect(service.blockedIds, isEmpty);
    });

    test('isBlocked returns false for unknown user', () {
      expect(service.isBlocked('unknown-id'), false);
    });

    test('blockedIds returns unmodifiable set', () {
      final ids = service.blockedIds;
      expect(() => ids.add('test'), throwsUnsupportedError);
    });

    test('clear resets all state', () {
      service.clear();
      expect(service.blockedIds, isEmpty);
    });
  });

  group('BlockUserService singleton', () {
    test('instance is singleton', () {
      final a = BlockUserService.instance;
      final b = BlockUserService.instance;
      expect(identical(a, b), true);
    });
  });
}
