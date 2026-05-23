/// Proveedores de Riverpod para el módulo de mensajería.
///
/// Gestiona el estado reactivo de conversaciones, mensajes,
/// conteo de no leídos y acciones de envío. Usa streams de Supabase
/// Realtime para actualizaciones en tiempo real.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mploya/features/auth/providers/auth_provider.dart';
import 'package:mploya/features/messaging/models/message_model.dart';
import 'package:mploya/features/messaging/services/messaging_service.dart';

// ─── Service Provider ──────────────────────────────────────────────

/// Proveedor del singleton de [MessagingService].
final messagingServiceProvider = Provider<MessagingService>((ref) {
  return MessagingService.instance;
});

// ─── Conversations State ───────────────────────────────────────────

/// Estado de la lista de conversaciones.
sealed class ConversationsState {
  const ConversationsState();
}

class ConversationsInitial extends ConversationsState {
  const ConversationsInitial();
}

class ConversationsLoading extends ConversationsState {
  const ConversationsLoading();
}

class ConversationsLoaded extends ConversationsState {
  const ConversationsLoaded(this.conversations);
  final List<Conversation> conversations;
}

class ConversationsError extends ConversationsState {
  const ConversationsError(this.message);
  final String message;
}

// ─── Conversations Notifier ────────────────────────────────────────

/// Notifier que gestiona la lista de conversaciones del usuario.
///
/// - Carga las conversaciones al inicializar.
/// - Se suscribe al stream en tiempo real para actualizaciones automáticas.
/// - Ordena por `lastMessageAt` descendente.
/// - Expone método para refrescar manualmente.
class ConversationsNotifier extends StateNotifier<ConversationsState> {
  ConversationsNotifier(this._service) : super(const ConversationsInitial());

  final MessagingService _service;
  StreamSubscription<List<Conversation>>? _subscription;
  String? _currentUserId;

  /// Carga las conversaciones e inicia el stream en tiempo real.
  ///
  /// Debe llamarse después de que el usuario se haya autenticado.
  void loadConversations(String userId) {
    _currentUserId = userId;
    state = const ConversationsLoading();

    // Cancelar suscripción anterior si existe
    _subscription?.cancel();

    // Suscribirse al stream en tiempo real
    _subscription = _service.conversationsStream(userId).listen(
      (conversations) {
        // Ordenar por último mensaje (más reciente primero)
        final sorted = List<Conversation>.from(conversations)
          ..sort((a, b) {
            final aTime = a.lastMessageAt ?? DateTime(1970);
            final bTime = b.lastMessageAt ?? DateTime(1970);
            return bTime.compareTo(aTime);
          });

        state = ConversationsLoaded(sorted);
      },
      onError: (error) {
        debugPrint('Error en stream de conversaciones: $error');
        state = ConversationsError(
          'Error al cargar conversaciones: $error',
        );
      },
    );
  }

  /// Refresca manualmente las conversaciones.
  Future<void> refresh() async {
    if (_currentUserId == null) return;

    try {
      final conversations =
          await _service.getConversations(_currentUserId!);

      final sorted = List<Conversation>.from(conversations)
        ..sort((a, b) {
          final aTime = a.lastMessageAt ?? DateTime(1970);
          final bTime = b.lastMessageAt ?? DateTime(1970);
          return bTime.compareTo(aTime);
        });

      state = ConversationsLoaded(sorted);
    } catch (e) {
      debugPrint('Error refrescando conversaciones: $e');
      state = ConversationsError('Error al refrescar: $e');
    }
  }

  /// Elimina una conversación y actualiza el estado local.
  Future<void> deleteConversation(String conversationId) async {
    try {
      await _service.deleteConversation(conversationId);

      // Actualizar estado local inmediatamente (optimistic)
      if (state is ConversationsLoaded) {
        final current = (state as ConversationsLoaded).conversations;
        final updated =
            current.where((c) => c.id != conversationId).toList();
        state = ConversationsLoaded(updated);
      }
    } catch (e) {
      debugPrint('Error eliminando conversación: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

// ─── Conversations Provider ────────────────────────────────────────

/// Proveedor principal del estado de conversaciones.
///
/// Se inicializa automáticamente cuando el usuario está autenticado.
final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, ConversationsState>((ref) {
  final service = ref.watch(messagingServiceProvider);
  final notifier = ConversationsNotifier(service);

  // Auto-inicializar con el usuario actual
  final authState = ref.watch(authProvider);
  if (authState is Authenticated) {
    notifier.loadConversations(authState.user.id);
  }

  ref.onDispose(() {
    notifier.dispose();
  });

  return notifier;
});

// ─── Messages State ────────────────────────────────────────────────

/// Estado de la lista de mensajes de una conversación.
sealed class MessagesState {
  const MessagesState();
}

class MessagesInitial extends MessagesState {
  const MessagesInitial();
}

class MessagesLoading extends MessagesState {
  const MessagesLoading();
}

class MessagesLoaded extends MessagesState {
  const MessagesLoaded({
    required this.messages,
    this.hasMore = true,
    this.isSending = false,
  });

  final List<Message> messages;

  /// Si hay más mensajes para cargar (paginación).
  final bool hasMore;

  /// Si se está enviando un mensaje actualmente.
  final bool isSending;

  MessagesLoaded copyWith({
    List<Message>? messages,
    bool? hasMore,
    bool? isSending,
  }) {
    return MessagesLoaded(
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      isSending: isSending ?? this.isSending,
    );
  }
}

class MessagesError extends MessagesState {
  const MessagesError(this.message);
  final String message;
}

// ─── Messages Notifier ─────────────────────────────────────────────

/// Notifier que gestiona los mensajes de una conversación específica.
///
/// - Carga mensajes con paginación.
/// - Se suscribe al stream en tiempo real para mensajes nuevos.
/// - Soporta envío con actualización optimista.
/// - Marca mensajes como leídos automáticamente.
class MessagesNotifier extends StateNotifier<MessagesState> {
  MessagesNotifier(this._service, this._conversationId)
      : super(const MessagesInitial());

  final MessagingService _service;
  final String _conversationId;
  StreamSubscription<List<Message>>? _subscription;

  static const _pageSize = 50;
  int _currentOffset = 0;

  /// Carga los mensajes iniciales e inicia el stream en tiempo real.
  void loadMessages() {
    state = const MessagesLoading();
    _currentOffset = 0;

    // Cancelar suscripción anterior
    _subscription?.cancel();

    // Suscribirse al stream en tiempo real
    _subscription = _service.messagesStream(_conversationId).listen(
      (messages) {
        state = MessagesLoaded(
          messages: messages,
          hasMore: messages.length >= _pageSize,
        );
      },
      onError: (error) {
        debugPrint('Error en stream de mensajes: $error');
        state = MessagesError('Error al cargar mensajes: $error');
      },
    );
  }

  /// Carga más mensajes antiguos (paginación).
  Future<void> loadMore() async {
    if (state is! MessagesLoaded) return;
    final currentState = state as MessagesLoaded;
    if (!currentState.hasMore) return;

    try {
      _currentOffset += _pageSize;

      final olderMessages = await _service.getMessages(
        _conversationId,
        limit: _pageSize,
        offset: _currentOffset,
      );

      final allMessages = [
        ...currentState.messages,
        ...olderMessages,
      ];

      // Deduplicar por ID
      final seen = <String>{};
      final unique = allMessages.where((m) => seen.add(m.id)).toList();

      state = currentState.copyWith(
        messages: unique,
        hasMore: olderMessages.length >= _pageSize,
      );
    } catch (e) {
      debugPrint('Error cargando más mensajes: $e');
    }
  }

  /// Envía un mensaje con actualización optimista.
  ///
  /// Agrega el mensaje localmente de inmediato y luego lo confirma
  /// con la respuesta del servidor. Si falla, marca el error.
  Future<void> sendMessage({
    required String senderId,
    required String content,
    MessageType type = MessageType.text,
    String? mediaUrl,
  }) async {
    if (state is! MessagesLoaded) return;
    final currentState = state as MessagesLoaded;

    // Mensaje optimista temporal
    final optimisticMessage = Message(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: _conversationId,
      senderId: senderId,
      content: content,
      type: type,
      mediaUrl: mediaUrl,
      isRead: false,
      createdAt: DateTime.now(),
    );

    // Insertar optimísticamente al inicio (más reciente primero)
    state = currentState.copyWith(
      messages: [optimisticMessage, ...currentState.messages],
      isSending: true,
    );

    try {
      final sentMessage = await _service.sendMessage(
        conversationId: _conversationId,
        senderId: senderId,
        content: content,
        type: type,
        mediaUrl: mediaUrl,
      );

      // Reemplazar el mensaje optimista con el real
      if (state is MessagesLoaded) {
        final current = (state as MessagesLoaded).messages;
        final updated = current.map((m) {
          if (m.id == optimisticMessage.id) return sentMessage;
          return m;
        }).toList();

        state = (state as MessagesLoaded).copyWith(
          messages: updated,
          isSending: false,
        );
      }
    } catch (e) {
      debugPrint('Error enviando mensaje: $e');

      // Remover el mensaje optimista en caso de error
      if (state is MessagesLoaded) {
        final current = (state as MessagesLoaded).messages;
        final updated =
            current.where((m) => m.id != optimisticMessage.id).toList();

        state = (state as MessagesLoaded).copyWith(
          messages: updated,
          isSending: false,
        );
      }
      rethrow;
    }
  }

  /// Marca todos los mensajes de la conversación como leídos.
  Future<void> markAsRead(String userId) async {
    try {
      await _service.markAsRead(_conversationId, userId);

      // Actualizar estado local
      if (state is MessagesLoaded) {
        final current = (state as MessagesLoaded).messages;
        final updated = current.map((m) {
          if (m.senderId != userId && !m.isRead) {
            return m.copyWith(isRead: true);
          }
          return m;
        }).toList();

        state = (state as MessagesLoaded).copyWith(messages: updated);
      }
    } catch (e) {
      debugPrint('Error marcando como leído: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

// ─── Messages Provider (family) ────────────────────────────────────

/// Proveedor de mensajes por conversación.
///
/// Usa `.family` para crear un notifier independiente por cada
/// `conversationId`. Cada instancia mantiene su propio stream
/// de Supabase Realtime.
///
/// ```dart
/// final messagesState = ref.watch(messagesProvider(conversationId));
/// ref.read(messagesProvider(conversationId).notifier).sendMessage(...);
/// ```
final messagesProvider = StateNotifierProvider.family<
    MessagesNotifier, MessagesState, String>((ref, conversationId) {
  final service = ref.watch(messagingServiceProvider);
  final notifier = MessagesNotifier(service, conversationId);

  // Auto-cargar mensajes al crear el notifier
  notifier.loadMessages();

  ref.onDispose(() {
    notifier.dispose();
  });

  return notifier;
});

// ─── Unread Count Provider ─────────────────────────────────────────

/// Proveedor del total de mensajes no leídos del usuario.
///
/// Se recalcula automáticamente cuando cambia el estado de las
/// conversaciones. Ideal para badges en la navegación.
final unreadCountProvider = Provider<int>((ref) {
  final convState = ref.watch(conversationsProvider);

  if (convState is ConversationsLoaded) {
    return convState.conversations.fold<int>(
      0,
      (total, conv) => total + conv.unreadCount,
    );
  }
  return 0;
});

// ─── Send Message Provider ─────────────────────────────────────────

/// Proveedor para enviar mensajes.
///
/// Encapsula la lógica de envío con el usuario actual y
/// proporciona un API limpio desde los widgets.
///
/// ```dart
/// await ref.read(sendMessageProvider)(
///   conversationId: 'conv-123',
///   content: 'Hola!',
/// );
/// ```
final sendMessageProvider = Provider<
    Future<void> Function({
      required String conversationId,
      required String content,
      MessageType type,
      String? mediaUrl,
    })>((ref) {
  return ({
    required String conversationId,
    required String content,
    MessageType type = MessageType.text,
    String? mediaUrl,
  }) async {
    final authState = ref.read(authProvider);
    if (authState is! Authenticated) {
      throw StateError('Usuario no autenticado');
    }

    final senderId = authState.user.id;
    final notifier = ref.read(messagesProvider(conversationId).notifier);

    await notifier.sendMessage(
      senderId: senderId,
      content: content,
      type: type,
      mediaUrl: mediaUrl,
    );
  };
});
