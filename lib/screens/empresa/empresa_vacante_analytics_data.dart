import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Métricas reales de UNA vacante.
///
/// Todo se calcula sobre filas que existen: `job_applications` (postulaciones,
/// con su estado y su fecha) e `interviews` (entrevistas de esa vacante). No hay
/// tracking de impresiones ni de vistas en el proyecto, así que las métricas de
/// alcance del mockup —visualizaciones, fuentes de tráfico, CTR— no se calculan
/// ni se estiman.
@immutable
class VacanteAnalytics {
  /// Postulaciones por estado, tal como lo guarda `job_applications.status`.
  final Map<String, int> porEstado;

  /// Postulaciones por día (clave: fecha sin hora), últimos [dias] días.
  final Map<DateTime, int> porDia;

  /// Ventana usada para la serie temporal.
  final int dias;

  final int entrevistas;

  /// `interviews` no respondió: la tabla puede no existir.
  final bool entrevistasNoDisponibles;

  /// `job_applications` no respondió.
  final bool error;

  const VacanteAnalytics({
    this.porEstado = const {},
    this.porDia = const {},
    this.dias = 14,
    this.entrevistas = 0,
    this.entrevistasNoDisponibles = false,
    this.error = false,
  });

  static const empty = VacanteAnalytics();

  int get postulaciones =>
      porEstado.values.fold<int>(0, (s, v) => s + v);

  bool get sinDatos => postulaciones == 0 && entrevistas == 0;

  /// Serie ordenada de los últimos [dias], rellenando con 0 los días sin
  /// postulaciones: un hueco no es lo mismo que el fin de la serie.
  List<({DateTime dia, int cantidad})> get serie {
    final hoy = DateTime.now();
    final base = DateTime(hoy.year, hoy.month, hoy.day);
    return [
      for (var i = dias - 1; i >= 0; i--)
        (
          dia: base.subtract(Duration(days: i)),
          cantidad: porDia[base.subtract(Duration(days: i))] ?? 0,
        ),
    ];
  }

  int get pico =>
      serie.fold<int>(0, (m, p) => p.cantidad > m ? p.cantidad : m);

  /// Postulaciones de los últimos 7 días contra los 7 anteriores.
  /// Null cuando no hay nada con qué comparar.
  int? get variacionSemanal {
    final s = serie;
    if (s.length < 14) return null;
    final recientes =
        s.sublist(s.length - 7).fold<int>(0, (a, p) => a + p.cantidad);
    final previas = s
        .sublist(s.length - 14, s.length - 7)
        .fold<int>(0, (a, p) => a + p.cantidad);
    if (previas == 0 && recientes == 0) return null;
    if (previas == 0) return null;
    return (((recientes - previas) / previas) * 100).round();
  }

  /// Del total de postulaciones, cuántas llegaron a entrevista. Null si no hay
  /// postulaciones (dividir por cero) o si no se pudo leer `interviews`.
  int? get tasaEntrevista {
    if (entrevistasNoDisponibles || postulaciones == 0) return null;
    return ((entrevistas / postulaciones) * 100).round();
  }
}

/// Carga las métricas de una vacante.
Future<VacanteAnalytics> loadVacanteAnalytics(
  String jobId, {
  int dias = 14,
}) async {
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) return VacanteAnalytics.empty;

  final porEstado = <String, int>{};
  final porDia = <DateTime, int>{};

  try {
    final filas = await client
        .from('job_applications')
        .select('status, created_at')
        .eq('job_id', jobId) as List<dynamic>;

    for (final raw in filas) {
      final f = raw as Map;
      final estado = (f['status']?.toString().isNotEmpty ?? false)
          ? f['status'].toString()
          : 'sin estado';
      porEstado[estado] = (porEstado[estado] ?? 0) + 1;

      final fecha = DateTime.tryParse(f['created_at']?.toString() ?? '');
      if (fecha != null) {
        final dia = DateTime(fecha.year, fecha.month, fecha.day);
        porDia[dia] = (porDia[dia] ?? 0) + 1;
      }
    }
  } catch (e) {
    debugPrint('analytics vacante · job_applications: $e');
    return const VacanteAnalytics(error: true);
  }

  var entrevistas = 0;
  var entrevistasNoDisponibles = false;
  try {
    final filas =
        await client.from('interviews').select('id').eq('job_id', jobId);
    entrevistas = (filas as List).length;
  } catch (e) {
    debugPrint('analytics vacante · interviews: $e');
    entrevistasNoDisponibles = true;
  }

  return VacanteAnalytics(
    porEstado: porEstado,
    porDia: porDia,
    dias: dias,
    entrevistas: entrevistas,
    entrevistasNoDisponibles: entrevistasNoDisponibles,
  );
}
