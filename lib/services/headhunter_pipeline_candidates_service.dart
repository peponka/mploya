import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/headhunter_candidate_privacy.dart';
import '../utils/user_columns.dart';

/// Sourcing de candidatos por búsqueda (`public.headhunter_pipeline_candidates`,
/// migración 043) — las 7 etapas de `_Headhunter_Pipeline_Busqueda.png`
/// (Descubiertos/Contactados/Interesados/Presentados/Entrevista/Oferta/
/// Colocado). Es un flujo de sourcing propio de Headhunter, no
/// `job_applications` (ver el doc-comment de la migración 043 para el
/// porqué).
///
/// Todo candidato que se muestra pasa por `protectCandidateRowForHeadhunter`
/// — mismo gate de privacidad que el pipeline global y Talent Pool.

const kPipelineStages = [
  'descubierto', 'contactado', 'interesado', 'presentado',
  'entrevista', 'oferta', 'colocado',
];

String pipelineStageLabel(String stage) => switch (stage) {
      'descubierto' => 'Descubiertos',
      'contactado' => 'Contactados',
      'interesado' => 'Interesados',
      'presentado' => 'Presentados',
      'entrevista' => 'Entrevista',
      'oferta' => 'Oferta',
      'colocado' => 'Colocado',
      _ => stage,
    };

/// Candidatos de una búsqueda, con el perfil (protegido) embebido bajo
/// `profile`. `viewerAccountType` siempre es `'headhunter'` acá — parámetro
/// explícito, no hardcodeado, para que un test pueda variarlo.
Future<List<Map<String, dynamic>>> listPipelineCandidates(
  String jobId, {
  String viewerAccountType = 'headhunter',
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  final uid = db.auth.currentUser?.id;
  if (uid == null) return const [];

  final entries = List<Map<String, dynamic>>.from(
    await db
        .from('headhunter_pipeline_candidates')
        .select('id, job_id, candidate_id, stage, match_score, stage_changed_at, created_at')
        .eq('job_id', jobId)
        .eq('headhunter_id', uid)
        .order('match_score', ascending: false) as List,
  );
  if (entries.isEmpty) return entries;

  final candidateIds = entries.map((e) => e['candidate_id'].toString()).toList();
  final profiles = List<Map<String, dynamic>>.from(
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
    for (final e in entries)
      {...e, 'profile': profileById[e['candidate_id'].toString()]},
  ];
}

/// Agrega un candidato "a mano" (desde Talent Pool) con `stage: descubierto`
/// y sin match score — no se inventa un porcentaje para alguien que no pasó
/// por `match_candidates_for_job`. Idempotente vía `upsert` sobre el
/// `UNIQUE(job_id, candidate_id)`: agregar dos veces no duplica ni pisa la
/// etapa que ya tenía.
Future<void> addCandidateToPipeline({
  required String jobId,
  required String candidateId,
  double? matchScore,
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  final uid = db.auth.currentUser?.id;
  if (uid == null) throw StateError('addCandidateToPipeline: sin sesión activa');

  await db.from('headhunter_pipeline_candidates').upsert({
    'headhunter_id': uid,
    'job_id': jobId,
    'candidate_id': candidateId,
    'source': 'talent_pool',
    if (matchScore != null) 'match_score': matchScore,
  }, onConflict: 'job_id,candidate_id', ignoreDuplicates: true);
}

/// Trae los mejores matches reales de `jobId` (RPC `match_candidates_for_job`,
/// migración 034) y los agrega como `descubierto` con su `similarity` real.
/// Candidatos ya presentes en el pipeline no se tocan (`ignoreDuplicates`):
/// no se pisa una etapa a la que el headhunter ya avanzó a mano.
Future<int> discoverMatchesForJob({
  required String jobId,
  int limit = 20,
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  final uid = db.auth.currentUser?.id;
  if (uid == null) return 0;

  final matches = List<Map<String, dynamic>>.from(
    await db.rpc('match_candidates_for_job', params: {
      'p_job_id': jobId,
      'p_limit': limit,
    }) as List,
  );
  if (matches.isEmpty) return 0;

  final rows = [
    for (final m in matches)
      {
        'headhunter_id': uid,
        'job_id': jobId,
        'candidate_id': m['id'],
        'match_score': m['similarity'],
        'source': 'busqueda_activa',
      },
  ];
  await db
      .from('headhunter_pipeline_candidates')
      .upsert(rows, onConflict: 'job_id,candidate_id', ignoreDuplicates: true);
  return rows.length;
}

Future<void> setPipelineCandidateStage(
  String pipelineCandidateId,
  String stage, {
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  await db
      .from('headhunter_pipeline_candidates')
      .update({'stage': stage})
      .eq('id', pipelineCandidateId);
}

Map<String, int> pipelineStageCounts(List<Map<String, dynamic>> entries) {
  final counts = {for (final s in kPipelineStages) s: 0};
  for (final e in entries) {
    final stage = e['stage']?.toString();
    if (stage != null && counts.containsKey(stage)) counts[stage] = counts[stage]! + 1;
  }
  return counts;
}
