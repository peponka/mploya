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
  final migration = source(
    'supabase/migrations/032_safe_user_profile_access.sql',
  );
  final service = source('lib/services/my_profile_service.dart');
  final consumers = <String, String>{
    'splash': source('lib/screens/splash_screen.dart'),
    'roles': source('lib/screens/role_selection_screen.dart'),
    'candidate': source('lib/screens/candidate_profile_form_screen.dart'),
    'company': source('lib/screens/company_profile_form_screen.dart'),
    'headhunter': source('lib/screens/headhunter_profile_form_screen.dart'),
    'provider': source('lib/providers/user_provider.dart'),
  };

  group('own-profile write RPC contracts', () {
    const functions = [
      'set_my_initial_role',
      'update_my_candidate_profile',
      'update_my_company_profile',
      'update_my_headhunter_profile',
      'set_my_candidate_privacy',
      'set_my_profile_avatar',
    ];

    test('all functions use only auth.uid and authenticated execution', () {
      for (final name in functions) {
        final function = sqlFunction(migration, name);
        final signature = function.substring(0, function.indexOf(')\n'));
        expect(signature, isNot(contains('user_id')));
        expect(signature, isNot(contains('owner_id')));
        expect(function, contains('auth.uid()'));
        expect(function, contains('SECURITY DEFINER'));
        expect(function, contains('SET search_path = public, pg_temp'));
        expect(function, contains('WHERE u.id = v_actor'));
        expect(migration, contains('GRANT EXECUTE ON FUNCTION public.$name'));
      }
      expect(
        RegExp(
          r'REVOKE ALL ON FUNCTION public\.[\s\S]*?FROM PUBLIC, anon, authenticated, service_role;',
        ).allMatches(migration).length,
        greaterThanOrEqualTo(functions.length + 1),
      );
    });

    test('initial role creates a missing row from trusted auth identity', () {
      final function = sqlFunction(migration, 'set_my_initial_role');
      expect(function, contains('FROM auth.users au'));
      expect(function, contains('au.id = v_actor'));
      expect(function, contains('IF NOT v_user_exists THEN'));
      expect(function, contains('INSERT INTO public.users'));
      expect(function, contains('v_email'));
      expect(function, contains('v_name'));
    });

    test('initial role preserves the three families and candidate privacy', () {
      final function = sqlFunction(migration, 'set_my_initial_role');
      expect(
        function,
        contains(
          "v_role NOT IN ('candidato', 'confidencial', 'empresa', 'headhunter')",
        ),
      );
      expect(function, contains('v_existing_step >= 1'));
      expect(function, contains("rol ya seleccionado"));
      expect(function, contains('GREATEST(v_existing_step, 1)'));
      expect(
        function,
        contains('CASE WHEN p_complete_selection THEN 1 ELSE 0 END'),
      );
    });

    test('candidate update allows only candidate-family rows', () {
      final function = sqlFunction(migration, 'update_my_candidate_profile');
      expect(function, contains("v_role = 'candidato'"));
      expect(function, contains("v_role = 'stealth'"));
      expect(function, contains("v_role LIKE 'confidenc%'"));
      expect(function, contains("v_role LIKE 'confidential%'"));
      expect(function, isNot(contains("account_type =")));
      expect(function, contains('p_complete_onboarding'));
      expect(function, contains('GREATEST(COALESCE(u.onboarding_step, 0), 2)'));
    });

    test('company and headhunter updates cannot cross roles', () {
      final company = sqlFunction(migration, 'update_my_company_profile');
      final headhunter = sqlFunction(migration, 'update_my_headhunter_profile');
      expect(company, contains("v_role <> 'empresa'"));
      expect(company, isNot(contains("'headhunter'")));
      expect(headhunter, contains("v_role <> 'headhunter'"));
      expect(headhunter, isNot(contains("'empresa'")));
      for (final function in [company, headhunter]) {
        expect(
          function,
          contains('GREATEST(COALESCE(u.onboarding_step, 0), 2)'),
        );
      }
    });

    test('candidate privacy is explicit and cannot change role family', () {
      final function = sqlFunction(migration, 'set_my_candidate_privacy');
      expect(
        function,
        contains(
          "CASE WHEN p_confidential THEN 'confidencial' ELSE 'candidato' END",
        ),
      );
      expect(function, contains("v_role = 'candidato'"));
      expect(function, contains("v_role LIKE 'confidenc%'"));
      expect(function, isNot(contains("v_target := 'empresa'")));
      expect(function, isNot(contains("v_target := 'headhunter'")));
    });

    test('explicit signatures reject unknown and privileged fields', () {
      const forbidden = [
        'p_user_id',
        'p_owner_id',
        'p_payload',
        'p_is_admin',
        'p_is_premium',
        'p_is_verified',
        'p_b2b_tokens',
        'p_boost',
        'p_rating',
        'p_profile_views',
        'p_profile_embedding',
        'p_deleted_at',
      ];
      for (final name in functions) {
        final signature = sqlFunction(migration, name).split('RETURNS').first;
        for (final field in forbidden) {
          expect(
            signature,
            isNot(contains(field)),
            reason: '$name acepta $field',
          );
        }
      }
    });

    test('profile updates expose only each form fields', () {
      final candidate = sqlFunction(migration, 'update_my_candidate_profile');
      for (final field in [
        'name =',
        'headline =',
        'city =',
        'about =',
        'tags =',
        'skills =',
        'experience =',
        'education =',
        'salary_expectation =',
        'latitude =',
        'longitude =',
      ]) {
        expect(candidate, contains(field));
      }
      final company = sqlFunction(migration, 'update_my_company_profile');
      for (final field in [
        'company =',
        'name =',
        'headline =',
        'about =',
        'tags =',
      ]) {
        expect(company, contains(field));
      }
      final headhunter = sqlFunction(migration, 'update_my_headhunter_profile');
      for (final field in ['name =', 'headline =', 'city =', 'tags =']) {
        expect(headhunter, contains(field));
      }
    });

    test('avatar accepts only the existing own Storage path or null', () {
      final function = sqlFunction(migration, 'set_my_profile_avatar');
      expect(function, contains("'/storage/v1/object/public/videos/avatars/'"));
      expect(function, contains('v_actor::TEXT'));
      expect(function, contains('p_avatar_url IS NOT NULL'));
    });
  });

  group('authorized Flutter callsites', () {
    test('six audited consumers no longer write directly to users', () {
      for (final entry in consumers.entries) {
        expect(
          RegExp(
            r"\.from\('users'\)\s*\.(insert|update|upsert)\(",
          ).hasMatch(entry.value),
          isFalse,
          reason: entry.key,
        );
      }
    });

    test('initial role keeps email step zero and selection step one', () {
      expect(consumers['splash'], contains('completeSelection: false'));
      expect(consumers['splash'], contains('completeSelection: true'));
      expect(consumers['roles'], contains('completeSelection: true'));
    });

    test('each form calls only its role-specific RPC', () {
      expect(consumers['candidate'], contains('updateMyCandidateProfile('));
      expect(consumers['candidate'], contains('setMyProfileAvatar('));
      expect(consumers['company'], contains('updateMyCompanyProfile('));
      expect(consumers['headhunter'], contains('updateMyHeadhunterProfile('));
      expect(consumers['company'], isNot(contains('updateMyCandidateProfile')));
      expect(
        consumers['headhunter'],
        isNot(contains('updateMyCompanyProfile')),
      );
    });

    test('service methods never accept a user id', () {
      expect(service, isNot(contains('userId')));
      expect(service, isNot(contains('ownerId')));
      for (final rpc in [
        'set_my_initial_role',
        'update_my_candidate_profile',
        'update_my_company_profile',
        'update_my_headhunter_profile',
        'set_my_candidate_privacy',
        'set_my_profile_avatar',
      ]) {
        expect(service, contains("'$rpc'"));
      }
    });

    test('unrelated privacy callsites remain outside this batch', () {
      for (final path in [
        'lib/screens/stealth_profile_form_screen.dart',
        'lib/screens/mis_herramientas_screen.dart',
        'lib/navigation/main_navigation.dart',
      ]) {
        final unrelated = source(path);
        expect(unrelated, isNot(contains('setMyCandidatePrivacy')));
        expect(unrelated, isNot(contains('updateMyCandidateProfile')));
      }
    });
  });
}
