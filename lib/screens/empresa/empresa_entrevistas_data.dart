import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'empresa_informe_entrevista_data.dart';

/// De dónde sale la entrevista.
///
/// El proyecto tiene DOS sistemas distintos y no intercambiables:
///   · `scheduled_interviews` + `interview_slots` → entrevista en vivo, con
///     fecha y hora. Es lo que dibuja la agenda.
///   · `interviews` (+ preguntas/respuestas/informe, migración 007) → entrevista
///     asíncrona con IA. No tiene fecha agendada: tiene estado.
enum FuenteEntrevista { agenda, ia }

@immutable
class EntrevistaEmpresa {
  final String id;
  final FuenteEntrevista fuente;

  final String? candidatoId;
  final String candidato;
  final String? candidatoAvatar;
  final String? candidatoHeadline;

  final String? vacanteId;
  final String? vacante;

  /// Fecha y hora agendadas. Null en las entrevistas con IA.
  final DateTime? cuando;

  final int? duracionMinutos;

  /// Estado tal como lo guarda la base ('confirmed', 'pending', 'completed'…).
  final String estado;

  final String? meetingUrl;

  const EntrevistaEmpresa({
    required this.id,
    required this.fuente,
    required this.candidato,
    required this.estado,
    this.candidatoId,
    this.candidatoAvatar,
    this.candidatoHeadline,
    this.vacanteId,
    this.vacante,
    this.cuando,
    this.duracionMinutos,
    this.meetingUrl,
  });

  bool get cancelada => estado.toLowerCase() == 'cancelled';

  bool esDelDia(DateTime dia) {
    final c = cuando;
    if (c == null) return false;
    return c.year == dia.year && c.month == dia.month && c.day == dia.day;
  }
}

@immutable
class EntrevistasData {
  final List<EntrevistaEmpresa> agenda;
  final List<EntrevistaEmpresa> conIa;

  /// Ids de entrevistas con IA que YA tienen informe generado en
  /// `interview_reports`. La agenda sólo ofrece "ver informe" para éstas: sin
  /// fila no hay nada que mostrar y el acceso sería un botón muerto.
  final Set<String> conInforme;

  /// `scheduled_interviews` no se pudo leer (puede no existir en la base).
  final bool agendaNoDisponible;

  /// `interviews` no se pudo leer.
  final bool iaNoDisponible;

  const EntrevistasData({
    this.conInforme = const {},
    this.agenda = const [],
    this.conIa = const [],
    this.agendaNoDisponible = false,
    this.iaNoDisponible = false,
  });

  static const empty = EntrevistasData();

  /// Nada que mostrar y ninguna fuente rota: agenda realmente vacía.
  bool get vacia =>
      agenda.isEmpty &&
      conIa.isEmpty &&
      !agendaNoDisponible &&
      !iaNoDisponible;

  bool get todoRoto => agendaNoDisponible && iaNoDisponible;

  List<EntrevistaEmpresa> del(DateTime dia) {
    final lista = agenda.where((e) => e.esDelDia(dia)).toList()
      ..sort((a, b) => a.cuando!.compareTo(b.cuando!));
    return lista;
  }

  int get hoy {
    final ahora = DateTime.now();
    return agenda.where((e) => !e.cancelada && e.esDelDia(ahora)).length;
  }

  int get estaSemana {
    final ahora = DateTime.now();
    final inicio = DateTime(ahora.year, ahora.month, ahora.day)
        .subtract(Duration(days: ahora.weekday - 1));
    final fin = inicio.add(const Duration(days: 7));
    return agenda.where((e) {
      final c = e.cuando;
      if (c == null || e.cancelada) return false;
      return !c.isBefore(inicio) && c.isBefore(fin);
    }).length;
  }

  int get proximas {
    final ahora = DateTime.now();
    return agenda
        .where((e) => !e.cancelada && (e.cuando?.isAfter(ahora) ?? false))
        .length;
  }

  /// Próxima entrevista futura, si hay.
  EntrevistaEmpresa? get siguiente {
    final ahora = DateTime.now();
    final futuras = agenda
        .where((e) => !e.cancelada && (e.cuando?.isAfter(ahora) ?? false))
        .toList()
      ..sort((a, b) => a.cuando!.compareTo(b.cuando!));
    return futuras.isEmpty ? null : futuras.first;
  }
}

DateTime? _fechaHora(Object? fecha, Object? hora) {
  final f = fecha?.toString() ?? '';
  if (f.isEmpty) return null;
  final h = (hora?.toString() ?? '00:00:00');
  return DateTime.tryParse('${f.substring(0, 10)} $h') ?? DateTime.tryParse(f);
}

/// Entrevistas reales de la empresa autenticada.
///
/// Cada fuente se consulta por separado y falla por separado: que la agenda no
/// esté disponible no puede tumbar la pantalla entera.
Future<EntrevistasData> loadEmpresaEntrevistas() async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return EntrevistasData.empty;

  // ── Vacantes propias: sirven para titular las entrevistas ──
  final tituloDeVacante = <String, String>{};
  try {
    final filas = await client
        .from('jobs')
        .select('id, title')
        .eq('company_id', uid);
    for (final f in filas as List) {
      tituloDeVacante[f['id'].toString()] = f['title']?.toString() ?? '';
    }
  } catch (e) {
    debugPrint('entrevistas · jobs: $e');
  }

  // ── Perfiles de candidato, para poner nombre y avatar ──
  final perfiles = <String, Map<String, dynamic>>{};
  Future<void> cargarPerfiles(Set<String> ids) async {
    if (ids.isEmpty) return;
    try {
      final filas = await client
          .from('users')
          .select('id, name, headline, avatar_url')
          .inFilter('id', ids.toList());
      for (final f in filas as List) {
        perfiles[f['id'].toString()] = Map<String, dynamic>.from(f as Map);
      }
    } catch (e) {
      debugPrint('entrevistas · users: $e');
    }
  }

  // ── Agenda: entrevistas con fecha ──
  final agenda = <EntrevistaEmpresa>[];
  var agendaNoDisponible = false;
  List<dynamic> filasAgenda = const [];
  try {
    filasAgenda = await client
        .from('scheduled_interviews')
        .select()
        .eq('company_id', uid)
        .order('scheduled_date') as List<dynamic>;
  } catch (e) {
    debugPrint('entrevistas · scheduled_interviews: $e');
    agendaNoDisponible = true;
  }

  // ── Entrevistas con IA: sin fecha, con estado ──
  final conIa = <EntrevistaEmpresa>[];
  var iaNoDisponible = false;
  List<dynamic> filasIa = const [];
  if (tituloDeVacante.isNotEmpty) {
    try {
      filasIa = await client
          .from('interviews')
          .select()
          .inFilter('job_id', tituloDeVacante.keys.toList())
          .order('created_at', ascending: false) as List<dynamic>;
    } catch (e) {
      debugPrint('entrevistas · interviews: $e');
      iaNoDisponible = true;
    }
  }

  await cargarPerfiles({
    for (final f in filasAgenda)
      if ((f as Map)['candidate_id'] != null) f['candidate_id'].toString(),
    for (final f in filasIa)
      if ((f as Map)['candidate_id'] != null) f['candidate_id'].toString(),
  });

  String nombre(String? id) =>
      perfiles[id]?['name']?.toString() ?? 'Candidato';

  String? avatar(String? id) {
    final v = perfiles[id]?['avatar_url']?.toString() ?? '';
    return v.isEmpty ? null : v;
  }

  String? headline(String? id) {
    final v = perfiles[id]?['headline']?.toString() ?? '';
    return v.isEmpty ? null : v;
  }

  for (final raw in filasAgenda) {
    final f = raw as Map;
    final candidatoId = f['candidate_id']?.toString();
    agenda.add(
      EntrevistaEmpresa(
        id: f['id']?.toString() ?? '',
        fuente: FuenteEntrevista.agenda,
        candidatoId: candidatoId,
        candidato: nombre(candidatoId),
        candidatoAvatar: avatar(candidatoId),
        candidatoHeadline: headline(candidatoId),
        cuando: _fechaHora(f['scheduled_date'], f['scheduled_time']),
        duracionMinutos: (f['duration_minutes'] as num?)?.toInt(),
        estado: f['status']?.toString() ?? 'pending',
        meetingUrl: (f['meeting_url']?.toString().isNotEmpty ?? false)
            ? f['meeting_url'].toString()
            : null,
      ),
    );
  }

  for (final raw in filasIa) {
    final f = raw as Map;
    final candidatoId = f['candidate_id']?.toString();
    final jobId = f['job_id']?.toString();
    conIa.add(
      EntrevistaEmpresa(
        id: f['id']?.toString() ?? '',
        fuente: FuenteEntrevista.ia,
        candidatoId: candidatoId,
        candidato: nombre(candidatoId),
        candidatoAvatar: avatar(candidatoId),
        candidatoHeadline: headline(candidatoId),
        vacanteId: jobId,
        vacante: tituloDeVacante[jobId],
        estado: f['status']?.toString() ?? 'pending',
      ),
    );
  }

  agenda.sort((a, b) {
    final ca = a.cuando, cb = b.cuando;
    if (ca == null || cb == null) return 0;
    return ca.compareTo(cb);
  });

  // Una sola consulta para saber cuáles tienen informe.
  final conInforme = await loadEntrevistasConInforme(
    [for (final e in conIa) e.id],
  );

  return EntrevistasData(
    agenda: agenda,
    conIa: conIa,
    conInforme: conInforme,
    agendaNoDisponible: agendaNoDisponible,
    iaNoDisponible: iaNoDisponible,
  );
}
