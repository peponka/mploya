import 'package:supabase_flutter/supabase_flutter.dart';

/// Decodifica la fila unica de `get_my_profile()`.
///
/// La separacion permite probar sesion, fila presente y fila ausente sin usar
/// una base ni introducir fixtures productivos.
Map<String, dynamic>? decodeMyProfileRpcResult({
  required bool hasSession,
  required Object? response,
}) {
  if (!hasSession) return null;
  if (response is! List || response.isEmpty) return null;
  final first = response.first;
  if (first is! Map) return null;
  return Map<String, dynamic>.from(first);
}

/// Lee exclusivamente el perfil de `auth.uid()` mediante la RPC privada.
///
/// Despliegue: `032_safe_user_profile_access.sql` debe aplicarse antes de
/// publicar la version de la app que contiene este cliente. No existe fallback
/// a `public.users`, porque mantendria indefinidamente el acceso inseguro.
Future<Map<String, dynamic>?> loadMyProfile({SupabaseClient? client}) async {
  final db = client ?? Supabase.instance.client;
  final hasSession = db.auth.currentUser != null;
  if (!hasSession) return null;

  final response = await db.rpc('get_my_profile');
  return decodeMyProfileRpcResult(hasSession: true, response: response);
}

Future<void> setMyInitialRole({
  required String role,
  required bool completeSelection,
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  await db.rpc(
    'set_my_initial_role',
    params: {'p_role': role, 'p_complete_selection': completeSelection},
  );
}

Future<void> updateMyCandidateProfile({
  required String name,
  required String headline,
  required String city,
  required String? about,
  required List<String>? tags,
  required List<String>? skills,
  required List<Map<String, Object?>> experience,
  required List<Map<String, Object?>> education,
  required String? salaryExpectation,
  required double? latitude,
  required double? longitude,
  required bool completeOnboarding,
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  await db.rpc(
    'update_my_candidate_profile',
    params: {
      'p_name': name,
      'p_headline': headline,
      'p_city': city,
      'p_about': about,
      'p_tags': tags,
      'p_skills': skills,
      'p_experience': experience,
      'p_education': education,
      'p_salary_expectation': salaryExpectation,
      'p_latitude': latitude,
      'p_longitude': longitude,
      'p_complete_onboarding': completeOnboarding,
    },
  );
}

Future<void> updateMyCompanyProfile({
  required String company,
  required String headline,
  required String about,
  required List<String>? tags,
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  await db.rpc(
    'update_my_company_profile',
    params: {
      'p_company': company,
      'p_headline': headline,
      'p_about': about,
      'p_tags': tags,
    },
  );
}

Future<void> updateMyHeadhunterProfile({
  required String name,
  required String headline,
  required String city,
  required List<String>? tags,
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  await db.rpc(
    'update_my_headhunter_profile',
    params: {
      'p_name': name,
      'p_headline': headline,
      'p_city': city,
      'p_tags': tags,
    },
  );
}

Future<void> setMyProfileAvatar(
  String? avatarUrl, {
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  await db.rpc('set_my_profile_avatar', params: {'p_avatar_url': avatarUrl});
}

Future<void> setMyCandidatePrivacy(
  bool confidential, {
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  await db.rpc(
    'set_my_candidate_privacy',
    params: {'p_confidential': confidential},
  );
}
