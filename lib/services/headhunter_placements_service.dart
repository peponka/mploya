import 'package:supabase_flutter/supabase_flutter.dart';

/// Escritura sobre `public.headhunter_placements` (migración 044).
///
/// `feeAmount` es opcional en ambas funciones a propósito: el headhunter
/// puede registrar que colocó a alguien sin saber el fee todavía y cargarlo
/// después — nunca se completa con un número inventado.

Future<Map<String, dynamic>> registerPlacement({
  required String pipelineCandidateId,
  required String jobId,
  required String candidateId,
  String? clientId,
  double? feeAmount,
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  final uid = db.auth.currentUser?.id;
  if (uid == null) throw StateError('registerPlacement: sin sesión activa');

  final row = await db
      .from('headhunter_placements')
      .upsert({
        'headhunter_id': uid,
        'pipeline_candidate_id': pipelineCandidateId,
        'job_id': jobId,
        'candidate_id': candidateId,
        if (clientId != null) 'client_id': clientId,
        if (feeAmount != null) 'fee_amount': feeAmount,
      }, onConflict: 'pipeline_candidate_id')
      .select()
      .single();
  return Map<String, dynamic>.from(row);
}

Future<void> updatePlacementFee(
  String placementId, {
  double? feeAmount,
  bool? marcarCobrado,
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  final fields = <String, dynamic>{
    if (feeAmount != null) 'fee_amount': feeAmount,
  };
  if (marcarCobrado == true) {
    fields['payment_status'] = 'cobrado';
    fields['paid_at'] = DateTime.now().toIso8601String();
  } else if (marcarCobrado == false) {
    fields['payment_status'] = 'pendiente';
    fields['paid_at'] = null;
  }
  if (fields.isEmpty) return;
  await db.from('headhunter_placements').update(fields).eq('id', placementId);
}
