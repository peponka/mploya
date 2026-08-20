import 'package:supabase_flutter/supabase_flutter.dart';

/// CRUD directo sobre `public.headhunter_clients` (migraciones 039 + 041).
///
/// Sin RPC intermedia: es un recurso propio simple (como `jobs`), no un dato
/// privilegiado como `users` — RLS (`headhunter_id = auth.uid()`) hace todo
/// el trabajo de aislamiento. Mismo patrón que `my_profile_service.dart`:
/// funciones sueltas, `client` opcional para poder inyectar en tests.

const _kClientColumns = '''
  id, headhunter_id, status,
  company_name, industry, company_size, website, country, city, description,
  relationship_type,
  contact_first_name, contact_last_name, contact_role, contact_email,
  contact_phone, contact_channel, decision_level, how_we_met, relationship_notes,
  work_mode, search_frequency, response_time, confidentiality_level,
  update_channel, contact_frequency, important_notes,
  created_at, updated_at
''';

Future<List<Map<String, dynamic>>> listHeadhunterClients({
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  final uid = db.auth.currentUser?.id;
  if (uid == null) return const [];

  final rows = await db
      .from('headhunter_clients')
      .select(_kClientColumns)
      .eq('headhunter_id', uid)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(rows as List);
}

/// Igual que [listHeadhunterClients], pero cada cliente trae además
/// `search_count` (vacantes de `jobs.client_id`) y `in_process_count`
/// (postulaciones de esas vacantes en `interviewing`/`accepted`) — las dos
/// cifras que la lista "Mis clientes" muestra por fila. Se calculan acá, no
/// se inventan: si un cliente no tiene vacantes vinculadas todavía, ambas
/// quedan en 0 (dato real, no un placeholder).
Future<List<Map<String, dynamic>>> listHeadhunterClientsWithStats({
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  final clients = await listHeadhunterClients(client: db);
  if (clients.isEmpty) return clients;

  final clientIds = clients.map((c) => c['id'].toString()).toList();
  final jobs = List<Map<String, dynamic>>.from(
    await db
        .from('jobs')
        .select('id, client_id')
        .inFilter('client_id', clientIds) as List,
  );

  final jobIds = jobs.map((j) => j['id'].toString()).toList();
  final applications = jobIds.isEmpty
      ? <Map<String, dynamic>>[]
      : List<Map<String, dynamic>>.from(
          await db
              .from('job_applications')
              .select('job_id, status')
              .inFilter('job_id', jobIds) as List,
        );

  final jobIdToClientId = {
    for (final j in jobs) j['id'].toString(): j['client_id'].toString(),
  };
  final searchCountByClient = <String, int>{};
  for (final j in jobs) {
    final cid = j['client_id'].toString();
    searchCountByClient[cid] = (searchCountByClient[cid] ?? 0) + 1;
  }
  final inProcessCountByClient = <String, int>{};
  for (final a in applications) {
    final status = a['status']?.toString().toLowerCase();
    if (status != 'interviewing' && status != 'accepted') continue;
    final cid = jobIdToClientId[a['job_id'].toString()];
    if (cid == null) continue;
    inProcessCountByClient[cid] = (inProcessCountByClient[cid] ?? 0) + 1;
  }

  return [
    for (final c in clients)
      {
        ...c,
        'search_count': searchCountByClient[c['id'].toString()] ?? 0,
        'in_process_count': inProcessCountByClient[c['id'].toString()] ?? 0,
      },
  ];
}

Future<Map<String, dynamic>?> getHeadhunterClient(
  String clientId, {
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  final row = await db
      .from('headhunter_clients')
      .select(_kClientColumns)
      .eq('id', clientId)
      .maybeSingle();
  return row == null ? null : Map<String, dynamic>.from(row);
}

/// Crea un cliente nuevo. `headhunter_id` se completa acá con `auth.uid()`,
/// nunca se toma de `fields` — evita que alguien intente crear un cliente
/// "para" otro headhunter (RLS lo bloquearía igual, pero así ni se intenta).
Future<Map<String, dynamic>> createHeadhunterClient(
  Map<String, dynamic> fields, {
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  final uid = db.auth.currentUser?.id;
  if (uid == null) {
    throw StateError('createHeadhunterClient: sin sesión activa');
  }

  final payload = Map<String, dynamic>.from(fields)..['headhunter_id'] = uid;
  final row = await db
      .from('headhunter_clients')
      .insert(payload)
      .select(_kClientColumns)
      .single();
  return Map<String, dynamic>.from(row);
}

Future<Map<String, dynamic>> updateHeadhunterClient(
  String clientId,
  Map<String, dynamic> fields, {
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  final row = await db
      .from('headhunter_clients')
      .update(fields)
      .eq('id', clientId)
      .select(_kClientColumns)
      .single();
  return Map<String, dynamic>.from(row);
}

Future<void> deleteHeadhunterClient(
  String clientId, {
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  await db.from('headhunter_clients').delete().eq('id', clientId);
}
