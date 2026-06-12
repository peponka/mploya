import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SocialAlgorithmService v3 — Motor de ranking social avanzado
//
// Implementa un algoritmo tipo TikTok/LinkedIn adaptado para Mploya:
//
//  • Engagement Decay — Posts recientes puntúan más (half-life 48h)
//  • Diversity Injection — No mostrar 5 del mismo tipo seguidos
//  • Social Graph Scoring — Usuarios conectados a mis conexiones rankean más
//  • Hashtag + Skill Affinity — Tags Y skills compartidos = boost
//  • Quality Signals — Rating alto, video pitch completo, verificado
//  • Anti-Bubble — 20% de contenido "descubrimiento" fuera del filtro habitual
//  • Freshness Bonus — Perfiles nuevos (<7 días) reciben bonus
//  • View Dedup — Penaliza perfiles ya vistos en sesión
//  • Engagement History — Pondera más perfiles similares a los likeados
//
// Uso:
//   SocialAlgorithmService.instance.rankFeed(rawUsers, myProfile)
// ─────────────────────────────────────────────────────────────────────────────

class SocialAlgorithmService {
  SocialAlgorithmService._();
  static final SocialAlgorithmService instance = SocialAlgorithmService._();

  final _supabase = Supabase.instance.client;
  final _random = Random();

  // Cache de conexiones del usuario para social graph
  Set<String>? _myConnections;
  DateTime? _connCacheTime;

  // IDs de perfiles ya vistos en esta sesión (penalización leve)
  final Set<String> _viewedThisSession = {};

  // Tags de perfiles que el usuario ha likeado (engagement history)
  Set<String>? _likedProfileTags;
  DateTime? _likedTagsCacheTime;

  /// Rankea la lista de usuarios raw para el feed del usuario actual.
  List<Map<String, dynamic>> rankFeed(
    List<Map<String, dynamic>> rawUsers, {
    required List<String> myTags,
    required String myAccountType,
    Set<String>? myConnectionIds,
    List<String> mySkills = const [],
  }) {
    if (rawUsers.isEmpty) return rawUsers;

    // Calcular scores
    final scored = rawUsers.map((user) {
      double score = 0;

      // ── 1. Engagement Decay (recency) ──
      score += _recencyScore(user);

      // ── 2. Quality Signals ──
      score += _qualityScore(user);

      // ── 3. Tag Affinity ──
      score += _tagAffinityScore(user, myTags);

      // ── 4. Skill Match ── (NEW)
      score += _skillMatchScore(user, mySkills);

      // ── 5. Social Graph ──
      score += _socialGraphScore(user, myConnectionIds ?? _myConnections ?? {});

      // ── 6. Boost pago ──
      score += _boostScore(user);

      // ── 7. Freshness Bonus ── (NEW)
      score += _freshnessBonus(user);

      // ── 8. View Dedup Penalty ── (NEW)
      score += _viewDedupPenalty(user);

      // ── 9. Engagement History ── (NEW)
      score += _engagementHistoryScore(user);

      // ── 10. Anti-Bubble Randomness ──
      score += _random.nextDouble() * 5; // Pequeño jitter

      user['_algo_score'] = score;
      return user;
    }).toList();

    // Sort by composite score
    scored.sort((a, b) =>
        ((b['_algo_score'] as double?) ?? 0).compareTo(
            (a['_algo_score'] as double?) ?? 0));

    // Track viewed profiles
    for (final u in scored) {
      final id = u['id']?.toString();
      if (id != null) _viewedThisSession.add(id);
    }

    // ── Diversity Injection ──
    final diversified = _applyDiversity(scored);

    // ── Anti-Bubble: inject 20% discovery content ──
    return _injectDiscovery(diversified);
  }

  // ── Score Components ──────────────────────────────────────────────────────

  /// Recency: half-life de 48 horas. Después de 4 días = ~25% del score.
  double _recencyScore(Map<String, dynamic> user) {
    final createdAt = DateTime.tryParse(
        user['created_at']?.toString() ?? '');
    if (createdAt == null) return 10;

    final hoursOld = DateTime.now().difference(createdAt).inHours;
    const halfLifeHours = 48.0;

    // Exponential decay: score = 50 * (0.5 ^ (hoursOld / halfLife))
    return 50 * pow(0.5, hoursOld / halfLifeHours).toDouble();
  }

  /// Quality: video, rating, verificado, perfil completo.
  double _qualityScore(Map<String, dynamic> user) {
    double score = 0;

    // Video pitch = +20
    final videoUrl = user['video_url']?.toString() ?? '';
    if (videoUrl.isNotEmpty) score += 20;

    // Rating alto = +0-15
    final rating = (user['rating_stars'] as num?)?.toDouble() ?? 0;
    if (rating >= 4.0) {
      score += 15;
    } else if (rating >= 3.0) {
      score += 8;
    }

    // Premium = +10
    if (user['is_premium'] == true) score += 10;

    // Avatar = +5
    if (user['avatar_url'] != null &&
        user['avatar_url'].toString().isNotEmpty) {
      score += 5;
    }

    // Headline/about completo = +5
    if (user['headline'] != null &&
        user['headline'].toString().length > 10) {
      score += 5;
    }

    // Tags >= 3 = +5
    final tags = user['tags'];
    if (tags is List && tags.length >= 3) score += 5;

    // About section filled = +5
    if (user['about'] != null && user['about'].toString().length > 20) {
      score += 5;
    }

    return score;
  }

  /// Tag Affinity: cada tag compartido = +10, max +60.
  double _tagAffinityScore(Map<String, dynamic> user, List<String> myTags) {
    if (myTags.isEmpty) return 0;

    final theirTags = (user['tags'] as List?)
        ?.map((e) => e.toString().toLowerCase())
        .toSet() ?? <String>{};

    int shared = 0;
    for (final t in myTags) {
      if (theirTags.contains(t.toLowerCase())) shared++;
    }

    return (shared * 10).clamp(0, 60).toDouble();
  }

  /// Skill Match: skills compartidos = +8 cada uno, max +48.
  double _skillMatchScore(Map<String, dynamic> user, List<String> mySkills) {
    if (mySkills.isEmpty) return 0;

    final theirSkills = (user['skills'] as List?)
        ?.map((e) => e.toString().toLowerCase())
        .toSet() ?? <String>{};

    int shared = 0;
    for (final s in mySkills) {
      if (theirSkills.contains(s.toLowerCase())) shared++;
    }

    return (shared * 8).clamp(0, 48).toDouble();
  }

  /// Social Graph: usuarios conectados con mis conexiones.
  double _socialGraphScore(
      Map<String, dynamic> user, Set<String> myConnectionIds) {
    if (myConnectionIds.isEmpty) return 0;

    final userId = user['id']?.toString() ?? '';
    if (myConnectionIds.contains(userId)) {
      return 25; // Direct connection = high relevance
    }

    return 0;
  }

  /// Boost pago activo = +100 (top del feed).
  double _boostScore(Map<String, dynamic> user) {
    final rawBoost = user['boost_ends_at'];
    if (rawBoost == null) return 0;

    final boostDt = DateTime.tryParse(rawBoost.toString());
    if (boostDt != null && boostDt.isAfter(DateTime.now())) {
      return 100;
    }
    return 0;
  }

  /// Freshness Bonus: perfiles creados hace <7 días = +30, <14 días = +15.
  double _freshnessBonus(Map<String, dynamic> user) {
    final createdAt = DateTime.tryParse(user['created_at']?.toString() ?? '');
    if (createdAt == null) return 0;

    final daysOld = DateTime.now().difference(createdAt).inDays;
    if (daysOld <= 3) return 35;
    if (daysOld <= 7) return 25;
    if (daysOld <= 14) return 15;
    return 0;
  }

  /// View Dedup: penaliza perfiles ya vistos en esta sesión (-15).
  double _viewDedupPenalty(Map<String, dynamic> user) {
    final userId = user['id']?.toString() ?? '';
    if (_viewedThisSession.contains(userId)) return -15;
    return 0;
  }

  /// Engagement History: si el usuario likeó perfiles con tags similares, boost.
  double _engagementHistoryScore(Map<String, dynamic> user) {
    if (_likedProfileTags == null || _likedProfileTags!.isEmpty) return 0;

    final theirTags = (user['tags'] as List?)
        ?.map((e) => e.toString().toLowerCase())
        .toSet() ?? <String>{};

    int overlap = 0;
    for (final t in theirTags) {
      if (_likedProfileTags!.contains(t)) overlap++;
    }

    // Cada tag en común con perfiles likeados = +6, max +30
    return (overlap * 6).clamp(0, 30).toDouble();
  }

  // ── Diversity Injection ────────────────────────────────────────────────────

  /// No permite más de 3 del mismo account_type seguidos.
  List<Map<String, dynamic>> _applyDiversity(List<Map<String, dynamic>> sorted) {
    if (sorted.length <= 3) return sorted;

    final result = <Map<String, dynamic>>[];
    final pool = List<Map<String, dynamic>>.from(sorted);
    int consecutiveSame = 0;
    String? lastType;

    while (pool.isNotEmpty) {
      int pickIdx = 0;

      if (consecutiveSame >= 3 && lastType != null) {
        for (int i = 0; i < pool.length; i++) {
          final type = pool[i]['account_type']?.toString() ?? '';
          if (type != lastType) {
            pickIdx = i;
            break;
          }
        }
      }

      final picked = pool.removeAt(pickIdx);
      final currentType = picked['account_type']?.toString() ?? '';

      if (currentType == lastType) {
        consecutiveSame++;
      } else {
        consecutiveSame = 1;
        lastType = currentType;
      }

      result.add(picked);
    }

    return result;
  }

  /// Anti-Bubble: mezcla 20% de contenido aleatorio para evitar echo chambers.
  List<Map<String, dynamic>> _injectDiscovery(List<Map<String, dynamic>> ranked) {
    if (ranked.length < 10) return ranked;

    final result = List<Map<String, dynamic>>.from(ranked);
    final discoveryCount = (ranked.length * 0.2).ceil();

    for (int i = 0; i < discoveryCount && result.length > 5; i++) {
      final last = result.removeLast();
      final insertAt = _random.nextInt((result.length * 0.7).ceil()) + 3;
      result.insert(insertAt.clamp(0, result.length), last);
    }

    return result;
  }

  // ── Social Graph Cache ─────────────────────────────────────────────────────

  /// Pre-carga las conexiones del usuario para social graph scoring.
  Future<void> preloadConnections() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    // Cache valid for 5 minutes
    if (_myConnections != null && _connCacheTime != null &&
        DateTime.now().difference(_connCacheTime!) < const Duration(minutes: 5)) {
      return;
    }

    try {
      final rows = await _supabase
          .from('connections')
          .select('requester_id, addressee_id')
          .eq('status', 'accepted')
          .or('requester_id.eq.$uid,addressee_id.eq.$uid');

      _myConnections = {};
      for (final row in List<Map<String, dynamic>>.from(rows)) {
        final req = row['requester_id']?.toString();
        final addr = row['addressee_id']?.toString();
        if (req != null && req != uid) _myConnections!.add(req);
        if (addr != null && addr != uid) _myConnections!.add(addr);
      }
      _connCacheTime = DateTime.now();

      debugPrint('🔗 Social graph: ${_myConnections!.length} conexiones cargadas');
    } catch (e) {
      debugPrint('❌ SocialAlgorithmService.preloadConnections: $e');
    }
  }

  /// Pre-carga los tags de perfiles likeados para engagement history.
  Future<void> preloadEngagementHistory() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    if (_likedProfileTags != null && _likedTagsCacheTime != null &&
        DateTime.now().difference(_likedTagsCacheTime!) < const Duration(minutes: 10)) {
      return;
    }

    try {
      final rows = await _supabase
          .from('pitch_likes')
          .select('pitch_owner_id')
          .eq('liker_id', uid)
          .order('created_at', ascending: false)
          .limit(50);

      final ownerIds = List<Map<String, dynamic>>.from(rows)
          .map((r) => r['pitch_owner_id']?.toString())
          .where((id) => id != null)
          .toList();

      if (ownerIds.isEmpty) {
        _likedProfileTags = {};
        _likedTagsCacheTime = DateTime.now();
        return;
      }

      // Fetch tags of liked profiles
      final userRows = await _supabase
          .from('users')
          .select('tags')
          .inFilter('id', ownerIds)
          .limit(50);

      _likedProfileTags = {};
      for (final row in List<Map<String, dynamic>>.from(userRows)) {
        final tags = row['tags'];
        if (tags is List) {
          for (final t in tags) {
            _likedProfileTags!.add(t.toString().toLowerCase());
          }
        }
      }
      _likedTagsCacheTime = DateTime.now();

      debugPrint('💜 Engagement history: ${_likedProfileTags!.length} tags de likes');
    } catch (e) {
      debugPrint('❌ SocialAlgorithmService.preloadEngagementHistory: $e');
    }
  }

  /// Limpia los perfiles vistos (llamar al hacer pull-to-refresh).
  void clearViewedSession() {
    _viewedThisSession.clear();
  }

  Set<String> get connectionIds => _myConnections ?? {};
}
