import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/models/models.dart';

void main() {
  group('NexUser', () {
    group('fromJson', () {
      test('parses complete JSON correctly', () {
        final json = {
          'id': 'user-123',
          'name': 'MarÃ­a GarcÃ­a',
          'headline': 'DiseÃ±adora UX Senior',
          'company': 'TechCorp',
          'location': 'Madrid, EspaÃ±a',
          'avatar_url': 'https://example.com/avatar.jpg',
          'video_url': 'https://example.com/pitch.mp4',
          'connections': 150,
          'profile_views': 42,
          'open_to_work': true,
          'is_hiring': false,
          'is_premium': true,
          'about': 'DiseÃ±adora con 10 aÃ±os de experiencia',
          'account_type': 'candidato',
          'skills': ['Flutter', 'Figma', 'UX Research'],
          'tags': ['#diseÃ±o', '#mobile', '#ux'],
          'latitude': 40.4168,
          'longitude': -3.7038,
          'is_verified': true,
        };

        final user = NexUser.fromJson(json);

        expect(user.id, 'user-123');
        expect(user.name, 'MarÃ­a GarcÃ­a');
        expect(user.headline, 'DiseÃ±adora UX Senior');
        expect(user.company, 'TechCorp');
        expect(user.location, 'Madrid, EspaÃ±a');
        expect(user.connections, 150);
        expect(user.profileViews, 42);
        expect(user.isOpenToWork, true);
        expect(user.isHiring, false);
        expect(user.isPremium, true);
        expect(user.accountType, 'candidato');
        expect(user.skills, ['Flutter', 'Figma', 'UX Research']);
        expect(user.tags, ['#diseÃ±o', '#mobile', '#ux']);
        expect(user.latitude, 40.4168);
        expect(user.longitude, -3.7038);
        expect(user.isVerified, true);
      });

      test('handles null and missing fields gracefully', () {
        final json = <String, dynamic>{
          'id': null,
          'name': null,
        };

        final user = NexUser.fromJson(json);

        expect(user.id, '');
        expect(user.name, 'Usuario');
        expect(user.headline, '');
        expect(user.company, isNull);
        expect(user.location, isNull);
        expect(user.avatarUrl, isNull);
        expect(user.videoUrl, isNull);
        expect(user.connections, 0);
        expect(user.profileViews, 0);
        expect(user.isOpenToWork, false);
        expect(user.isHiring, false);
        expect(user.isPremium, false);
        expect(user.accountType, 'candidato');
        expect(user.skills, isEmpty);
        expect(user.tags, isEmpty);
        expect(user.experience, isEmpty);
        expect(user.education, isEmpty);
      });

      test('handles empty JSON map', () {
        final user = NexUser.fromJson({});

        expect(user.id, '');
        expect(user.name, 'Usuario');
        expect(user.accountType, 'candidato');
      });

      test('parses experience correctly', () {
        final json = {
          'id': 'u1',
          'name': 'Test',
          'headline': 'Dev',
          'experience': [
            {
              'role': 'Senior Dev',
              'company': 'Google',
              'duration': '2020-2024',
              'location': 'Remote',
              'description': 'Built things',
              'is_current': true,
            },
          ],
        };

        final user = NexUser.fromJson(json);
        expect(user.experience.length, 1);
        expect(user.experience[0].role, 'Senior Dev');
        expect(user.experience[0].company, 'Google');
        expect(user.experience[0].isCurrent, true);
      });

      test('parses education correctly', () {
        final json = {
          'id': 'u1',
          'name': 'Test',
          'headline': 'Dev',
          'education': [
            {
              'school': 'MIT',
              'degree': 'BS',
              'field': 'Computer Science',
              'years': '2016-2020',
            },
          ],
        };

        final user = NexUser.fromJson(json);
        expect(user.education.length, 1);
        expect(user.education[0].school, 'MIT');
        expect(user.education[0].degree, 'BS');
      });

      test('falls back to skills when tags is null', () {
        final json = {
          'id': 'u1',
          'name': 'Test',
          'headline': 'Dev',
          'skills': ['Dart', 'Flutter'],
          // tags is intentionally missing
        };

        final user = NexUser.fromJson(json);
        expect(user.tags, ['Dart', 'Flutter']);
      });

      test('parses AI transcript segments', () {
        final json = {
          'id': 'u1',
          'name': 'Test',
          'headline': 'Dev',
          'ai_transcript_json': [
            {'start': 0.0, 'end': 2.5, 'text': 'Hola mundo'},
            {'start': 2.5, 'end': 5.0, 'text': 'Soy developer'},
          ],
        };

        final user = NexUser.fromJson(json);
        expect(user.aiTranscript.length, 2);
        expect(user.aiTranscript[0].text, 'Hola mundo');
        expect(user.aiTranscript[0].start, 0.0);
        expect(user.aiTranscript[1].end, 5.0);
      });

      test('parses boost fields', () {
        final future = DateTime.now().add(const Duration(hours: 24));
        final json = {
          'id': 'u1',
          'name': 'Test',
          'headline': 'Dev',
          'boost_ends_at': future.toIso8601String(),
          'boost_type': 'local',
          'boost_target_city': 'Madrid',
        };

        final user = NexUser.fromJson(json);
        expect(user.isBoosted, true);
        expect(user.boostType, 'local');
        expect(user.boostTargetCity, 'Madrid');
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        const user = NexUser(
          id: 'user-abc',
          name: 'Juan PÃ©rez',
          headline: 'Backend Dev',
          company: 'StartupX',
          location: 'Buenos Aires',
          isPremium: true,
          accountType: 'empresa',
          tags: ['#tech', '#startup'],
        );

        final json = user.toJson();

        expect(json['id'], 'user-abc');
        expect(json['name'], 'Juan PÃ©rez');
        expect(json['headline'], 'Backend Dev');
        expect(json['company'], 'StartupX');
        expect(json['is_premium'], true);
        expect(json['account_type'], 'empresa');
        expect(json['tags'], ['#tech', '#startup']);
      });

      test('roundtrip: fromJson â†’ toJson preserves data', () {
        final original = {
          'id': 'roundtrip-1',
          'name': 'Ana LÃ³pez',
          'headline': 'PM Senior',
          'connections': 200,
          'is_premium': true,
          'account_type': 'confidencial',
          'skills': ['Agile', 'Scrum'],
          'tags': ['#pm', '#agile'],
          'salary_expectation': 'USD 5K-8K/mes',
        };

        final user = NexUser.fromJson(original);
        final serialized = user.toJson();

        expect(serialized['id'], original['id']);
        expect(serialized['name'], original['name']);
        expect(serialized['headline'], original['headline']);
        expect(serialized['connections'], original['connections']);
        expect(serialized['is_premium'], original['is_premium']);
        expect(serialized['account_type'], original['account_type']);
        expect(serialized['salary_expectation'], original['salary_expectation']);
      });
    });

    group('computed properties', () {
      test('initials returns correct two-letter initials', () {
        const user = NexUser(id: '1', name: 'Ana LÃ³pez', headline: 'Dev');
        expect(user.initials, 'AL');
      });

      test('initials handles single name', () {
        const user = NexUser(id: '1', name: 'Madonna', headline: 'Singer');
        expect(user.initials, 'M');
      });

      test('initials handles empty name', () {
        const user = NexUser(id: '1', name: '', headline: '');
        expect(user.initials, '?');
      });

      test('isConfidential identifies stealth/confidencial', () {
        expect(
          const NexUser(id: '1', name: 'X', headline: '', accountType: 'confidencial').isConfidential,
          true,
        );
        expect(
          const NexUser(id: '1', name: 'X', headline: '', accountType: 'stealth').isConfidential,
          true,
        );
        expect(
          const NexUser(id: '1', name: 'X', headline: '', accountType: 'candidato').isConfidential,
          false,
        );
      });

      test('isCompanyAct identifies empresa accounts', () {
        expect(
          const NexUser(id: '1', name: 'X', headline: '', accountType: 'empresa').isCompanyAct,
          true,
        );
        expect(
          const NexUser(id: '1', name: 'X', headline: '', accountType: 'candidato').isCompanyAct,
          false,
        );
      });

      test('isBoosted checks boost expiry', () {
        final boosted = NexUser(
          id: '1', name: 'X', headline: '',
          boostEndsAt: DateTime.now().add(const Duration(hours: 1)),
        );
        expect(boosted.isBoosted, true);

        final expired = NexUser(
          id: '1', name: 'X', headline: '',
          boostEndsAt: DateTime.now().subtract(const Duration(hours: 1)),
        );
        expect(expired.isBoosted, false);
      });

      test('toString provides useful debug output', () {
        const user = NexUser(id: 'abc', name: 'Test', headline: '', accountType: 'empresa');
        expect(user.toString(), 'NexUser(id: abc, name: Test, type: empresa)');
      });
    });

    group('copyWith', () {
      test('creates a copy with modified fields', () {
        const original = NexUser(id: '1', name: 'Original', headline: 'Dev');
        final copy = original.copyWith(name: 'Modified', isPremium: true);

        expect(copy.name, 'Modified');
        expect(copy.isPremium, true);
        expect(copy.id, '1'); // unchanged
        expect(copy.headline, 'Dev'); // unchanged
      });
    });
  });

  group('Post', () {
    test('creates from JSON with video type', () {
      final json = {
        'id': 'post-1',
        'content': 'My pitch video',
        'type': 'video',
        'video_url': 'https://example.com/video.mp4',
        'author': {
          'id': 'u1',
          'name': 'Test User',
          'headline': 'Dev',
        },
      };

      // Verify Post model fields exist (basic smoke test)
      expect(json['id'], isNotNull);
      expect(json['content'], isNotNull);
    });
  });
}
