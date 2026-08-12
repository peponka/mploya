import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'empresa_vacante_detalle_data.dart';

/// Bandas de ajuste. NO son un dato de la base: son una lectura del score real
/// que devuelve `match_candidates_for_job`, con los cortes escritos acá para
/// que la UI no tenga números mágicos sueltos.
///
/// Los cortes salen de la calibración documentada en la migración 019
/// (mediana→0, p99→100 sobre 300 pares reales): con esa escala, 60+ es un match
/// que vale la pena mirar y por debajo de 35 es ruido.
enum BandaAjuste { alta, media, baja }

extension BandaInfo on BandaAjuste {
  String get etiqueta => switch (this) {
        BandaAjuste.alta => 'Alta compatibilidad',
        BandaAjuste.media => 'Compatibilidad media',
        BandaAjuste.baja => 'Compatibilidad baja',
      };

  static BandaAjuste de(double score) {
    if (score >= 0.60) return BandaAjuste.alta;
    if (score >= 0.35) return BandaAjuste.media;
    return BandaAjuste.baja;
  }
}

/// Un candidato de la shortlist de una vacante.
///
/// [match], [semantico] y [skills] vienen tal cual del RPC (0–1). Si el RPC no
/// devolvió a esta persona —por ejemplo porque se postuló pero no tiene
/// embedding— quedan en null y la UI NO dibuja porcentaje.
@immutable
class CandidatoShortlist {
  final String id;
  final String nombre;
  final String? headline;
  final String? avatarUrl;
  final List<String> tags;
  final String accountType;

  final double? match;
  final double? semantico;
  final double? skills;

  /// Se postuló realmente a esta vacante (`job_applications`).
  final bool postulado;

  /// `job_applications.status` cuando se postuló.
  final String? estadoPostulacion;

  const CandidatoShortlist({
    required this.id,
    required this.nombre,
    this.headline,
    this.avatarUrl,
    this.tags = const [],
    this.accountType = 'candidato',
    this.match,
    this.semantico,
    this.skills,
    this.postulado = false,
    this.estadoPostulacion,
  });

  bool get confidencial =>
      accountType.toLowerCase().startsWith('confidenc') ||
      accountType.toLowerCase() == 'stealth';

  /// Nombre a mostrar: un perfil confidencial no expone identidad.
  String get nombreVisible => confidencial ? 'Candidato confidencial' : nombre;

  int? get matchPct => match == null ? null : (match! * 100).round();

  BandaAjuste? get banda => match == null ? null : BandaInfo.de(match!);
}

@immutable
class ShortlistData {
  final List<CandidatoShortlist> candidatos;

  /// El RPC de match no se pudo ejecutar. Distinto de "no devolvió a nadie".
  final bool matchError;

  /// El RPC corrió pero no devolvió candidatos por encima del umbral. Puede ser
  /// que la vacante todavía no tenga embedding o que no haya perfiles afines.
  final bool sinMatch;

  const ShortlistData({
    required this.candidatos,
    this.matchError = false,
    this.sinMatch = false,
  });

  static const empty = ShortlistData(candidatos: [], sinMatch: true);

  List<CandidatoShortlist> get conMatch =>
      candidatos.where((c) => c.match != null).toList();

  int get total => candidatos.length;

  /// Promedio del ajuste sobre quienes SÍ tienen match. Null si no hay ninguno.
  double? get ajustePromedio {
    final lista = conMatch;
    if (lista.isEmpty) return null;
    final suma = lista.fold<double>(0, (s, c) => s + c.match!);
    return suma / lista.length;
  }

  double? get mejorAjuste {
    final lista = conMatch;
    if (lista.isEmpty) return null;
    return lista.map((c) => c.match!).reduce((a, b) => a > b ? a : b);
  }

  int enBanda(BandaAjuste banda) =>
      candidatos.where((c) => c.banda == banda).length;

  int get postulados => candidatos.where((c) => c.postulado).length;
}

/// Construye un candidato de shortlist a partir de una postulación real.
/// Sin match: la postulación no trae score.
CandidatoShortlist candidatoDesdePostulante(PostulanteVacante p) {
  return CandidatoShortlist(
    id: p.candidatoId,
    nombre: p.nombre,
    headline: p.headline,
    avatarUrl: p.avatarUrl,
    tags: p.tags,
    postulado: true,
    estadoPostulacion: p.estado,
  );
}

/// Shortlist real de una vacante.
///
/// Dos fuentes, ambas reales:
///   1. `match_candidates_for_job` — ranking por embedding + skills (mig. 019).
///   2. `get_company_candidates`   — quién se postuló de verdad.
///
/// Se fusionan por id: quien está en las dos conserva su score y además queda
/// marcado como postulante. No se inventa score para quien no lo tiene.
Future<ShortlistData> loadShortlist(String jobId, {int limite = 20}) async {
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) return ShortlistData.empty;

  final porId = <String, CandidatoShortlist>{};
  var matchError = false;
  var sinMatch = false;

  try {
    final filas = await client.rpc(
      'match_candidates_for_job',
      params: {'p_job_id': jobId, 'p_limit': limite},
    ) as List<dynamic>;

    if (filas.isEmpty) sinMatch = true;

    for (final raw in filas) {
      final m = raw as Map;
      final id = m['id']?.toString() ?? '';
      if (id.isEmpty) continue;

      porId[id] = CandidatoShortlist(
        id: id,
        nombre: m['name']?.toString() ?? 'Candidato',
        headline: (m['headline']?.toString().isNotEmpty ?? false)
            ? m['headline'].toString()
            : null,
        avatarUrl: (m['avatar_url']?.toString().isNotEmpty ?? false)
            ? m['avatar_url'].toString()
            : null,
        tags: [
          for (final t in (m['tags'] as List? ?? const []))
            t.toString().replaceAll('#', '').trim(),
        ]..removeWhere((t) => t.isEmpty),
        accountType: m['account_type']?.toString() ?? 'candidato',
        match: (m['similarity'] as num?)?.toDouble(),
        semantico: (m['semantic_score'] as num?)?.toDouble(),
        skills: (m['skill_score'] as num?)?.toDouble(),
      );
    }
  } catch (e) {
    debugPrint('shortlist · match_candidates_for_job: $e');
    matchError = true;
  }

  // Postulantes reales: entran aunque no tengan score, y marcan a los que ya
  // estaban en el ranking.
  try {
    final filas = await client.rpc('get_company_candidates') as List<dynamic>;
    for (final raw in filas) {
      final p = raw as Map;
      if (p['job_id']?.toString() != jobId) continue;

      final id = p['candidate_id']?.toString() ?? '';
      if (id.isEmpty) continue;

      final previo = porId[id];
      porId[id] = CandidatoShortlist(
        id: id,
        nombre: previo?.nombre ?? p['candidate_name']?.toString() ?? 'Candidato',
        headline: previo?.headline ??
            ((p['candidate_headline']?.toString().isNotEmpty ?? false)
                ? p['candidate_headline'].toString()
                : null),
        avatarUrl: previo?.avatarUrl ??
            ((p['candidate_avatar_url']?.toString().isNotEmpty ?? false)
                ? p['candidate_avatar_url'].toString()
                : null),
        tags: previo?.tags ??
            ([
              for (final t in (p['candidate_tags'] as List? ?? const []))
                t.toString().replaceAll('#', '').trim(),
            ]..removeWhere((t) => t.isEmpty)),
        accountType: previo?.accountType ?? 'candidato',
        match: previo?.match,
        semantico: previo?.semantico,
        skills: previo?.skills,
        postulado: true,
        estadoPostulacion: p['status']?.toString(),
      );
    }
  } catch (e) {
    debugPrint('shortlist · get_company_candidates: $e');
  }

  final candidatos = porId.values.toList()
    ..sort((a, b) {
      // Con score manda el score; sin score, primero los que se postularon.
      final ma = a.match, mb = b.match;
      if (ma != null && mb != null) return mb.compareTo(ma);
      if (ma != null) return -1;
      if (mb != null) return 1;
      if (a.postulado != b.postulado) return a.postulado ? -1 : 1;
      return a.nombre.compareTo(b.nombre);
    });

  return ShortlistData(
    candidatos: candidatos,
    matchError: matchError,
    sinMatch: sinMatch && candidatos.every((c) => c.match == null),
  );
}
