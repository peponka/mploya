import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final safeAccess = File(
    'supabase/migrations/032_safe_user_profile_access.sql',
  ).readAsStringSync();
  final privilegedColumns = File(
    'supabase/migrations/033_protect_user_privileged_columns.sql',
  ).readAsStringSync();
  final candidatePrivacy = File(
    'supabase/migrations/034_harden_candidate_matching_privacy.sql',
  ).readAsStringSync();

  group('user profile hardening migration contracts', () {
    test(
      'orders the additive profile layer before enforcement and matching',
      () {
        expect(safeAccess, contains('032 - Capa aditiva segura'));
        expect(
          privilegedColumns,
          contains('033 - Protect privileged public.users columns'),
        );
        expect(candidatePrivacy, contains('034 - Hardening'));
        expect(
          File(
            'supabase/migrations/032_harden_candidate_matching_privacy.sql',
          ).existsSync(),
          isFalse,
        );
      },
    );

    test('public projection excludes every confidential account variant', () {
      expect(safeAccess, contains("<> 'stealth'"));
      expect(safeAccess, contains("NOT LIKE 'confidenc%'"));
      expect(safeAccess, contains("NOT LIKE 'confidential%'"));
      expect(safeAccess, contains("lower(btrim(COALESCE("));
      expect(safeAccess, contains('u.deleted_at IS NULL'));
    });

    test('public projection omits sensitive and privileged columns', () {
      final projection = safeAccess.substring(
        safeAccess.indexOf('CREATE OR REPLACE VIEW'),
        safeAccess.indexOf('FROM public.users u'),
      );
      for (final column in [
        'email',
        'latitude',
        'longitude',
        'location_geom',
        'salary_expectation',
        'personality_scores',
        'ai_transcript_json',
        'profile_embedding',
        'fcm_token',
        'b2b_tokens',
        'boost_ends_at',
        'deleted_at',
        'is_admin',
        'push_enabled',
      ]) {
        expect(projection, isNot(contains('u.$column')));
      }
    });

    test('only authenticated can use the safe contracts', () {
      expect(
        safeAccess,
        contains(
          'REVOKE ALL ON public.safe_user_profiles\n'
          '  FROM PUBLIC, anon, authenticated, service_role;',
        ),
      );
      expect(
        safeAccess,
        contains('GRANT SELECT ON public.safe_user_profiles TO authenticated'),
      );
      expect(
        safeAccess,
        contains(
          'REVOKE ALL ON FUNCTION public.get_my_profile()\n'
          '  FROM PUBLIC, anon, authenticated, service_role;',
        ),
      );
      expect(
        safeAccess,
        contains(
          'GRANT EXECUTE ON FUNCTION public.get_my_profile() TO authenticated',
        ),
      );
    });

    test('get_my_profile requires auth and cannot select another user', () {
      expect(safeAccess, contains('v_actor UUID := auth.uid()'));
      expect(safeAccess, contains("ERRCODE = '28000'"));
      expect(safeAccess, contains('WHERE u.id = v_actor'));
      expect(safeAccess, isNot(contains('p_user_id')));
    });

    test(
      'get_my_profile returns the private fields required by own profile',
      () {
        final functionStart = safeAccess.indexOf(
          'CREATE OR REPLACE FUNCTION public.get_my_profile()',
        );
        final returnStart = safeAccess.indexOf(
          'RETURNS TABLE (',
          functionStart,
        );
        final returnEnd = safeAccess.indexOf(
          ')\nLANGUAGE plpgsql',
          returnStart,
        );
        final contract = safeAccess.substring(returnStart, returnEnd);

        for (final field in [
          'location TEXT',
          'latitude DOUBLE PRECISION',
          'longitude DOUBLE PRECISION',
          'ai_transcript_json JSONB',
          'account_type TEXT',
          'onboarding_step INTEGER',
          'salary_expectation TEXT',
        ]) {
          expect(contract, contains(field));
        }

        for (final forbidden in [
          'is_admin',
          'b2b_tokens',
          'profile_embedding',
          'fcm_token',
          'boost_ends_at',
          'boost_target_city',
          'match_percentage',
          'personality_scores',
          'push_enabled',
          'email_notifications_enabled',
          'job_alerts_enabled',
          'deleted_at',
        ]) {
          expect(contract, isNot(contains(forbidden)));
        }
      },
    );

    test('explicitly fixes search paths without removing current SELECT', () {
      expect(
        RegExp(r'SET search_path = public, pg_temp').allMatches(safeAccess),
        hasLength(9),
      );
      expect(
        RegExp(
          r'SET search_path = public, pg_temp',
        ).allMatches(privilegedColumns),
        hasLength(greaterThanOrEqualTo(6)),
      );
      expect(
        RegExp(r'REVOKE\s+SELECT', caseSensitive: false).hasMatch(safeAccess),
        isFalse,
      );
      expect(
        RegExp(
          r'REVOKE\s+SELECT',
          caseSensitive: false,
        ).hasMatch(privilegedColumns),
        isFalse,
      );
    });

    test('removes truncate and trigger from public client roles', () {
      expect(
        privilegedColumns,
        contains(
          'REVOKE TRUNCATE, TRIGGER, DELETE ON public.users\n'
          '  FROM PUBLIC, anon, authenticated;',
        ),
      );
    });

    test('blocks privileged values on insert and changes on update', () {
      expect(privilegedColumns, contains("TG_OP = 'INSERT'"));
      expect(privilegedColumns, contains('BEFORE INSERT OR UPDATE'));
      for (final column in [
        'is_admin',
        'is_premium',
        'is_verified',
        'b2b_tokens',
        'deleted_at',
        'boost_ends_at',
        'profile_views',
        'match_percentage',
        'rating_stars',
        'employer_rating_stars',
        'profile_embedding',
      ]) {
        expect(privilegedColumns, contains('NEW.$column'));
      }
      expect(
        privilegedColumns,
        contains('NEW.is_admin IS DISTINCT FROM OLD.is_admin'),
      );
      expect(
        privilegedColumns,
        isNot(contains('v_admin := public.is_admin()')),
      );
    });

    test('normal own-profile fields remain outside the trigger deny list', () {
      final protectedChecks = privilegedColumns.substring(
        privilegedColumns.indexOf("IF TG_OP = 'INSERT'"),
        privilegedColumns.indexOf(
          '-- Existing own-row RLS continues to govern ordinary profile fields.',
        ),
      );
      for (final column in [
        'name',
        'headline',
        'about',
        'avatar_url',
        'video_url',
        'skills',
        'experience',
        'education',
        'city',
        'push_enabled',
      ]) {
        expect(protectedChecks, isNot(contains('NEW.$column')));
      }
      expect(privilegedColumns, contains('RETURN NEW;'));
    });
  });
}
