/// Modelo de datos para notificaciones en mploya.
///
/// Soporta tipos: connection_request, match_interest, profile_view, system.
/// Mapea a la tabla `notifications` en Supabase.
library;

// ─── Enum de tipo de notificación ──────────────────────────────────

enum NotificationType {
  connectionRequest('connection_request'),
  matchInterest('match_interest'),
  profileView('profile_view'),
  system('system');

  const NotificationType(this.value);
  final String value;

  static NotificationType fromString(String? value) {
    return NotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationType.system,
    );
  }

  String get displayName {
    switch (this) {
      case NotificationType.connectionRequest:
        return 'Solicitud de conexión';
      case NotificationType.matchInterest:
        return 'Interés de match';
      case NotificationType.profileView:
        return 'Vista de perfil';
      case NotificationType.system:
        return 'Sistema';
    }
  }

  String get emoji {
    switch (this) {
      case NotificationType.connectionRequest:
        return '🤝';
      case NotificationType.matchInterest:
        return '⚡';
      case NotificationType.profileView:
        return '👁️';
      case NotificationType.system:
        return '🔔';
    }
  }
}

// ─── Modelo de Notificación ────────────────────────────────────────

class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.isRead = false,
    this.data = const {},
    this.createdAt,
    // UI-only fields
    this.senderName,
    this.senderAvatarUrl,
  });

  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final bool isRead;
  final Map<String, dynamic> data;
  final DateTime? createdAt;

  // UI-only
  final String? senderName;
  final String? senderAvatarUrl;

  // ─── JSON ──────────────────────────────────────────────────────

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: NotificationType.fromString(json['type'] as String?),
      title: json['title'] as String,
      body: json['body'] as String,
      isRead: json['is_read'] as bool? ?? false,
      data: (json['data'] as Map<String, dynamic>?) ?? const {},
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'type': type.value,
        'title': title,
        'body': body,
        'is_read': isRead,
        'data': data,
        'created_at': createdAt?.toIso8601String(),
      };

  // ─── copyWith ──────────────────────────────────────────────────

  NotificationModel copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? body,
    bool? isRead,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    String? senderName,
    String? senderAvatarUrl,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      senderName: senderName ?? this.senderName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
    );
  }

  /// Tiempo relativo en español (e.g. "Hace 2h")
  String get timeAgo {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
    return 'Hace ${diff.inDays ~/ 7}sem';
  }
}
