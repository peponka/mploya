import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/services/connectivity_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Unit tests para ConnectivityService — estado offline/online y cola
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  late ConnectivityService service;

  setUp(() {
    service = ConnectivityService.instance;
  });

  group('ConnectivityService', () {
    test('instance is singleton', () {
      final a = ConnectivityService.instance;
      final b = ConnectivityService.instance;
      expect(identical(a, b), true);
    });

    test('isOnline defaults to true', () {
      expect(service.isOnline, true);
    });

    test('onlineStream is broadcast', () {
      // Broadcast streams can have multiple listeners
      service.onlineStream.listen((_) {});
      service.onlineStream.listen((_) {}); // Should not throw
    });

    test('enqueue runs immediately when online', () async {
      bool executed = false;
      service.enqueue(() async {
        executed = true;
      });
      // Give it a moment to execute
      await Future.delayed(const Duration(milliseconds: 100));
      expect(executed, true);
    });
  });
}
