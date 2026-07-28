// ============================================================================
// Perfil público de Mploya — mploya.ai/u/<id>
// ============================================================================
// Página server-rendered (función serverless de Vercel) para compartir un perfil
// por WhatsApp/LinkedIn sin necesidad de tener cuenta ni instalar la app.
//
// Se renderiza en el servidor a propósito: los crawlers que arman la tarjetita de
// vista previa (WhatsApp, LinkedIn, Telegram, X) NO ejecutan JavaScript, así que
// una página que cargue los datos por fetch no mostraría ni nombre ni foto.
//
// Solo lee columnas públicas. La anon key es pública (viaja en la app) y desde la
// migración 017 el rol `anon` únicamente puede ver la lista blanca de columnas.
// ============================================================================

const SUPABASE_URL = 'https://qclipzefqndcefwwixdy.supabase.co';
const ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.' +
  'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFjbGlwemVmcW5kY2Vmd3dpeGR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ2MzQ1MjYsImV4cCI6MjA5MDIxMDUyNn0.' +
  'Pl6xdBAHP0yuSq91Dpv1SamSFkn4lTVsLOcu2EKdwkM';

const COLUMNS = [
  'id', 'name', 'headline', 'about', 'avatar_url', 'banner_url', 'video_url',
  'skills', 'soft_skills', 'tags', 'company', 'location', 'city', 'account_type',
  'is_verified', 'is_premium', 'open_to_work', 'is_hiring', 'experience',
  'education', 'rating_stars', 'rating_count', 'connections', 'profile_views',
].join(',');

const esc = (s) =>
  String(s ?? '').replace(/[&<>"']/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

/** Lista de strings desde jsonb/text[]/string, tolerante al formato. */
function toList(v) {
  if (!v) return [];
  if (Array.isArray(v)) return v.map((x) => (typeof x === 'string' ? x : x?.name)).filter(Boolean);
  if (typeof v === 'string') {
    try {
      const p = JSON.parse(v);
      if (Array.isArray(p)) return toList(p);
    } catch { /* texto plano separado por comas */ }
    return v.split(',').map((s) => s.trim()).filter(Boolean);
  }
  return [];
}

function notFound(res) {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.status(404).send(page({
    title: 'Perfil no encontrado · Mploya',
    body: `<div class="card empty">
      <div class="logo">m</div>
      <h1>Ese perfil no existe</h1>
      <p>Puede que el enlace esté mal o que la persona haya dado de baja su cuenta.</p>
      <a class="cta" href="/">Ir a Mploya</a>
    </div>`,
  }));
}

function page({ title, body, head = '' }) {
  return `<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>${title}</title>
${head}
<style>
  *{box-sizing:border-box;margin:0;padding:0}
  body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;
       background:#F6F8FB;color:#0F172A;padding:24px 16px;line-height:1.5}
  .wrap{max-width:620px;margin:0 auto}
  .card{background:#fff;border:1px solid #E9EEF4;border-radius:18px;overflow:hidden;
        box-shadow:0 8px 24px rgba(15,23,42,.06);margin-bottom:16px}
  .cover{height:104px;background:linear-gradient(135deg,#185FA5,#378ADD)}
  .head{padding:0 22px 22px;margin-top:-44px}
  .avatar{width:88px;height:88px;border-radius:50%;border:4px solid #fff;object-fit:cover;
          background:#E6F1FB;display:flex;align-items:center;justify-content:center;
          font-size:34px;font-weight:700;color:#185FA5}
  h1{font-size:22px;font-weight:800;margin-top:12px;display:flex;align-items:center;gap:7px;flex-wrap:wrap}
  .verified{width:19px;height:19px;flex:none}
  .role{color:#64748B;font-size:15px;font-weight:600;margin-top:2px}
  .loc{color:#94A3B8;font-size:13.5px;margin-top:6px}
  .badges{display:flex;gap:8px;flex-wrap:wrap;margin-top:12px}
  .badge{font-size:12px;font-weight:700;padding:5px 11px;border-radius:999px}
  .b-work{background:#E1F5EE;color:#0F6E56}
  .b-hire{background:#E6F1FB;color:#0C447C}
  .b-prem{background:#FAEEDA;color:#854F0B}
  .stats{display:flex;border-top:1px solid #EDF1F5}
  .stat{flex:1;padding:14px 8px;text-align:center}
  .stat+.stat{border-left:1px solid #EDF1F5}
  .stat b{display:block;font-size:17px}
  .stat span{font-size:12px;color:#94A3B8}
  .sec{padding:20px 22px}
  .sec h2{font-size:12px;font-weight:700;letter-spacing:.6px;color:#9AA6B5;
          text-transform:uppercase;margin-bottom:10px}
  .sec p{font-size:14.5px;color:#475569}
  .chips{display:flex;gap:7px;flex-wrap:wrap}
  .chip{background:#E6F1FB;color:#0C447C;font-size:12.5px;font-weight:600;
        padding:6px 12px;border-radius:999px}
  video{width:100%;border-radius:14px;display:block;background:#000}
  .item{padding:11px 0;border-top:1px solid #F1F5F9}
  .item:first-of-type{border-top:none}
  .item b{font-size:14.5px}
  .item span{display:block;font-size:13px;color:#94A3B8}
  .cta{display:block;text-align:center;background:#185FA5;color:#fff;font-weight:700;
       font-size:15px;padding:15px;border-radius:14px;text-decoration:none}
  .foot{text-align:center;color:#94A3B8;font-size:12.5px;margin:18px 0 8px}
  .foot a{color:#185FA5;text-decoration:none;font-weight:600}
  .empty{padding:52px 24px;text-align:center}
  .empty .logo{width:56px;height:56px;border-radius:16px;background:#185FA5;color:#fff;
        font-size:30px;font-weight:800;display:flex;align-items:center;justify-content:center;margin:0 auto 16px}
  .empty h1{justify-content:center}.empty p{color:#64748B;margin:8px 0 22px}
  @media(prefers-color-scheme:dark){
    body{background:#0B1220;color:#E8EDF5}
    .card{background:#131C2B;border-color:#22304A;box-shadow:none}
    .role{color:#93A4BC}.sec p{color:#B7C4D6}.item span,.loc,.stat span,.foot{color:#7C8CA5}
    .stats,.item,.sec h2{border-color:#22304A}
    .chip{background:#12314F;color:#9FC6F0}
  }
</style>
</head>
<body><div class="wrap">${body}</div></body>
</html>`;
}

export default async function handler(req, res) {
  const id = String(req.query.id || '').trim();
  if (!/^[0-9a-fA-F-]{36}$/.test(id)) return notFound(res);

  let u;
  try {
    const r = await fetch(
      `${SUPABASE_URL}/rest/v1/users?id=eq.${encodeURIComponent(id)}&select=${COLUMNS}&limit=1`,
      { headers: { apikey: ANON_KEY, Authorization: `Bearer ${ANON_KEY}` } },
    );
    if (!r.ok) return notFound(res);
    const rows = await r.json();
    u = Array.isArray(rows) ? rows[0] : null;
  } catch {
    return notFound(res);
  }
  if (!u) return notFound(res);

  const name = u.name || 'Perfil';
  const role = u.headline || (u.account_type === 'empresa' ? 'Empresa' : '');
  const place = u.location || u.city || '';
  const skills = [...toList(u.skills), ...toList(u.tags)].slice(0, 12);
  const desc = (u.about || `${role}${place ? ' · ' + place : ''}`).slice(0, 180);
  // Canónica = /p/<id> porque es la que ya genera ShareService en la app
  // (los links compartidos antes de esta página daban 404; ahora funcionan).
  const url = `https://www.mploya.ai/p/${u.id}`;
  const img = u.avatar_url || u.banner_url || 'https://www.mploya.ai/img/og_cover.png';

  // Meta tags para la tarjeta de vista previa (WhatsApp, LinkedIn, X, Telegram).
  const head = `
<meta name="description" content="${esc(desc)}"/>
<link rel="canonical" href="${esc(url)}"/>
<meta property="og:type" content="profile"/>
<meta property="og:title" content="${esc(name)}${role ? ' · ' + esc(role) : ''}"/>
<meta property="og:description" content="${esc(desc)}"/>
<meta property="og:image" content="${esc(img)}"/>
<meta property="og:url" content="${esc(url)}"/>
<meta property="og:site_name" content="Mploya"/>
<meta name="twitter:card" content="summary_large_image"/>
<meta name="twitter:title" content="${esc(name)}"/>
<meta name="twitter:description" content="${esc(desc)}"/>
<meta name="twitter:image" content="${esc(img)}"/>`;

  const initial = esc(name.trim().charAt(0).toUpperCase() || '?');
  const avatar = u.avatar_url
    ? `<img class="avatar" src="${esc(u.avatar_url)}" alt="${esc(name)}"/>`
    : `<div class="avatar">${initial}</div>`;

  const badges = [
    u.open_to_work ? '<span class="badge b-work">Busca trabajo</span>' : '',
    u.is_hiring ? '<span class="badge b-hire">Está contratando</span>' : '',
    u.is_premium ? '<span class="badge b-prem">Premium</span>' : '',
  ].join('');

  const verified = u.is_verified
    ? '<svg class="verified" viewBox="0 0 24 24" fill="#185FA5"><path d="M12 2l2.4 1.8 3-.3 1 2.8 2.6 1.5-.9 2.9.9 2.9-2.6 1.5-1 2.8-3-.3L12 22l-2.4-1.8-3 .3-1-2.8L3 16.2l.9-2.9L3 10.4l2.6-1.5 1-2.8 3 .3z"/><path d="M10.6 15.4l-3-3 1.4-1.4 1.6 1.6 4-4L16 10z" fill="#fff"/></svg>'
    : '';

  const section = (t, inner) => (inner ? `<div class="sec"><h2>${t}</h2>${inner}</div>` : '');

  const listOf = (v, tKey, sKey) =>
    (Array.isArray(v) ? v : (() => { try { return JSON.parse(v || '[]'); } catch { return []; } })())
      .slice(0, 4)
      .map((e) => `<div class="item"><b>${esc(e?.[tKey] ?? e?.title ?? '')}</b>
        <span>${esc(e?.[sKey] ?? e?.company ?? e?.school ?? '')}</span></div>`)
      .join('');

  const body = `
<div class="card">
  <div class="cover"></div>
  <div class="head">
    ${avatar}
    <h1>${esc(name)}${verified}</h1>
    ${role ? `<div class="role">${esc(role)}</div>` : ''}
    ${place ? `<div class="loc">📍 ${esc(place)}</div>` : ''}
    ${badges ? `<div class="badges">${badges}</div>` : ''}
  </div>
  <div class="stats">
    <div class="stat"><b>${Number(u.profile_views) || 0}</b><span>Vistas</span></div>
    <div class="stat"><b>${Number(u.connections) || 0}</b><span>Conexiones</span></div>
    <div class="stat"><b>${u.rating_stars ? Number(u.rating_stars).toFixed(1) : '—'}</b><span>Rating</span></div>
  </div>
</div>

${u.video_url ? `<div class="card"><div class="sec"><h2>Video pitch</h2>
  <video controls preload="metadata" playsinline src="${esc(u.video_url)}"></video></div></div>` : ''}

${u.about ? `<div class="card">${section('Sobre mí', `<p>${esc(u.about)}</p>`)}</div>` : ''}

${skills.length ? `<div class="card">${section('Habilidades',
  `<div class="chips">${skills.map((s) => `<span class="chip">${esc(s)}</span>`).join('')}</div>`)}</div>` : ''}

${listOf(u.experience, 'title', 'company') ? `<div class="card">${section('Experiencia', listOf(u.experience, 'title', 'company'))}</div>` : ''}
${listOf(u.education, 'title', 'school') ? `<div class="card">${section('Educación', listOf(u.education, 'title', 'school'))}</div>` : ''}

<a class="cta" href="/app/">Ver este perfil en Mploya</a>
<div class="foot">Perfil público de <a href="/">Mploya</a> · creá el tuyo gratis</div>`;

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  // Cache en CDN 5 min; sirve la copia vieja hasta 1h mientras revalida.
  res.setHeader('Cache-Control', 'public, s-maxage=300, stale-while-revalidate=3600');
  res.status(200).send(page({ title: `${name}${role ? ' · ' + role : ''} · Mploya`, body, head }));
}
