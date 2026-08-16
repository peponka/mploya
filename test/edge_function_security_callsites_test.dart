import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final aiMatch = File('lib/services/ai_match_service.dart').readAsStringSync();
  final auth = File('lib/services/auth_service.dart').readAsStringSync();
  final productionDart = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.readAsStringSync())
      .join('\n');

  test('generate embedding callsite sends only the current session user', () {
    final start = aiMatch.indexOf("'generate-embedding'");
    final contract = aiMatch.substring(start, aiMatch.indexOf(');', start) + 2);
    expect(contract, contains("body: {'user_id': _uid}"));
    expect(contract, isNot(contains('profile_embedding')));
    expect(contract, isNot(contains('headline')));

    final edge = File(
      'supabase/functions/generate-embedding/index.ts',
    ).readAsStringSync();
    final readSection = edge.substring(
      edge.indexOf('readOwnProfile:'),
      edge.indexOf('embed:'),
    );
    expect(readSection, contains("client.rpc('get_my_profile')"));
    expect(readSection, isNot(contains(".from('users')")));
    expect(readSection, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
    expect(edge, contains('032_safe_user_profile_access.sql'));
  });

  test('there is no Flutter callsite for the disabled payment function', () {
    expect(productionDart, isNot(contains("'create-payment-intent'")));
    expect(productionDart, isNot(contains('"create-payment-intent"')));
  });

  test('delete user remains closed until a safe function exists', () {
    expect(auth, isNot(contains('_cleanupUserData')));
    expect(auth, isNot(contains("'delete-user'")));
    expect(auth, isNot(contains("body: {'user_id': uid}")));
    expect(auth, contains('AppStrings.deleteServiceUnavailable'));
    expect(Directory('supabase/functions/delete-user').existsSync(), isFalse);
  });
}
