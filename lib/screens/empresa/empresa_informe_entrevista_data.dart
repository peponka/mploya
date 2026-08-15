import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/ai_interview_models.dart';
import '../../services/ai_interview_service.dart';
import '../../utils/user_columns.dart';

/// Una competencia evaluada por la IA.
///
/// Sale de `interview_reports.competencies`, que es JSONB con la forma
/// `[{name, score, note}]`. El puntaje viene 0–100 según la Edge Function
/// `generate-interview-report`; si llegara en otra escala se muestra igual el
/// número crudo, sin normalizarlo a ojo.
@immutable
class CompetenciaEvaluada {
  final String nombre;
  final int? puntaje;
  final String? nota;

  const CompetenciaEvaluada({
    required this.nombre,
    this.puntaje,
    this.nota,
  });

  static CompetenciaEvaluada? desde(dynamic raw) {
    if (raw is! Map) return null;
    final nombre = raw['name']?.toString().trim() ?? '';
    if (nombre.isEmpty) return null;

    final crudo = raw['score'];
    return CompetenciaEvaluada(
      nombre: nombre,
      puntaje: crudo is num ? crudo.round() : null,
      nota: (raw['note']?.toString().trim().isNotEmpty ?? false)
          ? raw['note'].toString().trim()
          : null,
    );
  }
}

/// Una respuesta grabada por el candidato.
@immutable
class RespuestaEntrevista {
  final String pregunta;
  final String? videoUrl;
  final String? transcripcion;

  const RespuestaEntrevista({
    required this.pregunta,
    this.videoUrl,
    this.transcripcion,
  });

  bool get tieneVideo => videoUrl != null && videoUrl!.isNotEmpty;
  bool get tieneTranscripcion =>
      transcripcion != null && transcripcion!.trim().isNotEmpty;
}

/// Informe de una entrevista con IA, listo para mostrar.
@immutable
class InformeEntrevista {
  final Interview entrevista;
  final InterviewReport informe;

  final String candidato;
  final String? candidatoHeadline;
  final String? candidatoAvatar;
  final String? vacante;

  /// `account_type` empieza con "confidenc" o es "stealth": mismo criterio que
  /// Pipeline, Shortlist, Mensajes, Match IA y el Perfil de Candidato.
  /// `candidato`/`candidatoAvatar` guardan el dato REAL — el ocultamiento es
  /// sólo de presentación.
  final bool candidatoConfidencial;

  final List<CompetenciaEvaluada> competencias;
  final List<String> habilidades;
  final List<RespuestaEntrevista> respuestas;

  const InformeEntrevista({
    required this.entrevista,
    required this.informe,
    required this.candidato,
    this.candidatoHeadline,
    this.candidatoAvatar,
    this.candidatoConfidencial = false,
    this.vacante,
    this.competencias = const [],
    this.habilidades = const [],
    this.respuestas = const [],
  });

  /// Nombre a mostrar: un candidato confidencial no expone su identidad acá
  /// tampoco, aunque `candidato` guarde el nombre real.
  String get candidatoVisible =>
      candidatoConfidencial ? 'Candidato confidencial' : candidato;

  /// Sin foto real para un candidato confidencial — mismo criterio que el
  /// resto de Empresa.
  String? get candidatoAvatarVisible =>
      candidatoConfidencial ? null : candidatoAvatar;

  int? get puntaje => informe.score;

  bool get tieneResumen => informe.summary?.trim().isNotEmpty ?? false;
  bool get tieneVeredicto => informe.rationale?.trim().isNotEmpty ?? false;

  /// Promedio de las competencias con puntaje. Null si ninguna lo trae.
  int? get promedioCompetencias {
    final conPuntaje =
        competencias.where((c) => c.puntaje != null).toList();
    if (conPuntaje.isEmpty) return null;
    final suma = conPuntaje.fold<int>(0, (s, c) => s + c.puntaje!);
    return (suma / conPuntaje.length).round();
  }
}

/// Por qué no hay informe que mostrar.
enum MotivoSinInforme {
  /// La entrevista existe pero todavía no está completada.
  entrevistaIncompleta,

  /// Está completada y el informe todavía no se generó.
  informePendiente,

  /// No se pudo leer.
  error,
}

@immutable
class InformeEntrevistaData {
  final InformeEntrevista? informe;
  final MotivoSinInforme? motivo;

  /// Datos del candidato aunque no haya informe, para poder encabezar la
  /// pantalla igual.
  final String candidato;
  final String? candidatoHeadline;
  final String? candidatoAvatar;

  const InformeEntrevistaData({
    this.informe,
    this.motivo,
    this.candidato = 'Candidato',
    this.candidatoHeadline,
    this.candidatoAvatar,
  });

  bool get hayInforme => informe != null;
}

/// Un id de entrevista de demostración, de los que `AIInterviewService`
/// responde con datos inventados.
bool esIdDemo(String interviewId) => interviewId.startsWith('demo-');

/// Carga el informe de una entrevista con IA.
///
/// Reutiliza [AIInterviewService] entero: `fetchInterview`, `fetchReport`,
/// `fetchQuestions` y `fetchAnswers`. No duplica ninguna consulta ni inventa
/// campos: si `interview_reports` no tiene fila, se dice que el informe está
/// pendiente en vez de rellenarlo.
Future<InformeEntrevistaData> loadInformeEntrevista(String interviewId) async {
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) {
    return const InformeEntrevistaData(motivo: MotivoSinInforme.error);
  }

  // BLINDAJE CONTRA DATOS DEMO. `AIInterviewService` devuelve entrevistas,
  // preguntas, respuestas e informes FALSOS —incluido un video de stock y una
  // transcripción inventada— para cualquier id que empiece con `demo-`. Eso
  // existe para el ATS legacy; Empresa Mobile no debe mostrarlo nunca, así que
  // se corta acá antes de llamar al servicio.
  if (esIdDemo(interviewId)) {
    return const InformeEntrevistaData(motivo: MotivoSinInforme.error);
  }

  final servicio = AIInterviewService.instance;

  final entrevista = await servicio.fetchInterview(interviewId);
  if (entrevista == null) {
    return const InformeEntrevistaData(motivo: MotivoSinInforme.error);
  }

  // ── Candidato y vacante ──
  var candidato = 'Candidato';
  String? headline;
  String? avatar;
  String? vacante;
  var candidatoConfidencial = false;

  try {
    final fila = await client
        .from('users')
        .select(kUserColumns)
        .eq('id', entrevista.candidateId)
        .maybeSingle();
    if (fila != null) {
      candidato = fila['name']?.toString() ?? 'Candidato';
      final h = fila['headline']?.toString() ?? '';
      headline = h.isEmpty ? null : h;
      final a = fila['avatar_url']?.toString() ?? '';
      avatar = a.isEmpty ? null : a;
      final tipo = fila['account_type']?.toString().toLowerCase() ?? '';
      candidatoConfidencial = tipo.startsWith('confidenc') || tipo == 'stealth';
    }
  } catch (e) {
    debugPrint('informe entrevista · users: $e');
  }

  try {
    final fila = await client
        .from('jobs')
        .select('title')
        .eq('id', entrevista.jobId)
        .maybeSingle();
    final t = fila?['title']?.toString() ?? '';
    vacante = t.isEmpty ? null : t;
  } catch (e) {
    debugPrint('informe entrevista · jobs: $e');
  }

  final base = InformeEntrevistaData(
    candidato: candidato,
    candidatoHeadline: headline,
    candidatoAvatar: avatar,
  );

  if (entrevista.status != 'completed') {
    return InformeEntrevistaData(
      motivo: MotivoSinInforme.entrevistaIncompleta,
      candidato: base.candidato,
      candidatoHeadline: base.candidatoHeadline,
      candidatoAvatar: base.candidatoAvatar,
    );
  }

  final informe = await servicio.fetchReport(interviewId);
  if (informe == null) {
    return InformeEntrevistaData(
      motivo: MotivoSinInforme.informePendiente,
      candidato: base.candidato,
      candidatoHeadline: base.candidatoHeadline,
      candidatoAvatar: base.candidatoAvatar,
    );
  }

  // ── Competencias y habilidades, tal como las dejó la IA ──
  final competencias = <CompetenciaEvaluada>[
    for (final c in (informe.competencies ?? const []))
      if (CompetenciaEvaluada.desde(c) != null) CompetenciaEvaluada.desde(c)!,
  ];

  final habilidades = <String>[
    for (final k in (informe.keywords ?? const []))
      k.toString().replaceAll('#', '').trim(),
  ]..removeWhere((k) => k.isEmpty);

  // ── Respuestas, emparejadas con su pregunta ──
  final respuestas = <RespuestaEntrevista>[];
  try {
    final preguntas = await servicio.fetchQuestions(interviewId);
    final textoPorId = {for (final p in preguntas) p.id: p.text};

    final filas = await servicio.fetchAnswers(interviewId);
    for (final f in filas) {
      final idPregunta = f['question_id']?.toString() ?? '';
      final video = f['video_url']?.toString() ?? '';
      final transcript = f['transcript']?.toString() ?? '';
      respuestas.add(
        RespuestaEntrevista(
          pregunta: textoPorId[idPregunta] ?? 'Pregunta de la entrevista',
          videoUrl: video.isEmpty ? null : video,
          transcripcion: transcript.isEmpty ? null : transcript,
        ),
      );
    }
  } catch (e) {
    debugPrint('informe entrevista · respuestas: $e');
  }

  return InformeEntrevistaData(
    candidato: candidato,
    candidatoHeadline: headline,
    candidatoAvatar: avatar,
    informe: InformeEntrevista(
      entrevista: entrevista,
      informe: informe,
      candidato: candidato,
      candidatoHeadline: headline,
      candidatoAvatar: avatar,
      candidatoConfidencial: candidatoConfidencial,
      vacante: vacante,
      competencias: competencias,
      habilidades: habilidades,
      respuestas: respuestas,
    ),
  );
}

/// Ids de entrevistas que YA tienen informe generado.
///
/// La agenda la usa para no ofrecer "ver informe" en una entrevista que todavía
/// no lo tiene: es una sola consulta sobre `interview_reports`.
Future<Set<String>> loadEntrevistasConInforme(List<String> interviewIds) async {
  final ids = interviewIds.where((id) => !esIdDemo(id)).toList();
  if (ids.isEmpty) return {};

  try {
    final filas = await Supabase.instance.client
        .from('interview_reports')
        .select('interview_id')
        .inFilter('interview_id', ids) as List<dynamic>;

    return {
      for (final f in filas)
        if ((f as Map)['interview_id'] != null)
          f['interview_id'].toString(),
    };
  } catch (e) {
    debugPrint('informe entrevista · interview_reports: $e');
    return {};
  }
}
