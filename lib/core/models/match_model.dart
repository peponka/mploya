/// Modelo de datos para matches/conexiones en mploya.
///
/// Representa una conexión entre dos usuarios de la plataforma.
/// Mapea a la tabla `matches` en Supabase.
library;

// ─── Enums ─────────────────────────────────────────────────────────

enum MatchStatus {
  pending('pending'),
  active('active'),
  connected('connected'),
  rejected('rejected');

  const MatchStatus(this.value);
  final String value;

  static MatchStatus fromString(String? value) {
    return MatchStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MatchStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case MatchStatus.pending:
        return 'Pendiente';
      case MatchStatus.active:
        return 'Activo';
      case MatchStatus.connected:
        return 'Conectado';
      case MatchStatus.rejected:
        return 'Rechazado';
    }
  }
}

enum MatchType {
  candidate('candidate'),
  company('company');

  const MatchType(this.value);
  final String value;

  static MatchType fromString(String? value) {
    return MatchType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MatchType.candidate,
    );
  }
}

// ─── Modelo de Match ───────────────────────────────────────────────

class MatchModel {
  const MatchModel({
    required this.id,
    required this.userId,
    required this.targetUserId,
    required this.status,
    required this.type,
    this.matchPercentage = 0,
    this.createdAt,
    // UI-only enriched fields
    this.targetUserName,
    this.targetUserAvatarUrl,
    this.targetUserHeadline,
    this.targetUserLocation,
    this.targetUserIsVerified = false,
    this.targetUserHashtags = const [],
  });

  final String id;
  final String userId;
  final String targetUserId;
  final MatchStatus status;
  final MatchType type;
  final int matchPercentage;
  final DateTime? createdAt;

  // UI-only enriched fields
  final String? targetUserName;
  final String? targetUserAvatarUrl;
  final String? targetUserHeadline;
  final String? targetUserLocation;
  final bool targetUserIsVerified;
  final List<String> targetUserHashtags;

  // ─── JSON ──────────────────────────────────────────────────────

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    return MatchModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      targetUserId: json['target_user_id']?.toString() ?? '',
      status: MatchStatus.fromString(json['status']?.toString()),
      type: MatchType.fromString(json['type']?.toString()),
      matchPercentage: (json['match_percentage'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']?.toString() ?? '')
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'target_user_id': targetUserId,
        'status': status.value,
        'type': type.value,
        'match_percentage': matchPercentage,
        'created_at': createdAt?.toIso8601String(),
      };

  // ─── copyWith ──────────────────────────────────────────────────

  MatchModel copyWith({
    String? id,
    String? userId,
    String? targetUserId,
    MatchStatus? status,
    MatchType? type,
    int? matchPercentage,
    DateTime? createdAt,
    String? targetUserName,
    String? targetUserAvatarUrl,
    String? targetUserHeadline,
    String? targetUserLocation,
    bool? targetUserIsVerified,
    List<String>? targetUserHashtags,
  }) {
    return MatchModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      targetUserId: targetUserId ?? this.targetUserId,
      status: status ?? this.status,
      type: type ?? this.type,
      matchPercentage: matchPercentage ?? this.matchPercentage,
      createdAt: createdAt ?? this.createdAt,
      targetUserName: targetUserName ?? this.targetUserName,
      targetUserAvatarUrl: targetUserAvatarUrl ?? this.targetUserAvatarUrl,
      targetUserHeadline: targetUserHeadline ?? this.targetUserHeadline,
      targetUserLocation: targetUserLocation ?? this.targetUserLocation,
      targetUserIsVerified: targetUserIsVerified ?? this.targetUserIsVerified,
      targetUserHashtags: targetUserHashtags ?? this.targetUserHashtags,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MatchModel(id: $id, userId: $userId, targetUserId: $targetUserId)';
}
