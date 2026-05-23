// =============================================================================
// Messaging Data Models
// =============================================================================
// Models for the real-time messaging feature of the mploya platform.
// Maps to the `conversations` and `messages` tables in Supabase.
// =============================================================================

/// Represents a chat conversation between two participants.
///
/// Maps to the `conversations` table in Supabase, joined with participant
/// profile data and the latest message metadata.
class Conversation {
  const Conversation({
    required this.id,
    required this.participantId,
    required this.participantName,
    this.participantAvatarUrl,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.isOnline = false,
    this.jobTitle,
  });

  final String id;

  /// The other participant's user ID.
  final String participantId;

  /// Display name of the other participant.
  final String participantName;

  /// Avatar URL of the other participant.
  final String? participantAvatarUrl;

  /// Preview text of the most recent message in this conversation.
  final String? lastMessage;

  /// Timestamp of the most recent message.
  final DateTime? lastMessageAt;

  /// Number of unread messages for the current user.
  final int unreadCount;

  /// Whether the other participant is currently online.
  final bool isOnline;

  /// The job title associated with this conversation, if any.
  final String? jobTitle;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      participantId: json['participant_id'] as String,
      participantName: json['participant_name'] as String,
      participantAvatarUrl: json['participant_avatar_url'] as String?,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
      isOnline: json['is_online'] as bool? ?? false,
      jobTitle: json['job_title'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'participant_id': participantId,
        'participant_name': participantName,
        'participant_avatar_url': participantAvatarUrl,
        'last_message': lastMessage,
        'last_message_at': lastMessageAt?.toIso8601String(),
        'unread_count': unreadCount,
        'is_online': isOnline,
        'job_title': jobTitle,
      };

  /// Returns the initials of the participant for avatar placeholders.
  String get participantInitials {
    final parts = participantName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }

  /// Whether this conversation has unread messages.
  bool get hasUnread => unreadCount > 0;

  /// Returns a display-friendly unread count (e.g. "99+" for large numbers).
  String get unreadDisplay => unreadCount > 99 ? '99+' : '$unreadCount';

  /// Returns a formatted preview of the last message, truncated if needed.
  String get lastMessagePreview {
    if (lastMessage == null || lastMessage!.isEmpty) {
      return 'Sin mensajes aún';
    }
    if (lastMessage!.length > 60) {
      return '${lastMessage!.substring(0, 60)}…';
    }
    return lastMessage!;
  }

  Conversation copyWith({
    String? id,
    String? participantId,
    String? participantName,
    String? participantAvatarUrl,
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    bool? isOnline,
    String? jobTitle,
  }) {
    return Conversation(
      id: id ?? this.id,
      participantId: participantId ?? this.participantId,
      participantName: participantName ?? this.participantName,
      participantAvatarUrl: participantAvatarUrl ?? this.participantAvatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      isOnline: isOnline ?? this.isOnline,
      jobTitle: jobTitle ?? this.jobTitle,
    );
  }
}

/// Represents a single message within a conversation.
///
/// Maps to the `messages` table in Supabase.
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.type = MessageType.text,
    this.mediaUrl,
    this.isRead = false,
    required this.createdAt,
  });

  final String id;
  final String conversationId;

  /// The user ID of the message sender.
  final String senderId;

  /// Text content of the message.
  final String content;

  /// The type of message content.
  final MessageType type;

  /// URL for media attachments (images, files, GIFs).
  final String? mediaUrl;

  /// Whether the recipient has read this message.
  final bool isRead;

  /// When this message was created/sent.
  final DateTime createdAt;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      type: _messageTypeFromJson(json['type'] as String?),
      mediaUrl: json['media_url'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'content': content,
        'type': type.value,
        'media_url': mediaUrl,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
      };

  /// Whether this message contains media content.
  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;

  /// Whether this is a system-generated message (e.g. "conversation started").
  bool get isSystem => type == MessageType.system;

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    MessageType? type,
    String? mediaUrl,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Types of messages supported by the platform.
enum MessageType {
  /// Plain text message.
  text('text'),

  /// Image attachment.
  image('image'),

  /// Animated GIF.
  gif('gif'),

  /// File attachment (PDF, document, etc.).
  file('file'),

  /// System-generated message (join, leave, etc.).
  system('system');

  const MessageType(this.value);
  final String value;

  /// Spanish label for display in the UI.
  String get label {
    switch (this) {
      case text:
        return 'Texto';
      case image:
        return 'Imagen';
      case gif:
        return 'GIF';
      case file:
        return 'Archivo';
      case system:
        return 'Sistema';
    }
  }
}

MessageType _messageTypeFromJson(String? value) {
  switch (value) {
    case 'image':
      return MessageType.image;
    case 'gif':
      return MessageType.gif;
    case 'file':
      return MessageType.file;
    case 'system':
      return MessageType.system;
    default:
      return MessageType.text;
  }
}
