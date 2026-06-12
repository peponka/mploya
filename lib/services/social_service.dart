import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SocialService — RPCs de conexiones, likes y ratings del Video-Pitch.
//
// Métodos:
//  • sendConnectionRequest(addresseeId)   — Envía solicitud de conexión
//  • respondConnection(requesterId, action) — Acepta o rechaza solicitud
//  • getConnectionStatus(otherUserId)     — Consulta estado de conexión
//  • togglePitchLike(pitchOwnerId)        — Like/Unlike sobre Video-Pitch
//  • rateUser(targetId, stars)            — Califica un perfil (1-5 estrellas)
//
// Todos devuelven un Map con los datos de respuesta o {'error': 'mensaje'}.
// ─────────────────────────────────────────────────────────────────────────────

class SocialService {
  SocialService._();
  static final SocialService instance = SocialService._();

  SupabaseClient get _db => Supabase.instance.client;

  // ── Connections ─────────────────────────────────────────────────────────

  /// Envía una solicitud de conexión al usuario [addresseeId].
  ///
  /// Retorna:
  ///   {status: 'pending', connection_id, message: 'pending_sent'}
  ///   {status: <existing>, connection_id, message: 'already_exists'}
  ///   {error: 'self_connect' | 'not_authenticated'}
  Future<Map<String, dynamic>> sendConnectionRequest(String addresseeId) async {
    try {
      final result = await _db.rpc(
        'send_connection_request',
        params: {'p_addressee_id': addresseeId},
      );
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Acepta o rechaza una solicitud de conexión pendiente.
  ///
  /// [action] debe ser 'accept' o 'reject'.
  /// Retorna: {status: 'accepted'|'rejected', message: 'ok'} | {error}
  Future<Map<String, dynamic>> respondConnection(
    String requesterId,
    String action, // 'accept' | 'reject'
  ) async {
    try {
      final result = await _db.rpc(
        'respond_connection',
        params: {'p_requester_id': requesterId, 'p_action': action},
      );
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Consulta el estado de conexión entre el usuario actual y [otherUserId].
  ///
  /// Retorna:
  ///   {status: 'none'|'pending'|'accepted'|'rejected'|'blocked',
  ///    connection_id, i_am_requester: bool}
  Future<Map<String, dynamic>> getConnectionStatus(String otherUserId) async {
    try {
      final result = await _db.rpc(
        'get_connection_status',
        params: {'p_other_user_id': otherUserId},
      );
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      return {'status': 'none'};
    }
  }

  // ── Pitch Likes ──────────────────────────────────────────────────────────

  /// Toggle del like sobre el Video-Pitch de [pitchOwnerId].
  ///
  /// Idempotente: si ya hay like, lo quita; si no, lo añade.
  /// Retorna: {liked: bool, like_count: int} | {error}
  Future<({bool liked, int likeCount})?> togglePitchLike(
    String pitchOwnerId,
  ) async {
    try {
      final result = await _db.rpc(
        'toggle_pitch_like',
        params: {'p_pitch_owner_id': pitchOwnerId},
      );
      final map = Map<String, dynamic>.from(result as Map);
      return (
        liked:     map['liked'] as bool? ?? false,
        likeCount: map['like_count'] as int? ?? 0,
      );
    } catch (e) {
      debugPrint('❌ SocialService.togglePitchLike: $e');
      return null; // Return null so caller keeps optimistic state
    }
  }

  // ── Ratings ──────────────────────────────────────────────────────────────

  /// Califica el perfil de [targetId] con [stars] estrellas (1.0 – 5.0).
  ///
  /// El backend recalcula el promedio y actualiza users.rating_stars.
  /// Retorna: {new_avg: float, total_ratings: int} | {error}
  Future<Map<String, dynamic>> rateUser(String targetId, double stars) async {
    try {
      final result = await _db.rpc(
        'rate_user',
        params: {'p_target_id': targetId, 'p_stars': stars},
      );
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Stream de solicitudes de conexión pendientes para el usuario actual.
  /// Útil para el badge de notificaciones.
  Stream<List<Map<String, dynamic>>> get pendingRequestsStream {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return const Stream.empty();
    // SupabaseStreamBuilder solo admite un .eq(); filtramos 'pending' en Dart.
    return _db
        .from('connections')
        .stream(primaryKey: ['id'])
        .eq('addressee_id', uid)
        .map((rows) => rows.where((r) => r['status'] == 'pending').toList());
  }

  // ── Conexiones Mutuas (RPC server-side, 1 query) ───────────────────

  /// Obtiene la cantidad de conexiones en común con [otherUserId].
  /// Usa un RPC en Supabase para hacerlo en 1 sola query server-side.
  Future<int> getMutualCount(String otherUserId) async {
    try {
      final result = await _db.rpc(
        'get_mutual_connections_count',
        params: {'p_other_user_id': otherUserId},
      );
      return result as int? ?? 0;
    } catch (e) {
      debugPrint('❌ getMutualCount: $e');
      return 0;
    }
  }

  // ── Recomendaciones IA (server-side ranking) ──────────────────────

  /// Obtiene usuarios recomendados con score de afinidad real.
  /// El RPC calcula el score basado en tags, ubicación, video pitch,
  /// rating y boost activo.
  Future<List<Map<String, dynamic>>> getRecommendedUsers({int limit = 30}) async {
    try {
      final result = await _db.rpc(
        'get_recommended_users',
        params: {'p_limit': limit},
      );
      if (result is List) {
        return List<Map<String, dynamic>>.from(
          result.map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }
      return [];
    } catch (e) {
      debugPrint('❌ getRecommendedUsers: $e');
      return [];
    }
  }

  // ── Anti-Ghosting: Match Expiration (7 días) ─────────────────────────────

  /// Ejecuta la expiración de matches pendientes que superaron 7 días.
  /// Llama al RPC `expire_stale_connections`.
  /// Retorna la cantidad de matches expirados.
  Future<int> expireStaleMatches() async {
    try {
      final result = await _db.rpc('expire_stale_connections');
      return result as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Verifica si una conexión pendiente está próxima a expirar.
  /// Retorna los días restantes (null si no aplica).
  int? daysUntilExpiry(Map<String, dynamic> connection) {
    final expiresAt = connection['expires_at'];
    if (expiresAt == null) return null;

    final dt = DateTime.tryParse(expiresAt.toString());
    if (dt == null) return null;

    final diff = dt.difference(DateTime.now()).inDays;
    return diff >= 0 ? diff : 0;
  }
}

