import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/my_profile_service.dart';

/// Provider que expone la sesión activa de Supabase en tiempo real.
final authSessionProvider = StreamProvider<Session?>((ref) async* {
  final auth = Supabase.instance.client.auth;
  yield auth.currentSession;
  await for (final data in auth.onAuthStateChange) {
    yield data.session;
  }
});

/// Perfil propio global. La fila se lee siempre por `get_my_profile()`.
/// Se refresca por la misma RPC privada; nunca se suscribe a `public.users`.
final currentUserProvider = StreamProvider<NexUser?>((ref) async* {
  final session = ref.watch(authSessionProvider).value;
  if (session == null) {
    yield null;
    return;
  }

  final client = Supabase.instance.client;
  Future<NexUser?> readProfile() async {
    final row = await loadMyProfile(client: client)
        .timeout(const Duration(seconds: 8));
    return row == null ? null : NexUser.fromJson(row);
  }

  while (true) {
    try {
      yield await readProfile();
    } catch (e) {
      debugPrint('currentUserProvider get_my_profile error: $e');
      yield null;
    }
    await Future<void>.delayed(const Duration(seconds: 30));
  }
});

/// Provider para forzar un refresh manual del perfil del usuario actual.
/// Útil cuando Realtime no está habilitado y necesitamos refrescar tras editar perfil.
final manualUserRefreshProvider = FutureProvider<NexUser?>((ref) async {
  final session =
      ref.watch(authSessionProvider).value ??
      Supabase.instance.client.auth.currentSession;
  if (session == null) return null;
  try {
    final row = await loadMyProfile().timeout(const Duration(seconds: 8));
    if (row == null) return null;
    return NexUser.fromJson(row);
  } catch (e) {
    return null;
  }
});
