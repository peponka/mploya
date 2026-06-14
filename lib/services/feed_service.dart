import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'social_algorithm_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FeedService — Centraliza la carga del feed con cacheo in-memory.
//
// Problema resuelto: Antes, cada rebuild de HomeFeedScreen hacía un query
// fresco a Supabase. Ahora el feed se cachea por 60s y se reusa.
//
// Uso:
//   FeedService.instance.getFeedUsers()          → Future<List<Map>>
//   FeedService.instance.invalidateCache()       → Fuerza re-fetch
//   FeedService.instance.getCachedOrFetch()      → Usa caché si hay
// ─────────────────────────────────────────────────────────────────────────────

class FeedService {
  FeedService._();
  static final FeedService instance = FeedService._();

  SupabaseClient get _db => Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;

  // ── Cache ──
  List<Map<String, dynamic>>? _cachedUsers;
  DateTime? _cacheTimestamp;
  static const _cacheDuration = Duration(seconds: 60);

  bool get _isCacheValid =>
      _cachedUsers != null &&
      _cacheTimestamp != null &&
      DateTime.now().difference(_cacheTimestamp!) < _cacheDuration;

  /// Invalida el caché forzando un re-fetch en la próxima llamada.
  void invalidateCache() {
    _cachedUsers = null;
    _cacheTimestamp = null;
    debugPrint('🔄 FeedService: Cache invalidado');
  }

  /// Obtiene usuarios del feed.
  /// [offset] = 0 usa caché si está vigente (< 60 s).
  /// [offset] > 0 siempre hace fetch fresco (siguiente página).
  Future<List<Map<String, dynamic>>> getFeedUsers({
    bool forceRefresh = false,
    int offset = 0,
    String myAccountType = 'candidato',
    List<String> myTags = const [],
    List<String> mySkills = const [],
  }) async {
    if (offset == 0 && !forceRefresh && _isCacheValid && _cachedUsers != null) {
      debugPrint('⚡ FeedService: Usando caché (${_cachedUsers!.length} usuarios)');
      return _cachedUsers!;
    }

    try {
      List<dynamic> rows;
      
      try {
        // Intentar con la vista optimizada feed_ranked
        var query = _db.from('feed_ranked').select();
        if (_uid != null) query = query.neq('id', _uid!);
        
        if (myAccountType == 'headhunter') {
          // Headhunter = visibilidad cruzada completa: ve candidatos, confidenciales
          // Y empresas. Es el único rol que ve ambos lados → no se filtra por tipo.
        } else if (myAccountType == 'empresa') {
          query = query.inFilter('account_type', ['candidato', 'confidencial']);
        } else {
          query = query.inFilter('account_type', ['empresa', 'headhunter']);
        }
        
        rows = await query
            .order('base_score', ascending: false)
            .order('created_at', ascending: false)
            .range(offset, offset + 19)
            .timeout(const Duration(seconds: 10));
      } catch (viewError) {
        // feed_ranked no existe → fallback a tabla users directamente
        debugPrint('⚠️ feed_ranked no disponible, usando tabla users: $viewError');
        var query = _db.from('users').select();
        if (_uid != null) query = query.neq('id', _uid!);
        
        // Filtro cruzado
        if (myAccountType == 'headhunter') {
          // Headhunter = visibilidad cruzada completa: ve candidatos, confidenciales
          // Y empresas. Es el único rol que ve ambos lados → no se filtra por tipo.
        } else if (myAccountType == 'empresa') {
          query = query.inFilter('account_type', ['candidato', 'confidencial']);
        } else {
          query = query.inFilter('account_type', ['empresa', 'headhunter']);
        }
        
        rows = await query
            .not('video_url', 'is', null)
            .neq('video_url', '')
            .order('created_at', ascending: false)
            .range(offset, offset + 19)
            .timeout(const Duration(seconds: 10));
      }

      var result = List<Map<String, dynamic>>.from(rows);
      
      // Apply advanced social algorithm for the first page,
      // fallback to basic sort for subsequent pages.
      if (offset == 0) {
        // Pre-load social graph for social scoring
        await SocialAlgorithmService.instance.preloadConnections();
        result = SocialAlgorithmService.instance.rankFeed(
          result,
          myTags: myTags,
          myAccountType: myAccountType,
          mySkills: mySkills,
        );
      } else {
        result = sortByAffinity(result, myTags);
      }

      if (offset == 0) {
        _cachedUsers = result;
        _cacheTimestamp = DateTime.now();
        debugPrint('📡 FeedService: Fetch fresco (${result.length} usuarios, algo social v2)');
      } else {
        debugPrint('📡 FeedService: Página +${result.length} usuarios (offset=$offset)');
      }

      return result;
    } catch (e) {
      debugPrint('❌ FeedService: Error al cargar feed: $e');
      if (offset == 0 && _cachedUsers != null) return _cachedUsers!;
      // No relanzar — retorna lista vacía para mostrar estado "Sé el primero"
      // en lugar del estado de error. Si la DB tiene usuarios eventualmente,
      // el usuario puede usar el botón "Actualizar feed".
      return [];
    }
  }

  /// Filtra usuarios según la Ley de Cruce y el tipo de cuenta.
  List<Map<String, dynamic>> applyCrossFilter(
    List<Map<String, dynamic>> users,
    String myAccountType,
  ) {
    return users.where((r) {
      final hasVideo = r['video_url'] != null && r['video_url'].toString().isNotEmpty;
      if (!hasVideo) return false;

      final t = (r['account_type'] as String?) ?? 'candidato';
      if (myAccountType == 'empresa' || myAccountType == 'headhunter') {
        return t == 'candidato' || t == 'confidencial';
      } else {
        return t == 'empresa' || t == 'headhunter';
      }
    }).toList();
  }

  /// Ordena usuarios por afinidad (tags compartidos + boost + premium).
  List<Map<String, dynamic>> sortByAffinity(
    List<Map<String, dynamic>> users,
    List<String> myTags,
  ) {
    int calculateAffinity(Map<String, dynamic> r) {
      int score = 0;

      // Boost pago activo
      final rawBoost = r['boost_ends_at'];
      if (rawBoost != null) {
        final boostDt = DateTime.tryParse(rawBoost.toString());
        if (boostDt != null && boostDt.isAfter(DateTime.now())) {
          score += 1000;
        }
      }

      // Premium
      if (r['is_premium'] == true) score += 100;

      // Tags compartidos
      if (myTags.isEmpty) return score;
      final theirTagsRaw = r['tags'];
      if (theirTagsRaw == null || theirTagsRaw is! List) return score;

      final theirTagsStr = theirTagsRaw
          .map((e) => e.toString().toLowerCase())
          .toSet();
      for (final t in myTags) {
        if (theirTagsStr.contains(t.toLowerCase())) score += 10;
      }

      return score;
    }

    users.sort((a, b) {
      final scoreA = calculateAffinity(a);
      final scoreB = calculateAffinity(b);
      if (scoreA != scoreB) return scoreB.compareTo(scoreA);

      // Desempate: más recientes primero
      final dateA = DateTime.tryParse(a['created_at'].toString()) ?? DateTime.now();
      final dateB = DateTime.tryParse(b['created_at'].toString()) ?? DateTime.now();
      return dateB.compareTo(dateA);
    });

    return users;
  }

  /// Aplica filtro de categoría (Senior, Remoto, Tech, Fintech).
  List<Map<String, dynamic>> applyFilter(
    List<Map<String, dynamic>> users,
    int filterIndex,
  ) {
    if (filterIndex == 0) return users; // Todos

    return users.where((r) {
      final headline = (r['headline']?.toString() ?? '').toLowerCase();
      final tags = (r['tags'] as List?)
              ?.map((t) => t.toString().toLowerCase())
              .toSet() ??
          <String>{};

      switch (filterIndex) {
        case 1: // Senior
          return headline.contains('senior') ||
              headline.contains('lead') ||
              headline.contains('director') ||
              headline.contains('vp') ||
              headline.contains('cto') ||
              headline.contains('ceo');
        case 2: // Remoto
          return r['open_to_work'] == true ||
              tags.contains('remoto') ||
              tags.contains('remote');
        case 3: // Tech
          return tags.any((t) => const [
                'tech', 'react', 'node', 'flutter', 'python', 'aws',
                'devops', 'javascript', 'ios', 'android', 'backend',
                'frontend', 'fullstack'
              ].contains(t));
        case 4: // Fintech
          return tags.any((t) => const [
                'fintech', 'blockchain', 'crypto', 'cripto', 'defi',
                'banking', 'finanzas', 'payments'
              ].contains(t));
        default:
          return true;
      }
    }).toList();
  }

  /// Convierte un row de Supabase a un Post para la UI.
  Post userRowToPost(Map<String, dynamic> row, {Set<String>? likedUserIds}) {
    final user = NexUser.fromJson(row);
    final isLiked = likedUserIds?.contains(user.id) ?? false;

    return Post(
      id: user.id,
      author: user,
      content: row['headline']?.toString() ?? '',
      type: PostType.video,
      videoUrl: row['video_url']?.toString(),
      timeAgo: _timeAgo(row['created_at']),
      likes: (row['pitch_like_count'] as int?) ?? 0,
      isLiked: isLiked,
      matchPercentage: user.matchPercentage,
      transcript: user.aiTranscript,
    );
  }

  String _timeAgo(dynamic raw) {
    if (raw == null) return 'Reciente';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return 'Reciente';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 365) return '${diff.inDays ~/ 365}a';
    if (diff.inDays > 30) return '${diff.inDays ~/ 30}mes';
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'Ahora';
  }
}
