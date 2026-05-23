/// Servicio de mensajería en tiempo real con Supabase.
///
/// Gestiona conversaciones, mensajes, streams en tiempo real,
/// marcado de lectura y conteos de no leídos.
/// Usa patrón singleton igual que [AuthService] y [JobsService].
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mploya/features/messaging/models/message_model.dart';

/// Servicio centralizado de mensajería.
///
/// ```dart
/// final conversations = await MessagingService.instance.getConversations(userId);
/// ```
class MessagingService {
  MessagingService._();
  static final MessagingService instance = MessagingService._();

  SupabaseClient get _client => Supabase.instance.client;

  // ─── Tabla y columnas ─────────────────────────────────────────────

  static const _conversationsTable = 'conversations';
  static const _messagesTable = 'messages';

  /// Columnas base para conversaciones.
  ///
  /// Se incluye un join con la tabla `profiles` para traer nombre y
  /// avatar del participante en una sola consulta.
  static const _conversationSelect = '''
    *,
    participant:participant_id (
      full_name,
      avatar_url,
      is_online
    )
  ''';

  // ─── Conversaciones ───────────────────────────────────────────────

  /// Obtiene todas las conversaciones del usuario.
  ///
  /// Retorna las conversaciones ordenadas por último mensaje,
  /// con datos del participante resueltos desde `profiles`.
  Future<List<Conversation>> getConversations(String userId) async {
    try {
      final data = await _client
          .from(_conversationsTable)
          .select(_conversationSelect)
          .or('user_id.eq.$userId,participant_id.eq.$userId')
          .order('last_message_at', ascending: false)
          as List<dynamic>? ?? [];

      return data
          .cast<Map<String, dynamic>>()
          .map((json) => _mapConversation(json, userId))
          .toList();
    } catch (e, st) {
      debugPrint('Error obteniendo conversaciones: $e\n$st');
      return [];
    }
  }

  /// Stream en tiempo real de las conversaciones del usuario.
  ///
  /// Escucha cambios en la tabla `conversations` y emite la lista
  /// actualizada cada vez que se inserta, actualiza o elimina un registro.
  Stream<List<Conversation>> conversationsStream(String userId) {
    final controller = StreamController<List<Conversation>>.broadcast();

    // Carga inicial
    getConversations(userId).then((conversations) {
      if (!controller.isClosed) {
        controller.add(conversations);
      }
    });

    // Suscripción a cambios en tiempo real
    final channel = _client
        .channel('conversations:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _conversationsTable,
          callback: (payload) {
            // Re-fetch completa para mantener datos consistentes
            // con los joins de participante.
            getConversations(userId).then((conversations) {
              if (!controller.isClosed) {
                controller.add(conversations);
              }
            });
          },
        )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  /// Obtiene o crea una conversación entre dos usuarios.
  ///
  /// Busca primero si ya existe una conversación entre [userId] y
  /// [participantId]. Si no existe, crea una nueva.
  Future<Conversation?> getOrCreateConversation({
    required String userId,
    required String participantId,
    String? jobTitle,
  }) async {
    try {
      // Buscar conversación existente en cualquier dirección
      final existing = await _client
          .from(_conversationsTable)
          .select(_conversationSelect)
          .or(
            'and(user_id.eq.$userId,participant_id.eq.$participantId),'
            'and(user_id.eq.$participantId,participant_id.eq.$userId)',
          )
          .maybeSingle();

      if (existing != null) {
        return _mapConversation(existing, userId);
      }

      // Crear nueva conversación
      final now = DateTime.now().toIso8601String();
      final data = await _client
          .from(_conversationsTable)
          .insert({
            'user_id': userId,
            'participant_id': participantId,
            'job_title': jobTitle,
            'unread_count': 0,
            'created_at': now,
            'updated_at': now,
          })
          .select(_conversationSelect)
          .single();

      return _mapConversation(data, userId);
    } catch (e, st) {
      debugPrint('Error obteniendo/creando conversación: $e\n$st');
      return null;
    }
  }

  /// Elimina una conversación y sus mensajes asociados.
  Future<void> deleteConversation(String conversationId) async {
    try {
      // Los mensajes se eliminan en cascada si la FK está configurada,
      // de lo contrario los eliminamos explícitamente.
      await _client
          .from(_messagesTable)
          .delete()
          .eq('conversation_id', conversationId);

      await _client
          .from(_conversationsTable)
          .delete()
          .eq('id', conversationId);

      debugPrint('Conversación $conversationId eliminada.');
    } catch (e, st) {
      debugPrint('Error eliminando conversación: $e\n$st');
      rethrow;
    }
  }

  // ─── Mensajes ─────────────────────────────────────────────────────

  /// Obtiene mensajes de una conversación con paginación.
  ///
  /// Retorna los mensajes ordenados del más reciente al más antiguo.
  /// [limit] y [offset] controlan la paginación.
  Future<List<Message>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final data = await _client
          .from(_messagesTable)
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1)
          as List<dynamic>? ?? [];

      return data
          .cast<Map<String, dynamic>>()
          .map((json) => Message.fromJson(json))
          .toList();
    } catch (e, st) {
      debugPrint('Error obteniendo mensajes: $e\n$st');
      return [];
    }
  }

  /// Stream en tiempo real de los mensajes de una conversación.
  ///
  /// Emite la lista completa de mensajes cada vez que se inserta,
  /// actualiza o elimina un mensaje en la conversación.
  Stream<List<Message>> messagesStream(String conversationId) {
    final controller = StreamController<List<Message>>.broadcast();

    // Carga inicial
    getMessages(conversationId).then((messages) {
      if (!controller.isClosed) {
        controller.add(messages);
      }
    });

    // Suscripción a cambios en tiempo real
    final channel = _client
        .channel('messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _messagesTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            getMessages(conversationId).then((messages) {
              if (!controller.isClosed) {
                controller.add(messages);
              }
            });
          },
        )
        .subscribe();

    controller.onCancel = () {
      _client.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  /// Envía un mensaje en una conversación.
  ///
  /// Crea un registro en la tabla `messages` y actualiza los metadatos
  /// de la conversación (último mensaje, timestamp, contador de no leídos).
  Future<Message> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    MessageType type = MessageType.text,
    String? mediaUrl,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      // Insertar el mensaje
      final data = await _client
          .from(_messagesTable)
          .insert({
            'conversation_id': conversationId,
            'sender_id': senderId,
            'content': content,
            'type': type.value,
            'media_url': mediaUrl,
            'is_read': false,
            'created_at': now,
          })
          .select()
          .single();

      final message = Message.fromJson(data);

      // Actualizar metadatos de la conversación
      await _updateConversationMetadata(
        conversationId: conversationId,
        lastMessage: content,
        lastMessageAt: now,
        senderId: senderId,
      );

      return message;
    } catch (e, st) {
      debugPrint('Error enviando mensaje: $e\n$st');
      rethrow;
    }
  }

  /// Marca todos los mensajes de una conversación como leídos
  /// para el usuario indicado.
  ///
  /// Solo marca mensajes que NO fueron enviados por [userId]
  /// (es decir, los mensajes recibidos).
  Future<void> markAsRead(String conversationId, String userId) async {
    try {
      await _client
          .from(_messagesTable)
          .update({'is_read': true})
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId)
          .eq('is_read', false);

      // Resetear el contador de no leídos en la conversación
      await _client
          .from(_conversationsTable)
          .update({'unread_count': 0})
          .eq('id', conversationId);

      debugPrint('Mensajes marcados como leídos en $conversationId.');
    } catch (e, st) {
      debugPrint('Error marcando mensajes como leídos: $e\n$st');
    }
  }

  /// Obtiene el total de mensajes no leídos del usuario.
  ///
  /// Suma los `unread_count` de todas las conversaciones del usuario.
  Future<int> getUnreadCount(String userId) async {
    try {
      final data = await _client
          .from(_conversationsTable)
          .select('unread_count')
          .or('user_id.eq.$userId,participant_id.eq.$userId')
          as List<dynamic>? ?? [];

      int total = 0;
      for (final row in data.cast<Map<String, dynamic>>()) {
        total += (row['unread_count'] as int? ?? 0);
      }
      return total;
    } catch (e, st) {
      debugPrint('Error obteniendo conteo de no leídos: $e\n$st');
      return 0;
    }
  }

  // ─── Helpers privados ─────────────────────────────────────────────

  /// Actualiza los metadatos de una conversación después de enviar
  /// un mensaje (último mensaje, timestamp, incrementar no leídos).
  Future<void> _updateConversationMetadata({
    required String conversationId,
    required String lastMessage,
    required String lastMessageAt,
    required String senderId,
  }) async {
    try {
      // Obtener la conversación para saber quién es el receptor
      final conv = await _client
          .from(_conversationsTable)
          .select('user_id, participant_id, unread_count')
          .eq('id', conversationId)
          .single();

      // Incrementar unread_count solo para el receptor
      final currentUnread = conv['unread_count'] as int? ?? 0;

      // Truncar el preview del último mensaje
      final preview = lastMessage.length > 100
          ? '${lastMessage.substring(0, 100)}…'
          : lastMessage;

      await _client
          .from(_conversationsTable)
          .update({
            'last_message': preview,
            'last_message_at': lastMessageAt,
            'unread_count': currentUnread + 1,
            'updated_at': lastMessageAt,
          })
          .eq('id', conversationId);
    } catch (e, st) {
      debugPrint('Error actualizando metadatos de conversación: $e\n$st');
    }
  }

  /// Mapea el resultado de un join conversations ↔ profiles a un [Conversation].
  ///
  /// Supabase retorna la relación como un objeto anidado en `participant`.
  /// Extraemos `full_name`, `avatar_url` e `is_online` y los inyectamos
  /// como campos planos.
  Conversation _mapConversation(
    Map<String, dynamic> json,
    String currentUserId,
  ) {
    final mapped = Map<String, dynamic>.from(json);

    // Determinar quién es el "otro" participante.
    // Si el current user es el `user_id`, el participante es `participant_id`
    // y viceversa.
    final rawUserId = json['user_id'] as String?;
    final rawParticipantId = json['participant_id'] as String?;

    final isCurrentUserOwner = rawUserId == currentUserId;
    final otherUserId = isCurrentUserOwner ? rawParticipantId : rawUserId;

    // Resolver datos del participante desde el join
    final participant = json['participant'];
    if (participant is Map<String, dynamic>) {
      mapped['participant_name'] =
          participant['full_name'] ?? 'Usuario';
      mapped['participant_avatar_url'] = participant['avatar_url'];
      mapped['is_online'] = participant['is_online'] ?? false;
    } else {
      mapped['participant_name'] = 'Usuario';
      mapped['is_online'] = false;
    }

    mapped['participant_id'] = otherUserId ?? '';

    // Eliminar el objeto anidado para que fromJson no falle
    mapped.remove('participant');
    mapped.remove('user_id');

    return Conversation.fromJson(mapped);
  }
}
