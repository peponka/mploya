import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NotificationService — Centraliza operaciones de notificaciones.
//
// Extrae la lógica de negocio de notifications_screen.dart:
//  • Mark as read (individual y masivo)
//  • Insights dashboard (profile views, matches, pitches)
//  • Formateo de timestamps
// ─────────────────────────────────────────────────────────────────────────────

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  SupabaseClient get _db => Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;

  // ── Cache de insights ──
  int? _cachedViews;
  int? _cachedMatches;
  int? _cachedPitches;
  DateTime? _insightsCacheTime;
  static const _insightsCacheDuration = Duration(minutes: 2);

  bool get _isInsightsCacheValid =>
      _insightsCacheTime != null &&
      DateTime.now().difference(_insightsCacheTime!) < _insightsCacheDuration;

  /// Stream de notificaciones del usuario actual, ordenadas por fecha.
  Stream<List<Map<String, dynamic>>> get notificationsStream {
    if (_uid == null) return const Stream.empty();
    try {
      return _db
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', _uid!)
          .order('created_at', ascending: false)
          .limit(60)
          .handleError((e) {
            debugPrint('⚠️ notificationsStream error (non-fatal): $e');
          });
    } catch (e) {
      debugPrint('⚠️ notificationsStream init failed: $e');
      return const Stream.empty();
    }
  }

  /// Marca una notificación como leída.
  Future<void> markAsRead(String notificationId) async {
    try {
      await _db
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('❌ NotificationService.markAsRead: $e');
    }
  }

  /// Marca múltiples notificaciones como leídas.
  Future<void> markAllAsRead(List<String> notificationIds) async {
    if (notificationIds.isEmpty) return;
    try {
      await _db
          .from('notifications')
          .update({'is_read': true})
          .inFilter('id', notificationIds);
    } catch (e) {
      debugPrint('❌ NotificationService.markAllAsRead: $e');
    }
  }

  /// Carga métricas de insights con caché de 2 minutos.
  Future<({int views, int matches, int pitches})> getInsights({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _isInsightsCacheValid) {
      return (
        views: _cachedViews ?? 0,
        matches: _cachedMatches ?? 0,
        pitches: _cachedPitches ?? 0,
      );
    }

    if (_uid == null) return (views: 0, matches: 0, pitches: 0);

    try {
      final viewsFuture = _db
          .from('notifications')
          .select('id')
          .eq('user_id', _uid!)
          .eq('type', 'profileView');

      final matchesFuture = _db
          .from('nexus_signals')
          .select('id')
          .or('sender_id.eq.$_uid,receiver_id.eq.$_uid')
          .eq('status', 'matched');

      final pitchesFuture = _db
          .from('nexus_signals')
          .select('id')
          .eq('receiver_id', _uid!)
          .eq('signal_type', 'micro_pitch');

      // Ejecutar las 3 queries en paralelo
      final results = await Future.wait([viewsFuture, matchesFuture, pitchesFuture]);

      _cachedViews = (results[0] as List).length;
      _cachedMatches = (results[1] as List).length;
      _cachedPitches = (results[2] as List).length;
      _insightsCacheTime = DateTime.now();

      return (
        views: _cachedViews!,
        matches: _cachedMatches!,
        pitches: _cachedPitches!,
      );
    } catch (e) {
      debugPrint('❌ NotificationService.getInsights: $e');
      return (
        views: _cachedViews ?? 0,
        matches: _cachedMatches ?? 0,
        pitches: _cachedPitches ?? 0,
      );
    }
  }

  /// Formatea un timestamp a string relativo (2h, 3d, Ahora).
  String timeAgo(dynamic raw) {
    if (raw == null) return 'Reciente';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return 'Reciente';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'Ahora';
  }

  /// Genera un tip contextual basado en las métricas del usuario.
  String getInsightTip(int pitches, int matches, int views) {
    if (pitches > 0) {
      return 'Tenés $pitches video replies. Revisalos en tu perfil para ver oportunidades.';
    }
    if (matches > 0) {
      return 'Ya hiciste $matches matches. Iniciar conversación aumenta 3x las chances de entrevista.';
    }
    if (views > 3) {
      return 'Tu perfil tuvo $views vistas. Completar tu pitch mejora la conversión un 40%.';
    }
    return 'Completá tu perfil y grabá un video pitch para aumentar tu visibilidad.';
  }

  /// Genera un tip contextual para usuarios stealth/confidencial.
  /// Retorna null si no hay tip relevante que mostrar.
  String? getStealthTip(dynamic user) {
    // Verificar si el usuario tiene campos clave completos
    final hasVideo = user.videoUrl != null && (user.videoUrl as String).isNotEmpty;
    final hasAbout = user.about != null && (user.about as String).isNotEmpty;
    final hasTags = user.tags != null && (user.tags as List).isNotEmpty;

    if (!hasVideo) {
      return '👁️ Empresas están buscando perfiles como el tuyo. Grabá un video-pitch para multiplicar tu visibilidad stealth.';
    }
    if (!hasAbout) {
      return '👁️ Tu perfil ciego necesita una descripción anónima. Completala para mejorar tu match con reclutadores.';
    }
    if (!hasTags) {
      return '👁️ Agregá habilidades a tu perfil para que el algoritmo te conecte con las empresas correctas.';
    }
    // Tip genérico de engagement
    return '👁️ Tu perfil stealth está activo. Las empresas ven tu CV ciego — seguí completando logros para mejorar el match.';
  }

  /// Invalida el cache de insights.
  void invalidateInsightsCache() {
    _insightsCacheTime = null;
  }

  // ── Notificaciones Geolocalizadas (Punto 6) ──────────────────────────────

  /// Verifica empresas cercanas y crea notificación si hay resultados.
  /// Llama al RPC PostGIS `nearby_companies`.
  /// Retorna el número de empresas encontradas.
  Future<int> checkNearbyCompanies({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
  }) async {
    if (_uid == null) return 0;

    try {
      final results = await _db.rpc('nearby_companies', params: {
        'p_lat': latitude,
        'p_lng': longitude,
        'p_radius_km': radiusKm,
      });

      final companies = List<Map<String, dynamic>>.from(results ?? []);
      
      if (companies.isNotEmpty) {
        // Crear notificación geo
        await createGeoNotification(companies.length, companies);
      }

      return companies.length;
    } catch (e) {
      debugPrint('❌ NotificationService.checkNearbyCompanies: $e');
      return 0;
    }
  }

  /// Crea una notificación geo con la cantidad de empresas cercanas
  Future<void> createGeoNotification(
    int count, 
    List<Map<String, dynamic>> companies,
  ) async {
    if (_uid == null) return;

    final firstNames = companies
        .take(2)
        .map((c) => c['name']?.toString() ?? 'Empresa')
        .join(', ');

    final description = count == 1
        ? '📍 $firstNames está cerca tuyo. ¡Explorá su perfil!'
        : '📍 $count empresas cerca tuyo: $firstNames${count > 2 ? ' y más' : ''}';

    try {
      // Usa RPC SECURITY DEFINER para bypasear la restricción de INSERT.
      // La política de notifications ahora requiere actor_id = auth.uid(),
      // pero las notificaciones geo son "del sistema" (sin actor).
      await _db.rpc('create_system_notification', params: {
        'p_user_id': _uid,
        'p_type': 'jobAlert',
        'p_description': description,
      });
    } catch (e) {
      debugPrint('❌ NotificationService.createGeoNotification: $e');
    }
  }

  /// Obtiene empresas cercanas (sin crear notificación)
  Future<List<Map<String, dynamic>>> getNearbyCompanies({
    required double latitude,
    required double longitude,
    double radiusKm = 50,
  }) async {
    try {
      final results = await _db.rpc('nearby_companies', params: {
        'p_lat': latitude,
        'p_lng': longitude,
        'p_radius_km': radiusKm,
      });
      return List<Map<String, dynamic>>.from(results ?? []);
    } catch (e) {
      debugPrint('❌ NotificationService.getNearbyCompanies: $e');
      return [];
    }
  }
}
