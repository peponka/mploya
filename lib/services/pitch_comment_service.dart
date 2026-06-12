import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PitchCommentService — Comentarios en Video-Pitches
//
// Tabla requerida en Supabase:
//   CREATE TABLE IF NOT EXISTS pitch_comments (
//     id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
//     author_id uuid REFERENCES auth.users(id) NOT NULL,
//     target_user_id uuid NOT NULL,
//     text text NOT NULL,
//     created_at timestamptz DEFAULT now()
//   );
//   CREATE INDEX IF NOT EXISTS idx_pc_target ON pitch_comments(target_user_id);
// ─────────────────────────────────────────────────────────────────────────────

class PitchCommentService {
  PitchCommentService._();
  static final PitchCommentService instance = PitchCommentService._();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  /// Agrega un comentario al pitch de un usuario
  Future<bool> addComment(String targetUserId, String text) async {
    if (_uid == null || text.trim().isEmpty) return false;
    try {
      await _client.from('pitch_comments').insert({
        'author_id': _uid,
        'target_user_id': targetUserId,
        'text': text.trim(),
      });
      return true;
    } catch (e) {
      debugPrint('PitchCommentService.addComment error: $e');
      return false;
    }
  }

  /// Obtiene los comentarios de un pitch (con datos del autor)
  Future<List<Map<String, dynamic>>> getComments(String targetUserId) async {
    try {
      final rows = await _client
          .from('pitch_comments')
          .select('id, author_id, text, created_at')
          .eq('target_user_id', targetUserId)
          .order('created_at', ascending: false)
          .limit(100);

      if (rows.isEmpty) return [];

      // Obtener info de autores
      final authorIds = rows.map((r) => r['author_id'].toString()).toSet().toList();
      final users = await _client
          .from('users')
          .select('id, name, headline, avatar_url')
          .inFilter('id', authorIds);

      final usersMap = <String, Map<String, dynamic>>{};
      for (final u in users) {
        usersMap[u['id'].toString()] = u;
      }

      return rows.map((r) {
        final authorId = r['author_id'].toString();
        final author = usersMap[authorId] ?? {};
        return {
          'id': r['id'],
          'text': r['text'],
          'created_at': r['created_at'],
          'author_name': author['name'] ?? 'Usuario',
          'author_avatar': author['avatar_url'],
          'author_headline': author['headline'] ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('PitchCommentService.getComments error: $e');
      return [];
    }
  }

  /// Cuenta comentarios de un pitch
  Future<int> getCommentCount(String targetUserId) async {
    try {
      final res = await _client
          .from('pitch_comments')
          .select('id')
          .eq('target_user_id', targetUserId);
      return (res as List).length;
    } catch (e) {
      return 0;
    }
  }
}
