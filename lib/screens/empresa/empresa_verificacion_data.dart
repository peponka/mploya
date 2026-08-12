import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/company_verification_service.dart';

/// Una fila real de `company_verifications`.
@immutable
class SolicitudVerificacion {
  final String id;
  final VerificationLevel nivel;

  /// 'pending' · 'approved' · 'rejected', tal como está en la base.
  final String estado;

  final DateTime? cuando;
  final String? notaDeRevision;

  const SolicitudVerificacion({
    required this.id,
    required this.nivel,
    required this.estado,
    this.cuando,
    this.notaDeRevision,
  });

  bool get aprobada => estado == 'approved';
  bool get pendiente => estado == 'pending';
  bool get rechazada => estado == 'rejected';
}

@immutable
class VerificacionData {
  /// Nivel vigente: el más alto aprobado. `none` si no hay ninguno.
  final VerificationLevel nivel;

  /// Todas las filas de la empresa, de la más nueva a la más vieja.
  final List<SolicitudVerificacion> historial;

  /// Dominio del email de la sesión, para poder explicar el resultado de la
  /// verificación automática sin adivinar.
  final String? dominioEmail;

  final bool error;

  const VerificacionData({
    this.nivel = VerificationLevel.none,
    this.historial = const [],
    this.dominioEmail,
    this.error = false,
  });

  static const vacia = VerificacionData();

  bool tieneAprobado(VerificationLevel n) =>
      historial.any((s) => s.nivel == n && s.aprobada);

  SolicitudVerificacion? pendienteDe(VerificationLevel n) {
    for (final s in historial) {
      if (s.nivel == n && s.pendiente) return s;
    }
    return null;
  }

  SolicitudVerificacion? rechazoDe(VerificationLevel n) {
    for (final s in historial) {
      if (s.nivel == n && s.rechazada) return s;
    }
    return null;
  }
}

VerificationLevel _nivelDesde(String? s) {
  switch (s) {
    case 'basic':
      return VerificationLevel.basic;
    case 'verified':
      return VerificationLevel.verified;
    case 'trusted':
      return VerificationLevel.trusted;
    default:
      return VerificationLevel.none;
  }
}

/// Carga el estado real de verificación de la empresa autenticada.
///
/// No calcula nada: lee `company_verifications` y muestra lo que hay.
Future<VerificacionData> loadVerificacion() async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return const VerificacionData(error: true);

  final email = client.auth.currentUser?.email ?? '';
  final dominio = email.contains('@') ? email.split('@').last : null;

  try {
    final filas = await client
        .from('company_verifications')
        .select('id, level, status, created_at, review_note')
        .eq('company_id', uid)
        .order('created_at', ascending: false) as List<dynamic>;

    final historial = <SolicitudVerificacion>[];
    for (final raw in filas) {
      final m = raw as Map<String, dynamic>;
      final nota = m['review_note']?.toString().trim() ?? '';
      historial.add(
        SolicitudVerificacion(
          id: m['id'].toString(),
          nivel: _nivelDesde(m['level']?.toString()),
          estado: m['status']?.toString() ?? 'pending',
          cuando: DateTime.tryParse(m['created_at']?.toString() ?? ''),
          notaDeRevision: nota.isEmpty ? null : nota,
        ),
      );
    }

    // El nivel vigente es el más alto aprobado, no el más reciente: tener
    // `trusted` no se pierde por pedir después otra cosa.
    var nivel = VerificationLevel.none;
    for (final s in historial) {
      if (!s.aprobada) continue;
      if (s.nivel.index > nivel.index) nivel = s.nivel;
    }

    return VerificacionData(
      nivel: nivel,
      historial: historial,
      dominioEmail: dominio,
    );
  } catch (e) {
    debugPrint('verificacion · company_verifications: $e');
    return VerificacionData(dominioEmail: dominio, error: true);
  }
}

/// Resultado de intentar la verificación automática por email.
enum ResultadoAutoVerificacion { verificada, dominioPublico, error }

/// Dispara `autoVerifyEmail()` del servicio existente.
///
/// El servicio decide: si el dominio del email de la sesión no está en su lista
/// de dominios públicos, inserta la fila `basic` aprobada. Acá no se replica esa
/// lista — se llama y se informa el resultado.
Future<ResultadoAutoVerificacion> verificarEmailCorporativo() async {
  try {
    final ok = await CompanyVerificationService.instance.autoVerifyEmail();
    return ok
        ? ResultadoAutoVerificacion.verificada
        : ResultadoAutoVerificacion.dominioPublico;
  } catch (e) {
    debugPrint('verificacion · autoVerifyEmail: $e');
    return ResultadoAutoVerificacion.error;
  }
}
