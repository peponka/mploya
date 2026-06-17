import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const { target_user_id, title, body, data } = await req.json();

    if (!target_user_id || !title || !body) {
      return new Response(
        JSON.stringify({ error: 'target_user_id, title y body son requeridos' }),
        { status: 400, headers: corsHeaders },
      );
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // Obtener el FCM token del usuario destino
    const { data: user, error } = await supabase
      .from('users')
      .select('fcm_token, name')
      .eq('id', target_user_id)
      .maybeSingle();

    if (error || !user?.fcm_token) {
      return new Response(
        JSON.stringify({ error: 'Usuario sin FCM token registrado', skipped: true }),
        { status: 200, headers: corsHeaders },
      );
    }

    const serverKey = Deno.env.get('FIREBASE_SERVER_KEY');
    if (!serverKey) {
      return new Response(
        JSON.stringify({ error: 'FIREBASE_SERVER_KEY no configurada' }),
        { status: 500, headers: corsHeaders },
      );
    }

    // Llamar a la API de FCM (legacy HTTP API)
    const fcmRes = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `key=${serverKey}`,
      },
      body: JSON.stringify({
        to: user.fcm_token,
        notification: {
          title,
          body,
          sound: 'default',
          badge: '1',
        },
        data: data ?? {},
        priority: 'high',
      }),
    });

    const result = await fcmRes.json();

    // FCM devuelve success:0 cuando el token no es válido
    if (result.failure === 1) {
      // Token inválido — limpiarlo de la DB
      await supabase
        .from('users')
        .update({ fcm_token: null })
        .eq('id', target_user_id);
    }

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: corsHeaders },
    );
  }
});
