import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'empresa_match_ia_data.dart' show distanciaEnKm, normalizarTag;

/// Filtros de búsqueda de talento.
///
/// CADA CAMPO DE ESTA CLASE MODIFICA LA CONSULTA. No hay ninguno decorativo: si
/// no se podía filtrar de verdad por algo, no está acá y no se dibuja.
@immutable
class FiltrosTalento {
  /// Se compara contra `users.headline` (ilike).
  final String texto;

  /// Se cruzan contra `users.tags` (overlaps).
  final List<String> skills;

  /// Se compara contra `users.city` (ilike).
  final String ciudad;

  /// Kilómetros desde la empresa. Sólo se aplica si la empresa Y el candidato
  /// tienen coordenadas; se calcula sobre los resultados, porque Postgrest no
  /// expone la distancia sin PostGIS del lado del cliente.
  final int? radioKm;

  /// `users.open_to_work = true`.
  final bool soloDisponibles;

  /// `users.is_verified = true`.
  final bool soloVerificados;

  /// `users.salary_expectation` no nulo. NO hay rango numérico: la columna es
  /// texto libre ("USD 2.500", "a convenir", "2000-2500"), así que un slider
  /// sería una mentira prolija. Lo único honesto es saber si lo declaró.
  final bool soloConExpectativa;

  const FiltrosTalento({
    this.texto = '',
    this.skills = const [],
    this.ciudad = '',
    this.radioKm,
    this.soloDisponibles = false,
    this.soloVerificados = false,
    this.soloConExpectativa = false,
  });

  static const vacios = FiltrosTalento();

  bool get hayAlguno =>
      texto.trim().isNotEmpty ||
      skills.isNotEmpty ||
      ciudad.trim().isNotEmpty ||
      radioKm != null ||
      soloDisponibles ||
      soloVerificados ||
      soloConExpectativa;

  int get cantidad =>
      (texto.trim().isEmpty ? 0 : 1) +
      skills.length +
      (ciudad.trim().isEmpty ? 0 : 1) +
      (radioKm == null ? 0 : 1) +
      (soloDisponibles ? 1 : 0) +
      (soloVerificados ? 1 : 0) +
      (soloConExpectativa ? 1 : 0);

  FiltrosTalento copyWith({
    String? texto,
    List<String>? skills,
    String? ciudad,
    int? radioKm,
    bool limpiarRadio = false,
    bool? soloDisponibles,
    bool? soloVerificados,
    bool? soloConExpectativa,
  }) {
    return FiltrosTalento(
      texto: texto ?? this.texto,
      skills: skills ?? this.skills,
      ciudad: ciudad ?? this.ciudad,
      radioKm: limpiarRadio ? null : (radioKm ?? this.radioKm),
      soloDisponibles: soloDisponibles ?? this.soloDisponibles,
      soloVerificados: soloVerificados ?? this.soloVerificados,
      soloConExpectativa: soloConExpectativa ?? this.soloConExpectativa,
    );
  }

  /// Etiquetas de los filtros activos, con la clave para poder quitar uno solo.
  List<({String clave, String etiqueta})> get activos {
    final r = <({String clave, String etiqueta})>[];
    if (texto.trim().isNotEmpty) {
      r.add((clave: 'texto', etiqueta: '"${texto.trim()}"'));
    }
    for (final s in skills) {
      r.add((clave: 'skill:$s', etiqueta: s));
    }
    if (ciudad.trim().isNotEmpty) {
      r.add((clave: 'ciudad', etiqueta: ciudad.trim()));
    }
    if (radioKm != null) {
      r.add((clave: 'radio', etiqueta: 'Hasta $radioKm km'));
    }
    if (soloDisponibles) {
      r.add((clave: 'disponibles', etiqueta: 'Disponibles'));
    }
    if (soloVerificados) {
      r.add((clave: 'verificados', etiqueta: 'Verificados'));
    }
    if (soloConExpectativa) {
      r.add((clave: 'expectativa', etiqueta: 'Con expectativa'));
    }
    return r;
  }

  /// Quita un filtro por su clave, sin tocar los demás.
  FiltrosTalento sin(String clave) {
    if (clave == 'texto') return copyWith(texto: '');
    if (clave == 'ciudad') return copyWith(ciudad: '');
    if (clave == 'radio') return copyWith(limpiarRadio: true);
    if (clave == 'disponibles') return copyWith(soloDisponibles: false);
    if (clave == 'verificados') return copyWith(soloVerificados: false);
    if (clave == 'expectativa') return copyWith(soloConExpectativa: false);
    if (clave.startsWith('skill:')) {
      final s = clave.substring(6);
      return copyWith(skills: [...skills]..remove(s));
    }
    return this;
  }
}

/// Un candidato tal como lo devuelve la búsqueda.
@immutable
class TalentoEncontrado {
  final String id;
  final String nombre;
  final String? headline;
  final String? avatarUrl;
  final String? ciudad;
  final List<String> tags;
  final bool verificado;
  final bool disponible;
  final String? expectativa;

  /// Distancia a la empresa. Null si falta alguna coordenada.
  final double? distanciaKm;

  const TalentoEncontrado({
    required this.id,
    required this.nombre,
    this.headline,
    this.avatarUrl,
    this.ciudad,
    this.tags = const [],
    this.verificado = false,
    this.disponible = false,
    this.expectativa,
    this.distanciaKm,
  });
}

@immutable
class ResultadoBusqueda {
  final List<TalentoEncontrado> talentos;
  final bool error;

  /// La empresa no tiene coordenadas, así que el filtro por radio no se puede
  /// aplicar. Se avisa en vez de devolver una lista silenciosamente recortada.
  final bool sinCoordenadasPropias;

  const ResultadoBusqueda({
    this.talentos = const [],
    this.error = false,
    this.sinCoordenadasPropias = false,
  });

  static const vacio = ResultadoBusqueda();
}

const _kColumnas =
    'id, name, headline, avatar_url, city, tags, is_verified, open_to_work, '
    'salary_expectation, latitude, longitude, account_type, deleted_at';

/// Busca talento aplicando los filtros CONTRA LA BASE.
///
/// Todo lo que se puede resolver en Postgrest se resuelve ahí (ilike, overlaps,
/// eq, not.is.null). El radio es la única excepción: se calcula sobre las filas
/// devueltas, porque necesita las coordenadas de la empresa y una cuenta que la
/// consulta no puede hacer sin PostGIS expuesto.
Future<ResultadoBusqueda> buscarTalento(
  FiltrosTalento f, {
  int limite = 60,
}) async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return const ResultadoBusqueda(error: true);

  // Coordenadas propias: sólo hacen falta si se filtra por radio.
  double? latEmpresa;
  double? lonEmpresa;
  if (f.radioKm != null) {
    try {
      final yo = await client
          .from('users')
          .select('latitude, longitude')
          .eq('id', uid)
          .maybeSingle();
      latEmpresa = (yo?['latitude'] as num?)?.toDouble();
      lonEmpresa = (yo?['longitude'] as num?)?.toDouble();
    } catch (e) {
      debugPrint('filtros · coords propias: $e');
    }
  }

  try {
    var q = client
        .from('users')
        .select(_kColumnas)
        .eq('account_type', 'candidato')
        .isFilter('deleted_at', null);

    final texto = f.texto.trim();
    if (texto.isNotEmpty) q = q.ilike('headline', '%$texto%');

    final ciudad = f.ciudad.trim();
    if (ciudad.isNotEmpty) q = q.ilike('city', '%$ciudad%');

    if (f.skills.isNotEmpty) {
      q = q.overlaps('tags', f.skills);
    }
    if (f.soloDisponibles) q = q.eq('open_to_work', true);
    if (f.soloVerificados) q = q.eq('is_verified', true);
    if (f.soloConExpectativa) q = q.not('salary_expectation', 'is', null);

    final filas = await q.limit(limite) as List<dynamic>;

    final talentos = <TalentoEncontrado>[];
    for (final raw in filas) {
      final m = raw as Map<String, dynamic>;

      double? km;
      final lat = (m['latitude'] as num?)?.toDouble();
      final lon = (m['longitude'] as num?)?.toDouble();
      if (latEmpresa != null && lonEmpresa != null && lat != null && lon != null) {
        km = distanciaEnKm(latEmpresa, lonEmpresa, lat, lon);
      }

      // Radio: si se pidió y se puede calcular, se aplica de verdad.
      if (f.radioKm != null && latEmpresa != null && lonEmpresa != null) {
        if (km == null || km > f.radioKm!) continue;
      }

      final nombre = m['name']?.toString().trim() ?? '';
      talentos.add(
        TalentoEncontrado(
          id: m['id'].toString(),
          nombre: nombre.isEmpty ? 'Candidato' : nombre,
          headline: _texto(m['headline']),
          avatarUrl: _texto(m['avatar_url']),
          ciudad: _texto(m['city']),
          tags: (m['tags'] as List?)
                  ?.map((e) => e.toString().replaceAll('#', '').trim())
                  .where((e) => e.isNotEmpty)
                  .toList() ??
              const [],
          verificado: m['is_verified'] == true,
          disponible: m['open_to_work'] == true,
          expectativa: _texto(m['salary_expectation']),
          distanciaKm: km,
        ),
      );
    }

    // Con radio activo, lo más cerca primero: es el orden que pidió el usuario
    // al poner el filtro.
    if (f.radioKm != null) {
      talentos.sort((a, b) =>
          (a.distanciaKm ?? 1e9).compareTo(b.distanciaKm ?? 1e9));
    }

    return ResultadoBusqueda(
      talentos: talentos,
      sinCoordenadasPropias:
          f.radioKm != null && (latEmpresa == null || lonEmpresa == null),
    );
  } catch (e) {
    debugPrint('filtros · buscarTalento: $e');
    return const ResultadoBusqueda(error: true);
  }
}

String? _texto(dynamic raw) {
  final s = raw?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}

/// Sugerencias de skills para los chips: los tags REALES más usados por los
/// candidatos, no una lista escrita a mano.
Future<List<String>> sugerenciasDeSkills({int limite = 12}) async {
  try {
    final filas = await Supabase.instance.client
        .from('users')
        .select('tags')
        .eq('account_type', 'candidato')
        .limit(300) as List<dynamic>;

    final cuenta = <String, int>{};
    final original = <String, String>{};
    for (final raw in filas) {
      for (final t in ((raw as Map)['tags'] as List? ?? const [])) {
        final limpio = t.toString().replaceAll('#', '').trim();
        if (limpio.isEmpty) continue;
        final k = normalizarTag(limpio);
        cuenta[k] = (cuenta[k] ?? 0) + 1;
        original.putIfAbsent(k, () => limpio);
      }
    }

    final ordenados = cuenta.keys.toList()
      ..sort((a, b) => cuenta[b]!.compareTo(cuenta[a]!));
    return ordenados.take(limite).map((k) => original[k]!).toList();
  } catch (e) {
    debugPrint('filtros · sugerencias: $e');
    return const [];
  }
}
