import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../utils/user_columns.dart';

/// Un resultado de la búsqueda de talento.
@immutable
class ResultadoTalento {
  final NexUser usuario;

  /// Match 0–100 cuando el resultado vino del motor de embeddings.
  /// `null` en la búsqueda por texto: ahí no hay score que mostrar.
  final int? match;

  const ResultadoTalento({required this.usuario, this.match});

  bool get confidencial {
    final tipo = usuario.accountType.toLowerCase();
    return tipo.startsWith('confidenc') || tipo == 'stealth';
  }

  String get nombreVisible =>
      confidencial ? 'Candidato confidencial' : usuario.name;
}

/// Cómo se buscó. Cambia lo que la UI puede afirmar sobre los resultados.
enum ModoBusqueda {
  /// Coincidencia de texto sobre nombre, titular y etiquetas.
  texto,

  /// Recomendación por embeddings (`match_users_by_embedding`).
  ia,
}

@immutable
class BusquedaData {
  final List<ResultadoTalento> resultados;
  final ModoBusqueda modo;
  final bool error;

  /// La búsqueda IA no pudo correr porque el perfil de la empresa todavía no
  /// tiene embedding. No es un error: es un requisito que falta.
  final bool sinEmbedding;

  const BusquedaData({
    required this.resultados,
    required this.modo,
    this.error = false,
    this.sinEmbedding = false,
  });

  static const vacia =
      BusquedaData(resultados: [], modo: ModoBusqueda.texto);

  int get total => resultados.length;
}

/// Etiquetas más frecuentes entre los candidatos. Sirven de filtros rápidos
/// REALES: son las que de verdad existen en la base, no una lista escrita a mano.
Future<List<String>> loadEtiquetasFrecuentes({int limite = 12}) async {
  try {
    final filas = await Supabase.instance.client
        .from('accessible_user_profiles')
        .select('tags')
        .not('tags', 'is', null)
        .limit(300) as List<dynamic>;

    final conteo = <String, int>{};
    for (final f in filas) {
      for (final t in ((f as Map)['tags'] as List? ?? const [])) {
        final tag = t.toString().replaceAll('#', '').trim();
        if (tag.isEmpty) continue;
        conteo[tag] = (conteo[tag] ?? 0) + 1;
      }
    }

    final ordenadas = conteo.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ordenadas.take(limite).map((e) => e.key).toList();
  } catch (e) {
    debugPrint('busqueda · etiquetas: $e');
    return const [];
  }
}

/// Búsqueda por texto sobre candidatos.
///
/// Es el mismo patrón que ya usa `SearchService`: `ilike` sobre nombre y
/// titular, más coincidencia por etiqueta. No hay score: ordenar por
/// "relevancia" inventada sería mentir sobre el criterio.
Future<BusquedaData> buscarTalentoPorTexto(
  String query, {
  List<String> etiquetas = const [],
}) async {
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) return BusquedaData.vacia;

  final q = query.trim();
  if (q.isEmpty && etiquetas.isEmpty) return BusquedaData.vacia;

  try {
    var consulta = client.from('accessible_user_profiles').select(kUserColumns);

    if (q.isNotEmpty) {
      final patron = '%$q%';
      consulta = consulta.or('name.ilike.$patron,headline.ilike.$patron');
    }
    if (etiquetas.isNotEmpty) {
      consulta = consulta.overlaps('tags', etiquetas);
    }

    final filas = await consulta.limit(40) as List<dynamic>;

    final resultados = <ResultadoTalento>[];
    for (final f in filas) {
      final fila = Map<String, dynamic>.from(f as Map);
      final tipo = fila['account_type']?.toString().toLowerCase() ?? '';
      // La búsqueda de talento busca personas, no empresas ni headhunters.
      if (tipo == 'empresa' || tipo == 'headhunter') continue;
      if (fila['deleted_at'] != null) continue;
      resultados.add(ResultadoTalento(usuario: NexUser.fromJson(fila)));
    }

    return BusquedaData(resultados: resultados, modo: ModoBusqueda.texto);
  } catch (e) {
    debugPrint('busqueda · texto: $e');
    return const BusquedaData(
      resultados: [],
      modo: ModoBusqueda.texto,
      error: true,
    );
  }
}

/// Recomendación por embeddings: a quién se parece más lo que busca la empresa.
///
/// Usa `match_users_by_embedding`, el mismo RPC calibrado de la migración 019.
/// Devuelve el score real, no uno estimado.
Future<BusquedaData> buscarTalentoConIa({int limite = 20}) async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return BusquedaData.vacia;

  try {
    final filas = await client.rpc(
      'match_users_by_embedding',
      params: {'p_user_id': uid, 'p_limit': limite},
    ) as List<dynamic>;

    if (filas.isEmpty) {
      return const BusquedaData(
        resultados: [],
        modo: ModoBusqueda.ia,
        sinEmbedding: true,
      );
    }

    final resultados = <ResultadoTalento>[];
    for (final raw in filas) {
      final m = Map<String, dynamic>.from(raw as Map);
      final sim = (m['similarity'] as num?)?.toDouble();
      resultados.add(
        ResultadoTalento(
          usuario: NexUser.fromJson({
            'id': m['id'],
            'name': m['name'],
            'headline': m['headline'],
            'avatar_url': m['avatar_url'],
            'account_type': m['account_type'],
            'tags': m['tags'],
          }),
          match: sim == null ? null : (sim * 100).round(),
        ),
      );
    }

    return BusquedaData(resultados: resultados, modo: ModoBusqueda.ia);
  } catch (e) {
    debugPrint('busqueda · match_users_by_embedding: $e');
    return const BusquedaData(
      resultados: [],
      modo: ModoBusqueda.ia,
      error: true,
    );
  }
}
