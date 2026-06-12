import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/services/employer_rating_service.dart';

void main() {
  group('EmployerReview', () {
    test('fromJson parses complete data', () {
      final json = {
        'id': '123',
        'candidate_id': 'c1',
        'company_id': 'co1',
        'overall_stars': 4.5,
        'communication_stars': 4.0,
        'transparency_stars': 5.0,
        'respect_stars': 3.5,
        'comment': 'Great experience',
        'process_type': 'interview',
        'created_at': '2026-04-30T10:00:00Z',
        'candidate': {
          'name': 'Juan',
          'headline': 'Dev',
          'avatar_url': 'https://example.com/avatar.jpg',
        },
      };
      final review = EmployerReview.fromJson(json);
      expect(review.id, '123');
      expect(review.candidateId, 'c1');
      expect(review.companyId, 'co1');
      expect(review.overallStars, 4.5);
      expect(review.communicationStars, 4.0);
      expect(review.transparencyStars, 5.0);
      expect(review.respectStars, 3.5);
      expect(review.comment, 'Great experience');
      expect(review.processType, 'interview');
      expect(review.candidateName, 'Juan');
      expect(review.candidateHeadline, 'Dev');
      expect(review.candidateAvatarUrl, 'https://example.com/avatar.jpg');
    });

    test('fromJson handles null fields gracefully', () {
      final json = <String, dynamic>{
        'id': null,
        'candidate_id': null,
        'company_id': null,
        'overall_stars': null,
        'created_at': null,
      };
      final review = EmployerReview.fromJson(json);
      expect(review.id, '');
      expect(review.candidateId, '');
      expect(review.overallStars, 0);
      expect(review.candidateName, isNull);
    });

    test('fromJson handles integer stars (type coercion)', () {
      final json = <String, dynamic>{
        'id': '1',
        'candidate_id': 'c1',
        'company_id': 'co1',
        'overall_stars': 4,
        'communication_stars': 3,
        'created_at': '2026-01-01T00:00:00Z',
      };
      final review = EmployerReview.fromJson(json);
      expect(review.overallStars, 4.0);
      expect(review.communicationStars, 3.0);
    });

    test('fromJson handles missing candidate join data', () {
      final json = <String, dynamic>{
        'id': '1',
        'candidate_id': 'c1',
        'company_id': 'co1',
        'overall_stars': 5,
        'created_at': '2026-01-01T00:00:00Z',
      };
      final review = EmployerReview.fromJson(json);
      expect(review.candidateName, isNull);
      expect(review.candidateHeadline, isNull);
      expect(review.candidateAvatarUrl, isNull);
    });
  });

  group('EmployerRatingSummary', () {
    test('badge returns empty for new company (no reviews)', () {
      const summary = EmployerRatingSummary();
      expect(summary.badge, '');
    });

    test('badge returns Recomendada for high rating + enough reviews', () {
      const summary = EmployerRatingSummary(avgOverall: 4.8, totalReviews: 5, isRecommended: true);
      expect(summary.badge, contains('Recomendada'));
    });

    test('badge requires at least 3 reviews for Recomendada', () {
      const summary = EmployerRatingSummary(avgOverall: 5.0, totalReviews: 2);
      expect(summary.badge, contains('Buena'));
    });

    test('badge returns Buena for 4.0-4.49', () {
      const summary = EmployerRatingSummary(avgOverall: 4.2, totalReviews: 10);
      expect(summary.badge, contains('Buena'));
    });

    test('badge returns empty for average rating (3.0-3.99)', () {
      const summary = EmployerRatingSummary(avgOverall: 3.5, totalReviews: 5);
      expect(summary.badge, '');
    });

    test('badge returns warning for low rating', () {
      const summary = EmployerRatingSummary(avgOverall: 2.1, totalReviews: 3);
      expect(summary.badge, contains('Baja'));
    });

    test('responseTimeBadge returns fast for <24h', () {
      const summary = EmployerRatingSummary(avgResponseTimeHours: 12);
      expect(summary.responseTimeBadge, contains('<24h'));
    });

    test('responseTimeBadge returns medium for <48h', () {
      const summary = EmployerRatingSummary(avgResponseTimeHours: 36);
      expect(summary.responseTimeBadge, contains('<48h'));
    });

    test('responseTimeBadge returns slow for >72h', () {
      const summary = EmployerRatingSummary(avgResponseTimeHours: 96);
      expect(summary.responseTimeBadge, contains('>72h'));
    });

    test('responseTimeBadge returns empty for 0', () {
      const summary = EmployerRatingSummary(avgResponseTimeHours: 0);
      expect(summary.responseTimeBadge, '');
    });

    test('responseTimeBadge returns empty for 48-72h gap', () {
      const summary = EmployerRatingSummary(avgResponseTimeHours: 60);
      expect(summary.responseTimeBadge, '');
    });
  });
}
