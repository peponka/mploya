import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;
  late String existingRls;

  setUpAll(() {
    migration = File(
      'supabase/migrations/033_protect_user_privileged_columns.sql',
    ).readAsStringSync();
    existingRls = File(
      'supabase/migrations/014_enable_all_rls.sql',
    ).readAsStringSync();
  });

  group('033 privileged users hardening', () {
    test('normal users and legacy user admins cannot change authority', () {
      expect(migration, contains('NEW.is_admin IS DISTINCT FROM OLD.is_admin'));
      expect(migration, isNot(contains('v_admin := public.is_admin()')));
      expect(migration, isNot(contains('SELECT u.is_admin FROM public.users')));
    });

    test('admin memberships are explicit and never backfilled', () {
      expect(migration, contains('CREATE TABLE public.admin_memberships'));
      expect(
        migration,
        contains('user_id UUID PRIMARY KEY REFERENCES public.users(id)'),
      );
      expect(migration, contains('active BOOLEAN NOT NULL DEFAULT TRUE'));
      expect(
        migration,
        contains('granted_by UUID REFERENCES public.users(id)'),
      );
      expect(
        migration,
        contains(
          'ALTER TABLE public.admin_memberships FORCE ROW LEVEL SECURITY',
        ),
      );
      expect(migration, contains('FROM PUBLIC, anon, authenticated'));
      expect(migration, contains('INSERT INTO public.admin_memberships'));
      expect(
        migration,
        contains(
          "current_setting('mploya.approved_admin_membership_ids', true)",
        ),
      );
      final bootstrap = _between(
        migration,
        'INSERT INTO public.admin_memberships',
        'ALTER TABLE public.admin_memberships ENABLE ROW LEVEL SECURITY',
      );
      expect(bootstrap, contains('jsonb_array_elements'));
      expect(bootstrap, isNot(contains('users.is_admin')));
      expect(bootstrap, isNot(contains('FROM public.users')));
    });

    test('admin bootstrap requires both independent session gates', () {
      expect(
        migration,
        contains("current_setting('mploya.privileged_audit_reviewed', true)"),
      );
      expect(
        migration,
        contains(
          "current_setting(\n    'mploya.approved_admin_membership_ids', true",
        ),
      );
      expect(migration, contains('approved admin membership list is absent'));
    });

    test('empty and malformed approval lists fail closed', () {
      expect(migration, contains("IF btrim(v_approved_raw) = '' THEN"));
      expect(migration, contains('jsonb_array_length(v_approved_json) = 0'));
      expect(migration, contains('approved admin membership list is empty'));
      expect(migration, contains('approved admin membership list is invalid'));
      expect(
        migration,
        contains('approved admin membership list must be a JSON array'),
      );
    });

    test('invalid UUIDs and duplicate approvals fail closed', () {
      expect(migration, contains('v_approved_item_text::UUID'));
      expect(migration, contains('WHEN invalid_text_representation THEN'));
      expect(migration, contains('approved admin membership UUID is invalid'));
      expect(migration, contains('COUNT(DISTINCT approved_id)'));
      expect(migration, contains('v_approved_count <> v_unique_count'));
      expect(
        migration,
        contains('approved admin membership list contains duplicates'),
      );
    });

    test('missing and deleted synthetic users cannot be approved', () {
      const approvedSynthetic = '11111111-1111-4111-8111-111111111111';
      const missingSynthetic = '22222222-2222-4222-8222-222222222222';
      const deletedSynthetic = '33333333-3333-4333-8333-333333333333';
      expect({approvedSynthetic, missingSynthetic, deletedSynthetic}.length, 3);
      expect(migration, contains('LEFT JOIN public.users u'));
      expect(migration, contains('WHERE u.id IS NULL'));
      expect(migration, contains('approved admin user does not exist'));
      expect(migration, contains('WHERE u.deleted_at IS NOT NULL'));
      expect(migration, contains('approved admin user is inactive or deleted'));
      for (final syntheticId in [
        approvedSynthetic,
        missingSynthetic,
        deletedSynthetic,
      ]) {
        expect(migration, isNot(contains(syntheticId)));
      }
    });

    test('one synthetic approval yields exactly one membership', () {
      const approvedSynthetic = '11111111-1111-4111-8111-111111111111';
      const historicalRejectedSynthetic =
          '44444444-4444-4444-8444-444444444444';
      final wrapperValue = '["$approvedSynthetic"]';
      expect(wrapperValue, isNot(contains(historicalRejectedSynthetic)));
      expect(
        migration,
        contains("'Explicit human approval bootstrap for migration 033'"),
      );
      expect(migration, contains('v_membership_count <> v_expected_count'));
      expect(
        migration,
        contains('admin memberships differ from explicit approval'),
      );
      expect(migration, isNot(contains(approvedSynthetic)));
      expect(migration, isNot(contains(historicalRejectedSynthetic)));
    });

    test('safe admin authority only evaluates auth uid active membership', () {
      final helper = _functionBody(migration, 'public.is_admin()');
      expect(helper, contains('am.user_id = auth.uid()'));
      expect(helper, contains('am.active IS TRUE'));
      expect(helper, isNot(contains('p_user_id')));
      expect(helper, contains('SET search_path = public, pg_temp'));
      expect(helper, isNot(contains('users.is_admin')));
    });

    test('premium verification boosts and economic values are blocked', () {
      for (final column in [
        'is_premium',
        'is_verified',
        'b2b_tokens',
        'boost_ends_at',
        'boost_type',
        'boost_target_city',
        'boost_started_at',
      ]) {
        expect(migration, contains('NEW.$column IS DISTINCT FROM OLD.$column'));
      }
    });

    test('ratings counters embeddings and deletion are blocked', () {
      for (final column in [
        'deleted_at',
        'profile_views',
        'match_percentage',
        'rating_stars',
        'rating_count',
        'like_count',
        'connections',
        'employer_rating_stars',
        'employer_rating_count',
      ]) {
        expect(migration, contains('NEW.$column IS DISTINCT FROM OLD.$column'));
      }
      expect(
        migration,
        contains(
          'NEW.profile_embedding::TEXT IS DISTINCT FROM OLD.profile_embedding::TEXT',
        ),
      );
    });

    test('privileged insert values are rejected', () {
      expect(migration, contains("IF TG_OP = 'INSERT' THEN"));
      expect(migration, contains('COALESCE(NEW.is_admin, false)'));
      expect(migration, contains('COALESCE(NEW.b2b_tokens, 0) <> 0'));
      expect(migration, contains('NEW.profile_embedding IS NOT NULL'));
    });

    test('ordinary own profile fields are not included in deny list', () {
      final guard = _functionBody(
        migration,
        'public.protect_user_privileged_columns()',
      );
      for (final field in [
        'NEW.name',
        'NEW.headline',
        'NEW.about',
        'NEW.avatar_url',
        'NEW.video_url',
        'NEW.city',
      ]) {
        expect(guard, isNot(contains(field)));
      }
      expect(guard, contains('RETURN NEW'));
    });

    test('delete truncate and trigger capabilities are revoked', () {
      expect(
        migration,
        contains('REVOKE TRUNCATE, TRIGGER, DELETE ON public.users'),
      );
      expect(migration, contains('FROM PUBLIC, anon, authenticated'));
    });

    test('internal bypass uses effective SQL identity only', () {
      final guard = _functionBody(
        migration,
        'public.protect_user_privileged_columns()',
      );
      expect(guard, contains('current_user IN'));
      expect(guard, contains("'postgres', 'service_role', 'supabase_admin'"));
      expect(guard, isNot(contains('auth.jwt')));
      expect(guard, isNot(contains('is_admin()')));
    });

    test('rate user preserves contract with fixed execution context', () {
      final body = _functionBody(
        migration,
        'public.rate_user(p_target_id UUID, p_stars FLOAT)',
      );
      expect(body, contains('v_actor UUID := auth.uid()'));
      expect(body, contains("jsonb_build_object('error', 'self_rate')"));
      expect(body, contains('INSERT INTO public.user_ratings'));
      expect(body, contains('SET rating_stars ='));
      expect(body, contains('SET search_path = public, pg_temp'));
      expect(migration, contains('GRANT EXECUTE ON FUNCTION public.rate_user'));
    });

    test('like and connection counters remain trigger-derived', () {
      final likes = _functionBody(migration, 'public.fn_sync_like_count()');
      final connections = _functionBody(
        migration,
        'public.fn_sync_connection_count()',
      );
      expect(likes, contains('UPDATE public.users SET like_count'));
      expect(connections, contains('UPDATE public.users SET connections'));
      expect(likes, contains('SET search_path = public, pg_temp'));
      expect(connections, contains('SET search_path = public, pg_temp'));
    });

    test('derived trigger functions are not executable by clients', () {
      expect(
        migration,
        contains(
          'REVOKE ALL ON FUNCTION public.fn_sync_like_count()\n'
          '  FROM PUBLIC, anon, authenticated, service_role',
        ),
      );
      expect(
        migration,
        contains(
          'REVOKE ALL ON FUNCTION public.fn_sync_connection_count()\n'
          '  FROM PUBLIC, anon, authenticated, service_role',
        ),
      );
    });

    test('administrative RPCs use membership helper and minimal grants', () {
      expect(
        migration,
        contains('ALTER FUNCTION public.admin_list_users(TEXT, INTEGER)'),
      );
      expect(migration, contains('ALTER FUNCTION public.admin_list_boosted()'));
      expect(migration, contains('SET search_path = public, pg_temp'));
      expect(
        migration,
        contains('policy still trusts users.is_admin directly'),
      );
    });

    test('live contracts and aggregate triggers are fail-closed', () {
      expect(
        migration,
        contains("to_regprocedure('public.rate_user(uuid,double precision)')"),
      );
      expect(migration, contains("tgname = 'trg_sync_like_count'"));
      expect(migration, contains("tgname = 'trg_sync_connection_count'"));
      expect(
        migration,
        contains(
          "tgfoid = to_regprocedure('public.fn_sync_like_count()')::oid",
        ),
      );
      expect(
        migration,
        contains('a versioned function has an unexpected owner'),
      );
      expect(
        migration,
        contains('a versioned function body differs from the audited contract'),
      );
      expect(migration, contains('a versioned function contract is missing'));
    });

    test('missing connection trigger is restored from versioned schema', () {
      expect(migration, contains('IF v_connection_trigger.oid IS NULL THEN'));
      expect(
        migration,
        contains(
          "EXECUTE 'CREATE TRIGGER trg_sync_connection_count\n"
          '      AFTER INSERT OR UPDATE OR DELETE ON public.connections\n'
          '      FOR EACH ROW EXECUTE FUNCTION '
          "public.fn_sync_connection_count()'",
        ),
      );
    });

    test('correct connection trigger is preserved without replacement', () {
      expect(migration, contains('v_connection_trigger.tgtype <> 29'));
      expect(migration, contains("v_connection_trigger.tgenabled <> 'O'"));
      expect(migration, contains('v_connection_trigger.tgnargs <> 0'));
      expect(migration, contains('v_connection_trigger.tgqual IS NOT NULL'));
      expect(
        migration,
        isNot(contains('DROP TRIGGER trg_sync_connection_count')),
      );
      expect(
        migration,
        isNot(contains('CREATE OR REPLACE TRIGGER trg_sync_connection_count')),
      );
    });

    test('conflicting connection trigger aborts clearly', () {
      expect(
        migration,
        contains(
          'trg_sync_connection_count conflicts with versioned definition',
        ),
      );
      expect(
        migration,
        contains('fn_sync_connection_count differs from versioned contract'),
      );
      expect(
        migration,
        contains(
          'to_regprocedure('
          "'public.fn_sync_connection_count()')::oid",
        ),
      );
      expect(
        migration,
        contains("p.prorettype = 'pg_catalog.trigger'::regtype"),
      );
      expect(migration, contains("l.lanname = 'plpgsql'"));
    });

    test('cross-row writes remain denied by existing own-row RLS', () {
      expect(existingRls, contains('CREATE POLICY "users_update_own"'));
      expect(
        existingRls,
        contains('USING (auth.uid() = id) WITH CHECK (auth.uid() = id)'),
      );
      expect(migration, isNot(contains('CREATE POLICY "users_update_own"')));
    });

    test('historical audit requires explicit confirmation', () {
      expect(
        migration,
        contains("current_setting('mploya.privileged_audit_reviewed', true)"),
      );
      expect(
        migration,
        contains('historical privileged-data audit not confirmed'),
      );
      expect(
        migration,
        contains('SELECT id FROM public.users WHERE is_admin IS TRUE'),
      );
      expect(
        migration,
        contains('SELECT id FROM public.users WHERE is_premium IS TRUE'),
      );
      expect(migration, contains('No query above mutates, deletes, corrects'));
    });

    test('no historical authority or privileged value is migrated', () {
      expect(migration, isNot(contains('UPDATE public.users SET is_admin')));
      expect(migration, isNot(contains('UPDATE public.users SET is_premium')));
      expect(migration, isNot(contains('DELETE FROM public.users')));
    });

    test('all created functions have fixed search paths', () {
      final functionCount = RegExp(
        r'CREATE OR REPLACE FUNCTION public\.',
      ).allMatches(migration).length;
      final fixedPathCount = RegExp(
        r'SET search_path = public, pg_temp',
      ).allMatches(migration).length;
      expect(fixedPathCount, greaterThanOrEqualTo(functionCount));
    });

    test('033 never grants protected table writes to clients', () {
      expect(
        migration,
        isNot(
          contains(
            'GRANT INSERT ON TABLE public.admin_memberships TO authenticated',
          ),
        ),
      );
      expect(
        migration,
        isNot(contains('GRANT DELETE ON public.users TO authenticated')),
      );
    });

    test('migration remains a guarded draft and does not apply itself', () {
      expect(
        migration,
        contains("-- SELECT set_config('mploya.privileged_audit_reviewed'"),
      );
      expect(
        migration,
        contains(
          "'mploya.approved_admin_membership_ids', '[\"<approved-uuid>\"]'",
        ),
      );
      expect(migration, contains('DRAFT: do not apply'));
    });
  });
}

String _functionBody(String sql, String signature) {
  final start = sql.indexOf('CREATE OR REPLACE FUNCTION $signature');
  expect(start, isNonNegative, reason: 'Missing function $signature');
  final end = sql.indexOf('\n\$\$;', start);
  expect(end, greaterThan(start), reason: 'Unterminated function $signature');
  return sql.substring(start, end);
}

String _between(String value, String startMarker, String endMarker) {
  final start = value.indexOf(startMarker);
  final end = value.indexOf(endMarker, start + startMarker.length);
  expect(start, isNonNegative, reason: 'Missing marker $startMarker');
  expect(end, greaterThan(start), reason: 'Missing marker $endMarker');
  return value.substring(start, end);
}
