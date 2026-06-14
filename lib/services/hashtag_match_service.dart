import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'hashtag_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HashtagMatchService — Matching inteligente por hashtags, a prueba de caos.
//
// No usa diccionarios: aguanta hashtags escritos libres por los usuarios.
//   • RAREZA: hashtag poco común compartido pesa más que uno masivo.
//   • FUZZY: #flutterdev ≈ #flutter, #programador ≈ #programadora, #UX = #ux.
//
// score() es SÍNCRONO (lo llama el build del feed). loadFrequencies() precarga
// las frecuencias de rareza 1 vez en segundo plano; si no están, usa peso
// neutro y el match igual funciona.
// ─────────────────────────────────────────────────────────────────────────────

class HashtagMatchResult {
  final int score;                 // 0-100
  final List<String> sharedExact;  // hashtags idénticos en común
  final List<String> sharedFuzzy;  // hashtags parecidos (no idénticos) en común

  const HashtagMatchResult({
    required this.score,
    required this.sharedExact,
    required this.sharedFuzzy,
  });
}

class HashtagMatchService {
  HashtagMatchService._();
  static final HashtagMatchService instance = HashtagMatchService._();

  // Frecuencia de cada hashtag normalizado (cuántos usuarios lo tienen).
  final Map<String, int> _freq = {};
  bool _loaded = false;

  /// Precarga las frecuencias desde HashtagService (llamar 1 vez al abrir feed).
  Future<void> loadFrequencies() async {
    if (_loaded) return;
    try {
      final trending = await HashtagService.instance.getTrendingHashtags(limit: 50);
      _freq.clear();
      for (final h in trending) {
        final k = _norm(h.tag);
        if (k.isNotEmpty) _freq[k] = (_freq[k] ?? 0) + h.count;
      }
      _loaded = true;
      debugPrint('🏷️ HashtagMatch: ${_freq.length} frecuencias cargadas');
    } catch (e) {
      debugPrint('⚠️ HashtagMatch.loadFrequencies: $e');
    }
  }

  /// Normaliza: minúsculas, sin '#', sin espacios, sin acentos, solo alfanum.
  String _norm(String raw) {
    var t = raw.toLowerCase().trim();
    if (t.startsWith('#')) t = t.substring(1);
    const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
    const to = 'aaaaaeeeeiiiiooooouuuunc';
    final sb = StringBuffer();
    for (final ch in t.split('')) {
      final idx = from.indexOf(ch);
      sb.write(idx >= 0 ? to[idx] : ch);
    }
    return sb.toString().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Peso por rareza: raro = alto, masivo = bajo. Neutro si no está cargado.
  double _rarity(String norm) {
    final f = _freq[norm];
    if (f == null) return 1.0;
    if (f <= 2) return 2.2;
    if (f <= 5) return 1.8;
    if (f <= 15) return 1.3;
    if (f <= 40) return 1.0;
    return 0.6;
  }

  /// Distancia de edición (Levenshtein) entre dos strings.
  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final prev = List<int>.generate(b.length + 1, (i) => i);
    final curr = List<int>.filled(b.length + 1, 0);
    for (var i = 0; i < a.length; i++) {
      curr[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        curr[j + 1] = math.min(
          math.min(curr[j] + 1, prev[j + 1] + 1),
          prev[j] + cost,
        );
      }
      for (var k = 0; k <= b.length; k++) {
        prev[k] = curr[k];
      }
    }
    return prev[b.length];
  }

  /// Similitud 0..1 entre dos strings (1 = idénticos).
  double _sim(String a, String b) {
    final maxLen = math.max(a.length, b.length);
    if (maxLen == 0) return 1.0;
    return 1.0 - (_levenshtein(a, b) / maxLen);
  }

  /// Mejor grado de coincidencia de `m` contra el set `others`.
  /// 1.0 = exacto; 0.85 = uno contiene al otro; sim*0.9 si sim>=0.82; else 0.
  double _bestMatch(String m, Set<String> others) {
    if (others.contains(m)) return 1.0;
    double best = 0;
    for (final o in others) {
      double grade = 0;
      if (m.length >= 4 && o.length >= 4 && (m.contains(o) || o.contains(m))) {
        grade = 0.85;
      } else {
        final s = _sim(m, o);
        if (s >= 0.82) grade = s * 0.9;
      }
      if (grade > best) best = grade;
    }
    return best;
  }

  /// Cálculo principal (SÍNCRONO). Devuelve solo el score 0-100.
  int score({
    required List<String> myTags,
    required List<String> mySkills,
    required List<String> theirTags,
    required List<String> theirSkills,
  }) {
    return detailed(
      myTags: myTags,
      mySkills: mySkills,
      theirTags: theirTags,
      theirSkills: theirSkills,
    ).score;
  }

  /// Cálculo detallado: score + qué hashtags causaron el match.
  HashtagMatchResult detailed({
    required List<String> myTags,
    required List<String> mySkills,
    required List<String> theirTags,
    required List<String> theirSkills,
  }) {
    final mine = <String>{
      ...myTags.map(_norm),
      ...mySkills.map(_norm),
    }..removeWhere((e) => e.isEmpty);

    final theirs = <String>{
      ...theirTags.map(_norm),
      ...theirSkills.map(_norm),
    }..removeWhere((e) => e.isEmpty);

    if (mine.isEmpty || theirs.isEmpty) {
      return const HashtagMatchResult(score: 40, sharedExact: [], sharedFuzzy: []);
    }

    double myWeight = 0;
    double matchWeight = 0;
    final sharedExact = <String>[];
    final sharedFuzzy = <String>[];

    for (final m in mine) {
      final w = _rarity(m);
      myWeight += w;
      final grade = _bestMatch(m, theirs);
      if (grade > 0) {
        matchWeight += w * grade;
        if (grade >= 1.0) {
          sharedExact.add(m);
        } else {
          sharedFuzzy.add(m);
        }
      }
    }

    if (myWeight == 0) {
      return const HashtagMatchResult(score: 40, sharedExact: [], sharedFuzzy: []);
    }

    final raw = matchWeight / myWeight; // 0..1
    final exactBonus = sharedExact.isNotEmpty ? 20 : 0;
    final score = ((raw * 75) + exactBonus).clamp(20, 99).round();

    return HashtagMatchResult(
      score: score,
      sharedExact: sharedExact,
      sharedFuzzy: sharedFuzzy,
    );
  }
}
