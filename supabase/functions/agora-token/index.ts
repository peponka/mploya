import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { RtcTokenBuilder, RtcRole } from "https://esm.sh/agora-token@2.0.4";

const APP_ID = '9e5d4dd01ed0449ba2990b3b7f580f0d';
const APP_CERT = '541ac679a05a4eaba824b6d43de743ad';

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, content-type' };

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: cors });
  try {
    const { channelName, uid } = await req.json();
    if (!channelName) return new Response(JSON.stringify({ error: 'channelName required' }), { status: 400, headers: cors });

    const expireTs = Math.floor(Date.now() / 1000) + 3600 * 4;
    const token = RtcTokenBuilder.buildTokenWithUid(
      APP_ID, APP_CERT, channelName, uid ?? 0,
      RtcRole.PUBLISHER, expireTs, expireTs
    );

    return new Response(JSON.stringify({ token }), { headers: { 'Content-Type': 'application/json', ...cors } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: cors });
  }
});
