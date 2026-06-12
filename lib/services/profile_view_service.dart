import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_analytics_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProfileViewService — Registra y consulta vistas de perfil
//
// Tabla requerida en Supabase:
//   CREATE TABLE IF NOT EXISTS profile_views (
//     id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
//     viewer_id uuid REFERENCES auth.users(id),
//     viewed_id uuid REFERENCES auth.users(id) NOT NULL,
//     created_at timestamptz DEFAULT now()
//   );
//   CREATE INDEX IF NOT EXISTS idx_pv_viewed ON profile_views(viewed_id);
//   -- Política RLS: usuarios autenticados pueden INSERT y SELECT
// ─────────────────────────────────────────────────────────────────────────────

class ProfileViewService {
  ProfileViewService._();
  static final ProfileViewService instance = ProfileViewService._();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _uid => _client.auth.currentUser?.id;

  /// Registra una vista de perfil. No registra self-views.
  Future<void> recordView(String viewedUserId) async {
    if (_uid == null || _uid == viewedUserId) return;
    try {
      await _client.from('profile_views').insert({
        'viewer_id': _uid,
        'viewed_id': viewedUserId,
      });
      // Also track in analytics
      ProfileAnalyticsService.instance.increment('views');
    } catch (e) {
      debugPrint('ProfileViewService.recordView error: $e');
    }
  }

  /// Retorna la lista de usuarios que vieron mi perfil (últimos 50).
  Future<List<Map<String, dynamic>>> getMyViewers() async {
    if (_uid == null) return [];
    try {
      final rows = await _client
          .from('profile_views')
          .select('viewer_id, created_at')
          .eq('viewed_id', _uid!)
          .order('created_at', ascending: false)
          .limit(50);

      // Obtener info de cada viewer
      final viewerIds = rows.map((r) => r['viewer_id'].toString()).toSet().toList();
      if (viewerIds.isEmpty) return [];

      final users = await _client
          .from('users')
          .select('id, name, headline, avatar_url, account_type')
          .inFilter('id', viewerIds);

      // Unir datos
      final usersMap = <String, Map<String, dynamic>>{};
      for (final u in users) {
        usersMap[u['id'].toString()] = u;
      }

      return rows.map((r) {
        final viewerId = r['viewer_id'].toString();
        final userData = usersMap[viewerId] ?? {};
        return {
          ...userData,
          'viewed_at': r['created_at'],
        };
      }).toList();
    } catch (e) {
      debugPrint('ProfileViewService.getMyViewers error: $e');
      return [];
    }
  }

  /// Cuenta total de vistas a mi perfil
  Future<int> getMyViewCount() async {
    if (_uid == null) return 0;
    try {
      final res = await _client
          .from('profile_views')
          .select('id')
          .eq('viewed_id', _uid!);
      return (res as List).length;
    } catch (e) {
      return 0;
    }
  }
}
