import 'package:supabase_flutter/supabase_flutter.dart';

/// "Búsquedas activas" (Headhunter) — lee `public.jobs` del headhunter
/// autenticado y arma, por búsqueda, las cifras reales que la pantalla
/// necesita: cantidad de postulaciones y "progreso" (postulaciones que ya
/// salieron de `pending`, sobre el total). No se inventa un porcentaje de
/// progreso distinto: es el único derivable de datos reales sin fabricar una
/// fórmula que no está documentada en ningún lado.
///
/// `search_status` (migración 042) es la columna de estado real —
/// Abierta/En proceso/En pausa/Cerrada, ver `10_Headhunter_Busquedas_
/// Activas.png`.

const _kSearchStatuses = ['abierta', 'en_proceso', 'en_pausa', 'cerrada'];

Future<List<Map<String, dynamic>>> listHeadhunterSearches({
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  final uid = db.auth.currentUser?.id;
  if (uid == null) return const [];

  final jobs = List<Map<String, dynamic>>.from(
    await db
        .from('jobs')
        .select('id, title, location, search_status, client_id, created_at')
        .eq('company_id', uid)
        .order('created_at', ascending: false) as List,
  );
  if (jobs.isEmpty) return jobs;

  final jobIds = jobs.map((j) => j['id'].toString()).toList();
  final applications = List<Map<String, dynamic>>.from(
    await db
        .from('job_applications')
        .select('job_id, status')
        .inFilter('job_id', jobIds) as List,
  );

  final clientIds = jobs
      .map((j) => j['client_id']?.toString())
      .whereType<String>()
      .toSet()
      .toList();
  final clients = clientIds.isEmpty
      ? <Map<String, dynamic>>[]
      : List<Map<String, dynamic>>.from(
          await db
              .from('headhunter_clients')
              .select('id, company_name')
              .inFilter('id', clientIds) as List,
        );
  final clientNameById = {
    for (final c in clients) c['id'].toString(): c['company_name']?.toString() ?? '',
  };

  final appsByJob = <String, List<String>>{};
  for (final a in applications) {
    final jobId = a['job_id'].toString();
    final status = a['status']?.toString() ?? 'pending';
    (appsByJob[jobId] ??= []).add(status);
  }

  return [
    for (final j in jobs)
      () {
        final jobId = j['id'].toString();
        final statuses = appsByJob[jobId] ?? const [];
        final total = statuses.length;
        final evaluated = statuses.where((s) => s != 'pending').length;
        final clientId = j['client_id']?.toString();
        return {
          ...j,
          'candidate_count': total,
          'progress': total == 0 ? 0.0 : evaluated / total,
          'client_name': clientId == null ? null : clientNameById[clientId],
        };
      }(),
  ];
}

int countBySearchStatus(List<Map<String, dynamic>> searches, String? status) {
  if (status == null) return searches.length;
  return searches.where((s) => s['search_status'] == status).length;
}

const kHeadhunterSearchStatuses = _kSearchStatuses;
