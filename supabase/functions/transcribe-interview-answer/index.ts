import { createClient } from 'npm:@supabase/supabase-js@2';
import {
  esParteDeLaEntrevista,
  jwtDeRequest,
} from '../_shared/autorizacion.ts';
import { transcribirRespuesta } from '../_shared/transcribe.ts';

// ─────────────────────────────────────────────────────────────────────────────
// transcribe-interview-answer — Transcribe el audio de UNA respuesta de
// entrevista y lo guarda en `interview_answers.transcript`.
//
// Body: { interview_id, question_id }
//
// POR QUÉ EXISTE. Hasta ahora `interview_answers.transcript` guardaba el texto
// fijo "[Respuesta grabada en video]" y `generate-interview-report` evaluaba ESO:
// el informe de IA no analizaba nada de lo que el candidato había dicho. El
// video se subía y nadie lo escuchaba nunca.
//
// La transcripción en sí vive en `_shared/transcribe.ts`, que comparte con
// generate-interview-report para que las dos vías apliquen las mismas reglas.
// Acá está lo que es propio de exponerla por HTTP: QUIÉN puede llamarla.
//
// Secretos: GEMINI_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY. Los tres ya
// existen y los usan las otras funciones. No hay secretos nuevos.
// ─────────────────────────────────────────────────────────────────────────────

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const json = (cuerpo: unknown, status = 200) =>
  new Response(JSON.stringify(cuerpo), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

const ES_UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const { interview_id, question_id } = await req.json();

    // ── Forma de los ids ─────────────────────────────────────────────────────
    //
    // Se exige UUID. Esto además cierra la puerta a los ids `demo-*`, que
    // `AIInterviewService` responde con entrevistas, preguntas, respuestas y
    // videos INVENTADOS: acá no se entra con eso ni por casualidad.
    if (!ES_UUID.test(String(interview_id ?? '')) ||
        !ES_UUID.test(String(question_id ?? ''))) {
      return json({ error: 'interview_id y question_id deben ser uuid' }, 400);
    }

    const url = Deno.env.get('SUPABASE_URL');
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const geminiKey = Deno.env.get('GEMINI_API_KEY');
    if (!url || !serviceKey) {
      return json({ error: 'faltan SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY' }, 500);
    }
    if (!geminiKey) {
      return json({ error: 'GEMINI_API_KEY no configurada' }, 500);
    }

    // El cliente de servicio NUNCA sale de acá: el service_role no se expone al
    // llamador ni viaja en ninguna respuesta.
    const supabase = createClient(url, serviceKey);

    // ── AUTORIZACIÓN ─────────────────────────────────────────────────────────
    //
    // Sin esto, cualquier usuario logueado podría hacer que transcribamos
    // entrevistas ajenas y quemar cuota de Gemini a voluntad.
    //
    // La regla vive en `_shared/autorizacion.ts` y es LA MISMA que aplica
    // generate-interview-report: candidato de la entrevista o empresa dueña de
    // la vacante, resuelto del JWT contra la base, nunca del body.
    const permiso = await esParteDeLaEntrevista(
      supabase,
      jwtDeRequest(req),
      interview_id,
    );
    if (!permiso.ok) {
      return json({ error: permiso.error }, permiso.status ?? 403);
    }

    // La pregunta tiene que pertenecer a ESTA entrevista. Sin este chequeo se
    // podría pedir la transcripción de una respuesta de otra entrevista pasando
    // un question_id ajeno.
    const { data: pregunta } = await supabase
      .from('interview_questions')
      .select('id')
      .eq('id', question_id)
      .eq('interview_id', interview_id)
      .maybeSingle();

    if (!pregunta) return json({ error: 'pregunta_ajena_a_la_entrevista' }, 404);

    // ── Transcripción ────────────────────────────────────────────────────────
    const r = await transcribirRespuesta(
      supabase,
      geminiKey,
      interview_id,
      question_id,
    );

    if (!r.ok) return json({ ok: false, error: r.error }, 422);

    // La transcripción no se devuelve entera: quien la necesita la lee de la
    // tabla, con sus propias políticas de RLS.
    return json({ ok: true, estado: r.estado, largo: r.transcript?.length ?? 0 });
  } catch (err) {
    return json({ error: (err as Error).message }, 500);
  }
});
