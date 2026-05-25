/// Servicio singleton para gestionar videos en Supabase.
///
/// Operaciones CRUD de videos, likes, conteo de vistas,
/// y consultas con join a perfiles para el feed.
/// Usa patrón singleton igual que [MessagingService].
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mploya/core/models/video_model.dart';

/// Servicio centralizado de videos.
///
/// ```dart
/// final videos = await VideoService.instance.getFeedVideos();
/// ```
class VideoService {
  VideoService._();
  static final VideoService instance = VideoService._();

  SupabaseClient get _client => Supabase.instance.client;

  // ─── Tabla y columnas ─────────────────────────────────────────────

  static const _videosTable = 'videos';
  static const _videoLikesTable = 'video_likes';

  /// Select con join a profiles para enriquecer datos del feed.
  ///
  /// Trae nombre, avatar y headline del dueño del video.
  static const _videoWithProfileSelect = '''
    *,
    profile:user_id (
      full_name,
      avatar_url,
      headline
    )
  ''';

  // ─── Feed de videos ──────────────────────────────────────────────

  /// Obtiene videos para el feed con paginación.
  ///
  /// Retorna videos tipo pitch ordenados por fecha,
  /// con datos del perfil del creador resueltos desde `profiles`.
  /// [currentUserId] se usa para resolver si el video está likeado.
  Future<List<VideoModel>> getFeedVideos({
    int limit = 20,
    int offset = 0,
    String? currentUserId,
  }) async {
    try {
      final response = await _client
          .from(_videosTable)
          .select(_videoWithProfileSelect)
          .eq('type', 'pitch')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      final data = (response is List) ? response : <dynamic>[];

      final videos = data
          .cast<Map<String, dynamic>>()
          .map((json) => _mapVideoWithProfile(json))
          .toList();

      // Resolver likes del usuario actual si se proporcionó
      if (currentUserId != null && videos.isNotEmpty) {
        return _resolveUserLikes(videos, currentUserId);
      }

      return videos;
    } catch (e, st) {
      debugPrint('Error obteniendo feed de videos: $e\n$st');
      return [];
    }
  }

  /// Obtiene los videos de un usuario específico.
  ///
  /// Útil para la sección de portfolio del perfil.
  Future<List<VideoModel>> getVideosByUser(
    String userId, {
    VideoType? type,
  }) async {
    try {
      var query = _client
          .from(_videosTable)
          .select()
          .eq('user_id', userId);

      if (type != null) {
        query = query.eq('type', type.value);
      }

      final response = await query
          .order('created_at', ascending: false);
      final data = (response is List) ? response : <dynamic>[];

      return data
          .cast<Map<String, dynamic>>()
          .map((json) => VideoModel.fromJson(json))
          .toList();
    } catch (e, st) {
      debugPrint('Error obteniendo videos del usuario $userId: $e\n$st');
      return [];
    }
  }

  // ─── Subida de videos ────────────────────────────────────────────

  /// Crea un registro de video en la base de datos.
  ///
  /// La subida del archivo al storage se hace previamente con
  /// [StorageService]. Este método solo crea el registro en la tabla.
  Future<VideoModel?> uploadVideo({
    required String userId,
    required String url,
    String? thumbnailUrl,
    required int duration,
    VideoType type = VideoType.pitch,
    String? title,
    String? description,
    List<String> hashtags = const [],
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      final data = await _client
          .from(_videosTable)
          .insert({
            'user_id': userId,
            'url': url,
            'thumbnail_url': thumbnailUrl,
            'duration': duration,
            'type': type.value,
            'title': title,
            'description': description,
            'hashtags': hashtags,
            'score': 0,
            'view_count': 0,
            'like_count': 0,
            'created_at': now,
            'updated_at': now,
          })
          .select()
          .single();

      debugPrint('✅ Video creado: ${data['id']}');
      return VideoModel.fromJson(data);
    } catch (e, st) {
      debugPrint('Error creando video: $e\n$st');
      return null;
    }
  }

  // ─── Likes ───────────────────────────────────────────────────────

  /// Da like a un video.
  ///
  /// Inserta un registro en `video_likes` e incrementa `like_count`
  /// en la tabla `videos`. Ignora errores de duplicado (idempotente).
  Future<void> likeVideo(String videoId, String userId) async {
    try {
      // Insertar el like (ignora si ya existe por UNIQUE constraint)
      await _client.from(_videoLikesTable).upsert(
        {
          'user_id': userId,
          'video_id': videoId,
          'created_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,video_id',
      );

      // Recalcular like_count desde la tabla de likes
      await _syncLikeCount(videoId);

      debugPrint('👍 Like dado al video $videoId');
    } catch (e, st) {
      debugPrint('Error dando like al video $videoId: $e\n$st');
      rethrow;
    }
  }

  /// Quita el like de un video.
  ///
  /// Elimina el registro de `video_likes` y decrementa `like_count`.
  Future<void> unlikeVideo(String videoId, String userId) async {
    try {
      await _client
          .from(_videoLikesTable)
          .delete()
          .eq('user_id', userId)
          .eq('video_id', videoId);

      // Recalcular like_count desde la tabla de likes
      await _syncLikeCount(videoId);

      debugPrint('👎 Like removido del video $videoId');
    } catch (e, st) {
      debugPrint('Error removiendo like del video $videoId: $e\n$st');
      rethrow;
    }
  }

  // ─── Vistas ──────────────────────────────────────────────────────

  /// Incrementa el conteo de vistas de un video.
  ///
  /// Usa una función RPC de Supabase para el incremento atómico.
  Future<void> incrementViewCount(String videoId) async {
    try {
      await _client.rpc('increment_view_count', params: {
        'p_video_id': videoId,
      });
    } catch (e, st) {
      debugPrint('Error incrementando vistas del video $videoId: $e\n$st');
    }
  }

  // ─── Eliminación ─────────────────────────────────────────────────

  /// Elimina un video y sus likes asociados.
  ///
  /// Los likes se eliminan en cascada por la FK. El archivo en
  /// Storage debe eliminarse por separado con [StorageService].
  Future<void> deleteVideo(String videoId) async {
    try {
      await _client
          .from(_videosTable)
          .delete()
          .eq('id', videoId);

      debugPrint('🗑️ Video $videoId eliminado.');
    } catch (e, st) {
      debugPrint('Error eliminando video $videoId: $e\n$st');
      rethrow;
    }
  }

  // ─── Conteos ─────────────────────────────────────────────────────

  /// Obtiene la cantidad total de videos de un usuario.
  Future<int> getVideoCountByUser(String userId) async {
    try {
      final response = await _client
          .from(_videosTable)
          .select('id')
          .eq('user_id', userId);
      final data = (response is List) ? response : <dynamic>[];
      return data.length;
    } catch (e, st) {
      debugPrint('Error contando videos del usuario $userId: $e\n$st');
      return 0;
    }
  }

  /// Obtiene la suma total de vistas de todos los videos de un usuario.
  Future<int> getTotalViewsByUser(String userId) async {
    try {
      final response = await _client
          .from(_videosTable)
          .select('view_count')
          .eq('user_id', userId);
      final data = (response is List) ? response : <dynamic>[];

      int total = 0;
      for (final row in data.cast<Map<String, dynamic>>()) {
        total += (row['view_count'] as int? ?? 0);
      }
      return total;
    } catch (e, st) {
      debugPrint('Error sumando vistas del usuario $userId: $e\n$st');
      return 0;
    }
  }

  // ─── Helpers privados ────────────────────────────────────────────

  /// Mapea un resultado con join de profiles a un [VideoModel].
  ///
  /// Extrae `full_name`, `avatar_url` y `headline` del objeto
  /// anidado `profile` y los inyecta como campos UI-only.
  VideoModel _mapVideoWithProfile(Map<String, dynamic> json) {
    final profile = json['profile'];
    final base = VideoModel.fromJson(json);

    if (profile is Map<String, dynamic>) {
      return base.copyWith(
        userName: profile['full_name'] as String?,
        userAvatarUrl: profile['avatar_url'] as String?,
        userHeadline: profile['headline'] as String?,
      );
    }

    return base;
  }

  /// Resuelve los likes del usuario actual para una lista de videos.
  ///
  /// Consulta `video_likes` para los IDs de videos y marca `isLiked`
  /// en cada video correspondiente.
  Future<List<VideoModel>> _resolveUserLikes(
    List<VideoModel> videos,
    String userId,
  ) async {
    try {
      final videoIds = videos.map((v) => v.id).toList();
      final likesResponse = await _client
          .from(_videoLikesTable)
          .select('video_id')
          .eq('user_id', userId)
          .inFilter('video_id', videoIds);
      final likes = (likesResponse is List) ? likesResponse : <dynamic>[];

      final likedIds = likes
          .cast<Map<String, dynamic>>()
          .map((l) => l['video_id'] as String)
          .toSet();

      return videos
          .map((v) => v.copyWith(isLiked: likedIds.contains(v.id)))
          .toList();
    } catch (e, st) {
      debugPrint('Error resolviendo likes del usuario: $e\n$st');
      return videos;
    }
  }

  /// Sincroniza el `like_count` de un video con la tabla `video_likes`.
  Future<void> _syncLikeCount(String videoId) async {
    try {
      final response = await _client
          .from(_videoLikesTable)
          .select('id')
          .eq('video_id', videoId);
      final data = (response is List) ? response : <dynamic>[];

      await _client
          .from(_videosTable)
          .update({'like_count': data.length})
          .eq('id', videoId);
    } catch (e, st) {
      debugPrint('Error sincronizando like_count: $e\n$st');
    }
  }
}
