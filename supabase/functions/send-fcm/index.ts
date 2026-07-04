import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// ── FCM v1 via JWT (service account) ─────────────────────────────────────────
// La API legacy (Authorization: key=...) fue deshabilitada por Google en junio 2024.
// Esta versión usa el service account JSON guardado en el secret FIREBASE_SERVICE_ACCOUNT
// para obtener un access_token OAuth2 y llamar a la FCM v1 HTTP API.

interface ServiceAccount {
  project_id: string;
  private_key: string;
  client_email: string;
}

/** Genera un JWT firmado con RS256 para Google OAuth2 */
async function buildJwt(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };

  const encode = (obj: object) =>
    btoa(JSON.stringify(obj)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

  const headerB64 = encode(header);
  const payloadB64 = encode(payload);
  const unsigned = `${headerB64}.${payloadB64}`;

  // Importar la clave privada PEM como CryptoKey
  const pem = sa.private_key.replace(/\\n/g, '\n');
  const pemBody = pem.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\n/g, '');
  const keyBytes = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyBytes.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(unsigned),
  );

  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

  return `${unsigned}.${sigB64}`;
}

/** Intercambia el JWT por un access_token de Google OAuth2 */
async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const jwt = await buildJwt(sa);
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`OAuth2 token error: ${err}`);
  }
  const json = await res.json();
  return json.access_token as string;
}

// ─────────────────────────────────────────────────────────────────────────────

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

    // Obtener FCM token del usuario destino
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

    // Cargar service account desde el secret
    const saRaw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
    if (!saRaw) {
      return new Response(
        JSON.stringify({ error: 'FIREBASE_SERVICE_ACCOUNT no configurada' }),
        { status: 500, headers: corsHeaders },
      );
    }
    const sa: ServiceAccount = JSON.parse(saRaw);

    // Obtener access token OAuth2
    const accessToken = await getAccessToken(sa);

    // Llamar a FCM v1 HTTP API
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;
    const fcmRes = await fetch(fcmUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token: user.fcm_token,
          notification: { title, body },
          android: {
            priority: 'high',
            notification: { sound: 'default' },
          },
          apns: {
            payload: { aps: { sound: 'default', badge: 1 } },
          },
          data: data ?? {},
        },
      }),
    });

    const result = await fcmRes.json();

    // FCM v1 devuelve error con código UNREGISTERED si el token no es válido
    if (!fcmRes.ok) {
      const errCode = result?.error?.details?.[0]?.errorCode ?? result?.error?.status ?? '';
      if (errCode === 'UNREGISTERED' || errCode === 'INVALID_ARGUMENT') {
        await supabase.from('users').update({ fcm_token: null }).eq('id', target_user_id);
      }
    }

    return new Response(JSON.stringify(result), {
      status: fcmRes.ok ? 200 : fcmRes.status,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: corsHeaders },
    );
  }
});
