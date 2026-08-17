import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

String between(String value, String start, String end) {
  final from = value.indexOf(start);
  final to = value.indexOf(end, from + start.length);
  if (from < 0 || to <= from) {
    throw StateError('Missing contract section: $start ... $end');
  }
  return value.substring(from, to);
}

void main() {
  final migration = source(
    'supabase/migrations/034_harden_candidate_matching_privacy.sql',
  );
  final catalog = between(
    migration,
    'CREATE FUNCTION public.get_stealth_catalog()',
    'ALTER FUNCTION public.get_stealth_catalog()',
  );
  final unlock = between(
    migration,
    'CREATE FUNCTION public.unlock_stealth_profile',
    'ALTER FUNCTION public.unlock_stealth_profile',
  );
  final match = between(
    migration,
    'CREATE OR REPLACE FUNCTION public.match_candidates_for_job',
    'ALTER FUNCTION public.match_candidates_for_job',
  );
  final candidates = between(
    migration,
    'CREATE FUNCTION public.get_company_candidates',
    'ALTER FUNCTION public.get_company_candidates',
  );

  group('034 preflight and live contracts', () {
    test('requires 032 and 033 before any hardening DDL', () {
      final preflight = migration.indexOf('DO \$\$');
      final firstTable = migration.indexOf('CREATE TABLE');
      expect(preflight, greaterThanOrEqualTo(0));
      expect(preflight, lessThan(firstTable));
      expect(migration, contains("to_regprocedure('public.get_my_profile()')"));
      expect(migration, contains("to_regclass('public.admin_memberships')"));
      expect(
        migration,
        contains("to_regprocedure('public.protect_user_privileged_columns()')"),
      );
    });

    test('locks the audited 20-column live application contract', () {
      expect(migration, contains('currently returns 20 columns'));
      const liveColumns = [
        'application_id uuid',
        'candidate_id uuid',
        'candidate_name text',
        'candidate_headline text',
        'candidate_avatar_url text',
        'candidate_tags text[]',
        'candidate_video_url text',
        'candidate_location text',
        'candidate_salary_expectation text',
        'candidate_is_verified boolean',
        'candidate_open_to_work boolean',
        'candidate_rating_stars double precision',
        'candidate_rating_count integer',
        'candidate_experience jsonb',
        'job_id uuid',
        'job_title text',
        'job_tags text[]',
        'status text',
        'is_favorite boolean',
        'applied_at timestamp with time zone',
      ];
      var cursor = migration.indexOf("'TABLE(application_id uuid");
      for (final column in liveColumns) {
        final next = migration.indexOf(column, cursor);
        expect(next, greaterThanOrEqualTo(cursor), reason: column);
        cursor = next;
      }
    });

    test(
      'guards owners, wallet schema, unlock schema and five legacy rows',
      () {
        expect(migration, contains('has an unexpected owner'));
        expect(migration, contains('company_wallets columns changed'));
        expect(migration, contains('profile_unlocks columns changed'));
        expect(migration, contains('v_historical_unlocks <> 5'));
        expect(migration, contains('jobs.company_id contract changed'));
      },
    );
  });

  group('opaque actor-scoped catalog', () {
    test('uses random per-actor handles in a private forced-RLS table', () {
      expect(
        migration,
        contains('handle UUID PRIMARY KEY DEFAULT gen_random_uuid()'),
      );
      expect(migration, contains('UNIQUE (actor_id, candidate_id)'));
      expect(migration, contains('FORCE ROW LEVEL SECURITY'));
      expect(
        migration,
        contains('REVOKE ALL ON TABLE public.candidate_access_handles'),
      );
      expect(catalog, contains('WHERE h.actor_id = v_actor'));
    });

    test('requires a session and an Empresa or Headhunter actor', () {
      expect(catalog, contains('v_actor UUID := auth.uid()'));
      expect(catalog, contains("USING ERRCODE = '28000'"));
      expect(
        catalog,
        contains("v_actor_type NOT IN ('empresa', 'headhunter')"),
      );
    });

    test('normalizes every confidential family generically', () {
      for (final section in [catalog, unlock, match, candidates]) {
        expect(section, contains("= 'stealth'"));
        expect(section, contains("LIKE 'confidenc%'"));
        expect(section, contains("LIKE 'confidential%'"));
        expect(section, contains('lower(btrim(COALESCE('));
      }
    });

    test('locked rows return no UUID or identifying profile attributes', () {
      expect(catalog, contains('THEN u.id ELSE NULL::UUID'));
      expect(catalog, contains("ELSE 'Confidencial'::TEXT"));
      expect(catalog, contains('THEN u.headline::TEXT ELSE NULL::TEXT'));
      expect(catalog, contains('THEN u.about::TEXT ELSE NULL::TEXT'));
      expect(catalog, contains("ELSE '{}'::TEXT[]"));
      expect(catalog, isNot(contains('avatar_url')));
      expect(catalog, isNot(contains('video_url')));
      expect(catalog, isNot(contains('location')));
    });

    test('legacy unlocks cannot authorize catalog identity', () {
      expect(catalog, contains('JOIN public.candidate_unlock_ledger ledger'));
      expect(catalog, contains('pu.authorization_version = 1'));
      expect(catalog, contains('ledger.authorization_version = 1'));
    });
  });

  group('atomic handle unlock', () {
    test('accepts only a handle and derives the actor from auth.uid', () {
      expect(
        unlock,
        contains('unlock_stealth_profile(p_candidate_handle UUID)'),
      );
      expect(unlock, isNot(contains('p_candidate_id')));
      expect(unlock, contains('v_actor UUID := auth.uid()'));
      expect(unlock, contains('h.handle = p_candidate_handle'));
      expect(unlock, contains('h.actor_id = v_actor'));
    });

    test(
      'rejects foreign, missing, revoked and expired handles generically',
      () {
        expect(unlock, contains('h.revoked_at IS NULL'));
        expect(unlock, contains('h.expires_at > now()'));
        expect(unlock, contains("'error', 'candidate_unavailable'"));
        expect(unlock, contains('FOR UPDATE OF h'));
      },
    );

    test('price is private configuration and never a Flutter parameter', () {
      expect(
        migration,
        contains('CREATE TABLE public.candidate_unlock_pricing'),
      );
      expect(migration, contains("VALUES ('stealth_profile', 1)"));
      expect(unlock, contains('pricing.credit_cost'));
      expect(unlock, isNot(contains('p_price')));
      expect(unlock, isNot(contains('p_cost')));
    });

    test('insufficient balance exits before every debit or authorization', () {
      final insufficient = unlock.indexOf("'insufficient_funds'");
      expect(
        insufficient,
        lessThan(unlock.indexOf('UPDATE public.company_wallets')),
      );
      expect(
        insufficient,
        lessThan(unlock.indexOf('INSERT INTO public.candidate_unlock_ledger')),
      );
      expect(
        insufficient,
        lessThan(unlock.indexOf('INSERT INTO public.profile_unlocks')),
      );
    });

    test('debit, ledger and unlock are ordered atomically', () {
      final debit = unlock.indexOf('UPDATE public.company_wallets');
      final ledger = unlock.indexOf(
        'INSERT INTO public.candidate_unlock_ledger',
      );
      final authorization = unlock.indexOf(
        'INSERT INTO public.profile_unlocks',
      );
      expect(debit, greaterThanOrEqualTo(0));
      expect(debit, lessThan(ledger));
      expect(ledger, lessThan(authorization));
      expect(
        migration,
        contains('balance_after = balance_before - credit_cost'),
      );
    });

    test('double attempts are idempotent and cannot double charge', () {
      final already = unlock.indexOf("'status', 'already_unlocked'");
      final debit = unlock.indexOf('UPDATE public.company_wallets');
      expect(already, greaterThanOrEqualTo(0));
      expect(already, lessThan(debit));
      expect(migration, contains('UNIQUE (actor_id, candidate_id)'));
      expect(migration, contains('UNIQUE (candidate_handle)'));
    });
  });

  group('legacy quarantine and backend-only authorization', () {
    test('does not update or delete the five historical rows', () {
      final quarantine = between(
        migration,
        '-- Quarantine legacy unlocks',
        '-- Wallet remains owner-readable',
      );
      expect(quarantine, isNot(contains('UPDATE public.profile_unlocks')));
      expect(quarantine, isNot(contains('DELETE FROM public.profile_unlocks')));
      expect(quarantine, contains('ADD COLUMN authorization_version SMALLINT'));
      expect(quarantine, contains('authorization_version IS NULL'));
    });

    test('allows a new authorized row beside an unchanged legacy pair', () {
      expect(migration, contains('DROP CONSTRAINT profile_unlocks_uniq'));
      expect(migration, contains('profile_unlocks_authorized_pair_uniq'));
      expect(migration, contains('WHERE authorization_version = 1'));
    });

    test('blocks every direct client write and read of unlock evidence', () {
      expect(
        migration,
        contains('DROP POLICY IF EXISTS profile_unlocks_insert_company'),
      );
      expect(migration, contains('REVOKE ALL ON TABLE public.profile_unlocks'));
      expect(
        migration,
        contains('REVOKE ALL ON TABLE public.candidate_unlock_ledger'),
      );
    });
  });

  group('owned-job candidate RPCs', () {
    test('both reject null sessions and unavailable jobs generically', () {
      for (final section in [match, candidates]) {
        expect(section, contains('v_actor UUID := auth.uid()'));
        expect(section, contains("v_actor_type NOT IN ('empresa', 'headhunter')"));
        expect(section, contains('v_owner IS NULL'));
        expect(section, contains('v_owner IS DISTINCT FROM v_actor'));
        expect(section, contains('vacante no disponible'));
      }
      expect(candidates, contains('IF p_job_id IS NOT NULL'));
    });

    test(
      'Match excludes locked profiles and includes ledger-backed unlocks',
      () {
        expect(match, contains('WHERE (NOT s.confidential OR s.unlocked)'));
        expect(match, contains('JOIN public.candidate_unlock_ledger ledger'));
        expect(match, contains('pu.company_id = v_actor'));
      },
    );

    test('Match preserves its exact nine output columns', () {
      for (final column in [
        'id UUID',
        'name VARCHAR',
        'headline VARCHAR',
        'avatar_url TEXT',
        'account_type VARCHAR',
        'tags TEXT[]',
        'similarity DOUBLE PRECISION',
        'semantic_score DOUBLE PRECISION',
        'skill_score DOUBLE PRECISION',
      ]) {
        expect(match, contains(column));
      }
    });

    test('company candidates excludes locked rows and never nulls IDs', () {
      expect(
        candidates,
        contains('WHERE NOT o.private_confidential OR o.private_unlocked'),
      );
      expect(candidates, isNot(contains('NULL::UUID')));
      expect(candidates, contains('o.candidate_id'));
      expect(candidates, contains('candidate_account_type TEXT'));
      expect(candidates, contains('is_confidential BOOLEAN'));
      expect(candidates, contains('is_unlocked BOOLEAN'));
    });
  });

  group('function permissions', () {
    test('all four RPCs fix search_path and execute only as authenticated', () {
      expect(
        RegExp(r'SET search_path = public, pg_temp').allMatches(migration),
        hasLength(4),
      );
      expect(
        RegExp(r'REVOKE ALL ON FUNCTION').allMatches(migration),
        hasLength(4),
      );
      expect(
        RegExp(r'GRANT EXECUTE ON FUNCTION').allMatches(migration),
        hasLength(4),
      );
      expect(migration, isNot(contains('TO service_role;')));
    });
  });

  group('Flutter contract migration', () {
    final catalogData = source(
      'lib/screens/empresa/empresa_confidenciales_data.dart',
    );
    final catalogScreen = source(
      'lib/screens/empresa/empresa_confidenciales_screen.dart',
    );
    final credits = source('lib/screens/empresa/empresa_creditos_data.dart');
    final shortlist = source('lib/screens/empresa/empresa_shortlist_data.dart');
    final process = source('lib/screens/empresa/empresa_proceso_data.dart');
    final notifications = source('lib/screens/notifications_screen.dart');
    final detail = source(
      'lib/screens/empresa/empresa_vacante_detalle_data.dart',
    );

    test('catalog and unlock use the opaque handle, never a blocked UUID', () {
      expect(catalogData, contains("m['candidate_handle']"));
      expect(
        catalogData,
        contains("params: {'p_candidate_handle': candidateHandle}"),
      );
      expect(catalogData, contains('final String? candidateId'));
      expect(catalogScreen, contains('final candidateId = c.candidateId'));
      expect(catalogScreen, contains('c.desbloqueado && candidateId != null'));
    });

    test('credits no longer reads profile_unlocks or users directly', () {
      expect(credits, contains("client.rpc('get_stealth_catalog')"));
      expect(credits, isNot(contains("from('profile_unlocks')")));
      expect(credits, isNot(contains("from('users')")));
    });

    test('shortlist and process consume server privacy flags', () {
      expect(shortlist, contains("p['candidate_account_type']"));
      expect(shortlist, contains("p['is_unlocked'] == true"));
      expect(process, contains("p['is_confidential'] == true"));
      expect(process, isNot(contains("select('id, account_type')")));
    });

    test('alerts never enrich relationship rows from users', () {
      final fetch = between(
        notifications,
        'Future<List<Map<String, dynamic>>> _fetchNewCandidates()',
        'Future<List<Map<String, dynamic>>> _fetchConnections()',
      );
      expect(fetch, contains("'get_company_candidates'"));
      expect(fetch, isNot(contains("from('users')")));
    });

    test('vacancy-specific consumers pass the owned job context', () {
      expect(shortlist, contains("params: {'p_job_id': jobId}"));
      expect(detail, contains("params: {'p_job_id': jobId}"));
    });
  });
}
