import { createClient } from 'npm:@supabase/supabase-js@2';
import { jwtDeRequest } from '../_shared/autorizacion.ts';
import {
  esTranscripcionReal,
  MARCA_SIN_AUDIO,
  descargarVideo,
  transcribirConGemini,
} from '../_shared/transcribe.ts';

// ─────────────────────────────────────────────────────────────────────────────
// analyze-video-pitch — Transcribe y evalúa con Gemini el video pitch de
// perfil del usuario autenticado (users.video_url), y guarda el resultado en
// video_pitch_analyses (migración 040).
//
// A diferencia de generate-interview-report, acá no hay "partes" que
// autorizar: el video pitch es siempre el propio, así que la autorización es
// simplemente "el JWT es válido" — no hace falta ningún join a jobs/interviews.
//
// MISMA red de seguridad que generate-interview-report: si la transcripción
// no pasa esTranscripcionReal (vacía, SIN_AUDIO, sólo "[inaudible]", etc.), se
// aborta sin guardar nada. No se genera un análisis parcial ni se evalúa una
// descripción de lo que se ve en el video en vez de lo que se dijo.
//
// Body: {} — no recibe parámetros, siempre opera sobre auth.uid() del caller.
// Usa el secret GEMINI_API_KEY (mismo que generate-interview-report /
// transcribe-interview-answer). Modelo gemini-2.5-flash.
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
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // ── AUTORIZACIÓN ─────────────────────────────────────────────────────────
    //
    // El dueño del video ES el caller: no hace falta comparar contra ningún
    // otro id. Se resuelve el uid a partir del JWT con el cliente de
    // service_role (que salta RLS) para no depender de que el caller mande un
    // user_id en el body, que sería confiar en un dato que el cliente puede
    // falsificar.
    const jwt = jwtDeRequest(req);
    if (!jwt) {
      return new Response(JSON.stringify({ error: 'sin_sesion' }), {
        status: 401, headers: corsHeaders,
      });
    }
    const { data: authData, error: authError } = await supabase.auth.getUser(jwt);
    if (authError || !authData?.user) {
      return new Response(JSON.stringify({ error: 'sesion_invalida' }), {
        status: 401, headers: corsHeaders,
      });
    }
    const uid = authData.user.id;

    const geminiKey = Deno.env.get('GEMINI_API_KEY');
    if (!geminiKey) {
      return new Response(JSON.stringify({ error: 'GEMINI_API_KEY no configurada' }), {
        status: 500, headers: corsHeaders,
      });
    }

    // ── Video pitch actual ───────────────────────────────────────────────────
    const { data: user, error: userErr } = await supabase
      .from('users')
      .select('video_url')
      .eq('id', uid)
      .maybeSingle();

    if (userErr || !user) {
      return new Response(JSON.stringify({ error: 'usuario_no_encontrado' }), {
        status: 404, headers: corsHeaders,
      });
    }

    const videoUrl = user.video_url as string | null;
    if (!videoUrl) {
      return new Response(JSON.stringify({
        error: 'sin_video_pitch',
        detalle: 'No tenés un video pitch grabado todavía.',
      }), { status: 400, headers: corsHeaders });
    }

    // ── Transcripción (misma disciplina que generate-interview-report) ──────
    const { bytes, mime } = await descargarVideo(supabase, videoUrl);
    if (bytes.length === 0) {
      return new Response(JSON.stringify({ error: 'video_vacio' }), {
        status: 422, headers: corsHeaders,
      });
    }

    const transcript = await transcribirConGemini(bytes, mime, geminiKey, `pitch_${uid}`);

    if (transcript.trim().toUpperCase() === MARCA_SIN_AUDIO) {
      return new Response(JSON.stringify({
        error: 'video_sin_voz',
        detalle: 'El video no tiene audio detectable. No se genera un análisis sobre lo que se ve: sólo sobre lo que se dice.',
      }), { status: 422, headers: corsHeaders });
    }

    if (!esTranscripcionReal(transcript)) {
      return new Response(JSON.stringify({
        error: 'transcripcion_no_disponible',
        detalle: 'No se pudo obtener una transcripción real del video. No se genera un análisis parcial.',
      }), { status: 422, headers: corsHeaders });
    }

    // ── Evaluación con Gemini ────────────────────────────────────────────────
    const prompt =
      `Sos un evaluador de video pitches de perfil profesional. La IA ASISTE, ` +
      `no decide: sé objetivo y no inventes datos que no estén en la transcripción.\n\n` +
      `Transcripción del video pitch:\n"${transcript}"\n\n` +
      `Evaluá comunicación, claridad, autenticidad y confianza, cada una en una ` +
      `escala de 0 a 5. Listá fortalezas detectadas (frases breves) y habilidades ` +
      `identificadas (palabras o frases cortas). Dá un score global de 0 a 100.`;

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
              communication_score: { type: 'number' },
              clarity_score: { type: 'number' },
              authenticity_score: { type: 'number' },
              confidence_score: { type: 'number' },
              strengths: { type: 'array', items: { type: 'string' } },
              skills: { type: 'array', items: { type: 'string' } },
              overall_score: { type: 'integer' },
            },
            required: [
              'communication_score', 'clarity_score', 'authenticity_score',
              'confidence_score', 'strengths', 'skills', 'overall_score',
            ],
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
    let analysis: {
      communication_score?: number; clarity_score?: number;
      authenticity_score?: number; confidence_score?: number;
      strengths?: unknown; skills?: unknown; overall_score?: number;
    };
    try {
      analysis = JSON.parse(raw);
    } catch {
      return new Response(JSON.stringify({ error: 'No se pudo parsear la respuesta de la IA' }), {
        status: 500, headers: corsHeaders,
      });
    }

    // ── Guardado (upsert por user_id) ────────────────────────────────────────
    const { error: upErr } = await supabase
      .from('video_pitch_analyses')
      .upsert({
        user_id: uid,
        video_url: videoUrl,
        transcript,
        communication_score: analysis.communication_score ?? null,
        clarity_score: analysis.clarity_score ?? null,
        authenticity_score: analysis.authenticity_score ?? null,
        confidence_score: analysis.confidence_score ?? null,
        strengths: analysis.strengths ?? null,
        skills: analysis.skills ?? null,
        overall_score: analysis.overall_score ?? null,
        analyzed_at: new Date().toISOString(),
      }, { onConflict: 'user_id' });

    if (upErr) {
      return new Response(JSON.stringify({ error: `Error guardando análisis: ${upErr.message}` }), {
        status: 500, headers: corsHeaders,
      });
    }

    return new Response(
      JSON.stringify({ success: true, analysis }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500, headers: corsHeaders,
    });
  }
});
