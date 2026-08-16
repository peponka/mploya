import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

String sqlFunction(String sql, String name) {
  final start = sql.indexOf('CREATE OR REPLACE FUNCTION public.$name(');
  expect(start, greaterThanOrEqualTo(0), reason: 'No existe $name');
  final end = sql.indexOf('\n\$\$;', start);
  expect(end, greaterThan(start), reason: '$name no termina correctamente');
  return sql.substring(start, end + 4);
}

void main() {
  final sql = source('supabase/migrations/032_safe_user_profile_access.sql');
  final service = source('lib/services/my_profile_service.dart');

  final consumers = <String, String>{
    'stealth form': source('lib/screens/stealth_profile_form_screen.dart'),
    'stealth builder': source('lib/screens/stealth_profile_builder.dart'),
    'preferences': source('lib/screens/preferencias_laborales_screen.dart'),
    'company editor': source(
      'lib/screens/empresa/empresa_editar_perfil_screen.dart',
    ),
    'headhunter editor': source(
      'lib/screens/headhunter/headhunter_edit_profile_screen.dart',
    ),
    'camera': source('lib/screens/camera_screen.dart'),
    'pitch onboarding': source('lib/screens/onboarding_pitch_screen.dart'),
    'company video': source(
      'lib/screens/empresa/empresa_video_pitch_screen.dart',
    ),
    'headhunter video': source(
      'lib/screens/headhunter/headhunter_video_pitch_screen.dart',
    ),
  };

  group('remaining own-profile SQL contracts', () {
    test('preferences are candidate-only and explicitly typed', () {
      final function = sqlFunction(sql, 'update_my_candidate_preferences');
      expect(function, contains('auth.uid()'));
      expect(function, contains("v_role = 'candidato'"));
      expect(function, contains("v_role = 'stealth'"));
      expect(function, contains("v_role LIKE 'confidenc%'"));
      expect(function, contains("v_role LIKE 'confidential%'"));
      for (final field in [
        'about = p_about',
        'city = p_city',
        'salary_expectation = p_salary_expectation',
        'latitude =',
        'longitude =',
      ]) {
        expect(function, contains(field));
      }
      expect(function, contains('p_latitude < -90'));
      expect(function, contains('p_longitude > 180'));
      expect(function, isNot(contains('user_id')));
    });

    test('video accepts only the current actor pitch path', () {
      final function = sqlFunction(sql, 'set_my_profile_video');
      expect(function, contains('auth.uid()'));
      expect(function, contains("'/storage/v1/object/public/videos/pitches/'"));
      expect(function, contains('v_actor::TEXT'));
      expect(function, contains("_[0-9]+\\.(mp4|webm)"));
      expect(function, contains('p_video_url !~ v_expected_pattern'));
      expect(function, contains("p_video_url !~ '^https://'"));
      expect(function, contains('video_url = p_video_url'));
      expect(function, isNot(contains('user_id')));
    });

    test('video supports all own role families but no unknown role', () {
      final function = sqlFunction(sql, 'set_my_profile_video');
      expect(
        function,
        contains("v_role IN ('candidato', 'empresa', 'headhunter', 'stealth')"),
      );
      expect(function, contains("v_role LIKE 'confidenc%'"));
      expect(function, contains("v_role LIKE 'confidential%'"));
      expect(function, contains('rol no permitido'));
    });

    test('advanced company fields stay role-scoped', () {
      final function = sqlFunction(sql, 'update_my_company_profile');
      expect(function, contains("v_role <> 'empresa'"));
      expect(function, contains('location = CASE WHEN p_update_location'));
      expect(function, contains('is_hiring = p_is_hiring'));
      expect(function, contains('WHEN p_complete_onboarding THEN'));
      expect(function, isNot(contains('account_type =')));
    });

    test('advanced headhunter fields stay role-scoped', () {
      final function = sqlFunction(sql, 'update_my_headhunter_profile');
      expect(function, contains("v_role <> 'headhunter'"));
      expect(function, contains('about = CASE WHEN p_update_details'));
      expect(function, contains('location = CASE WHEN p_update_details'));
      expect(function, contains('company = CASE WHEN p_update_details'));
      expect(function, isNot(contains('account_type =')));
    });

    test('all added contracts are authenticated-only', () {
      for (final signature in [
        'public.update_my_candidate_preferences(',
        'public.set_my_profile_video(',
      ]) {
        expect(sql, contains('REVOKE ALL ON FUNCTION $signature'));
        expect(sql, contains('GRANT EXECUTE ON FUNCTION $signature'));
      }
      expect(
        RegExp(r'SET search_path = public, pg_temp').allMatches(sql),
        hasLength(9),
      );
    });
  });

  group('remaining Flutter consumers', () {
    test('authorized blocks have no direct users reads or writes', () {
      final direct = RegExp(
        r"\.from\('users'\)\s*\.(select|insert|update|upsert)\(",
      );
      for (final entry in consumers.entries) {
        expect(direct.hasMatch(entry.value), isFalse, reason: entry.key);
      }
    });

    test('confidential screens preserve data through the shared merger', () {
      expect(
        consumers['stealth form'],
        contains('updateMyConfidentialProfile('),
      );
      expect(
        consumers['stealth builder'],
        contains('updateMyConfidentialProfile('),
      );
      expect(service, contains("row['skills']"));
      expect(service, contains("row['experience']"));
      expect(service, contains("row['education']"));
      expect(service, contains("row['salary_expectation']"));
      expect(service, contains("tags: updateTags ? tags : strings(row['tags'])"));
      expect(consumers['stealth form'], contains('updateTags: true'));
    });

    test('preferences use get_my_profile and their dedicated RPC', () {
      expect(consumers['preferences'], contains('loadMyProfile()'));
      expect(
        consumers['preferences'],
        contains('updateMyCandidatePreferences('),
      );
    });

    test('advanced editors use their role-specific RPC', () {
      expect(consumers['company editor'], contains('updateMyCompanyProfile('));
      expect(
        consumers['headhunter editor'],
        contains('updateMyHeadhunterProfile('),
      );
      expect(consumers['headhunter editor'], contains('loadMyProfile('));
    });

    test('video persistence no longer accepts a client user id', () {
      final auth = source('lib/services/auth_service.dart');
      expect(auth, contains('Future<String?> updatePitchUrl(String videoUrl'));
      expect(auth, isNot(contains('updatePitchUrl(String userId')));
      expect(auth, contains('setMyProfileVideo('));
      expect(consumers['camera'], isNot(contains('updatePitchUrl(userId')));
      expect(
        consumers['pitch onboarding'],
        isNot(contains('updatePitchUrl(user.id')),
      );
    });

    test('company and headhunter removal only unlink the own video', () {
      for (final key in ['company video', 'headhunter video']) {
        expect(consumers[key], contains('videoUrl: null'));
        expect(consumers[key], contains('completeOnboarding: false'));
        expect(consumers[key], isNot(contains('storage.from')));
      }
    });

    test('unrelated consumers remain outside this batch', () {
      for (final path in [
        'lib/screens/mis_herramientas_screen.dart',
        'lib/screens/premium_paywall_screen.dart',
        'lib/screens/boost_profile_screen.dart',
        'lib/screens/admin_dashboard_screen.dart',
        'lib/services/feed_service.dart',
      ]) {
        final unrelated = source(path);
        expect(unrelated, isNot(contains('updateMyCandidatePreferences')));
        expect(unrelated, isNot(contains('setMyProfileVideo')));
      }
    });
  });
}
