/// Modelo de datos para challenges/retos en mploya.
///
/// Representa un reto semanal de pitch con duración máxima,
/// participantes y fecha de expiración.
/// Mapea a la tabla `challenges` en Supabase.
library;

// ─── Enum de tipo de challenge ─────────────────────────────────────

enum ChallengeType {
  weekly('weekly'),
  video('video'),
  quiz('quiz'),
  presentation('presentation'),
  teamwork('teamwork');

  const ChallengeType(this.value);
  final String value;

  static ChallengeType fromString(String? value) {
    return ChallengeType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ChallengeType.weekly,
    );
  }
}

// ─── Modelo de Challenge ───────────────────────────────────────────

class ChallengeModel {
  const ChallengeModel({
    required this.id,
    required this.title,
    this.description,
    this.type = ChallengeType.weekly,
    this.maxDuration = 60,
    this.participantCount = 0,
    this.endsAt,
    this.userParticipated = false,
  });

  final String id;
  final String title;
  final String? description;
  final ChallengeType type;
  final int maxDuration; // in seconds
  final int participantCount;
  final DateTime? endsAt;
  final bool userParticipated;

  // ─── JSON ──────────────────────────────────────────────────────

  factory ChallengeModel.fromJson(Map<String, dynamic> json) {
    return ChallengeModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      type: ChallengeType.fromString(json['type']?.toString()),
      maxDuration: (json['max_duration'] as num?)?.toInt() ?? 60,
      participantCount: (json['participant_count'] as num?)?.toInt() ?? 0,
      endsAt: json['ends_at'] != null
          ? DateTime.tryParse(json['ends_at']?.toString() ?? '')
          : null,
      userParticipated: json['user_participated'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.value,
        'max_duration': maxDuration,
        'participant_count': participantCount,
        'ends_at': endsAt?.toIso8601String(),
        'user_participated': userParticipated,
      };

  // ─── copyWith ──────────────────────────────────────────────────

  ChallengeModel copyWith({
    String? id,
    String? title,
    String? description,
    ChallengeType? type,
    int? maxDuration,
    int? participantCount,
    DateTime? endsAt,
    bool? userParticipated,
  }) {
    return ChallengeModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      maxDuration: maxDuration ?? this.maxDuration,
      participantCount: participantCount ?? this.participantCount,
      endsAt: endsAt ?? this.endsAt,
      userParticipated: userParticipated ?? this.userParticipated,
    );
  }

  /// Remaining time as display string
  String get remainingTimeDisplay {
    if (endsAt == null) return 'Sin fecha';
    final diff = endsAt!.difference(DateTime.now());
    if (diff.isNegative) return 'Finalizado';
    if (diff.inDays > 0) return '${diff.inDays}d restantes';
    if (diff.inHours > 0) return '${diff.inHours}h restantes';
    return '${diff.inMinutes}m restantes';
  }

  /// Whether the challenge is still active
  bool get isActive {
    if (endsAt == null) return true;
    return endsAt!.isAfter(DateTime.now());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChallengeModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ChallengeModel(id: $id, title: $title)';
}
