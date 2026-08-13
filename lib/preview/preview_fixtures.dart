/// DATOS FICTICIOS DEL MODO PREVIEW — `PREVIEW_FIXTURE`.
///
/// ⚠️ NADA DE ESTE ARCHIVO PUEDE LLEGAR A PRODUCCIÓN.
///
/// Reglas que cumplen todas las fixtures de acá:
///
///  · Personas y empresas **inventadas**. No son datos reales de nadie ni
///    copias de la base: los ids llevan el prefijo `preview-` justamente para
///    que sean imposibles de confundir con un UUID real.
///  · **Cero URLs remotas.** Ni `randomuser.me`, ni avatares de internet, ni
///    videos externos. El preview tiene que funcionar sin red. Los avatares se
///    dibujan con iniciales y los videos son placeholders locales.
///  · **Cero Supabase.** Este archivo no importa `supabase_flutter` ni ningún
///    servicio productivo. Son estructuras de datos y nada más.
///  · **Nunca son fallback.** Ninguna pantalla productiva las consulta: sólo
///    las inyecta el modo preview, que a su vez sólo existe con `kDebugMode` y
///    `--dart-define=MPLOYA_PREVIEW=true`. Si una consulta real vuelve vacía,
///    la pantalla muestra su estado vacío honesto, no esto.
///
/// La forma de cada mapa imita la fila que devuelve la base, para que las
/// pantallas no necesiten un camino de datos distinto al productivo.
library;

/// Marca única para auditar que una estructura viene del preview.
const String kPreviewFixtureTag = 'PREVIEW_FIXTURE';

/// Prefijo de todos los identificadores ficticios.
const String kPreviewIdPrefix = 'preview-';

// ─────────────────────────────────────────────────────────────────────────────
// USUARIOS (forma de `public.users`)
// ─────────────────────────────────────────────────────────────────────────────

/// El candidato dueño de la sesión de preview.
const Map<String, dynamic> previewCandidato = {
  'id': '${kPreviewIdPrefix}cand-01',
  'name': 'Renata Ferreyra',
  'headline': 'Product Designer · Sistemas de diseño',
  'about':
      'Diseño productos digitales end-to-end. Me gusta el trabajo de sistema: '
      'tokens, componentes y documentación que sobreviven al equipo que los creó.',
  'city': 'Rosario, Argentina',
  'location': 'Rosario, Argentina',
  'account_type': 'candidato',
  'avatar_url': null,
  'banner_url': null,
  'video_url': '${kPreviewIdPrefix}video-pitch',
  'skills': ['Figma', 'Design Systems', 'Prototipado', 'Research'],
  'tags': ['Diseño', 'Producto'],
  'experience': [
    {
      'role': 'Product Designer',
      'company': 'Vantera',
      'duration': '2023 — actualidad',
      'location': 'Remoto',
      'description': 'Sistema de diseño y rediseño del checkout.',
      'is_current': true,
    },
    {
      'role': 'UI Designer',
      'company': 'Estudio Malvón',
      'duration': '2021 — 2023',
      'location': 'Rosario',
      'description': 'Interfaces para clientes de retail y salud.',
      'is_current': false,
    },
  ],
  'education': [
    {
      'school': 'Universidad Nacional de Rosario',
      'degree': 'Diseño de Comunicación Visual',
      'field': 'Diseño',
      'years': '2016 — 2021',
    },
  ],
  'is_premium': false,
  'is_verified': true,
  'open_to_work': true,
  'is_hiring': false,
  'connections': 34,
  'profile_views': 128,
  'match_percentage': 0.0,
  'rating_stars': 0.0,
  'rating_count': 0,
  'like_count': 0,
  'salary_expectation': 'USD 2.000 - 2.800',
  'onboarding_step': 3,
  'latitude': -32.9468,
  'longitude': -60.6393,
};

/// Variante confidencial del mismo candidato, para la vista en modo sigiloso.
///
/// No es `const`: un mapa constante no admite claves repetidas, y acá el spread
/// pisa cuatro campos del original a propósito.
final Map<String, dynamic> previewCandidatoConfidencial = {
  ...previewCandidato,
  'id': '${kPreviewIdPrefix}cand-conf',
  'name': 'Candidato Confidencial',
  'account_type': 'confidencial',
  'headline': 'Product Designer Senior · perfil en privado',
};

/// Otras personas: conexiones, solicitudes y conversaciones.
const List<Map<String, dynamic>> previewPersonas = [
  {
    'id': '${kPreviewIdPrefix}user-01',
    'name': 'Bruno Alcaraz',
    'headline': 'Frontend Engineer · React',
    'city': 'Córdoba, Argentina',
    'account_type': 'candidato',
    'avatar_url': null,
    'skills': ['React', 'TypeScript'],
    'is_verified': true,
    'open_to_work': true,
  },
  {
    'id': '${kPreviewIdPrefix}user-02',
    'name': 'Milena Ortiz',
    'headline': 'Talent Partner en Vantera',
    'city': 'Buenos Aires, Argentina',
    'account_type': 'empresa',
    'avatar_url': null,
    'skills': ['Recruiting'],
    'is_verified': true,
    'is_hiring': true,
  },
  {
    'id': '${kPreviewIdPrefix}user-03',
    'name': 'Ezequiel Paz',
    'headline': 'Data Analyst · SQL y dbt',
    'city': 'Montevideo, Uruguay',
    'account_type': 'candidato',
    'avatar_url': null,
    'skills': ['SQL', 'dbt', 'Python'],
    'is_verified': false,
    'open_to_work': true,
  },
  {
    'id': '${kPreviewIdPrefix}user-04',
    'name': 'Delfina Roca',
    'headline': 'Head of People en Almiar',
    'city': 'Rosario, Argentina',
    'account_type': 'empresa',
    'avatar_url': null,
    'skills': ['People Ops'],
    'is_verified': true,
    'is_hiring': true,
  },
];

// ─────────────────────────────────────────────────────────────────────────────
// EMPRESAS Y VACANTES (forma de `public.jobs` con el join a `users`)
// ─────────────────────────────────────────────────────────────────────────────

const List<Map<String, dynamic>> previewVacantes = [
  {
    'id': '${kPreviewIdPrefix}job-01',
    'title': 'Product Designer Senior',
    'company_id': '${kPreviewIdPrefix}user-02',
    'company': 'Vantera',
    'location': 'Buenos Aires, Argentina',
    'modality': 'hybrid',
    'seniority': 'senior',
    'salary_range': 'USD 2.800 - 3.600',
    'tags': ['Figma', 'Design Systems', 'Producto'],
    'description':
        'Buscamos una persona que lleve adelante el sistema de diseño y trabaje '
        'codo a codo con ingeniería.',
    'is_active': true,
    'is_remote': false,
    'created_at': '2026-08-11T10:00:00Z',
    'users': {'name': 'Vantera', 'avatar_url': null},
  },
  {
    'id': '${kPreviewIdPrefix}job-02',
    'title': 'Diseñadora de Producto (Remoto)',
    'company_id': '${kPreviewIdPrefix}user-04',
    'company': 'Almiar',
    'location': 'Remoto',
    'modality': 'remote',
    'seniority': 'mid',
    'salary_range': 'USD 2.000 - 2.600',
    'tags': ['Figma', 'Research'],
    'description': 'Equipo chico, mucho contacto con usuarios reales.',
    'is_active': true,
    'is_remote': true,
    'created_at': '2026-08-10T09:30:00Z',
    'users': {'name': 'Almiar', 'avatar_url': null},
  },
  {
    'id': '${kPreviewIdPrefix}job-03',
    'title': 'UX Researcher',
    'company_id': '${kPreviewIdPrefix}user-02',
    'company': 'Vantera',
    'location': 'Rosario, Argentina',
    'modality': 'onsite',
    'seniority': 'mid',
    'salary_range': 'USD 1.900 - 2.400',
    'tags': ['Research', 'Entrevistas'],
    'description': 'Investigación continua para el equipo de producto.',
    'is_active': true,
    'is_remote': false,
    'created_at': '2026-08-08T15:00:00Z',
    'users': {'name': 'Vantera', 'avatar_url': null},
  },
];

/// Porcentajes de match por vacante, con la forma que espera `_matchScores`.
const Map<String, int> previewMatchScores = {
  '${kPreviewIdPrefix}job-01': 92,
  '${kPreviewIdPrefix}job-02': 84,
  '${kPreviewIdPrefix}job-03': 71,
};

// ─────────────────────────────────────────────────────────────────────────────
// RED (forma de `public.connections`)
// ─────────────────────────────────────────────────────────────────────────────

const List<Map<String, dynamic>> previewConexiones = [
  {
    'id': '${kPreviewIdPrefix}conn-01',
    'requester_id': '${kPreviewIdPrefix}cand-01',
    'addressee_id': '${kPreviewIdPrefix}user-01',
    'status': 'accepted',
    'created_at': '2026-08-01T12:00:00Z',
  },
  {
    'id': '${kPreviewIdPrefix}conn-02',
    'requester_id': '${kPreviewIdPrefix}user-02',
    'addressee_id': '${kPreviewIdPrefix}cand-01',
    'status': 'accepted',
    'created_at': '2026-08-03T18:20:00Z',
  },
];

/// Solicitudes pendientes que la persona todavía no respondió.
const List<Map<String, dynamic>> previewSolicitudes = [
  {
    'id': '${kPreviewIdPrefix}conn-03',
    'requester_id': '${kPreviewIdPrefix}user-03',
    'addressee_id': '${kPreviewIdPrefix}cand-01',
    'status': 'pending',
    'created_at': '2026-08-12T09:05:00Z',
  },
  {
    'id': '${kPreviewIdPrefix}conn-04',
    'requester_id': '${kPreviewIdPrefix}user-04',
    'addressee_id': '${kPreviewIdPrefix}cand-01',
    'status': 'pending',
    'created_at': '2026-08-12T11:40:00Z',
  },
];

// ─────────────────────────────────────────────────────────────────────────────
// MENSAJES (forma de `public.messages`)
// ─────────────────────────────────────────────────────────────────────────────

const List<Map<String, dynamic>> previewMensajes = [
  {
    'id': '${kPreviewIdPrefix}msg-01',
    'sender_id': '${kPreviewIdPrefix}user-02',
    'receiver_id': '${kPreviewIdPrefix}cand-01',
    'content': 'Hola Renata, vi tu video pitch. ¿Charlamos esta semana?',
    'created_at': '2026-08-12T14:02:00Z',
    'is_read': false,
  },
  {
    'id': '${kPreviewIdPrefix}msg-02',
    'sender_id': '${kPreviewIdPrefix}cand-01',
    'receiver_id': '${kPreviewIdPrefix}user-02',
    'content': 'Hola Milena, sí. El jueves a la tarde me queda bien.',
    'created_at': '2026-08-12T14:15:00Z',
    'is_read': true,
  },
  {
    'id': '${kPreviewIdPrefix}msg-03',
    'sender_id': '${kPreviewIdPrefix}user-01',
    'receiver_id': '${kPreviewIdPrefix}cand-01',
    'content': '¿Viste la búsqueda de Almiar? Te la paso.',
    'created_at': '2026-08-11T20:31:00Z',
    'is_read': true,
  },
];

// ─────────────────────────────────────────────────────────────────────────────
// FEED (forma de las filas que consume el reel de Inicio)
// ─────────────────────────────────────────────────────────────────────────────

const List<Map<String, dynamic>> previewFeed = [
  {
    'id': '${kPreviewIdPrefix}feed-01',
    'user_id': '${kPreviewIdPrefix}user-01',
    'name': 'Bruno Alcaraz',
    'headline': 'Frontend Engineer · React',
    'video_url': '${kPreviewIdPrefix}video-01',
    'avatar_url': null,
    'like_count': 18,
    'match_percentage': 88.0,
    'tags': ['React', 'TypeScript'],
  },
  {
    'id': '${kPreviewIdPrefix}feed-02',
    'user_id': '${kPreviewIdPrefix}user-03',
    'name': 'Ezequiel Paz',
    'headline': 'Data Analyst · SQL y dbt',
    'video_url': '${kPreviewIdPrefix}video-02',
    'avatar_url': null,
    'like_count': 7,
    'match_percentage': 74.0,
    'tags': ['SQL', 'Python'],
  },
];

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICACIONES (forma de `public.notifications`)
// ─────────────────────────────────────────────────────────────────────────────

const List<Map<String, dynamic>> previewNotificaciones = [
  {
    'id': '${kPreviewIdPrefix}notif-01',
    'user_id': '${kPreviewIdPrefix}cand-01',
    'type': 'connection',
    'title': 'Nueva solicitud de conexión',
    'body': 'Ezequiel Paz quiere conectar con vos',
    'sender_name': 'Ezequiel Paz',
    'is_read': false,
    'created_at': '2026-08-12T09:05:00Z',
  },
  {
    'id': '${kPreviewIdPrefix}notif-02',
    'user_id': '${kPreviewIdPrefix}cand-01',
    'type': 'jobAlert',
    'title': 'Vacante que te puede interesar',
    'body': 'Vantera publicó Product Designer Senior',
    'sender_name': 'Vantera',
    'is_read': true,
    'created_at': '2026-08-11T10:05:00Z',
  },
];
