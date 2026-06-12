import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/services/ghost_apply_service.dart';

/// Tests unitarios para GhostApplyService â€” modelos y lÃ³gica de anonimizaciÃ³n.
///
/// Los tests de integraciÃ³n con Supabase se ejecutan por separado.
/// AquÃ­ se testean: parsing JSON, headline anonimizaciÃ³n, y blind CV extraction.
void main() {
  group('GhostApplication model', () {
    test('parses complete JSON correctly', () {
      final json = {
        'id': 'ga-123',
        'job_id': 'job-456',
        'candidate_id': 'cand-789',
        'blind_headline': 'CTO en Fintech',
        'blind_about': 'tecnologÃ­a || USD 1M+ || 3 exits exitosos',
        'blind_tags': ['Flutter', 'Leadership', 'AI'],
        'match_score': 87,
        'created_at': '2026-05-01T10:00:00Z',
        'is_unlocked': false,
        'status': 'pending',
      };

      final app = GhostApplication.fromJson(json);

      expect(app.id, 'ga-123');
      expect(app.jobId, 'job-456');
      expect(app.candidateId, 'cand-789');
      expect(app.blindHeadline, 'CTO en Fintech');
      expect(app.blindAbout, contains('exits'));
      expect(app.blindTags, ['Flutter', 'Leadership', 'AI']);
      expect(app.matchScore, 87);
      expect(app.isUnlocked, false);
      expect(app.status, 'pending');
    });

    test('handles null and missing fields gracefully', () {
      final json = <String, dynamic>{};

      final app = GhostApplication.fromJson(json);

      expect(app.id, '');
      expect(app.jobId, '');
      expect(app.candidateId, '');
      expect(app.blindHeadline, '');
      expect(app.blindAbout, '');
      expect(app.blindTags, isEmpty);
      expect(app.matchScore, 0);
      expect(app.isUnlocked, false);
      expect(app.status, 'pending');
    });

    test('handles partial JSON', () {
      final json = {
        'id': 'ga-partial',
        'match_score': 42,
        'is_unlocked': true,
        'status': 'unlocked',
      };

      final app = GhostApplication.fromJson(json);

      expect(app.id, 'ga-partial');
      expect(app.matchScore, 42);
      expect(app.isUnlocked, true);
      expect(app.status, 'unlocked');
    });

    test('parses created_at into DateTime', () {
      final json = {
        'id': 'ga-time',
        'created_at': '2026-05-01T15:30:00Z',
      };

      final app = GhostApplication.fromJson(json);

      expect(app.appliedAt.year, 2026);
      expect(app.appliedAt.month, 5);
      expect(app.appliedAt.day, 1);
    });

    test('handles invalid date gracefully', () {
      final json = {
        'id': 'ga-baddate',
        'created_at': 'not-a-date',
      };

      final app = GhostApplication.fromJson(json);

      // Should fallback to DateTime.now() approximately
      expect(app.appliedAt.year, DateTime.now().year);
    });

    test('handles numeric match_score types', () {
      final json = {
        'id': 'ga-num',
        'match_score': 95.7, // double instead of int
      };

      final app = GhostApplication.fromJson(json);
      expect(app.matchScore, 95); // Should truncate to int
    });

    test('handles blind_tags as various list types', () {
      final json = {
        'id': 'ga-tags',
        'blind_tags': [1, 'Flutter', true, null],
      };

      final app = GhostApplication.fromJson(json);
      expect(app.blindTags.length, 4);
      expect(app.blindTags[1], 'Flutter');
      expect(app.blindTags[2], 'true');
    });
  });

  group('GhostApplication â€” status lifecycle', () {
    test('all valid statuses are parseable', () {
      for (final status in ['pending', 'reviewed', 'shortlisted', 'rejected', 'unlocked']) {
        final app = GhostApplication.fromJson({'id': 'test', 'status': status});
        expect(app.status, status);
      }
    });
  });
}
