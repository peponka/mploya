import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PushNotificationService — FCM + Supabase token persistence
//
// Responsabilidades:
//  • Inicializar Firebase Messaging
//  • Solicitar permisos (crítico para iOS)
//  • Persistir FCM token en tabla users.fcm_token
//  • Handlers: foreground, background, terminated
//  • Cleanup en logout
// ─────────────────────────────────────────────────────────────────────────────

/// Handler background (debe ser top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📬 BG push: ${message.notification?.title}');
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _fcmToken;
  String? get fcmToken => _fcmToken;
  StreamSubscription<String>? _tokenRefreshSub;

  // Callbacks externos
  void Function(RemoteMessage)? _onForegroundMessage;
  void Function(RemoteMessage)? _onNotificationTapped;

  // ── Inicialización completa ─────────────────────────────────────────────

  Future<void> initialize() async {
    try {
      // Registrar handler background
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Solicitar permisos
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('📱 Push permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await _getAndSaveToken();
        _listenTokenRefresh();
        _setupHandlers();
      }
    } catch (e) {
      debugPrint('Error inicializando Push: $e');
    }
  }

  // ── Método legacy estático (backward compatibility) ─────────────────────

  static Future<void> init() async {
    await instance.initialize();
  }

  // ── Token ───────────────────────────────────────────────────────────────

  Future<void> _getAndSaveToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      debugPrint('📱 FCM Token obtenido');
      await _persistToken(_fcmToken);
    } catch (e) {
      debugPrint('Error obteniendo FCM token: $e');
    }
  }

  void _listenTokenRefresh() {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      _persistToken(newToken);
    });
  }

  Future<void> _persistToken(String? token) async {
    if (token == null) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      await Supabase.instance.client
          .from('users')
          .update({'fcm_token': token})
          .eq('id', uid);
    } catch (e) {
      debugPrint('Error persistiendo FCM token: $e');
    }
  }

  // ── Handlers ────────────────────────────────────────────────────────────

  void _setupHandlers() {
    // Foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📬 FG push: ${message.notification?.title}');
      _onForegroundMessage?.call(message);
    });

    // App abierta desde notificación (background → foreground)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📬 Opened from BG: ${message.data}');
      _onNotificationTapped?.call(message);
    });
  }

  // ── Callbacks para conectar desde la UI ─────────────────────────────────

  void onForegroundMessage(void Function(RemoteMessage) callback) {
    _onForegroundMessage = callback;
  }

  void onNotificationTapped(void Function(RemoteMessage) callback) {
    _onNotificationTapped = callback;
  }

  /// Obtener mensaje que abrió la app desde terminated
  Future<RemoteMessage?> getInitialMessage() async {
    return await _messaging.getInitialMessage();
  }

  // ── Cleanup (llamar en sign-out) ────────────────────────────────────────

  Future<void> clearToken() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _fcmToken = null;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await Supabase.instance.client
          .from('users')
          .update({'fcm_token': null})
          .eq('id', uid);
    } catch (e) {
      debugPrint('⚠️ PushNotificationService.clearToken: $e');
    }
  }

  // ── Enviar push a otro usuario via Edge Function ────────────────────────

  /// Invoca la Edge Function `send-fcm` para enviar una notificación push
  /// a [targetUserId]. Útil como fallback o para eventos custom.
  ///
  /// Los Database Webhooks manejan: connections, reactions, comments.
  /// Esta función se usa para: mensajes de chat y notificaciones custom.
  static Future<void> sendPushToUser({
    required String targetUserId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'send-fcm',
        body: {
          'target_user_id': targetUserId,
          'title': title,
          'body': body,
          if (data != null) 'data': data,
        },
      );
    } catch (e) {
      // No bloquear la UI si falla el push
      debugPrint('⚠️ sendPushToUser: $e');
    }
  }
}
