import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AIMatchService — Motor de matching inteligente candidato-empresa
//
// Usa embeddings vectoriales (pgvector) para calcular similitud semántica
// entre perfiles de candidatos y empresas.
//
// Flujo:
//   1. Onboarding: se genera embedding del perfil (skills + headline + about)
//   2. Feed/Network: se consulta match_users_by_embedding para ranking
//   3. El match_percentage se calcula como similitud coseno * 100
//
// Los embeddings se generan via Edge Function con un modelo de embedding
// (e.g. text-embedding-3-small de OpenAI o all-MiniLM de HuggingFace)
// ─────────────────────────────────────────────────────────────────────────────

class AIMatchService {
  AIMatchService._();
  static final AIMatchService instance = AIMatchService._();

  final _supabase = Supabase.instance.client;
  String? get _uid => _supabase.auth.currentUser?.id;

  // ── Cache de matches IA ──
  List<Map<String, dynamic>>? _cachedMatches;
  DateTime? _matchCacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  bool get _isCacheValid =>
      _matchCacheTime != null &&
      DateTime.now().difference(_matchCacheTime!) < _cacheDuration;

  /// Genera el embedding del perfil del usuario actual.
  ///
  /// Llama a una Edge Function que:
  ///   1. Lee el perfil del usuario (name, headline, about, skills, tags)
  ///   2. Concatena los campos en un texto descriptivo
  ///   3. Genera el embedding con el modelo
  ///   4. Lo guarda en users.profile_embedding
  ///
  /// Retorna true si fue exitoso.
  Future<bool> generateProfileEmbedding() async {
    if (_uid == null) return false;

    try {
      debugPrint('🧠 Generando embedding de perfil...');

      final response = await _supabase.functions.invoke(
        'generate-embedding',
        body: {'user_id': _uid},
      );

      if (response.status == 200) {
        debugPrint('✅ Embedding generado correctamente');
        _invalidateCache();
        return true;
      }

      debugPrint('❌ Error generando embedding: ${response.status}');
      return false;
    } catch (e) {
      debugPrint('❌ AIMatchService.generateProfileEmbedding: $e');
      return false;
    }
  }

  /// Obtiene matches inteligentes por similitud de embedding.
  ///
  /// Llama al RPC `match_users_by_embedding` que usa pgvector
  /// para encontrar los usuarios más similares.
  ///
  /// Retorna lista de usuarios con su similarity score.
  Future<List<Map<String, dynamic>>> getSmartMatches({
    int limit = 10,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _isCacheValid && _cachedMatches != null) {
      return _cachedMatches!;
    }

    if (_uid == null) return [];

    try {
      final results = await _supabase.rpc(
        'match_users_by_embedding',
        params: {
          'p_user_id': _uid,
          'p_limit': limit,
        },
      );

      final matches = List<Map<String, dynamic>>.from(results ?? []);

      // Convertir similarity (0-1) a porcentaje
      for (var match in matches) {
        final sim = (match['similarity'] as num?)?.toDouble() ?? 0;
        match['match_percentage'] = (sim * 100).round();
      }

      _cachedMatches = matches;
      _matchCacheTime = DateTime.now();

      debugPrint('🎯 ${matches.length} smart matches encontrados');
      return matches;
    } catch (e) {
      debugPrint('❌ AIMatchService.getSmartMatches: $e');
      return _cachedMatches ?? [];
    }
  }

  /// Genera un "match score" entre dos usuarios.
  ///
  /// Usa los tags, skills, y headline para un cálculo simple
  /// cuando embeddings no están disponibles.
  /// Esto es el fallback cuando pgvector no está configurado.
  int calculateBasicMatchScore({
    required List<String> myTags,
    required List<String> mySkills,
    required String myType,
    required List<String> otherTags,
    required List<String> otherSkills,
    required String otherType,
  }) {
    int score = 0;
    const tagWeight = 15;
    const skillWeight = 10;
    const crossTypeBonus = 20;

    // Tags en común
    final commonTags = myTags.where((t) => 
      otherTags.any((ot) => ot.toLowerCase() == t.toLowerCase())
    ).length;
    score += commonTags * tagWeight;

    // Skills en común
    final commonSkills = mySkills.where((s) => 
      otherSkills.any((os) => os.toLowerCase() == s.toLowerCase())
    ).length;
    score += commonSkills * skillWeight;

    // Bonus inter-tipo (candidato ↔ empresa)
    final isCross = (myType == 'candidato' || myType == 'confidencial') &&
        (otherType == 'empresa' || otherType == 'headhunter');
    final isCrossReverse = (myType == 'empresa' || myType == 'headhunter') &&
        (otherType == 'candidato' || otherType == 'confidencial');
    if (isCross || isCrossReverse) {
      score += crossTypeBonus;
    }

    // Normalizar a 0-100
    return score.clamp(0, 100);
  }

  /// Obtiene el match score para un usuario específico
  Future<int> getMatchScoreFor(String otherUserId) async {
    if (_uid == null) return 0;

    try {
      // Intentar con embeddings primero
      final result = await _supabase.rpc(
        'match_users_by_embedding',
        params: {'p_user_id': _uid, 'p_limit': 50},
      );

      final matches = List<Map<String, dynamic>>.from(result ?? []);
      final match = matches.firstWhere(
        (m) => m['id']?.toString() == otherUserId,
        orElse: () => {},
      );

      if (match.isNotEmpty) {
        final sim = (match['similarity'] as num?)?.toDouble() ?? 0;
        return (sim * 100).round();
      }

      return 0;
    } catch (e) {
      debugPrint('❌ AIMatchService.getMatchScoreFor: $e');
      return 0;
    }
  }

  void _invalidateCache() {
    _matchCacheTime = null;
    _cachedMatches = null;
  }
}
