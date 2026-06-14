import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ReportUserService — Sistema de reportes de usuarios
//
// Razones soportadas:
//  • harassment     — Acoso o comportamiento abusivo
//  • spam           — Spam o contenido no deseado
//  • fake_profile   — Perfil falso o suplantación
//  • inappropriate  — Contenido inapropiado
//  • scam           — Estafa o fraude
//  • other          — Otro motivo
//
// Los reportes se guardan en la tabla `user_reports` y se procesan
// manualmente desde el Admin Panel.
// ─────────────────────────────────────────────────────────────────────────────

enum ReportReason {
  harassment('harassment', 'Acoso o comportamiento abusivo'),
  spam('spam', 'Spam o contenido no deseado'),
  fakeProfile('fake_profile', 'Perfil falso o suplantación'),
  inappropriate('inappropriate', 'Contenido inapropiado'),
  scam('scam', 'Estafa o fraude'),
  other('other', 'Otro motivo');

  final String value;
  final String label;
  const ReportReason(this.value, this.label);
}

class ReportUserService {
  ReportUserService._();
  static final ReportUserService instance = ReportUserService._();

  SupabaseClient get _db => Supabase.instance.client;

  /// Envía un reporte sobre un usuario.
  ///
  /// Retorna null en éxito, o un String de error.
  Future<String?> reportUser({
    required String reportedId,
    required ReportReason reason,
    String? details,
  }) async {
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) return 'No autenticado';

      await _db.from('user_reports').insert({
        'reporter_id': uid,
        'reported_id': reportedId,
        'reason': reason.value,
        'details': details,
      });

      debugPrint('📋 Report submitted: ${reason.value} for $reportedId');
      return null;
    } catch (e) {
      debugPrint('❌ ReportUserService.reportUser: $e');
      return 'Error al enviar reporte: $e';
    }
  }
}
