import { createClient } from 'npm:@supabase/supabase-js@2';
import {
  esParteDeLaEntrevista,
  jwtDeRequest,
} from '../_shared/autorizacion.ts';
import {
  esTranscripcionReal,
  transcribirRespuesta,
} from '../_shared/transcribe.ts';

// ─────────────────────────────────────────────────────────────────────────────
// generate-interview-report — Lee las preguntas + respuestas transcriptas de una
// entrevista y genera un informe para RRHH con Gemini: resumen, competencias,
// palabras clave, score (0-100) y el POR QUÉ del score (IA explicable). Lo
// persiste (upsert) en interview_reports.
//
// Body: { interview_id }
// Usa el secret GEMINI_API_KEY. Modelo gemini-2.5-flash.
//
// ── RED DE SEGURIDAD DE TRANSCRIPCIÓN (12/8/2026) ───────────────────────────
//
// Antes, el cliente guardaba el texto fijo "[Respuesta grabada en video]" en
// `interview_answers.transcript`, y esta función lo tomaba como si fuera la
// respuesta del candidato. Resultado: informes con score y competencias
// generados sobre una frase de relleno repetida, presentados a la empresa como
// una evaluación real.
//
// Ahora, ANTES de evaluar:
//   1. se revisa cada respuesta;
//   2. las que no tengan transcripción REAL se intentan transcribir acá mismo
//      (por si el disparo del cliente se perdió);
//   3. se vuelve a verificar;
//   4. si queda alguna sin transcripción real, se ABORTA con un motivo claro.
//
// No se genera informe parcial. No se rellena con "(sin respuesta)". Un informe
// que no puede leer lo que dijo el candidato no debe existir.
// ─────────────────────────────────────────────────────────────────────────────

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const GEMINI_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const { interview_id } = await req.json();
    if (!interview_id) {
      return new Response(JSON.stringify({ error: 'interview_id requerido' }), {
        status: 400, headers: corsHeaders,
      });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // ── AUTORIZACIÓN ─────────────────────────────────────────────────────────
    //
    // Esta función corre con service_role, o sea que SALTEA RLS: sin este
    // chequeo, cualquiera con un interview_id recibía en la respuesta el informe
    // completo de un candidato ajeno, lo escribía en interview_reports, marcaba
    // la entrevista como completed y —desde que existe la red de
    // transcripción— hacía que mandáramos sus VIDEOS a Gemini.
    //
    // Va ANTES de leer nada de la entrevista.
    const permiso = await esParteDeLaEntrevista(
      supabase,
      jwtDeRequest(req),
      interview_id,
    );
    if (!permiso.ok) {
      return new Response(JSON.stringify({ error: permiso.error }), {
        status: permiso.status ?? 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Entrevista + vacante
    const { data: interview, error: iErr } = await supabase
      .from('interviews')
      .select('id, job_id, candidate_id')
      .eq('id', interview_id)
      .maybeSingle();
    if (iErr || !interview) {
      return new Response(JSON.stringify({ error: 'Entrevista no encontrada' }), {
        status: 404, headers: corsHeaders,
      });
    }

    const { data: job } = await supabase
      .from('jobs').select('title, description').eq('id', interview.job_id).maybeSingle();

    // Preguntas y respuestas
    const { data: questions } = await supabase
      .from('interview_questions')
      .select('id, ord, text, category')
      .eq('interview_id', interview_id)
      .order('ord', { ascending: true });

    if (!questions || questions.length === 0) {
      return new Response(JSON.stringify({ error: 'La entrevista no tiene preguntas' }), {
        status: 400, headers: corsHeaders,
      });
    }

    const geminiKey = Deno.env.get('GEMINI_API_KEY');
    if (!geminiKey) {
      return new Response(JSON.stringify({ error: 'GEMINI_API_KEY no configurada' }), {
        status: 500, headers: corsHeaders,
      });
    }

    const leerRespuestas = async () => {
      const { data } = await supabase
        .from('interview_answers')
        .select('question_id, transcript, created_at')
        .eq('interview_id', interview_id)
        .order('created_at', { ascending: true });

      // Si el candidato reintentó una pregunta hay más de una fila: vale la
      // última, que es la que también usa la transcripción.
      const porPregunta = new Map<string, string>();
      for (const a of data ?? []) {
        porPregunta.set(a.question_id as string, (a.transcript as string) ?? '');
      }
      return porPregunta;
    };

    let respuestas = await leerRespuestas();

    // ── Recuperar lo que falte ───────────────────────────────────────────────
    //
    // Se reutiliza todo lo ya transcripto: sólo se procesan los videos de las
    // respuestas cuyo texto no pasa `esTranscripcionReal` (NULL, vacío, el
    // placeholder viejo o una marca tipo "[inaudible]"). Si el cliente ya las
    // transcribió al subirlas, este bloque no gasta un solo token.
    const faltantes = questions
      .map((q) => q.id as string)
      .filter((id) => !esTranscripcionReal(respuestas.get(id)));

    const sinRespuesta: string[] = [];
    for (const questionId of faltantes) {
      const r = await transcribirRespuesta(
        supabase, geminiKey, interview_id, questionId,
      );
      if (!r.ok) sinRespuesta.push(`${questionId}: ${r.error}`);
    }

    if (faltantes.length > 0) respuestas = await leerRespuestas();

    // ── Verificación final: o están todas, o no hay informe ──────────────────
    const irrecuperables = questions
      .map((q) => q.id as string)
      .filter((id) => !esTranscripcionReal(respuestas.get(id)));

    if (irrecuperables.length > 0) {
      return new Response(JSON.stringify({
        error: 'transcripciones_faltantes',
        detalle:
          `${irrecuperables.length} de ${questions.length} respuestas no tienen ` +
          `transcripción real. No se genera el informe: evaluarlas sería ` +
          `inventar una evaluación.`,
        motivos: sinRespuesta,
      }), { status: 422, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const qaText = questions
      .map((q, i) =>
        `${i + 1}. [${q.category ?? '-'}] P: ${q.text}\n   R: ${respuestas.get(q.id as string)}`)
      .join('\n');

    const prompt =
      `Sos un especialista de RRHH. Evaluá esta entrevista para el puesto ` +
      `"${job?.title ?? ''}". La IA ASISTE, no decide: sé objetivo, justificá el score ` +
      `y no inventes datos que no estén en las respuestas.\n\n` +
      `Descripción del puesto: ${job?.description ?? ''}\n\n` +
      `Entrevista (preguntas y respuestas transcriptas):\n${qaText}\n\n` +
      `Devolvé: un resumen (2-4 oraciones), una lista de competencias evaluadas ` +
      `(cada una con nombre, score 0-100 y una nota breve), palabras clave detectadas, ` +
      `un score global 0-100, y el motivo del score (rationale).`;

    const gRes = await fetch(GEMINI_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': geminiKey },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.4,
          responseMimeType: 'application/json',
          responseSchema: {
            type: 'object',
            properties: {
              summary: { type: 'string' },
              competencies: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    name: { type: 'string' },
                    score: { type: 'integer' },
                    note: { type: 'string' },
                  },
                  required: ['name', 'score'],
                },
              },
              keywords: { type: 'array', items: { type: 'string' } },
              score: { type: 'integer' },
              rationale: { type: 'string' },
            },
            required: ['summary', 'competencies', 'keywords', 'score', 'rationale'],
          },
        },
      }),
    });

    if (!gRes.ok) {
      const errText = await gRes.text();
      return new Response(JSON.stringify({ error: `Gemini error: ${errText}` }), {
        status: 500, headers: corsHeaders,
      });
    }

    const gJson = await gRes.json();
    const raw = gJson?.candidates?.[0]?.content?.parts?.[0]?.text;
    let report: {
      summary?: string; competencies?: unknown; keywords?: unknown;
      score?: number; rationale?: string;
    };
    try {
      report = JSON.parse(raw);
    } catch {
      return new Response(JSON.stringify({ error: 'No se pudo parsear la respuesta de la IA' }), {
        status: 500, headers: corsHeaders,
      });
    }

    // Upsert del informe (unique por interview_id)
    const { error: upErr } = await supabase
      .from('interview_reports')
      .upsert({
        interview_id,
        summary: report.summary ?? null,
        competencies: report.competencies ?? null,
        keywords: report.keywords ?? null,
        score: report.score ?? null,
        rationale: report.rationale ?? null,
      }, { onConflict: 'interview_id' });

    if (upErr) {
      return new Response(JSON.stringify({ error: `Error guardando informe: ${upErr.message}` }), {
        status: 500, headers: corsHeaders,
      });
    }

    // Marcar la entrevista como completada
    await supabase.from('interviews')
      .update({ status: 'completed', completed_at: new Date().toISOString() })
      .eq('id', interview_id);

    return new Response(
      JSON.stringify({ success: true, report }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500, headers: corsHeaders,
    });
  }
});
