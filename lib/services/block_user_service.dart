import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BlockUserService — Gestión de bloqueos entre usuarios
//
// Provee:
//  • blockUser()       — Bloquea usuario (elimina conexión + mensajes)
//  • unblockUser()     — Desbloquea usuario
//  • isBlocked()       — Verifica si un usuario está bloqueado
//  • getBlockedUsers() — Lista de usuarios bloqueados
//
// El bloqueo se ejecuta server-side vía RPC SECURITY DEFINER para
// garantizar la integridad de la operación (atomicidad).
// ─────────────────────────────────────────────────────────────────────────────

class BlockUserService {
  BlockUserService._();
  static final BlockUserService instance = BlockUserService._();

  SupabaseClient get _db => Supabase.instance.client;

  /// Cache local de IDs bloqueados para filtrado rápido en el feed.
  final Set<String> _blockedIds = {};
  bool _loaded = false;

  /// IDs de usuarios que bloqueé (para filtrar del feed sin query).
  Set<String> get blockedIds => Set.unmodifiable(_blockedIds);

  /// Carga la lista de bloqueados desde Supabase (llamar una vez al login).
  Future<void> loadBlockedUsers() async {
    if (_loaded) return;
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) return;

      final rows = await _db
          .from('blocked_users')
          .select('blocked_id')
          .eq('blocker_id', uid);

      _blockedIds.clear();
      for (final row in rows) {
        _blockedIds.add(row['blocked_id'].toString());
      }
      _loaded = true;
    } catch (e) {
      debugPrint('⚠️ BlockUserService.loadBlockedUsers: $e');
    }
  }

  /// Bloquea un usuario. Elimina conexión y mensajes server-side.
  ///
  /// Retorna null en éxito, o un String de error.
  Future<String?> blockUser(String blockedId, {String? reason}) async {
    try {
      final result = await _db.rpc('block_user', params: {
        'p_blocked_id': blockedId,
        if (reason != null) 'p_reason': reason,
      });

      final map = Map<String, dynamic>.from(result as Map);
      if (map.containsKey('error')) {
        return map['error'].toString();
      }

      _blockedIds.add(blockedId);
      return null;
    } catch (e) {
      debugPrint('❌ BlockUserService.blockUser: $e');
      return 'Error al bloquear usuario: $e';
    }
  }

  /// Desbloquea un usuario.
  Future<String?> unblockUser(String blockedId) async {
    try {
      await _db.rpc('unblock_user', params: {
        'p_blocked_id': blockedId,
      });

      _blockedIds.remove(blockedId);
      return null;
    } catch (e) {
      return 'Error al desbloquear: $e';
    }
  }

  /// Verifica si un usuario está bloqueado (local, sin query).
  bool isBlocked(String userId) => _blockedIds.contains(userId);

  /// Obtiene la lista completa de usuarios bloqueados con datos.
  Future<List<Map<String, dynamic>>> getBlockedUsersWithDetails() async {
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) return [];

      final rows = await _db
          .from('blocked_users')
          .select('*, users!blocked_users_blocked_id_fkey(id, name, avatar_url, headline)')
          .eq('blocker_id', uid)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      debugPrint('❌ BlockUserService.getBlockedUsersWithDetails: $e');
      return [];
    }
  }

  /// Reset al hacer logout
  void clear() {
    _blockedIds.clear();
    _loaded = false;
  }
}
