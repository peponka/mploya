// ──── User Model ────
class NexUser {
  final String id;
  final String name;
  final String headline;
  final String? company;
  final String? location;
  final String? avatarUrl;
  final String? bannerUrl;
  final String? videoUrl;
  final int connections;
  final int profileViews;
  final bool isOpenToWork;
  final bool isHiring;
  final bool isPremium;
  final String? about;
  final List<Experience> experience;
  final List<Education> education;
  final List<String> skills;
  final double? latitude;
  final double? longitude;
  // ── Social Proof (Pilar 1) ──
  final double matchPercentage;
  final double ratingStars;
  final int ratingCount;
  // ── AI Transcript (Pilar 4) ──
  final List<TranscriptSegment> aiTranscript;
  // ── Perfiles Duales y Tags (Fase 8) ──
  final String accountType; // 'candidato', 'confidencial' o 'empresa'
  final List<String> tags;
  // ── Boosts / Monetización (Fase 9) ──
  final DateTime? boostEndsAt;
  final String? boostType; // 'local', 'remote'
  final String? boostTargetCity;
  // ── Salario esperado (Fase 10) ──
  final String? salaryExpectation; // e.g. 'USD 3K-5K/mes'
  // ── Verificado (Fase 14) ──
  final bool isVerified; // true si completó video pitch

  const NexUser({
    required this.id,
    required this.name,
    required this.headline,
    this.company,
    this.location,
    this.avatarUrl,
    this.bannerUrl,
    this.videoUrl,
    this.connections = 0,
    this.profileViews = 0,
    this.isOpenToWork = false,
    this.isHiring = false,
    this.isPremium = false,
    this.about,
    this.experience = const [],
    this.education = const [],
    this.skills = const [],
    this.latitude,
    this.longitude,
    this.matchPercentage = 0,
    this.ratingStars = 0,
    this.ratingCount = 0,
    this.aiTranscript = const [],
    this.accountType = 'candidato',
    this.tags = const [],
    this.boostEndsAt,
    this.boostType,
    this.boostTargetCity,
    this.salaryExpectation,
    this.isVerified = false,
  });

  String get initials {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  bool get isConfidential => accountType.toLowerCase().startsWith('confidenc') || accountType.toLowerCase() == 'stealth';
  bool get isCompanyAct => accountType == 'empresa';
  bool get isBoosted => boostEndsAt != null && boostEndsAt!.isAfter(DateTime.now());

  NexUser copyWith({
    String? id,
    String? name,
    String? headline,
    String? company,
    String? location,
    String? avatarUrl,
    String? bannerUrl,
    String? videoUrl,
    int? connections,
    int? profileViews,
    bool? isOpenToWork,
    bool? isHiring,
    bool? isPremium,
    String? about,
    List<Experience>? experience,
    List<Education>? education,
    List<String>? skills,
    double? latitude,
    double? longitude,
    double? matchPercentage,
    double? ratingStars,
    int? ratingCount,
    List<TranscriptSegment>? aiTranscript,
    String? accountType,
    List<String>? tags,
    DateTime? boostEndsAt,
    String? boostType,
    String? boostTargetCity,
    String? salaryExpectation,
    bool? isVerified,
  }) {
    return NexUser(
      id: id ?? this.id,
      name: name ?? this.name,
      headline: headline ?? this.headline,
      company: company ?? this.company,
      location: location ?? this.location,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      connections: connections ?? this.connections,
      profileViews: profileViews ?? this.profileViews,
      isOpenToWork: isOpenToWork ?? this.isOpenToWork,
      isHiring: isHiring ?? this.isHiring,
      isPremium: isPremium ?? this.isPremium,
      about: about ?? this.about,
      experience: experience ?? this.experience,
      education: education ?? this.education,
      skills: skills ?? this.skills,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      matchPercentage: matchPercentage ?? this.matchPercentage,
      ratingStars: ratingStars ?? this.ratingStars,
      ratingCount: ratingCount ?? this.ratingCount,
      aiTranscript: aiTranscript ?? this.aiTranscript,
      accountType: accountType ?? this.accountType,
      tags: tags ?? this.tags,
      boostEndsAt: boostEndsAt ?? this.boostEndsAt,
      boostType: boostType ?? this.boostType,
      boostTargetCity: boostTargetCity ?? this.boostTargetCity,
      salaryExpectation: salaryExpectation ?? this.salaryExpectation,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'headline': headline,
      'company': company,
      'location': location,
      'avatar_url': avatarUrl,
      'banner_url': bannerUrl,
      'video_url': videoUrl,
      'connections': connections,
      'profile_views': profileViews,
      'open_to_work': isOpenToWork,
      'is_hiring': isHiring,
      'is_premium': isPremium,
      'about': about,
      'experience': experience.map((e) => {
        'role': e.role,
        'company': e.company,
        'duration': e.duration,
        'location': e.location,
        'description': e.description,
        'is_current': e.isCurrent,
      }).toList(),
      'education': education.map((e) => {
        'school': e.school,
        'degree': e.degree,
        'field': e.field,
        'years': e.years,
      }).toList(),
      'skills': skills,
      'latitude': latitude,
      'longitude': longitude,
      'match_percentage': matchPercentage,
      'rating_stars': ratingStars,
      'rating_count': ratingCount,
      'ai_transcript_json': aiTranscript.map((s) => {
        'start': s.start,
        'end': s.end,
        'text': s.text,
      }).toList(),
      'account_type': accountType,
      'tags': tags,
      'boost_ends_at': boostEndsAt?.toIso8601String(),
      'boost_type': boostType,
      'boost_target_city': boostTargetCity,
      'salary_expectation': salaryExpectation,
      'is_verified': isVerified,
    };
  }

  @override
  String toString() => 'NexUser(id: $id, name: $name, type: $accountType)';

  factory NexUser.fromJson(Map<String, dynamic> json) {
    List<String> parseSkills() {
      final raw = json['skills'];
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return [];
    }
    
    List<String> parseTags() {
      final raw = json['tags'];
      if (raw == null) {
        // Fallback a skills si tags no existe aún
        return parseSkills();
      }
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return [];
    }

    List<Experience> parseExperience() {
      final raw = json['experience'];
      if (raw == null || raw is! List) return [];
      return raw.map((e) {
        final m = e as Map<String, dynamic>;
        return Experience(
          role: m['role']?.toString() ?? '',
          company: m['company']?.toString() ?? '',
          duration: m['duration']?.toString() ?? '',
          location: m['location']?.toString(),
          description: m['description']?.toString(),
          isCurrent: m['is_current'] == true,
        );
      }).toList();
    }

    List<Education> parseEducation() {
      final raw = json['education'];
      if (raw == null || raw is! List) return [];
      return raw.map((e) {
        final m = e as Map<String, dynamic>;
        return Education(
          school: m['school']?.toString() ?? '',
          degree: m['degree']?.toString() ?? '',
          field: m['field']?.toString(),
          years: m['years']?.toString() ?? '',
        );
      }).toList();
    }

    List<TranscriptSegment> parseTranscript() {
      final raw = json['ai_transcript_json'];
      if (raw == null || raw is! List) return [];
      return raw.map((e) {
        final m = e as Map<String, dynamic>;
        return TranscriptSegment(
          start: (m['start'] as num?)?.toDouble() ?? 0,
          end: (m['end'] as num?)?.toDouble() ?? 0,
          text: m['text']?.toString() ?? '',
        );
      }).toList();
    }

    return NexUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Usuario',
      headline: json['headline']?.toString() ?? '',
      company: json['company']?.toString(),
      location: json['location']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      bannerUrl: json['banner_url']?.toString(),
      videoUrl: json['video_url']?.toString(),
      about: json['about']?.toString(),
      connections: (json['connections'] as int?) ?? 0,
      profileViews: (json['profile_views'] as int?) ?? 0,
      isOpenToWork: json['open_to_work'] == true,
      isHiring: json['is_hiring'] == true,
      isPremium: json['is_premium'] == true,
      skills: parseSkills(),
      experience: parseExperience(),
      education: parseEducation(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      matchPercentage: (json['match_percentage'] as num?)?.toDouble() ?? 0,
      ratingStars: (json['rating_stars'] as num?)?.toDouble() ?? 0,
      ratingCount: (json['rating_count'] as int?) ?? 0,
      aiTranscript: parseTranscript(),
      accountType: json['account_type']?.toString() ?? 'candidato',
      tags: parseTags(),
      boostEndsAt: json['boost_ends_at'] != null ? DateTime.tryParse(json['boost_ends_at'].toString()) : null,
      boostType: json['boost_type']?.toString(),
      boostTargetCity: json['boost_target_city']?.toString(),
      salaryExpectation: json['salary_expectation']?.toString(),
      isVerified: json['is_verified'] == true,
    );
  }
}

// ──── Transcript Segment (Pilar 4) ────
class TranscriptSegment {
  final double start;
  final double end;
  final String text;

  const TranscriptSegment({
    required this.start,
    required this.end,
    required this.text,
  });
}

// ──── Experience Model ────
class Experience {
  final String role;
  final String company;
  final String? companyLogoUrl;
  final String duration;
  final String? location;
  final String? description;
  final bool isCurrent;

  const Experience({
    required this.role,
    required this.company,
    this.companyLogoUrl,
    required this.duration,
    this.location,
    this.description,
    this.isCurrent = false,
  });
}

// ──── Education Model ────
class Education {
  final String school;
  final String degree;
  final String? field;
  final String years;
  final String? logoUrl;

  const Education({
    required this.school,
    required this.degree,
    this.field,
    required this.years,
    this.logoUrl,
  });
}

// ──── Post Model ────
enum PostType { text, image, article, document, video }

class Post {
  final String id;
  final NexUser author;
  final String content;
  final PostType type;
  final String? imageUrl;
  final String? videoUrl;
  final String timeAgo;
  final int likes;
  final int comments;
  final int reposts;
  final bool isLiked;
  // ── Social proof fields from DB ──
  final double matchPercentage;
  final List<TranscriptSegment> transcript;

  const Post({
    required this.id,
    required this.author,
    required this.content,
    this.type = PostType.text,
    this.imageUrl,
    this.videoUrl,
    required this.timeAgo,
    this.likes = 0,
    this.comments = 0,
    this.reposts = 0,
    this.isLiked = false,
    this.matchPercentage = 0,
    this.transcript = const [],
  });
}

// ──── Job Model ────
class Job {
  final String id;
  final String title;
  final String company;
  final String? companyLogoUrl;
  final String location;
  final String? salaryRange;
  final String postedAgo;
  final bool isEasyApply;
  final bool isRemote;
  final bool isSaved;
  final int applicants;

  const Job({
    required this.id,
    required this.title,
    required this.company,
    this.companyLogoUrl,
    required this.location,
    this.salaryRange,
    required this.postedAgo,
    this.isEasyApply = false,
    this.isRemote = false,
    this.isSaved = false,
    this.applicants = 0,
  });
}

// ──── Conversation Model ────
class Conversation {
  final String id;
  final NexUser user;
  final String lastMessage;
  final String timeAgo;
  final bool isUnread;
  final int unreadCount;

  const Conversation({
    required this.id,
    required this.user,
    required this.lastMessage,
    required this.timeAgo,
    this.isUnread = false,
    this.unreadCount = 0,
  });
}

// ──── Video URL Utilities ────

/// Dominios que causan errores CORS en Flutter Web durante desarrollo/simulación.
/// En producción los videos deben vivir en Supabase Storage con CORS configurado,
/// por lo que esta lista quedará vacía y la función pasará todas las URLs sin cambio.
const _kCorsBlockedDomains = ['commondatastorage', 'flutter.github.io'];

/// Devuelve la URL efectiva del video aplicando el bypass de CORS para desarrollo.
/// Si la URL pertenece a un dominio bloqueado devuelve el asset de simulación local.
/// Centralizado aquí para que [TikTokReelCard] y [StoryViewerScreen] no dupliquen lógica.
String resolveVideoUrl(String? rawUrl) {
  if (rawUrl == null || rawUrl.isEmpty) return '';
  if (_kCorsBlockedDomains.any((domain) => rawUrl.contains(domain))) {
    return 'asset:assets/videos/mock_pitch.mp4';
  }
  return rawUrl;
}

// ──── Notification Model ────
enum NotificationType { like, comment, connection, jobAlert, profileView, mention }

class NexNotification {
  final String id;
  final NotificationType type;
  final NexUser? actor;
  final String description;
  final String timeAgo;
  final bool isRead;

  const NexNotification({
    required this.id,
    required this.type,
    this.actor,
    required this.description,
    required this.timeAgo,
    this.isRead = false,
  });
}
