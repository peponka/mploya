import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/headhunter_candidate_privacy.dart';

@immutable
class HeadhunterInterviewData {
  const HeadhunterInterviewData({
    required this.id,
    required this.status,
    required this.jobTitle,
    required this.candidateName,
    required this.createdAt,
    this.completedAt,
    this.candidateHeadline,
    this.avatarUrl,
    this.questionCount = 0,
    this.answerCount = 0,
    this.hasReport = false,
    this.isConfidential = false,
    this.notFound = false,
    this.error = false,
  });

  final String id;
  final String status;
  final String jobTitle;
  final String candidateName;
  final String? candidateHeadline;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int questionCount;
  final int answerCount;
  final bool hasReport;
  final bool isConfidential;
  final bool notFound;
  final bool error;
}

@immutable
class HeadhunterInterviewReportData {
  const HeadhunterInterviewReportData({
    required this.interview,
    this.summary,
    this.competencies = const [],
    this.keywords = const [],
    this.score,
    this.rationale,
    this.createdAt,
    this.notFound = false,
    this.error = false,
  });

  final HeadhunterInterviewData interview;
  final String? summary;
  final List<Map<String, dynamic>> competencies;
  final List<String> keywords;
  final int? score;
  final String? rationale;
  final DateTime? createdAt;
  final bool notFound;
  final bool error;

  bool get hasContent =>
      summary?.isNotEmpty == true ||
      competencies.isNotEmpty ||
      keywords.isNotEmpty ||
      score != null ||
      rationale?.isNotEmpty == true;
}

Future<HeadhunterInterviewData> loadHeadhunterInterview(String id) async {
  try {
    final client = Supabase.instance.client;
    final interview = await client
        .from('interviews')
        .select('id,job_id,candidate_id,status,created_at,completed_at')
        .eq('id', id)
        .maybeSingle();
    if (interview == null) return _missingInterview(id);
    final job = await client
        .from('jobs')
        .select('title')
        .eq('id', interview['job_id'])
        .maybeSingle();
    final candidate = await client
        .from('users')
        .select('name,headline,avatar_url,account_type')
        .eq('id', interview['candidate_id'])
        .maybeSingle();
    final questions =
        await client
                .from('interview_questions')
                .select('id')
                .eq('interview_id', id)
            as List<dynamic>;
    final answers =
        await client
                .from('interview_answers')
                .select('id')
                .eq('interview_id', id)
            as List<dynamic>;
    final report = await client
        .from('interview_reports')
        .select('id')
        .eq('interview_id', id)
        .maybeSingle();
    final accountType = candidate?['account_type']?.toString();
    final confidential = isConfidentialAccountType(accountType);
    return HeadhunterInterviewData(
      id: id,
      status: interview['status']?.toString() ?? 'pending',
      jobTitle: job?['title']?.toString() ?? 'Vacante sin título',
      candidateName: confidential
          ? headhunterProtectedCandidateName
          : candidate?['name']?.toString() ?? 'Candidato',
      candidateHeadline: confidential
          ? null
          : candidate?['headline']?.toString(),
      avatarUrl: confidential ? null : candidate?['avatar_url']?.toString(),
      createdAt:
          DateTime.tryParse(interview['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      completedAt: DateTime.tryParse(
        interview['completed_at']?.toString() ?? '',
      ),
      questionCount: questions.length,
      answerCount: answers.length,
      hasReport: report != null,
      isConfidential: confidential,
    );
  } catch (error) {
    debugPrint('Headhunter interview detail: $error');
    return _missingInterview(id, error: true);
  }
}

Future<HeadhunterInterviewReportData> loadHeadhunterInterviewReport(
  String id,
) async {
  final interview = await loadHeadhunterInterview(id);
  if (interview.error || interview.notFound) {
    return HeadhunterInterviewReportData(
      interview: interview,
      error: interview.error,
      notFound: interview.notFound,
    );
  }
  try {
    final row = await Supabase.instance.client
        .from('interview_reports')
        .select('summary,competencies,keywords,score,rationale,created_at')
        .eq('interview_id', id)
        .maybeSingle();
    if (row == null) {
      return HeadhunterInterviewReportData(
        interview: interview,
        notFound: true,
      );
    }
    final competencies = row['competencies'] is List
        ? (row['competencies'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final keywords = row['keywords'] is List
        ? (row['keywords'] as List)
              .map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    return HeadhunterInterviewReportData(
      interview: interview,
      summary: row['summary']?.toString(),
      competencies: competencies,
      keywords: keywords,
      score: row['score'] is num ? (row['score'] as num).round() : null,
      rationale: row['rationale']?.toString(),
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
    );
  } catch (error) {
    debugPrint('Headhunter interview report: $error');
    return HeadhunterInterviewReportData(interview: interview, error: true);
  }
}

HeadhunterInterviewData _missingInterview(String id, {bool error = false}) =>
    HeadhunterInterviewData(
      id: id,
      status: 'pending',
      jobTitle: '',
      candidateName: '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      notFound: !error,
      error: error,
    );
