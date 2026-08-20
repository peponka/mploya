import 'package:supabase_flutter/supabase_flutter.dart';

/// Lectura de `public.video_pitch_analyses` + disparo de la Edge Function
/// `analyze-video-pitch` (migración 040).
///
/// Sólo la Edge Function (service role) escribe en la tabla — ver la policy
/// `vpa_select`, no hay INSERT/UPDATE para `authenticated`. Por eso acá no
/// hay una función de "guardar análisis": el único camino de escritura es
/// `requestPitchAnalysis`.

const _kAnalysisColumns = '''
  user_id, video_url, transcript, communication_score, clarity_score,
  authenticity_score, confidence_score, strengths, skills, overall_score,
  analyzed_at
''';

/// Trae el análisis guardado del usuario actual, o `null` si nunca se generó
/// uno (video sin analizar todavía) — no es un error, es un estado real.
Future<Map<String, dynamic>?> getMyPitchAnalysis({SupabaseClient? client}) async {
  final db = client ?? Supabase.instance.client;
  final uid = db.auth.currentUser?.id;
  if (uid == null) return null;

  final row = await db
      .from('video_pitch_analyses')
      .select(_kAnalysisColumns)
      .eq('user_id', uid)
      .maybeSingle();
  return row == null ? null : Map<String, dynamic>.from(row);
}

/// Resultado de pedir un análisis nuevo.
class PitchAnalysisResult {
  const PitchAnalysisResult.success(this.analysis)
      : ok = true, error = null, detail = null;
  const PitchAnalysisResult.failure(this.error, {this.detail})
      : ok = false, analysis = null;

  final bool ok;
  final Map<String, dynamic>? analysis;
  final String? error;
  final String? detail;
}

/// Invoca `analyze-video-pitch`. Transcribe y evalúa `users.video_url` del
/// usuario autenticado con Gemini, del lado del servidor — puede tardar
/// varios segundos (video largo → Files API) y consume `GEMINI_API_KEY` del
/// proyecto, así que se llama sólo cuando el usuario lo pide explícitamente,
/// no automáticamente al abrir una pantalla.
Future<PitchAnalysisResult> requestPitchAnalysis({SupabaseClient? client}) async {
  final db = client ?? Supabase.instance.client;

  try {
    final res = await db.functions.invoke('analyze-video-pitch');
    final body = res.data;

    // Mismo patrón que el resto del proyecto (ver ai_interview_service.dart):
    // `invoke` no tira excepción en un 4xx/5xx acá, devuelve la respuesta con
    // el status real — el error viene en el body, no en un catch.
    if (res.status != 200) {
      final message = body is Map ? body['error']?.toString() : null;
      final detail = body is Map ? body['detalle']?.toString() : null;
      return PitchAnalysisResult.failure(
        message ?? 'analyze-video-pitch falló (HTTP ${res.status})',
        detail: detail,
      );
    }
    if (body is Map && body['analysis'] is Map) {
      return PitchAnalysisResult.success(
        Map<String, dynamic>.from(body['analysis'] as Map),
      );
    }
    // Éxito pero sin el shape esperado: releer la tabla en vez de asumir.
    final saved = await getMyPitchAnalysis(client: db);
    return saved == null
        ? const PitchAnalysisResult.failure('respuesta_inesperada')
        : PitchAnalysisResult.success(saved);
  } catch (e) {
    return PitchAnalysisResult.failure(e.toString());
  }
}
