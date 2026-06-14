import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EmployerRatingService — Candidatos califican a empresas
//
// Después de participar en un proceso de selección con una empresa,
// el candidato puede puntuar su experiencia de 1 a 5 estrellas.
// La puntuación es pública y afecta la visibilidad de la empresa
// en el algoritmo.
//
// Categorías de evaluación:
//   • overall: Puntuación general (1-5)
//   • communication: ¿La empresa fue clara y respondió a tiempo?
//   • transparency: ¿Las condiciones eran claras y honestas?
//   • respect: ¿El proceso fue profesional y respetuoso?
//
// Empresas con nota baja (<3.0) reciben menor visibilidad.
// Empresas con nota alta (>4.5) reciben el badge "Empresa Recomendada".
// ─────────────────────────────────────────────────────────────────────────────

class EmployerReview {
  final String id;
  final String candidateId;
  final String companyId;
  final double overallStars;
  final double communicationStars;
  final double transparencyStars;
  final double respectStars;
  final String? comment;
  final String? processType; // 'match', 'application', 'interview'
  final DateTime createdAt;
  // Datos del reviewer (join)
  final String? candidateName;
  final String? candidateHeadline;
  final String? candidateAvatarUrl;

  const EmployerReview({
    required this.id,
    required this.candidateId,
    required this.companyId,
    required this.overallStars,
    this.communicationStars = 0,
    this.transparencyStars = 0,
    this.respectStars = 0,
    this.comment,
    this.processType,
    required this.createdAt,
    this.candidateName,
    this.candidateHeadline,
    this.candidateAvatarUrl,
  });

  factory EmployerReview.fromJson(Map<String, dynamic> json) {
    // Handle joined user data
    final candidate = json['candidate'] as Map<String, dynamic>?;

    return EmployerReview(
      id: json['id']?.toString() ?? '',
      candidateId: json['candidate_id']?.toString() ?? '',
      companyId: json['company_id']?.toString() ?? '',
      overallStars: (json['overall_stars'] as num?)?.toDouble() ?? 0,
      communicationStars: (json['communication_stars'] as num?)?.toDouble() ?? 0,
      transparencyStars: (json['transparency_stars'] as num?)?.toDouble() ?? 0,
      respectStars: (json['respect_stars'] as num?)?.toDouble() ?? 0,
      comment: json['comment']?.toString(),
      processType: json['process_type']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      candidateName: candidate?['name']?.toString(),
      candidateHeadline: candidate?['headline']?.toString(),
      candidateAvatarUrl: candidate?['avatar_url']?.toString(),
    );
  }
}

/// Resumen de ratings de una empresa
class EmployerRatingSummary {
  final double avgOverall;
  final double avgCommunication;
  final double avgTransparency;
  final double avgRespect;
  final int totalReviews;
  final double avgResponseTimeHours;
  final bool isRecommended; // avgOverall >= 4.5

  const EmployerRatingSummary({
    this.avgOverall = 0,
    this.avgCommunication = 0,
    this.avgTransparency = 0,
    this.avgRespect = 0,
    this.totalReviews = 0,
    this.avgResponseTimeHours = 0,
    this.isRecommended = false,
  });

  String get badge {
    if (avgOverall >= 4.5 && totalReviews >= 3) return '⭐ Empresa Recomendada';
    if (avgOverall >= 4.0) return '✅ Buena Reputación';
    if (avgOverall >= 3.0) return '';
    if (totalReviews > 0) return '⚠️ Reputación Baja';
    return '';
  }

  String get responseTimeBadge {
    if (avgResponseTimeHours <= 0) return '';
    if (avgResponseTimeHours <= 24) return '⚡ Responde en <24h';
    if (avgResponseTimeHours <= 48) return '📨 Responde en <48h';
    if (avgResponseTimeHours > 72) return '🐌 Responde en >72h';
    return '';
  }
}

class EmployerRatingService {
  EmployerRatingService._();
  static final EmployerRatingService instance = EmployerRatingService._();

  final _supabase = Supabase.instance.client;
  String? get _uid => _supabase.auth.currentUser?.id;

  // ── Cache ──
  final Map<String, EmployerRatingSummary> _summaryCache = {};
  final Map<String, DateTime> _summaryCacheTime = {};
  static const _cacheDuration = Duration(minutes: 5);

  // ── Enviar review de empresa ──
  /// El candidato califica su experiencia con la empresa.
  /// [companyId] — ID de la empresa
  /// [overallStars] — Puntuación general 1-5
  /// [communicationStars] — Comunicación 1-5
  /// [transparencyStars] — Transparencia 1-5
  /// [respectStars] — Respeto/profesionalismo 1-5
  /// [comment] — Comentario opcional (max 500 chars)
  /// [processType] — Tipo de proceso: 'match', 'application', 'interview'
  ///
  /// Retorna null si fue exitoso, o String con error.
  Future<String?> submitReview({
    required String companyId,
    required double overallStars,
    double communicationStars = 0,
    double transparencyStars = 0,
    double respectStars = 0,
    String? comment,
    String? processType,
  }) async {
    if (_uid == null) return 'No autenticado';

    if (overallStars < 1 || overallStars > 5) return 'Puntuación inválida';
    if (_uid == companyId) return 'No podés calificarte a vos mismo';

    // Auto-fill subcategories with overall if not provided
    if (communicationStars <= 0) communicationStars = overallStars;
    if (transparencyStars <= 0) transparencyStars = overallStars;
    if (respectStars <= 0) respectStars = overallStars;

    try {
      // Verificar que no haya review previo
      final existing = await _supabase
          .from('employer_reviews')
          .select('id')
          .eq('candidate_id', _uid!)
          .eq('company_id', companyId)
          .maybeSingle();

      if (existing != null) {
        // Actualizar review existente
        await _supabase.from('employer_reviews').update({
          'overall_stars': overallStars,
          'communication_stars': communicationStars,
          'transparency_stars': transparencyStars,
          'respect_stars': respectStars,
          'comment': comment,
          'process_type': processType,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', existing['id']);
      } else {
        // Crear review nuevo
        await _supabase.from('employer_reviews').insert({
          'candidate_id': _uid,
          'company_id': companyId,
          'overall_stars': overallStars,
          'communication_stars': communicationStars,
          'transparency_stars': transparencyStars,
          'respect_stars': respectStars,
          'comment': comment,
          'process_type': processType,
        });
      }

      // Recalcular promedios de la empresa
      await _recalculateCompanyRating(companyId);
      _invalidateSummaryCache(companyId);

      return null; // éxito
    } catch (e) {
      debugPrint('❌ EmployerRatingService.submitReview: $e');
      return 'Error al enviar la calificación: $e';
    }
  }

  // ── Obtener resumen de ratings de una empresa ──
  Future<EmployerRatingSummary> getSummary(String companyId, {bool forceRefresh = false}) async {
    if (!forceRefresh && _isSummaryCacheValid(companyId)) {
      return _summaryCache[companyId]!;
    }

    try {
      final res = await _supabase
          .from('employer_reviews')
          .select('overall_stars, communication_stars, transparency_stars, respect_stars')
          .eq('company_id', companyId);

      final reviews = List<Map<String, dynamic>>.from(res);

      if (reviews.isEmpty) {
        return const EmployerRatingSummary();
      }

      double sumOverall = 0, sumComm = 0, sumTrans = 0, sumResp = 0;
      for (final r in reviews) {
        sumOverall += (r['overall_stars'] as num?)?.toDouble() ?? 0;
        sumComm += (r['communication_stars'] as num?)?.toDouble() ?? 0;
        sumTrans += (r['transparency_stars'] as num?)?.toDouble() ?? 0;
        sumResp += (r['respect_stars'] as num?)?.toDouble() ?? 0;
      }

      final count = reviews.length;
      final avgOverall = double.parse((sumOverall / count).toStringAsFixed(1));

      final summary = EmployerRatingSummary(
        avgOverall: avgOverall,
        avgCommunication: double.parse((sumComm / count).toStringAsFixed(1)),
        avgTransparency: double.parse((sumTrans / count).toStringAsFixed(1)),
        avgRespect: double.parse((sumResp / count).toStringAsFixed(1)),
        totalReviews: count,
        isRecommended: avgOverall >= 4.5 && count >= 3,
      );

      _summaryCache[companyId] = summary;
      _summaryCacheTime[companyId] = DateTime.now();
      return summary;
    } catch (e) {
      debugPrint('❌ EmployerRatingService.getSummary: $e');
      return _summaryCache[companyId] ?? const EmployerRatingSummary();
    }
  }

  // ── Obtener reviews individuales de una empresa ──
  Future<List<EmployerReview>> getReviews(String companyId, {int limit = 20}) async {
    try {
      final res = await _supabase
          .from('employer_reviews')
          .select('*, candidate:candidate_id(name, headline, avatar_url)')
          .eq('company_id', companyId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(res)
          .map((e) => EmployerReview.fromJson(e))
          .toList();
    } catch (e) {
      debugPrint('❌ EmployerRatingService.getReviews: $e');
      return [];
    }
  }

  // ── Verificar si el candidato ya calificó a esta empresa ──
  Future<EmployerReview?> getMyReview(String companyId) async {
    if (_uid == null) return null;

    try {
      final res = await _supabase
          .from('employer_reviews')
          .select()
          .eq('candidate_id', _uid!)
          .eq('company_id', companyId)
          .maybeSingle();

      if (res == null) return null;
      return EmployerReview.fromJson(res);
    } catch (e) {
      debugPrint('❌ EmployerRatingService.getMyReview: $e');
      return null;
    }
  }

  // ── Eliminar mi review ──
  Future<bool> deleteMyReview(String companyId) async {
    if (_uid == null) return false;

    try {
      await _supabase
          .from('employer_reviews')
          .delete()
          .eq('candidate_id', _uid!)
          .eq('company_id', companyId);

      await _recalculateCompanyRating(companyId);
      _invalidateSummaryCache(companyId);
      return true;
    } catch (e) {
      debugPrint('❌ EmployerRatingService.deleteMyReview: $e');
      return false;
    }
  }

  // ── Recalcular rating promedio en users (para el algoritmo) ──
  Future<void> _recalculateCompanyRating(String companyId) async {
    try {
      final res = await _supabase
          .from('employer_reviews')
          .select('overall_stars')
          .eq('company_id', companyId);

      final reviews = List<Map<String, dynamic>>.from(res);

      if (reviews.isEmpty) {
        await _supabase.from('users').update({
          'employer_rating_stars': 0,
          'employer_rating_count': 0,
        }).eq('id', companyId);
        return;
      }

      double sum = 0;
      for (final r in reviews) {
        sum += (r['overall_stars'] as num?)?.toDouble() ?? 0;
      }

      final avg = double.parse((sum / reviews.length).toStringAsFixed(1));

      await _supabase.from('users').update({
        'employer_rating_stars': avg,
        'employer_rating_count': reviews.length,
      }).eq('id', companyId);
    } catch (e) {
      debugPrint('⚠️ _recalculateCompanyRating: $e');
    }
  }

  // ── Cache helpers ──
  bool _isSummaryCacheValid(String companyId) {
    final time = _summaryCacheTime[companyId];
    return time != null &&
        DateTime.now().difference(time) < _cacheDuration &&
        _summaryCache.containsKey(companyId);
  }

  void _invalidateSummaryCache(String companyId) {
    _summaryCache.remove(companyId);
    _summaryCacheTime.remove(companyId);
  }
}
