import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { RtcTokenBuilder, RtcRole } from "https://esm.sh/agora-token@2.0.4";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const APP_ID = Deno.env.get('AGORA_APP_ID') ?? '';
const APP_CERT = Deno.env.get('AGORA_APP_CERT') ?? '';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: cors });

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: cors });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: authHeader } } },
  );

  const { error: authError } = await supabase.auth.getUser();
  if (authError) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: cors });
  }

  try {
    const { channelName, uid } = await req.json();
    if (!channelName) {
      return new Response(JSON.stringify({ error: 'channelName required' }), { status: 400, headers: cors });
    }
    if (!APP_ID || !APP_CERT) {
      return new Response(JSON.stringify({ error: 'Server misconfiguration' }), { status: 500, headers: cors });
    }

    const expireTs = Math.floor(Date.now() / 1000) + 3600 * 4;
    const token = RtcTokenBuilder.buildTokenWithUid(
      APP_ID, APP_CERT, channelName, uid ?? 0,
      RtcRole.PUBLISHER, expireTs, expireTs
    );

    return new Response(JSON.stringify({ token }), {
      headers: { 'Content-Type': 'application/json', ...cors },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: cors });
  }
});
