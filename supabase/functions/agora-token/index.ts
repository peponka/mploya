import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const APP_ID = '9e5d4dd01ed0449ba2990b3b7f580f0d';
const APP_CERT = '541ac679a05a4eaba824b6d43de743ad';

const le16 = (v: number) => { const b = new ArrayBuffer(2); new DataView(b).setUint16(0, v, true); return new Uint8Array(b); };
const le32 = (v: number) => { const b = new ArrayBuffer(4); new DataView(b).setUint32(0, v, true); return new Uint8Array(b); };
const cat = (...a: Uint8Array[]) => { const r = new Uint8Array(a.reduce((s, x) => s + x.length, 0)); let o = 0; for (const x of a) { r.set(x, o); o += x.length; } return r; };
const packBytes = (b: Uint8Array) => cat(le16(b.length), b);
const packStr = (s: string) => packBytes(new TextEncoder().encode(s));

async function hmacSha256(key: Uint8Array, msg: Uint8Array): Promise<Uint8Array> {
  const k = await crypto.subtle.importKey('raw', key, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return new Uint8Array(await crypto.subtle.sign('HMAC', k, msg));
}

// AccessToken2 — compatible con Agora SDK 4.x / agora_rtc_engine 6.x
async function buildToken(channel: string, uid: number, expireSec: number): Promise<string> {
  const issueTs = Math.floor(Date.now() / 1000);
  const salt = Math.floor(Math.random() * 99999998) + 1;
  const uidStr = uid === 0 ? '' : String(uid);
  const privExpire = issueTs + expireSec;

  // Firma en dos pasos
  const sigMsg = new TextEncoder().encode(APP_CERT + String(salt) + String(issueTs) + String(expireSec));
  const sig1 = await hmacSha256(le32(issueTs), sigMsg);
  const signing = await hmacSha256(sig1, new TextEncoder().encode(APP_ID));

  // Payload del servicio RTC
  const privs: [number, number][] = [[1, privExpire], [2, privExpire], [3, privExpire], [4, privExpire]];
  const svcBuf = cat(
    le16(1), // ServiceRtc
    packStr(channel),
    packStr(uidStr),
    le16(privs.length),
    ...privs.flatMap(([k, v]) => [le16(k), le32(v)])
  );

  // Token final
  const content = cat(le32(issueTs), le32(salt), le32(expireSec), packBytes(signing), packBytes(svcBuf));
  return '007' + btoa(String.fromCharCode(...content));
}

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, content-type' };

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: cors });
  try {
    const { channelName, uid } = await req.json();
    if (!channelName) return new Response(JSON.stringify({ error: 'channelName required' }), { status: 400, headers: cors });
    const token = await buildToken(channelName, uid ?? 0, 3600 * 4);
    return new Response(JSON.stringify({ token }), { headers: { 'Content-Type': 'application/json', ...cors } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: cors });
  }
});
