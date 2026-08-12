import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Datos compartidos por Ofertas, Contrataciones y Rendimiento de vacantes.
///
/// Las tres miran el MISMO proceso desde ángulos distintos, así que comparten
/// origen: `get_company_candidates` (postulaciones con perfil y vacante ya
/// unidos) y `get_my_pipeline` (etapas de `connections.ats_status`).
///
/// AUDITORÍA DEL CONCEPTO "OFERTA". No existe tabla de ofertas: ni salario
/// ofrecido, ni vencimiento, ni contrato, ni firma. Lo único real es
/// `job_applications.status = 'accepted'`, que es exactamente lo que el
/// Dashboard ya cuenta como etapa "Oferta". Esta pantalla muestra eso y nada
/// más.
///
/// AUDITORÍA DE "CONTRATADO". Hay dos fuentes y no siempre coinciden:
/// `connections.ats_status = 'hired'` (la que usa el Pipeline) y, si existiera,
/// un `job_applications.status = 'hired'`. Se leen las dos y se fusionan por
/// candidato, marcando de dónde salió cada una.

/// Una persona en una etapa concreta del proceso, con su vacante.
@immutable
class PersonaEnProceso {
  final String candidatoId;
  final String nombre;
  final String? headline;
  final String? avatarUrl;
  final List<String> tags;

  final String? vacanteId;
  final String? vacante;

  /// Estado crudo de la base. No se traduce en el modelo para no perder el dato.
  final String estado;

  /// Fecha de la postulación (`job_applications.created_at`). No es la fecha de
  /// la oferta ni de la contratación: esa no se registra en ningún lado.
  final DateTime? postuladoEl;

  /// De qué fuente salió: 'job_applications' o 'connections'.
  final String origen;

  const PersonaEnProceso({
    required this.candidatoId,
    required this.nombre,
    required this.estado,
    required this.origen,
    this.headline,
    this.avatarUrl,
    this.tags = const [],
    this.vacanteId,
    this.vacante,
    this.postuladoEl,
  });

  String? get antiguedad {
    final f = postuladoEl;
    if (f == null) return null;
    final d = DateTime.now().difference(f);
    if (d.inDays >= 30) {
      final m = (d.inDays / 30).floor();
      return 'Hace $m ${m == 1 ? 'mes' : 'meses'}';
    }
    if (d.inDays >= 1) {
      return 'Hace ${d.inDays} ${d.inDays == 1 ? 'día' : 'días'}';
    }
    return 'Hoy';
  }
}

@immutable
class ProcesoData {
  final List<PersonaEnProceso> personas;
  final bool error;

  const ProcesoData({required this.personas, this.error = false});

  static const empty = ProcesoData(personas: []);

  int get total => personas.length;

  /// Agrupa por vacante para poder mostrar "3 en oferta en Product Manager".
  Map<String, List<PersonaEnProceso>> get porVacante {
    final mapa = <String, List<PersonaEnProceso>>{};
    for (final p in personas) {
      final clave = p.vacante ?? 'Sin vacante';
      mapa.putIfAbsent(clave, () => []).add(p);
    }
    return mapa;
  }
}

/// Estados de `job_applications` que representan una oferta hecha.
///
/// Hoy la base sólo usa `accepted` (es lo que cuenta el Dashboard como
/// "Oferta"). `offered` se acepta por si aparece más adelante: leerlo no
/// inventa nada, y evita que la pantalla quede muda si el estado cambia.
const _estadosOferta = {'accepted', 'offered'};

/// Estados que representan una contratación.
const _estadosContratado = {'hired', 'contratado'};

/// Postulaciones de la empresa filtradas por un conjunto de estados.
Future<ProcesoData> _loadPostulacionesPorEstado(Set<String> estados) async {
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) return ProcesoData.empty;

  try {
    final filas = await client.rpc('get_company_candidates') as List<dynamic>;
    final personas = <PersonaEnProceso>[];

    for (final raw in filas) {
      final p = raw as Map;
      final estado = p['status']?.toString().toLowerCase() ?? '';
      if (!estados.contains(estado)) continue;

      personas.add(
        PersonaEnProceso(
          candidatoId: p['candidate_id']?.toString() ?? '',
          nombre: p['candidate_name']?.toString() ?? 'Candidato',
          headline: (p['candidate_headline']?.toString().isNotEmpty ?? false)
              ? p['candidate_headline'].toString()
              : null,
          avatarUrl: (p['candidate_avatar_url']?.toString().isNotEmpty ?? false)
              ? p['candidate_avatar_url'].toString()
              : null,
          tags: [
            for (final t in (p['candidate_tags'] as List? ?? const []))
              t.toString().replaceAll('#', '').trim(),
          ]..removeWhere((t) => t.isEmpty),
          vacanteId: p['job_id']?.toString(),
          vacante: p['job_title']?.toString(),
          estado: p['status']?.toString() ?? '',
          postuladoEl: DateTime.tryParse(p['applied_at']?.toString() ?? ''),
          origen: 'job_applications',
        ),
      );
    }

    personas.sort((a, b) {
      final fa = a.postuladoEl, fb = b.postuladoEl;
      if (fa == null || fb == null) return 0;
      return fb.compareTo(fa);
    });

    return ProcesoData(personas: personas);
  } catch (e) {
    debugPrint('proceso · get_company_candidates: $e');
    return const ProcesoData(personas: [], error: true);
  }
}

/// Candidatos con oferta hecha.
Future<ProcesoData> loadOfertas() =>
    _loadPostulacionesPorEstado(_estadosOferta);

/// Contrataciones.
///
/// Fusiona las dos fuentes reales: las postulaciones marcadas como contratadas
/// y el pipeline (`ats_status = 'hired'`). Si una persona aparece en las dos,
/// gana la de postulaciones, que trae vacante.
Future<ProcesoData> loadContrataciones() async {
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) return ProcesoData.empty;

  final porId = <String, PersonaEnProceso>{};
  var error = false;

  final desdePostulaciones =
      await _loadPostulacionesPorEstado(_estadosContratado);
  if (desdePostulaciones.error) {
    error = true;
  } else {
    for (final p in desdePostulaciones.personas) {
      porId[p.candidatoId] = p;
    }
  }

  try {
    final filas = await client.rpc('get_my_pipeline') as List<dynamic>;
    for (final raw in filas) {
      final f = raw as Map;
      if (f['ats_status']?.toString() != 'hired') continue;

      final id = f['user_id']?.toString() ?? '';
      if (id.isEmpty || porId.containsKey(id)) continue;

      porId[id] = PersonaEnProceso(
        candidatoId: id,
        nombre: f['user_name']?.toString() ?? 'Candidato',
        headline: (f['user_headline']?.toString().isNotEmpty ?? false)
            ? f['user_headline'].toString()
            : null,
        avatarUrl: (f['user_avatar_url']?.toString().isNotEmpty ?? false)
            ? f['user_avatar_url'].toString()
            : null,
        estado: 'hired',
        // El pipeline no dice para qué vacante: no se infiere.
        origen: 'connections',
      );
    }
  } catch (e) {
    debugPrint('proceso · get_my_pipeline: $e');
    if (porId.isEmpty) error = true;
  }

  return ProcesoData(personas: porId.values.toList(), error: error);
}

/// Rendimiento comparado de las vacantes propias.
@immutable
class RendimientoVacante {
  final String id;
  final String titulo;
  final int postulaciones;
  final int entrevistas;
  final bool activa;

  const RendimientoVacante({
    required this.id,
    required this.titulo,
    required this.postulaciones,
    required this.entrevistas,
    required this.activa,
  });
}

@immutable
class RendimientoData {
  final List<RendimientoVacante> vacantes;
  final bool entrevistasNoDisponibles;
  final bool error;

  const RendimientoData({
    required this.vacantes,
    this.entrevistasNoDisponibles = false,
    this.error = false,
  });

  static const empty = RendimientoData(vacantes: []);

  int get totalPostulaciones =>
      vacantes.fold<int>(0, (s, v) => s + v.postulaciones);

  int get totalEntrevistas =>
      vacantes.fold<int>(0, (s, v) => s + v.entrevistas);

  int get activas => vacantes.where((v) => v.activa).length;

  int get maxPostulaciones =>
      vacantes.fold<int>(0, (m, v) => v.postulaciones > m ? v.postulaciones : m);

  /// Vacantes sin una sola postulación: el dato accionable de esta pantalla.
  List<RendimientoVacante> get sinPostulaciones =>
      vacantes.where((v) => v.postulaciones == 0).toList();
}

/// Ranking de vacantes por postulaciones y entrevistas.
///
/// NO duplica el Analytics de una vacante (que mira una sola en profundidad) ni
/// el Dashboard (que mira el embudo agregado): acá la unidad es la COMPARACIÓN
/// entre las vacantes propias, que es lo que el mockup llama "Vacantes con mejor
/// rendimiento".
Future<RendimientoData> loadRendimiento() async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return RendimientoData.empty;

  List<dynamic> jobs;
  try {
    jobs = await client
        .from('jobs')
        .select()
        .eq('company_id', uid)
        .order('created_at', ascending: false) as List<dynamic>;
  } catch (e) {
    debugPrint('rendimiento · jobs: $e');
    return const RendimientoData(vacantes: [], error: true);
  }

  if (jobs.isEmpty) return RendimientoData.empty;

  final ids = [for (final j in jobs) (j as Map)['id'].toString()];

  final postulaciones = <String, int>{};
  try {
    final filas = await client
        .from('job_applications')
        .select('job_id')
        .inFilter('job_id', ids) as List<dynamic>;
    for (final f in filas) {
      final jid = (f as Map)['job_id']?.toString() ?? '';
      if (jid.isEmpty) continue;
      postulaciones[jid] = (postulaciones[jid] ?? 0) + 1;
    }
  } catch (e) {
    debugPrint('rendimiento · job_applications: $e');
    return const RendimientoData(vacantes: [], error: true);
  }

  final entrevistas = <String, int>{};
  var entrevistasNoDisponibles = false;
  try {
    final filas = await client
        .from('interviews')
        .select('job_id')
        .inFilter('job_id', ids) as List<dynamic>;
    for (final f in filas) {
      final jid = (f as Map)['job_id']?.toString() ?? '';
      if (jid.isEmpty) continue;
      entrevistas[jid] = (entrevistas[jid] ?? 0) + 1;
    }
  } catch (e) {
    debugPrint('rendimiento · interviews: $e');
    entrevistasNoDisponibles = true;
  }

  final vacantes = <RendimientoVacante>[];
  for (final j in jobs) {
    final fila = j as Map;
    final id = fila['id'].toString();
    vacantes.add(
      RendimientoVacante(
        id: id,
        titulo: fila['title']?.toString() ?? 'Vacante sin título',
        postulaciones: postulaciones[id] ?? 0,
        entrevistas: entrevistas[id] ?? 0,
        activa: fila['is_active'] != false,
      ),
    );
  }

  vacantes.sort((a, b) => b.postulaciones.compareTo(a.postulaciones));

  return RendimientoData(
    vacantes: vacantes,
    entrevistasNoDisponibles: entrevistasNoDisponibles,
  );
}
