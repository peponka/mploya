// ─────────────────────────────────────────────────────────────────────────────
// generate-job-posting — Genera con IA los campos de una vacante a partir del
// título (y notas opcionales de la empresa): descripción, requisitos, rango
// salarial, seniority y tags. Devuelve JSON estructurado para que la UI lo
// muestre EDITABLE antes de guardar.
//
// Usa Gemini (gemini-2.0-flash) vía el mismo secret GEMINI_API_KEY que los
// embeddings. No persiste nada: solo genera y devuelve.
// ─────────────────────────────────────────────────────────────────────────────

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// gemini-2.5-flash: los modelos 2.0-flash tienen cuota free 0 para generateContent
// en este proyecto (429 RESOURCE_EXHAUSTED); 2.5-flash sí está disponible en free tier.
const GEMINI_URL =
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const { title, notes } = await req.json();

    if (!title || !`${title}`.trim()) {
      return new Response(JSON.stringify({ error: 'title requerido' }), {
        status: 400,
        headers: corsHeaders,
      });
    }

    const geminiKey = Deno.env.get('GEMINI_API_KEY');
    if (!geminiKey) {
      return new Response(
        JSON.stringify({ error: 'GEMINI_API_KEY no configurada' }),
        { status: 500, headers: corsHeaders },
      );
    }

    const prompt =
      `Sos un reclutador experto en Latinoamérica. A partir del título de puesto ` +
      `y las notas de la empresa, generá una publicación de vacante atractiva y ` +
      `realista para el mercado latinoamericano. Respondé SIEMPRE en español.\n\n` +
      `Título: ${title}\n` +
      `Notas de la empresa: ${notes && `${notes}`.trim() ? notes : '(sin notas)'}\n\n` +
      `Devolvé la descripción en 2-4 oraciones, entre 4 y 7 requisitos concretos, ` +
      `un rango salarial plausible (texto libre con moneda local o USD), un nivel ` +
      `de seniority y entre 3 y 6 tags/skills (con # adelante).`;

    const gRes = await fetch(GEMINI_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': geminiKey,
      },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.7,
          responseMimeType: 'application/json',
          responseSchema: {
            type: 'object',
            properties: {
              description: { type: 'string' },
              requirements: { type: 'array', items: { type: 'string' } },
              salary_range: { type: 'string' },
              seniority: { type: 'string' },
              tags: { type: 'array', items: { type: 'string' } },
            },
            required: ['description', 'requirements', 'salary_range', 'seniority', 'tags'],
          },
        },
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
    const raw = gJson?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!raw) {
      return new Response(
        JSON.stringify({ error: 'Respuesta vacía de Gemini' }),
        { status: 500, headers: corsHeaders },
      );
    }

    let parsed: unknown;
    try {
      parsed = JSON.parse(raw);
    } catch {
      return new Response(
        JSON.stringify({ error: 'No se pudo parsear la respuesta de la IA' }),
        { status: 500, headers: corsHeaders },
      );
    }

    return new Response(
      JSON.stringify({ success: true, data: parsed }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: corsHeaders },
    );
  }
});
