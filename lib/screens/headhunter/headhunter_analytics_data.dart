import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/headhunter_candidate_privacy.dart';

/// Métricas reales de Colocaciones y Analytics (Headhunter).
///
/// RECONSTRUCCIÓN de `18_Headhunter_Colocaciones_Analytics.png`, con el
/// mismo principio que `empresa_vacante_analytics_data.dart`: se calcula
/// todo lo que sale de filas reales (`headhunter_placements`,
/// `headhunter_pipeline_candidates`, `headhunter_pipeline_stage_history`,
/// migración 044) y NO se inventa lo que el mockup pide pero no existe —
/// "Referidos"/"Aplicaciones" como fuente de colocación, por ejemplo, van a
/// dar siempre 0 porque no hay ningún flujo de referido ni de postulación
/// formal en este modelo de sourcing.
@immutable
class HeadhunterAnalytics {
  final List<Map<String, dynamic>> placements;
  final Map<String, String> jobTitleById;
  final Map<String, String> clientNameById;
  final Map<String, String> candidateNameById;
  final int totalJobs;
  final int jobsWithPipeline;

  /// `source` (busqueda_activa/talent_pool) de cada pipeline_candidate que
  /// terminó colocado — para la dona "Colocaciones por fuente".
  final Map<String, int> sourceCounts;

  /// Duración promedio real en cada una de las 7 etapas, sólo para etapas
  /// con al menos una transición completa (entró y salió). Ausente = "sin
  /// datos todavía", no un cero.
  final Map<String, Duration> stageAverages;

  final bool error;

  const HeadhunterAnalytics({
    this.placements = const [],
    this.jobTitleById = const {},
    this.clientNameById = const {},
    this.candidateNameById = const {},
    this.totalJobs = 0,
    this.jobsWithPipeline = 0,
    this.sourceCounts = const {},
    this.stageAverages = const {},
    this.error = false,
  });

  static const empty = HeadhunterAnalytics();

  bool get sinDatos => placements.isEmpty && totalJobs == 0;

  int get colocaciones => placements.length;

  /// Definición literal del mockup: "Colocaciones / búsquedas". Null si no
  /// hay ninguna búsqueda con pipeline (dividir por cero).
  int? get tasaExito =>
      jobsWithPipeline == 0 ? null : ((colocaciones / jobsWithPipeline) * 100).round();

  /// Días promedio entre que el candidato entró al pipeline y se colocó.
  /// Null si ninguna colocación tiene ambas fechas.
  Duration? get tiempoPromedio {
    final valores = [
      for (final p in placements)
        if (p['_dias_en_pipeline'] is int) p['_dias_en_pipeline'] as int,
    ];
    if (valores.isEmpty) return null;
    return Duration(days: (valores.reduce((a, b) => a + b) / valores.length).round());
  }

  /// Colocaciones agrupadas por mes (clave "yyyy-MM"), para la evolución.
  Map<String, int> get colocacionesPorMes {
    final out = <String, int>{};
    for (final p in placements) {
      final fecha = DateTime.tryParse(p['placed_at']?.toString() ?? '');
      if (fecha == null) continue;
      final clave = '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}';
      out[clave] = (out[clave] ?? 0) + 1;
    }
    return out;
  }

  double get feesGenerados => _sumaFee((p) => true);
  double get comisionesCobradas => _sumaFee((p) => p['payment_status'] == 'cobrado');
  double get pendienteDeCobro => _sumaFee((p) => p['payment_status'] == 'pendiente');

  double? get ticketPromedio {
    final conFee = placements.where((p) => p['fee_amount'] != null).toList();
    if (conFee.isEmpty) return null;
    return feesGenerados / conFee.length;
  }

  double _sumaFee(bool Function(Map<String, dynamic>) filtro) {
    var total = 0.0;
    for (final p in placements) {
      if (!filtro(p)) continue;
      final fee = p['fee_amount'];
      if (fee is num) total += fee.toDouble();
    }
    return total;
  }

  /// Top 5 clientes por cantidad de colocaciones.
  List<({String clientId, String nombre, int colocaciones})> get topClientes {
    final porCliente = <String, int>{};
    for (final p in placements) {
      final id = p['client_id']?.toString();
      if (id == null) continue;
      porCliente[id] = (porCliente[id] ?? 0) + 1;
    }
    final entradas = porCliente.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final e in entradas.take(5))
        (clientId: e.key, nombre: clientNameById[e.key] ?? 'Cliente', colocaciones: e.value),
    ];
  }
}

/// Carga las métricas del headhunter autenticado.
Future<HeadhunterAnalytics> loadHeadhunterAnalytics({
  String? clientId,
  DateTime? desde,
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  final uid = db.auth.currentUser?.id;
  if (uid == null) return HeadhunterAnalytics.empty;

  try {
    var query = db
        .from('headhunter_placements')
        .select('id, pipeline_candidate_id, job_id, client_id, candidate_id, '
            'fee_amount, currency, payment_status, placed_at')
        .eq('headhunter_id', uid);
    if (clientId != null) query = query.eq('client_id', clientId);
    if (desde != null) query = query.gte('placed_at', desde.toIso8601String());

    final placements = List<Map<String, dynamic>>.from(await query as List);

    final jobs = List<Map<String, dynamic>>.from(
      await db.from('jobs').select('id, title').eq('company_id', uid) as List,
    );
    final jobTitleById = {for (final j in jobs) j['id'].toString(): j['title']?.toString() ?? ''};

    final pipelineRows = List<Map<String, dynamic>>.from(
      await db
          .from('headhunter_pipeline_candidates')
          .select('id, job_id, source, stage, created_at')
          .eq('headhunter_id', uid) as List,
    );
    final jobsWithPipeline = pipelineRows.map((r) => r['job_id'].toString()).toSet().length;
    final pipelineById = {for (final r in pipelineRows) r['id'].toString(): r};

    // Días entre alta en el pipeline y colocación, por colocación.
    for (final p in placements) {
      final pc = pipelineById[p['pipeline_candidate_id']?.toString()];
      final creado = DateTime.tryParse(pc?['created_at']?.toString() ?? '');
      final colocado = DateTime.tryParse(p['placed_at']?.toString() ?? '');
      if (creado != null && colocado != null) {
        p['_dias_en_pipeline'] = colocado.difference(creado).inDays;
      }
    }

    final sourceCounts = <String, int>{};
    for (final p in placements) {
      final pc = pipelineById[p['pipeline_candidate_id']?.toString()];
      final source = pc?['source']?.toString();
      if (source == null) continue;
      sourceCounts[source] = (sourceCounts[source] ?? 0) + 1;
    }

    final clientIds = placements.map((p) => p['client_id']?.toString()).whereType<String>().toSet().toList();
    final clients = clientIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await db.from('headhunter_clients').select('id, company_name').inFilter('id', clientIds) as List,
          );
    final clientNameById = {for (final c in clients) c['id'].toString(): c['company_name']?.toString() ?? ''};

    final candidateIds = placements.map((p) => p['candidate_id']?.toString()).whereType<String>().toSet().toList();
    final candidates = candidateIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await db.from('accessible_user_profiles').select('id, name, account_type').inFilter('id', candidateIds) as List,
          );
    final candidateNameById = {
      for (final c in candidates)
        c['id'].toString(): protectCandidateRowForHeadhunter(c, 'headhunter')['name']?.toString() ?? 'Candidato',
    };

    // Tiempo promedio real por etapa, vía la historia de transiciones.
    final candidateIdsForHistory = pipelineRows.map((r) => r['id'].toString()).toList();
    final history = candidateIdsForHistory.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await db
                .from('headhunter_pipeline_stage_history')
                .select('pipeline_candidate_id, from_stage, to_stage, changed_at')
                .inFilter('pipeline_candidate_id', candidateIdsForHistory)
                .order('changed_at', ascending: true) as List,
          );
    final porCandidato = <String, List<Map<String, dynamic>>>{};
    for (final h in history) {
      (porCandidato[h['pipeline_candidate_id'].toString()] ??= []).add(h);
    }
    final duracionesPorEtapa = <String, List<int>>{};
    for (final entry in porCandidato.entries) {
      final filas = entry.value;
      final creado = DateTime.tryParse(pipelineById[entry.key]?['created_at']?.toString() ?? '');
      DateTime? anterior = creado;
      for (final h in filas) {
        final cambio = DateTime.tryParse(h['changed_at']?.toString() ?? '');
        final etapaQueTermina = h['from_stage']?.toString();
        if (anterior != null && cambio != null && etapaQueTermina != null) {
          (duracionesPorEtapa[etapaQueTermina] ??= []).add(cambio.difference(anterior).inHours);
        }
        anterior = cambio;
      }
    }
    final stageAverages = <String, Duration>{
      for (final e in duracionesPorEtapa.entries)
        if (e.value.isNotEmpty)
          e.key: Duration(hours: (e.value.reduce((a, b) => a + b) / e.value.length).round()),
    };

    return HeadhunterAnalytics(
      placements: placements,
      jobTitleById: jobTitleById,
      clientNameById: clientNameById,
      candidateNameById: candidateNameById,
      totalJobs: jobs.length,
      jobsWithPipeline: jobsWithPipeline,
      sourceCounts: sourceCounts,
      stageAverages: stageAverages,
    );
  } catch (e) {
    debugPrint('analytics headhunter: $e');
    return const HeadhunterAnalytics(error: true);
  }
}
