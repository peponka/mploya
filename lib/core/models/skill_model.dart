/// Modelo de datos para skills/habilidades en mploya.
///
/// Incluye nivel, tipo de badge y estado de verificación.
/// Mapea a la tabla `skills` en Supabase.
library;

// ─── Enums ─────────────────────────────────────────────────────────

enum SkillLevel {
  beginner('beginner'),
  intermediate('intermediate'),
  advanced('advanced'),
  expert('expert');

  const SkillLevel(this.value);
  final String value;

  static SkillLevel fromString(String? value) {
    // Support legacy values ('medio', 'avanzado') from existing data.
    switch (value) {
      case 'medio':
        return SkillLevel.intermediate;
      case 'avanzado':
        return SkillLevel.advanced;
      default:
        return SkillLevel.values.firstWhere(
          (e) => e.value == value,
          orElse: () => SkillLevel.beginner,
        );
    }
  }

  String get label => switch (this) {
        beginner => 'Principiante',
        intermediate => 'Intermedio',
        advanced => 'Avanzado',
        expert => 'Experto',
      };

  /// Alias kept for backward compatibility.
  String get displayName => label;
}

enum BadgeType {
  gold('gold'),
  silver('silver'),
  none('none');

  const BadgeType(this.value);
  final String value;

  static BadgeType fromString(String? value) {
    return BadgeType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BadgeType.none,
    );
  }

  String get displayName {
    switch (this) {
      case BadgeType.gold:
        return 'Gold';
      case BadgeType.silver:
        return 'Silver';
      case BadgeType.none:
        return 'Sin badge';
    }
  }

  String get emoji {
    switch (this) {
      case BadgeType.gold:
        return '🥇';
      case BadgeType.silver:
        return '🥈';
      case BadgeType.none:
        return '';
    }
  }
}

// ─── Modelo de Skill ───────────────────────────────────────────────

class SkillModel {
  const SkillModel({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.level = SkillLevel.beginner,
    this.badgeType = BadgeType.none,
    this.isVerified = false,
  });

  final String id;
  final String name;
  final String? description;
  final String? category;
  final SkillLevel level;
  final BadgeType badgeType;
  final bool isVerified;

  // ─── JSON ──────────────────────────────────────────────────────

  factory SkillModel.fromJson(Map<String, dynamic> json) {
    return SkillModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      category: json['category']?.toString(),
      level: SkillLevel.fromString(json['level']?.toString()),
      badgeType: BadgeType.fromString(json['badge_type']?.toString()),
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category,
        'level': level.value,
        'badge_type': badgeType.value,
        'is_verified': isVerified,
      };

  // ─── copyWith ──────────────────────────────────────────────────

  SkillModel copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    SkillLevel? level,
    BadgeType? badgeType,
    bool? isVerified,
  }) {
    return SkillModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      level: level ?? this.level,
      badgeType: badgeType ?? this.badgeType,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkillModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SkillModel(id: $id, name: $name)';
}
