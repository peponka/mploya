import { createClient } from 'npm:@supabase/supabase-js@2';

// ─────────────────────────────────────────────────────────────────────────────
// generate-job-embedding — Genera el embedding de UNA vacante y lo persiste en
// jobs.embedding usando Gemini (gemini-embedding-001, 1536 dims), el MISMO modelo
// y dimensión que los perfiles (generate-embedding), para que vacantes y
// candidatos vivan en el mismo espacio vectorial y el matching coseno tenga sentido.
//
// El proveedor de embeddings está aislado acá: cambiarlo implica tocar solo esta
// función + generate-embedding + la dimensión de las columnas vector(1536).
//
// Requiere el secret GEMINI_API_KEY (Supabase → Edge Functions → Secrets).
// ─────────────────────────────────────────────────────────────────────────────

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const EMBED_DIMS = 1536;
const GEMINI_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const { job_id } = await req.json();

    if (!job_id) {
      return new Response(JSON.stringify({ error: 'job_id requerido' }), {
        status: 400,
        headers: corsHeaders,
      });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // Leer la vacante
    const { data: job, error } = await supabase
      .from('jobs')
      .select('title, description, salary_range, location, seniority, tags')
      .eq('id', job_id)
      .maybeSingle();

    if (error || !job) {
      return new Response(JSON.stringify({ error: 'Vacante no encontrada' }), {
        status: 404,
        headers: corsHeaders,
      });
    }

    // Construir texto representativo de la vacante
    const jobText = [
      job.title,
      job.description,
      job.salary_range,
      job.location,
      job.seniority,
      ...(Array.isArray(job.tags) ? job.tags : []),
    ]
      .filter(Boolean)
      .join(' ');

    if (!jobText.trim()) {
      return new Response(
        JSON.stringify({ error: 'Vacante vacía — completá al menos título y descripción' }),
        { status: 400, headers: corsHeaders },
      );
    }

    const geminiKey = Deno.env.get('GEMINI_API_KEY');
    if (!geminiKey) {
      return new Response(
        JSON.stringify({ error: 'GEMINI_API_KEY no configurada' }),
        { status: 500, headers: corsHeaders },
      );
    }

    // Generar embedding con Gemini (gemini-embedding-001, truncado a 1536 dims).
    // La similitud coseno es invariante a la escala, así que no re-normalizamos.
    const gRes = await fetch(GEMINI_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': geminiKey,
      },
      body: JSON.stringify({
        content: { parts: [{ text: jobText }] },
        outputDimensionality: EMBED_DIMS,
      }),
    });

    if (!gRes.ok) {
      const errText = await gRes.text();
      return new Response(
        JSON.stringify({ error: `Gemini error: ${errText}` }),
        { status: 500, headers: corsHeaders },
      );
    }

    const gJson = await gRes.json();
    const embedding = gJson?.embedding?.values;

    if (!Array.isArray(embedding) || embedding.length !== EMBED_DIMS) {
      return new Response(
        JSON.stringify({ error: `Embedding inesperado (dims=${Array.isArray(embedding) ? embedding.length : 'n/a'})` }),
        { status: 500, headers: corsHeaders },
      );
    }

    // Persistir el embedding en la vacante
    const { error: updateError } = await supabase
      .from('jobs')
      .update({ embedding: JSON.stringify(embedding) })
      .eq('id', job_id);

    if (updateError) {
      return new Response(
        JSON.stringify({ error: `Error guardando embedding: ${updateError.message}` }),
        { status: 500, headers: corsHeaders },
      );
    }

    return new Response(
      JSON.stringify({ success: true, dims: embedding.length }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: corsHeaders },
    );
  }
});
