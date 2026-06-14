import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SearchService — Búsqueda de usuarios/empresas con debounce y sugerencias
//
// Provee:
//  • search()           — Búsqueda con debounce de 350ms
//  • suggestions        — Stream de resultados de búsqueda
//  • getRecent()        — Últimas búsquedas (local)
//  • getTrending()      — Tags/hashtags trending
//
// El debounce evita hacer queries mientras el usuario escribe rápido.
// Los resultados vienen paginados (20 por batch) y ordenados por relevancia.
// ─────────────────────────────────────────────────────────────────────────────

class SearchService {
  SearchService._();
  static final SearchService instance = SearchService._();

  SupabaseClient get _db => Supabase.instance.client;

  Timer? _debounceTimer;
  String _lastQuery = '';

  /// Stream de resultados de búsqueda.
  final _resultsController = StreamController<SearchResults>.broadcast();
  Stream<SearchResults> get resultsStream => _resultsController.stream;

  /// Últimas búsquedas locales (no persisten entre sesiones).
  final List<String> _recentSearches = [];
  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  /// Ejecuta una búsqueda con debounce.
  /// Se cancela automáticamente si el usuario sigue escribiendo.
  void search(String query, {Duration debounce = const Duration(milliseconds: 350)}) {
    _debounceTimer?.cancel();

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _resultsController.add(SearchResults.empty());
      return;
    }

    if (trimmed == _lastQuery) return; // Skip si no cambió

    _resultsController.add(SearchResults(isLoading: true));

    _debounceTimer = Timer(debounce, () {
      _executeSearch(trimmed);
    });
  }

  /// Cancela la búsqueda pendiente.
  void cancel() {
    _debounceTimer?.cancel();
    _resultsController.add(SearchResults.empty());
  }

  Future<void> _executeSearch(String query) async {
    _lastQuery = query;

    try {
      // Búsqueda por nombre, headline, tags (case-insensitive, partial match)
      final pattern = '%$query%';

      final rows = await _db
          .from('users')
          .select('id, name, headline, avatar_url, account_type, tags, is_premium')
          .or('name.ilike.$pattern,headline.ilike.$pattern')
          .order('is_premium', ascending: false)
          .order('name', ascending: true)
          .limit(20)
          .timeout(const Duration(seconds: 8));

      final users = List<Map<String, dynamic>>.from(rows);

      // Buscar tags también
      final tagRows = await _db
          .from('users')
          .select('id, name, headline, avatar_url, account_type, tags, is_premium')
          .contains('tags', [query])
          .limit(10)
          .timeout(const Duration(seconds: 5));

      // Merge sin duplicados
      final existingIds = users.map((u) => u['id']).toSet();
      for (final row in tagRows) {
        if (!existingIds.contains(row['id'])) {
          users.add(Map<String, dynamic>.from(row));
        }
      }

      // Guardar en recientes
      _addToRecent(query);

      _resultsController.add(SearchResults(
        users: users,
        query: query,
        totalCount: users.length,
      ));

      debugPrint('🔍 Search "$query": ${users.length} resultados');
    } catch (e) {
      debugPrint('❌ SearchService: $e');
      _resultsController.add(SearchResults(
        error: 'Error al buscar: $e',
        query: query,
      ));
    }
  }

  void _addToRecent(String query) {
    _recentSearches.remove(query); // Remove duplicado
    _recentSearches.insert(0, query); // Add al inicio
    if (_recentSearches.length > 10) {
      _recentSearches.removeLast(); // Max 10 recientes
    }
  }

  /// Limpia búsquedas recientes.
  void clearRecent() => _recentSearches.clear();

  /// Obtiene hashtags trending (basado en frecuencia de tags).
  Future<List<String>> getTrendingTags({int limit = 10}) async {
    try {
      // Obtener todos los tags y contar frecuencia
      final rows = await _db
          .from('users')
          .select('tags')
          .not('tags', 'is', null)
          .limit(200)
          .timeout(const Duration(seconds: 5));

      final tagCount = <String, int>{};
      for (final row in rows) {
        final tags = row['tags'];
        if (tags is List) {
          for (final tag in tags) {
            final t = tag.toString().toLowerCase().trim();
            if (t.isNotEmpty) {
              tagCount[t] = (tagCount[t] ?? 0) + 1;
            }
          }
        }
      }

      // Ordenar por frecuencia
      final sorted = tagCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sorted.take(limit).map((e) => e.key).toList();
    } catch (e) {
      debugPrint('⚠️ getTrendingTags: $e');
      return [];
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
    _resultsController.close();
  }
}

/// Resultado de búsqueda.
class SearchResults {
  final List<Map<String, dynamic>> users;
  final String? query;
  final String? error;
  final bool isLoading;
  final int totalCount;

  SearchResults({
    this.users = const [],
    this.query,
    this.error,
    this.isLoading = false,
    this.totalCount = 0,
  });

  factory SearchResults.empty() => SearchResults();

  bool get isEmpty => users.isEmpty && !isLoading && error == null;
  bool get hasResults => users.isNotEmpty;
  bool get hasError => error != null;
}
