// ============================================================================
// Vacante pública — mploya.ai/j/<id>
// ============================================================================
// `ShareService.jobUrl()` reparte links `mploya.ai/j/<id>` desde la app y esa
// ruta NO existía: daba 404 (mismo caso que /p/ y /invite/, detectados antes).
// Server-rendered para que WhatsApp/LinkedIn muestren la tarjeta de vista previa
// (esos crawlers no ejecutan JavaScript).
// ============================================================================

const SUPABASE_URL = 'https://qclipzefqndcefwwixdy.supabase.co';
const ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.' +
  'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFjbGlwemVmcW5kY2Vmd3dpeGR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ2MzQ1MjYsImV4cCI6MjA5MDIxMDUyNn0.' +
  'Pl6xdBAHP0yuSq91Dpv1SamSFkn4lTVsLOcu2EKdwkM';

const COLS = [
  'id', 'title', 'company_name', 'location', 'is_remote', 'salary_range', 'skills',
  'description', 'logo_url', 'created_at', 'modality', 'seniority', 'tags',
  'employment_type', 'experience_level', 'is_active',
].join(',');

const esc = (s) =>
  String(s ?? '').replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function toList(v) {
  if (!v) return [];
  if (Array.isArray(v)) return v.map(String).filter(Boolean);
  if (typeof v === 'string') {
    try { const p = JSON.parse(v); if (Array.isArray(p)) return p.map(String); } catch {}
    return v.split(',').map((s) => s.trim()).filter(Boolean);
  }
  return [];
}

function shell({ title, head = '', body }) {
  return `<!DOCTYPE html>
<html lang="es"><head>
<meta charset="utf-8"/><meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>${title}</title>${head}
<style>
  *{box-sizing:border-box;margin:0;padding:0}
  body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;
       background:#F6F8FB;color:#0F172A;padding:24px 16px;line-height:1.6}
  .wrap{max-width:620px;margin:0 auto}
  .card{background:#fff;border:1px solid #E9EEF4;border-radius:18px;overflow:hidden;
        box-shadow:0 8px 24px rgba(15,23,42,.06);margin-bottom:16px}
  .head{padding:24px 22px}
  .logo{width:56px;height:56px;border-radius:14px;background:#E6F1FB;color:#185FA5;font-size:24px;
        font-weight:800;display:flex;align-items:center;justify-content:center;object-fit:cover}
  h1{font-size:21px;font-weight:800;margin-top:14px}
  .emp{color:#475569;font-size:15px;font-weight:600;margin-top:3px}
  .meta{display:flex;gap:8px;flex-wrap:wrap;margin-top:14px}
  .pill{font-size:12.5px;font-weight:600;padding:6px 12px;border-radius:999px;
        background:#F1F5F9;color:#475569}
  .pill.sal{background:#E1F5EE;color:#0F6E56}
  .pill.rem{background:#E6F1FB;color:#0C447C}
  .sec{padding:20px 22px;border-top:1px solid #EDF1F5}
  .sec h2{font-size:12px;font-weight:700;letter-spacing:.6px;color:#9AA6B5;
          text-transform:uppercase;margin-bottom:10px}
  .sec p{font-size:14.5px;color:#475569;white-space:pre-wrap}
  .chips{display:flex;gap:7px;flex-wrap:wrap}
  .chip{background:#E6F1FB;color:#0C447C;font-size:12.5px;font-weight:600;
        padding:6px 12px;border-radius:999px}
  .cta{display:block;text-align:center;background:#185FA5;color:#fff;font-weight:700;
       font-size:15px;padding:15px;border-radius:14px;text-decoration:none}
  .foot{text-align:center;color:#94A3B8;font-size:12.5px;margin:18px 0 8px}
  .foot a{color:#185FA5;text-decoration:none;font-weight:600}
  .empty{padding:52px 24px;text-align:center}
  .empty .lg{width:56px;height:56px;border-radius:16px;background:#185FA5;color:#fff;font-size:30px;
        font-weight:800;display:flex;align-items:center;justify-content:center;margin:0 auto 16px}
  .empty p{color:#64748B;margin:8px 0 22px}
  @media(prefers-color-scheme:dark){
    body{background:#0B1220;color:#E8EDF5}
    .card{background:#131C2B;border-color:#22304A;box-shadow:none}
    .emp,.sec p{color:#B7C4D6}.foot{color:#7C8CA5}.sec{border-color:#22304A}
    .pill{background:#1B2740;color:#93A4BC}.chip{background:#12314F;color:#9FC6F0}
  }
</style></head>
<body><div class="wrap">${body}</div></body></html>`;
}

function notFound(res) {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.status(404).send(shell({
    title: 'Vacante no encontrada · Mploya',
    body: `<div class="card empty"><div class="lg">m</div>
      <h1>Esa búsqueda ya no está</h1>
      <p>Puede que se haya cerrado o que el enlace esté mal.</p>
      <a class="cta" href="/app/">Ver otras vacantes</a></div>`,
  }));
}

export default async function handler(req, res) {
  const id = String(req.query.id || '').trim();
  if (!/^[0-9a-fA-F-]{36}$/.test(id)) return notFound(res);

  let j;
  try {
    const r = await fetch(
      `${SUPABASE_URL}/rest/v1/jobs?id=eq.${encodeURIComponent(id)}&select=${COLS}&limit=1`,
      { headers: { apikey: ANON_KEY, Authorization: `Bearer ${ANON_KEY}` } },
    );
    if (!r.ok) return notFound(res);
    const rows = await r.json();
    j = Array.isArray(rows) ? rows[0] : null;
  } catch {
    return notFound(res);
  }
  if (!j) return notFound(res);

  const titulo = j.title || 'Vacante';
  const empresa = j.company_name || '';
  const lugar = j.location || (j.is_remote ? 'Remoto' : '');
  const skills = [...toList(j.skills), ...toList(j.tags)].slice(0, 12);
  const desc = (j.description || `${titulo}${empresa ? ' en ' + empresa : ''}`).slice(0, 180);
  const url = `https://www.mploya.ai/j/${j.id}`;
  const img = j.logo_url || 'https://www.mploya.ai/img/og_cover.png';

  const head = `
<meta name="description" content="${esc(desc)}"/>
<link rel="canonical" href="${esc(url)}"/>
<meta property="og:type" content="website"/>
<meta property="og:title" content="${esc(titulo)}${empresa ? ' · ' + esc(empresa) : ''}"/>
<meta property="og:description" content="${esc(desc)}"/>
<meta property="og:image" content="${esc(img)}"/>
<meta property="og:url" content="${esc(url)}"/>
<meta property="og:site_name" content="Mploya"/>
<meta name="twitter:card" content="summary_large_image"/>
<meta name="twitter:title" content="${esc(titulo)}"/>
<meta name="twitter:description" content="${esc(desc)}"/>
<meta name="twitter:image" content="${esc(img)}"/>`;

  const logo = j.logo_url
    ? `<img class="logo" src="${esc(j.logo_url)}" alt="${esc(empresa)}"/>`
    : `<div class="logo">${esc((empresa || titulo).trim().charAt(0).toUpperCase() || 'M')}</div>`;

  const pills = [
    lugar ? `<span class="pill">📍 ${esc(lugar)}</span>` : '',
    j.is_remote ? '<span class="pill rem">Remoto</span>' : '',
    j.modality ? `<span class="pill">${esc(j.modality)}</span>` : '',
    j.seniority || j.experience_level
      ? `<span class="pill">${esc(j.seniority || j.experience_level)}</span>` : '',
    j.employment_type ? `<span class="pill">${esc(j.employment_type)}</span>` : '',
    j.salary_range ? `<span class="pill sal">${esc(j.salary_range)}</span>` : '',
  ].join('');

  const cerrada = j.is_active === false
    ? '<div class="sec"><h2>Estado</h2><p>Esta búsqueda ya no está activa.</p></div>' : '';

  const body = `
<div class="card">
  <div class="head">
    ${logo}
    <h1>${esc(titulo)}</h1>
    ${empresa ? `<div class="emp">${esc(empresa)}</div>` : ''}
    ${pills ? `<div class="meta">${pills}</div>` : ''}
  </div>
  ${cerrada}
  ${j.description ? `<div class="sec"><h2>Descripción</h2><p>${esc(j.description)}</p></div>` : ''}
  ${skills.length ? `<div class="sec"><h2>Requisitos</h2>
    <div class="chips">${skills.map((s) => `<span class="chip">${esc(s)}</span>`).join('')}</div></div>` : ''}
</div>
<a class="cta" href="/app/">Postularme en Mploya</a>
<div class="foot">Publicado en <a href="/">Mploya</a> · video-pitches de 60 segundos</div>`;

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader('Cache-Control', 'public, s-maxage=300, stale-while-revalidate=3600');
  res.status(200).send(shell({ title: `${titulo}${empresa ? ' · ' + empresa : ''} · Mploya`, body, head }));
}
