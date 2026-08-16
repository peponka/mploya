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

    test('admin memberships are server-managed and never backfilled', () {
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
      expect(
        migration,
        isNot(contains('INSERT INTO public.admin_memberships')),
      );
    });

    test('safe admin authority only evaluates auth uid active membership', () {
      final helper = _functionBody(migration, 'public.is_admin()');
      expect(helper, contains('am.user_id = auth.uid()'));
      expect(helper, contains('am.active IS TRUE'));
      expect(helper, isNot(contains('p_user_id')));
      expect(helper, contains('SET search_path = public, pg_temp'));
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
