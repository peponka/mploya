import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

/// Provider que expone la sesión activa de Supabase en tiempo real.
final authSessionProvider = StreamProvider<Session?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map((data) => data.session);
});

/// Provider que vigila la tabla 'users' para obtener los datos del perfil local
/// (como 'account_type' (empresa/candidato), 'name', 'avatarUrl', etc)
/// en tiempo real, globalmente en toda la app.
///
/// ⚠️ IMPORTANTE: Para que las actualizaciones en tiempo real funcionen,
/// la tabla `users` debe tener Realtime habilitado en el Supabase Dashboard:
///   Database → Replication → supabase_realtime → Habilitar tabla `users`
/// Si no está habilitado, el stream solo dará el valor inicial (funciona como query).
final currentUserProvider = StreamProvider<NexUser?>((ref) {
  final session = ref.watch(authSessionProvider).value;
  if (session == null) {
    return Stream.value(null);
  }
  return Supabase.instance.client
      .from('users')
      .stream(primaryKey: ['id'])
      .eq('id', session.user.id)
      .map((rows) {
        if (rows.isEmpty) return null;
        return NexUser.fromJson(rows.first);
      })
      .handleError((e) {
        // Si Realtime no está habilitado, el stream puede fallar silenciosamente.
        // Esto evita que la app crashee y logea el error para debugging.
        debugPrint('⚠️ currentUserProvider stream error: $e');
      });
});

/// Provider para forzar un refresh manual del perfil del usuario actual.
/// Útil cuando Realtime no está habilitado y necesitamos refrescar tras editar perfil.
final manualUserRefreshProvider = FutureProvider<NexUser?>((ref) async {
  final session = ref.watch(authSessionProvider).value;
  if (session == null) return null;
  try {
    final row = await Supabase.instance.client
        .from('users')
        .select()
        .eq('id', session.user.id)
        .maybeSingle();
    if (row == null) return null;
    return NexUser.fromJson(row);
  } catch (e) {
    return null;
  }
});
