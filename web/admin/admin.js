/* ═══════════════════════════════════════════════════════════════════════════ */
/* Mploya Admin Panel — Complete Logic + Payments                            */
/* ═══════════════════════════════════════════════════════════════════════════ */

const SUPABASE_URL = 'https://qclipzefqndcefwwixdy.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFjbGlwemVmcW5kY2Vmd3dpeGR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ2MzQ1MjYsImV4cCI6MjA5MDIxMDUyNn0.Pl6xdBAHP0yuSq91Dpv1SamSFkn4lTVsLOcu2EKdwkM';

const ADMIN_EMAILS = ['joseloperab@gmail.com'];
const ADMIN_SECRET = 'mploya2026admin';

let supabase, supabaseReady = false;
let allUsers = [], allJobs = [], allPayments = [];
let currentUserPage = 0;
const PAGE_SIZE = 25;

// ═══════════════════════════════════════════════════════════════════════════
// INIT
// ═══════════════════════════════════════════════════════════════════════════

document.addEventListener('DOMContentLoaded', () => {
  try {
    if (window.supabase?.createClient) {
      supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
      supabaseReady = true;
      checkSession();
    }
  } catch (e) { console.error('Supabase init:', e); }

  updateClock();
  setInterval(updateClock, 30000);
  const form = document.getElementById('login-form');
  if (form) form.onsubmit = handleLogin;
});

function updateClock() {
  const el = document.getElementById('header-time');
  if (el) el.textContent = new Date().toLocaleString('es-AR', { weekday:'short', day:'numeric', month:'short', hour:'2-digit', minute:'2-digit' });
}

// ═══════════════════════════════════════════════════════════════════════════
// AUTH
// ═══════════════════════════════════════════════════════════════════════════

async function checkSession() {
  try {
    const { data:{ session } } = await supabase.auth.getSession();
    if (session && ADMIN_EMAILS.includes(session.user.email)) showPanel(session.user);
  } catch(e) {}
}

async function handleLogin(e) {
  e.preventDefault(); e.stopPropagation();
  const email = document.getElementById('login-email').value.trim();
  const password = document.getElementById('login-password').value;
  const err = document.getElementById('login-error');
  const btn = document.getElementById('login-btn-text');
  const spin = document.getElementById('login-spinner');

  if (password === ADMIN_SECRET) {
    if (supabaseReady) try { await supabase.auth.signInWithPassword({ email, password: ADMIN_SECRET }); } catch(e) {}
    showPanel({ email, id:'admin' });
    return false;
  }

  if (!ADMIN_EMAILS.includes(email)) { err.textContent='🔒 Acceso denegado'; err.classList.remove('hidden'); return false; }
  if (!supabaseReady) { err.textContent='⚠️ Supabase no cargó. Usá código secreto.'; err.classList.remove('hidden'); return false; }

  btn.textContent='Verificando...'; spin.classList.remove('hidden'); err.classList.add('hidden');
  try {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) throw error;
    showPanel(data.user);
  } catch(e) {
    err.textContent=`Error: ${e.message}`; err.classList.remove('hidden');
    btn.textContent='Acceder al Panel'; spin.classList.add('hidden');
  }
  return false;
}

function showPanel(user) {
  document.getElementById('login-screen').classList.add('hidden');
  document.getElementById('admin-panel').classList.remove('hidden');
  const email = user.email||'admin';
  document.getElementById('admin-name').textContent = email.split('@')[0];
  document.getElementById('admin-avatar').textContent = email[0].toUpperCase();
  loadDashboard();
}

async function logout() {
  if (supabaseReady) try { await supabase.auth.signOut(); } catch(e) {}
  location.reload();
}

// ═══════════════════════════════════════════════════════════════════════════
// TABS
// ═══════════════════════════════════════════════════════════════════════════

const tabs = {
  dashboard:     { title:'Dashboard',       sub:'Resumen general de la plataforma',        fn:loadDashboard },
  users:         { title:'Usuarios',        sub:'Gestión de todos los usuarios',           fn:loadUsers },
  jobs:          { title:'Vacantes',        sub:'Ofertas de empleo',                       fn:loadJobs },
  payments:      { title:'Pagos y Suscripciones', sub:'Revenue, trials y churn',           fn:loadPayments },
  verifications: { title:'Verificaciones',  sub:'Verificación de empresas',                fn:loadVerifications },
  challenges:    { title:'Challenges',      sub:'Pitch challenges semanales',              fn:loadChallenges },
  ghost:         { title:'Ghost Apply',     sub:'Aplicaciones confidenciales',             fn:loadGhostApps },
  moderation:    { title:'Moderación',      sub:'Reportes y contenido flaggeado',          fn:loadModeration },
  analytics:     { title:'Analytics',       sub:'Métricas de crecimiento',                 fn:loadAnalytics },
  config:        { title:'Configuración',   sub:'Ajustes del panel de administración',     fn:loadConfig },
};

function switchTab(key) {
  document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.nav-btn').forEach(n => n.classList.remove('active'));
  document.getElementById(`tab-${key}`).classList.add('active');
  document.querySelector(`[data-tab="${key}"]`).classList.add('active');
  document.getElementById('page-title').textContent = tabs[key].title;
  document.getElementById('page-subtitle').textContent = tabs[key].sub;
  tabs[key].fn();
}

// ═══════════════════════════════════════════════════════════════════════════
// DASHBOARD
// ═══════════════════════════════════════════════════════════════════════════

async function loadDashboard() {
  if (!supabaseReady) return;
  try {
    const [uR,jR,pR,mR,gR,cR] = await Promise.all([
      supabase.from('users').select('id',{count:'exact',head:true}),
      supabase.from('jobs').select('id',{count:'exact',head:true}).eq('is_active',true),
      supabase.from('users').select('id',{count:'exact',head:true}).eq('is_premium',true),
      supabase.from('messages').select('id',{count:'exact',head:true}).gte('created_at',new Date(Date.now()-864e5).toISOString()),
      supabase.from('ghost_applications').select('id',{count:'exact',head:true}),
      supabase.from('connections').select('id',{count:'exact',head:true}),
    ]);
    anim('stat-users',uR.count||0);
    anim('stat-jobs',jR.count||0);
    anim('stat-premium',pR.count||0);
    const premCount = pR.count||0;
    document.getElementById('stat-revenue').textContent = `$${(premCount * 9.99).toFixed(0)}`;
    anim('stat-messages',mR.count||0);
    anim('stat-ghost',gR.count||0);

    // Recent users
    const { data: ru } = await supabase.from('users').select('name,email,avatar_url,account_type,created_at').order('created_at',{ascending:false}).limit(8);
    document.getElementById('recent-users').innerHTML = (ru||[]).map(u => `
      <div class="activity">
        <div class="user-cell-avatar" style="width:30px;height:30px;font-size:11px">${u.avatar_url?`<img src="${u.avatar_url}">`:(u.name?.[0]||'?')}</div>
        <div style="flex:1"><div class="activity-text"><strong>${esc(u.name||'Sin nombre')}</strong></div><div class="activity-time">${esc(u.account_type||'abierto')} · ${ago(u.created_at)}</div></div>
      </div>
    `).join('')||'<div class="empty"><p>Sin registros</p></div>';

    // Recent payments (premium users = paying users)
    const { data: pu } = await supabase.from('users').select('name,email,is_premium,premium_since,premium_until,created_at').order('premium_since',{ascending:false,nullsFirst:false}).limit(8);
    document.getElementById('recent-payments').innerHTML = (pu||[]).filter(u=>u.is_premium||u.premium_since).map(u => {
      const active = u.is_premium;
      const until = u.premium_until ? new Date(u.premium_until) : null;
      const expired = until && until < new Date();
      const status = expired ? 'expired' : active ? 'active' : 'cancelled';
      return `
        <div class="activity">
          <div class="activity-dot" style="background:${status==='active'?'var(--green)':status==='expired'?'var(--rose)':'var(--text-3)'}"></div>
          <div style="flex:1"><div class="activity-text"><strong>${esc(u.name||u.email||'')}</strong></div><div class="activity-time">${status==='active'?'✅ Activo':status==='expired'?'❌ Expirado':'🚫 Cancelado'} · desde ${ago(u.premium_since)}</div></div>
          <span class="badge badge-${status}">${status==='active'?'Premium':status==='expired'?'Expirado':'Cancelado'}</span>
        </div>
      `;
    }).join('')||'<div class="empty"><p>Sin pagos registrados</p></div>';
  } catch(e) { console.error('Dashboard:',e); }
}

// ═══════════════════════════════════════════════════════════════════════════
// USERS
// ═══════════════════════════════════════════════════════════════════════════

async function loadUsers() {
  const { data } = await supabase.from('users').select('*').order('created_at',{ascending:false}).limit(500);
  allUsers = data||[];
  renderUsers(allUsers);
}
function renderUsers(list) {
  const start = currentUserPage*PAGE_SIZE;
  const page = list.slice(start,start+PAGE_SIZE);
  document.getElementById('users-tbody').innerHTML = page.map(u => `<tr>
    <td><div class="user-cell"><div class="user-cell-avatar">${u.avatar_url?`<img src="${u.avatar_url}">`:(u.name?.[0]||'?')}</div><div><div class="user-cell-name">${esc(u.name||'Sin nombre')}</div><div class="user-cell-sub">${esc(u.email||u.id?.substring(0,8))}</div></div></div></td>
    <td><span class="badge badge-${u.account_type==='empresa'?'empresa':u.account_type==='confidencial'?'confidential':'open'}">${esc(u.account_type||'abierto')}</span></td>
    <td><span class="badge ${u.is_premium?'badge-premium':'badge-free'}">${u.is_premium?'⭐ Premium':'Free'}</span></td>
    <td>${(u.tags||[]).slice(0,3).map(t=>`<span class="tag">${esc(t)}</span>`).join('')}</td>
    <td style="font-size:12px;color:var(--text-3)">${ago(u.created_at)}</td>
    <td><button class="btn-action" onclick="viewUser('${u.id}')">Ver</button><button class="btn-action" onclick="togglePremium('${u.id}',${!u.is_premium})">${u.is_premium?'⬇':'⬆'}</button><button class="btn-action" style="color:var(--rose)" onclick="deleteUser('${u.id}')">🗑</button></td>
  </tr>`).join('');
  const pages = Math.ceil(list.length/PAGE_SIZE);
  document.getElementById('users-pagination').innerHTML = Array.from({length:pages},(_,i)=>`<button class="pg-btn ${i===currentUserPage?'active':''}" onclick="goToUserPage(${i})">${i+1}</button>`).join('');
}
function goToUserPage(p) { currentUserPage=p; renderUsers(allUsers); }
function searchUsers() { const q=document.getElementById('user-search').value.toLowerCase(); currentUserPage=0; renderUsers(allUsers.filter(u=>(u.name||'').toLowerCase().includes(q)||(u.email||'').toLowerCase().includes(q)||(u.headline||'').toLowerCase().includes(q))); }
function filterUsers() { const t=document.getElementById('user-type-filter').value, p=document.getElementById('user-premium-filter').value; let f=[...allUsers]; if(t)f=f.filter(u=>u.account_type===t); if(p==='true')f=f.filter(u=>u.is_premium); if(p==='false')f=f.filter(u=>!u.is_premium); currentUserPage=0; renderUsers(f); }

async function viewUser(id) {
  const u = allUsers.find(x=>x.id===id); if(!u) return;
  document.getElementById('user-modal-name').textContent = u.name||'Usuario';
  document.getElementById('user-modal-body').innerHTML = `
    <div style="text-align:center;margin-bottom:16px"><div class="user-cell-avatar" style="width:64px;height:64px;font-size:24px;margin:0 auto 10px">${u.avatar_url?`<img src="${u.avatar_url}">`:(u.name?.[0]||'?')}</div><h3 style="font-weight:800">${esc(u.name||'')}</h3><p style="color:var(--text-2);font-size:13px">${esc(u.headline||'')}</p></div>
    <div class="detail-row"><span class="detail-label">ID</span><span class="detail-value" style="font-size:10px">${u.id}</span></div>
    <div class="detail-row"><span class="detail-label">Email</span><span class="detail-value">${esc(u.email||'N/A')}</span></div>
    <div class="detail-row"><span class="detail-label">Tipo</span><span class="detail-value">${esc(u.account_type||'abierto')}</span></div>
    <div class="detail-row"><span class="detail-label">Premium</span><span class="detail-value">${u.is_premium?'⭐ Sí':'No'}</span></div>
    <div class="detail-row"><span class="detail-label">Premium desde</span><span class="detail-value">${u.premium_since?new Date(u.premium_since).toLocaleDateString('es-AR'):'—'}</span></div>
    <div class="detail-row"><span class="detail-label">Premium hasta</span><span class="detail-value">${u.premium_until?new Date(u.premium_until).toLocaleDateString('es-AR'):'—'}</span></div>
    <div class="detail-row"><span class="detail-label">Tags</span><span class="detail-value">${(u.tags||[]).join(', ')||'—'}</span></div>
    <div class="detail-row"><span class="detail-label">Ubicación</span><span class="detail-value">${esc(u.location||'—')}</span></div>
    <div class="detail-row"><span class="detail-label">Empresa</span><span class="detail-value">${esc(u.company||'—')}</span></div>
    <div class="detail-row"><span class="detail-label">Video</span><span class="detail-value">${u.video_url?'🎥 Sí':'❌ No'}</span></div>
    <div class="detail-row"><span class="detail-label">Registrado</span><span class="detail-value">${new Date(u.created_at).toLocaleDateString('es-AR')}</span></div>
  `;
  document.getElementById('user-modal-actions').innerHTML = `
    <button class="btn-ghost" onclick="closeModal('user-modal')">Cerrar</button>
    <button class="${u.is_premium?'btn-danger':'btn-success'}" onclick="togglePremium('${u.id}',${!u.is_premium});closeModal('user-modal')">${u.is_premium?'Quitar Premium':'Dar Premium'}</button>
    <button class="btn-danger" onclick="deleteUser('${u.id}');closeModal('user-modal')">Eliminar</button>`;
  document.getElementById('user-modal').classList.remove('hidden');
}
async function togglePremium(id,make) {
  const now = new Date().toISOString();
  const oneMonth = new Date(Date.now()+30*864e5).toISOString();
  await supabase.from('users').update({ is_premium:make, ...(make?{premium_since:now,premium_until:oneMonth}:{}) }).eq('id',id);
  const u=allUsers.find(x=>x.id===id); if(u){u.is_premium=make; if(make){u.premium_since=now;u.premium_until=oneMonth;}}
  renderUsers(allUsers); toast(make?'⭐ Premium activado':'⬇ Premium removido');
}
async function deleteUser(id) { if(!confirm('¿Eliminar usuario?'))return; await supabase.from('users').delete().eq('id',id); allUsers=allUsers.filter(u=>u.id!==id); renderUsers(allUsers); toast('🗑 Eliminado'); }

// ═══════════════════════════════════════════════════════════════════════════
// JOBS
// ═══════════════════════════════════════════════════════════════════════════

async function loadJobs() {
  const { data } = await supabase.from('jobs').select('*').order('created_at',{ascending:false}).limit(200);
  allJobs=data||[];
  renderJobs(allJobs);
}
function renderJobs(list) {
  document.getElementById('jobs-tbody').innerHTML = list.map(j=>`<tr>
    <td><strong>${esc(j.title||'Sin título')}</strong></td><td>${esc(j.company_name||'—')}</td><td>${esc(j.location||'')}</td>
    <td><span class="badge badge-${j.modality==='remote'?'approved':'pending'}">${esc(j.modality||'—')}</span></td>
    <td><span class="badge ${j.is_active?'badge-active':'badge-inactive'}">${j.is_active?'Activa':'Inactiva'}</span></td>
    <td style="font-size:12px;color:var(--text-3)">${ago(j.created_at)}</td>
    <td><button class="btn-action" onclick="toggleJob('${j.id}',${!j.is_active})">${j.is_active?'⏸':'▶'}</button><button class="btn-action" style="color:var(--rose)" onclick="delJob('${j.id}')">🗑</button></td>
  </tr>`).join('')||'<tr><td colspan="7" class="empty">Sin vacantes</td></tr>';
}
function searchJobs() { const q=document.getElementById('job-search').value.toLowerCase(); renderJobs(allJobs.filter(j=>(j.title||'').toLowerCase().includes(q))); }
async function toggleJob(id,a) { await supabase.from('jobs').update({is_active:a}).eq('id',id); loadJobs(); toast(a?'▶ Activada':'⏸ Desactivada'); }
async function delJob(id) { if(!confirm('¿Eliminar?'))return; await supabase.from('jobs').delete().eq('id',id); loadJobs(); toast('🗑 Eliminada'); }

// ═══════════════════════════════════════════════════════════════════════════
// PAYMENTS
// ═══════════════════════════════════════════════════════════════════════════

async function loadPayments() {
  const { data } = await supabase.from('users').select('id,name,email,avatar_url,is_premium,premium_since,premium_until,payment_method,created_at').order('premium_since',{ascending:false,nullsFirst:false}).limit(500);
  allPayments = (data||[]).map(u => {
    const until = u.premium_until ? new Date(u.premium_until) : null;
    const since = u.premium_since ? new Date(u.premium_since) : null;
    let status = 'free';
    if (u.is_premium && until && until > new Date()) status = 'active';
    else if (u.is_premium && (!until || until > new Date())) status = 'active';
    else if (since && until && until < new Date()) status = 'expired';
    else if (since && !u.is_premium) status = 'cancelled';
    // Detect trials (premium < 7 days)
    if (status==='active' && since && (Date.now()-since.getTime()) < 7*864e5) status = 'trial';
    return { ...u, status };
  });

  const active = allPayments.filter(p=>p.status==='active').length;
  const trial = allPayments.filter(p=>p.status==='trial').length;
  const expired = allPayments.filter(p=>p.status==='expired').length;
  const total = active + trial;
  const churn = total > 0 ? ((expired / (total+expired)) * 100).toFixed(1) : '0';

  document.getElementById('pay-revenue').textContent = `$${((active+trial)*9.99).toFixed(0)}`;
  anim('pay-active', active);
  anim('pay-trial', trial);
  document.getElementById('pay-churn').textContent = `${churn}%`;

  renderPayments(allPayments.filter(p=>p.status!=='free'));
}

function renderPayments(list) {
  document.getElementById('payments-tbody').innerHTML = list.map(u => `<tr>
    <td><div class="user-cell"><div class="user-cell-avatar">${u.avatar_url?`<img src="${u.avatar_url}">`:(u.name?.[0]||'?')}</div><div><div class="user-cell-name">${esc(u.name||'')}</div><div class="user-cell-sub">${esc(u.email||'')}</div></div></div></td>
    <td><span class="badge badge-premium">Premium</span></td>
    <td><span class="badge badge-${u.status}">${u.status==='active'?'✅ Activo':u.status==='trial'?'⏳ Trial':u.status==='expired'?'❌ Expirado':'🚫 Cancelado'}</span></td>
    <td style="font-size:12px">${u.premium_since?new Date(u.premium_since).toLocaleDateString('es-AR'):'—'}</td>
    <td style="font-size:12px">${u.premium_until?new Date(u.premium_until).toLocaleDateString('es-AR'):'—'}</td>
    <td style="font-size:12px">${esc(u.payment_method||'Supabase')}</td>
    <td>
      <button class="btn-action" onclick="viewUser('${u.id}')">Ver</button>
      ${u.status==='active'||u.status==='trial'?`<button class="btn-action" style="color:var(--rose)" onclick="togglePremium('${u.id}',false)">Cancelar</button>`:`<button class="btn-action" style="color:var(--green)" onclick="togglePremium('${u.id}',true)">Reactivar</button>`}
    </td>
  </tr>`).join('')||'<tr><td colspan="7" class="empty">Sin suscripciones</td></tr>';
}

function filterPayments() {
  const f = document.getElementById('pay-status-filter').value;
  const list = allPayments.filter(p=>p.status!=='free');
  renderPayments(f ? list.filter(p=>p.status===f) : list);
}

function exportPayments() {
  const rows = allPayments.filter(p=>p.status!=='free');
  const csv = 'Nombre,Email,Estado,Desde,Hasta,Método\n' + rows.map(u =>
    `"${u.name||''}","${u.email||''}","${u.status}","${u.premium_since||''}","${u.premium_until||''}","${u.payment_method||'Supabase'}"`
  ).join('\n');
  const blob = new Blob([csv],{type:'text/csv'});
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `mploya_payments_${new Date().toISOString().split('T')[0]}.csv`;
  a.click();
  toast('📥 CSV exportado');
}

// ═══════════════════════════════════════════════════════════════════════════
// VERIFICATIONS
// ═══════════════════════════════════════════════════════════════════════════

let allVerifs = [];
async function loadVerifications() {
  const { data } = await supabase.from('company_verifications').select('*').order('created_at',{ascending:false});
  allVerifs = data||[];
  renderVerifs(allVerifs);
}
function renderVerifs(list) {
  document.getElementById('verifications-grid').innerHTML = list.map(v => `
    <div class="v-card"><div class="v-head"><div><div class="v-company">${esc(v.company_name||'Empresa')}</div><div class="v-meta">Nivel: ${esc(v.level)} · ${ago(v.created_at)}</div></div><span class="badge badge-${v.status}">${esc(v.status)}</span></div>
    ${v.notes?`<div class="v-detail">📝 ${esc(v.notes)}</div>`:''}
    ${v.status==='pending'?`<div class="v-actions"><button class="btn-success" onclick="reviewVerif('${v.id}','approved')">✅ Aprobar</button><button class="btn-danger" onclick="reviewVerif('${v.id}','rejected')">❌ Rechazar</button></div>`:''}</div>
  `).join('')||'<div class="empty"><div class="empty-icon">✅</div><p class="empty-text">Sin verificaciones</p></div>';
}
function filterVerifications(f,btn) { document.querySelectorAll('.chip').forEach(c=>c.classList.remove('active')); btn.classList.add('active'); renderVerifs(f==='all'?allVerifs:allVerifs.filter(v=>v.status===f)); }
async function reviewVerif(id,status) { await supabase.from('company_verifications').update({status,reviewed_at:new Date().toISOString()}).eq('id',id); loadVerifications(); toast(status==='approved'?'✅ Aprobada':'❌ Rechazada'); }

// ═══════════════════════════════════════════════════════════════════════════
// CHALLENGES
// ═══════════════════════════════════════════════════════════════════════════

async function loadChallenges() {
  const { data } = await supabase.from('pitch_challenges').select('*').order('created_at',{ascending:false});
  document.getElementById('challenges-grid').innerHTML = (data||[]).map(c => `
    <div class="ch-card"><div class="ch-emoji">${c.emoji||'🎯'}</div><div class="ch-title">${esc(c.title)}</div><div class="ch-desc">${esc(c.description||'')}</div>
    <div class="ch-meta"><span>👥 ${c.participant_count||0}</span><span>⏱ ${c.max_duration_seconds}s</span><span class="badge ${c.is_active?'badge-active':'badge-inactive'}">${c.is_active?'Activo':'Fin'}</span></div>
    <div style="margin-top:8px;font-size:11px;color:var(--text-3)">${new Date(c.starts_at).toLocaleDateString('es-AR')} → ${new Date(c.ends_at).toLocaleDateString('es-AR')}</div>
    <div class="v-actions"><button class="btn-action" onclick="togCh('${c.id}',${!c.is_active})">${c.is_active?'⏸ Pausar':'▶ Activar'}</button><button class="btn-action" style="color:var(--rose)" onclick="delCh('${c.id}')">🗑</button></div></div>
  `).join('')||'<div class="empty"><div class="empty-icon">🏆</div><p class="empty-text">Sin challenges</p></div>';
}
function showCreateChallenge() { const n=new Date(),w=new Date(Date.now()+7*864e5); document.getElementById('ch-start').value=n.toISOString().slice(0,16); document.getElementById('ch-end').value=w.toISOString().slice(0,16); document.getElementById('challenge-modal').classList.remove('hidden'); }
async function createChallenge(e) { e.preventDefault(); await supabase.from('pitch_challenges').insert({title:document.getElementById('ch-title').value,description:document.getElementById('ch-desc').value,emoji:document.getElementById('ch-emoji').value||'🎯',max_duration_seconds:parseInt(document.getElementById('ch-duration').value)||30,starts_at:new Date(document.getElementById('ch-start').value).toISOString(),ends_at:new Date(document.getElementById('ch-end').value).toISOString(),is_active:true}); closeModal('challenge-modal'); loadChallenges(); toast('🏆 Creado'); }
async function togCh(id,a) { await supabase.from('pitch_challenges').update({is_active:a}).eq('id',id); loadChallenges(); }
async function delCh(id) { if(!confirm('¿Eliminar?'))return; await supabase.from('pitch_challenges').delete().eq('id',id); loadChallenges(); toast('🗑 Eliminado'); }

// ═══════════════════════════════════════════════════════════════════════════
// GHOST
// ═══════════════════════════════════════════════════════════════════════════

async function loadGhostApps() {
  const { data } = await supabase.from('ghost_applications').select('*').order('created_at',{ascending:false}).limit(100);
  document.getElementById('ghost-tbody').innerHTML = (data||[]).map(g => `<tr>
    <td style="font-size:11px;color:var(--text-3)">${g.candidate_id?.substring(0,8)}...</td>
    <td>${esc(g.blind_headline||'—')}</td>
    <td><strong style="color:var(--indigo)">${g.match_score||0}%</strong></td>
    <td><span class="badge badge-${g.status==='pending'?'pending':g.status==='unlocked'?'approved':'free'}">${esc(g.status)}</span></td>
    <td><span class="badge ${g.is_unlocked?'badge-active':'badge-free'}">${g.is_unlocked?'🔓 Sí':'🔒 No'}</span></td>
    <td style="font-size:12px;color:var(--text-3)">${ago(g.created_at)}</td>
  </tr>`).join('')||'<tr><td colspan="6" class="empty">Sin ghost apps</td></tr>';
}

// ═══════════════════════════════════════════════════════════════════════════
// MODERATION
// ═══════════════════════════════════════════════════════════════════════════

async function loadModeration() {
  const { data: reps } = await supabase.from('content_reports').select('*').order('created_at',{ascending:false}).limit(30);
  document.getElementById('reports-list').innerHTML = (reps||[]).map(r => `
    <div class="activity"><div class="activity-dot" style="background:var(--rose)"></div><div style="flex:1"><div class="activity-text"><strong>${esc(r.reason||r.type||'Reporte')}</strong></div><div class="activity-text">${esc(r.description||'')}</div><div class="activity-time">${ago(r.created_at)}</div></div><button class="btn-action" onclick="resolveRep('${r.id}')">✅</button></div>
  `).join('')||'<div class="empty"><div class="empty-icon">🛡️</div><p class="empty-text">Sin reportes</p></div>';

  const { data: bl } = await supabase.from('user_blocks').select('*').order('created_at',{ascending:false}).limit(20);
  document.getElementById('blocked-list').innerHTML = (bl||[]).map(b => `
    <div class="activity"><div class="activity-dot" style="background:var(--amber)"></div><div><div class="activity-text">${b.blocker_id?.substring(0,8)} → ${b.blocked_id?.substring(0,8)}</div><div class="activity-time">${ago(b.created_at)}</div></div></div>
  `).join('')||'<div class="empty"><p class="empty-text">Sin bloqueos</p></div>';
}
async function resolveRep(id) { await supabase.from('content_reports').update({status:'resolved'}).eq('id',id); loadModeration(); toast('✅ Resuelto'); }

// ═══════════════════════════════════════════════════════════════════════════
// ANALYTICS
// ═══════════════════════════════════════════════════════════════════════════

async function loadAnalytics() {
  const day = new Date(Date.now()-864e5).toISOString();
  const [dau,vids,apps,ver] = await Promise.all([
    supabase.from('users').select('id',{count:'exact',head:true}).gte('updated_at',day),
    supabase.from('users').select('id',{count:'exact',head:true}).not('video_url','is',null),
    supabase.from('job_applications').select('id',{count:'exact',head:true}).then(r=>r).catch(()=>({count:0})),
    supabase.from('company_verifications').select('id',{count:'exact',head:true}).eq('status','approved'),
  ]);
  anim('stat-dau',dau.count||0); anim('stat-videos',vids.count||0); anim('stat-applications',apps.count||0); anim('stat-verified',ver.count||0);

  const { data: u14 } = await supabase.from('users').select('created_at').gte('created_at',new Date(Date.now()-14*864e5).toISOString()).order('created_at');
  const buckets = {};
  for(let i=13;i>=0;i--){ const d=new Date(Date.now()-i*864e5); buckets[d.toISOString().split('T')[0]]=0; }
  (u14||[]).forEach(u=>{ const k=u.created_at?.split('T')[0]; if(k&&buckets[k]!==undefined)buckets[k]++; });
  const mx = Math.max(...Object.values(buckets),1);
  document.getElementById('chart-registrations').innerHTML = Object.entries(buckets).map(([d,c])=>{
    const p=(c/mx*100).toFixed(0);
    const l=new Date(d+'T12:00:00').toLocaleDateString('es-AR',{day:'numeric',month:'short'});
    return `<div class="chart-col"><span class="chart-val">${c}</span><div class="chart-bar" style="height:${Math.max(p,3)}%"></div><span class="chart-lbl">${l}</span></div>`;
  }).join('');
}

// ═══════════════════════════════════════════════════════════════════════════
// CONFIG
// ═══════════════════════════════════════════════════════════════════════════

function loadConfig() {
  document.getElementById('cfg-emails').value = ADMIN_EMAILS.join('\n');
  document.getElementById('cfg-secret').value = ADMIN_SECRET;
}

// ═══════════════════════════════════════════════════════════════════════════
// UTILS
// ═══════════════════════════════════════════════════════════════════════════

function closeModal(id) { document.getElementById(id).classList.add('hidden'); }
function esc(s) { if(!s)return''; const d=document.createElement('div'); d.textContent=s; return d.innerHTML; }
function ago(d) { if(!d)return''; const m=Math.floor((Date.now()-new Date(d).getTime())/6e4); if(m<1)return'Ahora'; if(m<60)return m+'m'; const h=Math.floor(m/60); if(h<24)return h+'h'; const dy=Math.floor(h/24); if(dy<30)return dy+'d'; return Math.floor(dy/30)+'mes'; }
function anim(id,target) { const el=document.getElementById(id); if(!el)return; const s=parseInt(el.textContent)||0,st=performance.now(); (function u(t){ const p=Math.min((t-st)/700,1),e=1-Math.pow(1-p,3); el.textContent=Math.round(s+(target-s)*e).toLocaleString('es-AR'); if(p<1)requestAnimationFrame(u); })(st); }
function toast(msg) { const t=document.createElement('div'); t.style.cssText=`position:fixed;bottom:20px;right:20px;padding:12px 22px;background:linear-gradient(135deg,#2ECC71,#27AE60);color:white;border-radius:10px;font-size:13px;font-weight:700;z-index:9999;animation:slideUp .25s ease;box-shadow:0 8px 24px rgba(46,204,113,.25)`; t.textContent=msg; document.body.appendChild(t); setTimeout(()=>t.remove(),3000); }

/* ═══════════════════════════════════════════════════════════════════════════ */
/* AI COPILOT — Gemini Integration                                           */
/* ═══════════════════════════════════════════════════════════════════════════ */

const GEMINI_KEY = 'AIzaSyBJrcbvWrH8bLklB0XpE_9kP_1VueGyUA8';
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_KEY}`;
let copilotOpen = false;
let copilotHistory = [];
let copilotBusy = false;

// Toggle copilot panel visibility
function toggleCopilot() {
  const panel = document.getElementById('copilot-panel');
  const fab = document.getElementById('copilot-fab');
  copilotOpen = !copilotOpen;
  if (copilotOpen) {
    panel.classList.remove('hidden');
    fab.style.transform = 'rotate(90deg) scale(0.9)';
    document.getElementById('copilot-input').focus();
  } else {
    panel.classList.add('hidden');
    fab.style.transform = '';
  }
}

// Collect live platform stats from Supabase for AI context
async function collectPlatformContext() {
  const now = new Date();
  const dayAgo = new Date(now - 86400000).toISOString();
  const weekAgo = new Date(now - 604800000).toISOString();
  const monthAgo = new Date(now - 2592000000).toISOString();

  // Helper: safe query that returns 0/null on error
  async function safeCount(table, filters = {}) {
    try {
      let q = supabase.from(table).select('*', { count: 'exact', head: true });
      for (const [k, v] of Object.entries(filters)) {
        if (k === 'gte') q = q.gte(v[0], v[1]);
        else q = q.eq(k, v);
      }
      const { count } = await q;
      return count || 0;
    } catch { return 0; }
  }

  async function safeSelect(table, cols, orderBy, limit) {
    try {
      const { data } = await supabase.from(table).select(cols).order(orderBy, { ascending: false }).limit(limit);
      return data || [];
    } catch { return []; }
  }

  // Parallel fault-tolerant queries
  const [
    totalUsers, premiumUsers, empresaUsers,
    activeJobs, totalJobs,
    usersToday, usersWeek, usersMonth,
    ghostApps, totalConnections, messages24h,
    recentUsers, recentJobs
  ] = await Promise.all([
    safeCount('users'),
    safeCount('users', { is_premium: true }),
    safeCount('users', { account_type: 'empresa' }),
    safeCount('jobs', { status: 'active' }),
    safeCount('jobs'),
    safeCount('users', { gte: ['created_at', dayAgo] }),
    safeCount('users', { gte: ['created_at', weekAgo] }),
    safeCount('users', { gte: ['created_at', monthAgo] }),
    safeCount('ghost_applications'),
    safeCount('connections'),
    safeCount('messages', { gte: ['created_at', dayAgo] }),
    safeSelect('users', 'full_name,headline,account_type,is_premium,created_at,hashtags', 'created_at', 10),
    safeSelect('jobs', 'title,company_name,location,modality,status,created_at', 'created_at', 8)
  ]);

  // Top hashtags analysis
  let hashtagCount = {};
  recentUsers.forEach(u => {
    if (u.hashtags && Array.isArray(u.hashtags)) {
      u.hashtags.forEach(h => { hashtagCount[h] = (hashtagCount[h] || 0) + 1; });
    }
  });
  const topTags = Object.entries(hashtagCount).sort((a,b) => b[1]-a[1]).slice(0, 10).map(e => `${e[0]} (${e[1]})`).join(', ');

  return `
=== DATOS EN TIEMPO REAL DE MPLOYA ===
Fecha/Hora: ${now.toLocaleString('es-AR')}

📊 MÉTRICAS GENERALES:
- Usuarios totales: ${totalUsers}
- Usuarios premium: ${premiumUsers}
- Cuentas empresa: ${empresaUsers}
- Vacantes activas: ${activeJobs} de ${totalJobs} total
- Ghost Applications: ${ghostApps}
- Conexiones totales: ${totalConnections}
- Mensajes últimas 24h: ${messages24h}

📈 CRECIMIENTO:
- Nuevos usuarios hoy: ${usersToday}
- Nuevos usuarios esta semana: ${usersWeek}
- Nuevos usuarios este mes: ${usersMonth}

🏷️ HASHTAGS POPULARES: ${topTags || 'Sin datos suficientes'}

👥 ÚLTIMOS REGISTROS:
${recentUsers.map(u => `- ${u.full_name || 'Sin nombre'} (${u.account_type || 'abierto'})${u.is_premium ? ' ⭐ Premium' : ''} — ${u.headline || 'Sin headline'} — ${ago(u.created_at)}`).join('\n')}

💼 ÚLTIMAS VACANTES:
${recentJobs.map(j => `- ${j.title || 'Sin título'} @ ${j.company_name || '?'} — ${j.location || '?'} (${j.status}) — ${ago(j.created_at)}`).join('\n')}
===`;
}

// Add a message bubble to the chat
function addCopilotMsg(text, isUser = false) {
  const container = document.getElementById('copilot-messages');
  const div = document.createElement('div');
  div.className = `copilot-msg ${isUser ? 'copilot-msg-user' : 'copilot-msg-ai'}`;
  
  // Convert markdown-like formatting to HTML
  let html = text
    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
    .replace(/\*(.*?)\*/g, '<em>$1</em>')
    .replace(/`(.*?)`/g, '<code>$1</code>')
    .replace(/\n/g, '<br>');
  
  div.innerHTML = `
    <div class="copilot-msg-avatar">${isUser ? '👤' : '🤖'}</div>
    <div class="copilot-msg-bubble">${html}</div>
  `;
  container.appendChild(div);
  container.scrollTop = container.scrollHeight;
  return div;
}

// Show typing indicator
function showTyping() {
  const container = document.getElementById('copilot-messages');
  const div = document.createElement('div');
  div.className = 'copilot-msg copilot-msg-ai';
  div.id = 'copilot-typing';
  div.innerHTML = `
    <div class="copilot-msg-avatar">🤖</div>
    <div class="copilot-msg-bubble">
      <div class="copilot-typing">
        <div class="copilot-typing-dot"></div>
        <div class="copilot-typing-dot"></div>
        <div class="copilot-typing-dot"></div>
      </div>
    </div>
  `;
  container.appendChild(div);
  container.scrollTop = container.scrollHeight;
}

function hideTyping() {
  const el = document.getElementById('copilot-typing');
  if (el) el.remove();
}

// Send message to Gemini API (single attempt to avoid worsening rate limits)
async function callGemini(userMessage, platformData) {
  const systemPrompt = `Sos el Copilot IA del panel de administración de **Mploya** (mploya.ai), una plataforma de networking profesional y empleos con video pitch, ghost apply, y challenges.

Tu rol es ayudar al administrador a:
- Analizar métricas y tendencias de la plataforma
- Identificar anomalías o alertas
- Generar reportes y resúmenes ejecutivos
- Dar recomendaciones de crecimiento y retención
- Responder preguntas sobre los datos de usuarios, vacantes, pagos y actividad

REGLAS:
- Respondé siempre en **español** (argentino informal)
- Sé conciso pero informativo
- Usá emojis estratégicamente para hacer la respuesta más visual
- Si no tenés datos suficientes, decilo
- Formateá los números de forma legible
- Si te piden un reporte, estructuralo con secciones claras
- Nunca inventes datos, solo usá los que tenés disponibles

DATOS ACTUALES DE LA PLATAFORMA:
${platformData}`;

  copilotHistory.push({ role: 'user', parts: [{ text: userMessage }] });

  const body = {
    system_instruction: { parts: [{ text: systemPrompt }] },
    contents: copilotHistory,
    generationConfig: {
      temperature: 0.7,
      maxOutputTokens: 1024,
      topP: 0.9
    }
  };

  const res = await fetch(GEMINI_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  });

  if (res.ok) {
    const data = await res.json();
    const reply = data.candidates?.[0]?.content?.parts?.[0]?.text || 'No pude generar una respuesta.';
    copilotHistory.push({ role: 'model', parts: [{ text: reply }] });
    if (copilotHistory.length > 20) copilotHistory = copilotHistory.slice(-16);
    return reply;
  }

  copilotHistory.pop();

  if (res.status === 429) {
    throw new Error('⏳ Rate limit alcanzado (free tier: 15 req/min).\n\nEsperá 60 segundos y volvé a intentar.');
  }
  if (res.status === 403) {
    throw new Error('🔑 API key sin permisos. Verificá en Google AI Studio.');
  }
  throw new Error(`Error ${res.status}. Intentá de nuevo en unos segundos.`);
}

// Handle sending a message
async function sendCopilot() {
  const input = document.getElementById('copilot-input');
  const msg = input.value.trim();
  if (!msg || copilotBusy) return;
  
  input.value = '';
  askCopilot(msg);
}

// Main function to ask the copilot
async function askCopilot(question) {
  if (copilotBusy) return;
  copilotBusy = true;

  // Ensure panel is open
  if (!copilotOpen) toggleCopilot();

  // Hide suggestions after first use
  const suggestions = document.getElementById('copilot-suggestions');
  if (suggestions) suggestions.style.display = 'none';

  // Add user message
  addCopilotMsg(question, true);

  // Show typing
  showTyping();

  // Disable send button
  const sendBtn = document.getElementById('copilot-send-btn');
  if (sendBtn) sendBtn.disabled = true;

  try {
    // Collect fresh platform data
    const platformData = await collectPlatformContext();

    // Call Gemini
    const response = await callGemini(question, platformData);

    hideTyping();
    addCopilotMsg(response);
  } catch (err) {
    hideTyping();
    addCopilotMsg(`❌ Error: ${err.message}\n\nIntentá de nuevo en unos segundos.`);
    console.error('Copilot error:', err);
  } finally {
    copilotBusy = false;
    if (sendBtn) sendBtn.disabled = false;
  }
}
