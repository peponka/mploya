import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/services/notification_service.dart';
import 'package:mploya/models/models.dart';

void main() {
  group('NotificationService', () {
    group('timeAgo', () {
      final service = NotificationService.instance;

      test('returns "Ahora" for timestamps within last minute', () {
        final now = DateTime.now().subtract(const Duration(seconds: 30));
        expect(service.timeAgo(now.toIso8601String()), 'Ahora');
      });

      test('returns minutes for recent timestamps', () {
        final fiveMinAgo = DateTime.now().subtract(const Duration(minutes: 5));
        expect(service.timeAgo(fiveMinAgo.toIso8601String()), '5m');
      });

      test('returns hours for older timestamps', () {
        final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));
        expect(service.timeAgo(twoHoursAgo.toIso8601String()), '2h');
      });

      test('returns days for very old timestamps', () {
        final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
        expect(service.timeAgo(threeDaysAgo.toIso8601String()), '3d');
      });

      test('returns "Reciente" for null input', () {
        expect(service.timeAgo(null), 'Reciente');
      });

      test('returns "Reciente" for invalid string', () {
        expect(service.timeAgo('not-a-date'), 'Reciente');
      });
    });

    group('getInsightTip', () {
      final service = NotificationService.instance;

      test('prioritizes pitches tip when pitches > 0', () {
        final tip = service.getInsightTip(5, 10, 20);
        expect(tip, contains('5 video replies'));
      });

      test('shows matches tip when no pitches but matches > 0', () {
        final tip = service.getInsightTip(0, 10, 20);
        expect(tip, contains('10 matches'));
      });

      test('shows views tip when views > 3 and no pitches/matches', () {
        final tip = service.getInsightTip(0, 0, 15);
        expect(tip, contains('15 vistas'));
      });

      test('shows generic tip when all metrics are low', () {
        final tip = service.getInsightTip(0, 0, 0);
        expect(tip, contains('perfil'));
      });
    });

    group('getStealthTip', () {
      final service = NotificationService.instance;

      test('prompts for video when missing', () {
        const user = NexUser(
          id: '1', name: 'Stealth', headline: 'CFO',
          accountType: 'confidencial',
          videoUrl: null,
        );
        final tip = service.getStealthTip(user);
        expect(tip, isNotNull);
        expect(tip!, contains('video-pitch'));
      });

      test('prompts for about when video exists but about missing', () {
        const user = NexUser(
          id: '1', name: 'Stealth', headline: 'CFO',
          accountType: 'confidencial',
          videoUrl: 'https://example.com/pitch.mp4',
          about: null,
        );
        final tip = service.getStealthTip(user);
        expect(tip, isNotNull);
        expect(tip!, contains('descripci'));
      });

      test('prompts for tags when video and about exist but tags empty', () {
        const user = NexUser(
          id: '1', name: 'Stealth', headline: 'CFO',
          accountType: 'confidencial',
          videoUrl: 'https://example.com/pitch.mp4',
          about: 'Senior executive with 20 years experience',
          tags: [],
        );
        final tip = service.getStealthTip(user);
        expect(tip, isNotNull);
        expect(tip!, contains('habilidades'));
      });

      test('returns engagement tip when profile is complete', () {
        const user = NexUser(
          id: '1', name: 'Stealth', headline: 'CFO',
          accountType: 'confidencial',
          videoUrl: 'https://example.com/pitch.mp4',
          about: 'Senior executive',
          tags: ['#finanzas', '#strategy'],
        );
        final tip = service.getStealthTip(user);
        expect(tip, isNotNull);
        expect(tip!, contains('activo'));
      });
    });
  });
}
