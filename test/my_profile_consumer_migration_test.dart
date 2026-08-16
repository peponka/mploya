import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/services/my_profile_service.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  group('get_my_profile response contract', () {
    test('returns null without a session', () {
      final result = decodeMyProfileRpcResult(
        hasSession: false,
        response: [
          {'id': 'must-not-be-used'},
        ],
      );
      expect(result, isNull);
    });

    test('returns the own row for an authenticated user', () {
      final result = decodeMyProfileRpcResult(
        hasSession: true,
        response: [
          {'id': 'own-id', 'account_type': 'candidato', 'onboarding_step': 2},
        ],
      );
      expect(result?['id'], 'own-id');
      expect(result?['account_type'], 'candidato');
      expect(result?['onboarding_step'], 2);
    });

    test('returns null when the authenticated user has no row', () {
      expect(
        decodeMyProfileRpcResult(hasSession: true, response: const []),
        isNull,
      );
    });
  });

  group('own-profile consumer batches', () {
    final provider = source('lib/providers/user_provider.dart');
    final splash = source('lib/screens/splash_screen.dart');
    final roleSelection = source('lib/screens/role_selection_screen.dart');
    final candidate = source('lib/screens/candidate_profile_form_screen.dart');
    final company = source('lib/screens/company_profile_form_screen.dart');
    final headhunter = source(
      'lib/screens/headhunter_profile_form_screen.dart',
    );

    test('removes direct own-profile reads from the four readers', () {
      expect(provider, isNot(contains(".from('users')")));
      for (final reader in [splash, candidate, company]) {
        expect(
          RegExp(r"\.from\('users'\)\s*\.select\(").hasMatch(reader),
          isFalse,
        );
      }
      expect(RegExp('loadMyProfile\\(\\)').allMatches(splash), hasLength(2));
      expect(candidate, contains('final row = await loadMyProfile();'));
      expect(company, isNot(contains(".from('users').select")));
    });

    test('role selection and headhunter use write-only RPCs', () {
      expect(roleSelection, isNot(contains('loadMyProfile')));
      expect(headhunter, isNot(contains('loadMyProfile')));
      expect(roleSelection, contains('setMyInitialRole('));
      expect(headhunter, contains('updateMyHeadhunterProfile('));
      expect(roleSelection, isNot(contains(".from('users')")));
      expect(headhunter, isNot(contains(".from('users')")));
    });

    test('splash preserves routing and delegates missing rows to the RPC', () {
      expect(splash, contains('final step ='));
      expect(splash, contains("role == 'headhunter'"));
      expect(splash, contains("role == 'empresa'"));
      expect(splash, contains('CandidateProfileFormScreen'));
      expect(splash, contains('CompanyProfileFormScreen'));
      expect(splash, contains('HeadhunterProfileFormScreen'));
      expect(splash, contains('setMyInitialRole('));
      expect(splash, contains('completeSelection: false'));
      expect(splash, contains('completeSelection: true'));
    });

    test('role selection preserves candidate, company and headhunter', () {
      expect(roleSelection, contains("role == 'candidato'"));
      expect(roleSelection, contains("role: 'empresa'"));
      expect(roleSelection, contains("role == 'headhunter'"));
      expect(roleSelection, contains('CandidateProfileFormScreen'));
      expect(roleSelection, contains('CompanyProfileFormScreen'));
      expect(roleSelection, contains('HeadhunterProfileFormScreen'));
    });

    test('candidate, company and headhunter retain form data in RPC calls', () {
      for (final field in ['name:', 'headline:', 'city:', 'tags:']) {
        expect(candidate, contains(field));
        expect(headhunter, contains(field));
      }
      expect(candidate, contains('salaryExpectation:'));
      expect(candidate, contains('completeOnboarding: !widget.isEditing'));
      expect(company, contains('company: nombre'));
      expect(company, contains('updateMyCompanyProfile('));
      expect(headhunter, contains('updateMyHeadhunterProfile('));
    });

    test('does not migrate unrelated foreign-profile consumers', () {
      for (final path in [
        'lib/services/feed_service.dart',
        'lib/screens/network_screen.dart',
        'lib/screens/messaging_screen.dart',
        'lib/screens/empresa/empresa_busqueda_data.dart',
        'lib/screens/headhunter/headhunter_talent_pool_screen.dart',
      ]) {
        expect(source(path), isNot(contains("rpc('get_my_profile'")));
        expect(source(path), isNot(contains('loadMyProfile')));
      }
    });
  });
}
