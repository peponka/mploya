import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/user_columns.dart';

Future<Map<String, Map<String, dynamic>>> loadAccessibleProfilesById(
  Iterable<String> ids, {
  SupabaseClient? client,
}) async {
  final unique = ids.where((id) => id.isNotEmpty).toSet().toList();
  if (unique.isEmpty) return const {};
  final db = client ?? Supabase.instance.client;
  final rows = await db
      .from('accessible_user_profiles')
      .select(kUserColumns)
      .inFilter('id', unique);
  return {
    for (final raw in rows)
      if (raw['id'] != null)
        raw['id'].toString(): Map<String, dynamic>.from(raw),
  };
}

Future<List<Map<String, dynamic>>> hydrateJobCompanies(
  Iterable<dynamic> rows, {
  SupabaseClient? client,
  String companyKey = 'company_id',
  String outputKey = 'users',
}) async {
  final result = rows
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
  final profiles = await loadAccessibleProfilesById(
    result.map((row) => row[companyKey]?.toString() ?? ''),
    client: client,
  );
  for (final row in result) {
    row[outputKey] = profiles[row[companyKey]?.toString()];
  }
  return result;
}

Future<List<Map<String, dynamic>>> hydrateNestedJobCompanies(
  Iterable<dynamic> rows, {
  SupabaseClient? client,
  String jobKey = 'jobs',
}) async {
  final result = rows
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();
  final companyIds = <String>[];
  for (final row in result) {
    final nested = row[jobKey];
    if (nested is Map && nested['company_id'] != null) {
      companyIds.add(nested['company_id'].toString());
    }
  }
  final profiles = await loadAccessibleProfilesById(companyIds, client: client);
  for (final row in result) {
    final nested = row[jobKey];
    if (nested is! Map) continue;
    final job = Map<String, dynamic>.from(nested);
    job['users'] = profiles[job['company_id']?.toString()];
    row[jobKey] = job;
  }
  return result;
}
