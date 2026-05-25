/// Servicio de notificaciones push con Firebase Cloud Messaging.
///
/// Singleton que gestiona permisos, token FCM, y manejo de mensajes.
/// Todas las operaciones están envueltas en try-catch para funcionar
/// incluso si Firebase no está configurado.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';

import 'package:mploya/config/routes.dart';
import 'package:mploya/core/services/supabase_service.dart';

/// Handler de mensajes en background. Debe ser función top-level.
///
/// Se registra en `main()` para procesar notificaciones cuando
/// la app está cerrada o en segundo plano.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📩 Mensaje en background: ${message.messageId}');
}

/// Servicio centralizado de notificaciones push.
///
/// ```dart
/// await NotificationService.instance.initialize();
/// ```
class NotificationService {
  NotificationService._();

  static NotificationService? _instance;

  /// Instancia singleton del servicio.
  static NotificationService get instance {
    _instance ??= NotificationService._();
    return _instance!;
  }

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _fcmToken;
  StreamSubscription<String>? _tokenRefreshSubscription;

  /// Token FCM actual, si está disponible.
  String? get fcmToken => _fcmToken;

  // ─────────────────────────────────────────
  // Inicialización
  // ─────────────────────────────────────────

  /// Inicializa el servicio de notificaciones.
  ///
  /// Solicita permisos, obtiene el token FCM y configura los handlers.
  /// Si Firebase no está configurado, falla silenciosamente.
  Future<void> initialize() async {
    try {
      // Solicitar permisos de notificación.
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('⚠️ Permisos de notificación denegados.');
        return;
      }

      debugPrint(
        '✅ Permisos de notificación: ${settings.authorizationStatus}',
      );

      // Obtener el token FCM.
      _fcmToken = await _messaging.getToken();
      debugPrint('🔑 FCM Token: $_fcmToken');

      // Guardar token en Supabase si hay usuario autenticado.
      if (_fcmToken != null) {
        await _saveFcmToken(_fcmToken!);
      }

      // Escuchar cambios de token (puede rotar).
      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('🔄 FCM Token actualizado: $newToken');
        _saveFcmToken(newToken);
      });

      // Configurar handlers de mensajes.
      _setupForegroundHandler();

      debugPrint('✅ NotificationService inicializado correctamente.');
    } catch (e) {
      debugPrint('⚠️ NotificationService: Error al inicializar: $e');
      debugPrint('   Las notificaciones push estarán desactivadas.');
    }
  }

  // ─────────────────────────────────────────
  // Token FCM → Supabase
  // ─────────────────────────────────────────

  /// Guarda el token FCM en la columna `fcm_token` de la tabla `profiles`.
  Future<void> _saveFcmToken(String token) async {
    try {
      final user = SupabaseService.instance.currentUser;
      if (user == null) {
        debugPrint('ℹ️ No hay usuario autenticado para guardar FCM token.');
        return;
      }

      await SupabaseService.instance.client
          .from('profiles')
          .update({'fcm_token': token}).eq('id', user.id);

      debugPrint('✅ FCM Token guardado en Supabase.');
    } catch (e) {
      debugPrint('⚠️ Error guardando FCM token: $e');
    }
  }

  // ─────────────────────────────────────────
  // Handlers de mensajes
  // ─────────────────────────────────────────

  /// Configura el handler para mensajes recibidos en foreground.
  void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? 'Sin título';
      final body = message.notification?.body ?? '';
      debugPrint('📩 [FOREGROUND NOTIFICATION] Título: $title');
      debugPrint('📩 [FOREGROUND NOTIFICATION] Cuerpo: $body');
      debugPrint('📩 [FOREGROUND NOTIFICATION] Data: ${message.data}');

      // TODO: Show a local notification using flutter_local_notifications
      // or a SnackBar via GlobalKey<ScaffoldMessengerState> so the user
      // sees the notification while the app is open.
      _handleMessage(message);
    });

    // Cuando el usuario toca una notificación y la app estaba en background.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📩 Notificación abierta: ${message.data}');
      onNotificationTap(message.data);
    });
  }

  /// Procesa un mensaje recibido (logging y preparación de datos).
  void _handleMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      debugPrint('   Título: ${notification.title}');
      debugPrint('   Cuerpo: ${notification.body}');
    }
    debugPrint('   Data: ${message.data}');
  }

  /// Maneja el tap en una notificación para navegar a la pantalla correcta.
  ///
  /// Se espera que [data] contenga un campo `type` que indique
  /// la acción a realizar (ej: `chat`, `match`, `boost`).
  void onNotificationTap(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    switch (type) {
      case 'chat':
        final conversationId = data['conversation_id'] ?? data['chatId'] ?? '';
        debugPrint('🔗 Navegar a chat: $conversationId');
        _navigateTo('/chat/$conversationId');
        break;
      case 'match':
        debugPrint('🔗 Navegar a matches');
        _navigateTo('/home?tab=2');
        break;
      case 'boost':
        debugPrint('🔗 Navegar a boost');
        _navigateTo('/tools/boost');
        break;
      default:
        debugPrint('ℹ️ Tipo de notificación no reconocido: $type');
    }
  }

  /// Navigates to [path] using GoRouter from outside the widget tree.
  ///
  /// Uses the [rootNavigatorKey] defined in `routes.dart` to obtain
  /// a valid [BuildContext].
  void _navigateTo(String path) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      debugPrint('⚠️ No se pudo navegar: navigatorKey sin contexto.');
      return;
    }
    GoRouter.of(context).go(path);
  }

  /// Verifica si hay un mensaje inicial (app abierta desde notificación).
  Future<void> checkInitialMessage() async {
    try {
      final message = await _messaging.getInitialMessage();
      if (message != null) {
        debugPrint('📩 Mensaje inicial: ${message.data}');
        onNotificationTap(message.data);
      }
    } catch (e) {
      debugPrint('⚠️ Error verificando mensaje inicial: $e');
    }
  }

  /// Cancels all stream subscriptions and cleans up resources.
  ///
  /// Call this when the service is no longer needed.
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    debugPrint('🧹 NotificationService disposed.');
  }
}
