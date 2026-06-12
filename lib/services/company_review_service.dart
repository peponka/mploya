import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Company Reviews service — candidatos dejan reviews anónimos post-entrevista.
class CompanyReviewService {
  CompanyReviewService._();
  static final instance = CompanyReviewService._();

  final _supabase = Supabase.instance.client;
  String? get _uid => _supabase.auth.currentUser?.id;

  Future<List<CompanyReview>> fetchReviews(String companyId) async {
    try {
      final rows = await _supabase.from('company_reviews').select()
          .eq('company_id', companyId).eq('status', 'published')
          .order('created_at', ascending: false);
      return rows.map((r) => CompanyReview.fromJson(r)).toList();
    } catch (e) { debugPrint('CompanyReview: $e'); return []; }
  }

  Future<CompanyReviewStats> fetchStats(String companyId) async {
    final reviews = await fetchReviews(companyId);
    if (reviews.isEmpty) return CompanyReviewStats.empty();
    final avg = reviews.map((r) => r.overallRating).reduce((a, b) => a + b) / reviews.length;
    final cultureAvg = reviews.where((r) => r.cultureRating != null).map((r) => r.cultureRating!).fold(0, (a, b) => a + b);
    final cultureCount = reviews.where((r) => r.cultureRating != null).length;
    final interviewAvg = reviews.where((r) => r.interviewRating != null).map((r) => r.interviewRating!).fold(0, (a, b) => a + b);
    final interviewCount = reviews.where((r) => r.interviewRating != null).length;
    return CompanyReviewStats(
      totalReviews: reviews.length,
      averageRating: avg,
      cultureRating: cultureCount > 0 ? cultureAvg / cultureCount : 0,
      interviewRating: interviewCount > 0 ? interviewAvg / interviewCount : 0,
    );
  }

  Future<bool> hasReviewed(String companyId) async {
    if (_uid == null) return false;
    try {
      final rows = await _supabase.from('company_reviews').select('id')
          .eq('reviewer_id', _uid!).eq('company_id', companyId).limit(1);
      return (rows as List).isNotEmpty;
    } catch (_) { return false; }
  }

  Future<String?> submitReview({
    required String companyId,
    required int overallRating,
    int? interviewRating,
    int? cultureRating,
    String? pros,
    String? cons,
    String? interviewExperience,
  }) async {
    if (_uid == null) return 'No autenticado';
    try {
      await _supabase.from('company_reviews').insert({
        'reviewer_id': _uid,
        'company_id': companyId,
        'overall_rating': overallRating,
        'interview_rating': interviewRating,
        'culture_rating': cultureRating,
        'pros': pros,
        'cons': cons,
        'interview_experience': interviewExperience,
        'is_anonymous': true,
      });
      return null;
    } catch (e) { return e.toString(); }
  }
}

class CompanyReview {
  final String id;
  final int overallRating;
  final int? interviewRating;
  final int? cultureRating;
  final String? pros;
  final String? cons;
  final String? interviewExperience;
  final bool isAnonymous;
  final DateTime createdAt;

  CompanyReview({required this.id, required this.overallRating, this.interviewRating,
    this.cultureRating, this.pros, this.cons, this.interviewExperience,
    this.isAnonymous = true, required this.createdAt});

  factory CompanyReview.fromJson(Map<String, dynamic> j) => CompanyReview(
    id: j['id']?.toString() ?? '',
    overallRating: (j['overall_rating'] as num?)?.toInt() ?? 3,
    interviewRating: (j['interview_rating'] as num?)?.toInt(),
    cultureRating: (j['culture_rating'] as num?)?.toInt(),
    pros: j['pros']?.toString(),
    cons: j['cons']?.toString(),
    interviewExperience: j['interview_experience']?.toString(),
    isAnonymous: j['is_anonymous'] == true,
    createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
  );
}

class CompanyReviewStats {
  final int totalReviews;
  final double averageRating;
  final double cultureRating;
  final double interviewRating;
  const CompanyReviewStats({required this.totalReviews, required this.averageRating,
    required this.cultureRating, required this.interviewRating});
  factory CompanyReviewStats.empty() => const CompanyReviewStats(totalReviews: 0, averageRating: 0, cultureRating: 0, interviewRating: 0);
}
