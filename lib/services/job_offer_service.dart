import 'package:supabase_flutter/supabase_flutter.dart';

/// Ofertas laborales reales (migración 051).
///
/// Antes de esta migración "oferta" no era un dato: `job_applications.status
/// = 'accepted'` era lo único que existía, sin salario, vencimiento,
/// beneficios ni historial de negociación (ver la cabecera de
/// `empresa_ofertas_screen.dart` y `ofertas_recibidas_screen.dart`, todavía
/// sin la ADENDA de este bloque al momento de escribir este archivo).
///
/// ÚNICA VÍA DE ESCRITURA. `job_offers` no tiene policy de INSERT/UPDATE para
/// nadie: las seis funciones de acá son la única forma de tocar una oferta.
/// Cada una autoriza por su cuenta (empresa dueña o candidato dueño) del lado
/// del servidor — este archivo no duplica esa autorización, sólo llama.
///
/// LA REGLA QUE ATA TODO. Aceptar una oferta mueve `job_applications.status`
/// a `hired` pasando por la misma matriz de transiciones que cualquier otro
/// cambio de etapa (ver `application_stage_service.dart`). Rechazar una
/// oferta NO descarta la postulación: la empresa decide eso aparte.

// ─────────────────────────────────────────────────────────────────────────────
// Vocabulario
// ────────────────────────────────────────────────────────────────────────────

/// Los ocho estados reales de `job_offers.status`.
const List<String> kOfferOpenStatuses = ['sent', 'viewed', 'changes_requested'];
const List<String> kOfferClosedStatuses = [
  'accepted',
  'declined',
  'withdrawn',
  'expired',
];

String offerStatusLabel(String status) => switch (status) {
      'draft' => 'Borrador',
      'sent' => 'Enviada',
      'viewed' => 'Vista',
      'changes_requested' => 'Cambios pedidos',
      'accepted' => 'Aceptada',
      'declined' => 'Rechazada',
      'withdrawn' => 'Retirada',
      'expired' => 'Vencida',
      _ => status,
    };

/// Si la oferta todavía admite una acción (revisar, retirar, responder).
bool offerStatusAbierta(String status) => kOfferOpenStatuses.contains(status);

String offerChangeKindLabel(String changeKind) => switch (changeKind) {
      'creada' => 'Oferta creada',
      'enviada' => 'Oferta enviada',
      'revisada' => 'Oferta revisada',
      'vista' => 'El candidato la vio',
      'cambios_pedidos' => 'Pidió cambios',
      'aceptada' => 'Oferta aceptada',
      'rechazada' => 'Oferta rechazada',
      'retirada' => 'Oferta retirada',
      'vencida' => 'Oferta vencida',
      _ => changeKind,
    };

// ─────────────────────────────────────────────────────────────────────────────
// Modelo
// ────────────────────────────────────────────────────────────────────────────

class JobOffer {
  const JobOffer({
    required this.id,
    required this.applicationId,
    required this.companyId,
    required this.candidateId,
    required this.jobId,
    required this.status,
    required this.salaryPeriod,
    required this.benefits,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.salaryAmount,
    this.salaryCurrency,
    this.modalidad,
    this.startDate,
    this.expiresAt,
    this.message,
    this.decidedAt,
    this.declineReason,
  });

  final String id;
  final String applicationId;
  final String companyId;
  final String candidateId;
  final String jobId;

  /// Crudo de la base, sin traducir: usar [offerStatusLabel] para mostrar.
  final String status;

  final double? salaryAmount;
  final String? salaryCurrency; // 'ARS' | 'USD'
  final String salaryPeriod; // 'mensual' | 'anual' | 'hora'
  final String? modalidad; // 'presencial' | 'hibrido' | 'remoto'
  final List<String> benefits;
  final DateTime? startDate;
  final DateTime? expiresAt;
  final String? message;
  final int version;
  final DateTime? decidedAt;
  final String? declineReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get abierta => offerStatusAbierta(status);

  bool get vencida =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now()) && abierta;

  static JobOffer fromRow(Map<String, dynamic> row) {
    return JobOffer(
      id: row['id'].toString(),
      applicationId: row['application_id'].toString(),
      companyId: row['company_id'].toString(),
      candidateId: row['candidate_id'].toString(),
      jobId: row['job_id'].toString(),
      status: row['status']?.toString() ?? 'draft',
      salaryAmount: row['salary_amount'] == null
          ? null
          : double.tryParse(row['salary_amount'].toString()),
      salaryCurrency: row['salary_currency']?.toString(),
      salaryPeriod: row['salary_period']?.toString() ?? 'mensual',
      modalidad: row['modalidad']?.toString(),
      benefits: [
        for (final b in (row['benefits'] as List? ?? const [])) b.toString(),
      ],
      startDate: DateTime.tryParse(row['start_date']?.toString() ?? ''),
      expiresAt: DateTime.tryParse(row['expires_at']?.toString() ?? ''),
      message: (row['message']?.toString().isNotEmpty ?? false)
          ? row['message'].toString()
          : null,
      version: int.tryParse(row['version']?.toString() ?? '') ?? 1,
      decidedAt: DateTime.tryParse(row['decided_at']?.toString() ?? ''),
      declineReason: (row['decline_reason']?.toString().isNotEmpty ?? false)
          ? row['decline_reason'].toString()
          : null,
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '') ??
              DateTime.now(),
      updatedAt:
          DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
              DateTime.now(),
    );
  }

  /// "ARS $850.000/mes" o "A convenir" si falta el dato.
  String get salarioFormateado {
    final monto = salaryAmount;
    final moneda = salaryCurrency;
    if (monto == null || moneda == null) return 'A convenir';
    final entero = monto.round().toString();
    final conPuntos = entero.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => '.',
    );
    final periodo = switch (salaryPeriod) {
      'anual' => '/año',
      'hora' => '/hora',
      _ => '/mes',
    };
    return '$moneda \$$conPuntos$periodo';
  }

  String get modalidadLabel => switch (modalidad) {
        'presencial' => 'Presencial',
        'hibrido' => 'Híbrido',
        'remoto' => 'Remoto',
        _ => '',
      };
}

/// Una entrada del historial de versiones de una oferta (`job_offer_versions`).
class JobOfferVersion {
  const JobOfferVersion({
    required this.id,
    required this.offerId,
    required this.version,
    required this.changeKind,
    required this.createdAt,
    this.message,
    this.actorId,
  });

  final String id;
  final String offerId;
  final int version;
  final String changeKind;
  final String? message;
  final String? actorId;
  final DateTime createdAt;

  static JobOfferVersion fromRow(Map<String, dynamic> row) {
    return JobOfferVersion(
      id: row['id'].toString(),
      offerId: row['offer_id'].toString(),
      version: int.tryParse(row['version']?.toString() ?? '') ?? 1,
      changeKind: row['change_kind']?.toString() ?? '',
      message: (row['message']?.toString().isNotEmpty ?? false)
          ? row['message'].toString()
          : null,
      actorId: row['actor_id']?.toString(),
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Errores
// ─────────────────────────────────────────────────────────────────────────────

/// Mismo patrón que `StageChangeException`: el mensaje ya sale listo para
/// mostrarle a una persona, y el error crudo queda disponible para Crashlytics.
class JobOfferException implements Exception {
  const JobOfferException(this.mensaje, {this.original});

  final String mensaje;
  final Object? original;

  @override
  String toString() => 'JobOfferException: $mensaje';
}

JobOfferException _traducir(Object e) {
  final texto = e is PostgrestException ? e.message : e.toString();

  if (texto.contains('ya tiene una oferta abierta')) {
    return JobOfferException(
      'Esta postulación ya tiene una oferta abierta. Retirala o esperá su '
      'respuesta antes de crear otra.',
      original: e,
    );
  }
  if (texto.contains('ya está contratada')) {
    return JobOfferException(
      'Esta persona ya está contratada.',
      original: e,
    );
  }
  if (texto.contains('descartado')) {
    return JobOfferException(
      'No se le puede hacer una oferta a alguien descartado.',
      original: e,
    );
  }
  if (texto.contains('faltan datos')) {
    return JobOfferException(
      'Faltan datos para enviarla: monto, moneda, fecha de inicio y '
      'vencimiento son obligatorios.',
      original: e,
    );
  }
  if (texto.contains('vencimiento tiene que ser posterior')) {
    return JobOfferException(
      'La fecha de vencimiento tiene que ser posterior a ahora.',
      original: e,
    );
  }
  if (texto.contains('la oferta venció')) {
    return JobOfferException(
      'Esta oferta venció y ya no se puede responder.',
      original: e,
    );
  }
  if (texto.contains('ya no está abierta') ||
      texto.contains('ya fue enviada o está cerrada') ||
      texto.contains('ya está cerrada')) {
    return JobOfferException(
      'Esta oferta ya no está abierta. Actualizá la pantalla.',
      original: e,
    );
  }
  if (texto.contains('hace falta un mensaje')) {
    return JobOfferException(
      'Para rechazar o pedir cambios hace falta escribir un mensaje.',
      original: e,
    );
  }
  if (texto.contains('no existe o no es') || texto.contains('no existe o no pertenece')) {
    return JobOfferException(
      'Esta oferta ya no está disponible.',
      original: e,
    );
  }
  if (texto.contains('sin sesión activa')) {
    return JobOfferException(
      'Tu sesión se cerró. Volvé a entrar para seguir.',
      original: e,
    );
  }
  return JobOfferException(
    'No pudimos completar la acción en este momento. Probá de nuevo.',
    original: e,
  );
}

String? _fechaSql(DateTime? d) {
  if (d == null) return null;
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Escritura
// ─────────────────────────────────────────────────────────────────────────────

/// Crea una oferta en borrador sobre una postulación. El candidato todavía no
/// la ve — hace falta [sendJobOffer] para eso.
Future<String> createJobOffer({
  required String applicationId,
  double? salaryAmount,
  String? salaryCurrency,
  String salaryPeriod = 'mensual',
  String? modalidad,
  List<String> benefits = const [],
  DateTime? startDate,
  DateTime? expiresAt,
  String? message,
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  try {
    final id = await db.rpc('create_job_offer', params: {
      'p_application_id': applicationId,
      'p_salary_amount': salaryAmount,
      'p_salary_currency': salaryCurrency,
      'p_salary_period': salaryPeriod,
      'p_modalidad': modalidad,
      'p_benefits': benefits,
      'p_start_date': _fechaSql(startDate),
      'p_expires_at': expiresAt?.toUtc().toIso8601String(),
      'p_message': (message?.trim().isNotEmpty ?? false) ? message!.trim() : null,
    });
    return id.toString();
  } catch (e) {
    throw _traducir(e);
  }
}

/// Envía una oferta ya creada. El candidato la ve a partir de acá.
Future<void> sendJobOffer(String offerId, {SupabaseClient? client}) async {
  final db = client ?? Supabase.instance.client;
  try {
    await db.rpc('send_job_offer', params: {'p_offer_id': offerId});
  } catch (e) {
    throw _traducir(e);
  }
}

/// Revisa (nueva versión de) una oferta ya enviada. Sólo pisa los campos que
/// vienen con valor.
Future<void> reviseJobOffer({
  required String offerId,
  double? salaryAmount,
  String? salaryCurrency,
  String? salaryPeriod,
  String? modalidad,
  List<String>? benefits,
  DateTime? startDate,
  DateTime? expiresAt,
  String? message,
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  try {
    await db.rpc('revise_job_offer', params: {
      'p_offer_id': offerId,
      'p_salary_amount': salaryAmount,
      'p_salary_currency': salaryCurrency,
      'p_salary_period': salaryPeriod,
      'p_modalidad': modalidad,
      'p_benefits': benefits,
      'p_start_date': _fechaSql(startDate),
      'p_expires_at': expiresAt?.toUtc().toIso8601String(),
      'p_message': (message?.trim().isNotEmpty ?? false) ? message!.trim() : null,
    });
  } catch (e) {
    throw _traducir(e);
  }
}

/// Marca una oferta como vista. Silencioso a propósito: es un efecto
/// secundario de abrir la pantalla, no una acción de la persona. Que falle
/// no debería romper la vista de la oferta (mismo criterio que el backend).
Future<void> markJobOfferViewed(String offerId, {SupabaseClient? client}) async {
  final db = client ?? Supabase.instance.client;
  try {
    await db.rpc('mark_job_offer_viewed', params: {'p_offer_id': offerId});
  } catch (_) {
    // silencioso
  }
}

/// El candidato responde. [decision] es 'accepted', 'declined' o
/// 'changes_requested'. [message] es obligatorio salvo para 'accepted' — se
/// valida acá también para no gastar una ida y vuelta, pero la autoridad
/// sigue siendo el servidor.
Future<void> respondToJobOffer({
  required String offerId,
  required String decision,
  String? message,
  SupabaseClient? client,
}) async {
  final msg = message?.trim();
  if (decision != 'accepted' && (msg == null || msg.isEmpty)) {
    throw const JobOfferException(
      'Para rechazar o pedir cambios hace falta escribir un mensaje.',
    );
  }

  final db = client ?? Supabase.instance.client;
  try {
    await db.rpc('respond_to_job_offer', params: {
      'p_offer_id': offerId,
      'p_decision': decision,
      'p_message': (msg != null && msg.isNotEmpty) ? msg : null,
    });
  } catch (e) {
    throw _traducir(e);
  }
}

/// La empresa retira una oferta abierta.
Future<void> withdrawJobOffer(
  String offerId, {
  String? reason,
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  try {
    await db.rpc('withdraw_job_offer', params: {
      'p_offer_id': offerId,
      'p_reason': (reason?.trim().isNotEmpty ?? false) ? reason!.trim() : null,
    });
  } catch (e) {
    throw _traducir(e);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lectura
// ─────────────────────────────────────────────────────────────────────────────

/// La oferta más reciente de una postulación (abierta o cerrada), si existe.
Future<JobOffer?> loadOfferForApplication(
  String applicationId, {
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  final row = await db
      .from('job_offers')
      .select()
      .eq('application_id', applicationId)
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();
  if (row == null) return null;
  return JobOffer.fromRow(row);
}

/// Todas las ofertas hechas por la empresa autenticada (sin los borradores
/// que todavía no se enviaron).
Future<List<JobOffer>> loadOffersForCompany({SupabaseClient? client}) async {
  final db = client ?? Supabase.instance.client;
  final uid = db.auth.currentUser?.id;
  if (uid == null) return const [];
  final rows = await db
      .from('job_offers')
      .select()
      .eq('company_id', uid)
      .neq('status', 'draft')
      .order('created_at', ascending: false);
  return [for (final r in rows) JobOffer.fromRow(r)];
}

/// Todas las ofertas recibidas por el candidato autenticado.
Future<List<JobOffer>> loadOffersForCandidate({SupabaseClient? client}) async {
  final db = client ?? Supabase.instance.client;
  final uid = db.auth.currentUser?.id;
  if (uid == null) return const [];
  final rows = await db
      .from('job_offers')
      .select()
      .eq('candidate_id', uid)
      .order('created_at', ascending: false);
  return [for (final r in rows) JobOffer.fromRow(r)];
}

/// Historial de versiones de una oferta, de la más vieja a la más nueva.
Future<List<JobOfferVersion>> loadOfferVersions(
  String offerId, {
  SupabaseClient? client,
}) async {
  final db = client ?? Supabase.instance.client;
  final rows = await db
      .from('job_offer_versions')
      .select()
      .eq('offer_id', offerId)
      .order('created_at', ascending: true);
  return [for (final r in rows) JobOfferVersion.fromRow(r)];
}
