import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../utils/user_columns.dart';

/// Perfil de un candidato visto por una EMPRESA.
///
/// Todo sale de `public.users` (por la lista blanca [kUserColumns], no por `*`)
/// más dos datos propios de la relación empresa↔candidato: si está guardado y
/// cuánto matchea.
@immutable
class CandidatoPerfil {
  final NexUser usuario;

  /// Está en `saved_profiles` de esta empresa.
  final bool guardado;

  /// Match 0–100. `null` cuando no hay match calculado — nunca 0 por defecto,
  /// porque 0 y "no calculado" no son lo mismo.
  final int? match;

  /// De qué vacante es ese match, si vino de una shortlist.
  final String? vacanteTitulo;

  final bool error;

  const CandidatoPerfil({
    required this.usuario,
    this.guardado = false,
    this.match,
    this.vacanteTitulo,
    this.error = false,
  });

  bool get confidencial {
    final tipo = usuario.accountType.toLowerCase();
    return tipo.startsWith('confidenc') || tipo == 'stealth';
  }

  String get nombreVisible =>
      confidencial ? 'Candidato confidencial' : usuario.name;
}

/// Carga el perfil completo de un candidato.
///
/// [matchPrecalculado] lo pasa la Shortlist, que ya tiene el score de esa
/// vacante: pedirlo de nuevo daría OTRO número (el match genérico entre
/// usuarios, que no es el mismo cálculo) y confundiría.
Future<CandidatoPerfil?> loadCandidatoPerfil(
  String candidatoId, {
  int? matchPrecalculado,
  String? vacanteTitulo,
}) async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return null;

  Map<String, dynamic>? fila;
  try {
    fila = await client
        .from('users')
        .select(kUserColumns)
        .eq('id', candidatoId)
        .maybeSingle();
  } catch (e) {
    debugPrint('candidato perfil · users: $e');
    return null;
  }
  if (fila == null) return null;

  var guardado = false;
  try {
    final filas = await client
        .from('saved_profiles')
        .select('saved_user_id')
        .eq('user_id', uid)
        .eq('saved_user_id', candidatoId);
    guardado = (filas as List).isNotEmpty;
  } catch (e) {
    debugPrint('candidato perfil · saved_profiles: $e');
  }

  return CandidatoPerfil(
    usuario: NexUser.fromJson(fila),
    guardado: guardado,
    match: matchPrecalculado,
    vacanteTitulo: vacanteTitulo,
  );
}

/// Guarda o desguarda un candidato. Devuelve el estado resultante, o `null` si
/// la base rechazó el cambio (la UI entonces no miente con un corazón lleno).
Future<bool?> toggleCandidatoGuardado(String candidatoId, bool guardar) async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return null;

  try {
    if (guardar) {
      await client.from('saved_profiles').insert({
        'user_id': uid,
        'saved_user_id': candidatoId,
      });
    } else {
      await client
          .from('saved_profiles')
          .delete()
          .eq('user_id', uid)
          .eq('saved_user_id', candidatoId);
    }
    return guardar;
  } catch (e) {
    debugPrint('candidato perfil · toggle guardado: $e');
    return null;
  }
}
