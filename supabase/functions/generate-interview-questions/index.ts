import { createClient } from 'npm:@supabase/supabase-js@2';

// ─────────────────────────────────────────────────────────────────────────────
// generate-interview-questions — Genera preguntas de entrevista para una vacante
// con Gemini. Si se pasa interview_id, las persiste en interview_questions.
// Si se pasa previous_qa (lista {question, answer}), genera UNA pregunta de
// seguimiento adaptada a lo respondido en vez del set inicial.
//
// Body: { job_id, interview_id?, count?, previous_qa? }
// Usa el secret GEMINI_API_KEY. Modelo gemini-2.5-flash (free tier disponible).
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
    const { job_id, interview_id, count, previous_qa } = await req.json();

    if (!job_id) {
      return new Response(JSON.stringify({ error: 'job_id requerido' }), {
        status: 400, headers: corsHeaders,
      });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: job, error } = await supabase
      .from('jobs')
      .select('title, description, salary_range, seniority, tags')
      .eq('id', job_id)
      .maybeSingle();

    if (error || !job) {
      return new Response(JSON.stringify({ error: 'Vacante no encontrada' }), {
        status: 404, headers: corsHeaders,
      });
    }

    const geminiKey = Deno.env.get('GEMINI_API_KEY');
    if (!geminiKey) {
      return new Response(JSON.stringify({ error: 'GEMINI_API_KEY no configurada' }), {
        status: 500, headers: corsHeaders,
      });
    }

    const jobCtx =
      `Puesto: ${job.title}\n` +
      `Descripción: ${job.description ?? ''}\n` +
      `Seniority: ${job.seniority ?? ''}\n` +
      `Skills/tags: ${(Array.isArray(job.tags) ? job.tags : []).join(', ')}`;

    const isFollowUp = Array.isArray(previous_qa) && previous_qa.length > 0;
    const n = isFollowUp ? 1 : Math.min(Math.max(Number(count) || 6, 1), 10);

    let prompt: string;
    if (isFollowUp) {
      const qaText = previous_qa
        .map((p: { question?: string; answer?: string }, i: number) =>
          `${i + 1}. P: ${p.question ?? ''}\n   R: ${p.answer ?? ''}`)
        .join('\n');
      prompt =
        `Sos un entrevistador experto. Contexto de la vacante:\n${jobCtx}\n\n` +
        `Preguntas y respuestas hasta ahora:\n${qaText}\n\n` +
        `Generá UNA sola pregunta de seguimiento, en español, que profundice en la ` +
        `última respuesta o cubra un vacío importante. Devolvé también su categoría ` +
        `(technical, behavioral o motivation).`;
    } else {
      prompt =
        `Sos un entrevistador experto en Latinoamérica. A partir de esta vacante, ` +
        `generá ${n} preguntas de entrevista en español, mezclando técnicas, de ` +
        `comportamiento y de motivación, ordenadas de más general a más específica.\n\n` +
        `${jobCtx}\n\n` +
        `Cada pregunta con su categoría (technical, behavioral o motivation).`;
    }

    const gRes = await fetch(GEMINI_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': geminiKey },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.7,
          responseMimeType: 'application/json',
          responseSchema: {
            type: 'object',
            properties: {
              questions: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    text: { type: 'string' },
                    category: { type: 'string' },
                  },
                  required: ['text', 'category'],
                },
              },
            },
            required: ['questions'],
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
    let questions: Array<{ text: string; category?: string }> = [];
    try {
      questions = JSON.parse(raw)?.questions ?? [];
    } catch {
      return new Response(JSON.stringify({ error: 'No se pudo parsear la respuesta de la IA' }), {
        status: 500, headers: corsHeaders,
      });
    }

    // Persistir si hay interview_id
    let inserted: unknown = null;
    if (interview_id && questions.length > 0) {
      // ord arranca después de las preguntas ya existentes (para follow-ups)
      const { count: existing } = await supabase
        .from('interview_questions')
        .select('id', { count: 'exact', head: true })
        .eq('interview_id', interview_id);
      const base = existing ?? 0;
      const rows = questions.map((q, i) => ({
        interview_id,
        ord: base + i,
        text: q.text,
        category: q.category ?? null,
        generated_by: 'ai',
      }));
      const { data, error: insErr } = await supabase
        .from('interview_questions')
        .insert(rows)
        .select();
      if (insErr) {
        return new Response(JSON.stringify({ error: `Error guardando preguntas: ${insErr.message}` }), {
          status: 500, headers: corsHeaders,
        });
      }
      inserted = data;
    }

    return new Response(
      JSON.stringify({ success: true, questions, inserted }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500, headers: corsHeaders,
    });
  }
});
