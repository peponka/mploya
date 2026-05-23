/// Providers de Riverpod para notificaciones.
///
/// Gestiona la lista de notificaciones, conteo de no leídas
/// y la acción de marcar como leída.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mploya/core/models/notification_model.dart';

// ─── Mock Data ─────────────────────────────────────────────────────

final List<NotificationModel> _mockNotifications = [
  NotificationModel(
    id: 'n1',
    userId: 'current_user',
    type: NotificationType.connectionRequest,
    title: 'Solicitud de conexión',
    body: 'María García quiere conectar contigo',
    isRead: false,
    createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
    senderName: 'María García',
    senderAvatarUrl: 'https://i.pravatar.cc/150?img=1',
    data: {'sender_id': 'u1'},
  ),
  NotificationModel(
    id: 'n2',
    userId: 'current_user',
    type: NotificationType.matchInterest,
    title: 'Nuevo match',
    body: 'TechStartup MX está interesado en tu perfil (95% match)',
    isRead: false,
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    senderName: 'TechStartup MX',
    senderAvatarUrl: 'https://i.pravatar.cc/150?img=12',
    data: {'match_id': 'm6', 'match_percentage': 95},
  ),
  NotificationModel(
    id: 'n3',
    userId: 'current_user',
    type: NotificationType.profileView,
    title: 'Vista de perfil',
    body: 'Carlos Mendoza vio tu perfil',
    isRead: true,
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    senderName: 'Carlos Mendoza',
    senderAvatarUrl: 'https://i.pravatar.cc/150?img=3',
    data: {'viewer_id': 'u2'},
  ),
  NotificationModel(
    id: 'n4',
    userId: 'current_user',
    type: NotificationType.system,
    title: 'Completa tu perfil',
    body: 'Tu perfil está al 65%. Agrega tu video pitch para llegar al 80%.',
    isRead: true,
    createdAt: DateTime.now().subtract(const Duration(hours: 12)),
    data: {'profile_completion': 65},
  ),
  NotificationModel(
    id: 'n5',
    userId: 'current_user',
    type: NotificationType.matchInterest,
    title: 'Match mutuo',
    body: 'Ana Rodríguez y tú hicieron match (92% compatibilidad)',
    isRead: false,
    createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    senderName: 'Ana Rodríguez',
    senderAvatarUrl: 'https://i.pravatar.cc/150?img=5',
    data: {'match_id': 'm3', 'match_percentage': 92},
  ),
  NotificationModel(
    id: 'n6',
    userId: 'current_user',
    type: NotificationType.connectionRequest,
    title: 'Solicitud de conexión',
    body: 'Diego Fernández quiere conectar contigo',
    isRead: true,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    senderName: 'Diego Fernández',
    senderAvatarUrl: 'https://i.pravatar.cc/150?img=8',
    data: {'sender_id': 'u4'},
  ),
  NotificationModel(
    id: 'n7',
    userId: 'current_user',
    type: NotificationType.system,
    title: '¡Nuevo challenge semanal!',
    body: 'El pitch challenge de esta semana ya está disponible. ¡Participa!',
    isRead: true,
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    data: {'challenge_id': 'ch1'},
  ),
];

// ─── Notifications Provider ────────────────────────────────────────

class NotificationsNotifier
    extends StateNotifier<AsyncValue<List<NotificationModel>>> {
  NotificationsNotifier() : super(const AsyncValue.loading()) {
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    state = const AsyncValue.loading();
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      state = AsyncValue.data(List.from(_mockNotifications));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final current = state.valueOrNull ?? [];
    final updated = current.map((n) {
      if (n.id == notificationId) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();
    state = AsyncValue.data(updated);
  }

  Future<void> markAllAsRead() async {
    final current = state.valueOrNull ?? [];
    final updated = current.map((n) => n.copyWith(isRead: true)).toList();
    state = AsyncValue.data(updated);
  }

  Future<void> deleteNotification(String notificationId) async {
    final current = state.valueOrNull ?? [];
    final updated = current.where((n) => n.id != notificationId).toList();
    state = AsyncValue.data(updated);
  }

  Future<void> refresh() async => loadNotifications();
}

final notificationsProvider = StateNotifierProvider<NotificationsNotifier,
    AsyncValue<List<NotificationModel>>>(
  (ref) => NotificationsNotifier(),
);

// ─── Unread Count Provider ─────────────────────────────────────────

final unreadCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider).valueOrNull ?? [];
  return notifications.where((n) => !n.isRead).length;
});

// ─── Mark As Read Provider ─────────────────────────────────────────

/// Convenience provider to mark a notification as read by ID.
final markAsReadProvider = Provider<Future<void> Function(String)>((ref) {
  return (String id) =>
      ref.read(notificationsProvider.notifier).markAsRead(id);
});
