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
  });

  final String id;
  final String name;
  final int count;
  final List<String> relatedTags;

  // ─── JSON ──────────────────────────────────────────────────────

  factory HashtagModel.fromJson(Map<String, dynamic> json) {
    return HashtagModel(
      id: json['id'] as String,
      name: json['name'] as String,
      count: json['count'] as int? ?? 0,
      relatedTags: (json['related_tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'count': count,
        'related_tags': relatedTags,
      };

  // ─── copyWith ──────────────────────────────────────────────────

  HashtagModel copyWith({
    String? id,
    String? name,
    int? count,
    List<String>? relatedTags,
  }) {
    return HashtagModel(
      id: id ?? this.id,
      name: name ?? this.name,
      count: count ?? this.count,
      relatedTags: relatedTags ?? this.relatedTags,
    );
  }

  /// Display name with # prefix
  String get displayName => '#$name';
}
