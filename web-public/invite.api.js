// ============================================================================
// Landing de invitación — mploya.ai/invite/<code>
// ============================================================================
// ReferralService reparte links `https://mploya.ai/invite/<code>` desde la app,
// pero esa ruta NO existía: daba 404. Resultado medido el 28/7/2026: 6 códigos
// generados y 0 referidos registrados.
//
// Esta página server-rendered muestra quién invita (RPC pública
// get_referrer_name, que solo expone el nombre) y manda a la app con ?ref=<code>;
// además deja el código en localStorage por si el usuario se registra más tarde.
// ============================================================================

const SUPABASE_URL = 'https://qclipzefqndcefwwixdy.supabase.co';
const ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.' +
  'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFjbGlwemVmcW5kY2Vmd3dpeGR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ2MzQ1MjYsImV4cCI6MjA5MDIxMDUyNn0.' +
  'Pl6xdBAHP0yuSq91Dpv1SamSFkn4lTVsLOcu2EKdwkM';

const esc = (s) =>
  String(s ?? '').replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function render({ code, referrer }) {
  const who = referrer ? esc(referrer) : null;
  const title = who ? `${who} te invitó a Mploya` : 'Te invitaron a Mploya';
  const desc =
    'Conseguí trabajo mostrando quién sos: video-pitches de 60 segundos en vez de un CV. Gratis.';
  const url = `https://www.mploya.ai/invite/${encodeURIComponent(code)}`;
  const appUrl = `/app/?ref=${encodeURIComponent(code)}`;

  return `<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>${esc(title)} · Mploya</title>
<meta name="description" content="${esc(desc)}"/>
<link rel="canonical" href="${esc(url)}"/>
<meta property="og:type" content="website"/>
<meta property="og:title" content="${esc(title)}"/>
<meta property="og:description" content="${esc(desc)}"/>
<meta property="og:image" content="https://www.mploya.ai/img/og_cover.png"/>
<meta property="og:url" content="${esc(url)}"/>
<meta property="og:site_name" content="Mploya"/>
<meta name="twitter:card" content="summary_large_image"/>
<meta name="twitter:title" content="${esc(title)}"/>
<meta name="twitter:description" content="${esc(desc)}"/>
<meta name="twitter:image" content="https://www.mploya.ai/img/og_cover.png"/>
<style>
  *{box-sizing:border-box;margin:0;padding:0}
  body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;
       background:#F6F8FB;color:#0F172A;padding:28px 16px;line-height:1.55}
  .wrap{max-width:520px;margin:0 auto}
  .card{background:#fff;border:1px solid #E9EEF4;border-radius:20px;
        box-shadow:0 10px 28px rgba(15,23,42,.07);overflow:hidden}
  .top{background:linear-gradient(135deg,#185FA5,#378ADD);padding:34px 24px;text-align:center;color:#fff}
  .logo{width:58px;height:58px;border-radius:17px;background:rgba(255,255,255,.18);
        font-size:31px;font-weight:800;display:flex;align-items:center;justify-content:center;margin:0 auto 14px}
  .top h1{font-size:21px;font-weight:800;line-height:1.35}
  .top p{font-size:14px;opacity:.92;margin-top:7px}
  .body{padding:24px}
  .lead{font-size:15px;color:#475569;text-align:center;margin-bottom:20px}
  .feat{display:flex;gap:12px;align-items:flex-start;padding:12px 0;border-top:1px solid #F1F5F9}
  .feat:first-of-type{border-top:none}
  .ico{width:38px;height:38px;border-radius:11px;background:#E6F1FB;color:#185FA5;flex:none;
       display:flex;align-items:center;justify-content:center;font-size:19px}
  .feat b{display:block;font-size:14.5px}
  .feat span{font-size:13px;color:#94A3B8}
  .cta{display:block;text-align:center;background:#185FA5;color:#fff;font-weight:700;font-size:16px;
       padding:16px;border-radius:14px;text-decoration:none;margin-top:22px}
  .code{text-align:center;font-size:12.5px;color:#94A3B8;margin-top:12px}
  .code b{color:#475569;letter-spacing:.5px}
  .foot{text-align:center;color:#94A3B8;font-size:12.5px;margin-top:18px}
  .foot a{color:#185FA5;text-decoration:none;font-weight:600}
  @media(prefers-color-scheme:dark){
    body{background:#0B1220;color:#E8EDF5}
    .card{background:#131C2B;border-color:#22304A;box-shadow:none}
    .lead{color:#B7C4D6}.feat{border-color:#22304A}.feat span,.code,.foot{color:#7C8CA5}
    .code b{color:#B7C4D6}.ico{background:#12314F;color:#9FC6F0}
  }
</style>
</head>
<body>
<div class="wrap">
  <div class="card">
    <div class="top">
      <div class="logo">m</div>
      <h1>${who ? `${who} te invitó a Mploya` : 'Te invitaron a Mploya'}</h1>
      <p>Mostrá quién sos en 60 segundos</p>
    </div>
    <div class="body">
      <p class="lead">En Mploya no mandás un CV: grabás un video-pitch y las empresas te descubren.</p>

      <div class="feat"><div class="ico">🎬</div>
        <div><b>Video-pitch de 60 segundos</b><span>Contá tu experiencia en cámara, sin currículum</span></div></div>
      <div class="feat"><div class="ico">⚡</div>
        <div><b>Match con IA</b><span>Te conectamos con las vacantes que encajan con vos</span></div></div>
      <div class="feat"><div class="ico">💬</div>
        <div><b>Hablá directo con quien contrata</b><span>Chat y videollamada dentro de la app</span></div></div>

      <a class="cta" href="${esc(appUrl)}">Crear mi cuenta gratis</a>
      <div class="code">Invitación de <b>${esc(code)}</b></div>
    </div>
  </div>
  <div class="foot">Ya tenés cuenta? <a href="/app/">Iniciá sesión</a> · <a href="/">Conocer Mploya</a></div>
</div>
<script>
  // Guardar el código por si se registra más tarde o vuelve por otro camino.
  try { localStorage.setItem('mploya_ref', ${JSON.stringify(code)}); } catch (e) {}
</script>
</body>
</html>`;
}

export default async function handler(req, res) {
  const code = String(req.query.code || '').trim().slice(0, 40);
  res.setHeader('Content-Type', 'text/html; charset=utf-8');

  if (!/^[A-Za-z0-9_-]{3,40}$/.test(code)) {
    res.status(404).send(render({ code: '—', referrer: null }));
    return;
  }

  let referrer = null;
  try {
    const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/get_referrer_name`, {
      method: 'POST',
      headers: {
        apikey: ANON_KEY,
        Authorization: `Bearer ${ANON_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ p_code: code }),
    });
    if (r.ok) {
      const v = await r.json();
      if (typeof v === 'string' && v.trim()) referrer = v.trim();
    }
  } catch { /* seguimos sin nombre: la página igual sirve */ }

  res.setHeader('Cache-Control', 'public, s-maxage=300, stale-while-revalidate=3600');
  res.status(200).send(render({ code, referrer }));
}
