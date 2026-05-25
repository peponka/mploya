/// Modelo de datos para hashtags en mploya.
///
/// Representa un hashtag con su conteo de uso y tags relacionados.
/// Mapea a la tabla `hashtags` en Supabase.
library;

class HashtagModel {
  const HashtagModel({
    required this.id,
    required this.name,
    this.count = 0,
    this.relatedTags = const [],
    this.updatedAt,
  });

  final String id;
  final String name;
  final int count;
  final List<String> relatedTags;
  final DateTime? updatedAt;

  // ─── JSON ──────────────────────────────────────────────────────

  factory HashtagModel.fromJson(Map<String, dynamic> json) {
    return HashtagModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      relatedTags: (json['related_tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at']?.toString() ?? '')
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'count': count,
        'related_tags': relatedTags,
        'updated_at': updatedAt?.toIso8601String(),
      };

  // ─── copyWith ──────────────────────────────────────────────────

  HashtagModel copyWith({
    String? id,
    String? name,
    int? count,
    List<String>? relatedTags,
    DateTime? updatedAt,
  }) {
    return HashtagModel(
      id: id ?? this.id,
      name: name ?? this.name,
      count: count ?? this.count,
      relatedTags: relatedTags ?? this.relatedTags,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Display name with # prefix
  String get displayName => '#$name';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HashtagModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'HashtagModel(id: $id, name: $name)';
}
