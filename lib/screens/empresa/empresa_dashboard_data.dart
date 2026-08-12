import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Una etapa del embudo de `dashboard empresa.png`.
@immutable
class EmpresaStage {
  final String label;
  final int value;

  const EmpresaStage({required this.label, required this.value});
}

@immutable
class EmpresaMonthPoint {
  final String label;
  final double value;

  const EmpresaMonthPoint({required this.label, required this.value});
}

/// Una fuente de candidatos de la dona "Fuentes de candidatos".
@immutable
class EmpresaSource {
  final String label;
  final int value;

  const EmpresaSource({required this.label, required this.value});
}

/// Datos del Dashboard de Empresa.
///
/// REGLA: acá no se inventan números. Si un KPI vale 0, vale 0. Si una sección
/// no tiene datos, la UI muestra su estado vacío con la MISMA composición del
/// mockup, no un bloque distinto.
@immutable
class EmpresaDashboardData {
  final String companyName;

  /// KPI 1 — vacantes activas.
  final int vacantesActivas;

  /// KPI 2 — candidatos en proceso (postulaciones no cerradas).
  final int candidatosEnProceso;

  /// KPI 3 — entrevistas de esta semana (lunes a hoy).
  final int entrevistasSemana;

  /// KPI 4 — contrataciones de este mes.
  final int contratacionesMes;

  /// Embudo de 5 etapas, en el orden del mockup.
  final List<EmpresaStage> funnel;

  /// Contrataciones por mes (6 meses, de más viejo a más nuevo).
  final List<EmpresaMonthPoint> hiringTrend;

  /// Fuentes de candidatos. Vacío mientras el backend no registre el origen.
  final List<EmpresaSource> sources;

  /// Tiempo promedio por etapa, en días. Vacío mientras no haya marcas de
  /// tiempo por transición de etapa.
  final Map<String, double> stageDays;

  const EmpresaDashboardData({
    required this.companyName,
    required this.vacantesActivas,
    required this.candidatosEnProceso,
    required this.entrevistasSemana,
    required this.contratacionesMes,
    required this.funnel,
    required this.hiringTrend,
    required this.sources,
    required this.stageDays,
  });

  bool get hasFunnel => funnel.any((stage) => stage.value > 0);
  bool get hasTrend => hiringTrend.any((point) => point.value > 0);
  bool get hasSources => sources.any((source) => source.value > 0);
  bool get hasStageDays => stageDays.isNotEmpty;

  /// Sin vacantes la empresa todavía no arrancó: cambia el tono de los vacíos.
  bool get hasNoJobs => vacantesActivas == 0;

  static const empty = EmpresaDashboardData(
    companyName: '',
    vacantesActivas: 0,
    candidatosEnProceso: 0,
    entrevistasSemana: 0,
    contratacionesMes: 0,
    funnel: _emptyFunnel,
    hiringTrend: [],
    sources: [],
    stageDays: {},
  );

  /// Las cinco etapas del mockup, en cero. Se usa mientras carga y cuando no
  /// hay datos, para que la composición no cambie de forma.
  static const _emptyFunnel = [
    EmpresaStage(label: 'Postulados', value: 0),
    EmpresaStage(label: 'Screening', value: 0),
    EmpresaStage(label: 'Entrevistas', value: 0),
    EmpresaStage(label: 'Oferta', value: 0),
    EmpresaStage(label: 'Contratados', value: 0),
  ];
}

/// Carga el dashboard desde Supabase.
///
/// MAPEO DEL EMBUDO — el mockup pide cinco etapas y el backend las cubre así:
///
///   Postulados   job_applications                      (todas)
///   Screening    job_applications.status = 'viewed'
///   Entrevistas  interviews                            (de las vacantes propias)
///   Oferta       job_applications.status = 'accepted'
///   Contratados  connections.ats_status = 'hired'      (RPC get_my_pipeline)
///
/// Todas son columnas que YA existen. Ninguna etapa se inventa: la que no tiene
/// registros muestra 0, que es lo que corresponde.
Future<EmpresaDashboardData> loadEmpresaDashboard() async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return EmpresaDashboardData.empty;

  var companyName = '';
  try {
    final me =
        await client.from('users').select('name').eq('id', uid).maybeSingle();
    companyName = (me?['name'] ?? '').toString();
  } catch (_) {}

  var jobs = <Map<String, dynamic>>[];
  try {
    jobs = List<Map<String, dynamic>>.from(
      await client
          .from('jobs')
          .select('id, is_active')
          .eq('company_id', uid),
    );
  } catch (e) {
    debugPrint('empresa dashboard · jobs: $e');
  }
  final jobIds = jobs.map((job) => job['id'].toString()).toList();

  var applications = <Map<String, dynamic>>[];
  if (jobIds.isNotEmpty) {
    try {
      applications = List<Map<String, dynamic>>.from(
        await client
            .from('job_applications')
            .select('status, created_at')
            .inFilter('job_id', jobIds),
      );
    } catch (e) {
      debugPrint('empresa dashboard · applications: $e');
    }
  }

  var interviews = <Map<String, dynamic>>[];
  if (jobIds.isNotEmpty) {
    try {
      interviews = List<Map<String, dynamic>>.from(
        await client
            .from('interviews')
            .select('id, created_at')
            .inFilter('job_id', jobIds),
      );
    } catch (e) {
      debugPrint('empresa dashboard · interviews: $e');
    }
  }

  // Ya no se consulta `get_my_pipeline`: su único uso acá era el embudo, que
  // quedó oculto. Verificado el 12/8/2026 contra la base — devuelve 0 filas y
  // el valor 'hired' no existe en `ats_status`.

  int countStatus(String status) => applications
      .where((app) => (app['status']?.toString() ?? '') == status)
      .length;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  // Semana que arranca el lunes, como se lee "esta semana" en el mockup.
  final weekStart = today.subtract(Duration(days: today.weekday - 1));

  DateTime? parseDate(Object? raw) =>
      raw == null ? null : DateTime.tryParse(raw.toString());

  final entrevistasSemana = interviews.where((row) {
    final date = parseDate(row['created_at']);
    return date != null && !date.isBefore(weekStart);
  }).length;

  // OFERTAS ACEPTADAS — corregido dos veces el 12/8/2026.
  //
  // 1er intento: contaba `job_applications.status = 'accepted'` y lo rotulaba
  //   "Contrataciones". Mal: aceptar una postulación no es contratar, y el
  //   embudo de esta misma pantalla llama "Oferta" a ese estado.
  //
  // 2do intento: se pasó a `connections.ats_status = 'hired'` vía
  //   `get_my_pipeline`. PEOR: verificado contra la base, ese valor NO EXISTE
  //   —las filas reales tienen 'pendiente'— y ninguna ruta productiva escribe
  //   `ats_status`; el único código que lo hacía (`ats_kanban_screen`) es
  //   inalcanzable. El KPI mostraba 0 permanente.
  //
  // Ahora: se vuelve al dato REAL —`accepted`— con el nombre que le
  // corresponde. La tarjeta dice "Ofertas aceptadas", que es exactamente lo
  // que cuenta. No hay ningún dato de contratación en el sistema, así que no
  // se muestra ninguno.
  final ofertasAceptadas = countStatus('accepted');

  // EVOLUCIÓN DE CONTRATACIONES — eliminada el 12/8/2026.
  //
  // La serie agrupaba por `job_applications.created_at`, que es cuándo se
  // POSTULÓ el candidato, no cuándo se lo contrató: alguien que se postuló en
  // enero y fue aceptado en agosto sumaba en enero. No era la evolución de las
  // contrataciones, era la de las postulaciones que hoy están aceptadas.
  //
  // No se reemplazó por otra serie: no existe ninguna columna con la fecha del
  // cambio de estado. Cuando se persista esa fecha, la gráfica vuelve con la
  // cuenta real. `hiringTrend` queda vacío y la tarjeta no se dibuja.

  return EmpresaDashboardData(
    companyName: companyName,
    vacantesActivas: jobs.where((job) => job['is_active'] != false).length,
    // "En proceso" = postulaciones que siguen vivas.
    candidatosEnProceso: applications
        .where((app) => (app['status']?.toString() ?? '') != 'rejected')
        .length,
    entrevistasSemana: entrevistasSemana,
    contratacionesMes: ofertasAceptadas,
    // EMBUDO — oculto en producción. Cuatro de sus cinco etapas son
    // confiables, pero "Contratados" lee `ats_status = hired`, un valor que
    // nadie escribe: los porcentajes de TODAS las etapas salían mal. Vuelve
    // cuando el pipeline ATS funcione de punta a punta.
    funnel: const [],
    hiringTrend: const [],
    // El backend todavía no registra origen ni tiempos por etapa.
    sources: const [],
    stageDays: const {},
  );
}
