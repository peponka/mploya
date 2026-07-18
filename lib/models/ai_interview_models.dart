class Interview {
  final String id;
  final String jobId;
  final String candidateId;
  final String status; // pending | in_progress | completed
  final DateTime createdAt;
  final DateTime? completedAt;

  Interview({
    required this.id,
    required this.jobId,
    required this.candidateId,
    required this.status,
    required this.createdAt,
    this.completedAt,
  });

  factory Interview.fromJson(Map<String, dynamic> json) {
    return Interview(
      id: json['id'] as String,
      jobId: json['job_id'] as String,
      candidateId: json['candidate_id'] as String,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'job_id': jobId,
      'candidate_id': candidateId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }
}

class InterviewQuestion {
  final String id;
  final String interviewId;
  final int ord;
  final String text;
  final String? category; // technical | behavioral | motivation
  final String generatedBy; // ai | human
  final DateTime createdAt;

  InterviewQuestion({
    required this.id,
    required this.interviewId,
    required this.ord,
    required this.text,
    this.category,
    required this.generatedBy,
    required this.createdAt,
  });

  factory InterviewQuestion.fromJson(Map<String, dynamic> json) {
    return InterviewQuestion(
      id: json['id'] as String,
      interviewId: json['interview_id'] as String,
      ord: (json['ord'] as num?)?.toInt() ?? 0,
      text: json['text'] as String,
      category: json['category'] as String?,
      generatedBy: json['generated_by'] as String? ?? 'ai',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'interview_id': interviewId,
      'ord': ord,
      'text': text,
      'category': category,
      'generated_by': generatedBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class InterviewAnswer {
  final String id;
  final String questionId;
  final String interviewId;
  final String? videoUrl;
  final String? transcript;
  final DateTime createdAt;

  InterviewAnswer({
    required this.id,
    required this.questionId,
    required this.interviewId,
    this.videoUrl,
    this.transcript,
    required this.createdAt,
  });

  factory InterviewAnswer.fromJson(Map<String, dynamic> json) {
    return InterviewAnswer(
      id: json['id'] as String,
      questionId: json['question_id'] as String,
      interviewId: json['interview_id'] as String,
      videoUrl: json['video_url'] as String?,
      transcript: json['transcript'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_id': questionId,
      'interview_id': interviewId,
      'video_url': videoUrl,
      'transcript': transcript,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class InterviewReport {
  final String id;
  final String interviewId;
  final String? summary;
  final List<dynamic>? competencies; // [{name, score, note}]
  final List<dynamic>? keywords;
  final int? score;
  final String? rationale;
  final DateTime createdAt;

  InterviewReport({
    required this.id,
    required this.interviewId,
    this.summary,
    this.competencies,
    this.keywords,
    this.score,
    this.rationale,
    required this.createdAt,
  });

  factory InterviewReport.fromJson(Map<String, dynamic> json) {
    return InterviewReport(
      id: json['id'] as String,
      interviewId: json['interview_id'] as String,
      summary: json['summary'] as String?,
      competencies: json['competencies'] as List<dynamic>?,
      keywords: json['keywords'] as List<dynamic>?,
      score: (json['score'] as num?)?.toInt(),
      rationale: json['rationale'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'interview_id': interviewId,
      'summary': summary,
      'competencies': competencies,
      'keywords': keywords,
      'score': score,
      'rationale': rationale,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
