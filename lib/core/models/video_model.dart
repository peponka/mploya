/// Modelo de datos para videos en la plataforma mploya.
///
/// Soporta tipos: pitch, story, reply, portfolio.
/// Mapea a la tabla `videos` en Supabase.
library;

// ─── Enum de tipo de video ─────────────────────────────────────────

enum VideoType {
  pitch('pitch'),
  story('story'),
  reply('reply'),
  portfolio('portfolio');

  const VideoType(this.value);
  final String value;

  static VideoType fromString(String? value) {
    return VideoType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => VideoType.pitch,
    );
  }
}

// ─── Modelo de Video ───────────────────────────────────────────────

class VideoModel {
  const VideoModel({
    required this.id,
    required this.userId,
    required this.url,
    this.thumbnailUrl,
    required this.duration,
    required this.type,
    this.title,
    this.description,
    this.score = 0,
    this.hashtags = const [],
    this.viewCount = 0,
    this.likeCount = 0,
    this.createdAt,
    // UI-only fields (not persisted)
    this.userName,
    this.userAvatarUrl,
    this.userHeadline,
    this.matchPercentage,
    this.isLiked = false,
    this.isSaved = false,
  });

  final String id;
  final String userId;
  final String url;
  final String? thumbnailUrl;
  final int duration; // in seconds
  final VideoType type;
  final String? title;
  final String? description;
  final int score; // AI score points
  final List<String> hashtags;
  final int viewCount;
  final int likeCount;
  final DateTime? createdAt;

  // UI-only fields for feed display
  final String? userName;
  final String? userAvatarUrl;
  final String? userHeadline;
  final int? matchPercentage;
  final bool isLiked;
  final bool isSaved;

  // ─── JSON ──────────────────────────────────────────────────────

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      url: json['url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      duration: json['duration'] as int? ?? 0,
      type: VideoType.fromString(json['type'] as String?),
      title: json['title'] as String?,
      description: json['description'] as String?,
      score: json['score'] as int? ?? 0,
      hashtags: (json['hashtags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      viewCount: json['view_count'] as int? ?? 0,
      likeCount: json['like_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'url': url,
        'thumbnail_url': thumbnailUrl,
        'duration': duration,
        'type': type.value,
        'title': title,
        'description': description,
        'score': score,
        'hashtags': hashtags,
        'view_count': viewCount,
        'like_count': likeCount,
        'created_at': createdAt?.toIso8601String(),
      };

  // ─── copyWith ──────────────────────────────────────────────────

  VideoModel copyWith({
    String? id,
    String? userId,
    String? url,
    String? thumbnailUrl,
    int? duration,
    VideoType? type,
    String? title,
    String? description,
    int? score,
    List<String>? hashtags,
    int? viewCount,
    int? likeCount,
    DateTime? createdAt,
    String? userName,
    String? userAvatarUrl,
    String? userHeadline,
    int? matchPercentage,
    bool? isLiked,
    bool? isSaved,
  }) {
    return VideoModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      url: url ?? this.url,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      score: score ?? this.score,
      hashtags: hashtags ?? this.hashtags,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      createdAt: createdAt ?? this.createdAt,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      userHeadline: userHeadline ?? this.userHeadline,
      matchPercentage: matchPercentage ?? this.matchPercentage,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
    );
  }

  /// Display-friendly duration string (e.g. "0:45")
  String get durationFormatted {
    final mins = duration ~/ 60;
    final secs = duration % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}
