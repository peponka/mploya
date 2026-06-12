import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// StoryService — Gestión de historias efímeras (24h) de Mploya
//
// Lógica:
//  • Las empresas ven historias de candidatos
//  • Los candidatos ven historias de empresas  
//  • Like en historia = "Estoy interesado / Contactame"
//  • Las historias expiran a las 24h automáticamente
// ─────────────────────────────────────────────────────────────────────────────

class StoryService {
  StoryService._();
  static final StoryService instance = StoryService._();

  SupabaseClient get _db => Supabase.instance.client;

  /// Obtiene usuarios con historias activas del tipo opuesto.
  /// Si soy empresa → candidatos con historias.
  /// Si soy candidato → empresas con historias.
  Future<List<StoryUser>> getStoryUsers() async {
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) return [];

      // Obtener mi tipo de cuenta
      final me = await _db.from('users').select('account_type').eq('id', uid).maybeSingle();
      final myType = me?['account_type']?.toString() ?? 'candidato';

      // Tipo opuesto
      final targetType = (myType == 'empresa' || myType == 'headhunter') ? 'candidato' : 'empresa';

      // Historias activas del tipo opuesto, con datos del usuario
      final rows = await _db
          .from('stories')
          .select('*, users!inner(id, name, avatar_url, headline, company, account_type, video_url)')
          .eq('is_active', true)
          .gt('expires_at', DateTime.now().toIso8601String())
          .eq('users.account_type', targetType)
          .order('created_at', ascending: false);

      // También obtener MIS propias historias activas
      final myRows = await _db
          .from('stories')
          .select('*, users!inner(id, name, avatar_url, headline, company, account_type, video_url)')
          .eq('user_id', uid)
          .eq('is_active', true)
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      // Agrupar por usuario (primero las mías)
      final Map<String, StoryUser> grouped = {};

      // Procesar mis historias primero
      for (final row in myRows) {
        final userData = row['users'] as Map<String, dynamic>;
        final userId = userData['id'].toString();

        if (!grouped.containsKey(userId)) {
          grouped[userId] = StoryUser(
            user: NexUser.fromJson(userData),
            stories: [],
            isMe: true,
          );
        }
        grouped[userId]!.stories.add(Story(
          id: row['id'].toString(),
          userId: userId,
          videoUrl: row['video_url'].toString(),
          caption: row['caption']?.toString(),
          createdAt: DateTime.tryParse(row['created_at'].toString()) ?? DateTime.now(),
          expiresAt: DateTime.tryParse(row['expires_at'].toString()) ?? DateTime.now(),
        ));
      }

      // Luego historias del tipo opuesto
      for (final row in rows) {
        final userData = row['users'] as Map<String, dynamic>;
        final userId = userData['id'].toString();

        if (!grouped.containsKey(userId)) {
          grouped[userId] = StoryUser(
            user: NexUser.fromJson(userData),
            stories: [],
          );
        }
        grouped[userId]!.stories.add(Story(
          id: row['id'].toString(),
          userId: userId,
          videoUrl: row['video_url'].toString(),
          caption: row['caption']?.toString(),
          createdAt: DateTime.tryParse(row['created_at'].toString()) ?? DateTime.now(),
          expiresAt: DateTime.tryParse(row['expires_at'].toString()) ?? DateTime.now(),
        ));
      }

      // Poner mis historias primero
      final myStories = grouped.values.where((s) => s.isMe).toList();
      final otherStories = grouped.values.where((s) => !s.isMe).toList();
      return [...myStories, ...otherStories];
    } catch (e) {
      debugPrint('❌ StoryService.getStoryUsers: $e');
      return [];
    }
  }

  /// Publica una nueva historia (video).
  Future<bool> publishStory(String videoUrl, {String? caption}) async {
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) return false;

      await _db.from('stories').insert({
        'user_id': uid,
        'video_url': videoUrl,
        'caption': caption,
      });
      return true;
    } catch (e) {
      debugPrint('❌ StoryService.publishStory: $e');
      return false;
    }
  }

  /// Toggle like en una historia (señal de interés).
  /// Retorna true si quedó likeada, false si se removió.
  Future<bool> toggleStoryLike(String storyId) async {
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) return false;

      // Verificar si ya existe
      final existing = await _db
          .from('story_likes')
          .select('id')
          .eq('story_id', storyId)
          .eq('user_id', uid)
          .maybeSingle();

      if (existing != null) {
        // Quitar like
        await _db.from('story_likes').delete().eq('story_id', storyId).eq('user_id', uid);
        return false;
      } else {
        // Dar like
        await _db.from('story_likes').insert({
          'story_id': storyId,
          'user_id': uid,
        });

        // Enviar notificación al dueño de la historia
        final story = await _db.from('stories').select('user_id').eq('id', storyId).maybeSingle();
        if (story != null) {
          final storyOwnerId = story['user_id'].toString();
          final myData = await _db.from('users').select('name').eq('id', uid).maybeSingle();
          final myName = myData?['name']?.toString() ?? 'Alguien';

          await _db.from('notifications').insert({
            'user_id': storyOwnerId,
            'type': 'story_interest',
            'title': '⚡ Interés en tu historia',
            'body': '$myName está interesado/a — ¡quiere conectar contigo!',
            'data': {'story_id': storyId, 'from_user_id': uid},
          });
        }

        return true;
      }
    } catch (e) {
      debugPrint('❌ StoryService.toggleStoryLike: $e');
      return false;
    }
  }

  /// Verifica si ya le di like a una historia.
  Future<bool> hasLiked(String storyId) async {
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) return false;

      final row = await _db
          .from('story_likes')
          .select('id')
          .eq('story_id', storyId)
          .eq('user_id', uid)
          .maybeSingle();
      return row != null;
    } catch (e) {
      return false;
    }
  }

  /// Cuenta likes de una historia.
  Future<int> getLikeCount(String storyId) async {
    try {
      final rows = await _db
          .from('story_likes')
          .select('id')
          .eq('story_id', storyId);
      return rows.length;
    } catch (e) {
      return 0;
    }
  }

  /// Elimina una historia propia.
  Future<bool> deleteStory(String storyId) async {
    try {
      await _db.from('stories').delete().eq('id', storyId);
      return true;
    } catch (e) {
      return false;
    }
  }
}

// ── Modelos locales ──

class Story {
  final String id;
  final String userId;
  final String videoUrl;
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;

  const Story({
    required this.id,
    required this.userId,
    required this.videoUrl,
    this.caption,
    required this.createdAt,
    required this.expiresAt,
  });
}

class StoryUser {
  final NexUser user;
  final List<Story> stories;
  final bool isMe;

  StoryUser({required this.user, required this.stories, this.isMe = false});
}
