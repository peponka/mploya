import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../utils/user_columns.dart';

/// Un candidato guardado por la empresa (`public.saved_profiles`).
@immutable
class CandidatoGuardado {
  final NexUser usuario;

  /// Cuándo lo guardó la empresa.
  final DateTime? guardadoEl;

  const CandidatoGuardado({required this.usuario, this.guardadoEl});

  bool get confidencial {
    final tipo = usuario.accountType.toLowerCase();
    return tipo.startsWith('confidenc') || tipo == 'stealth';
  }

  String get nombreVisible =>
      confidencial ? 'Candidato confidencial' : usuario.name;

  String? get antiguedad {
    final f = guardadoEl;
    if (f == null) return null;
    final diff = DateTime.now().difference(f);
    if (diff.inDays >= 30) {
      final meses = (diff.inDays / 30).floor();
      return 'Hace $meses ${meses == 1 ? 'mes' : 'meses'}';
    }
    if (diff.inDays >= 1) {
      return 'Hace ${diff.inDays} ${diff.inDays == 1 ? 'día' : 'días'}';
    }
    if (diff.inHours >= 1) return 'Hace ${diff.inHours} h';
    return 'Recién';
  }
}

@immutable
class GuardadosData {
  final List<CandidatoGuardado> candidatos;
  final bool error;

  const GuardadosData({required this.candidatos, this.error = false});

  static const empty = GuardadosData(candidatos: []);

  int get total => candidatos.length;

  /// Guardados en los últimos 7 días. Sale de `saved_profiles.created_at`.
  int get estaSemana {
    final corte = DateTime.now().subtract(const Duration(days: 7));
    return candidatos
        .where((c) => c.guardadoEl != null && c.guardadoEl!.isAfter(corte))
        .length;
  }

  int get verificados =>
      candidatos.where((c) => c.usuario.isVerified).length;

  int get disponibles =>
      candidatos.where((c) => c.usuario.isOpenToWork).length;

  /// Todas las etiquetas presentes, ordenadas por frecuencia. Es lo más
  /// parecido a "colecciones" que se puede armar SIN inventar una tabla.
  List<({String tag, int cantidad})> get agrupacionesPorTag {
    final conteo = <String, int>{};
    for (final c in candidatos) {
      for (final t in c.usuario.tags) {
        final tag = t.replaceAll('#', '').trim();
        if (tag.isEmpty) continue;
        conteo[tag] = (conteo[tag] ?? 0) + 1;
      }
    }
    final lista = conteo.entries
        .map((e) => (tag: e.key, cantidad: e.value))
        .toList()
      ..sort((a, b) => b.cantidad.compareTo(a.cantidad));
    return lista;
  }
}

/// Candidatos guardados por la empresa autenticada.
///
/// `saved_profiles` guarda el vínculo y la fecha; los perfiles se traen aparte
/// con la lista blanca de columnas.
Future<GuardadosData> loadGuardados() async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return GuardadosData.empty;

  List<dynamic> vinculos;
  try {
    vinculos = await client
        .from('saved_profiles')
        .select('saved_user_id, created_at')
        .eq('user_id', uid)
        .order('created_at', ascending: false) as List<dynamic>;
  } catch (e) {
    debugPrint('guardados · saved_profiles: $e');
    return const GuardadosData(candidatos: [], error: true);
  }

  if (vinculos.isEmpty) return GuardadosData.empty;

  final fechaPorId = <String, DateTime?>{};
  for (final v in vinculos) {
    final m = v as Map;
    final id = m['saved_user_id']?.toString();
    if (id == null || id.isEmpty) continue;
    fechaPorId[id] = DateTime.tryParse(m['created_at']?.toString() ?? '');
  }

  List<dynamic> perfiles;
  try {
    perfiles = await client
        .from('accessible_user_profiles')
        .select(kUserColumns)
        .inFilter('id', fechaPorId.keys.toList()) as List<dynamic>;
  } catch (e) {
    debugPrint('guardados · users: $e');
    return const GuardadosData(candidatos: [], error: true);
  }

  final candidatos = <CandidatoGuardado>[];
  for (final p in perfiles) {
    final fila = Map<String, dynamic>.from(p as Map);
    candidatos.add(
      CandidatoGuardado(
        usuario: NexUser.fromJson(fila),
        guardadoEl: fechaPorId[fila['id'].toString()],
      ),
    );
  }

  // El orden de `users` no respeta el de `saved_profiles`: se reordena por
  // fecha de guardado, que es lo que la pantalla promete.
  candidatos.sort((a, b) {
    final fa = a.guardadoEl, fb = b.guardadoEl;
    if (fa == null || fb == null) return 0;
    return fb.compareTo(fa);
  });

  return GuardadosData(candidatos: candidatos);
}

/// Quita un candidato de guardados. `false` si la base rechazó el cambio.
Future<bool> quitarGuardado(String candidatoId) async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return false;

  try {
    await client
        .from('saved_profiles')
        .delete()
        .eq('user_id', uid)
        .eq('saved_user_id', candidatoId);
    return true;
  } catch (e) {
    debugPrint('guardados · quitar: $e');
    return false;
  }
}
