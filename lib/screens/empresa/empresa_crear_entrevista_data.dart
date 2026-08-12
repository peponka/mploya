import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/ai_interview_models.dart';
import '../../services/ai_interview_service.dart';

/// Un candidato al que se le puede pedir una entrevista con IA.
///
/// Sale de `get_company_candidates`: son postulaciones REALES a vacantes de la
/// empresa. No se ofrece entrevistar a alguien que no se postuló.
@immutable
class CandidatoEntrevistable {
  final String candidatoId;
  final String nombre;
  final String? headline;
  final String? avatarUrl;
  final String vacanteId;
  final String vacante;

  /// Ya tiene una entrevista con IA para esta vacante.
  final bool yaTieneEntrevista;

  const CandidatoEntrevistable({
    required this.candidatoId,
    required this.nombre,
    required this.vacanteId,
    required this.vacante,
    this.headline,
    this.avatarUrl,
    this.yaTieneEntrevista = false,
  });
}

@immutable
class CrearEntrevistaData {
  final List<CandidatoEntrevistable> candidatos;
  final bool error;

  const CrearEntrevistaData({required this.candidatos, this.error = false});

  static const empty = CrearEntrevistaData(candidatos: []);

  int get disponibles =>
      candidatos.where((c) => !c.yaTieneEntrevista).length;

  Map<String, List<CandidatoEntrevistable>> get porVacante {
    final mapa = <String, List<CandidatoEntrevistable>>{};
    for (final c in candidatos) {
      mapa.putIfAbsent(c.vacante, () => []).add(c);
    }
    return mapa;
  }
}

/// Postulantes de la empresa, marcando a quién ya se le pidió una entrevista.
Future<CrearEntrevistaData> loadCandidatosEntrevistables() async {
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) return CrearEntrevistaData.empty;

  final candidatos = <CandidatoEntrevistable>[];

  try {
    final filas = await client.rpc('get_company_candidates') as List<dynamic>;
    for (final raw in filas) {
      final p = raw as Map;
      final id = p['candidate_id']?.toString() ?? '';
      final jobId = p['job_id']?.toString() ?? '';
      if (id.isEmpty || jobId.isEmpty) continue;

      candidatos.add(
        CandidatoEntrevistable(
          candidatoId: id,
          nombre: p['candidate_name']?.toString() ?? 'Candidato',
          headline: (p['candidate_headline']?.toString().isNotEmpty ?? false)
              ? p['candidate_headline'].toString()
              : null,
          avatarUrl: (p['candidate_avatar_url']?.toString().isNotEmpty ?? false)
              ? p['candidate_avatar_url'].toString()
              : null,
          vacanteId: jobId,
          vacante: p['job_title']?.toString() ?? 'Vacante',
        ),
      );
    }
  } catch (e) {
    debugPrint('crear entrevista · get_company_candidates: $e');
    return const CrearEntrevistaData(candidatos: [], error: true);
  }

  if (candidatos.isEmpty) return CrearEntrevistaData.empty;

  // ── Quién ya tiene entrevista, para no pedir dos veces la misma ──
  final yaTiene = <String>{};
  try {
    final jobIds = candidatos.map((c) => c.vacanteId).toSet().toList();
    final filas = await client
        .from('interviews')
        .select('job_id, candidate_id')
        .inFilter('job_id', jobIds) as List<dynamic>;

    for (final f in filas) {
      final m = f as Map;
      yaTiene.add('${m['job_id']}·${m['candidate_id']}');
    }
  } catch (e) {
    debugPrint('crear entrevista · interviews: $e');
  }

  return CrearEntrevistaData(
    candidatos: [
      for (final c in candidatos)
        CandidatoEntrevistable(
          candidatoId: c.candidatoId,
          nombre: c.nombre,
          headline: c.headline,
          avatarUrl: c.avatarUrl,
          vacanteId: c.vacanteId,
          vacante: c.vacante,
          yaTieneEntrevista:
              yaTiene.contains('${c.vacanteId}·${c.candidatoId}'),
        ),
    ],
  );
}

/// Resultado de pedir una entrevista.
@immutable
class ResultadoPedido {
  /// Id de la entrevista, tal como lo devolvió la RPC. Null si no se creó.
  final String? interviewId;

  /// La entrevista ya existía: NO se creó una segunda ni se volvió a avisar.
  final bool yaExistia;

  /// Preguntas que generó la IA. Vacío si la generación falló.
  final List<InterviewQuestion> preguntas;

  final String? error;

  const ResultadoPedido({
    this.interviewId,
    this.yaExistia = false,
    this.preguntas = const [],
    this.error,
  });

  bool get ok => interviewId != null;

  /// La invitación se escribió en esta llamada.
  ///
  /// Es exactamente lo mismo que "se creó la entrevista": la RPC inserta las dos
  /// filas en la misma transacción, así que no existe el caso de una entrevista
  /// nueva sin aviso.
  bool get avisado => ok && !yaExistia;
}

/// Traduce el motivo que devuelve `request_ai_interview` a algo que la empresa
/// pueda entender y accionar.
///
/// Los códigos los fija la migración 027 y son estables; el texto se arma acá
/// para no mandar prosa desde la base. Un código desconocido cae a un mensaje
/// genérico en vez de mostrar el código crudo.
String mensajeDeErrorPedido(String? codigo) {
  switch (codigo) {
    case 'no_auth':
      return 'Tu sesión venció. Volvé a entrar y probá de nuevo.';
    case 'autoentrevista':
      return 'No podés pedirte una entrevista a vos mismo.';
    case 'vacante_inexistente':
      return 'Esa vacante ya no existe. Actualizá la lista.';
    case 'vacante_ajena':
      return 'Esa vacante no es de tu empresa.';
    case 'no_postulado':
      return 'Esa persona no se postuló a esta vacante, así que no se le puede '
          'pedir una entrevista. Actualizá la lista.';
    case 'candidato_inexistente':
      return 'El perfil de esa persona ya no está disponible.';
    default:
      return 'No pudimos crear la entrevista. Probá de nuevo en un momento.';
  }
}

/// Pide una entrevista con IA para un candidato.
///
/// DOS PASOS, Y EN ESTE ORDEN:
///
///   1. `request_ai_interview` (migración 027). Una sola RPC que, del lado del
///      servidor, valida que la vacante sea de esta empresa y que el candidato
///      se haya postulado a ella, y después crea la entrevista y escribe la
///      invitación EN LA MISMA TRANSACCIÓN. Si la entrevista ya existía, la
///      devuelve y no avisa de nuevo.
///
///   2. La generación de preguntas, que es una llamada HTTP a Gemini y por eso
///      queda FUERA de la transacción. Se disparan y después se releen de la
///      base: no se declara éxito por el `200` de la Edge Function, sino porque
///      las preguntas están.
///
/// POR QUÉ NO SE INSERTA LA NOTIFICACIÓN DESDE ACÁ. `public.notifications`
/// tiene RLS activa y NINGUNA política de INSERT (verificado en la base el
/// 12/8/2026), así que un insert desde el cliente devuelve 42501 y el candidato
/// nunca se entera. Y no se abre una política porque la tabla dispara un push
/// FCM en cada insert: sería habilitar pushes arbitrarios entre usuarios.
///
/// Si la generación de preguntas falla, la entrevista NO se borra: ya está
/// creada y el candidato ya fue invitado. Se informa y listo.
Future<ResultadoPedido> pedirEntrevista({
  required String jobId,
  required String candidatoId,
}) async {
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) {
    return ResultadoPedido(error: mensajeDeErrorPedido('no_auth'));
  }

  // ── 1. Entrevista + invitación, atómico y validado en el servidor ──
  Map<String, dynamic> respuesta;
  try {
    final cruda = await client.rpc(
      'request_ai_interview',
      params: {'p_job_id': jobId, 'p_candidate_id': candidatoId},
    );
    if (cruda is! Map) {
      debugPrint('crear entrevista · respuesta inesperada: $cruda');
      return ResultadoPedido(error: mensajeDeErrorPedido(null));
    }
    respuesta = Map<String, dynamic>.from(cruda);
  } catch (e) {
    debugPrint('crear entrevista · request_ai_interview: $e');
    return ResultadoPedido(error: mensajeDeErrorPedido(null));
  }

  if (respuesta['ok'] != true) {
    return ResultadoPedido(
      error: mensajeDeErrorPedido(respuesta['error']?.toString()),
    );
  }

  final interviewId = respuesta['interview_id']?.toString() ?? '';
  if (interviewId.isEmpty) {
    debugPrint('crear entrevista · la RPC no devolvió interview_id');
    return ResultadoPedido(error: mensajeDeErrorPedido(null));
  }
  final yaExistia = respuesta['ya_existia'] == true;

  // ── 2. Preguntas: fuera de la transacción ──
  final servicio = AIInterviewService.instance;
  var preguntas = <InterviewQuestion>[];
  try {
    // El `job_id` va explícito: la Edge Function lo exige y sin él devuelve 400
    // sin generar nada.
    await servicio.triggerQuestionGeneration(interviewId, jobId: jobId);
    // Se releen de la base: que la función responda 200 no prueba que hayan
    // quedado persistidas.
    preguntas = await servicio.fetchQuestions(interviewId);
  } catch (e) {
    debugPrint('crear entrevista · preguntas: $e');
  }

  return ResultadoPedido(
    interviewId: interviewId,
    yaExistia: yaExistia,
    preguntas: preguntas,
  );
}
