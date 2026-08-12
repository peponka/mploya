import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'empresa_vacantes_data.dart';

/// Una postulación real a la vacante (`public.job_applications` + perfil).
@immutable
class PostulanteVacante {
  final String applicationId;
  final String candidatoId;
  final String nombre;
  final String? headline;
  final String? avatarUrl;
  final List<String> tags;

  /// `job_applications.status` tal como lo devuelve la base. No se traduce a un
  /// vocabulario propio para no inventar estados que la base no tiene.
  final String? estado;

  final DateTime? postuladoEl;

  const PostulanteVacante({
    required this.applicationId,
    required this.candidatoId,
    required this.nombre,
    this.headline,
    this.avatarUrl,
    this.tags = const [],
    this.estado,
    this.postuladoEl,
  });
}

/// Detalle de UNA vacante propia de la empresa.
///
/// Todo lo que hay acá sale de la base. Los campos que la fila no trae quedan
/// en null y la pantalla directamente no dibuja esa sección.
@immutable
class VacanteDetalle {
  final Vacante vacante;

  final String? descripcion;
  final String? horario;
  final String? experiencia;
  final String? extras;

  final List<PostulanteVacante> postulantes;

  /// La consulta de postulaciones falló (permisos, red). Distinto de "no hay
  /// postulantes": la UI muestra "—", no un 0 que mentiría.
  final bool postulantesNoDisponibles;

  /// Entrevistas registradas para esta vacante. `null` = no se pudo consultar
  /// (la tabla puede no existir en la base). La UI omite el dato en ese caso.
  final int? entrevistas;

  /// La vacante no se pudo cargar.
  final bool error;

  const VacanteDetalle({
    required this.vacante,
    this.descripcion,
    this.horario,
    this.experiencia,
    this.extras,
    this.postulantes = const [],
    this.postulantesNoDisponibles = false,
    this.entrevistas,
    this.error = false,
  });

  /// Cantidad real de postulaciones. Prefiere la lista detallada; si no hubo
  /// acceso a ella cae al contador que ya traía la vacante.
  int get totalPostulantes =>
      postulantes.isNotEmpty ? postulantes.length : vacante.candidatos;

  bool get tieneDescripcion => (descripcion?.trim().isNotEmpty ?? false);
}

/// Carga el detalle de una vacante propia.
///
/// Tres consultas independientes y cada una tolera su propio fallo: si las
/// postulaciones no se pueden leer, la ficha igual se muestra.
Future<VacanteDetalle?> loadVacanteDetalle(String jobId) async {
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) return null;

  Map<String, dynamic>? fila;
  try {
    fila = await client.from('jobs').select().eq('id', jobId).maybeSingle();
  } catch (e) {
    debugPrint('detalle vacante · jobs: $e');
    return null;
  }
  if (fila == null) return null;

  // ── Postulaciones con el perfil del candidato ya unido ──
  final postulantes = <PostulanteVacante>[];
  var postulantesNoDisponibles = false;
  try {
    final filas = await client.rpc('get_company_candidates') as List<dynamic>;
    for (final raw in filas) {
      final p = raw as Map;
      if (p['job_id']?.toString() != jobId) continue;
      postulantes.add(
        PostulanteVacante(
          applicationId: p['application_id']?.toString() ?? '',
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
          estado: p['status']?.toString(),
          postuladoEl: DateTime.tryParse(p['applied_at']?.toString() ?? ''),
        ),
      );
    }
  } catch (e) {
    debugPrint('detalle vacante · get_company_candidates: $e');
    postulantesNoDisponibles = true;
  }

  // ── Entrevistas de esta vacante ──
  // `public.interviews` está en la migración 007, pero que una migración exista
  // en el repo NO prueba que esté aplicada. Si no está, se devuelve null.
  int? entrevistas;
  try {
    final filasEntrevistas =
        await client.from('interviews').select('id').eq('job_id', jobId);
    entrevistas = (filasEntrevistas as List).length;
  } catch (e) {
    debugPrint('detalle vacante · interviews: $e');
  }

  // El conteo de postulaciones ya lo tenemos detallado; si no hubo acceso se
  // consulta aparte para no dejar la ficha sin ningún número.
  var conteo = postulantes.length;
  if (postulantesNoDisponibles) {
    try {
      final apps =
          await client.from('job_applications').select('id').eq('job_id', jobId);
      conteo = (apps as List).length;
      postulantesNoDisponibles = false;
    } catch (e) {
      debugPrint('detalle vacante · job_applications: $e');
      conteo = 0;
    }
  }

  String? texto(Object? value) {
    final s = value?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  return VacanteDetalle(
    vacante: vacanteDesdeFila(
      fila,
      soportaEstados: fila.containsKey('is_active'),
      candidatos: conteo,
    ),
    descripcion: texto(fila['description']),
    horario: texto(fila['schedule']),
    experiencia: texto(fila['experience_level']),
    extras: texto(fila['extras']),
    postulantes: postulantes,
    postulantesNoDisponibles: postulantesNoDisponibles,
    entrevistas: entrevistas,
  );
}

/// Pausa o reactiva la vacante escribiendo `jobs.is_active`.
///
/// Devuelve `true` si la base aceptó el cambio. Si la columna no existe o RLS
/// lo bloquea, devuelve `false` y la pantalla avisa en vez de mentir con un
/// cambio local que no persistió.
Future<bool> setVacanteActiva(String jobId, bool activa) async {
  try {
    await Supabase.instance.client
        .from('jobs')
        .update({'is_active': activa})
        .eq('id', jobId);
    return true;
  } catch (e) {
    debugPrint('detalle vacante · update is_active: $e');
    return false;
  }
}
