import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HashtagService — Motor de hashtags interactivos
//
// Features:
//  • getTrendingHashtags()   → Top hashtags por frecuencia de uso
//  • getHashtagCount(tag)    → Cuántos usuarios usan ese tag
//  • searchByHashtag(tag)    → Usuarios que tienen el tag
//  • getSuggestedHashtags()  → Sugerencias basadas en perfil del usuario
//  • getRelatedHashtags(tag) → Tags co-ocurrentes
//
// Los hashtags se leen del campo users.tags (jsonb array en Supabase).
// ─────────────────────────────────────────────────────────────────────────────

class HashtagData {
  final String tag;
  final int count;
  final double trendScore; // 0-100: popularidad relativa

  const HashtagData({
    required this.tag,
    required this.count,
    this.trendScore = 0,
  });
}

class HashtagService {
  HashtagService._();
  static final HashtagService instance = HashtagService._();

  SupabaseClient get _db => Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;

  // ── Cache ──
  List<HashtagData>? _trendingCache;
  DateTime? _trendingCacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  bool get _isCacheValid =>
      _trendingCache != null &&
      _trendingCacheTime != null &&
      DateTime.now().difference(_trendingCacheTime!) < _cacheDuration;

  /// Obtiene los hashtags más populares de la plataforma.
  /// Lee todos los tags de la tabla users y calcula frecuencia.
  Future<List<HashtagData>> getTrendingHashtags({int limit = 20}) async {
    if (_isCacheValid && _trendingCache != null) {
      return _trendingCache!.take(limit).toList();
    }

    try {
      // Fetch all users' tags
      final rows = await _db
          .from('users')
          .select('tags')
          .not('tags', 'is', null)
          .limit(500);

      // Count frequency of each tag
      final Map<String, int> freq = {};
      for (final row in List<Map<String, dynamic>>.from(rows)) {
        final tags = row['tags'];
        if (tags is List) {
          for (final t in tags) {
            final normalized = t.toString().toLowerCase().trim();
            if (normalized.isNotEmpty) {
              freq[normalized] = (freq[normalized] ?? 0) + 1;
            }
          }
        }
      }

      // Sort by frequency
      final sorted = freq.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final maxCount = sorted.isNotEmpty ? sorted.first.value : 1;

      _trendingCache = sorted
          .take(50)
          .map((e) => HashtagData(
                tag: e.key,
                count: e.value,
                trendScore: (e.value / maxCount * 100),
              ))
          .toList();
      _trendingCacheTime = DateTime.now();

      debugPrint('🏷️ Trending: ${_trendingCache!.length} hashtags calculados');
      return _trendingCache!.take(limit).toList();
    } catch (e) {
      debugPrint('❌ HashtagService.getTrendingHashtags: $e');
      return _trendingCache ?? [];
    }
  }

  /// Cuántos usuarios usan un hashtag específico.
  Future<int> getHashtagCount(String tag) async {
    try {
      final trending = await getTrendingHashtags(limit: 50);
      final match = trending.where((h) => h.tag.toLowerCase() == tag.toLowerCase());
      if (match.isNotEmpty) return match.first.count;

      // Fallback: query directa
      final rows = await _db
          .from('users')
          .select('id')
          .contains('tags', [tag])
          .limit(100);
      return (rows as List).length;
    } catch (e) {
      debugPrint('❌ HashtagService.getHashtagCount: $e');
      return 0;
    }
  }

  /// Busca usuarios que tienen un hashtag específico.
  Future<List<Map<String, dynamic>>> searchByHashtag(String tag) async {
    try {
      final uid = _uid;
      final Set<String> ids = {};
      final List<Map<String, dynamic>> results = [];

      // Buscar variaciones del tag
      for (final variant in {
        tag,
        tag.toLowerCase(),
        tag.toUpperCase(),
        '${tag[0].toUpperCase()}${tag.substring(1).toLowerCase()}'
      }) {
        final rows = await _db
            .from('users')
            .select()
            .contains('tags', [variant])
            .limit(30);

        for (final row in List<Map<String, dynamic>>.from(rows)) {
          final id = row['id']?.toString() ?? '';
          if (id.isNotEmpty && id != uid && !ids.contains(id)) {
            ids.add(id);
            results.add(row);
          }
        }
      }

      return results;
    } catch (e) {
      debugPrint('❌ HashtagService.searchByHashtag: $e');
      return [];
    }
  }

  /// Sugiere hashtags basados en el perfil del usuario actual.
  /// Usa los tags de usuarios similares (mismos tags/skills).
  Future<List<String>> getSuggestedHashtags() async {
    if (_uid == null) return [];

    try {
      // Get current user's tags
      final userData = await _db
          .from('users')
          .select('tags, skills')
          .eq('id', _uid!)
          .maybeSingle();

      if (userData == null) return [];

      final myTags = (userData['tags'] as List?)
              ?.map((e) => e.toString().toLowerCase())
              .toSet() ??
          <String>{};

      // Get trending and filter out already-used tags
      final trending = await getTrendingHashtags(limit: 30);
      return trending
          .where((h) => !myTags.contains(h.tag.toLowerCase()))
          .take(10)
          .map((h) => h.tag)
          .toList();
    } catch (e) {
      debugPrint('❌ HashtagService.getSuggestedHashtags: $e');
      return [];
    }
  }

  /// Tags que co-aparecen con el tag dado.
  Future<List<String>> getRelatedHashtags(String tag) async {
    try {
      final rows = await _db
          .from('users')
          .select('tags')
          .contains('tags', [tag])
          .limit(50);

      final Map<String, int> coFreq = {};
      final normalizedTag = tag.toLowerCase();

      for (final row in List<Map<String, dynamic>>.from(rows)) {
        final tags = row['tags'];
        if (tags is List) {
          for (final t in tags) {
            final normalized = t.toString().toLowerCase().trim();
            if (normalized.isNotEmpty && normalized != normalizedTag) {
              coFreq[normalized] = (coFreq[normalized] ?? 0) + 1;
            }
          }
        }
      }

      final sorted = coFreq.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sorted.take(8).map((e) => e.key).toList();
    } catch (e) {
      debugPrint('❌ HashtagService.getRelatedHashtags: $e');
      return [];
    }
  }

  void invalidateCache() {
    _trendingCache = null;
    _trendingCacheTime = null;
  }
}
