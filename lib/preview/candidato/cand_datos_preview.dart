/// Datos ficticios COMPARTIDOS por las cinco composiciones de la tanda.
///
/// Están en un solo archivo para que las cinco pantallas parezcan el mismo
/// usuario y el mismo producto: si Renata aparece en Perfil con 128 vistas,
/// en Inicio y en Red es la misma persona con los mismos números.
///
/// Personas y empresas inventadas. Sin URLs remotas: los avatares se dibujan
/// con iniciales (`CandAvatar`). Nada de esto se importa desde `lib/screens/`.
library;

class CandPersona {
  const CandPersona({
    required this.nombre,
    required this.titulo,
    this.ciudad = '',
    this.verificado = false,
    this.match = 0,
    this.etiquetas = const [],
  });

  final String nombre;
  final String titulo;
  final String ciudad;
  final bool verificado;
  final int match;
  final List<String> etiquetas;
}

class CandVacante {
  const CandVacante({
    required this.puesto,
    required this.empresa,
    required this.ubicacion,
    required this.modalidad,
    required this.salario,
    required this.match,
    required this.etiquetas,
    this.publicada = 'Hace 2 h',
    this.guardada = false,
    this.destacada = false,
  });

  final String puesto;
  final String empresa;
  final String ubicacion;
  final String modalidad;
  final String salario;
  final int match;
  final List<String> etiquetas;
  final String publicada;
  final bool guardada;
  final bool destacada;
}

class CandConversacion {
  const CandConversacion({
    required this.persona,
    required this.ultimo,
    required this.hora,
    this.sinLeer = 0,
    this.enLinea = false,
  });

  final CandPersona persona;
  final String ultimo;
  final String hora;
  final int sinLeer;
  final bool enLinea;
}

class CandMensaje {
  const CandMensaje(this.texto, this.hora, {this.mio = false});
  final String texto;
  final String hora;
  final bool mio;
}

// ── La persona dueña de la sesión ────────────────────────────────────────────

const candYo = CandPersona(
  nombre: 'Renata Ferreyra',
  titulo: 'Product Designer · Sistemas de diseño',
  ciudad: 'Rosario, Argentina',
  verificado: true,
  etiquetas: ['Figma', 'Design Systems', 'Prototipado', 'Research'],
);

const candYoSobre =
    'Diseño productos digitales end-to-end. Me gusta el trabajo de sistema: '
    'tokens, componentes y documentación que sobreviven al equipo que los creó.';

const candMetricas = <(String, String)>[
  ('128', 'Vistas'),
  ('34', 'Conexiones'),
  ('86%', 'Perfil'),
];

const candExperiencia = <(String, String, String)>[
  ('Product Designer', 'Vantera', '2023 — actualidad'),
  ('UI Designer', 'Estudio Malvón', '2021 — 2023'),
];

// ── Gente ────────────────────────────────────────────────────────────────────

const candPersonas = <CandPersona>[
  CandPersona(
    nombre: 'Bruno Alcaraz',
    titulo: 'Frontend Engineer · React',
    ciudad: 'Córdoba',
    verificado: true,
    match: 88,
    etiquetas: ['React', 'TypeScript'],
  ),
  CandPersona(
    nombre: 'Milena Ortiz',
    titulo: 'Talent Partner en Vantera',
    ciudad: 'Buenos Aires',
    verificado: true,
    match: 92,
    etiquetas: ['Recruiting'],
  ),
  CandPersona(
    nombre: 'Ezequiel Paz',
    titulo: 'Data Analyst · SQL y dbt',
    ciudad: 'Montevideo',
    match: 74,
    etiquetas: ['SQL', 'Python'],
  ),
  CandPersona(
    nombre: 'Delfina Roca',
    titulo: 'Head of People en Almiar',
    ciudad: 'Rosario',
    verificado: true,
    match: 81,
    etiquetas: ['People Ops'],
  ),
  CandPersona(
    nombre: 'Tomás Bengoa',
    titulo: 'Product Manager',
    ciudad: 'Santiago',
    match: 69,
    etiquetas: ['Producto'],
  ),
  CandPersona(
    nombre: 'Sol Miranda',
    titulo: 'UX Researcher',
    ciudad: 'Rosario',
    verificado: true,
    match: 90,
    etiquetas: ['Research'],
  ),
];

// ── Vacantes ─────────────────────────────────────────────────────────────────

const candVacantes = <CandVacante>[
  CandVacante(
    puesto: 'Product Designer Senior',
    empresa: 'Vantera',
    ubicacion: 'Buenos Aires',
    modalidad: 'Híbrido',
    salario: 'USD 2.800 – 3.600',
    match: 92,
    etiquetas: ['Figma', 'Design Systems', 'Producto'],
    publicada: 'Hace 2 h',
    destacada: true,
  ),
  CandVacante(
    puesto: 'Diseñadora de Producto',
    empresa: 'Almiar',
    ubicacion: 'Remoto',
    modalidad: 'Remoto',
    salario: 'USD 2.000 – 2.600',
    match: 84,
    etiquetas: ['Figma', 'Research'],
    publicada: 'Hace 5 h',
    guardada: true,
  ),
  CandVacante(
    puesto: 'UX Researcher',
    empresa: 'Vantera',
    ubicacion: 'Rosario',
    modalidad: 'Presencial',
    salario: 'USD 1.900 – 2.400',
    match: 71,
    etiquetas: ['Research', 'Entrevistas'],
    publicada: 'Ayer',
  ),
  CandVacante(
    puesto: 'Design Lead',
    empresa: 'Nubero',
    ubicacion: 'Remoto',
    modalidad: 'Remoto',
    salario: 'USD 3.400 – 4.200',
    match: 66,
    etiquetas: ['Liderazgo', 'Sistemas'],
    publicada: 'Hace 2 días',
  ),
];

// ── Mensajes ─────────────────────────────────────────────────────────────────

const candConversaciones = <CandConversacion>[
  CandConversacion(
    persona: CandPersona(
      nombre: 'Milena Ortiz',
      titulo: 'Talent Partner en Vantera',
    ),
    ultimo: 'Hola Renata, vi tu video pitch. ¿Charlamos esta semana?',
    hora: '14:02',
    sinLeer: 2,
    enLinea: true,
  ),
  CandConversacion(
    persona: CandPersona(nombre: 'Bruno Alcaraz', titulo: 'Frontend Engineer'),
    ultimo: '¿Viste la búsqueda de Almiar? Te la paso.',
    hora: 'Ayer',
    enLinea: true,
  ),
  CandConversacion(
    persona: CandPersona(nombre: 'Delfina Roca', titulo: 'Head of People'),
    ultimo: 'Gracias por mandarme el portfolio, lo veo hoy.',
    hora: 'Ayer',
  ),
  CandConversacion(
    persona: CandPersona(nombre: 'Sol Miranda', titulo: 'UX Researcher'),
    ultimo: 'Te comparto la guía de entrevistas que armamos.',
    hora: '2 días',
    sinLeer: 1,
  ),
  CandConversacion(
    persona: CandPersona(nombre: 'Tomás Bengoa', titulo: 'Product Manager'),
    ultimo: 'Perfecto, quedamos así entonces.',
    hora: '3 días',
  ),
];

const candHilo = <CandMensaje>[
  CandMensaje(
    'Hola Renata, vi tu video pitch y me encantó cómo contás el trabajo de sistema.',
    '14:02',
  ),
  CandMensaje(
    'Estamos buscando una Product Designer Senior para el equipo de checkout.',
    '14:03',
  ),
  CandMensaje('¡Hola Milena! Gracias. Me interesa mucho.', '14:15', mio: true),
  CandMensaje(
    'El jueves a la tarde me queda bien para una charla.',
    '14:15',
    mio: true,
  ),
  CandMensaje('Genial, te mando la invitación ahora.', '14:18'),
];
