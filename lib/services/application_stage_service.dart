import 'package:supabase_flutter/supabase_flutter.dart';

/// Etapas de una postulación y su historial (migraciones 029 y 050).
///
/// ÚNICA VÍA DE ESCRITURA. El estado de una postulación sólo se cambia por la
/// función `update_application_status`. `job_applications` no tiene policy de
/// UPDATE para nadie, así que no hay forma —ni tentación— de escribirlo
/// directo desde acá.
///
/// El historial lo escribe el trigger del lado del servidor: este servicio
/// sólo lo lee. Si una postulación no tiene historial es porque es anterior a
/// la migración 050, no porque se haya perdido; la 050 no hace backfill a
/// propósito (ver §6 de esa migración).

// ─────────────────────────────────────────────────────────────────────────────
// Vocabulario
// ─────────────────────────────────────────────────────────────────────────────

/// Los seis estados reales de `job_applications.status`, en orden de avance.
/// `rejected` va aparte porque no es una etapa del avance sino una salida.
const List<String> kApplicationStages = [
  'pending',
  'viewed',
  'interviewing',
  'accepted',
  'hired',
];

const String kApplicationRejected = 'rejected';

/// Etiqueta en castellano de cada estado. Se usa en Pipeline, historial y
/// Contrataciones para que las tres pantallas digan lo mismo.
String applicationStageLabel(String status) => switch (status) {
      'pending' => 'Nuevo',
      'viewed' => 'Visto',
      'interviewing' => 'En entrevista',
      'accepted' => 'Con oferta',
      'hired' => 'Contratado',
      'rejected' => 'Descartado',
      _ => status,
    };

/// Frase corta para el historial: "pasó a En entrevista".
String applicationStageVerb(String status) => switch (status) {
      'hired' => 'Contratado',
      'rejected' => 'Descartado',
      _ => applicationStageLabel(status),
    };

/// Copia EXACTA de la matriz de transiciones de la migración 029/050.
///
/// Vive también acá para que la interfaz ofrezca sólo movimientos válidos en
/// vez de dejar que el usuario elija uno que el servidor va a rechazar. La
/// autoridad sigue siendo el servidor: si estas dos se desincronizan, gana la
/// base y el usuario ve el error traducido, nunca un cambio silencioso.
const Map<String, List<String>> kAllowedStageTransitions = {
  'pending': ['viewed', 'interviewing', 'accepted', 'rejected'],
  'viewed': ['pending', 'interviewing', 'accepted', 'rejected'],
  'interviewing': ['viewed', 'accepted', 'rejected'],
  'accepted': ['interviewing', 'hired', 'rejected'],
  'hired': ['accepted', 'rejected'],
  'rejected': ['pending', 'viewed', 'interviewing', 'accepted'],
};

/// Destinos válidos desde [status]. Lista vacía si el estado es desconocido.
List<String> allowedStagesFrom(String status) =>
    kAllowedStageTransitions[status] ?? const [];

/// A `hired` sólo se llega desde `accepted`: toda contratación pasa por la
/// oferta. Lo dice la matriz, y se expone acá para poder explicarlo en la UI
/// en vez de mostrar una opción deshabilitada sin motivo.
bool requiereOfertaPrevia(String desde, String hacia) =>
    hacia == 'hired' && desde != 'accepted';

// ─────────────────────────────────────────────────────────────────────────────
// Errores
// ─────────────────────────────────────────────────────────────────────────────

/// Error con un mensaje ya escrito para mostrarle a una persona.
///
/// Los errores de la RPC son precisos pero están escritos para quien lee la
/// migración. Acá se traducen una sola vez para que ninguna pantalla tenga
/// que interpretar texto de Postgres.
class StageChangeException implements Exception {
  const StageChangeException(this.mensaje, {this.original});

  /// Listo para mostrar tal cual.
  final String mensaje;

  /// El error crudo, para Crashlytics.
  final Object? original;

  @override
  String toString() => 'StageChangeException: $mensaje';
}

StageChangeException _traducir(Object e) {
  final texto = e is PostgrestException ? e.message : e.toString();

  if (texto.contains('hace falta un motivo')) {
    return StageChangeException(
      'Para descartar a alguien hace falta anotar el motivo.',
      original: e,
    );
  }
  if (texto.contains('transición no permitida')) {
    return StageChangeException(
      'Ese cambio de etapa no está permitido desde la etapa actual. '
      'Actualizá la pantalla y probá de nuevo.',
      original: e,
    );
  }
  if (texto.contains('no existe o no pertenece') ||
      texto.contains('dejó de pertenecer')) {
    return StageChangeException(
      'Esta postulación ya no está disponible para tu empresa.',
      original: e,
    );
  }
  if (texto.contains('sin sesión activa')) {
    return StageChangeException(
      'Tu sesión se cerró. Volvé a entrar para seguir.',
      original: e,
    );
  }
  if (texto.contains('240 caracteres')) {
    return StageChangeException(
      'El motivo es muy largo. Dejá lo esencial acá y el resto en las notas.',
      original: e,
    );
  }
  return StageChangeException(
    'No pudimos cambiar la etapa en este momento. Probá de nuevo.',
    original: e,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Escritura
// ─────────────────────────────────────────────────────────────────────────────

/// Mueve una postulación de etapa.
///
/// [reason] es obligatorio cuando [status] es `rejected` — lo exige el
/// servidor y se valida también acá para no gastar una ida y vuelta.
/// [notes] es texto libre interno de la empresa.
Future<void> setApplicationStage({
  required String applicationId,
  required String status,
  String? reason,
  String? notes,
  SupabaseClient? client,
}) async {
  final motivo = reason?.trim();
  if (status == kApplicationRejected && (motivo == null || motivo.isEmpty)) {
    throw const StageChangeException(
      'Para descartar a alguien hace falta anotar el motivo.',
    );
  }

  final db = client ?? Supabase.instance.client;
  try {
    await db.rpc(
      'update_application_status',
      params: {
        'p_application_id': applicationId,
        'p_status': status,
        'p_reason': (motivo != null && motivo.isNotEmpty) ? motivo : null,
        'p_notes': (notes != null && notes.trim().isNotEmpty)
            ? notes.trim()
            : null,
      },
    );
  } catch (e) {
    throw _traducir(e);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lectura del historial
// ─────────────────────────────────────────────────────────────────────────────

/// Un cambio de etapa ya ocurrido.
class ApplicationStageEvent {
  const ApplicationStageEvent({
    required this.id,
    required this.toStatus,
    required this.changedAt,
    this.fromStatus,
    this.changedById,
    this.reason,
    this.notes,
  });

  final String id;
  final String? fromStatus;
  final String toStatus;
  final DateTime changedAt;

  /// Quién lo hizo. Puede faltar: un cambio hecho por mantenimiento no tiene
  /// sesión y la migración prefiere registrarlo sin actor antes que perderlo.
  final String? changedById;

  final String? reason;
  final String? notes;

  static ApplicationStageEvent fromRow(Map<String, dynamic> row) {
    return ApplicationStageEvent(
      id: row['id'].toString(),
      fromStatus: row['from_status']?.toString(),
      toStatus: row['to_status']?.toString() ?? '',
      changedAt:
          DateTime.tryParse(row['changed_at']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
      changedById: row['changed_by']?.toString(),
      reason: row['reason']?.toString(),
      notes: row['notes']?.toString(),
    );
  }

  /// Cómo nombrar al actor.
  ///
  /// Hoy la cuenta de empresa es UNA sola persona: no existe todavía equipo
  /// ni roles (es el bloque 7 del plan), así que el actor coincide siempre
  /// con la sesión. Cuando exista el equipo, acá se resuelve el nombre real
  /// del integrante en vez de esta etiqueta.
  String actorLabel(String? miUid) {
    if (changedById == null) return 'Sistema';
    if (miUid != null && changedById == miUid) return 'Vos';
    return 'Otro integrante';
  }
}

/// Historial completo de una postulación, del cambio más nuevo al más viejo.
///
/// Devuelve lista vacía —no error— cuando la postulación no tiene historial:
/// eso es lo normal para las anteriores a la migración 050.
Future<List<ApplicationStageEvent>> loadStageHistory(
  String applicationId, {
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  final rows = await db
      .from('job_application_stage_history')
      .select('id, from_status, to_status, changed_at, changed_by, reason, notes')
      .eq('application_id', applicationId)
      .order('changed_at', ascending: false);

  return List<Map<String, dynamic>>.from(rows)
      .map(ApplicationStageEvent.fromRow)
      .toList();
}
