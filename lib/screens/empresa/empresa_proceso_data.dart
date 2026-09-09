import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/job_offer_service.dart';

/// Datos compartidos por Ofertas, Contrataciones y Rendimiento de vacantes.
///
/// Las tres miran el MISMO proceso desde ángulos distintos, así que comparten
/// origen: `get_company_candidates` (postulaciones con perfil y vacante ya
/// unidos) y `get_my_pipeline` (etapas de `connections.ats_status`).
///
/// ╔═══════════════════════════════════════════════════════════════════════╗
/// ║ ADENDA 30/8/2026 — migración 051, bloque E2 del plan de ofertas y     ║
/// ║ pipeline.                                                              ║
/// ╚═══════════════════════════════════════════════════════════════════════╝
///
/// Las dos auditorías de más abajo (conservadas por honestidad histórica) ya
/// no describen el estado real de la base:
///
/// · "OFERTA" ahora es un dato real: `job_offers` (salario, moneda, modalidad,
///   beneficios, fechas, mensaje, versiones). `loadOfertasEmpresa()` la lee
///   directamente en vez de inferirla de `job_applications.status`.
/// · "CONTRATADO" ya no se fusiona: `connections.ats_status` no tiene ninguna
///   vía de escritura real en la app (ver la ADENDA de
///   `empresa_pipeline_screen.dart`), así que dejó de leerse. La única fuente
///   es `job_applications.status = 'hired'`.
///
/// AUDITORÍA ORIGINAL (ya no vigente, ver arriba):
/// No existe tabla de ofertas: ni salario ofrecido, ni vencimiento, ni
/// contrato, ni firma. Lo único real es `job_applications.status =
/// 'accepted'`, que es exactamente lo que el Dashboard ya cuenta como etapa
/// "Oferta". Hay dos fuentes de "contratado" y no siempre coinciden:
/// `connections.ats_status = 'hired'` (la que usa el Pipeline) y, si
/// existiera, un `job_applications.status = 'hired'`. Se leen las dos y se
/// fusionan por candidato, marcando de dónde salió cada una.

/// Una persona en una etapa concreta del proceso, con su vacante.
@immutable
class PersonaEnProceso {
  final String candidatoId;
  final String nombre;
  final String? headline;
  final String? avatarUrl;
  final List<String> tags;
  final bool confidencial;

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
    this.confidencial = false,
    this.vacanteId,
    this.vacante,
    this.postuladoEl,
  });

  String get nombreVisible =>
      confidencial ? 'Candidato confidencial' : nombre;

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

/// Estados que representan una contratación: un solo estado real,
/// `hired` en `job_applications.status` (ver la ADENDA de más arriba).
const _estadosContratado = {'hired'};

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
      final candidatoId = p['candidate_id']?.toString() ?? '';

      personas.add(
        PersonaEnProceso(
          candidatoId: candidatoId,
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
          // Los bloqueados no salen de la RPC. Una fila confidencial solo
          // existe con un desbloqueo versionado valido.
          confidencial: p['is_confidential'] == true &&
              p['is_unlocked'] != true,
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

/// Una oferta real (migración 051), con el candidato y la vacante ya
/// resueltos con el mismo trato de confidencialidad que Pipeline y
/// Contrataciones (`get_company_candidates`).
@immutable
class OfertaEmpresa {
  const OfertaEmpresa({
    required this.oferta,
    required this.candidatoId,
    required this.nombre,
    required this.vacante,
    this.headline,
    this.avatarUrl,
    this.confidencial = false,
  });

  final JobOffer oferta;
  final String candidatoId;
  final String nombre;
  final String? headline;
  final String? avatarUrl;
  final bool confidencial;
  final String vacante;

  String get nombreVisible => confidencial ? 'Candidato confidencial' : nombre;
}

@immutable
class OfertasEmpresaData {
  const OfertasEmpresaData({required this.ofertas, this.error = false});

  final List<OfertaEmpresa> ofertas;
  final bool error;

  static const empty = OfertasEmpresaData(ofertas: []);

  int get total => ofertas.length;

  Map<String, List<OfertaEmpresa>> get porVacante {
    final mapa = <String, List<OfertaEmpresa>>{};
    for (final o in ofertas) {
      mapa.putIfAbsent(o.vacante, () => []).add(o);
    }
    return mapa;
  }
}

/// Ofertas reales hechas por la empresa. Cruza `job_offers` (salario,
/// moneda, modalidad, fechas, estado) con `get_company_candidates`
/// (nombre, vacante, confidencialidad) por `application_id`.
Future<OfertasEmpresaData> loadOfertasEmpresa() async {
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) return OfertasEmpresaData.empty;

  List<JobOffer> ofertas;
  try {
    ofertas = await loadOffersForCompany(client: client);
  } catch (e) {
    debugPrint('proceso · loadOffersForCompany: $e');
    return const OfertasEmpresaData(ofertas: [], error: true);
  }
  if (ofertas.isEmpty) return OfertasEmpresaData.empty;

  final porApplicationId = {for (final o in ofertas) o.applicationId: o};

  try {
    final filas = await client.rpc('get_company_candidates') as List<dynamic>;
    final resultado = <OfertaEmpresa>[];

    for (final raw in filas) {
      final p = raw as Map;
      final appId = p['application_id']?.toString() ?? '';
      final oferta = porApplicationId[appId];
      if (oferta == null) continue;

      resultado.add(
        OfertaEmpresa(
          oferta: oferta,
          candidatoId: p['candidate_id']?.toString() ?? '',
          nombre: p['candidate_name']?.toString() ?? 'Candidato',
          headline: (p['candidate_headline']?.toString().isNotEmpty ?? false)
              ? p['candidate_headline'].toString()
              : null,
          avatarUrl: (p['candidate_avatar_url']?.toString().isNotEmpty ?? false)
              ? p['candidate_avatar_url'].toString()
              : null,
          confidencial: p['is_confidential'] == true && p['is_unlocked'] != true,
          vacante: p['job_title']?.toString() ?? 'Sin vacante',
        ),
      );
    }

    resultado.sort((a, b) => b.oferta.createdAt.compareTo(a.oferta.createdAt));
    return OfertasEmpresaData(ofertas: resultado);
  } catch (e) {
    debugPrint('proceso · get_company_candidates (ofertas): $e');
    return const OfertasEmpresaData(ofertas: [], error: true);
  }
}

/// Contrataciones. Una sola fuente: `job_applications.status = 'hired'`,
/// la misma que usa Pipeline desde la ADENDA del 30/8/2026. Ya no se lee
/// `connections.ats_status`: esa columna no tiene ninguna vía de escritura
/// real en la app (ver la ADENDA de `empresa_pipeline_screen.dart`).
Future<ProcesoData> loadContrataciones() =>
    _loadPostulacionesPorEstado(_estadosContratado);

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
