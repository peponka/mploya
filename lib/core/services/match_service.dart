/// Servicio singleton para gestionar matches/conexiones en Supabase.
///
/// Operaciones CRUD de matches, streams en tiempo real,
/// y acciones de aceptar/rechazar/conectar.
/// Usa patrón singleton igual que [MessagingService].
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mploya/core/models/match_model.dart';

/// Servicio centralizado de matches.
///
/// ```dart
/// final matches = await MatchService.instance.getMatches(userId);
/// ```
class MatchService {
  MatchService._();
  static final MatchService instance = MatchService._();

  SupabaseClient get _client => Supabase.instance.client;

  // ─── Tabla y columnas ─────────────────────────────────────────────

  static const _matchesTable = 'matches';
  static const _connectionsTable = 'connections';

  /// Select con join a profiles para enriquecer datos del target.
  ///
  /// Trae nombre, avatar, headline, ubicación, verificación y skills
  /// del usuario objetivo del match.
  static const _matchWithProfileSelect = '''
    *,
    target:target_user_id (
      full_name,
      avatar_url,
      headline,
      location,
      is_verified,
      skills
    )
  ''';

  // ─── Obtener matches ─────────────────────────────────────────────

  /// Obtiene todos los matches de un usuario.
  ///
  /// Retorna los matches ordenados por fecha, con datos del perfil
  /// del target resueltos desde `profiles`.
  Future<List<MatchModel>> getMatches(String userId) async {
    try {
      final response = await _client
          .from(_matchesTable)
          .select(_matchWithProfileSelect)
          .or('user_id.eq.$userId,target_user_id.eq.$userId')
          .order('created_at', ascending: false);
      final data = (response is List) ? response : <dynamic>[];

      return data
          .cast<Map<String, dynamic>>()
          .map((json) => _mapMatchWithProfile(json, userId))
          .toList();
    } catch (e, st) {
      debugPrint('Error obteniendo matches: $e\n$st');
      return [];
    }
  }

  /// Stream en tiempo real de los matches del usuario.
  ///
  /// Escucha cambios en la tabla `matches` y emite la lista
  /// actualizada cada vez que se inserta, actualiza o elimina.
  Stream<List<MatchModel>> matchesStream(String userId) {
    final controller = StreamController<List<MatchModel>>.broadcast();

    // Carga inicial
    getMatches(userId).then((matches) {
      if (!controller.isClosed) {
        controller.add(matches);
      }
    });

    // Suscripción a cambios en tiempo real
    final channel = _client
        .channel('matches:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _matchesTable,
          callback: (payload) {
            // Re-fetch completa para mantener datos consistentes
            // con los joins de perfil.
            getMatches(userId).then((matches) {
              if (!controller.isClosed) {
                controller.add(matches);
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

  // ─── Crear match ─────────────────────────────────────────────────

  /// Crea un nuevo match entre dos usuarios.
  ///
  /// El match se crea con status `pending` por defecto.
  /// [type] indica si es un match de candidato o empresa.
  Future<MatchModel?> createMatch({
    required String userId,
    required String targetUserId,
    MatchType type = MatchType.candidate,
    int matchPercentage = 0,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      final data = await _client
          .from(_matchesTable)
          .insert({
            'user_id': userId,
            'target_user_id': targetUserId,
            'status': MatchStatus.pending.value,
            'type': type.value,
            'match_percentage': matchPercentage,
            'created_at': now,
            'updated_at': now,
          })
          .select(_matchWithProfileSelect)
          .single();

      debugPrint('✅ Match creado: ${data['id']}');
      return _mapMatchWithProfile(data, userId);
    } catch (e, st) {
      debugPrint('Error creando match: $e\n$st');
      return null;
    }
  }

  // ─── Acciones sobre matches ──────────────────────────────────────

  /// Acepta un match pendiente, cambiando su status a `active`.
  Future<void> acceptMatch(String matchId) async {
    try {
      await _client
          .from(_matchesTable)
          .update({'status': MatchStatus.active.value})
          .eq('id', matchId);

      debugPrint('✅ Match $matchId aceptado.');
    } catch (e, st) {
      debugPrint('Error aceptando match $matchId: $e\n$st');
      rethrow;
    }
  }

  /// Rechaza un match, cambiando su status a `rejected`.
  Future<void> rejectMatch(String matchId) async {
    try {
      await _client
          .from(_matchesTable)
          .update({'status': MatchStatus.rejected.value})
          .eq('id', matchId);

      debugPrint('❌ Match $matchId rechazado.');
    } catch (e, st) {
      debugPrint('Error rechazando match $matchId: $e\n$st');
      rethrow;
    }
  }

  /// Conecta con un match, cambiando su status a `connected`
  /// y creando un registro en la tabla `connections`.
  Future<void> connectWith(String matchId) async {
    try {
      // Obtener datos del match para saber los participantes
      final matchData = await _client
          .from(_matchesTable)
          .select('user_id, target_user_id')
          .eq('id', matchId)
          .single();

      final userId = matchData['user_id'] as String;
      final targetUserId = matchData['target_user_id'] as String;

      // Actualizar status del match
      await _client
          .from(_matchesTable)
          .update({'status': MatchStatus.connected.value})
          .eq('id', matchId);

      // Crear la conexión bidireccional
      final now = DateTime.now().toIso8601String();
      await _client.from(_connectionsTable).upsert(
        {
          'user_id': userId,
          'connected_user_id': targetUserId,
          'status': 'active',
          'connected_at': now,
        },
        onConflict: 'user_id,connected_user_id',
      );

      debugPrint('🤝 Match $matchId conectado.');
    } catch (e, st) {
      debugPrint('Error conectando match $matchId: $e\n$st');
      rethrow;
    }
  }

  // ─── Conteos ─────────────────────────────────────────────────────

  /// Obtiene la cantidad de matches de un usuario (todos los status).
  Future<int> getMatchCount(String userId) async {
    try {
      final response = await _client
          .from(_matchesTable)
          .select('id')
          .or('user_id.eq.$userId,target_user_id.eq.$userId')
          .neq('status', 'rejected');
      final data = (response is List) ? response : <dynamic>[];
      return data.length;
    } catch (e, st) {
      debugPrint('Error contando matches del usuario $userId: $e\n$st');
      return 0;
    }
  }

  /// Obtiene la cantidad de conexiones confirmadas de un usuario.
  Future<int> getConnectionCount(String userId) async {
    try {
      final response = await _client
          .from(_connectionsTable)
          .select('id')
          .or('user_id.eq.$userId,connected_user_id.eq.$userId')
          .eq('status', 'active');
      final data = (response is List) ? response : <dynamic>[];
      return data.length;
    } catch (e, st) {
      debugPrint('Error contando conexiones del usuario $userId: $e\n$st');
      return 0;
    }
  }

  // ─── Helpers privados ────────────────────────────────────────────

  /// Mapea un resultado con join de profiles a un [MatchModel].
  ///
  /// Extrae datos del perfil del target y los inyecta como
  /// campos UI-only del modelo.
  MatchModel _mapMatchWithProfile(
    Map<String, dynamic> json,
    String currentUserId,
  ) {
    final target = json['target'];
    final base = MatchModel.fromJson(json);

    if (target is Map<String, dynamic>) {
      // Convertir skills (text[]) a hashtags para display
      final skills = (target['skills'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [];

      return base.copyWith(
        targetUserName: target['full_name'] as String?,
        targetUserAvatarUrl: target['avatar_url'] as String?,
        targetUserHeadline: target['headline'] as String?,
        targetUserLocation: target['location'] as String?,
        targetUserIsVerified: target['is_verified'] as bool? ?? false,
        targetUserHashtags: skills,
      );
    }

    return base;
  }
}
