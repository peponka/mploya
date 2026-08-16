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
  String? company,
  bool updateCompany = false,
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
      'p_company': company,
      'p_update_company': updateCompany,
    },
  );
}

Future<void> updateMyCompanyProfile({
  required String company,
  required String? headline,
  required String? about,
  required List<String>? tags,
  String? location,
  bool isHiring = true,
  bool updateLocation = false,
  bool completeOnboarding = true,
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
      'p_location': location,
      'p_is_hiring': isHiring,
      'p_update_location': updateLocation,
      'p_complete_onboarding': completeOnboarding,
    },
  );
}

Future<void> updateMyHeadhunterProfile({
  required String name,
  required String headline,
  required String city,
  required List<String>? tags,
  String? about,
  String? location,
  String? company,
  bool updateDetails = false,
  bool completeOnboarding = true,
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
      'p_about': about,
      'p_location': location,
      'p_company': company,
      'p_update_details': updateDetails,
      'p_complete_onboarding': completeOnboarding,
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

Future<void> updateMyCandidatePreferences({
  required String about,
  required String city,
  required String? salaryExpectation,
  required double? latitude,
  required double? longitude,
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  await db.rpc(
    'update_my_candidate_preferences',
    params: {
      'p_about': about,
      'p_city': city,
      'p_salary_expectation': salaryExpectation,
      'p_latitude': latitude,
      'p_longitude': longitude,
    },
  );
}

Future<void> setMyProfileVideo({
  required String? videoUrl,
  List<String>? tags,
  required bool completeOnboarding,
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  await db.rpc(
    'set_my_profile_video',
    params: {
      'p_video_url': videoUrl,
      'p_tags': tags,
      'p_complete_onboarding': completeOnboarding,
    },
  );
}

Future<void> updateMyConfidentialProfile({
  String? name,
  required String headline,
  required String about,
  String? company,
  List<String>? tags,
  bool updateTags = false,
  bool updateCompany = false,
  bool completeOnboarding = false,
  SupabaseClient? client,
}) async {
  final row = await loadMyProfile(client: client);
  if (row == null) throw StateError('Perfil propio no disponible');

  List<String>? strings(Object? value) => value is List
      ? value.map((item) => item.toString()).toList(growable: false)
      : null;
  List<Map<String, Object?>> maps(Object? value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, Object?>.from(item))
            .toList(growable: false)
      : const [];

  await updateMyCandidateProfile(
    name: name ?? row['name']?.toString() ?? 'Talento Oculto',
    headline: headline,
    city: row['city']?.toString() ?? '',
    about: about,
    tags: updateTags ? tags : strings(row['tags']),
    skills: strings(row['skills']),
    experience: maps(row['experience']),
    education: maps(row['education']),
    salaryExpectation: row['salary_expectation']?.toString(),
    latitude: (row['latitude'] as num?)?.toDouble(),
    longitude: (row['longitude'] as num?)?.toDouble(),
    completeOnboarding: completeOnboarding,
    company: company,
    updateCompany: updateCompany,
    client: client,
  );
}
