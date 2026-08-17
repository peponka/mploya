import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../services/my_profile_service.dart';
import 'empresa_vacantes_data.dart';

/// Ficha pública de la propia empresa.
@immutable
class PerfilEmpresa {
  final NexUser empresa;

  /// Vacantes propias, con su conteo real de postulaciones.
  final List<Vacante> vacantes;

  /// Postulaciones sumadas de todas las vacantes.
  final int postulaciones;

  /// El conteo de postulaciones no se pudo leer.
  final bool postulacionesNoDisponibles;

  final bool error;

  const PerfilEmpresa({
    required this.empresa,
    this.vacantes = const [],
    this.postulaciones = 0,
    this.postulacionesNoDisponibles = false,
    this.error = false,
  });

  int get vacantesActivas =>
      vacantes.where((v) => v.estado != VacanteEstado.pausada).length;

  /// Etiquetas que la empresa usa en sus vacantes: es lo más cercano a "en qué
  /// trabaja" que se puede afirmar con datos.
  List<String> get sectores {
    final conteo = <String, int>{};
    for (final v in vacantes) {
      for (final t in v.tags) {
        final tag = t.trim();
        if (tag.isEmpty) continue;
        conteo[tag] = (conteo[tag] ?? 0) + 1;
      }
    }
    final ordenadas = conteo.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ordenadas.take(8).map((e) => e.key).toList();
  }

  bool get perfilIncompleto =>
      (empresa.about?.trim().isEmpty ?? true) ||
      empresa.headline.trim().isEmpty;
}

/// Carga la ficha de la empresa autenticada junto con sus vacantes.
Future<PerfilEmpresa?> loadPerfilEmpresa() async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return null;

  Map<String, dynamic>? fila;
  try {
    fila = await loadMyProfile(client: client);
  } catch (e) {
    debugPrint('perfil empresa · users: $e');
    return null;
  }
  if (fila == null) return null;

  // Reutiliza el mismo cargador que la pantalla de Vacantes, para que el perfil
  // y la lista nunca discrepen sobre cuántas vacantes hay.
  final vacantes = await loadEmpresaVacantes();

  return PerfilEmpresa(
    empresa: NexUser.fromJson(fila),
    vacantes: vacantes.vacantes,
    postulaciones: vacantes.candidatos,
    postulacionesNoDisponibles: vacantes.conteoNoDisponible,
  );
}
