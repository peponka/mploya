import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

Iterable<File> sourceFiles(Directory root, Set<String> extensions) sync* {
  for (final entity in root.listSync(recursive: true)) {
    if (entity is File && extensions.any(entity.path.endsWith)) yield entity;
  }
}

String section(String source, String start, String end) {
  final from = source.indexOf(start);
  final to = source.indexOf(end, from + start.length);
  if (from < 0 || to <= from) {
    throw StateError('Missing contract section: $start ... $end');
  }
  return source.substring(from, to);
}

void main() {
  final migration = read(
    'supabase/migrations/035_close_direct_user_profile_access.sql',
  );

  group('035 direct users closure', () {
    test('requires the three earlier security migrations and legacy quarantine', () {
      expect(migration, contains("to_regprocedure('public.get_my_profile()')"));
      expect(migration, contains("to_regprocedure('public.is_admin()')"));
      expect(migration, contains("to_regprocedure('public.get_stealth_catalog()')"));
      expect(migration, contains('v_legacy_unlocks <> 5'));
    });

    test('revokes every direct client privilege on public.users', () {
      expect(
        migration,
        contains(
          'REVOKE ALL ON TABLE public.users FROM PUBLIC, anon, authenticated;',
        ),
      );
      expect(migration, contains('ALTER TABLE public.users ENABLE ROW LEVEL SECURITY'));
      expect(migration, contains("polcmd IN ('r', '*')"));
    });

    test('public and authenticated projections use explicit safe columns', () {
      final publicView = section(
        migration,
        'CREATE VIEW public.safe_user_profiles',
        'ALTER VIEW public.safe_user_profiles',
      );
      final accessibleView = section(
        migration,
        'CREATE VIEW public.accessible_user_profiles',
        'ALTER VIEW public.accessible_user_profiles',
      );
      for (final forbidden in [
        'u.email',
        'u.fcm_token',
        'u.latitude',
        'u.longitude',
        'u.location_geom',
        'u.is_admin',
        'u.b2b_tokens',
        'u.boost_ends_at',
        'u.boost_target_city',
        'u.profile_embedding',
        'u.deleted_at,',
      ]) {
        expect(publicView, isNot(contains(forbidden)), reason: forbidden);
        expect(accessibleView, isNot(contains(forbidden)), reason: forbidden);
      }
      expect(migration, contains('GRANT SELECT ON public.safe_user_profiles TO anon, authenticated'));
      expect(migration, contains('GRANT SELECT ON public.accessible_user_profiles TO authenticated'));
    });

    test('all confidential account variants require a version-one ledger', () {
      for (final variant in ["= 'stealth'", "LIKE 'confidenc%'", "LIKE 'confidential%'"]) {
        expect(migration, contains(variant), reason: variant);
      }
      expect(migration, contains('pu.authorization_version = 1'));
      expect(migration, contains('ledger.authorization_version = 1'));
      expect(migration, contains('ledger.id = pu.authorization_ledger_id'));
    });

    test('exact coordinates and boost dates remain server-side', () {
      final talent = section(
        migration,
        'CREATE OR REPLACE FUNCTION public.search_accessible_talent',
        'CREATE OR REPLACE FUNCTION public.admin_profile_metrics',
      );
      expect(talent, contains('distance_km DOUBLE PRECISION'));
      expect(talent, isNot(contains('RETURNS TABLE (\n  latitude')));
      final map = section(
        migration,
        'CREATE OR REPLACE FUNCTION public.get_explore_pins',
        '-- Remove broad table policies',
      );
      expect(map, contains('round(u.latitude::NUMERIC, 2)'));
      expect(map, contains('round(u.longitude::NUMERIC, 2)'));
      expect(map, contains('round(m.distance_km::NUMERIC, 1)'));
    });

    test('own reads and mutations derive the actor from auth.uid()', () {
      final ownProfile = section(
        migration,
        'CREATE FUNCTION public.get_my_profile()',
        '-- Private own-account mutations',
      );
      expect(ownProfile, contains('match_percentage DOUBLE PRECISION'));
      for (final forbidden in [
        'is_admin',
        'fcm_token',
        'profile_embedding',
        'b2b_tokens',
        'boost_ends_at',
      ]) {
        expect(ownProfile, isNot(contains(forbidden)), reason: forbidden);
      }
      for (final contract in [
        'get_my_profile_entitlements',
        'update_my_setting',
        'set_my_fcm_token',
        'set_my_profile_analysis',
      ]) {
        final start = migration.indexOf('FUNCTION public.$contract');
        expect(start, greaterThanOrEqualTo(0), reason: contract);
        final end = start + 2600 < migration.length
            ? start + 2600
            : migration.length;
        expect(
          migration.substring(start, end),
          contains('auth.uid()'),
          reason: contract,
        );
      }
    });

    test('historic RPC bypasses are replaced with fixed grants', () {
      for (final contract in [
        'get_recommended_users',
        'get_my_pipeline',
        'redeem_referral_code',
        'get_explore_pins',
      ]) {
        expect(migration, contains('FUNCTION public.$contract'));
        expect(migration, contains('GRANT EXECUTE ON FUNCTION public.$contract'));
      }
      expect(migration, contains("THEN 'Alguien'::TEXT"));
    });
  });

  group('productive consumers', () {
    test('Flutter and public web never query public.users directly', () {
      final files = <File>[
        ...sourceFiles(Directory('lib'), {'.dart'}),
        ...sourceFiles(Directory('web-public'), {'.js'}),
      ];
      for (final file in files) {
        final source = file.readAsStringSync();
        expect(source, isNot(contains(".from('users')")), reason: file.path);
        expect(source, isNot(contains("table: 'users'")), reason: file.path);
        expect(
          RegExp(r'users\s*:\s*[a-z_]+\s*\(', caseSensitive: false)
              .hasMatch(source),
          isFalse,
          reason: file.path,
        );
        expect(source, isNot(contains('/rest/v1/users')), reason: file.path);
      }
    });

    test('own profile consumers use the private service', () {
      final service = read('lib/services/my_profile_service.dart');
      expect(service, contains("rpc('get_my_profile')"));
      expect(service, isNot(contains(".from('users')")));
      for (final path in [
        'lib/providers/user_provider.dart',
        'lib/screens/profile_screen.dart',
        'lib/screens/tools_hub_entry_screen.dart',
        'lib/screens/post_composer_screen.dart',
        'lib/services/revenuecat_service.dart',
      ]) {
        expect(read(path), contains('loadMyProfile'), reason: path);
      }
    });

    test('service-role users access remains confined to audited Edge functions', () {
      final direct = <String>[];
      for (final file in sourceFiles(Directory('supabase/functions'), {'.ts'})) {
        if (file.readAsStringSync().contains(".from('users')")) {
          direct.add(file.path.replaceAll('\\', '/'));
        }
      }
      expect(
        direct.toSet(),
        equals({
          'supabase/functions/generate-embedding/index.ts',
          'supabase/functions/send-fcm/index.ts',
        }),
      );
      final embedding = read('supabase/functions/generate-embedding/index.ts');
      expect(embedding, contains("rpc('get_my_profile')"));
      expect(embedding.indexOf("rpc('get_my_profile')"), lessThan(embedding.indexOf(".from('users')")));
    });
  });
}
