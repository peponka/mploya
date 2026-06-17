import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const { user_id } = await req.json();

    if (!user_id) {
      return new Response(JSON.stringify({ error: 'user_id requerido' }), {
        status: 400,
        headers: corsHeaders,
      });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // Leer perfil del usuario
    const { data: user, error } = await supabase
      .from('users')
      .select('name, headline, about, tags, skills')
      .eq('id', user_id)
      .maybeSingle();

    if (error || !user) {
      return new Response(JSON.stringify({ error: 'Usuario no encontrado' }), {
        status: 404,
        headers: corsHeaders,
      });
    }

    // Construir texto representativo del perfil
    const profileText = [
      user.headline,
      user.about,
      ...(Array.isArray(user.tags) ? user.tags : []),
      ...(Array.isArray(user.skills) ? user.skills : []),
    ]
      .filter(Boolean)
      .join(' ');

    if (!profileText.trim()) {
      return new Response(
        JSON.stringify({ error: 'Perfil vacío — completá headline, tags y skills primero' }),
        { status: 400, headers: corsHeaders },
      );
    }

    const hfKey = Deno.env.get('HUGGINGFACE_API_KEY');
    if (!hfKey) {
      return new Response(
        JSON.stringify({ error: 'HUGGINGFACE_API_KEY no configurada' }),
        { status: 500, headers: corsHeaders },
      );
    }

    // Generar embedding con HuggingFace (all-MiniLM-L6-v2, 384 dims, gratuito)
    const hfRes = await fetch(
      'https://api-inference.huggingface.co/pipeline/feature-extraction/sentence-transformers/all-MiniLM-L6-v2',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${hfKey}`,
        },
        body: JSON.stringify({ inputs: profileText, options: { wait_for_model: true } }),
      },
    );

    if (!hfRes.ok) {
      const errText = await hfRes.text();
      return new Response(
        JSON.stringify({ error: `HuggingFace error: ${errText}` }),
        { status: 500, headers: corsHeaders },
      );
    }

    const embedding = await hfRes.json();

    // Guardar embedding en la tabla users
    const { error: updateError } = await supabase
      .from('users')
      .update({ profile_embedding: JSON.stringify(embedding) })
      .eq('id', user_id);

    if (updateError) {
      return new Response(
        JSON.stringify({ error: `Error guardando embedding: ${updateError.message}` }),
        { status: 500, headers: corsHeaders },
      );
    }

    return new Response(
      JSON.stringify({ success: true, dims: Array.isArray(embedding) ? embedding.length : 0 }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: corsHeaders },
    );
  }
});
