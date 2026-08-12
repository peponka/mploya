import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/ai_match_service.dart';
import '../../utils/user_columns.dart';

/// Compatibilidad real entre un candidato y una vacante.
///
/// TODO lo que hay acá sale de la base. Lo que no existe, NO se calcula ni se
/// aproxima: el campo queda en null y la pantalla no lo dibuja.
@immutable
class MatchIaData {
  /// Porcentaje que devuelve la RPC `match_candidates_for_job`.
  ///
  /// Null si la vacante todavía no tiene embedding o si el candidato no entró
  /// en el ranking: en ese caso no hay match que mostrar, y no se inventa uno.
  final int? match;

  final String candidato;
  final String? candidatoHeadline;
  final String? candidatoAvatar;
  final String? candidatoCiudad;

  final String vacante;
  final String? empresa;
  final String? empresaAvatar;
  final String? empresaCiudad;

  /// Intersección real entre `jobs.tags` y `users.tags`.
  final List<String> skillsEnComun;

  /// Skills que pide la vacante y el candidato no declara.
  final List<String> skillsQueFaltan;

  /// Sólo si existen LOS DOS: `users.salary_expectation` y `jobs.salary_range`.
  final String? expectativaCandidato;
  final String? rangoVacante;

  /// Kilómetros entre candidato y empresa. Sólo si ambos tienen coordenadas.
  final double? distanciaKm;

  final bool error;

  const MatchIaData({
    this.match,
    this.candidato = 'Candidato',
    this.candidatoHeadline,
    this.candidatoAvatar,
    this.candidatoCiudad,
    this.vacante = '',
    this.empresa,
    this.empresaAvatar,
    this.empresaCiudad,
    this.skillsEnComun = const [],
    this.skillsQueFaltan = const [],
    this.expectativaCandidato,
    this.rangoVacante,
    this.distanciaKm,
    this.error = false,
  });

  static const vacia = MatchIaData();

  bool get haySalario =>
      expectativaCandidato != null && rangoVacante != null;

  bool get hayDistancia => distanciaKm != null;

  /// Etiqueta del match, con los mismos cortes que usa el resto de Empresa.
  String? get etiquetaMatch {
    final m = match;
    if (m == null) return null;
    if (m >= 80) return 'Match alto';
    if (m >= 60) return 'Match medio';
    return 'Match bajo';
  }
}

/// Distancia en kilómetros entre dos puntos (haversine).
///
/// Se expone para poder probarla sin base: es la única cuenta de esta pantalla.
double distanciaEnKm(double lat1, double lon1, double lat2, double lon2) {
  const radioTierra = 6371.0;
  double aRad(double g) => g * math.pi / 180.0;

  final dLat = aRad(lat2 - lat1);
  final dLon = aRad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(aRad(lat1)) *
          math.cos(aRad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return radioTierra * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Normaliza una etiqueta para poder compararlas sin depender de mayúsculas,
/// tildes de más o el `#` que a veces traen los tags.
String normalizarTag(String t) =>
    t.replaceAll('#', '').trim().toLowerCase();

/// Cruza los tags de la vacante con los del candidato.
///
/// Devuelve las coincidencias con el texto ORIGINAL de la vacante, que es el
/// que la empresa escribió y reconoce.
({List<String> comunes, List<String> faltantes}) cruzarSkills(
  List<String> tagsVacante,
  List<String> tagsCandidato,
) {
  final delCandidato = tagsCandidato.map(normalizarTag).toSet()
    ..removeWhere((t) => t.isEmpty);

  final comunes = <String>[];
  final faltantes = <String>[];
  final vistos = <String>{};

  for (final crudo in tagsVacante) {
    final norm = normalizarTag(crudo);
    if (norm.isEmpty || vistos.contains(norm)) continue;
    vistos.add(norm);
    final limpio = crudo.replaceAll('#', '').trim();
    if (delCandidato.contains(norm)) {
      comunes.add(limpio);
    } else {
      faltantes.add(limpio);
    }
  }

  return (comunes: comunes, faltantes: faltantes);
}

List<String> _listaDeTexto(dynamic raw) {
  if (raw is List) {
    return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
  }
  return const [];
}

String? _textoNoVacio(dynamic raw) {
  final s = raw?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}

/// Carga la compatibilidad real entre un candidato y una vacante.
Future<MatchIaData> loadMatchIa({
  required String jobId,
  required String candidatoId,
}) async {
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) {
    return const MatchIaData(error: true);
  }

  Map<String, dynamic>? vacante;
  Map<String, dynamic>? candidato;
  Map<String, dynamic>? empresa;

  try {
    vacante = await client
        .from('jobs')
        .select('id, title, tags, salary_range, company_id, company_name')
        .eq('id', jobId)
        .maybeSingle();
  } catch (e) {
    debugPrint('match ia · jobs: $e');
  }
  if (vacante == null) return const MatchIaData(error: true);

  try {
    candidato = await client
        .from('users')
        .select(kUserColumns)
        .eq('id', candidatoId)
        .maybeSingle();
  } catch (e) {
    debugPrint('match ia · users candidato: $e');
  }
  if (candidato == null) return const MatchIaData(error: true);

  final empresaId = vacante['company_id']?.toString();
  if (empresaId != null) {
    try {
      empresa = await client
          .from('users')
          .select(kUserColumns)
          .eq('id', empresaId)
          .maybeSingle();
    } catch (e) {
      debugPrint('match ia · users empresa: $e');
    }
  }

  // ── Match: el número lo pone la RPC, no esta pantalla ──
  //
  // `getCandidatesForJob` devuelve el ranking por similitud de embeddings de la
  // vacante. Se busca a ESTE candidato dentro del ranking. Si no está —porque
  // la vacante no tiene embedding, o porque quedó fuera del corte— no hay match
  // y se deja en null: dibujar un 0% sería mentir distinto.
  int? match;
  try {
    final ranking =
        await AIMatchService.instance.getCandidatesForJob(jobId, limit: 100);
    for (final fila in ranking) {
      final id = (fila['id'] ?? fila['user_id'] ?? fila['candidate_id'])
          ?.toString();
      if (id == candidatoId) {
        final p = fila['match_percentage'];
        if (p is num) match = p.round().clamp(0, 100);
        break;
      }
    }
  } catch (e) {
    debugPrint('match ia · ranking: $e');
  }

  // ── Skills ──
  final cruce = cruzarSkills(
    _listaDeTexto(vacante['tags']),
    _listaDeTexto(candidato['tags']),
  );

  // ── Salario: sólo con los dos datos ──
  final expectativa = _textoNoVacio(candidato['salary_expectation']);
  final rango = _textoNoVacio(vacante['salary_range']);
  final haySalario = expectativa != null && rango != null;

  // ── Distancia: sólo con las cuatro coordenadas ──
  double? km;
  final latC = (candidato['latitude'] as num?)?.toDouble();
  final lonC = (candidato['longitude'] as num?)?.toDouble();
  final latE = (empresa?['latitude'] as num?)?.toDouble();
  final lonE = (empresa?['longitude'] as num?)?.toDouble();
  if (latC != null && lonC != null && latE != null && lonE != null) {
    km = distanciaEnKm(latC, lonC, latE, lonE);
  }

  return MatchIaData(
    match: match,
    candidato: _textoNoVacio(candidato['name']) ?? 'Candidato',
    candidatoHeadline: _textoNoVacio(candidato['headline']),
    candidatoAvatar: _textoNoVacio(candidato['avatar_url']),
    candidatoCiudad:
        _textoNoVacio(candidato['city']) ?? _textoNoVacio(candidato['location']),
    vacante: _textoNoVacio(vacante['title']) ?? 'Vacante',
    empresa: _textoNoVacio(empresa?['company']) ??
        _textoNoVacio(vacante['company_name']) ??
        _textoNoVacio(empresa?['name']),
    empresaAvatar: _textoNoVacio(empresa?['avatar_url']),
    empresaCiudad:
        _textoNoVacio(empresa?['city']) ?? _textoNoVacio(empresa?['location']),
    skillsEnComun: cruce.comunes,
    skillsQueFaltan: cruce.faltantes,
    expectativaCandidato: haySalario ? expectativa : null,
    rangoVacante: haySalario ? rango : null,
    distanciaKm: km,
  );
}
