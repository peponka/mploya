import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mploya/screens/admin_dashboard_screen.dart';
import 'package:mploya/screens/boost_profile_screen.dart';
import 'package:mploya/screens/empresa/empresa_verificacion_data.dart';
import 'package:mploya/screens/empresa/empresa_verificacion_screen.dart';
import 'package:mploya/screens/headhunter/headhunter_settings_screen.dart';
import 'package:mploya/screens/premium_paywall_screen.dart';
import 'package:mploya/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String source(String path) => File(path).readAsStringSync();

String between(String value, String start, String end) {
  final from = value.indexOf(start);
  final to = value.indexOf(end, from + start.length);
  expect(from, greaterThanOrEqualTo(0), reason: 'Missing start marker: $start');
  expect(to, greaterThan(from), reason: 'Missing end marker: $end');
  return value.substring(from, to);
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'test-anon-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });

  final premium = source('lib/screens/premium_paywall_screen.dart');
  final boost = source('lib/screens/boost_profile_screen.dart');
  final verification = source('lib/services/company_verification_service.dart');
  final verificationData = source(
    'lib/screens/empresa/empresa_verificacion_data.dart',
  );
  final verificationScreen = source(
    'lib/screens/empresa/empresa_verificacion_screen.dart',
  );
  final ratings = source('lib/services/employer_rating_service.dart');
  final auth = source('lib/services/auth_service.dart');
  final settings = source('lib/screens/settings_screen.dart');
  final toolsHub = source('lib/screens/tools_hub_entry_screen.dart');
  final headhunterSettings = source(
    'lib/screens/headhunter/headhunter_settings_screen.dart',
  );
  final admin = source('lib/screens/admin_dashboard_screen.dart');

  test(
    'premium has no bypass or privileged write and both CTAs fail closed',
    () {
      expect(premium, isNot(contains('DEBUG BYPASS')));
      expect(premium, isNot(contains('kReleaseMode')));
      expect(premium, isNot(contains("update({'is_premium': true})")));
      expect(premium, contains('onTap: _processPurchase'));
      expect(premium, contains('La suscripción Premium estará disponible'));
    },
  );

  test('boost has no founder activation or boost field writes', () {
    expect(boost, isNot(contains('_founderMode')));
    expect(boost, isNot(contains('Activar Boost GRATIS')));
    expect(boost, isNot(contains("'boost_ends_at':")));
    expect(boost, isNot(contains("'boost_started_at':")));
    final action = between(
      boost,
      'void _processPayment()',
      'Widget _buildBoostResultsCard',
    );
    expect(action, isNot(contains('.update(')));
    expect(action, contains('disponibles cuando podamos validar la compra'));
  });

  test('verification never approves or mutates from Flutter', () {
    final mutations = RegExp(
      r"from\('company_verifications'\)[\s\S]{0,180}\.(insert|update|delete)\(",
    );
    expect(mutations.hasMatch(verification), isFalse);
    expect(verification, isNot(contains("'status': 'approved'")));
    expect(verification, isNot(contains("'is_verified':")));
    expect(verification, contains('status = pending'));
    expect(
      verificationData,
      contains('ResultadoAutoVerificacion.noDisponible'),
    );
    expect(verificationScreen, contains('Verificación pendiente'));
  });

  test('employer ratings are read-only until an eligibility RPC exists', () {
    expect(ratings, isNot(contains('_recalculateCompanyRating')));
    expect(ratings, isNot(contains("'employer_rating_stars':")));
    expect(ratings, isNot(contains("'employer_rating_count':")));
    final submit = between(
      ratings,
      'Future<String?> submitReview',
      '// ── Obtener resumen',
    );
    expect(submit, isNot(contains('.insert(')));
    expect(submit, isNot(contains('.update(')));
    expect(submit, contains('disponibles próximamente'));
  });

  test('account deletion performs no cleanup, function call or client id', () {
    final deletion = between(
      auth,
      'Future<String?> deleteAccount()',
      '// Helpers privados',
    );
    expect(deletion, isNot(contains('.delete(')));
    expect(deletion, isNot(contains('functions.invoke')));
    expect(deletion, isNot(contains('delete-user')));
    expect(deletion, isNot(contains('user_id')));
    expect(auth, isNot(contains('_cleanupUserData')));
    expect(deletion, contains('deleteServiceUnavailable'));

    final candidateAction = between(
      settings,
      'Future<void> _executeDeleteAccount()',
      '// Helpers',
    );
    expect(candidateAction, isNot(contains('clearToken')));
    expect(candidateAction, isNot(contains('logout')));
    expect(candidateAction, contains('deleteAccount()'));
    expect(headhunterSettings, contains('deleteAccount()'));
  });

  test('admin authority and privileged actions fail closed', () {
    final access = between(admin, 'Future<void> _verifyAdmin()', '@override');
    expect(access, contains("rpc('is_admin')"));
    expect(access, isNot(contains("select('is_admin')")));

    expect(admin, isNot(contains("update({'is_verified':")));
    expect(admin, isNot(contains("update({'boost_ends_at':")));
    expect(RegExp(r"from\('users'\)\.delete\(\)").hasMatch(admin), isFalse);
    expect(admin, contains('verificación administrativa estará disponible'));
    expect(admin, contains('eliminación administrativa estará disponible'));
    expect(admin, contains('revocación de Boost estará disponible'));
  });

  test('admin authority is never read directly from users', () {
    for (final consumer in [settings, toolsHub]) {
      expect(consumer, contains("rpc('is_admin')"));
      expect(
        RegExp(r'''select\([^)]*is_admin''').hasMatch(consumer),
        isFalse,
      );
    }
  });

  test('the six blocks keep their production screens and CTA entrypoints', () {
    expect(premium, contains('class PremiumPaywallScreen'));
    expect(boost, contains('class BoostProfileScreen'));
    expect(verificationScreen, contains('class EmpresaVerificacionScreen'));
    expect(settings, contains('class SettingsScreen'));
    expect(headhunterSettings, contains('class HeadhunterSettingsScreen'));
    expect(admin, contains('class AdminDashboardScreen'));
  });

  testWidgets('affected screens build without overflow at approved widths', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    const verificationPreview = VerificacionData(dominioEmail: 'empresa.test');
    const headhunterPreview = HeadhunterSettingsData(
      pushEnabled: true,
      emailEnabled: false,
      blindHiring: true,
      email: 'headhunter@example.test',
    );

    final screens = <Widget>[
      const PremiumPaywallScreen(),
      const ProviderScope(child: BoostProfileScreen()),
      const EmpresaVerificacionScreen(previewData: verificationPreview),
      const SettingsScreen(),
      const HeadhunterSettingsScreen(previewData: headhunterPreview),
      const AdminDashboardScreen(),
    ];

    for (final size in const [
      Size(400, 900),
      Size(768, 1024),
      Size(1440, 900),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      for (final screen in screens) {
        await tester.pumpWidget(MaterialApp(home: screen));
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          tester.takeException(),
          isNull,
          reason:
              '${screen.runtimeType} failed at ${size.width}x${size.height}',
        );
      }
    }
  });
}
