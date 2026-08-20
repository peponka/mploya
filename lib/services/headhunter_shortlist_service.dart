import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/headhunter_candidate_privacy.dart';
import '../utils/user_columns.dart';

/// CRUD sobre `public.shortlists` / `public.shortlist_candidates`
/// (migraciones 039 + 043).
///
/// `shortlist_candidates` referencia `headhunter_pipeline_candidates`, no
/// `job_applications` — una shortlist se arma sobre el sourcing del
/// headhunter para esa búsqueda (ver migración 043). `match_score` viaja
/// desde ahí (que a su vez sale de la función real `match_candidates_for_job`,
/// migración 034) — nunca se inventa un porcentaje acá.

const _kShortlistColumns = 'id, headhunter_id, job_id, client_id, status, sent_at, created_at';
const _kShortlistCandidateColumns =
    'id, shortlist_id, pipeline_candidate_id, rank, match_score, note, '
    'client_decision, client_comment, decision_at, created_at';

Future<List<Map<String, dynamic>>> listShortlists({
  String? jobId,
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  final uid = db.auth.currentUser?.id;
  if (uid == null) return const [];

  var query = db.from('shortlists').select(_kShortlistColumns).eq('headhunter_id', uid);
  if (jobId != null) query = query.eq('job_id', jobId);

  final rows = await query.order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(rows as List);
}

Future<Map<String, dynamic>?> getShortlist(
  String shortlistId, {
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  if (db.auth.currentUser == null) return null;
  final row = await db
      .from('shortlists')
      .select(_kShortlistColumns)
      .eq('id', shortlistId)
      .maybeSingle();
  return row == null ? null : Map<String, dynamic>.from(row);
}

Future<List<Map<String, dynamic>>> listShortlistCandidates(
  String shortlistId, {
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  if (db.auth.currentUser == null) return const [];
  final rows = await db
      .from('shortlist_candidates')
      .select(_kShortlistCandidateColumns)
      .eq('shortlist_id', shortlistId)
      .order('rank', ascending: true);
  return List<Map<String, dynamic>>.from(rows as List);
}

/// Crea una shortlist con los `pipelineCandidateIds` elegidos (checkboxes de
/// `Headhunter_Crear_Shortlist.png`), copiando `match_score` de cada fila
/// del pipeline. El orden de la lista define `rank`.
Future<Map<String, dynamic>> createShortlist({
  required String jobId,
  required List<Map<String, dynamic>> selectedPipelineCandidates,
  String? clientId,
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  final uid = db.auth.currentUser?.id;
  if (uid == null) {
    throw StateError('createShortlist: sin sesión activa');
  }
  if (selectedPipelineCandidates.isEmpty) {
    throw ArgumentError('createShortlist: seleccioná al menos un candidato');
  }

  final shortlist = await db
      .from('shortlists')
      .insert({
        'headhunter_id': uid,
        'job_id': jobId,
        if (clientId != null) 'client_id': clientId,
      })
      .select(_kShortlistColumns)
      .single();

  var rank = 1;
  final rows = [
    for (final pc in selectedPipelineCandidates)
      {
        'shortlist_id': shortlist['id'],
        'pipeline_candidate_id': pc['id'],
        'rank': rank++,
        'match_score': pc['match_score'],
      },
  ];
  await db.from('shortlist_candidates').insert(rows);

  return Map<String, dynamic>.from(shortlist);
}

/// Igual que [listShortlistCandidates], pero cada fila trae el perfil
/// (protegido) del candidato bajo `profile` — resuelto vía
/// `pipeline_candidate_id` → `headhunter_pipeline_candidates.candidate_id` →
/// `accessible_user_profiles`. Es lo que necesita la pantalla de ver/enviar
/// shortlist y la de feedback del cliente.
Future<List<Map<String, dynamic>>> listShortlistCandidatesWithProfiles(
  String shortlistId, {
  String viewerAccountType = 'headhunter',
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  final rows = await listShortlistCandidates(shortlistId, client: db);
  if (rows.isEmpty) return rows;

  final pipelineIds = rows.map((r) => r['pipeline_candidate_id'].toString()).toList();
  final pipelineRows = List<Map<String, dynamic>>.from(
    await db
        .from('headhunter_pipeline_candidates')
        .select('id, candidate_id, stage')
        .inFilter('id', pipelineIds) as List,
  );
  final candidateIdByPipelineId = {
    for (final p in pipelineRows) p['id'].toString(): p['candidate_id'].toString(),
  };
  final stageByPipelineId = {
    for (final p in pipelineRows) p['id'].toString(): p['stage'].toString(),
  };

  final candidateIds = candidateIdByPipelineId.values.toSet().toList();
  final profiles = candidateIds.isEmpty
      ? <Map<String, dynamic>>[]
      : List<Map<String, dynamic>>.from(
          await db
              .from('accessible_user_profiles')
              .select(kUserColumns)
              .inFilter('id', candidateIds) as List,
        );
  final profileById = {
    for (final p in profiles)
      p['id'].toString(): protectCandidateRowForHeadhunter(p, viewerAccountType),
  };

  return [
    for (final r in rows)
      {
        ...r,
        'profile': profileById[candidateIdByPipelineId[r['pipeline_candidate_id'].toString()]],
        'pipeline_stage': stageByPipelineId[r['pipeline_candidate_id'].toString()],
      },
  ];
}

Future<void> setShortlistCandidateNote(
  String shortlistCandidateId,
  String note, {
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  await db.from('shortlist_candidates').update({'note': note}).eq('id', shortlistCandidateId);
}

/// Registra la decisión del cliente sobre un candidato de la shortlist
/// (`Headhunter_Feedback_Cliente.png`). El headhunter la carga después de
/// hablar con el cliente por fuera de la app — no hay portal de cliente en
/// el proyecto, así que esto SIEMPRE lo escribe el headhunter dueño de la
/// shortlist (RLS lo garantiza).
Future<void> setShortlistCandidateDecision(
  String shortlistCandidateId,
  String decision, {
  String? comment,
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  await db.from('shortlist_candidates').update({
    'client_decision': decision,
    if (comment != null) 'client_comment': comment,
    'decision_at': DateTime.now().toIso8601String(),
  }).eq('id', shortlistCandidateId);
}

Future<Map<String, dynamic>> markShortlistSent(
  String shortlistId, {
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  final row = await db
      .from('shortlists')
      .update({'status': 'sent', 'sent_at': DateTime.now().toIso8601String()})
      .eq('id', shortlistId)
      .select(_kShortlistColumns)
      .single();
  return Map<String, dynamic>.from(row);
}
